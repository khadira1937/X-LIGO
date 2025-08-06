"""
Swarm Coordinator

Central coordination hub for all X-LiGo agents.
Manages agent lifecycle, health monitoring, task distribution, and event routing.
"""
module Coordinator

using Dates
using JSON
using Logging

# Import all agents
# using ..WatcherSolana
# using ..WatcherEVM
using ..Predictor
using ..Optimizer
using ..AnalystLLM
using ..PolicyGuard
# using ..ActionerSolana
# using ..ActionerEVM
using ..Reporter

# Import core modules
using ..Types
using ..Database
using ..Config

export start_swarm, stop_swarm, get_swarm_status, process_risk_event, handle_incident, get_latest_security_incident

# Global variable to track the latest security incident for chat endpoint
const LATEST_SECURITY_INCIDENT = Ref{Union{Nothing, Dict{String, Any}}}(nothing)

# Swarm state
mutable struct SwarmState
    running::Bool
    agents::Dict{String, Any}
    agent_health::Dict{String, Any}
    config::Any
    event_queue::Vector{Any}
    processing_queue::Vector{Any}
    metrics::Dict{String, Any}
    last_health_check::DateTime
end

const SWARM_STATE = Ref{Union{Nothing, SwarmState}}(nothing)

"""
    start_swarm(config=nothing)

Initialize and start the entire agent swarm.
"""
function start_swarm(config=nothing)
    @info "🚀 Starting X-LiGo Agent Swarm..."
    
    try
        # Load configuration
        swarm_config = config !== nothing ? config : Config.load_config()
        
        # Initialize swarm state
        SWARM_STATE[] = SwarmState(
            running = false,
            agents = Dict{String, Any}(),
            agent_health = Dict{String, Any}(),
            config = swarm_config,
            event_queue = Vector{Any}(),
            processing_queue = Vector{Any}(),
            metrics = Dict{String, Any}(
                "events_processed" => 0,
                "incidents_handled" => 0,
                "protections_executed" => 0,
                "start_time" => now()
            ),
            last_health_check = now()
        )
        
        state = SWARM_STATE[]
        
        @info "🔧 Initializing agents..."
        
        # Start all agents in order
        agents_to_start = [
            # ("watcher_solana", WatcherSolana),
            # ("watcher_evm", WatcherEVM),
            ("predictor", Predictor),
            ("optimizer", Optimizer),
            ("analyst_llm", AnalystLLM),
            ("policy_guard", PolicyGuard),
            # ("actioner_solana", ActionerSolana),
            # ("actioner_evm", ActionerEVM),
            ("reporter", Reporter)
        ]
        
        successful_agents = String[]
        failed_agents = String[]
        
        for (agent_name, agent_module) in agents_to_start
            try
                @info "Starting $agent_name..."
                agent = agent_module.start(swarm_config)
                state.agents[agent_name] = agent
                state.agent_health[agent_name] = agent_module.health()
                push!(successful_agents, agent_name)
                @info "✅ $agent_name started successfully"
            catch e
                @error "❌ Failed to start $agent_name: $e"
                push!(failed_agents, agent_name)
                state.agent_health[agent_name] = Dict("status" => "failed", "error" => string(e))
            end
        end
        
        # Check if minimum required agents are running
        required_agents = ["watcher_solana", "predictor", "optimizer", "actioner_solana"]
        running_required = count(agent -> agent in successful_agents, required_agents)
        
        if running_required < length(required_agents)
            @warn "⚠️ Not all required agents started successfully"
            @warn "Required: $required_agents"
            @warn "Failed: $failed_agents"
        end
        
        state.running = true
        
        @info "🌟 X-LiGo Agent Swarm started successfully!"
        @info "📊 Agents running: $(length(successful_agents))/$(length(agents_to_start))"
        @info "🎯 Ready to protect DeFi positions"
        
        # Start background monitoring
        start_health_monitoring()
        start_event_processing()
        
        return Dict(
            "success" => true,
            "agents_started" => successful_agents,
            "agents_failed" => failed_agents,
            "total_agents" => length(successful_agents),
            "swarm_status" => "running"
        )
        
    catch e
        @error "💥 Failed to start swarm: $e"
        if SWARM_STATE[] !== nothing
            SWARM_STATE[].running = false
        end
        rethrow(e)
    end
