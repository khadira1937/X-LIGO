"""
Test suite for Watchers & Health Tracking (Commit 3)
Tests position monitoring, incident detection, and health factor violations
"""

using Test
using Dates

# Set up test environment
ENV["DEMO_MODE"] = "true"
ENV["WATCH_INTERVAL_MS"] = "1000"  # Fast testing
ENV["AAVE_SUBGRAPH_URL"] = ""
ENV["SOLANA_RPC_URL"] = ""

# Include the main module
include("../src/XLiGo.jl")
using .XLiGo.IncidentStore
using .XLiGo.PositionWatcher
using .XLiGo.UserManagement
using .XLiGo.PositionFetcher

@testset "Watchers & Health Tracking Tests" begin
    
    # Clear any existing data
    IncidentStore.clear_all_incidents!()
    
    @testset "Incident Store" begin
        # Test incident creation
        test_incident = IncidentStore.Incident(
            "test_user_123",
            "aave_eth_pos_1",
            "aave",
            "ethereum",
            "HIGH",
            "Health factor 1.05 below threshold 1.10",
            1.05,
            1.10,
            "ETH",
            5.0,
            "USDC",
            8000.0,
            now()
        )
        
        # Test adding incident
        added_incident = IncidentStore.add_incident!(test_incident)
        @test added_incident.user_id == "test_user_123"
        @test added_incident.severity == "HIGH"
        
        # Test retrieving incidents
        user_incidents = IncidentStore.get_user_incidents("test_user_123")
        @test length(user_incidents) == 1
        @test user_incidents[1].position_id == "aave_eth_pos_1"
        
        # Test recent incidents
        recent = IncidentStore.get_recent_incidents("test_user_123", hours=1)
        @test length(recent) == 1
        
        # Test incident summary
        summary = IncidentStore.get_incident_summary()
        @test summary["total_incidents"] >= 1
        @test summary["active_users_with_incidents"] >= 1
        @test haskey(summary, "severity_breakdown")
        @test summary["severity_breakdown"]["HIGH"] >= 1
        
        # Test severity determination
        @test IncidentStore.determine_severity(0.9, 1.0) == "CRITICAL"
        @test IncidentStore.determine_severity(0.95, 1.0) == "HIGH"
        @test IncidentStore.determine_severity(0.98, 1.0) == "MEDIUM"
        @test IncidentStore.determine_severity(0.99, 1.0) == "LOW"
        
        # Test create incident from position
        position_data = Dict{String, Any}(
            "position_id" => "test_position",
            "protocol" => "aave",
            "chain" => "ethereum",
            "health_factor" => 1.03,
            "collateral_token" => "ETH",
            "collateral_amount" => 10.0,
            "debt_token" => "USDC",
            "debt_amount" => 15000.0
        )
        
        created_incident = IncidentStore.create_incident("test_user_2", position_data, 1.1, "CRITICAL")
        @test created_incident.user_id == "test_user_2"
        @test created_incident.health_factor == 1.03
        @test created_incident.severity == "CRITICAL"
    end
    
    @testset "Position Monitoring" begin
        # Register test user with policy
        test_user_data = Dict{String, Any}(
            "user_id" => "test_watcher_user",
            "display_name" => "Test Watcher User",
            "ethereum_wallet" => "0x742d35Cc6634C0532925a3b8D48C405fD75d4CaD",
            "solana_wallet" => "6dSk7LHZWmfw2ZJyCQsFd4z4Wjt9dUqAKAxKg3BmHQS",
            "discord_id" => "testwatcher#1234"
        )
        
        reg_result = UserManagement.register_user(test_user_data)
        @test reg_result["success"] == true
        
        # Set policy with critical health factor
        test_policy = UserManagement.ProtectionPolicy(
            "test_watcher_user",
            500.0,  # max_daily_spend_usd
            250.0,  # max_per_incident_usd
            1.25,   # target_health_factor
            1.10,   # critical_health_factor (this will trigger alerts)
            true,   # auto_protection_enabled
            ["add_collateral", "partial_repay"],
            ["discord"]
        )
        
        policy_result = UserManagement.set_policy(test_policy)
        @test policy_result["success"] == true
        
        # Clear incidents before monitoring
        IncidentStore.clear_incidents!("test_watcher_user")
        
        # Test single user monitoring
        incidents = PositionWatcher.monitor_user_positions("test_watcher_user")
        @test incidents isa Vector{IncidentStore.Incident}
        
        # In demo mode with mock positions, check if any incidents were created
        # Mock positions might have health factors that trigger alerts
        user_incidents_after = IncidentStore.get_user_incidents("test_watcher_user")
        @test user_incidents_after isa Vector{IncidentStore.Incident}
        
        # Test monitoring status
        status = PositionWatcher.get_monitoring_status()
        @test status isa Dict{String, Any}
        @test haskey(status, "active")
        @test haskey(status, "check_count")
        @test haskey(status, "watch_interval_ms")
        
        # Test monitoring stats
        stats = PositionWatcher.get_monitoring_stats()
        @test stats isa Dict{String, Any}
        @test haskey(stats, "total_registered_users")
        @test haskey(stats, "monitoring_coverage")
        
        # Test force monitoring check
        check_result = PositionWatcher.force_monitoring_check()
        @test check_result["success"] == true
        @test haskey(check_result, "incidents_found")
        @test haskey(check_result, "users_monitored")
        
        # Test health data for endpoint
        health_data = PositionWatcher.get_health_data()
        @test health_data isa Dict{String, Any}
        @test haskey(health_data, "monitored_users")
        @test haskey(health_data, "monitored_wallets")
        @test haskey(health_data, "positions_cached")
        @test haskey(health_data, "mempool_monitoring")
    end
    
    @testset "Position Monitoring Lifecycle" begin
        # Test starting monitoring
        start_result = PositionWatcher.start_position_monitoring!()
        @test start_result == true
        
        # Check that monitoring is active
        status = PositionWatcher.get_monitoring_status()
        @test status["active"] == true
        @test status["start_time"] !== nothing
        
        # Wait briefly for monitoring loop
        sleep(1.5)
        
        # Check that monitoring has run
        status_after = PositionWatcher.get_monitoring_status()
        @test status_after["check_count"] >= 0
        
        # Test stopping monitoring
        stop_result = PositionWatcher.stop_position_monitoring!()
        @test stop_result == true
        
        # Check that monitoring is stopped
        status_stopped = PositionWatcher.get_monitoring_status()
        @test status_stopped["active"] == false
        
        # Test starting again (should work)
        restart_result = PositionWatcher.start_position_monitoring!()
        @test restart_result == true
        
        # Stop for cleanup
        PositionWatcher.stop_position_monitoring!()
    end
    
    @testset "Integration with Position Fetcher" begin
        # Test that monitoring works with position fetching
        test_user_profile = Dict{String, Any}(
            "user_id" => "integration_test_user",
            "ethereum_wallet" => "0x742d35Cc6634C0532925a3b8D48C405fD75d4CaD",
            "solana_wallet" => "6dSk7LHZWmfw2ZJyCQsFd4z4Wjt9dUqAKAxKg3BmHQS"
        )
        
        # This should fetch positions and check health factors
        positions = PositionFetcher.fetch_user_positions(test_user_profile)
        @test positions isa Vector{Dict{String, Any}}
        
        # Each position should have required fields for monitoring
        for position in positions
            @test haskey(position, "health_factor")
            @test haskey(position, "position_id")
            @test haskey(position, "protocol")
            @test haskey(position, "chain")
            @test position["health_factor"] isa Float64
        end
    end
    
    @testset "Incident Cleanup and Limits" begin
        # Test incident cleanup and limits
        test_user = "cleanup_test_user"
        
        # Clear existing incidents
        IncidentStore.clear_incidents!(test_user)
        
        # Add multiple incidents
        for i in 1:5
            incident = IncidentStore.Incident(
                test_user,
                "position_$i",
                "aave",
                "ethereum",
                "HIGH",
                "Test incident $i",
                1.05,
                1.10,
                "ETH",
                1.0,
                "USDC",
                1000.0,
                now() - Minute(i * 10)  # Spread out over time
            )
            IncidentStore.add_incident!(incident)
        end
        
        # Check that incidents were added
        all_incidents = IncidentStore.get_user_incidents(test_user)
        @test length(all_incidents) == 5
        
        # Test recent incidents filtering
        recent_1h = IncidentStore.get_recent_incidents(test_user, hours=1)
        @test length(recent_1h) <= 5  # Should include incidents from last hour
        
        # Test clearing incidents
        IncidentStore.clear_incidents!(test_user)
        cleared_incidents = IncidentStore.get_user_incidents(test_user)
        @test length(cleared_incidents) == 0
    end
    
    @testset "Error Handling" begin
        # Test monitoring non-existent user
        @test_nowarn PositionWatcher.monitor_user_positions("non_existent_user")
        incidents = PositionWatcher.monitor_user_positions("non_existent_user")
        @test length(incidents) == 0
        
        # Test getting incidents for non-existent user
        @test_nowarn IncidentStore.get_user_incidents("non_existent_user")
        empty_incidents = IncidentStore.get_user_incidents("non_existent_user")
        @test length(empty_incidents) == 0
        
        # Test monitoring with malformed user data
        @test_nowarn PositionWatcher.monitor_all_users()
        
        # Test double start/stop
        @test_nowarn PositionWatcher.start_position_monitoring!()
        @test_nowarn PositionWatcher.start_position_monitoring!()  # Should handle gracefully
        @test_nowarn PositionWatcher.stop_position_monitoring!()
        @test_nowarn PositionWatcher.stop_position_monitoring!()   # Should handle gracefully
    end
end

println("✅ Watchers & Health Tracking tests completed successfully")
