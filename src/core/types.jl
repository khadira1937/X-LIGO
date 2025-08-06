"""
Core data types and structures for the X-LiGo system.

Defines the main data models used throughout the application including
Users, Positions, Policies, Incidents, and Plans.
"""
module Types

using Dates
using UUIDs
using JSON

export User, Position, Policy, Incident, Plan, Action, SwarmBatch
export HealthFactor, TimeToBreachResult, OptimizationResult
export AssetAmount, VenueInfo, PriceOracle

# Basic financial types
"""
    AssetAmount

Represents an amount of a specific asset.
"""
struct AssetAmount
    mint::String          # Asset identifier (e.g., "SOL", "USDC")
    amount::Float64       # Amount in base units
    decimals::Int         # Number of decimal places
end

"""
    VenueInfo

Information about a lending/trading venue.
"""
struct VenueInfo
    chain::String         # "solana", "ethereum", etc.
    name::String          # "LENDING_X", "PERP_Y", etc.
    protocol::String      # "aave", "compound", "mango", etc.
    address::String       # Contract address or program ID
end

"""
    PriceOracle

Oracle price feed information.
"""
struct PriceOracle
    provider::String      # "pyth", "chainlink", etc.
    feed_id::String       # Oracle feed identifier
    price::Float64        # Current price
    confidence::Float64   # Price confidence interval
    last_update::DateTime # Last update timestamp
end

# User and policy types
"""
    User

Represents a user in the X-LiGo system.
"""
Base.@kwdef mutable struct User
    user_id::String = string(uuid4())
    wallets::Vector{Dict{String, String}} = []  # [{"chain": "solana", "address": "..."}]
    auto_protect::Bool = false
    policy_id::String = ""
    notifications::Dict{String, Any} = Dict(
        "email" => nothing,
        "discord_webhook" => "",
        "slack_webhook" => ""
    )
    created_at::DateTime = now()
    last_active::DateTime = now()
    total_positions::Int = 0
    total_protected::Int = 0
end

"""
    Policy

User-defined protection policy configuration.
"""
Base.@kwdef struct Policy
    policy_id::String = string(uuid4())
    user_id::String = ""
    
    # Risk thresholds
    hf_target::Float64 = 1.15           # Target health factor
    hf_critical::Float64 = 1.05         # Critical health factor threshold
    ttb_threshold_minutes::Int = 30      # Time-to-breach threshold
    
    # Spending limits
    max_daily_spend_usd::Float64 = 50.0
    max_per_incident_usd::Float64 = 20.0
    
    # Allowed venues and assets
    allowed_venues::Vector{String} = []  # ["solana:DEX_A", "ethereum:AAVE"]
    allowed_assets::Vector{String} = []  # ["SOL", "ETH", "USDC"]
    blocked_venues::Vector{String} = []
    blocked_assets::Vector{String} = []
    
    # Protection strategies
    hedge_allowed::Bool = true
    migration_allowed::Bool = false
    partial_repay_allowed::Bool = true
    collateral_add_allowed::Bool = true
    
    # Cooperative features
    coop_netting::String = "opt_in"     # "opt_in", "required", "off"
    max_batch_wait_seconds::Int = 30
    
    # Approval settings
    approval_mode::String = "auto_if_confidence_ge"  # "manual", "auto_always", "auto_if_confidence_ge"
    approval_threshold::Float64 = 0.85   # Confidence threshold for auto-approval
    
    # Advanced settings
    slippage_tolerance::Float64 = 0.005  # 0.5% slippage tolerance
    deadline_seconds::Int = 300          # Transaction deadline
    
    created_at::DateTime = now()
    updated_at::DateTime = now()
end

"""
    Position

Normalized representation of a lending position across different chains.
"""
Base.@kwdef mutable struct Position
    position_id::String = string(uuid4())
    user_id::String = ""
    
    # Position identification
    chain::String = ""              # "solana", "ethereum"
    venue::String = ""              # Venue identifier
    account_id::String = ""         # On-chain account/address
    
    # Financial data
    collateral::Vector{AssetAmount} = []
    debt::Vector{AssetAmount} = []
    health_factor::Float64 = 0.0
    liquidation_threshold::Float64 = 0.0
    
    # Oracle references
    oracle_refs::Dict{String, String} = Dict()  # asset -> oracle_id mapping
    
    # Metadata
    last_scan_ts::DateTime = now()
    last_health_update::DateTime = now()
    is_active::Bool = true
    risk_level::String = "low"      # "low", "medium", "high", "critical"
    
    # Position-specific limits (override policy)
    max_protection_spend::Float64 = 0.0  # 0 = use policy default
end

"""
    HealthFactor

Health factor calculation with breakdown.
"""
struct HealthFactor
    current::Float64
    liquidation_threshold::Float64
    collateral_value_usd::Float64
    debt_value_usd::Float64
    calculation_time::DateTime
    oracle_prices::Dict{String, Float64}  # asset -> price
end

"""
    TimeToBreachResult

Result of time-to-breach analysis.
"""
struct TimeToBreachResult
    ttb_minutes::Float64            # Expected time to breach in minutes
    breach_probability::Float64     # Probability of breach within horizon
    shock_scenarios::Vector{Float64} # Price shock scenarios tested
    critical_price_levels::Dict{String, Float64}  # asset -> critical price
    confidence::Float64             # Confidence in prediction (0-1)
    calculation_time::DateTime
end

"""
    Action

Individual action within a protection plan.
"""
Base.@kwdef struct Action
    action_type::String = ""        # "add_collateral", "repay", "hedge", "migrate"
    asset::String = ""              # Asset being acted upon
    amount::Float64 = 0.0           # Amount in base units
    venue::String = ""              # Target venue
    estimated_cost_usd::Float64 = 0.0
    estimated_gas::Float64 = 0.0
    slippage_impact::Float64 = 0.0
    route_info::Dict{String, Any} = Dict()  # Routing-specific data