end

"""
    stop_swarm()

Gracefully stop all agents in the swarm.
"""
function stop_swarm()
    if SWARM_STATE[] === nothing
        @warn "Swarm not initialized"
        return
    end
    
    state = SWARM_STATE[]
    
    @info "🛑 Stopping X-LiGo Agent Swarm..."
    
    # Stop all agents
    for (agent_name, agent) in state.agents
        try
            @info "Stopping $agent_name..."
            
            # Call agent's stop method
            if hasfield(typeof(agent), :state) && hasmethod(stop, Tuple{typeof(agent)})
                stop(agent)
            else
                # Fallback to module stop function
                agent_module = if agent_name == "watcher_solana"
                    # WatcherSolana
                    nothing
                elseif agent_name == "watcher_evm"
                    # WatcherEVM
                    nothing
                elseif agent_name == "predictor"
                    Predictor
                elseif agent_name == "optimizer"
                    Optimizer
                elseif agent_name == "analyst_llm"
                    AnalystLLM
                elseif agent_name == "policy_guard"
                    PolicyGuard
                elseif agent_name == "actioner_solana"
                    ActionerSolana
                elseif agent_name == "actioner_evm"
                    ActionerEVM
                elseif agent_name == "reporter"
                    Reporter
                end
                
                if agent_module !== nothing
                    agent_module.stop()
                end
            end
            
            @info "✅ $agent_name stopped"
            
        catch e
            @error "❌ Error stopping $agent_name: $e"
        end
    end
    
    state.running = false
    empty!(state.agents)
    empty!(state.agent_health)
    
    @info "🏁 X-LiGo Agent Swarm stopped"
end

"""
    get_swarm_status()

Get comprehensive status of the entire swarm.
"""
function get_swarm_status()
    if SWARM_STATE[] === nothing
        return Dict("status" => "not_initialized")
    end
    
    state = SWARM_STATE[]
    
    # Refresh agent health
    refresh_agent_health()
    
    # Calculate uptime
    uptime_seconds = Dates.value(now() - state.metrics["start_time"]) ÷ 1000
    
    # Agent summary
    total_agents = length(state.agents)
    healthy_agents = count(health -> get(health, "status", "") == "running", values(state.agent_health))
    
    return Dict(
        "swarm_status" => state.running ? "running" : "stopped",
        "uptime_seconds" => uptime_seconds,
        "agents" => Dict(
            "total" => total_agents,
            "healthy" => healthy_agents,
            "unhealthy" => total_agents - healthy_agents,
            "health_details" => state.agent_health
        ),
        "metrics" => state.metrics,
        "event_queue_size" => length(state.event_queue),
        "processing_queue_size" => length(state.processing_queue),
        "last_health_check" => state.last_health_check
    )
end

"""
    process_risk_event(event::Dict)

Process incoming risk events through the agent pipeline.
"""
function process_risk_event(event::Dict)
    if SWARM_STATE[] === nothing
        error("Swarm not initialized")
    end
    
    state = SWARM_STATE[]
    
    @info "🚨 Processing risk event: $(get(event, "event_type", "unknown"))"
    
    try
        # Add event to queue
        push!(state.event_queue, event)
        
        # Create incident record
        incident = Incident(
            incident_id = "inc_" * string(rand(UInt32), base=16),
            position_id = event["position_id"],
            incident_type = get(event, "event_type", "risk_detected"),
            severity = get(event, "severity", "medium"),
            status = "detected",
            detected_at = now(),
            resolved_at = nothing,
            position_value_usd = get(event, "position_value_usd", 0.0),
            metadata = event
        )
        
        # Save incident
        Database.save_incident(incident)
        
        # Process through pipeline
        result = process_incident_pipeline(incident)
        
        state.metrics["events_processed"] += 1
        
        return result
        
    catch e
        @error "❌ Failed to process risk event: $e"
        return Dict("success" => false, "error" => string(e))
    end
