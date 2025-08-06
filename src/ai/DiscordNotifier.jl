"""
DiscordNotifier Module

Sends real-time security alerts to Discord webhooks when critical incidents are detected.
Formats rich embeds with incident details, severity levels, and actionable information.
"""
module DiscordNotifier

using HTTP
using JSON3
using Dates
using ..IncidentStore

export send_discord_alert, test_discord_connection

"""
Send a Discord alert for a security incident.

# Arguments
- `incident::IncidentStore.Incident`: The incident to alert about

# Returns
- `Dict{String, Any}`: Response with success status and details
"""
function send_discord_alert(incident::IncidentStore.Incident)::Dict{String, Any}
    webhook_url = get(ENV, "DISCORD_WEBHOOK_URL", "")
    
    if isempty(webhook_url)
        @warn "DISCORD_WEBHOOK_URL not configured, skipping Discord alert"
        return Dict("success" => false, "reason" => "webhook_not_configured")
    end
    
    try
        # Build Discord embed payload
        embed = build_incident_embed(incident)
        payload = Dict(
            "embeds" => [embed],
            "username" => "X-LiGo Security Bot",
            "avatar_url" => "https://cdn.discordapp.com/attachments/placeholder/xligo-bot-avatar.png"
        )
        
        # Send HTTP POST to Discord webhook
        headers = ["Content-Type" => "application/json"]
        response = HTTP.post(webhook_url, headers, JSON3.write(payload))
        
        if response.status == 204  # Discord webhook success
            @info "Discord alert sent successfully" incident_id=incident.user_id severity=incident.severity
            return Dict(
                "success" => true,
                "status" => response.status,
                "incident_id" => incident.user_id,
                "timestamp" => now()
            )
        else
            @error "Discord webhook failed" status=response.status
            return Dict("success" => false, "status" => response.status)
        end
        
    catch e
        @error "Failed to send Discord alert" error=e
        return Dict("success" => false, "error" => string(e))
    end
end

"""
Build a rich Discord embed for an incident.
"""
function build_incident_embed(incident::IncidentStore.Incident)::Dict{String, Any}
    # Color coding based on severity
    color = get_severity_color(incident.severity)
    
    # Main embed structure
    embed = Dict{String, Any}(
        "title" => "🚨 Security Incident Detected",
        "description" => "**$(get(incident.metadata, "attack_type", "Health Factor Violation"))** - $(incident.severity) severity",
        "color" => color,
        "timestamp" => Dates.format(incident.timestamp, "yyyy-mm-ddTHH:MM:SS.sssZ"),
        "footer" => Dict(
            "text" => "X-LiGo DeFi Protection System",
            "icon_url" => "https://cdn.discordapp.com/attachments/placeholder/xligo-footer.png"
        ),
        "fields" => []
    )
    
    # Add incident details as fields
    push!(embed["fields"], Dict(
        "name" => "👤 User",
        "value" => "`$(incident.user_id)`",
        "inline" => true
    ))
    
    push!(embed["fields"], Dict(
        "name" => "🎯 Position",
        "value" => "`$(incident.position_id)`",
        "inline" => true
    ))
    
    push!(embed["fields"], Dict(
        "name" => "💓 Health Factor",
        "value" => "**$(round(incident.health_factor, digits=3))**",
        "inline" => true
    ))
    
    # Add protocol info if available
    if !isempty(incident.protocol)
        push!(embed["fields"], Dict(
            "name" => "🏦 Protocol",
            "value" => incident.protocol,
            "inline" => true
        ))
    end
    
    # Add value at risk if available
    if haskey(incident.metadata, "value_at_risk")
        push!(embed["fields"], Dict(
            "name" => "💰 Value at Risk",
            "value" => "\$$(format_currency(incident.metadata["value_at_risk"]))",
            "inline" => true
        ))
    end
    
    # Add attack type analysis
    attack_analysis = analyze_attack_type(incident)
    if !isempty(attack_analysis)
        push!(embed["fields"], Dict(
            "name" => "🔍 Attack Analysis",
            "value" => attack_analysis,
            "inline" => false
        ))
    end
    
    # Add recommended actions
    actions = get_recommended_actions(incident)
    if !isempty(actions)
        push!(embed["fields"], Dict(
            "name" => "⚡ Recommended Actions",
            "value" => actions,
            "inline" => false
        ))
    end
    
    # Add urgency indicator for critical incidents
    if incident.severity == "CRITICAL"
        embed["description"] = "🔴 **CRITICAL ALERT** - " * embed["description"]
        
        # Add alert mention for critical incidents
        if haskey(incident.metadata, "alert_role")
            embed["content"] = "<@&$(incident.metadata["alert_role"])> Critical DeFi security incident!"
        end
    end
    
    return embed
