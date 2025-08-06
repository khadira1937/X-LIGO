"""
User Management API Routes

Handles HTTP endpoints for user registration, policy management, and status queries.
Converts internal types to JSON-compatible dictionaries at response boundaries.
"""
module UserRoutes

using HTTP
using JSON3
using Dates
using Logging
using ..UserManagement
using ..UserManagement: UserProfile, ProtectionPolicy

export handle_user_routes

"""
Handle user-related HTTP routes
"""
function handle_user_routes(request::HTTP.Request)::HTTP.Response
    headers = [
        "Content-Type" => "application/json",
        "Access-Control-Allow-Origin" => "*",
        "Access-Control-Allow-Methods" => "GET, POST, OPTIONS",
        "Access-Control-Allow-Headers" => "Content-Type"
    ]
    
    try
        # Parse URL path
        path_parts = split(request.target, "/")
        
        if request.method == "OPTIONS"
            return HTTP.Response(200, headers, "")
        end
        
        # POST /api/users/register
        if request.method == "POST" && length(path_parts) >= 4 && 
           path_parts[2] == "api" && path_parts[3] == "users" && path_parts[4] == "register"
            return handle_user_register(request, headers)
            
        # POST /api/users/{user_id}/policy
        elseif request.method == "POST" && length(path_parts) >= 5 && 
               path_parts[2] == "api" && path_parts[3] == "users" && path_parts[5] == "policy"
            user_id = path_parts[4]
            return handle_set_policy(request, headers, user_id)
            
        # GET /api/users/{user_id}/status
        elseif request.method == "GET" && length(path_parts) >= 5 && 
               path_parts[2] == "api" && path_parts[3] == "users" && path_parts[5] == "status"
            user_id = path_parts[4]
            return handle_user_status(request, headers, user_id)
            
        # GET /api/users/{user_id}/positions - delegate to PositionRoutes
        elseif request.method == "GET" && length(path_parts) >= 5 && 
               path_parts[2] == "api" && path_parts[3] == "users" && path_parts[5] == "positions"
            # Delegate to PositionRoutes module
            try
                return Main.XLiGo.PositionRoutes.handle_position_routes(request)
            catch e
                @error "Position routes delegation error" exception=e
                error_response = Dict("error" => "Position routes not available", "message" => string(e))
                return HTTP.Response(503, headers, JSON3.write(error_response))
            end
            
        else
            error_response = Dict("error" => "User route not found", "path" => request.target)
            return HTTP.Response(404, headers, JSON3.write(error_response))
        end
        
    catch e
        @error "User routes error" exception=e request.target
        error_response = Dict("error" => "Internal server error", "message" => string(e))
        return HTTP.Response(500, headers, JSON3.write(error_response))
    end
end

"""
Handle user registration
POST /api/users/register
"""
function handle_user_register(request::HTTP.Request, headers::Vector{Pair{String, String}})::HTTP.Response
    try
        # Parse request body
        request_body = JSON3.read(IOBuffer(request.body))
        
        # Convert JSON3.Object to Dict
        user_data = Dict{String, Any}()
        for (k, v) in pairs(request_body)
            user_data[string(k)] = v
        end
        
        # Validate required fields
        if !haskey(user_data, "user_id") || isempty(get(user_data, "user_id", ""))
            error_response = Dict(
                "success" => false,
                "error" => "user_id is required",
                "example" => Dict(
                    "user_id" => "alice_trader_001",
                    "solana_wallet" => "9WzDXwBbmkg8ZTbNMqUxvQRAyrZzDsGYdLVL9zYtAWWM",
                    "ethereum_wallet" => "0x742d35Cc6634C0532925a3b8D48C405fD75d4CaD",
                    "email" => "alice@example.com",
                    "discord_id" => "alice#1234"
                )
            )
            return HTTP.Response(400, headers, JSON3.write(error_response))
        end
        
        # Register user
        result = UserManagement.register_user(user_data)
        
        if result["success"]
            @info "User registered successfully" user_id=result["user_id"]
            return HTTP.Response(200, headers, JSON3.write(result))
        else
            @warn "User registration failed" error=result["error"]
            return HTTP.Response(400, headers, JSON3.write(result))
        end
        
    catch e
        @error "User registration endpoint error" exception=e
        error_response = Dict("success" => false, "error" => "Failed to process registration request")
        return HTTP.Response(500, headers, JSON3.write(error_response))
    end