end

"""
    handle_incident(incident::Incident)

Handle a specific incident through the full protection pipeline.
"""
function handle_incident(incident::Incident)
    if SWARM_STATE[] === nothing
        error("Swarm not initialized")
    end
    
    state = SWARM_STATE[]
    
    @info "🛡️ Handling incident: $(incident.incident_id)"
    
    try
        # Get position details
        position = Database.get_position(incident.position_id)
        if position === nothing
            error("Position not found: $(incident.position_id)")
        end
        
        # Check policy compliance
        if haskey(state.agents, "policy_guard")
            policy_result = PolicyGuard.validate_incident(incident, position)
            if !policy_result["allowed"]
                @warn "⚠️ Policy violation detected: $(policy_result["reason"])"
                incident.status = "policy_blocked"
                Database.save_incident(incident)
                return Dict("success" => false, "reason" => "policy_violation", "details" => policy_result)
            end
        end
        
        # Risk prediction
        prediction_result = nothing
        if haskey(state.agents, "predictor")
            prediction_result = Predictor.predict_liquidation_risk(position)
            @info "🔮 Risk prediction: $(prediction_result["risk_level"])"
        end
        
        # Generate protection plan
        plan_result = nothing
        if haskey(state.agents, "optimizer")
            plan_result = Optimizer.optimize_protection_plan(position, incident)
            @info "🎯 Protection plan generated: $(length(plan_result["actions"])) actions"
        end
        
        if plan_result === nothing || !plan_result["success"]
            error("Failed to generate protection plan")
        end
        
        # Execute protection actions
        execution_result = execute_protection_plan(plan_result["plan"], position)
        
        # Update incident status
        if execution_result["success"]
            incident.status = "protected"
            incident.resolved_at = now()
            state.metrics["protections_executed"] += 1
        else
            incident.status = "failed"
            incident.resolved_at = now()
        end
        
        # Add execution details to incident metadata
        incident.metadata["execution_result"] = execution_result
        incident.metadata["prediction_result"] = prediction_result
        incident.metadata["plan_result"] = plan_result
        
        Database.save_incident(incident)
        
        # Generate incident explanation
        if haskey(state.agents, "analyst_llm")
            try
                explanation = AnalystLLM.explain_incident(incident, position)
                incident.metadata["explanation"] = explanation
                Database.save_incident(incident)
            catch e
                @warn "Failed to generate explanation: $e"
            end
        end
        
        # Generate incident report and send Discord notification
        if haskey(state.agents, "reporter")
            try
                Reporter.generate_incident_report(incident)
                @info "📊 Incident report generated and Discord notification sent"
            catch e
                @warn "Failed to generate incident report: $e"
            end
        end
        
        # Track security incidents for chat endpoint
        if incident.incident_type in ["liquidation_risk", "flash_loan_attack", "sandwich_attack", "governance_attack", "price_manipulation", "suspicious_transaction"]
            # Convert incident to dictionary for storage
            incident_dict = Dict(
                "incident_id" => incident.incident_id,
                "incident_type" => incident.incident_type,
                "severity" => incident.severity,
                "status" => incident.status,
                "detected_at" => incident.detected_at,
                "resolved_at" => incident.resolved_at,
                "position_value_usd" => incident.position_value_usd,
                "position_id" => incident.position_id,
                "metadata" => incident.metadata
            )
            LATEST_SECURITY_INCIDENT[] = incident_dict
            @info "🔍 Latest security incident tracked for chat endpoint: $(incident.incident_id)"
        end
        
        state.metrics["incidents_handled"] += 1
        
        @info "✅ Incident handled successfully: $(incident.status)"
        
        return Dict(
            "success" => true,
            "incident_id" => incident.incident_id,
            "status" => incident.status,
            "execution_result" => execution_result,
            "protection_cost" => get(execution_result, "total_cost", 0.0)
        )
        
    catch e
        @error "❌ Failed to handle incident: $e"
        
        # Update incident with error
        incident.status = "error"
        incident.resolved_at = now()
        incident.metadata["error"] = string(e)
        Database.save_incident(incident)
        
        return Dict("success" => false, "error" => string(e))
    end
