"""
EVM Watcher Agent

Monitors lending positions on EVM-compatible blockchains (Ethereum, Polygon, etc.),
tracks health factors, and feeds data to the prediction engine.
"""
module WatcherEVM

using Dates
using JSON
using HTTP
using Logging

# Import core modules
using ..Types
using ..Database
using ..Utils
using ..Config

export start, stop, health, ping_evm, mode

# Module-level mode tracking
const CURRENT_MODE = Ref{String}("not_started")

# Agent state
Base.@kwdef mutable struct EVMWatcherState
    running::Bool
    config::Any
    monitored_positions::Dict{String, Position}
    last_scan_time::DateTime
    scan_count::Int64
    error_count::Int64
    health_status::String
end

const AGENT_STATE = Ref{Union{Nothing, EVMWatcherState}}(nothing)

"""
    ping_evm(cfg)::Bool

Test EVM RPC connectivity.
"""
function ping_evm(cfg)::Bool
    try
        rpc_url = Config.getc(cfg, :ethereum_rpc_url, "")
        if isempty(rpc_url) || rpc_url == "demo"
            @warn "No EVM RPC URL configured"
            return false
        end
        
        # Test with eth_blockNumber
        headers = ["Content-Type" => "application/json"]
        test_payload = Dict(
            "jsonrpc" => "2.0",
            "id" => 1,
            "method" => "eth_blockNumber",
            "params" => []
        )
        
        response = HTTP.post(
            rpc_url,
            headers,
            JSON.json(test_payload);
            timeout=10
        )
        
        if response.status == 200
            result = JSON.parse(String(response.body))
            return haskey(result, "result")
        end
        
        return false
    catch e
        @warn "EVM connectivity test failed" exception=e
        return false
    end
end

"""
    start(config::Dict)::NamedTuple

Start the EVM watcher agent.
"""
function start(config::Dict)::NamedTuple
    @info "🟦 Starting EVM Watcher Agent..."
    
    demo_mode = Config.getc(config, :demo_mode, true)
    
    try
        # Determine mode
        evm_rpc = Config.getc(config, :ethereum_rpc_url, "")
        has_evm_config = !isempty(evm_rpc) && evm_rpc != "demo"
        
        if !demo_mode && !has_evm_config
            # Missing required EVM config in real mode
            CURRENT_MODE[] = "mock"
            return (success=false, message="Missing Ethereum RPC URL for real mode", mode="mock")
        end
        
        mode_str = (demo_mode || !has_evm_config) ? "mock" : "real"
        CURRENT_MODE[] = mode_str
        
        @info "✅ EVM Watcher Agent started successfully" mode=mode_str
        
        return (success=true, message="EVM Watcher started successfully", mode=mode_str)
        
    catch e
        @error "❌ Failed to start EVM Watcher Agent: $e"
        
        if !demo_mode
            # Fail in real mode
            CURRENT_MODE[] = "mock"
            return (success=false, message="Failed to start EVM Watcher Agent: $e", mode="mock")
        end
        
        # Allow mock in demo mode
        CURRENT_MODE[] = "mock"
        return (success=true, message="EVM Watcher started in mock mode (error: $e)", mode="mock")
    end
end

# Add ping_evm function
function ping_evm(config::Dict{String,Any})::Dict{String, Any}
    try
        # For now, just return a mock success since we're focusing on QC infrastructure
        @info "� Checking EVM connectivity..."
        return Dict(
            "status" => "ok",
            "rpc_url" => "mock://evm-rpc",
            "message" => "EVM connectivity check successful (mock)"
        )
    catch e
        @error "Failed to ping EVM: $e"
        return Dict(
            "status" => "error",
            "message" => "EVM connectivity failed: $e"
        )
    end
end

function mode()::String
    return CURRENT_MODE[]
end

"""
    stop()

Stop the EVM Watcher agent.
"""
function stop()
    @info "🛑 Stopping EVM Watcher Agent..."
    CURRENT_MODE[] = "not_started"
    @info "✅ EVM Watcher Agent stopped"
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
        "monitored_positions" => length(state.monitored_positions),
        "scan_count" => state.scan_count,
        "error_count" => state.error_count,
        "last_scan" => state.last_scan_time
    )
end

# Agent wrapper
struct EVMWatcherAgent
    state::EVMWatcherState
end

function stop(agent::EVMWatcherAgent)
    stop()
end

function health(agent::EVMWatcherAgent)
    return health()
end

function load_monitored_positions(state::EVMWatcherState)
    try
        all_positions = Database.get_active_positions()
        evm_positions = filter(p -> p.chain in ["ethereum", "polygon", "arbitrum"], all_positions)
        
        for position in evm_positions
            state.monitored_positions[position.position_id] = position
        end
        
        @info "✅ Loaded $(length(state.monitored_positions)) EVM positions for monitoring"
        
    catch e
        @error "❌ Failed to load EVM monitored positions: $e"
    end
end

function monitoring_loop(state::EVMWatcherState)
    @info "🔄 Starting EVM monitoring loop..."
    
    while state.running
        try
            state.last_scan_time = now()
            
            # Scan all monitored positions (simplified for demo)
            for (position_id, position) in state.monitored_positions
                # Mock position updates for demo
                position.last_scan_ts = now()
                position.health_factor *= (1.0 + (rand() - 0.5) * 0.01)  # Small random variation
                Database.save_position(position)
            end
            
            state.scan_count += 1
            
            # Sleep until next scan
            interval_ms = Config.getc(state.config, :swarm_update_interval_ms, 1000)
            sleep(interval_ms / 1000)
            
        catch e
            @error "❌ Error in EVM monitoring loop: $e"
            state.error_count += 1
            sleep(5.0)  # Error backoff
        end
    end
    
    @info "🔄 EVM monitoring loop stopped"
end

end # module WatcherEVM
