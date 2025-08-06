"""
Reporter Agent

Generates comprehensive reports on system activities, incidents, and performance.
Provides analytics, metrics, and actionable insights for users and administrators.
"""
module Reporter

using Dates
using JSON
using Logging
using Statistics
using HTTP
using JSON3

# Import core modules
using ..Types
using ..Database
using ..Config

export start, stop, health, generate_user_report, generate_system_report, generate_incident_report, send_discord_notification, mode

# Module-level mode tracking
const CURRENT_MODE = Ref{String}("not_started")

# Agent state
Base.@kwdef mutable struct ReporterState
    running::Bool
    config::Any
    reports_generated::Int64
    last_report_time::DateTime
    health_status::String
    report_cache::Dict{String, Any}
end

const AGENT_STATE = Ref{Union{Nothing, ReporterState}}(nothing)

"""
    send_discord_notification(incident::Incident, report::Dict)

Send Discord notification for security incidents.
"""
function send_discord_notification(incident::Incident, report::Dict)
    if AGENT_STATE[] === nothing
        @warn "Reporter agent not initialized - cannot send Discord notification"
        return Dict("success" => false, "error" => "Agent not initialized")
    end
    
    state = AGENT_STATE[]
    discord_webhook_url = Config.getc(state.config, :discord_webhook_url, "")
    
    if isempty(discord_webhook_url)
        @info "No Discord webhook URL configured - skipping notification"
        return Dict("success" => true, "message" => "Discord webhook not configured")
    end
    
    try
        # Create Discord embed message
        embed = Dict(
            "title" => "🚨 X-LiGo Security Alert",
            "description" => "DeFi threat detected and processed",
            "color" => incident.severity == "critical" ? 15158332 : incident.severity == "high" ? 16776960 : 255, # Red, Yellow, Blue
            "timestamp" => string(incident.detected_at),
            "fields" => [
                Dict("name" => "Incident ID", "value" => incident.incident_id, "inline" => true),
                Dict("name" => "Position ID", "value" => incident.position_id, "inline" => true),
                Dict("name" => "Severity", "value" => uppercase(incident.severity), "inline" => true),
                Dict("name" => "Type", "value" => incident.incident_type, "inline" => true),
                Dict("name" => "Status", "value" => uppercase(incident.status), "inline" => true),
                Dict("name" => "Value at Risk", "value" => "\$$(round(incident.position_value_usd, digits=2))", "inline" => true)
            ],
            "footer" => Dict("text" => "X-LiGo DeFi Protection System")
        )
        
        # Add threat details if available
        if haskey(incident.metadata, "attack_vector")
            push!(embed["fields"], Dict("name" => "Attack Vector", "value" => incident.metadata["attack_vector"], "inline" => false))
        end
        
        # Add protection status
        if incident.status == "protected"
            push!(embed["fields"], Dict("name" => "✅ Protection", "value" => "Threat successfully blocked", "inline" => false))
        elseif incident.status == "policy_blocked"
            push!(embed["fields"], Dict("name" => "🛡️ Policy Action", "value" => "Blocked by security policy", "inline" => false))
        end
        
        # Create Discord webhook payload
        payload = Dict(
            "embeds" => [embed],
            "username" => "X-LiGo Security Bot",
            "avatar_url" => "https://cdn.discordapp.com/emojis/🛡️.png"
        )
        
        # Send HTTP POST to Discord webhook
        response = HTTP.post(
            discord_webhook_url,
            ["Content-Type" => "application/json"],
            JSON3.write(payload);
            timeout=10
        )
        
        if response.status == 204  # Discord returns 204 for successful webhook
            @info "✅ Discord notification sent successfully for incident $(incident.incident_id)"
            return Dict("success" => true, "message" => "Discord notification sent")
        else
            @warn "Discord webhook returned status $(response.status)"
            return Dict("success" => false, "error" => "Discord webhook failed with status $(response.status)")
        end
        
    catch e
        @error "❌ Failed to send Discord notification: $e"
        return Dict("success" => false, "error" => string(e))
    end
end