end

"""
    process_incident_pipeline(incident::Incident)

Process incident through the complete agent pipeline.
"""
function process_incident_pipeline(incident::Incident)
    pipeline_stages = [
        ("policy_check", check_policy_compliance),
        ("risk_prediction", predict_risk),
        ("plan_optimization", optimize_plan),
        ("plan_execution", execute_plan),
        ("incident_analysis", analyze_incident)
    ]
    
    results = Dict{String, Any}()
    
    for (stage_name, stage_function) in pipeline_stages
        try
            @info "Pipeline stage: $stage_name"
            stage_result = stage_function(incident)
            results[stage_name] = stage_result
            
            # Check if stage failed and should stop pipeline
            if !get(stage_result, "success", true)
                @warn "Pipeline stopped at stage: $stage_name"
                break
            end
            
        catch e
            @error "Pipeline stage failed: $stage_name - $e"
            results[stage_name] = Dict("success" => false, "error" => string(e))
            break
        end
    end
    
    return Dict(
        "success" => all(get(result, "success", false) for result in values(results)),
        "pipeline_results" => results,
        "incident_id" => incident.incident_id
    )
end

"""
    execute_protection_plan(plan, position)

Execute the protection plan using appropriate actioner agents.
"""
function execute_protection_plan(plan, position)
    if SWARM_STATE[] === nothing
        error("Swarm not initialized")
    end
    
    state = SWARM_STATE[]
    
    # Determine which actioner to use based on blockchain
    actioner_name = if position.blockchain == "solana"
        "actioner_solana"
    else
        "actioner_evm"
    end
    
    if !haskey(state.agents, actioner_name)
        error("Required actioner not available: $actioner_name")
    end
    
    # Execute plan
    if actioner_name == "actioner_solana"
        return ActionerSolana.execute_plan(plan, position)
    else
        return ActionerEVM.execute_plan(plan, position)
    end
end

# Pipeline stage functions
function check_policy_compliance(incident::Incident)
    if SWARM_STATE[] === nothing || !haskey(SWARM_STATE[].agents, "policy_guard")
        return Dict("success" => true, "message" => "Policy guard not available")
    end
    
    position = Database.get_position(incident.position_id)
    return PolicyGuard.validate_incident(incident, position)
end

function predict_risk(incident::Incident)
    if SWARM_STATE[] === nothing || !haskey(SWARM_STATE[].agents, "predictor")
        return Dict("success" => true, "message" => "Predictor not available")
    end
    
    position = Database.get_position(incident.position_id)
    return Predictor.predict_liquidation_risk(position)
end

function optimize_plan(incident::Incident)
    if SWARM_STATE[] === nothing || !haskey(SWARM_STATE[].agents, "optimizer")
        return Dict("success" => false, "error" => "Optimizer not available")
    end
    
    position = Database.get_position(incident.position_id)
    return Optimizer.optimize_protection_plan(position, incident)
end

function execute_plan(incident::Incident)
    position = Database.get_position(incident.position_id)
    
    # Get the optimized plan from metadata
    plan_result = get(incident.metadata, "plan_result", nothing)
    if plan_result === nothing
        return Dict("success" => false, "error" => "No plan available")
    end
    
    return execute_protection_plan(plan_result["plan"], position)
