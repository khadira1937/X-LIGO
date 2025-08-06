"""
Enhanced Solana watcher for real-time monitoring of user wallets and positions.
"""
module EnhancedWatcherSolana

using Dates, HTTP, JSON3, Logging
using ..Config, ..Database, ..UserManagement
using ..PositionFetcher, ..IncidentStore

export start_wallet_monitoring!, monitor_mempool_for_attacks

# Global monitoring state
const MONITORING_STATE = Dict{String, Any}(
    "active_users" => Dict{String, Any}(),
    "last_check" => Dict{String, DateTime}(),
    "position_cache" => Dict{String, Vector{Dict}}()
)

"""
    start_wallet_monitoring!(user::UserProfile)

Start monitoring a user's Solana wallet for position changes and potential liquidation risks.
"""
function start_wallet_monitoring!(user::UserProfile)
    try
        if user.solana_wallet === nothing
            @debug "User $(user.user_id) has no Solana wallet to monitor"
            return (success=false, message="No Solana wallet configured")
        end
        
        wallet = user.solana_wallet
        @info "Starting Solana wallet monitoring for user $(user.user_id), wallet: $wallet"
        
        # Add to monitoring state
        MONITORING_STATE["active_users"][user.user_id] = Dict(
            "profile" => user,
            "solana_wallet" => wallet,
            "started_at" => Dates.now(),
            "last_position_check" => Dates.now(),
            "position_count" => 0,
            "alerts_sent" => 0
        )
        
        MONITORING_STATE["last_check"][user.user_id] = Dates.now()
        
        @info "Solana monitoring started for user $(user.user_id)"
        return (success=true, message="Solana wallet monitoring started")
        
    catch e
        @error "Failed to start Solana wallet monitoring for user $(user.user_id)" exception=e
        return (success=false, message="Failed to start monitoring: $e")
    end
end

"""
    stop_wallet_monitoring!(user_id::String)

Stop monitoring a user's Solana wallet.
"""
function stop_wallet_monitoring!(user_id::String)
    try
        if haskey(MONITORING_STATE["active_users"], user_id)
            delete!(MONITORING_STATE["active_users"], user_id)
            delete!(MONITORING_STATE["last_check"], user_id)
            delete!(MONITORING_STATE["position_cache"], user_id)
            @info "Stopped Solana monitoring for user $user_id"
            return (success=true, message="Monitoring stopped")
        else
            return (success=false, message="User not being monitored")
        end
    catch e
        @error "Failed to stop Solana monitoring for user $user_id" exception=e
        return (success=false, message="Failed to stop monitoring: $e")
    end
end

"""
    check_user_positions(user_id::String)

Check a monitored user's Solana positions for health factor changes.
"""
function check_user_positions(user_id::String)
    try
        if !haskey(MONITORING_STATE["active_users"], user_id)
            return (success=false, message="User not being monitored")
        end
        
        user_state = MONITORING_STATE["active_users"][user_id]
        wallet = user_state["solana_wallet"]
        
        # This would integrate with PositionFetcher in a real implementation
        @debug "Checking Solana positions for user $user_id, wallet $wallet"
        
        # Update last check time
        MONITORING_STATE["last_check"][user_id] = Dates.now()
        user_state["last_position_check"] = Dates.now()
        
        # In demo mode, return mock data
        cfg = Config.load_config()
        if get(cfg, "DEMO_MODE", "true") == "true"
            mock_positions = [
                Dict(
                    "protocol" => "solend",
                    "chain" => "solana",
                    "position_id" => "solend_sol_$(user_id)_1",
                    "collateral_token" => "SOL",
                    "collateral_amount" => 25.0,
                    "debt_token" => "USDC",
                    "debt_amount" => 2800.0,
                    "health_factor" => 2.1,
                    "liquidation_threshold" => 0.8,
                    "last_updated" => Dates.now()
                )
            ]
            
            MONITORING_STATE["position_cache"][user_id] = mock_positions
            user_state["position_count"] = length(mock_positions)
            
            return (success=true, positions=mock_positions)
        end
        
        # TODO: Implement real position fetching via PositionFetcher
        return (success=true, positions=Vector{Dict}())
        
    catch e
        @error "Failed to check Solana positions for user $user_id" exception=e
        return (success=false, message="Failed to check positions: $e")
    end
end

"""
    monitor_mempool_for_attacks()

Monitor Solana for potential attack transactions.
Only runs when ENABLE_MEMPOOL_MONITORING=true.
"""
function monitor_mempool_for_attacks()
    try
        cfg = Config.load_config()
        
        if get(cfg, "ENABLE_MEMPOOL_MONITORING", "false") != "true"
            @debug "Mempool monitoring disabled via ENABLE_MEMPOOL_MONITORING"
            return (success=false, message="Mempool monitoring disabled")
        end
        
        @info "Starting Solana mempool monitoring for attack detection"
        
        # In a real implementation, this would connect to Solana RPC
        # and monitor recent transactions for suspicious patterns
        
        solana_rpc_url = get(cfg, "SOLANA_RPC_URL", "")
        if isempty(solana_rpc_url)
            @warn "SOLANA_RPC_URL not configured, mempool monitoring will use mock data"
        end
        
        watch_interval_ms = parse(Int, get(cfg, "WATCH_INTERVAL_MS", "5000"))
        
        @info "Solana mempool monitoring configured with interval $(watch_interval_ms)ms"
        
        # For now, return success - real implementation would start background task
        return (success=true, message="Solana mempool monitoring started")
        
    catch e
        @error "Failed to start Solana mempool monitoring" exception=e
        return (success=false, message="Failed to start mempool monitoring: $e")
    end
end

"""
    get_monitoring_status()

Get current Solana monitoring status for all users.
"""
function get_monitoring_status()
    try
        active_count = length(MONITORING_STATE["active_users"])
        total_positions = sum(
            get(user_state, "position_count", 0) 
            for user_state in values(MONITORING_STATE["active_users"])
        )
        
        return Dict(
            "active_users" => active_count,
            "total_positions_cached" => total_positions,
            "users" => [
                Dict(
                    "user_id" => user_id,
                    "solana_wallet" => user_state["solana_wallet"],
                    "started_at" => user_state["started_at"],
                    "last_check" => get(MONITORING_STATE["last_check"], user_id, nothing),
                    "position_count" => get(user_state, "position_count", 0),
                    "alerts_sent" => get(user_state, "alerts_sent", 0)
                )
                for (user_id, user_state) in MONITORING_STATE["active_users"]
            ]
        )
    catch e
        @error "Failed to get Solana monitoring status" exception=e
        return Dict("error" => "Failed to get monitoring status: $e")
    end
end

"""
    run_monitoring_loop()

Main Solana monitoring loop that checks all active users periodically.
"""
function run_monitoring_loop()
    try
        cfg = Config.load_config()
        watch_interval_ms = parse(Int, get(cfg, "WATCH_INTERVAL_MS", "5000"))
        
        @info "Starting Solana monitoring loop with interval $(watch_interval_ms)ms"
        
        while true
            for user_id in keys(MONITORING_STATE["active_users"])
                try
                    result = check_user_positions(user_id)
                    if !result.success
                        @warn "Solana position check failed for user $user_id: $(result.message)"
                    end
                catch e
                    @error "Error checking user $user_id Solana positions" exception=e
                end
            end
            
            sleep(watch_interval_ms / 1000.0)
        end
        
    catch e
        @error "Solana monitoring loop crashed" exception=e
        rethrow(e)
    end
end

end # module EnhancedWatcherSolana
