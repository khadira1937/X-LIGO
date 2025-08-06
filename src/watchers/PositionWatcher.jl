"""
Position Watcher Module for X-LiGo
Real-time monitoring of user positions for health factor violations and security incidents
"""
module PositionWatcher

using Dates
using Logging
using ..UserManagement
using ..PositionFetcher
using ..IncidentStore

export start_position_monitoring!, stop_position_monitoring!
export monitor_user_positions, monitor_all_users
export get_monitoring_status, get_monitoring_stats

# Global monitoring state
mutable struct MonitoringState
    active::Bool
    start_time::Union{DateTime, Nothing}
    last_check::Union{DateTime, Nothing}
    check_count::Int
    users_monitored::Int
    incidents_found::Int
    watch_interval_ms::Int
    monitoring_task::Union{Task, Nothing}
end

const MONITORING_STATE = MonitoringState(false, nothing, nothing, 0, 0, 0, 5000, nothing)

"""
Start position monitoring for all registered users
"""
function start_position_monitoring!()
    if MONITORING_STATE.active
        @warn "Position monitoring is already active"
        return false
    end
    
    # Get monitoring interval from environment
    interval_ms = parse(Int, get(ENV, "WATCH_INTERVAL_MS", "5000"))
    MONITORING_STATE.watch_interval_ms = interval_ms
    
    @info "Starting position monitoring" interval_ms=interval_ms
    
    # Reset state
    MONITORING_STATE.active = true
    MONITORING_STATE.start_time = now()
    MONITORING_STATE.check_count = 0
    MONITORING_STATE.users_monitored = 0
    MONITORING_STATE.incidents_found = 0
    
    # Start monitoring task
    MONITORING_STATE.monitoring_task = @async begin
        try
            monitoring_loop()
        catch e
            @error "Position monitoring task failed" exception=e
            MONITORING_STATE.active = false
        end
    end
    
    @info "Position monitoring started successfully"
    return true
end

"""
Stop position monitoring
"""
function stop_position_monitoring!()
    if !MONITORING_STATE.active
        @warn "Position monitoring is not active"
        return false
    end
    
    @info "Stopping position monitoring"
    MONITORING_STATE.active = false
    
    # Cancel monitoring task if it exists
    if MONITORING_STATE.monitoring_task !== nothing
        try
            Base.cancel(MONITORING_STATE.monitoring_task)
        catch e
            @debug "Error canceling monitoring task" exception=e
        end
        MONITORING_STATE.monitoring_task = nothing
    end
    
    @info "Position monitoring stopped"
    return true
end

"""
Main monitoring loop
"""
function monitoring_loop()
    @info "Position monitoring loop started"
    
    while MONITORING_STATE.active
        try
            # Monitor all users
            incidents_this_round = monitor_all_users()
            
            # Update state
            MONITORING_STATE.last_check = now()
            MONITORING_STATE.check_count += 1
            MONITORING_STATE.incidents_found += incidents_this_round
            
            @debug "Monitoring check completed" incidents=incidents_this_round check_count=MONITORING_STATE.check_count
            
            # Wait for next interval
            sleep(MONITORING_STATE.watch_interval_ms / 1000.0)
            
        catch e
            @error "Error in monitoring loop" exception=e
            # Continue monitoring despite errors
            sleep(5.0)  # Wait 5 seconds before retry
        end
    end
    
    @info "Position monitoring loop ended"
end

"""
Monitor all registered users for position health violations
"""
function monitor_all_users()::Int
    total_incidents = 0
    users_checked = 0
    
    try
        # Get all active users
        active_users = UserManagement.list_active_users()
        
        @debug "Monitoring positions for users" count=length(active_users)
        
        for user_profile in active_users
            try
                user_id = get(user_profile, "user_id", "unknown")
                incidents = monitor_user_positions(user_id)
                total_incidents += length(incidents)
                users_checked += 1
                
            catch e
                @warn "Failed to monitor user positions" user_id=get(user_profile, "user_id", "unknown") exception=e
            end
        end
        
        MONITORING_STATE.users_monitored = users_checked
        
        if total_incidents > 0
            @info "Position monitoring completed" users_checked=users_checked incidents_found=total_incidents
        end
        
    catch e
        @error "Failed to monitor all users" exception=e
    end
    
    return total_incidents
end

