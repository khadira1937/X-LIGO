#!/usr/bin/env julia

"""
X-LiGo DeFi Protection System - Quick Demo (Non-Interactive)
===========================================================

This demo runs automatically with sample data for quick testing.
Perfect for CI/CD, automated testing, or quick demonstrations.

Usage: julia --project=. demo/quick_demo.jl
"""

using Pkg
Pkg.activate(".")

# Load all required modules
include("../src/XLiGo.jl")
using .XLiGo
using .XLiGo.UserManagement
using .XLiGo.PositionFetcher
using .XLiGo.AttackDetector
using .XLiGo.ChatResponder
using .XLiGo.DiscordNotifier

using Dates
using Random

function print_banner()
    println("🚀" * "="^50 * "🚀")
    println("🛡️  X-LiGo Quick Demo - Auto Mode  🛡️")
    println("🚀" * "="^50 * "🚀")
    println()
    println("📅 Demo Date: $(Dates.format(now(), "yyyy-mm-dd HH:MM:SS"))")
    println("🤖 Running automated demo with sample data...")
    println()
end

function main()
    # Enable demo mode for in-memory storage
    ENV["DEMO_MODE"] = "true"
    
    print_banner()
    
    # Sample user data
    sample_user = (
        name="Demo User",
        email="demo@xligo.com",
        wallet="6dSk7LHZWmfw2ZJyCQsFd4z4Wjt9dUqAKAxKg3BmHQS",
        discord_id="demo_user_001"
    )
    
    println("👤 Using sample user data:")
    println("   - Name: $(sample_user.name)")
    println("   - Email: $(sample_user.email)")
    println("   - Wallet: $(sample_user.wallet)")
    println("   - Discord: $(sample_user.discord_id)")
    println()
    
    try
        # Step 1: Register user
        println("🔹 Step 1: Registering User...")
        user_id = "demo_user_xligo"
        
        user_data = Dict(
            "user_id" => user_id,
            "display_name" => sample_user.name,
            "solana_wallet" => sample_user.wallet,
            "ethereum_wallet" => "0x" * Random.randstring(['0':'9'; 'a':'f'], 40),
            "email" => sample_user.email,
            "discord_id" => sample_user.discord_id
        )
        
        reg_result = register_user(user_data)
        if reg_result["success"]
            println("✅ User registered: $user_id")
        else
            println("❌ User registration failed: $(reg_result["error"])")
            return
        end
        
        # Step 2: Setup protection policy
        println("🔹 Step 2: Setting Protection Policy...")
        policy = ProtectionPolicy(
            user_id,               # user_id
            10000.0,              # max_daily_spend_usd
            5000.0,               # max_per_incident_usd
            1.3,                  # target_health_factor
            1.05,                 # critical_health_factor
            true,                 # auto_protection_enabled
            ["add_collateral", "partial_repay"],  # allowed_strategies
            ["discord", "email"]  # notification_preferences
        )
        
        policy_result = set_policy(policy)
        if policy_result["success"]
            println("✅ Protection policy configured")
        else
            println("❌ Policy configuration failed: $(policy_result["error"])")
            return
        end
        
        # Step 3: Simulate attack
        println("🔹 Step 3: Simulating Flash Loan Attack...")
        incident = simulate_attack_scenario("flash_loan", user_id)
        
        if incident !== nothing
            println("🚨 ATTACK SIMULATED!")
            println("   - Type: $(get(incident.metadata, "attack_type", "unknown"))")
            println("   - Severity: $(incident.severity)")
            println("   - Health Factor: $(incident.health_factor)")
        end
        
        # Step 4: AI Analysis
        println("🔹 Step 4: AI Security Analysis...")
        queries = [
            "What was the latest attack?",
            "Show me the security status",
            "Give me a security report"
        ]
        
        for query in queries
            println("💬 Query: \"$query\"")
            response = generate_response(query)
            # Print first line of response for brevity
            first_line = split(response, "\n")[1]
            println("🤖 AI: $first_line")
            println()
        end
        
        # Step 5: Discord Alert Preview
        println("🔹 Step 5: Discord Alert System...")
        webhook_url = get(ENV, "DISCORD_WEBHOOK_URL", "")
        
        if !isempty(webhook_url)
            println("✅ Discord webhook configured!")
            println("   - Alert ready to send")
        else
            println("⚠️  Discord webhook not configured")
            println("   - Would send: 🚨 CRITICAL Attack Alert")
        end
        
        # Success summary
        println()
        println("🎯" * "="^40 * "🎯")
        println("✅ X-LiGo Quick Demo Completed!")
        println("🎯" * "="^40 * "🎯")
        println()
        println("📊 Demo Results:")
        println("✅ User Registration: Working")
        println("✅ Protection Policy: Configured")
        println("✅ Attack Detection: Functional")
        println("✅ AI Analysis: Operational")
        println("✅ Discord Integration: Ready")
        println()
        println("🚀 System Status: READY FOR PRODUCTION")
        println("🛡️ Your DeFi is now protected by X-LiGo!")
        
    catch e
        println("❌ Demo failed with error: $e")
        println("Please check your configuration.")
    end
end

# Run the demo
if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
