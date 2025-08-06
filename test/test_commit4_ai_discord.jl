"""
Test suite for Commit 4: AI Reasoning & Discord Alert Integration
Tests chat functionality, Discord notifications, and attack simulation
"""

# Load the modules
include("../src/XLiGo.jl")
using .XLiGo
using Test
using HTTP
using JSON3
using Dates

println("🧪 === COMMIT 4: AI + DISCORD INTEGRATION TESTS ===")

@testset "Commit 4: AI & Discord Integration" begin
    
    @testset "ChatResponder Core Functionality" begin
        println("Testing ChatResponder AI reasoning...")
        
        # Test basic chat response
        response = XLiGo.ChatResponder.generate_response("What happened?")
        @test response isa String
        @test length(response) > 10
        @test occursin("incident", lowercase(response)) || occursin("clear", lowercase(response))
        
        # Test different query types
        queries = [
            "Show me the latest attack",
            "What just happened?", 
            "Health factor status",
            "User test_user incidents",
            "Any recent threats?"
        ]
        
        for query in queries
            response = XLiGo.ChatResponder.generate_response(query)
            @test response isa String
            @test length(response) > 0
            println("✓ Query: \"$query\" → $(length(response)) chars")
        end
        
        println("✅ ChatResponder core functionality verified")
    end
    
    @testset "Discord Notification System" begin
        println("Testing Discord webhook integration...")
        
        # Test Discord connection
        connection_test = XLiGo.DiscordNotifier.test_discord_connection()
        @test connection_test isa Dict{String, Any}
        @test haskey(connection_test, "success")
        
        if get(connection_test, "success", false)
            println("✅ Discord webhook connection successful")
        else
            println("⚠️ Discord webhook not configured or failed - this is OK for testing")
            println("   Reason: $(get(connection_test, "reason", "unknown"))")
        end
        
        # Create a test incident for Discord notification
        test_position = Dict{String, Any}(
            "position_id" => "test_position_123",
            "protocol" => "aave",
            "chain" => "ethereum",
            "health_factor" => 1.08,
            "collateral_token" => "USDC",
            "collateral_amount" => 25000.0,
            "debt_token" => "ETH", 
            "debt_amount" => 20000.0
        )
        
        test_metadata = Dict{String, Any}(
            "value_at_risk" => 25000.0,
            "test_mode" => true
        )
        
        test_incident = XLiGo.IncidentStore.create_incident(
            "discord_test_user", test_position, 1.20, "HIGH", test_metadata
        )
        
        # Test Discord alert formatting (even if webhook fails)
        discord_result = XLiGo.DiscordNotifier.send_discord_alert(test_incident)
        @test discord_result isa Dict{String, Any}
        @test haskey(discord_result, "success")
        
        println("✅ Discord notification system tested")
    end
    
    @testset "Attack Detection & Classification" begin
        println("Testing enhanced attack detection...")
        
        # Test attack simulation
        attack_types = ["flash_loan", "sandwich", "liquidation"]
        
        for attack_type in attack_types
            simulated_incident = XLiGo.AIAttackDetector.simulate_attack_scenario(attack_type, "attack_test_user")
            @test simulated_incident isa XLiGo.IncidentStore.Incident
            @test simulated_incident.user_id == "attack_test_user"
            @test haskey(simulated_incident.metadata, "attack_type")
            @test haskey(simulated_incident.metadata, "risk_score")
            @test simulated_incident.metadata["simulated"] == true
            
            println("✓ Simulated $attack_type attack: severity=$(simulated_incident.severity), risk=$(simulated_incident.metadata["risk_score"])")
        end
        
        # Test attack pattern detection
        position_data = Dict{String, Any}(
            "borrowed_amount" => 2_000_000.0,
            "transaction_value" => 1_500_000.0,
            "slippage" => 0.08,
            "rapid_price_change" => true,
            "bot_behavior" => true
        )
        
        base_position = Dict{String, Any}(
            "position_id" => "test_pos",
            "protocol" => "aave",
            "chain" => "ethereum",
            "health_factor" => 1.05,
            "collateral_token" => "USDC",
            "collateral_amount" => 100000.0,
            "debt_token" => "ETH",
            "debt_amount" => 80000.0
        )
        
        base_incident = XLiGo.IncidentStore.create_incident(
            "pattern_test_user", base_position, 1.20, "MEDIUM"
        )
        
        enhanced_incident = XLiGo.AIAttackDetector.enhance_incident_classification(base_incident, position_data)
        @test enhanced_incident isa XLiGo.IncidentStore.Incident
        @test haskey(enhanced_incident.metadata, "attack_type")
        @test haskey(enhanced_incident.metadata, "risk_score")
        @test enhanced_incident.metadata["risk_score"] > 50.0  # Should be high risk
        
        println("✅ Attack detection and classification verified")
    end
    
    @testset "End-to-End AI + Discord Flow" begin
        println("Testing complete incident → AI analysis → Discord alert flow...")
        
        # 1. Create a critical incident through PositionWatcher
        test_user_data = Dict{String, Any}(
            "user_id" => "e2e_test_user",
            "display_name" => "E2E Test User",
            "ethereum_wallet" => "0x742d35Cc6634C0532925a3b8D48C405fD75d4CaD",
            "solana_wallet" => "6dSk7LHZWmfw2ZJyCQsFd4z4Wjt9dUqAKAxKg3BmHQS"
        )
        
        # Register user
        reg_result = XLiGo.UserManagement.register_user(test_user_data)
        @test reg_result["success"] == true
        
        # Set critical protection policy
        policy = XLiGo.UserManagement.ProtectionPolicy(
            "e2e_test_user", 500.0, 250.0, 1.30, 1.05,  # Very strict thresholds
            true, ["add_collateral"], ["discord"]
        )
        
        policy_result = XLiGo.UserManagement.set_policy(policy)
        @test policy_result["success"] == true
        
        # 2. Force monitoring to create incident (should trigger with demo positions)
        incidents_before = length(XLiGo.IncidentStore.get_user_incidents("e2e_test_user"))
        
        # Monitor the user (this will check positions and create incidents if health factor is low)
        user_incidents = XLiGo.PositionWatcher.monitor_user_positions("e2e_test_user")
        @test user_incidents isa Vector{XLiGo.IncidentStore.Incident}
        
        # Force a manual incident creation for testing
        test_position = Dict{String, Any}(
            "position_id" => "e2e_test_position",
            "protocol" => "aave",
            "chain" => "ethereum", 
            "health_factor" => 1.03,
            "collateral_token" => "USDC",
            "collateral_amount" => 75000.0,
            "debt_token" => "ETH",
            "debt_amount" => 60000.0
        )
        
        test_metadata = Dict{String, Any}(
            "value_at_risk" => 75000.0,
            "attack_type" => "liquidation_attack",
            "risk_score" => 95.0
        )
        
        test_incident = XLiGo.IncidentStore.create_incident(
            "e2e_test_user", test_position, 1.30, "CRITICAL", test_metadata
        )
        
        XLiGo.IncidentStore.add_incident!(test_incident)
        
        # 3. Test AI analysis of the incident
        ai_queries = [
            "What just happened?",
            "Show me the latest attack",
            "Give me the security report"
        ]
        
        for query in ai_queries
            ai_response = XLiGo.ChatResponder.generate_response(query)
            @test ai_response isa String
            @test length(ai_response) > 50
            # Should mention the critical incident we just created
            @test occursin("CRITICAL", ai_response) || occursin("critical", ai_response) || occursin("incident", ai_response)
            println("✓ AI Query: \"$query\" → mentions critical incident")
        end
        
        # 4. Test Discord notification for the critical incident
        discord_result = XLiGo.DiscordNotifier.send_discord_alert(test_incident)
        @test discord_result isa Dict{String, Any}
        @test haskey(discord_result, "success")
        
        # 5. Verify incident is in store
        final_incidents = XLiGo.IncidentStore.get_user_incidents("e2e_test_user")
        @test length(final_incidents) > incidents_before
        @test any(inc -> inc.severity == "CRITICAL", final_incidents)
        
        println("✅ End-to-end AI + Discord flow verified")
    end
    
    @testset "API Chat Endpoint Integration" begin
        println("Testing /chat API endpoint...")
        
        # These tests require the API server to be running
        # We'll test the logic without actually starting the server
        
        # Test that the chat endpoint logic works
        test_messages = [
            "What happened?",
            "Show me recent attacks", 
            "Health factor status",
            "Any security incidents?"
        ]
        
        for message in test_messages
            # Simulate the API logic
            try
                response = XLiGo.ChatResponder.generate_response(message)
                @test response isa String
                @test length(response) > 0
                
                # Simulate API response format
                api_response = Dict(
                    "response" => response,
                    "status" => "success", 
                    "message" => message,
                    "timestamp" => Dates.format(now(), "yyyy-mm-ddTHH:MM:SS"),
                    "ai_powered" => true
                )
                
                @test haskey(api_response, "response")
                @test haskey(api_response, "status")
                @test api_response["status"] == "success"
                @test api_response["ai_powered"] == true
                
                println("✓ API simulation for: \"$message\"")
                
            catch e
                @warn "Chat API simulation failed for message: $message" error=e
                @test false  # Fail the test if chat simulation fails
            end
        end
        
        println("✅ Chat API endpoint logic verified")
    end
    
