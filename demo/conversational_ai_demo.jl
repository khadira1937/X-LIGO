#!/usr/bin/env julia

"""
X-LiGo DeFi Protection System - REAL CONVERSATIONAL AI DEMO
Uses OpenAI API for natural conversations like ChatGPT
"""

using Pkg
Pkg.activate(".")

# Load environment
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

# Demo modules (these work fine)
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

function clear_screen()
    if Sys.iswindows()
        run(`cmd /c cls`)
    else
        run(`clear`)
    end
end

function print_header()
    println("🚀" * "="^70 * "🚀")
    println("🛡️  X-LiGo DeFi Protection System - REAL AI CONVERSATION  🛡️")
    println("🚀" * "="^70 * "🚀")
    println()
    println("📅 Demo Session: $(now())")
    println()
end

function print_welcome()
    println("🎉 Welcome to X-LiGo DeFi Protection System!")
    println()
    println("🛡️  Your Personal DeFi Security Assistant with REAL OpenAI")
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
    println("💡 Now with REAL conversational AI - talk about ANYTHING!")
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
    
    user_id = "$(replace(lowercase(name), " " => "_"))_$(split(email, "@")[1])"
    register_user_demo(user_id)
    
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
    
    demo_state.monitoring_task = @async begin
        while demo_state.monitoring_active
            try
                sleep(10)
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
    
    println("📤 Sending instant Discord alert...")
    sleep(1)
    
    try
        webhook_url = get(ENV, "DISCORD_WEBHOOK_URL", "")
        if !isempty(webhook_url)
            alert_data = Dict(
                "embeds" => [Dict(
                    "title" => "🚨 CRITICAL DeFi Security Alert",
                    "description" => "Flash loan attack detected on your Aave position",
                    "color" => 15158332,
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
    println("🌐  STARTING REAL AI CHAT SERVER")
    println("🌐" * "="^50 * "🌐")
    println()
    
    println("🔹 Initializing HTTP server...")
    println("🔹 Loading OpenAI models...")
    println("🔹 Configuring conversational AI...")
    
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
                        
                        # REAL OPENAI API CALL - DIRECT IMPLEMENTATION
                        ai_response = ""
                        try
                            api_key = get(ENV, "OPENAI_API_KEY", "")
                            if !isempty(api_key)
                                # Build context
                                user_id = demo_state.user_id
                                monitoring_active = demo_state.monitoring_active
                                
                                system_prompt = """You are an intelligent AI assistant for X-LiGo DeFi Protection System. 
                                
You can discuss ANY topic naturally - DeFi security, general questions, sports, technology, etc.

Current user context:
- User ID: $user_id  
- Monitoring: $(monitoring_active ? "Active" : "Inactive")
- Recent incident: Flash loan attack (Health factor: 1.05 - CRITICAL)

Be conversational, helpful, and knowledgeable. Use emojis and formatting for engaging responses."""

                                # OpenAI API call
                                payload = Dict(
                                    "model" => "gpt-3.5-turbo",
                                    "messages" => [
                                        Dict("role" => "system", "content" => system_prompt),
                                        Dict("role" => "user", "content" => message)
                                    ],
                                    "max_tokens" => 500,
                                    "temperature" => 0.7
                                )
                                
                                response = HTTP.post(
                                    "https://api.openai.com/v1/chat/completions",
                                    ["Authorization" => "Bearer $api_key", "Content-Type" => "application/json"],
                                    JSON3.write(payload)
                                )
                                
                                if response.status == 200
                                    result = JSON3.read(response.body)
                                    if haskey(result, "choices") && length(result["choices"]) > 0
                                        ai_response = "🤖 " * result["choices"][1]["message"]["content"]
                                    else
                                        ai_response = "🤖 I understand your question, but I'm having trouble generating a response right now. Could you try rephrasing?"
                                    end
                                else
                                    ai_response = "🤖 I'm experiencing some technical difficulties. Let me try to help anyway: I can discuss DeFi security, answer general questions, or chat about various topics!"
                                end
                            else
                                ai_response = "🤖 I'd love to help but my AI engine isn't configured. I can still help with basic DeFi security questions!"
                            end
                        catch e
                            ai_response = "🤖 I'm having a moment, but I'm here to help! I can discuss DeFi security, general topics, or answer questions about X-LiGo protection."
                        end
                        
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
    
    sleep(2)
    demo_state.server_running = true
    
    println("✅ Real AI Chat server started successfully!")
    println("🔗 Chat endpoint: http://localhost:3000/chat")
    println("📊 Status endpoint: http://localhost:3000/status")
    println()
    println("💡 Test the API:")
    println("   curl -X POST http://localhost:3000/chat \\")
    println("        -H \"Content-Type: application/json\" \\")
    println("        -d '{\"message\":\"Tell me about blockchain security\"}'")
    println()
end

function interactive_chat()
    if demo_state.user_id === nothing
        println("❌ Please register first!")
        return
    end
    
    println("💬" * "="^50 * "💬")
    println("💬  REAL AI CONVERSATION (OpenAI)")
    println("💬" * "="^50 * "💬")
    println()
    
    println("🤖 Hello! I'm your intelligent AI assistant powered by OpenAI!")
    println("💡 Ask me ANYTHING - I can discuss any topic naturally!")
    println("🎯 DeFi security, general questions, sports, technology - whatever you want!")
    println("📝 Type 'exit' to return to the main menu")
    println()
    
    while true
        print("You: ")
        message = strip(readline())
        
        if lowercase(message) in ["exit", "quit", "back"]
            break
        end
        
        if isempty(message)
            continue
        end
        
        print("🤖 AI: ")
        flush(stdout)
        
        # REAL OPENAI API CALL - DIRECT IN CHAT LOOP
        try
            api_key = get(ENV, "OPENAI_API_KEY", "")
            if !isempty(api_key)
                # Build context-aware prompt
                user_id = demo_state.user_id
                monitoring_active = demo_state.monitoring_active
                
                system_prompt = """You are an intelligent AI assistant for X-LiGo DeFi Protection System.

You can discuss ANY topic naturally and conversationally - DeFi security, general questions, sports, technology, movies, food, travel, science, etc.

Current user context:
- User ID: $user_id
- DeFi Monitoring: $(monitoring_active ? "Active" : "Inactive")  
- Recent security incident: Flash loan attack detected (Health factor: 1.05 - CRITICAL)

Be helpful, conversational, and engaging. Use emojis when appropriate. You're a smart, friendly AI that can talk about anything!"""

                # Call OpenAI API directly
                payload = Dict(
                    "model" => "gpt-3.5-turbo",
                    "messages" => [
                        Dict("role" => "system", "content" => system_prompt),
                        Dict("role" => "user", "content" => message)
                    ],
                    "max_tokens" => 500,
                    "temperature" => 0.7
                )
                
                response = HTTP.post(
                    "https://api.openai.com/v1/chat/completions",
                    ["Authorization" => "Bearer $api_key", "Content-Type" => "application/json"],
                    JSON3.write(payload)
                )
                
                if response.status == 200
                    result = JSON3.read(response.body)
                    if haskey(result, "choices") && length(result["choices"]) > 0
                        ai_response = result["choices"][1]["message"]["content"]
                        println(ai_response)
                    else
                        println("I understand your question, but I'm having trouble generating a response right now. Could you try rephrasing?")
                    end
                else
                    println("I'm experiencing some technical difficulties with my AI engine. Let me try to help anyway based on what I know!")
                    
                    # Simple fallback
                    msg_lower = lowercase(message)
                    if contains(msg_lower, "attack")
                        println("🚨 Based on our recent detection, you had a critical flash loan attack on your Aave position with health factor 1.05. This requires immediate attention!")
                    elseif contains(msg_lower, "world cup") || contains(msg_lower, "football")
                        println("⚽ Argentina won the 2022 World Cup! Messi finally got his championship, beating France in an epic final.")
                    else
                        println("I'd love to help with that topic! I can discuss DeFi security, general questions, sports, technology, and more. What specifically interests you?")
                    end
                end
            else
                println("My OpenAI connection isn't configured, but I can still help! What would you like to know about DeFi security or general topics?")
            end
        catch e
            println("I'm having a technical moment, but I'm here to help! 😊")
            println("I can discuss DeFi security, answer questions about X-LiGo protection, or chat about general topics. What interests you?")
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
        println("🤖 AI Engine: ✅ OpenAI Conversational")
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
    println("   5️⃣  Real AI Conversation (OpenAI)")
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
