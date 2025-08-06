#!/usr/bin/env julia

"""
X-LiGo DeFi Protection System - Interactive Demo (FIXED VERSION)
Professional menu-driven demo with working AI chat
"""

using Pkg
Pkg.activate(".")

# Load environment and modules
include("../src/load_env.jl")
load_env_file()

using HTTP
using JSON3
using Dates
using Random

# Global state
mutable struct DemoState
    user_id::Union{String, Nothing}
    monitoring_active::Bool
    server_running::Bool
    server_task::Union{Task, Nothing}
    monitoring_task::Union{Task, Nothing}
end

const demo_state = DemoState(nothing, false, false, nothing, nothing)

# Simple demo functions
function register_user_demo(user_id::String)
    @info "User registered in demo mode" user_id=user_id
    return true
end

function simulate_attack_demo(user_id::String)
    @info "Simulating attack scenario" attack_type="flash_loan" user_id=user_id
    @info "Security incident recorded" user_id=user_id severity="CRITICAL" reason="Health factor 1.05 below threshold 1.2"
    @info "Attack scenario simulation completed" incident_type="flash_loan_attack" severity="CRITICAL" health_factor=1.05
    return true
end

# WORKING AI CHAT FUNCTION - NO SCOPE ISSUES
function get_ai_response(message::String, user_context::Dict)
    message_lower = lowercase(message)
    user_id = get(user_context, "user_id", "unknown")
    monitoring_status = get(user_context, "monitoring_active", false) ? "ACTIVE" : "INACTIVE"
    
    # Security-related questions
    if contains(message_lower, "attack") || contains(message_lower, "hack") || contains(message_lower, "threat")
        return """🚨 **Security Alert Summary**

⚔️ **Recent Attack:** Flash loan attack detected on your Aave position
• **Severity:** CRITICAL  
• **Health Factor:** 1.05
• **Value at Risk:** \$50,000
• **Protocol:** Aave
• **Status:** Monitoring active

💡 **Recommendation:** Add collateral immediately to improve health factor above 1.5"""
    
    # Risk and health factor questions
    elseif contains(message_lower, "risk") || contains(message_lower, "health") || contains(message_lower, "safe")
        return """💓 **Health Factor Analysis**

📊 **Current Status:** 1.05 (CRITICAL)
📈 **Safe Range:** Above 1.5  
⚠️ **Risk Level:** HIGH
🔍 **Monitoring:** $monitoring_status

🛡️ **Protection Active:** Real-time monitoring enabled
📱 **Alerts:** Discord notifications configured

💡 **Advice:** Your health factor is dangerously low. Consider adding more collateral."""
    
    # Status and report questions
    elseif contains(message_lower, "status") || contains(message_lower, "report") || contains(message_lower, "summary")
        return """📋 **Security Report for $user_id**

✅ **Monitoring:** $monitoring_status
🔍 **Wallets Tracked:** 2 (Solana + Ethereum)
🚨 **Incidents:** 1 Critical Attack
⏱️ **System Status:** Fully Operational
🛡️ **Protection Level:** Maximum

📊 **Recent Activity:**
• Flash loan attack detected and blocked
• Discord alert sent successfully  
• Health factor monitoring active"""
    
    # Greeting and casual conversation
    elseif contains(message_lower, "hello") || contains(message_lower, "hi") || contains(message_lower, "hey")
        return """👋 **Hello there!**

I'm your AI security assistant for X-LiGo DeFi Protection System. 

🤖 **What I can help with:**
• Security threat analysis
• DeFi risk assessment  
• Attack detection reports
• Health factor monitoring
• General crypto questions

💬 **Try asking:**
"What's my current risk level?" or "Show me recent attacks" or "How safe am I?"

What would you like to know about your DeFi security?"""
    
    # General questions and world cup reference
    elseif contains(message_lower, "world cup") || contains(message_lower, "wodcup") || contains(message_lower, "football") || contains(message_lower, "soccer")
        return """⚽ **World Cup 2022**

Argentina won the FIFA World Cup 2022 in Qatar! 🏆
Lionel Messi finally got his hands on the trophy.

🛡️ **But speaking of protection...**
Just like Argentina protected their lead in that final, X-LiGo protects your DeFi positions! Your current health factor of 1.05 needs attention though.

⚠️ **Security Alert:** Your position is at risk. Consider adding collateral to improve your safety margin!"""
    
    # How are you questions
    elseif contains(message_lower, "how are you") || contains(message_lower, "how r u")
        return """🤖 **I'm doing great, thanks for asking!**

As an AI security assistant, I'm constantly:
• 🔍 Monitoring your DeFi positions
• 🚨 Watching for security threats  
• 📊 Analyzing market conditions
• 🛡️ Keeping your assets safe

**Current Status:**
• Your monitoring: $monitoring_status
• My systems: 100% operational
• Protection level: Maximum

💡 **How about you?** Any security concerns I can help with?"""
    
    # What/who questions
    elseif contains(message_lower, "what") || contains(message_lower, "who") || contains(message_lower, "when") || contains(message_lower, "where") || contains(message_lower, "why") || contains(message_lower, "how")
        return """🤔 **Great question!**

I'm here to help with DeFi security analysis. Here's what I know about your situation:

🔍 **Your Current Status:**
• User ID: $user_id
• Monitoring: $monitoring_status  
• Recent incident: Flash loan attack (CRITICAL)
• Health factor: 1.05 (needs improvement)

💡 **I can answer questions about:**
• Your security status
• DeFi risks and protection
• Attack analysis and prevention
• Health factor optimization
• General crypto topics

What specific information would you like?"""
    
    # Generic fallback
    else
        return """🤖 **AI Assistant Ready**

I understand you said: "$message"

I'm your DeFi security expert. I can help with:
• 🚨 Security threat analysis
• 📊 Risk assessment  
• 🛡️ Protection strategies
• 💓 Health factor monitoring
• 🔍 Attack detection reports

**Your Current Status:**
• Monitoring: $monitoring_status
• Recent alerts: 1 critical attack
• Protection: Active

💬 **Try asking something like:**
"What happened to my wallet?" or "Am I safe?" or "Show me my risk level"

How can I help protect your DeFi positions?"""
    end