"""
    start(config::Dict)::NamedTuple

Start the Reporter agent.
"""
function start(config::Dict)::NamedTuple
    @info "📊 Starting Reporter Agent..."
    
    demo_mode = Config.getc(config, :demo_mode, true)
    
    try
        AGENT_STATE[] = ReporterState(
            running = false,
            config = config,
            reports_generated = 0,
            last_report_time = now(),
            health_status = "starting",
            report_cache = Dict{String, Any}()
        )
        
        state = AGENT_STATE[]
        state.running = true
        state.health_status = "running"
        
        # Determine mode based on demo_mode
        mode_str = demo_mode ? "mock" : "real"
        CURRENT_MODE[] = mode_str
        
        @info "✅ Reporter Agent started successfully"
        
        return (success=true, message="Reporter Agent started successfully", mode=mode_str)
        
    catch e
        @error "❌ Failed to start Reporter Agent: $e"
        if AGENT_STATE[] !== nothing
            AGENT_STATE[].health_status = "error"
        end
        
        if !demo_mode
            # Fail in real mode
            CURRENT_MODE[] = "mock"
            return (success=false, message="Failed to start Reporter Agent: $e", mode="mock")
        end
        
        # Allow mock in demo mode
        CURRENT_MODE[] = "mock"
        return (success=true, message="Reporter Agent started in mock mode (error: $e)", mode="mock")
    end
end

"""
    mode()::String

Get current agent mode.
"""
function mode()::String
    return CURRENT_MODE[]
end

"""
    stop()

Stop the Reporter agent.
"""
function stop()
    if AGENT_STATE[] !== nothing
        @info "🛑 Stopping Reporter Agent..."
        
        state = AGENT_STATE[]
        state.running = false
        state.health_status = "stopped"
        
        @info "✅ Reporter Agent stopped"
    end
    CURRENT_MODE[] = "not_started"
end

"""
    health()

Get agent health status.
"""
function health()
    if AGENT_STATE[] === nothing
        return Dict("status" => "not_initialized")
    end
    
    state = AGENT_STATE[]
    
    return Dict(
        "status" => state.health_status,
        "running" => state.running,
        "reports_generated" => state.reports_generated,
        "last_report" => state.last_report_time,
        "cache_size" => length(state.report_cache)
    )
end

# Agent wrapper
struct ReporterAgent
    state::ReporterState
end

function stop(agent::ReporterAgent)
    stop()
end

function health(agent::ReporterAgent)
    return health()
end

"""
    generate_user_report(user_id::String, period_days::Int=30)

Generate comprehensive user activity report.
"""
function generate_user_report(user_id::String, period_days::Int=30)
    if AGENT_STATE[] === nothing
        error("Reporter agent not initialized")
    end
    
    state = AGENT_STATE[]
    
    @info "📈 Generating user report for: $user_id (last $period_days days)"
    
    try
        # Get user data
        user = Database.get_user(user_id)
        if user === nothing
            return Dict("error" => "User not found")
        end
        
        # Calculate date range
        end_date = now()
        start_date = end_date - Day(period_days)
        
        # Get user positions
        positions = Database.get_user_positions(user_id)
        
        # Get user incidents
        incidents = Database.get_user_incidents(user_id, start_date, end_date)
        
        # Calculate metrics
        metrics = calculate_user_metrics(user, positions, incidents, start_date, end_date)
        
        # Generate protection analytics
        protection_stats = analyze_protection_effectiveness(incidents)
        
        # Create risk assessment
        risk_assessment = assess_user_risk_profile(user, positions, incidents)
        
        # Generate recommendations
        recommendations = generate_user_recommendations(user, positions, incidents, metrics)
        
        report = Dict(
            "user_id" => user_id,
            "report_period" => Dict(
                "start_date" => start_date,
                "end_date" => end_date,
                "days" => period_days
            ),
            "user_profile" => Dict(
                "address" => user.wallet_address,
                "preferred_blockchain" => user.preferred_blockchain,
                "risk_tolerance" => user.risk_tolerance,
                "joined_date" => user.created_at
            ),
            "portfolio_summary" => Dict(
                "total_positions" => length(positions),
                "active_positions" => count(p -> p.status == "active", positions),
                "total_value_usd" => sum(p -> p.position_value_usd, positions),
                "total_debt_usd" => sum(p -> p.debt_value_usd, positions),
                "average_health_factor" => length(positions) > 0 ? mean([p.health_factor for p in positions]) : 0.0
            ),
            "protection_activity" => Dict(
                "total_incidents" => length(incidents),
                "protection_events" => count(i -> i.status == "protected", incidents),
                "liquidation_events" => count(i -> i.status == "liquidated", incidents),
                "total_protected_value" => sum(i -> i.position_value_usd, filter(i -> i.status == "protected", incidents))
            ),
            "metrics" => metrics,
            "protection_effectiveness" => protection_stats,
            "risk_assessment" => risk_assessment,
            "recommendations" => recommendations,
            "generated_at" => now()
        )
        
        state.reports_generated += 1
        state.last_report_time = now()
        
        # Cache report for 1 hour
        cache_key = "user_$(user_id)_$(period_days)d"
        state.report_cache[cache_key] = (report, now() + Hour(1))
        
        @info "✅ User report generated successfully"
        
        return report
        
    catch e
        @error "❌ Failed to generate user report: $e"
        return Dict("error" => string(e))
    end
