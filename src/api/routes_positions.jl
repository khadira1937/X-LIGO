"""
Position API Routes

Handles HTTP endpoints for position discovery and monitoring across chains.
Integrates with PositionFetcher to provide normalized position data.
"""
module PositionRoutes

using HTTP
using JSON3
using Dates
using Logging
using ..UserManagement
using ..PositionFetcher

export handle_position_routes

"""
Handle position-related HTTP routes
"""
function handle_position_routes(request::HTTP.Request)::HTTP.Response
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
        
        # GET /api/users/{user_id}/positions
        if request.method == "GET" && length(path_parts) >= 5 && 
           path_parts[2] == "api" && path_parts[3] == "users" && path_parts[5] == "positions"
            user_id = path_parts[4]
            return handle_user_positions(request, headers, user_id)
            
        # POST /api/positions/monitor
        elseif request.method == "POST" && length(path_parts) >= 4 && 
               path_parts[2] == "api" && path_parts[3] == "positions" && path_parts[4] == "monitor"
            return handle_monitor_position(request, headers)
            
        else
            error_response = Dict("error" => "Position route not found", "path" => request.target)
            return HTTP.Response(404, headers, JSON3.write(error_response))
        end
        
    catch e
        @error "Position routes error" exception=e request.target
        error_response = Dict("error" => "Internal server error", "message" => string(e))
        return HTTP.Response(500, headers, JSON3.write(error_response))
    end
end

"""
Handle user positions query
GET /api/users/{user_id}/positions
"""
function handle_user_positions(request::HTTP.Request, headers::Vector{Pair{String, String}}, user_id::String)::HTTP.Response
    try
        @info "Fetching positions for user" user_id=user_id
        
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
        
        # Fetch positions across all chains
        positions = PositionFetcher.fetch_user_positions(user_profile)
        
        # Compute summary statistics
        total_positions = length(positions)
        total_collateral_usd = sum(pos -> get(pos, "collateral_amount", 0.0) * get_token_price_usd(get(pos, "collateral_token", "")), positions)
        total_debt_usd = sum(pos -> get(pos, "debt_amount", 0.0) * get_token_price_usd(get(pos, "debt_token", "")), positions)
        
        # Risk analysis
        risk_summary = analyze_position_risks(positions)
        
        # Create response
        response_data = Dict(
            "success" => true,
            "user_id" => user_id,
            "positions" => positions,
            "summary" => Dict(
                "total_positions" => total_positions,
                "total_collateral_usd" => round(total_collateral_usd, digits=2),
                "total_debt_usd" => round(total_debt_usd, digits=2),
                "net_value_usd" => round(total_collateral_usd - total_debt_usd, digits=2),
                "protocols" => unique([get(pos, "protocol", "") for pos in positions]),
                "chains" => unique([get(pos, "chain", "") for pos in positions])
            ),
            "risk_analysis" => risk_summary,
            "timestamp" => string(Dates.now())
        )
        
        @info "Retrieved positions for user" user_id=user_id count=total_positions
        return HTTP.Response(200, headers, JSON3.write(response_data))
        
    catch e
        @error "User positions endpoint error" exception=e user_id=user_id
        error_response = Dict(
            "success" => false, 
            "error" => "Failed to fetch user positions",
            "user_id" => user_id,
            "positions" => [],
            "summary" => Dict("total_positions" => 0)
        )
        return HTTP.Response(500, headers, JSON3.write(error_response))
    end
end

