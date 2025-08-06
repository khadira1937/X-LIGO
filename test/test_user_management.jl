"""
Test suite for User Management functionality
"""

using Test
using Dates

# Include the project modules
include("../src/XLiGo.jl")
using .XLiGo.UserManagement
using .XLiGo.Config

@testset "User Management Tests" begin
    
    @testset "Wallet Address Validation" begin
        # Test valid Solana addresses (base58, 44 chars)
        @test is_valid_solana_address("6dSk7LHZWmfw2ZJyCQsFd4z4Wjt9dUqAKAxKg3BmHQS") == true
        @test is_valid_solana_address("9WzDXwBbmkg8ZTbNMqUxvQRAyrZzDsGYdLVL9zYtAWWM") == true
        
        # Test invalid Solana addresses
        @test is_valid_solana_address("invalid") == false
        @test is_valid_solana_address("") == false
        @test is_valid_solana_address(nothing) == false
        @test is_valid_solana_address("6dSk7LHZWmfw2ZJyCQsFd4z4Wjt9dUqAKAxKg3BmHQStoolong") == false
        
        # Test valid Ethereum addresses (0x + 40 hex chars)
        @test is_valid_ethereum_address("0x742d35Cc6634C0532925a3b8D48C405fD75d4CaD") == true
        @test is_valid_ethereum_address("0x742D35Cc6634C0532925a3b8D902D86C01a5B1B1") == true
        
        # Test invalid Ethereum addresses  
        @test is_valid_ethereum_address("invalid") == false
        @test is_valid_ethereum_address("") == false
        @test is_valid_ethereum_address(nothing) == false
        @test is_valid_ethereum_address("742d35Cc6634C0532925a3b8D48C405fD75d4CaD") == false  # no 0x
        @test is_valid_ethereum_address("0x742d35Cc6634C0532925a3b8D48C405fD75d4CaDtoolong") == false
    end
    
    @testset "User Registration - Demo Mode" begin
        # Ensure demo mode
        ENV["DEMO_MODE"] = "true"
        
        # Test successful registration
        user_data = Dict(
            "user_id" => "test_user_demo",
            "display_name" => "Demo Test User",
            "solana_wallet" => "6dSk7LHZWmfw2ZJyCQsFd4z4Wjt9dUqAKAxKg3BmHQS",
            "ethereum_wallet" => "0x742d35Cc6634C0532925a3b8D48C405fD75d4CaD",
            "email" => "demo@test.com",
            "discord_id" => "demo#1234"
        )
        
        result = register_user(user_data)
        @test result["success"] == true
        @test haskey(result, "user_id")
        @test result["user_id"] == "test_user_demo"
        
        # Test retrieval
        profile = get_user_profile("test_user_demo")
        @test profile !== nothing
        @test profile["user_id"] == "test_user_demo"
        @test profile["display_name"] == "Demo Test User"
        @test profile["solana_wallet"] == "6dSk7LHZWmfw2ZJyCQsFd4z4Wjt9dUqAKAxKg3BmHQS"
        @test profile["ethereum_wallet"] == "0x742d35Cc6634C0532925a3b8D48C405fD75d4CaD"
        
        # Test duplicate registration
        duplicate_result = register_user(user_data)
        @test duplicate_result["success"] == false
        @test occursin("already exists", duplicate_result["error"])
    end
    
    @testset "User Registration Validation" begin
        ENV["DEMO_MODE"] = "true"
        
        # Test missing user_id
        result = register_user(Dict("display_name" => "Test"))
        @test result["success"] == false
        @test occursin("user_id", result["error"])
        
        # Test missing display_name
        result = register_user(Dict("user_id" => "test"))
        @test result["success"] == false
        @test occursin("display_name", result["error"])
        
        # Test invalid Solana wallet
        result = register_user(Dict(
            "user_id" => "test_invalid_sol",
            "display_name" => "Test User",
            "solana_wallet" => "invalid_solana_address"
        ))
        @test result["success"] == false
        @test occursin("Invalid Solana wallet", result["error"])
        
        # Test invalid Ethereum wallet
        result = register_user(Dict(
            "user_id" => "test_invalid_eth", 
            "display_name" => "Test User",
            "ethereum_wallet" => "invalid_eth_address"
        ))
        @test result["success"] == false
        @test occursin("Invalid Ethereum wallet", result["error"])
        
        # Test no wallets provided
        result = register_user(Dict(
            "user_id" => "test_no_wallets",
            "display_name" => "Test User"
        ))
        @test result["success"] == false
        @test occursin("At least one wallet", result["error"])
        
        # Test Solana only (should succeed)
        result = register_user(Dict(
            "user_id" => "test_solana_only",
            "display_name" => "Solana User",
            "solana_wallet" => "6dSk7LHZWmfw2ZJyCQsFd4z4Wjt9dUqAKAxKg3BmHQS"
        ))
        @test result["success"] == true
        
        # Test Ethereum only (should succeed)
        result = register_user(Dict(
            "user_id" => "test_ethereum_only",
            "display_name" => "Ethereum User", 
            "ethereum_wallet" => "0x742d35Cc6634C0532925a3b8D48C405fD75d4CaD"
        ))
        @test result["success"] == true
    end
    
    @testset "Protection Policy Management" begin
        ENV["DEMO_MODE"] = "true"
        
        # Register a test user first
        user_data = Dict(
            "user_id" => "policy_test_user",
            "display_name" => "Policy Test User",
            "solana_wallet" => "6dSk7LHZWmfw2ZJyCQsFd4z4Wjt9dUqAKAxKg3BmHQS"
        )
        register_user(user_data)
        
        # Test policy creation
        policy = ProtectionPolicy(
            "policy_test_user",
            10000.0,  # max_daily_spend_usd
            5000.0,   # max_per_incident_usd
            2.0,      # target_health_factor
            1.5,      # critical_health_factor
            true,     # auto_protection_enabled
            ["liquidation", "hedge"],  # allowed_strategies
            ["discord", "email"]       # notification_preferences
        )
        
        result = set_policy(policy)
        @test result["success"] == true
        
        # Test policy retrieval
        retrieved_policy = get_user_policy("policy_test_user")
        @test retrieved_policy !== nothing
        @test retrieved_policy["user_id"] == "policy_test_user"
        @test retrieved_policy["max_daily_spend_usd"] == 10000.0
        @test retrieved_policy["auto_protection_enabled"] == true
        @test length(retrieved_policy["allowed_strategies"]) == 2
    end
    
    @testset "List Active Users" begin
        ENV["DEMO_MODE"] = "true"
        
        # Get initial count
        initial_users = list_active_users()
        initial_count = length(initial_users)
        
        # Register additional users
        for i in 1:3
            user_data = Dict(
                "user_id" => "list_test_user_$i",
                "display_name" => "List Test User $i",
                "solana_wallet" => "6dSk7LHZWmfw2ZJyCQsFd4z4Wjt9dUqAKAxKg3BmHQS"
            )
            register_user(user_data)
        end
        
        # Check updated count
        updated_users = list_active_users()
        @test length(updated_users) == initial_count + 3
        
        # Verify user data structure
        user = updated_users[end]  # Get last user
        @test haskey(user, "user_id")
        @test haskey(user, "display_name") 
        @test haskey(user, "solana_wallet")
        @test haskey(user, "created_at")
    end
end

println("✅ User Management tests completed")