end

"""
    generate_system_report(period_days::Int=7)

Generate system-wide performance and activity report.
"""
function generate_system_report(period_days::Int=7)
    if AGENT_STATE[] === nothing
        error("Reporter agent not initialized")
    end
    
    state = AGENT_STATE[]
    
    @info "🌐 Generating system report (last $period_days days)"
    
    try
        # Calculate date range
        end_date = now()
        start_date = end_date - Day(period_days)
        
        # Get system-wide data
        all_users = Database.get_all_users()
        all_positions = Database.get_all_positions()
        all_incidents = Database.get_incidents_by_date_range(start_date, end_date)
        
        # System metrics
        system_metrics = calculate_system_metrics(all_users, all_positions, all_incidents, start_date, end_date)
        
        # Agent performance
        agent_performance = analyze_agent_performance()
        
        # Top risks
        top_risks = identify_top_risks(all_positions)
        
        # Market conditions
        market_analysis = analyze_market_conditions()
        
        report = Dict(
            "report_period" => Dict(
                "start_date" => start_date,
                "end_date" => end_date,
                "days" => period_days
            ),
            "system_overview" => Dict(
                "total_users" => length(all_users),
                "active_users" => count(u -> any(p -> p.status == "active", Database.get_user_positions(u.user_id)), all_users),
                "total_positions" => length(all_positions),
                "active_positions" => count(p -> p.status == "active", all_positions),
                "total_tvl_usd" => sum(p -> p.position_value_usd, all_positions),
                "total_debt_usd" => sum(p -> p.debt_value_usd, all_positions)
            ),
            "incident_summary" => Dict(
                "total_incidents" => length(all_incidents),
                "protection_successes" => count(i -> i.status == "protected", all_incidents),
                "liquidation_events" => count(i -> i.status == "liquidated", all_incidents),
                "success_rate" => length(all_incidents) > 0 ? count(i -> i.status == "protected", all_incidents) / length(all_incidents) : 0.0,
                "total_value_protected" => sum(i -> i.position_value_usd, filter(i -> i.status == "protected", all_incidents))
            ),
            "system_metrics" => system_metrics,
            "agent_performance" => agent_performance,
            "top_risks" => top_risks,
            "market_analysis" => market_analysis,
            "generated_at" => now()
        )
        
        state.reports_generated += 1
        state.last_report_time = now()
        
        @info "✅ System report generated successfully"
        
        return report
        
    catch e
        @error "❌ Failed to generate system report: $e"
        return Dict("error" => string(e))
    end
end

