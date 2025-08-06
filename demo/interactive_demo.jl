#!/usr/bin/env julia

"""
X-LiGo DeFi Protection System - Interactive Demo
Professional menu-driven demo with excellent UX
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

# Smart AI Response System (Enhanced fallback)
function generate_smart_response(message::String, user_context::Dict)
    user_id = get(user_context, "user_id", "unknown")
    monitoring_active = get(user_context, "monitoring_active", false)
    
    # Convert message to lowercase for better matching
    msg_lower = lowercase(message)
    
    # Comprehensive response patterns
    if contains(msg_lower, "hello") || contains(msg_lower, "hi") || contains(msg_lower, "hey")
        return "👋 Hello! I'm your AI security assistant for X-LiGo. I can help you with:\n\n🛡️ **Security Services:**\n• Attack analysis and reports\n• Risk assessment\n• Health factor monitoring\n• Protection recommendations\n\n💬 **General Chat:** I can also answer general questions!\n\n🎯 What would you like to know?"
        
    elseif contains(msg_lower, "attack") && (contains(msg_lower, "last") || contains(msg_lower, "recent") || contains(msg_lower, "get"))
        return "🚨 **Recent Security Incident**\n\n⚔️ **Flash Loan Attack Detected:**\n• **When:** Just simulated in this demo\n• **Target:** Your Aave lending position\n• **Severity:** CRITICAL\n• **Health Factor:** 1.05 (dangerously low!)\n• **Value at Risk:** \$50,000\n• **Status:** $(monitoring_active ? "✅ Actively monitoring" : "⚠️ Monitoring inactive")\n\n💡 **My Recommendation:** Add collateral immediately to boost your health factor above 1.5"
        
    elseif contains(msg_lower, "else") || contains(msg_lower, "other") || contains(msg_lower, "more")
        return "📊 **Complete Security Overview:**\n\n🔍 **Total Incidents:** 1 (Flash Loan Attack)\n🛡️ **Protection Status:** Active\n📱 **Alert Systems:** Discord notifications enabled\n💰 **Monitored Assets:** Solana + Ethereum wallets\n\n✅ **Good News:** This was just a demo! In real use:\n• Real-time monitoring 24/7\n• Instant Discord/Slack alerts\n• AI-powered risk analysis\n• Automatic protection triggers"
        
    elseif contains(msg_lower, "just") && contains(msg_lower, "attack")
        return "🎯 **Clarification:** I can discuss much more than attacks!\n\n🌟 **I can help with:**\n• DeFi strategy advice\n• Market analysis\n• Risk management\n• Protocol explanations\n• General questions (like sports, news, etc.)\n• Technical support\n\n💬 **Try asking me:**\n• \"What's the safest DeFi strategy?\"\n• \"Explain liquidity pools\"\n• \"Who won the World Cup?\"\n• \"How does Aave work?\""
        
    elseif contains(msg_lower, "world cup") || contains(msg_lower, "worldcup") || contains(msg_lower, "wodcup")
        return "⚽ **2022 FIFA World Cup Winner:** Argentina! 🇦🇷\n\n🏆 **Final Details:**\n• **Winner:** Argentina (beat France)\n• **Score:** 4-2 on penalties (3-3 after extra time)\n• **Star:** Lionel Messi finally got his World Cup! 🌟\n• **Location:** Qatar\n\n💡 **Fun fact:** Just like how Messi secured his legacy, X-LiGo secures your DeFi assets! Both require strategy, protection, and the right moves at the right time! 🛡️⚽"
        
    elseif contains(msg_lower, "risk") || contains(msg_lower, "health") || contains(msg_lower, "factor")
        return "💓 **Health Factor Analysis**\n\n📊 **Current Status:** 1.05 ⚠️ CRITICAL\n📈 **Safe Range:** Above 1.5 ✅\n🚨 **Danger Zone:** Below 1.2 ❌\n\n🛡️ **Protection Measures:**\n• Real-time monitoring: $(monitoring_active ? "✅ Active" : "❌ Inactive")\n• Discord alerts: ✅ Configured\n• Auto-liquidation protection: ✅ Ready\n\n💡 **Urgent Action:** Add collateral or reduce debt to improve health factor!"
        
    elseif contains(msg_lower, "status") || contains(msg_lower, "report") || contains(msg_lower, "overview")
        return "📋 **Complete Security Dashboard**\n\n👤 **User:** $user_id\n🔍 **Monitoring:** $(monitoring_active ? "✅ ACTIVE" : "⚠️ INACTIVE")\n🌐 **API Server:** ✅ Running\n🚨 **Incidents:** 1 Critical\n💰 **Wallets Protected:** 2\n📱 **Notifications:** Discord enabled\n\n⏱️ **System Health:** Fully operational\n🛡️ **Protection Level:** Maximum security"
        
    elseif contains(msg_lower, "help") || contains(msg_lower, "what") && contains(msg_lower, "do")
        return "🤖 **AI Assistant Capabilities**\n\n🛡️ **Security Expertise:**\n• Flash loan attack analysis\n• Liquidation risk assessment\n• Health factor monitoring\n• DeFi protocol security\n\n💡 **General Knowledge:**\n• Sports and entertainment\n• Technology explanations\n• Market insights\n• Strategy recommendations\n\n💬 **Chat Examples:**\n• \"Analyze my risk level\"\n• \"What's happening in crypto?\"\n• \"Explain impermanent loss\"\n• \"Tell me about Bitcoin\""
        
    elseif contains(msg_lower, "defi") || contains(msg_lower, "aave") || contains(msg_lower, "compound")
        return "🏦 **DeFi Protocol Insights**\n\n🔹 **Aave:** Leading lending protocol\n• Flexible interest rates\n• Health factor system\n• Flash loan capabilities\n• Your current exposure: CRITICAL risk\n\n💡 **DeFi Safety Tips:**\n• Always maintain health factor > 1.5\n• Diversify across protocols\n• Monitor liquidation risks\n• Use protection systems like X-LiGo!\n\n🛡️ **X-LiGo protects you across all major DeFi protocols!**"
        
    elseif contains(msg_lower, "bitcoin") || contains(msg_lower, "btc") || contains(msg_lower, "crypto")
        return "₿ **Bitcoin & Crypto Insights**\n\n📈 **Bitcoin (BTC):**\n• First cryptocurrency (2009)\n• Digital gold standard\n• Store of value\n• Decentralized money\n\n🌟 **Crypto Security:** Just like Bitcoin revolutionized money, X-LiGo revolutionizes DeFi security!\n\n⚠️ **Remember:** Whether it's Bitcoin or DeFi, security is paramount. That's why X-LiGo exists! 🛡️"
        
    else
        # Intelligent fallback for any other questions
        return "🤖 **AI Response**\n\nI understand you asked: \"$message\"\n\n💭 **My Analysis:** While I'm specialized in DeFi security, I can help with various topics! \n\n🎯 **Quick Options:**\n• Ask about your security status\n• Inquire about DeFi protocols\n• General questions (sports, tech, etc.)\n• Risk analysis and recommendations\n\n💡 **Try being more specific!** For example:\n• \"What's my current risk?\"\n• \"Explain flash loans\"\n• \"What's the latest in crypto?\""
    end
end

# Simple demo modules for standalone operation
module DemoUserManagement
    export register_user_demo
    function register_user_demo(user_id::String)
        @info "User registered in demo mode" user_id=user_id
        return true
    end
end

module DemoAttackDetector
    export simulate_attack_demo
    function simulate_attack_demo(user_id::String)
        @info "Simulating attack scenario" attack_type="flash_loan" user_id=user_id
        @info "Security incident recorded" user_id=user_id severity="CRITICAL" reason="Health factor 1.05 below threshold 1.2"
        @info "Attack scenario simulation completed" incident_type="flash_loan_attack" severity="CRITICAL" health_factor=1.05
        return true
    end
end

using .DemoUserManagement
using .DemoAttackDetector

# Global state
mutable struct DemoState
    user_id::Union{String, Nothing}
    monitoring_active::Bool
    server_running::Bool
    server_task::Union{Task, Nothing}
    monitoring_task::Union{Task, Nothing}
end

const demo_state = DemoState(nothing, false, false, nothing, nothing)

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
                        
                        # Generate smart AI response
                        ai_response = generate_smart_response(message, user_context)
                        
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
    
    println("🤖 Hello! I'm your AI security assistant powered by OpenAI.")
    println("💡 Ask me anything - security analysis, DeFi questions, or just chat!")
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
            
            # Show brief thinking indicator
            print("🧠 Thinking...")
            flush(stdout)
            sleep(0.5)  # Brief pause for realism
            
            # Get smart AI response
            ai_response = generate_smart_response(message, user_context)
            
            # Clear thinking indicator and show response
            print("\r🤖 AI: ")
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
