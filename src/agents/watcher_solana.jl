module WatcherSolana

using Logging
using ..Config

export start, stop, health, ping_solana, mode

# Module-level mode tracking
const CURRENT_MODE = Ref{String}("not_started")

# State management
mutable struct WatcherState
    active::Bool
    last_ping::Union{Nothing, Float64}
end

const STATE = Ref{WatcherState}(WatcherState(false, nothing))

# QC Mode connectivity check
function ping_solana()::Dict{String, Any}
    try
        # For now, just return a mock success since we're focusing on QC infrastructure
        @info "🔍 Checking Solana connectivity..."
        return Dict(
            "status" => "ok",
            "rpc_url" => "mock://solana-rpc",
            "message" => "Solana connectivity check successful (mock)"
        )
    catch e
        @error "Failed to ping Solana: $e"
        return Dict(
            "status" => "error",
            "message" => "Solana connectivity failed: $e"
        )
    end
end

function start(cfg::Dict{String,Any})::NamedTuple
    @info "🟢 Starting WatcherSolana..."
    
    demo_mode = Config.getc(cfg, :demo_mode, true)
    
    # Determine mode based on demo_mode and Solana connectivity
    solana_rpc = Config.getc(cfg, :solana_rpc_url, "")
    has_solana_config = !isempty(solana_rpc) && solana_rpc != "demo"
    
    if !demo_mode && !has_solana_config
        # Missing required Solana config in real mode
        CURRENT_MODE[] = "mock"
        return (success=false, message="Missing Solana RPC URL for real mode", mode="mock")
    end
    
    mode_str = (demo_mode || !has_solana_config) ? "mock" : "real"
    CURRENT_MODE[] = mode_str
    
    STATE[].active = true
    STATE[].last_ping = time()
    return (success=true, message="WatcherSolana started successfully", mode=mode_str)
end

function mode()::String
    return CURRENT_MODE[]
end

function stop()
    @info "🔴 Stopping WatcherSolana..."
    STATE[].active = false
    CURRENT_MODE[] = "not_started"
    return true
end

function health()::Dict{String, Any}
    state = STATE[]
    return Dict(
        "status" => state.active ? "active" : "inactive",
        "last_ping" => state.last_ping,
        "uptime" => state.last_ping !== nothing ? time() - state.last_ping : 0
    )
end

end # module WatcherSolana