"""
    generate_incident_report(incident::Incident)

Generate detailed incident analysis report.
"""
function generate_incident_report(incident::Incident)
    if AGENT_STATE[] === nothing
        error("Reporter agent not initialized")
    end
    
    state = AGENT_STATE[]
    
    @info "🚨 Generating incident report for: $(incident.incident_id)"
    
    try
        # Get related position
        position = Database.get_position(incident.position_id)
        if position === nothing
            return Dict("error" => "Position not found")
        end
        
        # Get user
        user = Database.get_user(position.user_id)
        
        # Timeline analysis
        timeline = analyze_incident_timeline(incident, position)
        
        # Root cause analysis
        root_causes = analyze_root_causes(incident, position)
        
        # Financial impact
        financial_impact = calculate_financial_impact(incident, position)
        
        # Prevention analysis
        prevention_analysis = analyze_prevention_opportunities(incident, position)
        
        # Similar incidents
        similar_incidents = find_similar_incidents(incident)
        
        report = Dict(
            "incident_id" => incident.incident_id,
            "incident_overview" => Dict(
                "type" => incident.incident_type,
                "status" => incident.status,
                "severity" => incident.severity,
                "detected_at" => incident.detected_at,
                "resolved_at" => incident.resolved_at,
                "duration_minutes" => incident.resolved_at !== nothing ? 
                    Dates.value(incident.resolved_at - incident.detected_at) ÷ 60000 : nothing
            ),
            "position_details" => Dict(
                "position_id" => position.position_id,
                "user_id" => position.user_id,
                "blockchain" => position.blockchain,
                "protocol" => position.protocol,
                "position_value_usd" => position.position_value_usd,
                "debt_value_usd" => position.debt_value_usd,
                "health_factor" => position.health_factor,
                "liquidation_threshold" => position.liquidation_threshold
            ),
            "timeline" => timeline,
            "root_cause_analysis" => root_causes,
            "financial_impact" => financial_impact,
            "prevention_analysis" => prevention_analysis,
            "similar_incidents" => similar_incidents,
            "lessons_learned" => generate_lessons_learned(incident, position),
            "generated_at" => now()
        )
        
        state.reports_generated += 1
        state.last_report_time = now()
        
        # Send Discord notification for security incidents
        if incident.incident_type in ["liquidation_risk", "flash_loan_attack", "sandwich_attack", "governance_attack", "price_manipulation", "suspicious_transaction"]
            @info "📢 Sending Discord notification for security incident..."
            discord_result = send_discord_notification(incident, report)
            if discord_result["success"]
                @info "✅ Discord notification sent for incident $(incident.incident_id)"
            else
                @warn "⚠️ Discord notification failed: $(discord_result["error"])"
            end
        end
        
        @info "✅ Incident report generated successfully"
        
        return report
        
    catch e
        @error "❌ Failed to generate incident report: $e"
        return Dict("error" => string(e))
    end
end

"""
    calculate_user_metrics(user, positions, incidents, start_date, end_date)

Calculate comprehensive user metrics.
"""
function calculate_user_metrics(user, positions, incidents, start_date, end_date)
    active_positions = filter(p -> p.status == "active", positions)
    period_incidents = filter(i -> i.detected_at >= start_date && i.detected_at <= end_date, incidents)
    
    return Dict(
        "portfolio_health" => Dict(
            "average_health_factor" => length(active_positions) > 0 ? mean([p.health_factor for p in active_positions]) : 0.0,
            "lowest_health_factor" => length(active_positions) > 0 ? minimum([p.health_factor for p in active_positions]) : 0.0,
            "positions_at_risk" => count(p -> p.health_factor < 1.5, active_positions),
            "total_collateral_ratio" => calculate_total_collateral_ratio(active_positions)
        ),
        "protection_performance" => Dict(
            "incidents_in_period" => length(period_incidents),
            "protection_rate" => length(period_incidents) > 0 ? count(i -> i.status == "protected", period_incidents) / length(period_incidents) : 1.0,
            "average_response_time" => calculate_average_response_time(period_incidents),
            "value_saved" => sum(i -> i.position_value_usd, filter(i -> i.status == "protected", period_incidents))
        ),
        "risk_metrics" => Dict(
            "diversification_score" => calculate_diversification_score(positions),
            "concentration_risk" => calculate_concentration_risk(positions),
            "protocol_exposure" => calculate_protocol_exposure(positions),
            "blockchain_exposure" => calculate_blockchain_exposure(positions)
        ),
        "financial_summary" => Dict(
            "total_value_locked" => sum(p -> p.position_value_usd, active_positions),
            "total_debt" => sum(p -> p.debt_value_usd, active_positions),
            "net_value" => sum(p -> p.position_value_usd - p.debt_value_usd, active_positions),
            "monthly_yields" => estimate_monthly_yields(positions)
        )
    )
end

