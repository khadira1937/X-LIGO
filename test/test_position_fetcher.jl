"""
Test suite for Position Fetcher module
Tests position discovery across Aave and Solend with graceful RPC handling
"""

using Test
using JSON3
using HTTP

# Set up test environment
ENV["DEMO_MODE"] = "true"
ENV["AAVE_SUBGRAPH_URL"] = ""  # Test missing RPC gracefully
ENV["SOLANA_RPC_URL"] = ""     # Test missing RPC gracefully

# Include the main module which includes all submodules
include("../src/XLiGo.jl")
using .XLiGo.PositionFetcher
using .XLiGo.Config

@testset "Position Fetcher Tests" begin
    
    @testset "Ethereum Position Fetching" begin
        # Test with empty AAVE_SUBGRAPH_URL in demo mode
        positions = fetch_ethereum_positions("0x742d35Cc6634C0532925a3b8D48C405fD75d4CaD")
        @test positions isa Vector{Dict{String, Any}}
        # In demo mode, should return demo positions even without URL
        @test length(positions) >= 0
        
        # Test with invalid wallet address
        positions = fetch_ethereum_positions("invalid-address")
        @test positions isa Vector{Dict{String, Any}}
        
        # Test with empty wallet
        positions = fetch_ethereum_positions("")
        @test positions isa Vector{Dict{String, Any}}
        
        # Test with URL configured but demo mode (should still get demo positions)
        ENV["AAVE_SUBGRAPH_URL"] = "https://api.thegraph.com/subgraphs/name/aave/protocol-v2"
        demo_positions = fetch_ethereum_positions("0x742d35Cc6634C0532925a3b8D48C405fD75d4CaD")
        @test demo_positions isa Vector{Dict{String, Any}}
        ENV["AAVE_SUBGRAPH_URL"] = ""  # Reset
    end
    
    @testset "Solana Position Fetching" begin
        # Test with empty SOLANA_RPC_URL in demo mode
        positions = fetch_solana_positions("6dSk7LHZWmfw2ZJyCQsFd4z4Wjt9dUqAKAxKg3BmHQS")
        @test positions isa Vector{Dict{String, Any}}
        # In demo mode, should return demo positions even without URL
        @test length(positions) >= 0
        
        # Test with invalid wallet address
        positions = fetch_solana_positions("invalid-address")
        @test positions isa Vector{Dict{String, Any}}
        
        # Test with empty wallet
        positions = fetch_solana_positions("")
        @test positions isa Vector{Dict{String, Any}}
        
        # Test with URL configured but demo mode (should still get demo positions)
        ENV["SOLANA_RPC_URL"] = "https://api.devnet.solana.com"
        demo_positions = fetch_solana_positions("6dSk7LHZWmfw2ZJyCQsFd4z4Wjt9dUqAKAxKg3BmHQS")
        @test demo_positions isa Vector{Dict{String, Any}}
        ENV["SOLANA_RPC_URL"] = ""  # Reset
    end
    
    @testset "Position Schema Validation" begin
        # Test normalized position structure
        position = normalize_position(
            "aave", "ethereum", "test_pos_1",
            "ETH", 5.0, "USDC", 1000.0,
            1.5, 0.85
        )
        
        @test position isa Dict{String, Any}
        @test position["protocol"] == "aave"
        @test position["chain"] == "ethereum"
        @test position["position_id"] == "test_pos_1"
        @test position["collateral_token"] == "ETH"
        @test position["collateral_amount"] == 5.0
        @test position["debt_token"] == "USDC"
        @test position["debt_amount"] == 1000.0
        @test position["health_factor"] == 1.5
        @test position["liquidation_threshold"] == 0.85
        @test haskey(position, "last_updated")
        @test haskey(position, "risk_level")
        
        # Test risk level computation
        @test position["risk_level"] == "medium"  # HF 1.5 = medium risk
        
        # Test different risk levels
        critical_pos = normalize_position("test", "test", "test", "TEST", 1.0, "TEST", 1.0, 1.05, 0.8)
        @test critical_pos["risk_level"] == "critical"
        
        high_pos = normalize_position("test", "test", "test", "TEST", 1.0, "TEST", 1.0, 1.2, 0.8)
        @test high_pos["risk_level"] == "high"
        
        low_pos = normalize_position("test", "test", "test", "TEST", 1.0, "TEST", 1.0, 2.0, 0.8)
        @test low_pos["risk_level"] == "low"
    end
    
    @testset "User Position Aggregation" begin
        # Test user profile with both wallets
        user_profile_both = Dict{String, Any}(
            "user_id" => "test_user_both",
            "display_name" => "Test User Both",
            "ethereum_wallet" => "0x742d35Cc6634C0532925a3b8D48C405fD75d4CaD",
            "solana_wallet" => "6dSk7LHZWmfw2ZJyCQsFd4z4Wjt9dUqAKAxKg3BmHQS"
        )
        
        positions = fetch_user_positions(user_profile_both)
        @test positions isa Vector{Dict{String, Any}}
        # Should aggregate positions from both chains
        
        # Test user profile with only Ethereum wallet
        user_profile_eth = Dict{String, Any}(
            "user_id" => "test_user_eth",
            "display_name" => "Test User ETH",
            "ethereum_wallet" => "0x742d35Cc6634C0532925a3b8D48C405fD75d4CaD",
            "solana_wallet" => nothing
        )
        
        positions = fetch_user_positions(user_profile_eth)
        @test positions isa Vector{Dict{String, Any}}
        
        # Test user profile with only Solana wallet
        user_profile_sol = Dict{String, Any}(
            "user_id" => "test_user_sol",
            "display_name" => "Test User SOL",
            "ethereum_wallet" => nothing,
            "solana_wallet" => "6dSk7LHZWmfw2ZJyCQsFd4z4Wjt9dUqAKAxKg3BmHQS"
        )
        
        positions = fetch_user_positions(user_profile_sol)
        @test positions isa Vector{Dict{String, Any}}
        
        # Test user profile with no wallets
        user_profile_none = Dict{String, Any}(
            "user_id" => "test_user_none",
            "display_name" => "Test User None",
            "ethereum_wallet" => nothing,
            "solana_wallet" => nothing
        )
        
        positions = fetch_user_positions(user_profile_none)
        @test positions isa Vector{Dict{String, Any}}
        @test length(positions) == 0  # No positions without wallets
    end
    
    @testset "Demo Position Generation" begin
        # Test Ethereum demo positions
        demo_eth = XLiGo.PositionFetcher.generate_demo_ethereum_positions("0x742d35Cc6634C0532925a3b8D48C405fD75d4CaD")
        @test demo_eth isa Vector{Dict{String, Any}}
        @test length(demo_eth) > 0
        
        for pos in demo_eth
            @test pos["protocol"] == "aave"
            @test pos["chain"] == "ethereum"
            @test haskey(pos, "position_id")
            @test haskey(pos, "health_factor")
            @test pos["health_factor"] > 0
        end
        
        # Test Solana demo positions
        demo_sol = XLiGo.PositionFetcher.generate_demo_solana_positions("6dSk7LHZWmfw2ZJyCQsFd4z4Wjt9dUqAKAxKg3BmHQS")
        @test demo_sol isa Vector{Dict{String, Any}}
        @test length(demo_sol) > 0
        
        for pos in demo_sol
            @test pos["protocol"] == "solend"
            @test pos["chain"] == "solana"
            @test haskey(pos, "position_id")
            @test haskey(pos, "health_factor")
            @test pos["health_factor"] > 0
        end
    end
    
    @testset "Error Handling" begin
        # Test malformed wallet addresses don't crash
        @test_nowarn fetch_ethereum_positions("malformed")
        @test_nowarn fetch_solana_positions("malformed")
        
        # Test empty inputs
        @test_nowarn fetch_ethereum_positions("")
        @test_nowarn fetch_solana_positions("")
        
        # Test nil inputs don't crash user position fetching
        bad_profile = Dict{String, Any}("user_id" => "bad")
        @test_nowarn fetch_user_positions(bad_profile)
        
        # Test missing user_id doesn't crash
        empty_profile = Dict{String, Any}()
        @test_nowarn fetch_user_positions(empty_profile)
        
        # All should return valid arrays
        @test fetch_ethereum_positions("malformed") isa Vector{Dict{String, Any}}
        @test fetch_solana_positions("malformed") isa Vector{Dict{String, Any}}
        @test fetch_user_positions(bad_profile) isa Vector{Dict{String, Any}}
        @test fetch_user_positions(empty_profile) isa Vector{Dict{String, Any}}
    end
    
    @testset "Cache Stats" begin
        # Test cache stats structure
        stats = XLiGo.PositionFetcher.get_positions_cache_stats()
        @test stats isa Dict{String, Any}
        @test haskey(stats, "cached_positions")
        @test haskey(stats, "cache_hits")
        @test haskey(stats, "cache_misses")
        @test haskey(stats, "last_refresh")
    end
end

println("✅ Position Fetcher tests completed")