"""
Handle position monitoring request
POST /api/positions/monitor
"""
function handle_monitor_position(request::HTTP.Request, headers::Vector{Pair{String, String}})::HTTP.Response
    try
        # Parse request body
        request_body = JSON3.read(IOBuffer(request.body))
        
        # Convert to Dict
        monitor_data = Dict{String, Any}()
        for (k, v) in pairs(request_body)
            monitor_data[string(k)] = v
        end
        
        # Validate required fields
        user_id = get(monitor_data, "user_id", "")
        if isempty(user_id)
            error_response = Dict(
                "success" => false,
                "error" => "user_id is required",
                "example" => Dict(
                    "user_id" => "alice_001",
                    "protocol" => "aave",
                    "chain" => "ethereum",
                    "position_id" => "optional_specific_position"
                )
            )
            return HTTP.Response(400, headers, JSON3.write(error_response))
        end
        
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
        
        # Extract monitoring parameters
        protocol = get(monitor_data, "protocol", "all")
        chain = get(monitor_data, "chain", "all") 
        position_id = get(monitor_data, "position_id", nothing)
        
        # Start monitoring (placeholder for now)
        monitoring_result = start_position_monitoring(user_id, protocol, chain, position_id)
        
        # Create response
        response_data = Dict(
            "success" => true,
            "user_id" => user_id,
            "monitoring" => monitoring_result,
            "message" => "Position monitoring configured successfully",
            "timestamp" => string(now())
        )
        
        @info "Position monitoring configured" user_id=user_id protocol=protocol chain=chain
        return HTTP.Response(200, headers, JSON3.write(response_data))
        
    catch e
        @error "Position monitoring endpoint error" exception=e
        error_response = Dict("success" => false, "error" => "Failed to configure monitoring")
        return HTTP.Response(500, headers, JSON3.write(error_response))
    end
end

"""
Analyze risks across user positions
"""
function analyze_position_risks(positions::Vector{Dict{String, Any}})::Dict{String, Any}
    risk_counts = Dict("critical" => 0, "high" => 0, "medium" => 0, "low" => 0)
    min_health_factor = Inf
    avg_health_factor = 0.0
    
    if !isempty(positions)
        health_factors = [get(pos, "health_factor", 1.0) for pos in positions]
        min_health_factor = minimum(health_factors)
        avg_health_factor = sum(health_factors) / length(health_factors)
        
        for pos in positions
            risk_level = get(pos, "risk_level", "low")
            risk_counts[risk_level] = get(risk_counts, risk_level, 0) + 1
        end
    end
    
    return Dict(
        "total_positions" => length(positions),
        "risk_distribution" => risk_counts,
        "min_health_factor" => min_health_factor == Inf ? nothing : round(min_health_factor, digits=3),
        "avg_health_factor" => isempty(positions) ? nothing : round(avg_health_factor, digits=3),
        "overall_risk" => determine_overall_risk(min_health_factor, risk_counts)
    )
end

"""
Determine overall risk level
"""
function determine_overall_risk(min_hf::Float64, risk_counts::Dict{String, Int})::String
    if risk_counts["critical"] > 0 || min_hf <= 1.1
        return "critical"
    elseif risk_counts["high"] > 0 || min_hf <= 1.3
        return "high"
    elseif risk_counts["medium"] > 0 || min_hf <= 1.5
        return "medium"
    else
        return "low"
    end
end

"""
Start position monitoring (placeholder implementation)
"""
function start_position_monitoring(user_id::String, protocol::String, chain::String, position_id::Union{String, Nothing})::Dict{String, Any}
    # TODO: Integration with watchers in step 3
    return Dict(
        "status" => "active",
        "protocol" => protocol,
        "chain" => chain,
        "position_id" => position_id,
        "monitoring_interval" => get(ENV, "WATCH_INTERVAL_MS", "5000"),
        "alerts_enabled" => true
    )
end

"""
Get token price in USD (placeholder - would integrate with price feeds)
"""
function get_token_price_usd(token::String)::Float64
    # Mock prices for demo
    prices = Dict(
        "ETH" => 3200.0,
        "USDC" => 1.0,
        "USDT" => 1.0,
        "SOL" => 140.0,
        "BTC" => 65000.0
    )
    return get(prices, uppercase(token), 1.0)
end

end # module PositionRoutes
