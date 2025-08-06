"""
Minimal Watchers test - core functionality only
"""

using Test
using Dates

# Set up test environment  
ENV["DEMO_MODE"] = "true"
ENV["WATCH_INTERVAL_MS"] = "1000"

# Include the main module
include("../src/XLiGo.jl")
using .XLiGo.IncidentStore
using .XLiGo.PositionWatcher
using .XLiGo.UserManagement

@testset "Watchers Essential Tests" begin
    
    # Clear incidents
    IncidentStore.clear_all_incidents!()
    
    # Test 1: Incident Store Basic Operations
    incident = IncidentStore.Incident(
        "test_user", "pos_1", "aave", "ethereum", "HIGH",
        "Health factor below threshold", 1.05, 1.10,
        "ETH", 5.0, "USDC", 8000.0, now()
    )
    
    IncidentStore.add_incident!(incident)
    incidents = IncidentStore.get_user_incidents("test_user")
    @test length(incidents) == 1
    @test incidents[1].severity == "HIGH"
    
    # Test 2: Position Monitoring Setup
    user_data = Dict{String, Any}(
        "user_id" => "test_monitor_user",
        "display_name" => "Test User",
        "ethereum_wallet" => "0x742d35Cc6634C0532925a3b8D48C405fD75d4CaD"
    )
    
    reg_result = UserManagement.register_user(user_data)
    @test reg_result["success"] == true
    
    # Test 3: Policy Setting
    policy = UserManagement.ProtectionPolicy(
        "test_monitor_user", 500.0, 250.0, 1.25, 1.10, 
        true, ["add_collateral"], ["discord"]
    )
    
    policy_result = UserManagement.set_policy(policy)
    @test policy_result["success"] == true
    
    # Test 4: Monitor User Positions (core function)
    result = PositionWatcher.monitor_user_positions("test_monitor_user")
    @test result isa Vector{IncidentStore.Incident}
    
    # Test 5: Get Status Data
    status = PositionWatcher.get_monitoring_status()
    @test status isa Dict{String, Any}
    @test haskey(status, "active")
    
    health_data = PositionWatcher.get_health_data()
    @test health_data isa Dict{String, Any}
    @test haskey(health_data, "monitored_users")
    @test haskey(health_data, "positions_cached")
    
    # Test 6: Monitoring Lifecycle  
    start_result = PositionWatcher.start_position_monitoring!()
    @test start_result == true
    
    active_status = PositionWatcher.get_monitoring_status()
    @test active_status["active"] == true
    
    stop_result = PositionWatcher.stop_position_monitoring!()
    @test stop_result == true
    
    stopped_status = PositionWatcher.get_monitoring_status()
    @test stopped_status["active"] == false
    
    # Test 7: Error Handling
    empty_result = PositionWatcher.monitor_user_positions("non_existent_user")
    @test length(empty_result) == 0
    
    empty_incidents = IncidentStore.get_user_incidents("non_existent_user")
    @test length(empty_incidents) == 0
    
    println("✅ All essential watcher functionality verified!")
end
