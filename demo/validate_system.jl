#!/usr/bin/env julia

"""
X-LiGo Demo Validation - Test all components before full demo
"""

using Pkg
Pkg.activate(".")

# Load environment variables
function load_env_file()
    env_file = ".env"
    if isfile(env_file)
        for line in eachline(env_file)
            line = strip(line)
            if !isempty(line) && !startswith(line, "#") && contains(line, "=")
                key, value = split(line, "=", limit=2)
                ENV[strip(key)] = strip(value)
            end
        end
    end
end

load_env_file()

include("../src/XLiGo.jl")
using .XLiGo
using .XLiGo.UserManagement
using .XLiGo.AttackDetector
using .XLiGo.ChatResponder

using HTTP
using JSON3
using Dates

function test_component(name, test_func)
    print("🔹 Testing $name... ")
    flush(stdout)
    
    try
        result = test_func()
        if result
            println("✅ PASS")
            return true
        else
            println("❌ FAIL")
            return false
        end
    catch e
        println("❌ ERROR: $e")
        return false
    end
end

function test_user_registration()
    ENV["DEMO_MODE"] = "true"
    
    user_data = Dict(
        "user_id" => "test_validation_user",
        "display_name" => "Test User",
        "solana_wallet" => "6dSk7LHZWmfw2ZJyCQsFd4z4Wjt9dUqAKAxKg3BmHQS",
        "ethereum_wallet" => "0x742d35Cc6634C0532925a3b8D48C405fD75d4CaD",
        "email" => "test@example.com",
        "discord_id" => "testuser001"
    )
    
    result = register_user(user_data)
    return result["success"]
end

function test_attack_simulation()
    incident = simulate_attack_scenario("flash_loan", "test_validation_user")
    return incident !== nothing
end

function test_ai_chat()
    response = generate_response("What happened?")
    return !isempty(response) && length(response) > 10
end

function test_discord_webhook()
    webhook_url = get(ENV, "DISCORD_WEBHOOK_URL", "")
    if isempty(webhook_url)
        return false
    end
    
    try
        payload = Dict(
            "content" => "🧪 X-LiGo validation test",
            "embeds" => [Dict(
                "title" => "Validation Test",
                "description" => "Component testing in progress",
                "color" => 3447003
            )]
        )
        
        response = HTTP.post(
            webhook_url,
            ["Content-Type" => "application/json"],
            JSON3.write(payload)
        )
        
        return response.status == 200 || response.status == 204
    catch
        return false
    end
end

function test_environment_config()
    required_vars = ["DISCORD_WEBHOOK_URL", "OPENAI_API_KEY"]
    
    for var in required_vars
        if isempty(get(ENV, var, ""))
            println("   ❌ Missing: $var")
            return false
        end
    end
    
    return true
end

function main()
    println("🧪" * "="^60 * "🧪")
    println("🧪  X-LiGo Component Validation Tests")
    println("🧪" * "="^60 * "🧪")
    println()
    
    tests = [
        ("Environment Configuration", test_environment_config),
        ("User Registration", test_user_registration),
        ("Attack Simulation", test_attack_simulation),
        ("AI Chat Response", test_ai_chat),
        ("Discord Webhook", test_discord_webhook)
    ]
    
    passed = 0
    total = length(tests)
    
    for (name, test_func) in tests
        if test_component(name, test_func)
            passed += 1
        end
    end
    
    println()
    println("📊 Results: $passed/$total tests passed")
    
    if passed == total
        println("✅ All tests passed! System ready for full demo.")
        println()
        println("🚀 You can now run the full demo:")
        println("   julia --project=. demo/start_full_demo.jl")
    else
        println("❌ Some tests failed. Please check configuration before running demo.")
    end
    
    println()
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
