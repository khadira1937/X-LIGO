"""
API Server for X-LiGo system status and health monitoring.
"""
module ApiServer

using HTTP
using JSON3
using Dates
using Logging
using ..Config

export start_api_server, stop_api_server

# Global server reference
const SERVER_REF = Ref{Union{Nothing, HTTP.Server}}(nothing)

"""
    get_system_status()

Get comprehensive system status including agent modes and configuration health.
"""
function get_system_status()
    try
        # Load current configuration
        cfg = Config.load_config()
        
        # Get agent modes (will be implemented in XLiGo.jl)
        agent_modes = try
            # Try to get from parent module if available
            if isdefined(Main, :XLiGo) && hasmethod(Main.XLiGo.agent_modes, ())
                Main.XLiGo.agent_modes()
            else
                Dict{String,String}(
                    "watcher_solana" => "unknown",
                    "watcher_evm" => "unknown", 
                    "predictor" => "unknown",
                    "optimizer" => "unknown",
                    "analyst_llm" => "unknown",
                    "policy_guard" => "unknown",
                    "actioner_solana" => "unknown",
                    "actioner_evm" => "unknown",
                    "reporter" => "unknown"
                )
            end
        catch e
            @warn "Failed to get agent modes" exception=e
            Dict{String,String}()
        end
        
        # Run configuration doctor
        doc_result = try
            if isdefined(Main, :XLiGo) && hasmethod(Main.XLiGo.config_doctor, (Dict,))
                Main.XLiGo.config_doctor(cfg)
            else
                # Basic config check
                missing_keys = String[]
                demo_mode = Config.getc(cfg, :demo_mode, true)
                
                if !demo_mode
                    # Required keys for real mode
                    required_keys = ["openai_api_key", "solana_rpc_url"]
                    for key in required_keys
                        if isempty(get(cfg, key, ""))
                            push!(missing_keys, key)
                        end
                    end
                end
                
                (ok = isempty(missing_keys), missing = missing_keys, notes = String[])
            end
        catch e
            @warn "Failed to run config doctor" exception=e
            (ok = false, missing = String[], notes = ["Config doctor failed: $e"])
        end
        
        return Dict(
            "ok" => doc_result.ok,
            "ts" => Dates.format(now(), "yyyy-mm-ddTHH:MM:SS.sssZ"),
            "demo_mode" => Config.getc(cfg, :demo_mode, true),
            "agents" => agent_modes,
            "missing_keys" => doc_result.missing,
            "notes" => doc_result.notes
        )
    catch e
        @error "Failed to get system status" exception=e
        return Dict(
            "ok" => false,
            "ts" => Dates.format(now(), "yyyy-mm-ddTHH:MM:SS.sssZ"),
            "demo_mode" => true,
            "agents" => Dict{String,String}(),
            "missing_keys" => String[],
            "notes" => ["System status check failed: $e"]
        )
    end
end

