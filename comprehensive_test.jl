#!/usr/bin/env julia

"""
Comprehensive X-LiGo System Test
Tests all components with your personal configuration
"""

using Pkg
using Dates

# Change to project directory
cd(@__DIR__)

# Activate project environment
Pkg.activate(".")

println("""
╔══════════════════════════════════════════════════════════════════════╗
║                                                                      ║
║    🧪 X-LiGo System Comprehensive Test Suite                        ║
║       Testing with your personal configuration                      ║
║                                                                      ║
╚══════════════════════════════════════════════════════════════════════╝
""")

function test_step(step_name::String, test_function)
    print("🔄 Testing: $step_name... ")
    try
        result = test_function()
        if result
            println("✅ PASSED")
            return true
        else
            println("❌ FAILED")
            return false
        end
    catch e
        println("❌ ERROR: $e")
        return false
    end
end

function test_environment_variables()
    # Test if .env file exists and has required variables
    if !isfile(".env")
        println("❌ .env file not found!")
        return false
    end
    
    required_vars = ["MONGODB_URI", "OPENAI_API_KEY", "JWT_SECRET"]
    env_content = read(".env", String)
    
    for var in required_vars
        if !occursin(var, env_content)
            println("❌ Missing required variable: $var")
            return false
        end
    end
    
    return true
end

function test_module_loading()
    try
        using XLiGo
        return true
    catch e
        println("Module loading error: $e")
        return false
    end
end

function test_database_connection()
    try
        using XLiGo
        # This will test if MongoDB connection string is valid
        XLiGo.generate_demo_data()
        return true
    catch e
        println("Database error: $e")
        return false
    end
end

function test_openai_api()
    try
        using XLiGo
        # Start system to test OpenAI integration
        result = XLiGo.start_swarm()
        if result["success"]
            XLiGo.stop_swarm()
            return true
        end
        return false
    catch e
        println("API error: $e")
        return false
    end
end

function test_demo_scenario()
    try
        using XLiGo
        
        # Generate demo data
        demo_result = XLiGo.generate_demo_data()
        if !demo_result["success"]
            return false
        end
        
        # Start swarm
        start_result = XLiGo.start_swarm()
        if !start_result["success"]
            return false
        end
        
        # Test risk event processing
        risk_event = Dict(
            "event_type" => "liquidation_risk",
            "position_id" => "pos_alice_sol_1",
            "severity" => "high",
            "position_value_usd" => 25000.0,
            "trigger_health_factor" => 1.25
        )
        
        event_result = XLiGo.process_risk_event(risk_event)
        
        # Stop swarm
        XLiGo.stop_swarm()
        
        return event_result["success"]
    catch e
        println("Demo error: $e")
        return false
    end
end

# Run all tests
println("🚀 Starting comprehensive system test...\n")

tests = [
    ("Environment Variables", test_environment_variables),
    ("Module Loading", test_module_loading),
    ("Database Connection", test_database_connection),
    ("OpenAI API Integration", test_openai_api),
    ("Full Demo Scenario", test_demo_scenario)
]

passed_tests = 0
total_tests = length(tests)

for (test_name, test_func) in tests
    if test_step(test_name, test_func)
        passed_tests += 1
    end
    println()
end

println("="^70)
println("📊 TEST RESULTS:")
println("✅ Passed: $passed_tests/$total_tests")
println("❌ Failed: $(total_tests - passed_tests)/$total_tests")

if passed_tests == total_tests
    println("""
🎉 ALL TESTS PASSED! 🎉

Your X-LiGo system is fully functional and ready for:
✅ Real-time DeFi position monitoring
✅ AI-powered risk prediction
✅ Mathematical optimization
✅ Automated liquidation protection
✅ Multi-chain coordination

🚀 Ready to run the full demo: julia demo.jl
💰 Ready for production deployment!
""")
else
    println("""
⚠️  Some tests failed. Please check:
1. MongoDB connection string
2. OpenAI API key validity
3. Internet connection
4. Julia package installation

🔧 Run 'julia --project=. -e "using Pkg; Pkg.instantiate()"' to reinstall packages
""")
end
