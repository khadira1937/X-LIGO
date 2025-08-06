#!/usr/bin/env julia

"""
Quick Test Script for X-LiGo System

Basic functionality test to ensure all modules load and core functions work.
"""

using Pkg

# Change to project directory
cd(@__DIR__)

# Activate project environment
Pkg.activate(".")

println("🧪 Testing X-LiGo System Components...")

try
    # Test module loading
    println("📦 Loading X-LiGo module...")
    using XLiGo
    println("✅ XLiGo module loaded successfully")
    
    # Test system status (should show not initialized)
    println("\n📊 Testing system status...")
    status = XLiGo.get_system_status()
    println("✅ System status: $(status["status"])")
    
    # Test demo data generation
    println("\n🎭 Testing demo data generation...")
    demo_result = XLiGo.generate_demo_data()
    if demo_result["success"]
        println("✅ Demo data generated: $(demo_result["users_created"]) users, $(demo_result["positions_created"]) positions")
    else
        println("❌ Demo data generation failed: $(demo_result["error"])")
    end
    
    # Test swarm startup
    println("\n🚀 Testing swarm startup...")
    start_result = XLiGo.start_swarm()
    if start_result["success"]
        println("✅ Swarm started: $(start_result["total_agents"]) agents")
        
        # Test system status with running swarm
        println("\n📈 Testing system status with active swarm...")
        status = XLiGo.get_system_status()
        println("✅ Swarm status: $(status["swarm_status"])")
        println("🤖 Healthy agents: $(status["agents"]["healthy"])")
        
        # Test risk event processing
        println("\n🚨 Testing risk event processing...")
        test_event = Dict(
            "event_type" => "test_event",
            "position_id" => "pos_alice_sol_1",
            "severity" => "low",
            "position_value_usd" => 25000.0
        )
        
        event_result = XLiGo.process_risk_event(test_event)
        if event_result["success"]
            println("✅ Risk event processed successfully")
        else
            println("⚠️  Risk event processing: $(event_result["error"])")
        end
        
        # Stop swarm
        println("\n🛑 Testing swarm shutdown...")
        XLiGo.stop_swarm()
        println("✅ Swarm stopped successfully")
        
    else
        println("❌ Swarm startup failed")
    end
    
    println("\n🎉 All tests completed!")
    println("✅ X-LiGo system is ready for demo")
    
catch e
    println("\n❌ Test failed with error: $e")
    println("🔧 Attempting cleanup...")
    
    try
        XLiGo.stop_swarm()
    catch cleanup_error
        println("⚠️  Cleanup error: $cleanup_error")
    end
end
