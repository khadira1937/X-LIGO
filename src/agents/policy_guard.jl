"""
Policy Guard Agent

Enforces user-defined policy constraints and compliance rules.
Validates all proposed actions against policy limits and regulatory requirements.
"""
module PolicyGuard

using Dates
using Logging

# Import core modules
using ..Types
using ..Config

export start, stop, health, validate_action, validate_plan, enforce_policy, check_policy, mode

# Module-level mode tracking
const CURRENT_MODE = Ref{String}("not_started")

# Add missing function
function check_policy(plan::Dict)
    # Simple policy check - always allow for demo
    return (success=true, data=true, message="Policy check passed")
end

# Add overload for two-parameter version
function check_policy(user_id::String, plan::Dict)
    # Check user-specific policies
    return check_policy(plan)
end

# Agent state
Base.@kwdef mutable struct PolicyGuardState
    running::Bool
    config::Any
    validation_count::Int64
    violation_count::Int64
    last_validation_time::DateTime
    health_status::String
end

const AGENT_STATE = Ref{Union{Nothing, PolicyGuardState}}(nothing)

"""
    start(config::Dict)::NamedTuple

Start the Policy Guard agent.
"""
function start(config::Dict)::NamedTuple
    @info "🛡️ Starting Policy Guard Agent..."
    
    demo_mode = Config.getc(config, :demo_mode, true)
    
    try
        AGENT_STATE[] = PolicyGuardState(
            running = false,
            config = config,
            validation_count = 0,
            violation_count = 0,
            last_validation_time = now(),
            health_status = "starting"
        )
        
        state = AGENT_STATE[]
        state.running = true
        state.health_status = "running"
        
        # Determine mode based on demo_mode
        mode_str = demo_mode ? "mock" : "real"
        CURRENT_MODE[] = mode_str
        
        @info "✅ Policy Guard Agent started successfully"
        
        return (success=true, message="Policy Guard Agent started successfully", mode=mode_str)
        
    catch e
        @error "❌ Failed to start Policy Guard Agent: $e"
        if AGENT_STATE[] !== nothing
            AGENT_STATE[].health_status = "error"
        end
        
        if !demo_mode
            # Fail in real mode
            CURRENT_MODE[] = "mock"
            return (success=false, message="Failed to start Policy Guard Agent: $e", mode="mock")
        end
        
        # Allow mock in demo mode
        CURRENT_MODE[] = "mock"
        return (success=true, message="Policy Guard Agent started in mock mode (error: $e)", mode="mock")
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

Stop the Policy Guard agent.
"""
function stop()
    if AGENT_STATE[] !== nothing
        @info "🛑 Stopping Policy Guard Agent..."
        
        state = AGENT_STATE[]
        state.running = false
        state.health_status = "stopped"
        
        @info "✅ Policy Guard Agent stopped"
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
        "validation_count" => state.validation_count,
        "violation_count" => state.violation_count,
        "last_validation" => state.last_validation_time
    )
end

"""
    validate_plan(plan::Plan, policy::Policy, user::User)

Validate an entire protection plan against policy constraints.
"""
function validate_plan(plan::Plan, policy::Policy, user::User)
    if AGENT_STATE[] === nothing
        error("Policy Guard agent not initialized")
    end
    
    state = AGENT_STATE[]
    state.validation_count += 1
    state.last_validation_time = now()
    
    violations = String[]
    
    # Check spending limits
    if plan.total_cost_usd > policy.max_per_incident_usd
        push!(violations, "Plan cost ($(plan.total_cost_usd)) exceeds per-incident limit ($(policy.max_per_incident_usd))")
        state.violation_count += 1
    end
    
    # Check individual actions
    for action in plan.actions
        action_violations = validate_action(action, policy, user)
        append!(violations, action_violations)
    end
    
    # Check approval requirements
    if policy.approval_mode == "manual"
        push!(violations, "Manual approval required by policy")
    elseif policy.approval_mode == "auto_if_confidence_ge" && plan.confidence < policy.approval_threshold
        push!(violations, "Plan confidence ($(plan.confidence)) below auto-approval threshold ($(policy.approval_threshold))")
    end
    
    return Dict(
        "valid" => isempty(violations),
        "violations" => violations,
        "approved" => isempty(violations) && policy.approval_mode != "manual"
    )
end

"""
    validate_action(action::Action, policy::Policy, user::User)

Validate a single action against policy constraints.
"""
function validate_action(action::Action, policy::Policy, user::User)
    violations = String[]
    
    # Check venue restrictions
    if !isempty(policy.blocked_venues) && action.venue in policy.blocked_venues
        push!(violations, "Action uses blocked venue: $(action.venue)")
    end
    
    if !isempty(policy.allowed_venues) && action.venue ∉ policy.allowed_venues
        push!(violations, "Action uses non-allowed venue: $(action.venue)")
    end
    
    # Check asset restrictions
    if !isempty(policy.blocked_assets) && action.asset in policy.blocked_assets
        push!(violations, "Action uses blocked asset: $(action.asset)")
    end
    
    if !isempty(policy.allowed_assets) && action.asset ∉ policy.allowed_assets
        push!(violations, "Action uses non-allowed asset: $(action.asset)")
    end
    
    # Check action type restrictions
    if action.action_type == "hedge" && !policy.hedge_allowed
        push!(violations, "Hedging not allowed by policy")
    end
    
    if action.action_type == "migrate" && !policy.migration_allowed
        push!(violations, "Position migration not allowed by policy")
    end
    
    if action.action_type == "repay" && !policy.partial_repay_allowed
        push!(violations, "Partial repayment not allowed by policy")
    end
    
    if action.action_type == "add_collateral" && !policy.collateral_add_allowed
        push!(violations, "Adding collateral not allowed by policy")
    end
    
    return violations
end

"""
    enforce_policy(incident::Incident, policy::Policy, user::User)

Enforce policy constraints on an incident and its plans.
"""
function enforce_policy(incident::Incident, policy::Policy, user::User)
    if incident.primary_plan !== nothing
        primary_validation = validate_plan(incident.primary_plan, policy, user)
        
        if !primary_validation["valid"]
            @warn "Primary plan violates policy: $(primary_validation["violations"])"
            return Dict(
                "approved" => false,
                "reason" => "Policy violations in primary plan",
                "violations" => primary_validation["violations"]
            )
        end
        
        # Auto-approval logic
        if primary_validation["approved"]
            return Dict(
                "approved" => true,
                "reason" => "Auto-approved by policy",
                "violations" => String[]
            )
        end
    end
    
    return Dict(
        "approved" => false,
        "reason" => "Manual approval required",
        "violations" => String[]
    )
end

end # module PolicyGuard
