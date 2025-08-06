"""
Incident Store Module for X-LiGo
Manages security incidents and position vulnerabilities for real-time monitoring
"""
module IncidentStore

using Dates
using JSON3

export Incident, add_incident!, get_recent_incidents, get_user_incidents, clear_incidents!
export get_all_incidents, get_incident_summary

"""
Security incident structure for position vulnerabilities
"""
mutable struct Incident
    user_id::String
    position_id::String
    protocol::String
    chain::String
    severity::String  # "CRITICAL", "HIGH", "MEDIUM", "LOW"
    reason::String    # Description of the issue
    health_factor::Float64
    threshold::Float64
    collateral_token::String
    collateral_amount::Float64
    debt_token::String
    debt_amount::Float64
    timestamp::DateTime
    metadata::Dict{String, Any}  # Additional metadata for AI analysis
    
    # Constructor with metadata
    function Incident(user_id, position_id, protocol, chain, severity, reason, 
                     health_factor, threshold, collateral_token, collateral_amount, 
                     debt_token, debt_amount, timestamp, metadata=Dict{String, Any}())
        new(user_id, position_id, protocol, chain, severity, reason, 
            health_factor, threshold, collateral_token, collateral_amount, 
            debt_token, debt_amount, timestamp, metadata)
    end
end

# Global incident storage (in-memory for now)
const INCIDENT_CACHE = Dict{String, Vector{Incident}}()
const MAX_INCIDENTS_PER_USER = 100
const INCIDENT_RETENTION_HOURS = 24

"""
Add a new incident to the store
"""
function add_incident!(incident::Incident)
    user_id = incident.user_id
    
    # Initialize user's incident list if needed
    if !haskey(INCIDENT_CACHE, user_id)
        INCIDENT_CACHE[user_id] = Vector{Incident}()
    end
    
    # Add the incident
    push!(INCIDENT_CACHE[user_id], incident)
    
    # Clean up old incidents and enforce limits
    cleanup_user_incidents!(user_id)
    
    @info "Security incident recorded" user_id=user_id severity=incident.severity reason=incident.reason
    
    return incident
end

"""
Get recent incidents for a specific user
"""
function get_recent_incidents(user_id::String; hours::Int=24)::Vector{Incident}
    if !haskey(INCIDENT_CACHE, user_id)
        return Vector{Incident}()
    end
    
    cutoff_time = now() - Hour(hours)
    recent_incidents = filter(inc -> inc.timestamp >= cutoff_time, INCIDENT_CACHE[user_id])
    
    # Sort by timestamp (most recent first)
    return sort(recent_incidents, by=inc -> inc.timestamp, rev=true)
end

"""
Get recent incidents for all users (used by AI chat)
"""
function get_recent_incidents(; hours::Int=24)::Vector{Incident}
    all_incidents = Vector{Incident}()
    
    cutoff_time = now() - Hour(hours)
    
    for (user_id, incidents) in INCIDENT_CACHE
        recent_user_incidents = filter(inc -> inc.timestamp >= cutoff_time, incidents)
        append!(all_incidents, recent_user_incidents)
    end
    
    # Sort by timestamp (most recent first)
    return sort(all_incidents, by=inc -> inc.timestamp, rev=true)
end

"""
Get all incidents for a specific user (regardless of age)
"""
function get_user_incidents(user_id::String)::Vector{Incident}
    if !haskey(INCIDENT_CACHE, user_id)
        return Vector{Incident}()
    end
    
    # Sort by timestamp (most recent first)
    incidents = copy(INCIDENT_CACHE[user_id])
    sort!(incidents, by=inc -> inc.timestamp, rev=true)
    
    return incidents
end

"""
Get all incidents across all users
"""
function get_all_incidents()::Dict{String, Vector{Incident}}
    result = Dict{String, Vector{Incident}}()
    
    for (user_id, incidents) in INCIDENT_CACHE
        if !isempty(incidents)
            result[user_id] = copy(incidents)
        end
    end
    
    return result
end

