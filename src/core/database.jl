# src/core/database.jl
module Database

using Dates

export init_db, save_incident, get_user, save_user, get_position, save_position, 
       update_position, delete_position, get_policy, save_policy, update_policy,
       get_active_positions, save_incident_record, get_latest_incident

# In-memory database for testing and demo
const _DB = Dict{String, Any}(
    "users" => Dict{String, Any}(),
    "positions" => Dict{String, Any}(),
    "policies" => Dict{String, Any}(),
    "incidents" => Dict{String, Any}(),
    "config" => Dict{String, Any}()
)

function init_db(; url::AbstractString="memory://localhost")
    @info "🗄️ Initializing X-LiGo database" type="in-memory" url=url
    
    _DB["config"]["url"] = url
    _DB["config"]["initialized_at"] = Dates.now()
    _DB["config"]["type"] = "in-memory"
    
    # Create demo data
    _create_demo_data()
    
    @info "✅ Database initialized successfully" 
    return true
end

function _create_demo_data()
    # Demo users
    demo_users = [
        Dict("user_id" => "demo_user_1", "name" => "Alice DeFi", "email" => "alice@defi.com", "created_at" => Dates.now()),
        Dict("user_id" => "demo_user_2", "name" => "Bob Trader", "email" => "bob@trading.com", "created_at" => Dates.now()),
        Dict("user_id" => "demo_user_3", "name" => "Charlie LP", "email" => "charlie@lp.com", "created_at" => Dates.now())
    ]
    
    for user in demo_users
        _DB["users"][user["user_id"]] = user
    end
    
    # Demo policies
    demo_policies = [
        Dict("policy_id" => "policy_1", "user_id" => "demo_user_1", "hf_target" => 1.5, "max_cost_usd" => 1000.0),
        Dict("policy_id" => "policy_2", "user_id" => "demo_user_2", "hf_target" => 1.3, "max_cost_usd" => 500.0),
        Dict("policy_id" => "policy_3", "user_id" => "demo_user_3", "hf_target" => 1.8, "max_cost_usd" => 2000.0)
    ]
    
    for policy in demo_policies
        _DB["policies"][policy["policy_id"]] = policy
    end
    
    @info "📝 Demo data created" users=length(demo_users) policies=length(demo_policies)
end

# User operations
function save_user(user::Dict)
    user_id = user["user_id"]
    user["updated_at"] = Dates.now()
    _DB["users"][user_id] = user
    @info "👤 User saved" user_id=user_id
    return user_id
end

function get_user(user_id::String)
    return get(_DB["users"], user_id, nothing)
end

# Position operations  
function save_position(position::Dict)
    position_id = "$(position["user_id"])_$(position["chain"])_$(position["venue"])"
    position["position_id"] = position_id
    position["updated_at"] = Dates.now()
    _DB["positions"][position_id] = position
    @info "📊 Position saved" position_id=position_id
    return position_id
end

function get_position(position_id::String)
    return get(_DB["positions"], position_id, nothing)
end

function update_position(position_id::String, updates::Dict)
    if haskey(_DB["positions"], position_id)
        for (k, v) in updates
            _DB["positions"][position_id][k] = v
        end
        _DB["positions"][position_id]["updated_at"] = Dates.now()
        @info "📊 Position updated" position_id=position_id
        return true
    end
    return false
end

function delete_position(position_id::String)
    if haskey(_DB["positions"], position_id)
        delete!(_DB["positions"], position_id)
        @info "🗑️ Position deleted" position_id=position_id
        return true
    end
    return false
end

# Policy operations
function save_policy(policy::Dict)
    policy_id = policy["policy_id"]
    policy["updated_at"] = Dates.now()
    _DB["policies"][policy_id] = policy
    @info "📋 Policy saved" policy_id=policy_id
    return policy_id
end

function get_policy(policy_id::String)
    return get(_DB["policies"], policy_id, nothing)
end

function update_policy(policy_id::String, updates::Dict)
    if haskey(_DB["policies"], policy_id)
        for (k, v) in updates
            _DB["policies"][policy_id][k] = v
        end
        _DB["policies"][policy_id]["updated_at"] = Dates.now()
        @info "📋 Policy updated" policy_id=policy_id
        return true
    end
    return false
end

# Incident operations
function save_incident(incident::Dict)
    incident_id = "incident_$(length(_DB["incidents"]) + 1)_$(Dates.now().instant.periods.value)"
    incident["incident_id"] = incident_id
    incident["created_at"] = Dates.now()
    _DB["incidents"][incident_id] = incident
    @info "🚨 Incident saved" incident_id=incident_id user_id=get(incident, "user_id", "unknown")
    return incident_id
end

function get_incident(incident_id::String)
    return get(_DB["incidents"], incident_id, nothing)
end

function get_incidents_by_user(user_id::String)
    return [incident for incident in values(_DB["incidents"]) if incident["user_id"] == user_id]
end

function get_latest_incident()
    """Get the most recent incident from the database."""
    incidents = collect(values(_DB["incidents"]))
    if isempty(incidents)
        return nothing
    end
    
    # Sort by created_at timestamp (most recent first)
    sorted_incidents = sort(incidents, by = x -> get(x, "created_at", Dates.DateTime(1970)), rev=true)
    return first(sorted_incidents)
end

# Stats and reporting
function get_database_stats()
    return Dict(
        "users_count" => length(_DB["users"]),
        "positions_count" => length(_DB["positions"]),
        "policies_count" => length(_DB["policies"]), 
        "incidents_count" => length(_DB["incidents"]),
        "initialized_at" => _DB["config"]["initialized_at"],
        "type" => _DB["config"]["type"]
    )
end

function get_all_users()
    return collect(values(_DB["users"]))
end

function get_all_positions()
    return collect(values(_DB["positions"]))
end

function get_all_policies()
    return collect(values(_DB["policies"]))
end

function get_all_incidents()
    return collect(values(_DB["incidents"]))
end

# Health check
function health_check()
    return Dict(
        "status" => "healthy",
        "timestamp" => Dates.now(),
        "stats" => get_database_stats()
    )
end

# Additional stubs for agent compatibility
function get_active_positions()::Vector{Any}
    return Vector{Any}()  # empty for demo
end

function save_incident_record(incident::Dict)::Bool
    save_incident(incident)
    return true
end

end # module Database
