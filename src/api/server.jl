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
                
                health = Dict("status" => "ok", "agents" => agents)
                response_body = JSON3.write(health)
                return HTTP.Response(200, headers, response_body)
            elseif request.method == "POST" && request.target == "/chat"
                # Chat endpoint for LLM interaction
                try
                    request_body = JSON3.read(IOBuffer(request.body))
                    message = get(request_body, "message", "")
                    
                    if isempty(message)
                        error_response = Dict("error" => "Message is required", "example" => Dict("message" => "Why was this transaction flagged?"))
                        return HTTP.Response(400, headers, JSON3.write(error_response))
                    end
                    
                    # Check for security incident queries first
                    message_lower = lowercase(message)
                    security_keywords = [
                        "what just happened", "what happened", "last attack", "latest incident", 
                        "recent attack", "show me the report", "security report", "last report",
                        "attack report", "what was blocked", "recent threat", "latest threat",
                        "any attack", "incident report", "what's the status", "recent activity"
                    ]
                    
                    is_security_query = any(keyword -> contains(message_lower, keyword), security_keywords)
                    
                    response = if is_security_query
                        # Handle security incident queries
                        try
                            @info "Processing security incident query: '$message'"
                            
                            # Get latest security incident
                            latest_incident = if isdefined(Main, :XLiGo) && isdefined(Main.XLiGo, :Coordinator)
                                Main.XLiGo.Coordinator.get_latest_security_incident()
                            else
                                nothing
                            end
                            
                            if latest_incident !== nothing
                                # Format incident as security alert
                                incident_type = get(latest_incident, "incident_type", "unknown")
                                severity = get(latest_incident, "severity", "unknown")
                                status = get(latest_incident, "status", "unknown")
                                incident_id = get(latest_incident, "incident_id", "unknown")
                                position_value = get(latest_incident, "position_value_usd", 0)
                                
                                # Extract additional details from metadata
                                metadata = get(latest_incident, "metadata", Dict())
                                attack_vector = get(metadata, "attack_vector", "unknown")
                                protocol = get(metadata, "target_protocol", get(metadata, "protocol", "unknown"))
                                
                                # Calculate loss prevented (estimate 10% liquidation penalty)
                                loss_prevented = position_value * 0.1
                                
                                # Format timestamp
                                detected_at = get(latest_incident, "detected_at", "")
                                time_str = if !isempty(string(detected_at))
                                    try
                                        if isa(detected_at, String)
                                            # Parse and format the timestamp
                                            parsed_time = DateTime(detected_at[1:19])  # Remove timezone part
                                            Dates.format(parsed_time, "yyyy-mm-dd HH:MM:SS")
                                        else
                                            Dates.format(detected_at, "yyyy-mm-dd HH:MM:SS")
                                        end
                                    catch
                                        "recently"
                                    end
                                else
                                    "recently"
                                end
                                
                                # Create formatted response
                                status_emoji = if status == "protected" || status == "policy_blocked"
                                    "✅ BLOCKED"
                                elseif status == "detected"
                                    "🔍 DETECTED"
                                else
                                    "⚠️ $(uppercase(status))"
                                end
                                
                                response_text = """🚨 **Latest Security Alert**

**Attack Type:** $(replace(incident_type, "_" => " ") |> titlecase)
**Incident ID:** $(incident_id)
**Severity:** $(uppercase(severity))
**Status:** $(status_emoji)
**Protocol:** $(titlecase(protocol))
**Detected:** $(time_str)

💰 **Financial Impact:**
• Value Protected: \$$(Int(round(position_value)))
• Loss Prevented: \$$(Int(round(loss_prevented)))

🔍 **Attack Details:**
• Vector: $(replace(attack_vector, "_" => " ") |> titlecase)
• Classification: Sophisticated threat pattern detected

🛡️ **X-LiGo Response:**
The threat was automatically identified and neutralized by our AI-powered protection system. All positions remain secure."""
                                
                                Dict("response" => response_text, "status" => "real")
                            else
                                # No incidents found
                                Dict("response" => "No recent security incidents detected. The X-LiGo protection system is monitoring all positions and has not identified any threats. All systems are operating normally.", "status" => "real")
                            end
                        catch e
                            @error "Failed to get security incident: $e"
                            Dict("response" => "I'm having trouble accessing the latest security reports. Please try again or contact support if the issue persists.", "status" => "error")
                        end
                    else
                        # Handle regular LLM queries
                        try
                            @info "Attempting to call LLM chat function..."
                            
                            # Check if the module is available
                            if !isdefined(Main, :XLiGo)
                                @error "Main.XLiGo not defined"
                                Dict("response" => "XLiGo module not available", "status" => "error")
                            elseif !isdefined(Main.XLiGo, :AnalystLLM)
                                @error "AnalystLLM module not defined"
                                Dict("response" => "AnalystLLM module not available", "status" => "error")
                            elseif !hasmethod(Main.XLiGo.AnalystLLM.chat_with_analyst, (String,))
                                @error "chat_with_analyst function not available"
                                Dict("response" => "chat_with_analyst function not available", "status" => "error")
                            else
                                @info "Calling chat_with_analyst with message: '$message'"
                                result = Main.XLiGo.AnalystLLM.chat_with_analyst(message)
                                @info "LLM response received: $result"
                                result
                            end
                        catch e
                            @error "LLM chat failed" exception=e
                            Dict("response" => "Sorry, I'm having trouble thinking right now. Error: $e", "status" => "error")
                        end
                    end
                    
                    chat_response = Dict(
                        "message" => message,
                        "response" => get(response, "response", "No response available"),
                        "status" => get(response, "status", "unknown"),
                        "timestamp" => Dates.format(now(), "yyyy-mm-ddTHH:MM:SS.sssZ")
                    )
                    
                    response_body = JSON3.write(chat_response)
                    return HTTP.Response(200, headers, response_body)
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