end

function analyze_incident(incident::Incident)
    if SWARM_STATE[] === nothing || !haskey(SWARM_STATE[].agents, "analyst_llm")
        return Dict("success" => true, "message" => "Analyst not available")
    end
    
    position = Database.get_position(incident.position_id)
    return AnalystLLM.explain_incident(incident, position)
end

# Background monitoring functions
function start_health_monitoring()
    # In a real implementation, this would start a background task
    # For now, we'll just update the timestamp
    if SWARM_STATE[] !== nothing
        SWARM_STATE[].last_health_check = now()
    end
end

function start_event_processing()
    # In a real implementation, this would start a background task
    # to process events from the queue
    @info "📡 Event processing started"
end

function refresh_agent_health()
    if SWARM_STATE[] === nothing
        return
    end
    
    state = SWARM_STATE[]
    
    # Update health status for all agents
    for (agent_name, agent) in state.agents
        try
            # Get health from appropriate module
            health_result = if agent_name == "watcher_solana"
                # WatcherSolana.health()
                Dict("status" => "disabled", "message" => "Module temporarily disabled")
            elseif agent_name == "watcher_evm"
                # WatcherEVM.health()
                Dict("status" => "disabled", "message" => "Module temporarily disabled")
            elseif agent_name == "predictor"
                Predictor.health()
            elseif agent_name == "optimizer"
                Optimizer.health()
            elseif agent_name == "analyst_llm"
                AnalystLLM.health()
            elseif agent_name == "policy_guard"
                PolicyGuard.health()
            elseif agent_name == "actioner_solana"
                ActionerSolana.health()
            elseif agent_name == "actioner_evm"
                ActionerEVM.health()
            elseif agent_name == "reporter"
                Reporter.health()
            else
                Dict("status" => "unknown")
            end
            
            state.agent_health[agent_name] = health_result
            
        catch e
            state.agent_health[agent_name] = Dict("status" => "error", "error" => string(e))
        end
    end
    
    state.last_health_check = now()
end

"""
    restart_failed_agents()

Attempt to restart any failed agents.
"""
function restart_failed_agents()
    if SWARM_STATE[] === nothing
        return
    end
    
    refresh_agent_health()
    
    state = SWARM_STATE[]
    
    for (agent_name, health) in state.agent_health
        if get(health, "status", "") in ["error", "failed", "stopped"]
            @info "🔄 Attempting to restart failed agent: $agent_name"
            
            try
                # Stop existing agent if needed
                if haskey(state.agents, agent_name)
                    delete!(state.agents, agent_name)
                end
                
                # Restart agent
                agent_module = get_agent_module(agent_name)
                if agent_module !== nothing
                    agent = agent_module.start(state.config)
                    state.agents[agent_name] = agent
                    @info "✅ Successfully restarted: $agent_name"
                end
                
            catch e
                @error "❌ Failed to restart $agent_name: $e"
            end
        end
    end
end

function get_agent_module(agent_name::String)
    module_map = Dict(
        # "watcher_solana" => WatcherSolana,
        # "watcher_evm" => WatcherEVM,
        "predictor" => Predictor,
        "optimizer" => Optimizer,
        "analyst_llm" => AnalystLLM,
        "policy_guard" => PolicyGuard,
        "actioner_solana" => ActionerSolana,
        "actioner_evm" => ActionerEVM,
        "reporter" => Reporter
    )
    
    return get(module_map, agent_name, nothing)
end

"""
    get_latest_security_incident()

Get the most recent security incident for chat endpoint queries.
"""
function get_latest_security_incident()
    # First try the global variable
    if LATEST_SECURITY_INCIDENT[] !== nothing
        return LATEST_SECURITY_INCIDENT[]
    end
    
    # Fallback to database
    try
        return Database.get_latest_incident()
    catch e
        @warn "Failed to get latest incident from database: $e"
        return nothing
    end
end

end # module Coordinator