"""
Monitor positions for a specific user
"""
function monitor_user_positions(user_id::String)::Vector{IncidentStore.Incident}
    incidents = Vector{IncidentStore.Incident}()
    
    try
        @debug "Monitoring positions for user" user_id=user_id
        
        # Get user profile and policy
        user_profile = UserManagement.get_user_profile(user_id)
        if user_profile === nothing
            @debug "User profile not found" user_id=user_id
            return incidents
        end
        
        user_policy = UserManagement.get_user_policy(user_id)
        if user_policy === nothing
            @debug "User policy not found, skipping monitoring" user_id=user_id
            return incidents
        end
        
        # Get critical health factor threshold
        critical_hf = get(user_policy, "critical_health_factor", 1.1)
        
        # Fetch user's positions
        positions = PositionFetcher.fetch_user_positions(user_profile)
        
        @debug "Checking positions" user_id=user_id position_count=length(positions) critical_threshold=critical_hf
        
        # Check each position for health factor violations
        for position in positions
            health_factor = get(position, "health_factor", 999.0)
            
            # Check if health factor is below critical threshold
            if health_factor <= critical_hf
                severity = IncidentStore.determine_severity(health_factor, critical_hf)
                incident = IncidentStore.create_incident(user_id, position, critical_hf, severity)
                
                # Add to incident store
                IncidentStore.add_incident!(incident)
                push!(incidents, incident)
                
                # Send Discord notification for high-severity incidents
                if severity in ["HIGH", "CRITICAL"]
                    try
                        # Call Discord notifier from parent module if available
                        if isdefined(Main, :XLiGo) && isdefined(Main.XLiGo, :DiscordNotifier)
                            discord_result = Main.XLiGo.DiscordNotifier.send_discord_alert(incident)
                            if get(discord_result, "success", false)
                                @info "Discord alert sent successfully" incident_severity=severity user_id=user_id
                            else
                                @warn "Discord alert failed" reason=get(discord_result, "reason", "unknown")
                            end
                        end
                    catch e
                        @warn "Failed to send Discord notification" error=e
                    end
                end
                
                @warn "Health factor violation detected" user_id=user_id position_id=get(position, "position_id", "unknown") health_factor=health_factor threshold=critical_hf severity=severity
            end
        end
        
        if !isempty(incidents)
            @info "Found position violations" user_id=user_id incident_count=length(incidents)
        end
        
    catch e
        @error "Failed to monitor user positions" user_id=user_id exception=e
    end
    
    return incidents
end

"""
Get current monitoring status
"""
function get_monitoring_status()::Dict{String, Any}
    return Dict{String, Any}(
        "active" => MONITORING_STATE.active,
        "start_time" => MONITORING_STATE.start_time !== nothing ? string(MONITORING_STATE.start_time) : nothing,
        "last_check" => MONITORING_STATE.last_check !== nothing ? string(MONITORING_STATE.last_check) : nothing,
        "check_count" => MONITORING_STATE.check_count,
        "users_monitored" => MONITORING_STATE.users_monitored,
        "incidents_found" => MONITORING_STATE.incidents_found,
        "watch_interval_ms" => MONITORING_STATE.watch_interval_ms,
        "uptime_minutes" => MONITORING_STATE.start_time !== nothing ? 
            round((now() - MONITORING_STATE.start_time).value / 60000, digits=1) : 0
    )
end

"""
Get detailed monitoring statistics
"""
function get_monitoring_stats()::Dict{String, Any}
    status = get_monitoring_status()
    incident_summary = IncidentStore.get_incident_summary()
    
    # Get additional stats
    try
        all_users = UserManagement.list_active_users()
        total_users = length(all_users)
        
        status["total_registered_users"] = total_users
        status["monitoring_coverage"] = total_users > 0 ? 
            round(MONITORING_STATE.users_monitored / total_users * 100, digits=1) : 0.0
    catch e
        @debug "Could not get user statistics" exception=e
        status["total_registered_users"] = 0
        status["monitoring_coverage"] = 0.0
    end
    
    # Merge incident summary
    merge!(status, incident_summary)
    
    return status
end

"""
Force a single monitoring check (for testing)
"""
function force_monitoring_check()::Dict{String, Any}
    @info "Forcing manual monitoring check"
    
    incidents_found = monitor_all_users()
    
    return Dict{String, Any}(
        "success" => true,
        "incidents_found" => incidents_found,
        "users_monitored" => MONITORING_STATE.users_monitored,
        "timestamp" => string(now())
    )
end

"""
Get position monitoring data for health endpoint
"""
function get_health_data()::Dict{String, Any}
    status = get_monitoring_status()
    
    return Dict{String, Any}(
        "monitored_users" => MONITORING_STATE.users_monitored,
        "monitored_wallets" => Dict(
            "evm" => 0,  # TODO: Track separately if needed
            "solana" => 0  # TODO: Track separately if needed
        ),
        "positions_cached" => get(IncidentStore.get_incident_summary(), "total_incidents", 0),
        "mempool_monitoring" => get(ENV, "ENABLE_MEMPOOL_MONITORING", "false") == "true" ? "enabled" : "disabled",
        "last_monitoring_check" => status["last_check"],
        "monitoring_active" => status["active"]
    )
end

end # module PositionWatcher