"""
    calculate_system_metrics(users, positions, incidents, start_date, end_date)

Calculate system-wide performance metrics.
"""
function calculate_system_metrics(users, positions, incidents, start_date, end_date)
    active_positions = filter(p -> p.status == "active", positions)
    period_incidents = filter(i -> i.detected_at >= start_date && i.detected_at <= end_date, incidents)
    
    return Dict(
        "performance_metrics" => Dict(
            "system_uptime" => 99.9,  # Mock - would track actual uptime
            "average_response_time" => calculate_average_response_time(period_incidents),
            "protection_success_rate" => length(period_incidents) > 0 ? count(i -> i.status == "protected", period_incidents) / length(period_incidents) : 1.0,
            "false_positive_rate" => 0.05  # Mock - would calculate actual FP rate
        ),
        "network_metrics" => Dict(
            "total_tvl" => sum(p -> p.position_value_usd, active_positions),
            "total_debt" => sum(p -> p.debt_value_usd, active_positions),
            "average_health_factor" => length(active_positions) > 0 ? mean([p.health_factor for p in active_positions]) : 0.0,
            "critical_positions" => count(p -> p.health_factor < 1.2, active_positions)
        ),
        "user_engagement" => Dict(
            "active_users" => length(users),
            "new_users_period" => count(u -> u.created_at >= start_date, users),
            "retention_rate" => 0.85,  # Mock - would calculate actual retention
            "avg_positions_per_user" => length(users) > 0 ? length(positions) / length(users) : 0.0
        ),
        "blockchain_distribution" => calculate_blockchain_distribution(positions),
        "protocol_distribution" => calculate_protocol_distribution(positions)
    )
end

"""
    analyze_protection_effectiveness(incidents)

Analyze protection system effectiveness.
"""
function analyze_protection_effectiveness(incidents)
    if isempty(incidents)
        return Dict("no_data" => true)
    end
    
    protected_incidents = filter(i -> i.status == "protected", incidents)
    liquidated_incidents = filter(i -> i.status == "liquidated", incidents)
    
    return Dict(
        "total_incidents" => length(incidents),
        "protection_rate" => length(protected_incidents) / length(incidents),
        "average_detection_time" => calculate_average_detection_time(incidents),
        "average_resolution_time" => calculate_average_resolution_time(protected_incidents),
        "value_protected" => sum(i -> i.position_value_usd, protected_incidents),
        "value_lost" => sum(i -> i.position_value_usd, liquidated_incidents),
        "cost_effectiveness" => calculate_cost_effectiveness(protected_incidents)
    )
end

"""
    assess_user_risk_profile(user, positions, incidents)

Assess user's risk profile and characteristics.
"""
function assess_user_risk_profile(user, positions, incidents)
    return Dict(
        "risk_score" => calculate_risk_score(user, positions, incidents),
        "risk_category" => categorize_risk_level(user, positions),
        "diversification_level" => assess_diversification(positions),
        "experience_level" => assess_experience_level(user, positions, incidents),
        "protection_dependency" => assess_protection_dependency(incidents),
        "recommended_settings" => recommend_risk_settings(user, positions)
    )
end

"""
    generate_user_recommendations(user, positions, incidents, metrics)

Generate personalized recommendations for user.
"""
function generate_user_recommendations(user, positions, incidents, metrics)
    recommendations = String[]
    
    # Health factor recommendations
    if metrics["portfolio_health"]["average_health_factor"] < 2.0
        push!(recommendations, "Consider adding more collateral or reducing debt to improve health factors")
    end
    
    # Diversification recommendations
    if metrics["risk_metrics"]["diversification_score"] < 0.6
        push!(recommendations, "Diversify across more protocols and blockchains to reduce concentration risk")
    end
    
    # Protection performance recommendations
    if metrics["protection_performance"]["protection_rate"] < 0.9
        push!(recommendations, "Review protection policies and consider more conservative thresholds")
    end
    
    # Risk-specific recommendations
    risk_score = calculate_risk_score(user, positions, incidents)
    if risk_score > 7.0
        push!(recommendations, "High risk detected - consider reducing position sizes or increasing collateral")
    end
    
    return recommendations
end

# Helper functions for calculations
function calculate_total_collateral_ratio(positions)
    total_collateral = sum(p -> p.position_value_usd, positions)
    total_debt = sum(p -> p.debt_value_usd, positions)
    return total_debt > 0 ? total_collateral / total_debt : 0.0
end

function calculate_average_response_time(incidents)
    response_times = [Dates.value(i.resolved_at - i.detected_at) ÷ 60000 for i in incidents if i.resolved_at !== nothing]
    return length(response_times) > 0 ? mean(response_times) : 0.0
end

function calculate_diversification_score(positions)
    if isempty(positions)
        return 0.0
    end
    
    protocols = unique([p.protocol for p in positions])
    blockchains = unique([p.blockchain for p in positions])
    
    # Simple diversification score based on number of protocols and chains
    protocol_score = min(length(protocols) / 5.0, 1.0)
    blockchain_score = min(length(blockchains) / 3.0, 1.0)
    
    return (protocol_score + blockchain_score) / 2.0