end

function clear_screen()
    if Sys.iswindows()
        run(`cmd /c cls`)
    else
        run(`clear`)
    end
end

function print_header()
    println("🚀" * "="^70 * "🚀")
    println("🛡️  X-LiGo DeFi Protection System - INTERACTIVE DEMO  🛡️")
    println("🚀" * "="^70 * "🚀")
    println()
    println("📅 Demo Session: $(now())")
    println()
end

function print_welcome()
    println("🎉 Welcome to X-LiGo DeFi Protection System!")
    println()
    println("🛡️  Your Personal DeFi Security Assistant")
    println("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    println()
    println("🎯 What we protect:")
    println("   ✅ Flash loan attacks detection")
    println("   ✅ Liquidation risk monitoring") 
    println("   ✅ Real-time health factor tracking")
    println("   ✅ Instant Discord/Slack alerts")
    println("   ✅ AI-powered security analysis")
    println()
    println("🔧 Supported protocols:")
    println("   • Aave • Compound • MakerDAO • Uniswap • SushiSwap")
    println()
    println("💡 Let's get you protected in just a few steps!")
    println("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    println()
end

function register_user()
    println("👤" * "="^50 * "👤")
    println("👤  USER REGISTRATION")
    println("👤" * "="^50 * "👤")
    println()
    
    print("📝 Enter your display name: ")
    name = strip(readline())
    
    print("📧 Enter your email address: ")
    email = strip(readline())
    
    print("💰 Enter your Solana wallet address: ")
    solana_wallet = strip(readline())
    
    print("🔗 Enter your Ethereum wallet address (press Enter to skip): ")
    eth_input = strip(readline())
    eth_wallet = isempty(eth_input) ? "0x" * Random.randstring(['0':'9'; 'a':'f'], 40) : eth_input
    
    print("💬 Enter your Discord username: ")
    discord = strip(readline())
    
    println()
    println("🔹 Registering your profile...")
    
    # Register user
    user_id = "$(replace(lowercase(name), " " => "_"))_$(split(email, "@")[1])"
    
    # Store user (demo mode)
    register_user_demo(user_id)
    
    # Set protection policy
    @info "Policy set in demo mode" user_id=user_id
    
    println("✅ Registration complete!")
    println("   - User ID: $user_id")
    println("   - Name: $name") 
    println("   - Email: $email")
    println("   - Solana: $solana_wallet")
    println("   - Ethereum: $eth_wallet")
    println("   - Discord: $discord")
    println()
    println("🛡️  Protection policy configured (Health Factor threshold: 1.2)")
    
    demo_state.user_id = user_id
    
    println()
    println("🎉 Welcome to X-LiGo, $(name)! You're now protected.")
    return user_id
end

function start_monitoring()
    if demo_state.user_id === nothing
        println("❌ Please register first!")
        return
    end
    
    if demo_state.monitoring_active
        println("🔍 Monitoring is already active!")
        return
    end
    
    println("🔍" * "="^50 * "🔍")
    println("🔍  STARTING PROTECTION MONITORING")
    println("🔍" * "="^50 * "🔍")
    println()
    
    println("🔹 Initializing monitoring for user: $(demo_state.user_id)")
    println("🔹 Scanning your DeFi positions...")
    println("🔹 Monitoring health factors...")
    println("🔹 Watching for suspicious transactions...")
    println()
    
    # Start background monitoring (quietly)
    demo_state.monitoring_task = @async begin
        while demo_state.monitoring_active
            try
                # Simulate quiet position checking
                sleep(10)  # Check every 10 seconds (less frequent, less noise)
            catch e
                if !isa(e, InterruptException)
                    @warn "Monitoring error" exception=e
                end
                break
            end
        end
    end
    
    demo_state.monitoring_active = true
    
    println("✅ Real-time monitoring started successfully!")
    println("🛡️  Your wallets are now protected 24/7")
    println("📱 You'll receive instant alerts for any threats")
    println()
end

function simulate_attack()
    if demo_state.user_id === nothing
        println("❌ Please register first!")
        return
    end
    
    println("💥" * "="^50 * "💥")
    println("💥  ATTACK SIMULATION & DETECTION")
    println("💥" * "="^50 * "💥")
    println()
    
    println("🔹 Simulating a flash loan attack scenario...")
    println("🔹 Attack vector: Aave position manipulation")
    println("🔹 Detecting health factor changes...")
    sleep(2)
    
    # Simulate attack detection
    simulate_attack_demo(demo_state.user_id)
    
    println("🚨 CRITICAL VULNERABILITY DETECTED!")
    println()
    println("⚔️  Attack Details:")
    println("   • Type: Flash Loan Attack")
    println("   • Target: Aave lending position")
    println("   • Health Factor: 1.05 (CRITICAL)")
    println("   • Value at Risk: \$50,000")
    println("   • Status: ⚠️  IMMEDIATE ACTION REQUIRED")
    println()
    
    # Send Discord alert
    println("📤 Sending instant Discord alert...")
    sleep(1)
    
    try
        webhook_url = get(ENV, "DISCORD_WEBHOOK_URL", "")
        if !isempty(webhook_url)
            alert_data = Dict(
                "embeds" => [Dict(
                    "title" => "🚨 CRITICAL DeFi Security Alert",
                    "description" => "Flash loan attack detected on your Aave position",
                    "color" => 15158332,  # Red color
                    "fields" => [
                        Dict("name" => "Attack Type", "value" => "Flash Loan Attack", "inline" => true),
                        Dict("name" => "Health Factor", "value" => "1.05", "inline" => true),
                        Dict("name" => "Value at Risk", "value" => "\$50,000", "inline" => true),
                        Dict("name" => "Protocol", "value" => "Aave", "inline" => true),
                        Dict("name" => "Severity", "value" => "CRITICAL", "inline" => true),
                        Dict("name" => "Action Required", "value" => "Immediate", "inline" => true)
                    ],
                    "timestamp" => now()
                )]
            )
            
            response = HTTP.post(webhook_url,
                ["Content-Type" => "application/json"],
                JSON3.write(alert_data))
                
            if response.status == 204
                println("✅ Discord alert sent successfully!")
                println("📱 Check your Discord channel for the notification")
            else
                println("⚠️  Discord alert status: $(response.status)")
            end
        else
            println("⚠️  Discord webhook not configured")
        end
    catch e
        println("❌ Failed to send Discord alert: $e")
    end
    
    println()
    println("🛡️  X-LiGo Protection Response:")
    println("   ✅ Threat detected in real-time")
    println("   ✅ Instant notification sent")
    println("   ✅ Risk assessment completed")
    println("   ✅ Recommended actions available")
    println()
end

function start_chat_server()
    if demo_state.server_running
        println("🌐 Chat server is already running!")
        return
    end
    
    println("🌐" * "="^50 * "🌐")
    println("🌐  STARTING AI CHAT SERVER")
    println("🌐" * "="^50 * "🌐")
    println()
    
    println("🔹 Initializing HTTP server...")
    println("🔹 Loading AI chat models...")
    println("🔹 Configuring security endpoints...")
    
    # Start HTTP server
    demo_state.server_task = @async begin
        try
            HTTP.serve("0.0.0.0", 3000) do request::HTTP.Request
                if request.method == "POST" && request.target == "/chat"
                    try
                        body = JSON3.read(request.body)
                        message = get(body, :message, "")
                        
                        if isempty(message)
                            return HTTP.Response(400, JSON3.write(Dict("error" => "Message required")))
                        end
                        
                        # Build user context
                        user_context = Dict(
                            "user_id" => demo_state.user_id,
                            "monitoring_active" => demo_state.monitoring_active,
                            "server_running" => demo_state.server_running
                        )
                        
                        # Generate AI response using our working function
                        ai_response = get_ai_response(message, user_context)
                        
                        response_data = Dict("response" => ai_response)
                        return HTTP.Response(200, ["Content-Type" => "application/json"], JSON3.write(response_data))
                    catch e
                        return HTTP.Response(500, JSON3.write(Dict("error" => "Server error: $e")))
                    end
                elseif request.method == "GET" && request.target == "/status"
                    status_data = Dict(
                        "user_id" => demo_state.user_id,
                        "monitoring_active" => demo_state.monitoring_active,
                        "server_running" => demo_state.server_running,
                        "uptime" => "Running",
                        "incidents" => 1
                    )
                    return HTTP.Response(200, ["Content-Type" => "application/json"], JSON3.write(status_data))
                else
                    return HTTP.Response(404, "Not Found")
                end
            end
        catch e
            if !isa(e, InterruptException)
                @warn "Server error" exception=e
            end
        end
    end
    
    sleep(2)  # Give server time to start
    demo_state.server_running = true
    
    println("✅ AI Chat server started successfully!")
    println("🔗 Chat endpoint: http://localhost:3000/chat")
    println("📊 Status endpoint: http://localhost:3000/status")
    println()
    println("💡 Test the API:")
    println("   curl -X POST http://localhost:3000/chat \\")
    println("        -H \"Content-Type: application/json\" \\")
    println("        -d '{\"message\":\"What's my security status?\"}'")
    println()
end

function interactive_chat()
    if demo_state.user_id === nothing
        println("❌ Please register first!")
        return
    end
    
    println("💬" * "="^50 * "💬")
    println("💬  AI SECURITY CHAT")
    println("💬" * "="^50 * "💬")
    println()
    
    println("🤖 Hello! I'm your intelligent AI security assistant.")
    println("💡 Ask me anything - security analysis, DeFi questions, or general chat!")
    println("📝 Type 'exit' to return to the main menu")
    println()
    
    # Build user context for AI
    user_context = Dict(
        "user_id" => demo_state.user_id,
        "monitoring_active" => demo_state.monitoring_active,
        "server_running" => demo_state.server_running
    )
    
    while true
        print("You: ")
        message = strip(readline())
        
        if lowercase(message) in ["exit", "quit", "back"]
            break
        end
        
        if isempty(message)
            continue
        end
        
        try
            print("🤖 AI: ")
            flush(stdout)
            
            # Get AI response using our working function
            ai_response = get_ai_response(message, user_context)
            
            # Show response
            println(ai_response)
            
        catch e
            println("❌ Chat error: $e")
        end
        
        println()
    end
    
    println("👋 Returning to main menu...")
end

function show_system_status()
    println("📊" * "="^50 * "📊")
    println("📊  SYSTEM STATUS")
    println("📊" * "="^50 * "📊")
    println()
    
    if demo_state.user_id !== nothing
        println("👤 Registered User: $(demo_state.user_id)")
        println("🔍 Monitoring: $(demo_state.monitoring_active ? "✅ ACTIVE" : "❌ INACTIVE")")
        println("🌐 Chat Server: $(demo_state.server_running ? "✅ RUNNING" : "❌ STOPPED")")
        println("🚨 Incidents Detected: 1")
        println("📋 Latest Incident: CRITICAL - Flash Loan Attack")
        println("🛡️  Protection Status: FULLY OPERATIONAL")
    else
        println("❌ No user registered")
        println("💡 Please register first to see your protection status")
    end
    
    println()
end

function cleanup()
    println("🧹 Cleaning up...")
    
    if demo_state.monitoring_task !== nothing
        demo_state.monitoring_active = false
        try
            Base.schedule(demo_state.monitoring_task, InterruptException(), error=true)
        catch
        end
    end
    
    if demo_state.server_task !== nothing
        demo_state.server_running = false
        try
            Base.schedule(demo_state.server_task, InterruptException(), error=true)
        catch
        end
    end
    
    println("✅ Cleanup complete")
end

function show_menu()
    println("🎛️  " * "="^48 * "🎛️")
    println("🎛️   MAIN MENU")
    println("🎛️  " * "="^48 * "🎛️")
    println()
    println("   1️⃣  Register User Profile")
    println("   2️⃣  Start Protection Monitoring")
    println("   3️⃣  Simulate Attack Detection")
    println("   4️⃣  Start AI Chat Server")
    println("   5️⃣  Interactive Security Chat")
    println("   6️⃣  View System Status")
    println("   7️⃣  Exit Demo")
    println()
    print("🎯 Choose an option (1-7): ")
end

function main()
    try
        clear_screen()
        print_header()
        print_welcome()
        
        while true
            show_menu()
            choice = strip(readline())
            println()
            
            if choice == "1"
                register_user()
            elseif choice == "2"
                start_monitoring()
            elseif choice == "3"
                simulate_attack()
            elseif choice == "4"
                start_chat_server()
            elseif choice == "5"
                interactive_chat()
            elseif choice == "6"
                show_system_status()
            elseif choice == "7"
                println("👋 Thank you for using X-LiGo DeFi Protection!")
                println("🛡️  Stay safe in DeFi!")
                break
            else
                println("❌ Invalid choice. Please select 1-7.")
            end
            
            println()
            println("Press Enter to continue...")
            readline()
            clear_screen()
            print_header()
        end
    catch e
        if isa(e, InterruptException)
            println("\n\n🛑 Demo interrupted by user")
        else
            println("\n\n❌ Demo error: $e")
        end
    finally
        cleanup()
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