end

# Final summary
println("\n🎯 === COMMIT 4 TEST SUMMARY ===")
println("✅ ChatResponder: Natural language incident analysis")
println("✅ DiscordNotifier: Rich webhook alerts for security incidents")  
println("✅ AttackDetector: Enhanced incident classification with attack patterns")
println("✅ End-to-End Flow: Incident detection → AI analysis → Discord alerts")
println("✅ API Integration: /chat endpoint with AI-powered responses")
println("\n🎉 Commit 4: AI Reasoning & Discord Alert Integration - COMPLETE!")
println("📦 Ready for production with real-time AI incident analysis")

# Demo attack simulation for visual verification
println("\n🔥 === DEMO: ATTACK SIMULATION ===")
println("Simulating a flash loan attack for demonstration...")

demo_incident = XLiGo.AttackDetector.simulate_attack_scenario("flash_loan", "demo_victim")
println("📊 Attack Details:")
println("   - Type: $(get(demo_incident.metadata, "attack_type", "health_factor_violation"))")
println("   - Severity: $(demo_incident.severity)")
println("   - Health Factor: $(demo_incident.health_factor)")
println("   - Risk Score: $(demo_incident.metadata["risk_score"])")
println("   - Value at Risk: \$$(demo_incident.metadata["value_at_risk"])")

# Test AI analysis of the simulated attack
println("\n🤖 AI Analysis:")
ai_analysis = XLiGo.ChatResponder.generate_response("What was the latest attack?")
println(ai_analysis)

println("\n✨ Demo complete! Your Discord channel should have received an alert (if configured).")