end

function calculate_concentration_risk(positions)
    if isempty(positions)
        return 0.0
    end
    
    total_value = sum(p -> p.position_value_usd, positions)
    max_position = maximum(p -> p.position_value_usd, positions)
    
    return max_position / total_value
end

function calculate_protocol_exposure(positions)
    protocol_values = Dict{String, Float64}()
    
    for pos in positions
        protocol_values[pos.protocol] = get(protocol_values, pos.protocol, 0.0) + pos.position_value_usd
    end
    
    return protocol_values
end

function calculate_blockchain_exposure(positions)
    blockchain_values = Dict{String, Float64}()
    
    for pos in positions
        blockchain_values[pos.blockchain] = get(blockchain_values, pos.blockchain, 0.0) + pos.position_value_usd
    end
    
    return blockchain_values
end

function estimate_monthly_yields(positions)
    # Mock yield estimation - would integrate with protocol APIs
    active_positions = filter(p -> p.status == "active", positions)
    total_value = sum(p -> p.position_value_usd, active_positions)
    
    # Assume average 5% APY across DeFi
    monthly_yield = total_value * 0.05 / 12
    
    return Dict(
        "estimated_monthly_yield" => monthly_yield,
        "annual_percentage_yield" => 5.0,
        "yield_sources" => ["lending", "liquidity_mining", "staking"]
    )
end

function calculate_blockchain_distribution(positions)
    distribution = Dict{String, Int}()
    
    for pos in positions
        distribution[pos.blockchain] = get(distribution, pos.blockchain, 0) + 1
    end
    
    return distribution
end

function calculate_protocol_distribution(positions)
    distribution = Dict{String, Int}()
    
    for pos in positions
        distribution[pos.protocol] = get(distribution, pos.protocol, 0) + 1
    end
    
    return distribution
end

function calculate_average_detection_time(incidents)
    # Mock calculation - would measure actual detection times
    return 30.0  # seconds
end

function calculate_average_resolution_time(incidents)
    resolution_times = [Dates.value(i.resolved_at - i.detected_at) ÷ 1000 for i in incidents if i.resolved_at !== nothing]
    return length(resolution_times) > 0 ? mean(resolution_times) : 0.0
end

function calculate_cost_effectiveness(incidents)
    total_cost = sum(i -> get(i.metadata, "execution_cost", 0.0), incidents)
    total_value_saved = sum(i -> i.position_value_usd, incidents)
    
    return total_value_saved > 0 ? total_cost / total_value_saved : 0.0
end

function calculate_risk_score(user, positions, incidents)
    # Simple risk scoring algorithm
    score = 0.0
    
    # Position risk factors
    active_positions = filter(p -> p.status == "active", positions)
    if !isempty(active_positions)
        avg_health = mean([p.health_factor for p in active_positions])
        score += max(0, (2.0 - avg_health) * 3.0)  # Higher score for lower health
    end
    
    # Incident history
    liquidated_count = count(i -> i.status == "liquidated", incidents)
    score += liquidated_count * 1.5
    
    # Diversification penalty
    if length(unique([p.protocol for p in positions])) < 2
        score += 2.0
    end
    
    return min(score, 10.0)  # Cap at 10
end

function categorize_risk_level(user, positions)
    risk_score = calculate_risk_score(user, positions, [])
    
    if risk_score < 3.0
        return "low"
    elseif risk_score < 6.0
        return "medium"
    else
        return "high"
    end
end

function assess_diversification(positions)
    score = calculate_diversification_score(positions)
    
    if score > 0.7
        return "well_diversified"
    elseif score > 0.4
        return "moderately_diversified"
    else
        return "concentrated"
    end
end

function assess_experience_level(user, positions, incidents)
    days_active = Dates.value(now() - user.created_at) ÷ 86400000
    total_incidents = length(incidents)
    
    if days_active > 180 && total_incidents > 5
        return "experienced"
    elseif days_active > 30 && total_incidents > 0
        return "intermediate"
    else
        return "beginner"
    end
end

function assess_protection_dependency(incidents)
    protected_count = count(i -> i.status == "protected", incidents)
    total_count = length(incidents)
    
    if total_count == 0
        return "unknown"
    end
    
    protection_rate = protected_count / total_count
    
    if protection_rate > 0.8
        return "high_dependency"
    elseif protection_rate > 0.5
        return "moderate_dependency"
    else
        return "low_dependency"
    end