end

"""
Handle policy setting
POST /api/users/{user_id}/policy
"""
function handle_set_policy(request::HTTP.Request, headers::Vector{Pair{String, String}}, user_id::String)::HTTP.Response
    try
        # Parse request body
        request_body = JSON3.read(IOBuffer(request.body))
        
        # Validate user exists
        user_profile = UserManagement.get_user_profile(user_id)
        if user_profile === nothing
            error_response = Dict(
                "success" => false,
                "error" => "User not found",
                "user_id" => user_id
            )
            return HTTP.Response(404, headers, JSON3.write(error_response))
        end
        
        # Create policy object with defaults
        policy_data = Dict{String, Any}()
        for (k, v) in pairs(request_body)
            policy_data[string(k)] = v
        end
        
        # Set defaults for missing fields
        max_daily_spend = get(policy_data, "max_daily_spend_usd", 10000.0)
        max_per_incident = get(policy_data, "max_per_incident_usd", 1000.0)
        target_hf = get(policy_data, "target_health_factor", 1.5)
        critical_hf = get(policy_data, "critical_health_factor", 1.2)
        auto_protection = get(policy_data, "auto_protection_enabled", true)
        allowed_strategies = get(policy_data, "allowed_strategies", ["repay", "add_collateral"])
        notification_prefs = get(policy_data, "notification_preferences", ["discord", "email"])
        
        # Create policy struct
        policy = ProtectionPolicy(
            user_id,
            Float64(max_daily_spend),
            Float64(max_per_incident),
            Float64(target_hf),
            Float64(critical_hf),
            Bool(auto_protection),
            Vector{String}(allowed_strategies),
            Vector{String}(notification_prefs)
        )
        
        # Set policy
        result = UserManagement.set_policy(policy)
        
        if result["success"]
            @info "Policy set successfully" user_id=user_id
            return HTTP.Response(200, headers, JSON3.write(result))
        else
            @warn "Policy setting failed" user_id=user_id error=result["error"]
            return HTTP.Response(400, headers, JSON3.write(result))
        end
        
    catch e
        @error "Policy setting endpoint error" exception=e user_id=user_id
        error_response = Dict("success" => false, "error" => "Failed to process policy request")
        return HTTP.Response(500, headers, JSON3.write(error_response))
    end
end

"""
Handle user status query
GET /api/users/{user_id}/status
"""
function handle_user_status(request::HTTP.Request, headers::Vector{Pair{String, String}}, user_id::String)::HTTP.Response
    try
        # Get user profile
        user_profile = UserManagement.get_user_profile(user_id)
        if user_profile === nothing
            error_response = Dict(
                "success" => false,
                "error" => "User not found",
                "user_id" => user_id
            )
            return HTTP.Response(404, headers, JSON3.write(error_response))
        end
        
        # Get user policy
        user_policy = UserManagement.get_user_policy(user_id)
        
        # Create response
        response_data = Dict(
            "success" => true,
            "user_id" => user_id,
            "profile" => user_profile,
            "policy" => user_policy,
            "monitoring_status" => Dict(
                "active" => user_profile !== nothing,
                "wallets_monitored" => count_monitored_wallets(user_profile),
                "last_check" => string(now()),
                "alerts_enabled" => user_policy !== nothing ? get(user_policy, "auto_protection_enabled", false) : false
            ),
            "timestamp" => string(now())
        )
        
        @info "User status retrieved" user_id=user_id
        return HTTP.Response(200, headers, JSON3.write(response_data))
        
    catch e
        @error "User status endpoint error" exception=e user_id=user_id
        error_response = Dict("success" => false, "error" => "Failed to get user status")
        return HTTP.Response(500, headers, JSON3.write(error_response))
    end
end

"""
Helper to count monitored wallets
"""
function count_monitored_wallets(profile::Union{Dict, Nothing})::Int
    profile === nothing && return 0
    
    count = 0
    if get(profile, "solana_wallet", nothing) !== nothing
        count += 1
    end
    if get(profile, "ethereum_wallet", nothing) !== nothing
        count += 1
    end
    return count
end

end # module UserRoutes
