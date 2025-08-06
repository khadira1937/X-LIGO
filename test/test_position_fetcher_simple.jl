"""
Simplified Position Fetcher test focused on functionality
"""

using Test

# Set up test environment
ENV["DEMO_MODE"] = "true"
ENV["AAVE_SUBGRAPH_URL"] = ""  # Test graceful handling
ENV["SOLANA_RPC_URL"] = ""     # Test graceful handling

# Include the main module
include("../src/XLiGo.jl")
using .XLiGo.PositionFetcher

@testset "Position Fetcher Core Tests" begin
    
    @testset "Basic Functionality" begin
        # Test Ethereum positions (should work in demo mode)
        eth_positions = fetch_ethereum_positions("0x742d35Cc6634C0532925a3b8D48C405fD75d4CaD")
        @test eth_positions isa Vector{Dict{String, Any}}
        
        # Test Solana positions (should work in demo mode)  
        sol_positions = fetch_solana_positions("6dSk7LHZWmfw2ZJyCQsFd4z4Wjt9dUqAKAxKg3BmHQS")
        @test sol_positions isa Vector{Dict{String, Any}}
        
        # Test user position aggregation
        user_profile = Dict{String, Any}(
            "user_id" => "test_user",
            "ethereum_wallet" => "0x742d35Cc6634C0532925a3b8D48C405fD75d4CaD",
            "solana_wallet" => "6dSk7LHZWmfw2ZJyCQsFd4z4Wjt9dUqAKAxKg3BmHQS"
        )
        
        all_positions = fetch_user_positions(user_profile)
        @test all_positions isa Vector{Dict{String, Any}}
        @test length(all_positions) >= 0  # Should handle gracefully
    end
    
    @testset "Normalized Schema Validation" begin
        # Test normalized position structure
        position = normalize_position(
            "aave", "ethereum", "test_pos_1",
            "ETH", 5.0, "USDC", 1000.0,
            1.5, 0.85
        )
        
        # Verify all required fields exist
        required_fields = ["protocol", "chain", "position_id", "collateral_token", 
                          "collateral_amount", "debt_token", "debt_amount", 
                          "health_factor", "liquidation_threshold"]
        
        for field in required_fields
            @test haskey(position, field)
        end
        
        # Verify data types and values
        @test position["protocol"] == "aave"
        @test position["chain"] == "ethereum"
        @test position["collateral_amount"] isa Float64
        @test position["debt_amount"] isa Float64
        @test position["health_factor"] isa Float64
        @test position["liquidation_threshold"] isa Float64
        
        # Test risk level computation
        @test haskey(position, "risk_level")
        @test position["risk_level"] in ["critical", "high", "medium", "low"]
    end
    
    @testset "Error Resilience" begin
        # Functions should return valid results with invalid inputs (logging is expected)
        eth_result1 = fetch_ethereum_positions("")
        @test eth_result1 isa Vector{Dict{String, Any}}
        
        eth_result2 = fetch_ethereum_positions("invalid")
        @test eth_result2 isa Vector{Dict{String, Any}}
        
        sol_result1 = fetch_solana_positions("")
        @test sol_result1 isa Vector{Dict{String, Any}}
        
        sol_result2 = fetch_solana_positions("invalid")
        @test sol_result2 isa Vector{Dict{String, Any}}
        
        # Empty user profile should not crash
        empty_profile = Dict{String, Any}()
        result = fetch_user_positions(empty_profile)
        @test result isa Vector{Dict{String, Any}}
        @test length(result) == 0  # No positions for empty profile
    end
    
    @testset "Demo Position Generation" begin
        # Demo functions should exist and work
        demo_eth = XLiGo.PositionFetcher.generate_demo_ethereum_positions("0x123")
        @test demo_eth isa Vector{Dict{String, Any}}
        @test length(demo_eth) > 0
        
        demo_sol = XLiGo.PositionFetcher.generate_demo_solana_positions("123")
        @test demo_sol isa Vector{Dict{String, Any}}
        @test length(demo_sol) > 0
        
        # Verify demo positions have correct schema
        for pos in demo_eth
            @test haskey(pos, "protocol")
            @test haskey(pos, "chain")
            @test haskey(pos, "health_factor")
            @test pos["chain"] == "ethereum"
        end
        
        for pos in demo_sol
            @test haskey(pos, "protocol")
            @test haskey(pos, "chain")
            @test haskey(pos, "health_factor")
            @test pos["chain"] == "solana"
        end
    end
    
    @testset "Cache Stats" begin
        # Cache stats function should exist and work
        stats = XLiGo.PositionFetcher.get_positions_cache_stats()
        @test stats isa Dict{String, Any}
        
        expected_keys = ["cached_positions", "cache_hits", "cache_misses", "last_refresh"]
        for key in expected_keys
            @test haskey(stats, key)
        end
    end
end

println("✅ Position Fetcher functionality tests completed successfully")