end

function recommend_risk_settings(user, positions)
    risk_level = categorize_risk_level(user, positions)
    
    if risk_level == "high"
        return Dict(
            "health_factor_threshold" => 2.0,
            "max_position_size" => 0.2,
            "diversification_requirement" => 3
        )
    elseif risk_level == "medium"
        return Dict(
            "health_factor_threshold" => 1.5,
            "max_position_size" => 0.3,
            "diversification_requirement" => 2
        )
    else
        return Dict(
            "health_factor_threshold" => 1.3,
            "max_position_size" => 0.5,
            "diversification_requirement" => 1
        )
    end
end

function analyze_incident_timeline(incident, position)
    return [
        Dict("timestamp" => incident.detected_at, "event" => "Risk detected", "details" => "Health factor below threshold"),
        Dict("timestamp" => incident.detected_at + Minute(1), "event" => "Protection plan generated", "details" => "Optimal strategy calculated"),
        Dict("timestamp" => incident.detected_at + Minute(2), "event" => "Execution started", "details" => "Blockchain transactions initiated"),
        Dict("timestamp" => incident.resolved_at, "event" => "Protection completed", "details" => "Position secured")
    ]
end

function analyze_root_causes(incident, position)
    return [
        "Market volatility caused collateral price decline",
        "High network congestion delayed protection response",
        "Insufficient collateral buffer for risk tolerance"
    ]
end

function calculate_financial_impact(incident, position)
    return Dict(
        "position_value_at_risk" => incident.position_value_usd,
        "potential_loss_avoided" => incident.position_value_usd * 0.1,  # Assume 10% liquidation penalty
        "protection_cost" => get(incident.metadata, "execution_cost", 50.0),
        "net_value_saved" => incident.position_value_usd * 0.1 - get(incident.metadata, "execution_cost", 50.0)
    )
end

function analyze_prevention_opportunities(incident, position)
    return [
        "Earlier alert threshold could provide more reaction time",
        "Automated collateral top-up could prevent manual intervention",
        "Diversification across protocols could reduce concentration risk"
    ]
end

function find_similar_incidents(incident)
    # Mock similar incidents - would query database for actual similar cases
    return [
        Dict("incident_id" => "inc_456", "similarity_score" => 0.85, "outcome" => "protected"),
        Dict("incident_id" => "inc_789", "similarity_score" => 0.72, "outcome" => "protected")
    ]
end

function generate_lessons_learned(incident, position)
    return [
        "Proactive monitoring prevented liquidation loss",
        "Quick execution time minimized market impact",
        "Diversified collateral types improved stability"
    ]
end

function analyze_agent_performance()
    # Mock agent performance data
    return Dict(
        "watcher_solana" => Dict("uptime" => 99.8, "avg_scan_time" => 2.3),
        "watcher_evm" => Dict("uptime" => 99.5, "avg_scan_time" => 3.1),
        "predictor" => Dict("accuracy" => 0.89, "avg_prediction_time" => 0.8),
        "optimizer" => Dict("success_rate" => 0.94, "avg_optimization_time" => 1.2),
        "policy_guard" => Dict("violation_detection_rate" => 0.98, "false_positive_rate" => 0.02)
    )
end

function identify_top_risks(positions)
    # Identify positions with highest risk scores
    risk_positions = [(p, calculate_position_risk_score(p)) for p in positions]
    sort!(risk_positions, by=x->x[2], rev=true)
    
    return [
        Dict(
            "position_id" => p[1].position_id,
            "risk_score" => p[2],
            "health_factor" => p[1].health_factor,
            "value_usd" => p[1].position_value_usd
        ) for p in risk_positions[1:min(5, length(risk_positions))]
    ]
end

function calculate_position_risk_score(position)
    # Simple risk scoring for position
    health_risk = max(0, (2.0 - position.health_factor) * 5.0)
    size_risk = position.position_value_usd / 100000.0  # Larger positions have more risk
    
    return health_risk + size_risk
end

function analyze_market_conditions()
    # Mock market analysis - would integrate with price feeds
    return Dict(
        "volatility_index" => 0.65,  # VIX-like metric
        "market_trend" => "bullish",
        "major_risks" => ["regulatory_uncertainty", "macro_economic_headwinds"],
        "opportunity_score" => 0.7
    )
end

end # module Reporter
