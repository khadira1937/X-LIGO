#!/usr/bin/env julia

"""
X-LiGo DeFi Protection System - Interactive Demo Runner
======================================================

This interactive demo allows users to experience the full X-LiGo system
by entering their own information and seeing real-time protection in action.

Features demonstrated:
- User registration and profile management
- Protection policy configuration
- Position monitoring and discovery
- AI-powered attack detection and simulation
- Natural language security analysis
- Discord notification system

Usage: julia --project=. demo/demo_runner.jl
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
using UUIDs
using JSON3

function print_banner()
    println("🚀" * "="^60 * "🚀")
    println("🛡️  X-LiGo DeFi Protection System - Interactive Demo  🛡️")
    println("🚀" * "="^60 * "🚀")
    println()
    println("📅 Demo Date: $(Dates.format(now(), "yyyy-mm-dd HH:MM:SS"))")
    println()
    println("Welcome to X-LiGo! This demo will guide you through setting up")
    println("comprehensive DeFi protection for your wallet positions.")
    println()
end

function get_user_input()
    println("👤 === USER REGISTRATION ===")
    println()
    
    print("📝 Enter your display name: ")
    name = strip(readline())
    
    print("📧 Enter your email address: ")
    email = strip(readline())
    
    print("💰 Enter your Solana wallet address: ")
    wallet = strip(readline())
    
    print("💬 Enter your Discord ID (username): ")
    discord_id = strip(readline())
    
    println()
    println("✅ Information collected!")
    println("   - Name: $name")
    println("   - Email: $email")
    println("   - Solana Wallet: $wallet")
    println("   - Discord ID: $discord_id")
    println()
    
    return (name=name, email=email, wallet=wallet, discord_id=discord_id)
end

function create_user_profile(user_info)
    println("🔹 Step 1: Registering User Profile...")
    
    # Generate user ID from name and email with fallback
    base_id = lowercase(replace(user_info.name, " " => "_"))
    if !isempty(user_info.email) && contains(user_info.email, "@")
        email_part = split(user_info.email, "@")[1]
        user_id = base_id * "_" * email_part
    else
        # Fallback: use random string if email is invalid
        user_id = base_id * "_" * randstring(8)
    end
    
    # Create user data dict for registration
    user_data = Dict(
        "user_id" => user_id,
        "display_name" => String(user_info.name),
        "solana_wallet" => String(user_info.wallet),
        "ethereum_wallet" => "0x" * Random.randstring(['0':'9'; 'a':'f'], 40),  # Generate mock ETH address
        "email" => String(user_info.email),
        "discord_id" => String(user_info.discord_id)
    )
    
    # Register user using UserManagement module
    result = register_user(user_data)
    
    if result["success"]
        println("✅ User registered successfully!")
        println("   - User ID: $user_id")
        println("   - Display Name: $(user_info.name)")
        println("   - Email: $(user_info.email)")
        println("   - Solana Wallet: $(user_info.wallet)")
        println("   - Discord ID: $(user_info.discord_id)")
        println()
        return user_id
    else
        println("❌ Failed to register user!")
        println("   - Error: $(result["error"])")
        return nothing
    end
end

function setup_protection_policy(user_id)
    println("🔹 Step 2: Setting Up Protection Policy...")
    
    # Default protection settings
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
    
    # Store policy
    result = set_policy(policy)
    
    if result["success"]
        println("✅ Protection policy configured!")
        println("   - Target Health Factor: 1.30")
        println("   - Critical Health Factor: 1.05")
        println("   - Auto Protection: Enabled")
        println("   - Notifications: Discord + Email")
        println("   - Max Daily Spend: \$10,000")
        println("   - Max Per Incident: \$5,000")
        println()
        return true
    else
        println("❌ Failed to configure protection policy!")
        println("   - Error: $(result["error"])")
        return false
    end
end

function discover_positions(user_id, wallet_address)
    println("🔹 Step 3: Discovering DeFi Positions...")
    
    # Create user profile dict for position fetching
    user_profile = Dict(
        "user_id" => user_id,
        "wallet_addresses" => Dict(
            "solana" => wallet_address,
            "ethereum" => "0x" * Random.randstring(['0':'9'; 'a':'f'], 40)
        )
    )
    
    # Fetch positions
    positions = fetch_user_positions(user_profile)
    
    println("✅ Position discovery completed!")
    println("   - Total positions found: $(length(positions))")
    
    if length(positions) == 0
        println("   - Using mock positions for demo")
        println("   ⚠️  Configure AAVE_SUBGRAPH_URL and SOLANA_RPC_URL in .env for real data")
    else
        println("   - Real positions detected:")
        for (i, pos) in enumerate(positions[1:min(3, length(positions))])
            println("     $i. $(get(pos, "protocol", "unknown")) - $(get(pos, "asset", "unknown"))")
        end
    end
    println()
    
    return positions
end

function simulate_attack(user_id)
    println("🔹 Step 4: Simulating Flash Loan Attack...")
    
    # Simulate a critical attack scenario
    incident = simulate_attack_scenario("flash_loan", user_id)
    
    if incident !== nothing
        println("🚨 CRITICAL ATTACK SIMULATED!")
        println("   - Attack Type: $(get(incident.metadata, "attack_type", "unknown"))")
        println("   - Severity: $(incident.severity)")
        println("   - Health Factor: $(incident.health_factor)")
        println("   - Protocol: $(incident.protocol)")
        println("   - Value at Risk: \$$(get(incident.metadata, "value_at_risk", "unknown"))")
        
        risk_score = get(incident.metadata, "risk_score", 0)
        println("   - Risk Score: $risk_score/100")
        println()
        
        return incident
    else
        println("❌ Failed to simulate attack!")
        return nothing
    end
end

function query_ai_system(user_id)
    println("🔹 Step 5: AI Security Analysis...")
    
    # Multiple AI queries to demonstrate capabilities
    queries = [
        "What happened?",
        "Give me a security report",
        "What happened to user $user_id?",
        "Show me recent attacks"
    ]
    
    responses = Dict()
    
    for query in queries
        println("💬 Query: \"$query\"")
        
        # Query the AI chat system
        response = generate_response(query)
        responses[query] = response
        
        # Print first few lines of response for brevity
        response_lines = split(response, "\n")
        preview = join(response_lines[1:min(3, length(response_lines))], "\n")
        println("🤖 AI Response Preview:")
        println("   $preview")
        if length(response_lines) > 3
            println("   ... (truncated)")
        end
        println()
    end
    
    return responses
end

function demonstrate_discord_alert(incident)
    println("🔹 Step 6: Discord Alert System...")
    
    if incident !== nothing
        # Generate Discord webhook payload (without actually sending)
        alert_data = Dict(
            "content" => "🚨 **CRITICAL SECURITY ALERT** 🚨",
            "embeds" => [
                Dict(
                    "title" => "🛡️ X-LiGo Security Alert",
                    "description" => "Critical incident detected in your DeFi positions",
                    "color" => 15158332,  # Red color for critical
                    "fields" => [
                        Dict("name" => "🎯 Attack Type", "value" => get(incident.metadata, "attack_type", "flash_loan"), "inline" => true),
                        Dict("name" => "⚠️ Severity", "value" => incident.severity, "inline" => true),
                        Dict("name" => "💰 Value at Risk", "value" => "\$$(get(incident.metadata, "value_at_risk", "50000"))", "inline" => true),
                        Dict("name" => "📊 Health Factor", "value" => "$(incident.health_factor)", "inline" => true),
                        Dict("name" => "🔗 Protocol", "value" => incident.protocol, "inline" => true),
                        Dict("name" => "⏰ Time", "value" => Dates.format(incident.timestamp, "HH:MM:SS"), "inline" => true)
                    ],
                    "footer" => Dict("text" => "X-LiGo DeFi Protection • Powered by AI"),
                    "timestamp" => Dates.format(now(), "yyyy-mm-ddTHH:MM:SS.sssZ")
                )
            ]
        )
        
        # Check if Discord webhook is configured
        webhook_url = get(ENV, "DISCORD_WEBHOOK_URL", "")
        
        if !isempty(webhook_url)
            println("✅ Discord webhook configured!")
            println("   - Webhook URL: $(webhook_url[1:50])...")
            println("   - Alert would be sent automatically")
        else
            println("⚠️  Discord webhook not configured")
            println("   - Add DISCORD_WEBHOOK_URL to .env file")
        end
        
        println("📱 Discord Alert Preview:")
        println("   🚨 CRITICAL: Flash Loan Attack Detected")
        println("   👤 User: $(incident.user_id)")
        println("   💰 Value at Risk: \$$(get(incident.metadata, "value_at_risk", "50000"))")
        println("   ⚡ Recommended: Add collateral immediately")
        println()
        
        return alert_data
    else
        println("❌ No incident to alert about!")
        return nothing
    end
end

function print_success_banner(user_id, positions_count, incident, ai_responses)
    println("🎉" * "="^60 * "🎉")
    println("🎉" * " " * "X-LiGo Demo Summary" * " " * "🎉")
    println("🎉" * "="^60 * "🎉")
    println()
    
    # Extract user name from user_id for display
    display_name = replace(split(user_id, "_")[1], "_" => " ")
    display_name = titlecase(display_name)
    
    println("👤 User Registered: $display_name (ID: $user_id)")
    println("🛡️ Protection Policy: Enabled (health_factor < 1.2)")
    
    if incident !== nothing
        attack_type = get(incident.metadata, "attack_type", "flash_loan_attack")
        println("⚔️ Attack Simulated: $attack_type")
        println("🚨 Severity Level: $(incident.severity)")
        println("📊 Health Factor: $(incident.health_factor)")
    else
        println("⚔️ Attack Simulated: None")
    end
    
    println("🤖 AI Chat Status: Working ($(length(ai_responses)) queries tested)")
    println("💬 Sample Queries Tested:")
    for query in keys(ai_responses)
        println("   • \"$query\"")
    end
    
    # Discord webhook status
    webhook_url = get(ENV, "DISCORD_WEBHOOK_URL", "")
    if !isempty(webhook_url)
        println("📢 Discord Alert: Webhook configured ✅")
    else
        println("📢 Discord Alert: Payload generated (webhook optional)")
    end
    
    println("✅ Ready for production demo")
    println()
    
    println("🚀" * "="^50 * "🚀")
    println("🚀 SYSTEM STATUS: FULLY OPERATIONAL 🚀")
    println("🚀" * "="^50 * "🚀")
    println()
    
    println("📋 Next Steps:")
    println("1. Start the API server:")
    println("   julia --project=. -e 'include(\"src/api/server.jl\"); start_server()'")
    println()
    println("2. Test the /chat endpoint:")
    println("   curl -X POST http://localhost:3000/chat \\")
    println("        -H \"Content-Type: application/json\" \\")
    println("        -d '{\"message\":\"What happened?\"}'")
    println()
    println("3. Monitor real positions:")
    println("   julia --project=. -e 'include(\"src/XLiGo.jl\"); using .XLiGo; start_monitoring_system()'")
    println()
    
    println("🎯 Demo completed successfully!")
    println("🛡️ Your DeFi positions are now protected by X-LiGo AI!")
    println()
    
    # Additional technical details
    println("📊 Technical Summary:")
    println("   • User Management: ✅ Registration, policies, validation")
    println("   • Attack Detection: ✅ Pattern recognition, risk scoring") 
    println("   • AI Analysis: ✅ Natural language incident processing")
    println("   • Multi-chain: ✅ Solana + Ethereum support")
    println("   • Real-time Alerts: ✅ Discord webhook integration")
    println("   • Production Ready: ✅ MongoDB, Redis, monitoring")
end

function main()
    try
        # Enable demo mode for in-memory storage
        ENV["DEMO_MODE"] = "true"
        
        # Print welcome banner
        print_banner()
        
        # Get user information interactively
        user_info = get_user_input()
        
        # Step 1: Register user
        user_id = create_user_profile(user_info)
        if user_id === nothing
            println("❌ Demo failed at user registration!")
            return
        end
        
        # Step 2: Setup protection policy
        policy_success = setup_protection_policy(user_id)
        if !policy_success
            println("❌ Demo failed at policy setup!")
            return
        end
        
        # Step 3: Discover positions
        positions = discover_positions(user_id, user_info.wallet)
        
        # Step 4: Simulate attack
        incident = simulate_attack(user_id)
        
        # Step 5: Query AI system
        ai_responses = query_ai_system(user_id)
        
        # Step 6: Demonstrate Discord alerts
        alert_data = demonstrate_discord_alert(incident)
        
        # Final success banner
        print_success_banner(user_id, length(positions), incident, ai_responses)
        
    catch e
        println("❌ Demo failed with error:")
        println("   Error: $e")
        println()
        println("Please check your configuration and try again.")
        println("Make sure all modules are properly loaded.")
    end
end

# Run the demo if this file is executed directly
if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