"""
Get incident summary statistics
"""
function get_incident_summary()::Dict{String, Any}
    total_incidents = 0
    severity_counts = Dict("CRITICAL" => 0, "HIGH" => 0, "MEDIUM" => 0, "LOW" => 0)
    active_users = 0
    
    for (user_id, incidents) in INCIDENT_CACHE
        if !isempty(incidents)
            active_users += 1
            total_incidents += length(incidents)
            
            for incident in incidents
                severity = get(severity_counts, incident.severity, 0)
                severity_counts[incident.severity] = severity + 1
            end
        end
    end
    
    return Dict{String, Any}(
        "total_incidents" => total_incidents,
        "active_users_with_incidents" => active_users,
        "severity_breakdown" => severity_counts,
        "cache_size_mb" => round(Base.summarysize(INCIDENT_CACHE) / 1024 / 1024, digits=2),
        "last_updated" => string(now())
    )
end

"""
Clear incidents for a specific user
"""
function clear_incidents!(user_id::String)
    if haskey(INCIDENT_CACHE, user_id)
        delete!(INCIDENT_CACHE, user_id)
        @info "Cleared incidents for user" user_id=user_id
    end
end

"""
Clear all incidents (admin function)
"""
function clear_all_incidents!()
    empty!(INCIDENT_CACHE)
    @info "Cleared all incidents from cache"
end

"""
Clean up old incidents for a user to enforce retention and limits
"""
function cleanup_user_incidents!(user_id::String)
    if !haskey(INCIDENT_CACHE, user_id)
        return
    end
    
    incidents = INCIDENT_CACHE[user_id]
    cutoff_time = now() - Hour(INCIDENT_RETENTION_HOURS)
    
    # Remove incidents older than retention period
    filter!(inc -> inc.timestamp >= cutoff_time, incidents)
    
    # Enforce maximum incidents per user (keep most recent)
    if length(incidents) > MAX_INCIDENTS_PER_USER
        sort!(incidents, by=inc -> inc.timestamp, rev=true)
        INCIDENT_CACHE[user_id] = incidents[1:MAX_INCIDENTS_PER_USER]
    end
end

"""
Create an incident from position data with optional metadata
"""
function create_incident(
    user_id::String,
    position::Dict{String, Any},
    threshold::Float64,
    severity::String = "HIGH",
    metadata::Dict{String, Any} = Dict{String, Any}()
)::Incident
    
    health_factor = get(position, "health_factor", 0.0)
    reason = "Health factor $(round(health_factor, digits=3)) below threshold $(round(threshold, digits=3))"
    
    return Incident(
        user_id,
        get(position, "position_id", "unknown"),
        get(position, "protocol", "unknown"),
        get(position, "chain", "unknown"),
        severity,
        reason,
        health_factor,
        threshold,
        get(position, "collateral_token", ""),
        get(position, "collateral_amount", 0.0),
        get(position, "debt_token", ""),
        get(position, "debt_amount", 0.0),
        now(),
        metadata
    )
end

"""
Determine incident severity based on health factor and threshold
"""
function determine_severity(health_factor::Float64, threshold::Float64)::String
    ratio = health_factor / threshold
    
    if ratio <= 0.9  # Health factor is 90% or less of threshold
        return "CRITICAL"
    elseif ratio <= 0.95  # Health factor is 95% or less of threshold
        return "HIGH"
    elseif ratio <= 0.98  # Health factor is 98% or less of threshold
        return "MEDIUM"
    else
        return "LOW"
    end
end

"""
Convert incident to dictionary for JSON serialization
"""
function incident_to_dict(incident::Incident)::Dict{String, Any}
    return Dict{String, Any}(
        "user_id" => incident.user_id,
        "position_id" => incident.position_id,
        "protocol" => incident.protocol,
        "chain" => incident.chain,
        "severity" => incident.severity,
        "reason" => incident.reason,
        "health_factor" => incident.health_factor,
        "threshold" => incident.threshold,
        "collateral_token" => incident.collateral_token,
        "collateral_amount" => incident.collateral_amount,
        "debt_token" => incident.debt_token,
        "debt_amount" => incident.debt_amount,
        "timestamp" => string(incident.timestamp),
        "metadata" => incident.metadata
    )
end

end # module IncidentStore