"""
    create_router()

Create HTTP router with status endpoints.
"""
function create_router()
    return HTTP.Router() do request::HTTP.Request
        # CORS headers
        headers = [
            "Access-Control-Allow-Origin" => "*",
            "Access-Control-Allow-Methods" => "GET, POST, OPTIONS",
            "Access-Control-Allow-Headers" => "Content-Type",
            "Content-Type" => "application/json"
        ]
        
        try
            if request.method == "OPTIONS"
                return HTTP.Response(200, headers, "")
            elseif request.method == "GET" && request.target == "/status"
                status = get_system_status()
                response_body = JSON3.write(status)
                return HTTP.Response(200, headers, response_body)
            elseif request.method == "GET" && request.target == "/health"
                # Get agent status for health endpoint
                agents = try
                    if isdefined(Main, :XLiGo) && hasmethod(Main.XLiGo.agent_modes, ())
                        agent_modes = Main.XLiGo.agent_modes()
                        # Convert to array of agent info
                        [Dict("name" => name, "status" => mode) for (name, mode) in agent_modes]
                    else
                        # Default agent list when not available
                        agent_names = ["predictor", "optimizer", "analyst", "policy_guard", 
                                     "actioner_solana", "actioner_evm", "reporter", 
                                     "watcher_solana", "watcher_evm"]
                        [Dict("name" => name, "status" => "unknown") for name in agent_names]
                    end
                catch e
                    @warn "Failed to get agent modes for health check" exception=e
                    []
                end
                
                # Get user monitoring info
                monitored_users = try
                    if isdefined(Main, :XLiGo) && isdefined(Main.XLiGo, :UserManagement)
                        Main.XLiGo.UserManagement.get_monitored_user_count()
                    else
                        0
                    end
                catch e
                    @warn "Failed to get monitored user count" exception=e
                    0
                end
                
                # Get positions cache info
                positions_cached = try
                    if isdefined(Main, :XLiGo) && isdefined(Main.XLiGo, :PositionFetcher)
                        cache_stats = Main.XLiGo.PositionFetcher.get_positions_cache_stats()
                        get(cache_stats, "cached_positions", 0)
                    else
                        0
                    end
                catch e
                    @warn "Failed to get positions cache info" exception=e
                    0
                end
                
                # Get enhanced watcher status
                evm_watcher_status = try
                    if isdefined(Main, :XLiGo) && isdefined(Main.XLiGo, :EnhancedWatcherEVM)
                        Main.XLiGo.EnhancedWatcherEVM.get_monitoring_status()
                    else
                        Dict("active_users" => 0, "total_positions_cached" => 0)
                    end
                catch e
                    @warn "Failed to get EVM watcher status" exception=e
                    Dict("active_users" => 0, "total_positions_cached" => 0)
                end
                
                solana_watcher_status = try
                    if isdefined(Main, :XLiGo) && isdefined(Main.XLiGo, :EnhancedWatcherSolana)
                        Main.XLiGo.EnhancedWatcherSolana.get_monitoring_status()
                    else
                        Dict("active_users" => 0, "total_positions_cached" => 0)
                    end
                catch e
                    @warn "Failed to get Solana watcher status" exception=e
                    Dict("active_users" => 0, "total_positions_cached" => 0)
                end
                
                # Calculate total monitored wallets more accurately
                total_monitored_wallets = get(evm_watcher_status, "active_users", 0) + 
                                        get(solana_watcher_status, "active_users", 0)
                total_cached_positions = positions_cached + 
                                       get(evm_watcher_status, "total_positions_cached", 0) +
                                       get(solana_watcher_status, "total_positions_cached", 0)
                
                # Get mempool monitoring status
                mempool_monitoring = get(ENV, "ENABLE_MEMPOOL_MONITORING", "false") == "true"
                
                # Get new position watcher status
                position_watcher_data = try
                    if isdefined(Main, :XLiGo) && isdefined(Main.XLiGo, :PositionWatcher)
                        Main.XLiGo.PositionWatcher.get_health_data()
                    else
                        Dict(
                            "monitored_users" => 0,
                            "monitored_wallets" => Dict("evm" => 0, "solana" => 0),
                            "positions_cached" => 0,
                            "mempool_monitoring" => "disabled",
                            "monitoring_active" => false
                        )
                    end
                catch e
                    @warn "Failed to get position watcher data" exception=e
                    Dict(
                        "monitored_users" => 0,
                        "monitored_wallets" => Dict("evm" => 0, "solana" => 0),
                        "positions_cached" => 0,
                        "mempool_monitoring" => "disabled",
                        "monitoring_active" => false
                    )
                end
                
                health = Dict(
                    "status" => "ok", 
                    "agents" => agents,
                    "monitored_users" => get(position_watcher_data, "monitored_users", monitored_users),
                    "monitored_wallets" => get(position_watcher_data, "monitored_wallets", Dict("evm" => 0, "solana" => 0)),
                    "positions_cached" => get(position_watcher_data, "positions_cached", total_cached_positions),
                    "mempool_monitoring" => get(position_watcher_data, "mempool_monitoring", mempool_monitoring ? "enabled" : "disabled"),
                    "position_monitoring_active" => get(position_watcher_data, "monitoring_active", false),
                    "last_monitoring_check" => get(position_watcher_data, "last_monitoring_check", nothing),
                    "evm_watcher" => Dict(
                        "active_users" => get(evm_watcher_status, "active_users", 0),
                        "cached_positions" => get(evm_watcher_status, "total_positions_cached", 0)
                    ),
                    "solana_watcher" => Dict(
                        "active_users" => get(solana_watcher_status, "active_users", 0),
                        "cached_positions" => get(solana_watcher_status, "total_positions_cached", 0)
                    )
                )
                response_body = JSON3.write(health)
                return HTTP.Response(200, headers, response_body)
            elseif request.method == "POST" && request.target == "/chat"
                # AI-powered chat endpoint for incident analysis
                try
                    request_body = JSON3.read(IOBuffer(request.body))
                    message = get(request_body, "message", "")
                    
                    if isempty(message)
                        error_response = Dict(
                            "error" => "Message is required", 
                            "status" => "error",
                            "example" => Dict("message" => "What just happened?")
                        )
                        return HTTP.Response(400, headers, JSON3.write(error_response))
                    end
                    
                    # Generate AI response using ChatResponder
                    ai_response = try
                        if isdefined(Main, :XLiGo) && isdefined(Main.XLiGo, :ChatResponder)
                            Main.XLiGo.ChatResponder.generate_response(message)
                        else
                            "🤖 **AI Chat Unavailable**\n\nChatResponder module not loaded. Please ensure the AI modules are properly initialized."
                        end
                    catch e
                        @error "ChatResponder failed" error=e message=message
                        "🚨 **AI Error**\n\nFailed to process your request. Please try again or check system logs."
                    end
                    
                    # Build response
                    chat_response = Dict(
                        "response" => ai_response,
                        "status" => "success",
                        "message" => message,
                        "timestamp" => Dates.format(now(), "yyyy-mm-ddTHH:MM:SS"),
                        "ai_powered" => true
                    )
                    
                    @info "Chat response generated" message_length=length(message) response_length=length(ai_response)
                    
                    return HTTP.Response(200, headers, JSON3.write(chat_response))
                catch e
                    @error "Chat endpoint error" exception=e
                    error_response = Dict("error" => "Failed to process chat request", "message" => string(e))
                    return HTTP.Response(500, headers, JSON3.write(error_response))
                end
            elseif request.method == "POST" && request.target == "/api/incidents"
                # Incidents endpoint for registering demo incidents
                try
                    request_body = JSON3.read(IOBuffer(request.body))
                    
                    # Convert to proper Dict format (JSON3 may create symbols)
                    incident_dict = Dict{String, Any}()
                    for (k, v) in pairs(request_body)
                        key_str = string(k)
                        if v isa Dict || v isa JSON3.Object
                            # Convert nested dictionaries recursively
                            nested_dict = Dict{String, Any}()
                            for (nk, nv) in pairs(v)
                                nested_dict[string(nk)] = nv
                            end
                            incident_dict[key_str] = nested_dict
                        else
                            incident_dict[key_str] = v
                        end
                    end
                    
                    # Validate required fields
                    required_fields = ["incident_id", "incident_type", "severity", "status"]
                    for field in required_fields
                        if !haskey(incident_dict, field)
                            error_response = Dict("error" => "Missing required field: $field")
                            return HTTP.Response(400, headers, JSON3.write(error_response))
                        end
                    end
                    
                    # Register incident with coordinator
                    if isdefined(Main, :XLiGo) && isdefined(Main.XLiGo, :Coordinator)
                        @info "Registering demo incident: $(get(incident_dict, "incident_id", "unknown"))"
                        Main.XLiGo.Coordinator.LATEST_SECURITY_INCIDENT[] = incident_dict
                        
                        success_response = Dict(
                            "status" => "success",
                            "message" => "Incident registered successfully",
                            "incident_id" => get(incident_dict, "incident_id", "unknown"),
                            "timestamp" => Dates.format(now(), "yyyy-mm-ddTHH:MM:SS.sssZ")
                        )
                        return HTTP.Response(201, headers, JSON3.write(success_response))
                    else
                        error_response = Dict("error" => "Coordinator not available")
                        return HTTP.Response(503, headers, JSON3.write(error_response))
                    end
                catch e
                    @error "Incidents endpoint error" exception=e
                    error_response = Dict("error" => "Failed to register incident", "message" => string(e))
                    return HTTP.Response(500, headers, JSON3.write(error_response))
                end
            elseif startswith(request.target, "/api/users")
                # Delegate user routes to UserRoutes module
                try
                    return Main.XLiGo.UserRoutes.handle_user_routes(request)
                catch e
                    @error "User routes delegation error" exception=e
                    error_response = Dict("error" => "User routes not available", "message" => string(e))
                    return HTTP.Response(503, headers, JSON3.write(error_response))
                end
            elseif startswith(request.target, "/api/positions")
                # Delegate position routes to PositionRoutes module
                try
                    return Main.XLiGo.PositionRoutes.handle_position_routes(request)
                catch e
                    @error "Position routes delegation error" exception=e
                    error_response = Dict("error" => "Position routes not available", "message" => string(e))
                    return HTTP.Response(503, headers, JSON3.write(error_response))
                end
            else
                error_response = Dict("error" => "Not found", "path" => request.target)
                return HTTP.Response(404, headers, JSON3.write(error_response))
            end
        catch e
            @error "Request handling error" exception=e request.target
            error_response = Dict("error" => "Internal server error", "message" => string(e))
            return HTTP.Response(500, headers, JSON3.write(error_response))
        end
    end
end

"""
    start_api_server(port::Int = 3000; host::String = "127.0.0.1")

Start the API server on the specified port.
"""
function start_api_server(port::Int = 3000; host::String = "127.0.0.1")
    if SERVER_REF[] !== nothing
        @warn "API server already running"
        return (success=true, message="Server already running", port=port)
    end
    
    try
        router = create_router()
        
        server = HTTP.serve!(router, host, port; verbose=false)
        SERVER_REF[] = server
        
        @info "Listening on $(host):$(port)..."
        return (success=true, message="API server started successfully", port=port)
    catch e
        @error "Failed to start API server" exception=e port=port
        return (success=false, message="Failed to start API server: $e", port=port)
    end
end

"""
    stop_api_server()

Stop the running API server.
"""
function stop_api_server()
    if SERVER_REF[] === nothing
        @warn "No API server running"
        return (success=true, message="No server was running")
    end
    
    try
        HTTP.close(SERVER_REF[])
        SERVER_REF[] = nothing
        @info "API server stopped"
        return (success=true, message="API server stopped successfully")
    catch e
        @error "Failed to stop API server" exception=e
        return (success=false, message="Failed to stop API server: $e")
    end
end

end # module ApiServer