end

"""
    Plan

Optimized protection plan with multiple actions.
"""
Base.@kwdef struct Plan
    plan_id::String = string(uuid4())
    incident_id::String = ""
    
    # Plan details
    actions::Vector{Action} = []
    total_cost_usd::Float64 = 0.0
    total_gas_cost::Float64 = 0.0
    
    # Expected outcomes
    hf_after::Float64 = 0.0
    risk_reduction::Float64 = 0.0   # How much risk is reduced (0-1)
    
    # Optimization metadata
    confidence::Float64 = 0.0       # Confidence in plan success (0-1)
    optimization_time_ms::Float64 = 0.0
    solver_status::String = ""      # "optimal", "feasible", "infeasible"
    
    # Cooperative netting
    can_be_netted::Bool = false
    netting_priority::Float64 = 0.0
    
    # Alternatives
    alternatives::Vector{Plan} = []  # Alternative plans (lower ranked)
    
    created_at::DateTime = now()
end

"""
    SwarmBatch

Batch of netted actions across multiple users.
"""
Base.@kwdef struct SwarmBatch
    batch_id::String = string(uuid4())
    incident_ids::Vector{String} = []
    
    # Netting results
    internal_matches::Vector{Dict{String, Any}} = []  # Internal transfers
    external_actions::Vector{Action} = []              # Remaining external actions
    
    # Cost savings
    total_cost_before::Float64 = 0.0
    total_cost_after::Float64 = 0.0
    cost_savings_usd::Float64 = 0.0
    gas_savings::Float64 = 0.0
    
    # Execution
    status::String = "pending"      # "pending", "executing", "completed", "failed"
    tx_hashes::Vector{String} = []
    
    created_at::DateTime = now()
    executed_at::Union{DateTime, Nothing} = nothing
end

"""
    Incident

A detected risk event requiring protection action.
"""
Base.@kwdef mutable struct Incident
    incident_id::String = string(uuid4())
    user_id::String = ""
    position_ids::Vector{String} = []
    
    # Risk analysis
    risk_assessment::TimeToBreachResult = TimeToBreachResult(
        ttb_minutes = 0.0,
        breach_probability = 0.0,
        shock_scenarios = [],
        critical_price_levels = Dict(),
        confidence = 0.0,
        calculation_time = now()
    )
    
    # Protection plans
    primary_plan::Union{Plan, Nothing} = nothing
    alternative_plans::Vector{Plan} = []
    
    # Status tracking
    status::String = "detected"     # "detected", "analyzing", "awaiting_approval", "executing", "completed", "failed"
    approval_status::String = "pending"  # "pending", "approved", "rejected", "auto_approved"
    
    # Execution tracking
    batch_id::String = ""           # If part of a swarm batch
    tx_hashes::Vector{String} = []
    execution_logs::Vector{String} = []
    
    # AI explanation
    explanation_short::String = ""
    explanation_detailed::String = ""
    llm_confidence::Float64 = 0.0
    
    # Timestamps
    detected_at::DateTime = now()
    approved_at::Union{DateTime, Nothing} = nothing
    executed_at::Union{DateTime, Nothing} = nothing
    completed_at::Union{DateTime, Nothing} = nothing
    
    # Metadata
    total_cost_usd::Float64 = 0.0
    cost_savings_usd::Float64 = 0.0  # From cooperative netting
    final_health_factor::Float64 = 0.0
    success::Bool = false
end

"""
    OptimizationResult

Result from the optimization engine.
"""
struct OptimizationResult
    primary_plan::Plan
    alternative_plans::Vector{Plan}
    optimization_time_ms::Float64
    solver_iterations::Int
    objective_value::Float64
    constraints_satisfied::Bool
    warnings::Vector{String}
end

# JSON serialization helpers
function Base.Dict(user::User)
    return Dict(
        "user_id" => user.user_id,
        "wallets" => user.wallets,
        "auto_protect" => user.auto_protect,
        "policy_id" => user.policy_id,
        "notifications" => user.notifications,
        "created_at" => user.created_at,
        "last_active" => user.last_active,
        "total_positions" => user.total_positions,
        "total_protected" => user.total_protected
    )
end

function Base.Dict(position::Position)
    return Dict(
        "position_id" => position.position_id,
        "user_id" => position.user_id,
        "chain" => position.chain,
        "venue" => position.venue,
        "account_id" => position.account_id,
        "collateral" => [Dict("mint" => c.mint, "amount" => c.amount, "decimals" => c.decimals) for c in position.collateral],
        "debt" => [Dict("mint" => d.mint, "amount" => d.amount, "decimals" => d.decimals) for d in position.debt],
        "health_factor" => position.health_factor,
        "liquidation_threshold" => position.liquidation_threshold,
        "oracle_refs" => position.oracle_refs,
        "last_scan_ts" => position.last_scan_ts,
        "last_health_update" => position.last_health_update,
        "is_active" => position.is_active,
        "risk_level" => position.risk_level,
        "max_protection_spend" => position.max_protection_spend
    )
end

function Base.Dict(incident::Incident)
    return Dict(
        "incident_id" => incident.incident_id,
        "user_id" => incident.user_id,
        "position_ids" => incident.position_ids,
        "status" => incident.status,
        "approval_status" => incident.approval_status,
        "explanation_short" => incident.explanation_short,
        "total_cost_usd" => incident.total_cost_usd,
        "cost_savings_usd" => incident.cost_savings_usd,
        "final_health_factor" => incident.final_health_factor,
        "detected_at" => incident.detected_at,
        "success" => incident.success
    )
end

end # module Types