end

"""
Get Discord color code based on severity.
"""
function get_severity_color(severity::String)::Int
    severity_colors = Dict(
        "CRITICAL" => 0xFF0000,  # Red
        "HIGH" => 0xFF8C00,      # Dark Orange
        "MEDIUM" => 0xFFD700,    # Gold
        "LOW" => 0x32CD32,       # Lime Green
        "INFO" => 0x87CEEB       # Sky Blue
    )
    
    return get(severity_colors, severity, 0x808080)  # Gray for unknown
end

"""
Analyze attack type based on incident data.
"""
function analyze_attack_type(incident::IncidentStore.Incident)::String
    analysis = ""
    
    # Health factor based analysis
    if incident.health_factor < 1.05
        analysis *= "🔴 **Imminent Liquidation Risk**\n"
    elseif incident.health_factor < 1.2
        analysis *= "🟠 **High Liquidation Risk**\n"
    end
    
    # Metadata-based analysis
    if haskey(incident.metadata, "large_transaction") && incident.metadata["large_transaction"]
        analysis *= "⚡ **Large Transaction Detected** - Possible flash loan attack\n"
    end
    
    if haskey(incident.metadata, "rapid_price_change") && incident.metadata["rapid_price_change"]
        analysis *= "📈 **Rapid Price Movement** - Possible oracle manipulation\n"
    end
    
    if haskey(incident.metadata, "bot_behavior") && incident.metadata["bot_behavior"]
        analysis *= "🤖 **Bot Activity Detected** - Automated attack pattern\n"
    end
    
    if haskey(incident.metadata, "mev_detected") && incident.metadata["mev_detected"]
        analysis *= "🎯 **MEV Activity** - Sandwich/frontrunning detected\n"
    end
    
    # Pattern-based analysis
    incident_type = get(incident.metadata, "attack_type", "health_factor_violation")
    if incident_type == "health_factor_violation"
        if incident.health_factor < 1.1
            analysis *= "⚠️ **Liquidation Attack Vector** - Position vulnerable\n"
        end
    end
    
    return isempty(analysis) ? "Standard health factor monitoring alert" : strip(analysis)
end

"""
Get recommended actions based on incident severity and type.
"""
function get_recommended_actions(incident::IncidentStore.Incident)::String
    actions = ""
    
    if incident.severity == "CRITICAL"
        actions *= "🚨 **IMMEDIATE:**\n"
        actions *= "• Add collateral to increase health factor\n"
        actions *= "• Consider partial repayment\n"
        actions *= "• Monitor position closely\n"
    elseif incident.severity == "HIGH"
        actions *= "⚠️ **URGENT:**\n"
        actions *= "• Review position safety\n"
        actions *= "• Consider risk reduction\n"
        actions *= "• Set closer monitoring alerts\n"
    else
        actions *= "ℹ️ **RECOMMENDED:**\n"
        actions *= "• Monitor market conditions\n"
        actions *= "• Review risk parameters\n"
        actions *= "• Stay informed of protocol changes\n"
    end
    
    # Add protocol-specific actions
    if !isempty(incident.protocol)
        protocol = incident.protocol
        if protocol == "aave"
            actions *= "• Check Aave governance proposals\n"
        elseif protocol == "solend"
            actions *= "• Monitor Solana network congestion\n"
        end
    end
    
    return actions
end

"""
Format currency values for display.
"""
function format_currency(value::Union{Float64, Int})::String
    if value >= 1_000_000
        return "$(round(value / 1_000_000, digits=2))M"
    elseif value >= 1_000
        return "$(round(value / 1_000, digits=1))K"
    else
        return "$(round(value, digits=2))"
    end
end

"""
Test Discord webhook connectivity.
"""
function test_discord_connection()::Dict{String, Any}
    webhook_url = get(ENV, "DISCORD_WEBHOOK_URL", "")
    
    if isempty(webhook_url)
        return Dict("success" => false, "reason" => "webhook_not_configured")
    end
    
    try
        # Send test message
        test_embed = Dict(
            "title" => "🧪 X-LiGo Test Alert",
            "description" => "Discord integration test successful!",
            "color" => 0x00FF00,  # Green
            "timestamp" => Dates.format(now(), "yyyy-mm-ddTHH:MM:SS.sssZ"),
            "fields" => [
                Dict(
                    "name" => "Status",
                    "value" => "✅ All systems operational",
                    "inline" => true
                ),
                Dict(
                    "name" => "Test Time",
                    "value" => Dates.format(now(), "HH:MM:SS"),
                    "inline" => true
                )
            ],
            "footer" => Dict(
                "text" => "X-LiGo DeFi Protection System - Test Mode"
            )
        )
        
        payload = Dict(
            "embeds" => [test_embed],
            "username" => "X-LiGo Security Bot (Test)",
            "content" => "🔧 **System Test** - Discord webhook integration verified"
        )
        
        headers = ["Content-Type" => "application/json"]
        response = HTTP.post(webhook_url, headers, JSON3.write(payload))
        
        if response.status == 204
            @info "Discord test alert sent successfully"
            return Dict(
                "success" => true,
                "status" => response.status,
                "message" => "Discord webhook test successful"
            )
        else
            return Dict("success" => false, "status" => response.status)
        end
        
    catch e
        @error "Discord test failed" error=e
        return Dict("success" => false, "error" => string(e))
    end
end

"""
Send batch alerts for multiple incidents.
"""
function send_batch_discord_alerts(incidents::Vector{IncidentStore.Incident})::Dict{String, Any}
    if length(incidents) == 1
        return send_discord_alert(incidents[1])
    end
    
    webhook_url = get(ENV, "DISCORD_WEBHOOK_URL", "")
    
    if isempty(webhook_url)
        return Dict("success" => false, "reason" => "webhook_not_configured")
    end
    
    try
        # Create summary embed for multiple incidents
        embed = Dict{String, Any}(
            "title" => "⚠️ Multiple Security Incidents",
            "description" => "**$(length(incidents)) incidents** detected in rapid succession",
            "color" => 0xFF4500,  # Orange Red
            "timestamp" => Dates.format(now(), "yyyy-mm-ddTHH:MM:SS.sssZ"),
            "fields" => []
        )
        
        # Add summary statistics
        critical_count = count(inc -> inc.severity == "CRITICAL", incidents)
        high_count = count(inc -> inc.severity == "HIGH", incidents)
        
        push!(embed["fields"], Dict(
            "name" => "📊 Severity Breakdown",
            "value" => "Critical: $critical_count\nHigh: $high_count\nOther: $(length(incidents) - critical_count - high_count)",
            "inline" => true
        ))
        
        # Add affected users
        unique_users = unique([inc.user_id for inc in incidents])
        push!(embed["fields"], Dict(
            "name" => "👥 Affected Users",
            "value" => "$(length(unique_users)) users",
            "inline" => true
        ))
        
        # Add most critical incident details
        most_critical = incidents[1]  # Assuming sorted by severity
        incident_type = get(most_critical.metadata, "attack_type", "health_factor_violation")
        push!(embed["fields"], Dict(
            "name" => "🔴 Most Critical",
            "value" => "$(incident_type)\nHF: $(round(most_critical.health_factor, digits=3))\nUser: `$(most_critical.user_id)`",
            "inline" => false
        ))
        
        payload = Dict(
            "embeds" => [embed],
            "username" => "X-LiGo Security Bot",
            "content" => "🚨 **MASS INCIDENT ALERT** - Multiple security events detected!"
        )
        
        headers = ["Content-Type" => "application/json"]
        response = HTTP.post(webhook_url, headers, JSON3.write(payload))
        
        if response.status == 204
            @info "Discord batch alert sent successfully" incident_count=length(incidents)
            return Dict(
                "success" => true,
                "status" => response.status,
                "incidents_count" => length(incidents)
            )
        else
            return Dict("success" => false, "status" => response.status)
        end
        
    catch e
        @error "Failed to send Discord batch alert" error=e
        return Dict("success" => false, "error" => string(e))
    end
end

end # module DiscordNotifier
