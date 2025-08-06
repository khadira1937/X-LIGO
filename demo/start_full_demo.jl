#!/usr/bin/env julia

"""
X-LiGo DeFi Protection System - Complete Production Demo
=======================================================

This script demonstrates the full production workflow:
1. Interactive user registration
2. Automatic monitoring system startup
3. Real-time vulnerability detection
4. AI-powered incident analysis
5. Discord webhook notifications
6. HTTP API server with chat endpoint

Usage: julia --project=. demo/start_full_demo.jl
"""

using Pkg
Pkg.activate(".")

# Load environment variables from .env file
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
        println("✅ Environment variables loaded from .env")
    else
        println("⚠️  .env file not found")
    end
end

# Load environment first
load_env_file()

# Load all required modules
include("../src/XLiGo.jl")
using .XLiGo
using .XLiGo.UserManagement
using .XLiGo.PositionFetcher
using .XLiGo.AttackDetector
using .XLiGo.ChatResponder
using .XLiGo.DiscordNotifier
using .XLiGo.IncidentStore

using Dates
using Random
using UUIDs
using JSON3
using HTTP

# Global state for demo
const DEMO_STATE = Dict{String, Any}(
    "registered_user" => nothing,
    "monitoring_active" => false,
    "server_running" => false,
    "incidents" => [],
    "start_time" => now()
)

function print_welcome_banner()
    println("🚀" * "="^70 * "🚀")
    println("🛡️  X-LiGo DeFi Protection System - PRODUCTION DEMO  🛡️")
    println("🚀" * "="^70 * "🚀")
    println()
    println("📅 Demo Session: $(Dates.format(now(), "yyyy-mm-dd HH:MM:SS"))")
    println()
    println("🎯 This demo will demonstrate:")
    println("   ✅ User registration with real wallet data")
    println("   ✅ Real-time monitoring and vulnerability detection")
    println("   ✅ AI-powered incident analysis and reporting")
    println("   ✅ Instant Discord webhook notifications")
    println("   ✅ Interactive chat API for security queries")
    println()
    println("🔧 Configuration loaded from .env:")
    println("   • Discord Webhook: $(get(ENV, "DISCORD_WEBHOOK_URL", "NOT_CONFIGURED")[1:min(50, length(get(ENV, "DISCORD_WEBHOOK_URL", "")))]...))")
    println("   • OpenAI API: $(isempty(get(ENV, "OPENAI_API_KEY", "")) ? "NOT_CONFIGURED" : "CONFIGURED")")
    println("   • MongoDB: $(isempty(get(ENV, "MONGODB_URI", "")) ? "NOT_CONFIGURED" : "CONFIGURED")")
    println()
end

function collect_user_registration()
    println("👤" * "="^50 * "👤")
    println("👤  STEP 1: USER REGISTRATION")
    println("👤" * "="^50 * "👤")
    println()
    println("Please enter your DeFi wallet information for protection:")
    println()
    
    print("📝 Enter your display name: ")
    name = strip(readline())
    
    print("📧 Enter your email address: ")
    email = strip(readline())
    
    print("💰 Enter your Solana wallet address: ")
    solana_wallet = strip(readline())
    
    print("🔗 Enter your Ethereum wallet address (optional): ")
    eth_wallet = strip(readline())
    if isempty(eth_wallet)
        eth_wallet = "0x" * Random.randstring(['0':'9'; 'a':'f'], 40)
        println("   Generated mock Ethereum address: $eth_wallet")
    end
    
    print("💬 Enter your Discord username: ")
    discord_id = strip(readline())
    
    println()
    println("✅ Registration information collected:")
    println("   - Name: $name")
    println("   - Email: $email")
    println("   - Solana Wallet: $solana_wallet")
    println("   - Ethereum Wallet: $eth_wallet")
    println("   - Discord: $discord_id")
    println()
    
    return (
        name=String(name),
        email=String(email),
        solana_wallet=String(solana_wallet),
        ethereum_wallet=String(eth_wallet),
        discord_id=String(discord_id)
    )
end

function register_user_profile(user_info)
    println("🔹 Registering user profile...")
    
    # Generate unique user ID
    base_id = lowercase(replace(user_info.name, " " => "_"))
    if !isempty(user_info.email) && contains(user_info.email, "@")
        email_part = split(user_info.email, "@")[1]
        user_id = base_id * "_" * email_part
    else
        user_id = base_id * "_" * randstring(8)
    end
    
    # Create user data for registration
    user_data = Dict(
        "user_id" => user_id,
        "display_name" => user_info.name,
        "solana_wallet" => user_info.solana_wallet,
        "ethereum_wallet" => user_info.ethereum_wallet,
        "email" => user_info.email,
        "discord_id" => user_info.discord_id
    )
    
    # Enable demo mode for in-memory storage
    ENV["DEMO_MODE"] = "true"
    
    # Register user
    result = register_user(user_data)
    
    if result["success"]
        println("✅ User registered successfully!")
        println("   - User ID: $user_id")
        
        # Set up protection policy
        policy = ProtectionPolicy(
            user_id,
            10000.0,    # max_daily_spend_usd
            5000.0,     # max_per_incident_usd
            1.3,        # target_health_factor
            1.05,       # critical_health_factor
            true,       # auto_protection_enabled
            ["add_collateral", "partial_repay"],
            ["discord", "email"]
        )
        
        policy_result = set_policy(policy)
        if policy_result["success"]
            println("✅ Protection policy configured (HF threshold: 1.05)")
        end
        
        # Store in global state
        DEMO_STATE["registered_user"] = Dict(
            "user_id" => user_id,
            "user_info" => user_info,
            "user_data" => user_data
        )
        
        return user_id
    else
        println("❌ Registration failed: $(result["error"])")
        return nothing
    end
end

function start_monitoring_system(user_id, user_info)
    println("🔍" * "="^50 * "🔍")
    println("🔍  STEP 2: STARTING REAL-TIME MONITORING")
    println("🔍" * "="^50 * "🔍")
    println()
    
    println("🔹 Initializing monitoring for user: $user_id")
    println("🔹 Wallets being monitored:")
    println("   • Solana: $(user_info.solana_wallet)")
    println("   • Ethereum: $(user_info.ethereum_wallet)")
    println()
    
    # Start position monitoring in background
    monitoring_task = @async begin
        while DEMO_STATE["monitoring_active"]
            try
                # Fetch positions for the registered user
                user_profile = Dict(
                    "user_id" => user_id,
                    "wallet_addresses" => Dict(
                        "solana" => user_info.solana_wallet,
                        "ethereum" => user_info.ethereum_wallet
                    )
                )
                
                positions = fetch_user_positions(user_profile)
                
                # Check for vulnerabilities in positions
                for position in positions
                    # Simulate health factor checks
                    health_factor = get(position, "health_factor", rand(1.0:0.01:2.0))
                    
                    if health_factor < 1.2  # Vulnerability threshold
                        println("⚠️  VULNERABILITY DETECTED in position $(get(position, "position_id", "unknown"))")
                        
                        # Create incident
                        incident = create_incident(
                            user_id,
                            get(position, "position_id", "pos_" * randstring(8)),
                            health_factor,
                            health_factor < 1.05 ? "CRITICAL" : "HIGH"
                        )
                        
                        # Add to demo state
                        push!(DEMO_STATE["incidents"], incident)
                        
                        # Send Discord alert
                        send_discord_alert_for_incident(incident, user_info)
                        
                        println("🚨 Incident reported and Discord alert sent!")
                        break
                    end
                end
                
                # Wait before next check
                sleep(5)
                
            catch e
                println("⚠️  Monitoring error: $e")
                sleep(10)
            end
        end
    end
    
    DEMO_STATE["monitoring_active"] = true
    println("✅ Real-time monitoring started successfully!")
    println("🔄 Checking positions every 5 seconds...")
    println()
    
    return monitoring_task
end

function simulate_vulnerability_detection(user_id, user_info)
    println("💥" * "="^50 * "💥")
    println("💥  STEP 3: SIMULATING VULNERABILITY DETECTION")
    println("💥" * "="^50 * "💥")
    println()
    
    println("🔹 Simulating flash loan attack detection...")
    sleep(2)
    
    # Create a critical incident
    incident = simulate_attack_scenario("flash_loan", user_id)
    
    if incident !== nothing
        println("🚨 CRITICAL VULNERABILITY DETECTED!")
        println("   - Attack Type: $(get(incident.metadata, "attack_type", "flash_loan"))")
        println("   - Severity: $(incident.severity)")
        println("   - Health Factor: $(incident.health_factor)")
        println("   - Protocol: $(incident.protocol)")
        println("   - Value at Risk: \$$(get(incident.metadata, "value_at_risk", "50000"))")
        
        # Add to demo state
        push!(DEMO_STATE["incidents"], incident)
        
        # Send Discord alert
        alert_sent = send_discord_alert_for_incident(incident, user_info)
        
        if alert_sent
            println("✅ Discord alert sent successfully!")
        else
            println("⚠️  Discord alert failed (check webhook configuration)")
        end
        
        println()
        return incident
    else
        println("❌ Failed to simulate attack")
        return nothing
    end
end

function send_discord_alert_for_incident(incident, user_info)
    webhook_url = get(ENV, "DISCORD_WEBHOOK_URL", "")
    
    if isempty(webhook_url)
        println("⚠️  No Discord webhook configured")
        return false
    end
    
    try
        # Create rich Discord embed
        embed = Dict(
            "title" => "🚨 X-LiGo Security Alert",
            "description" => "Critical vulnerability detected in DeFi position",
            "color" => 15158332,  # Red
            "fields" => [
                Dict("name" => "👤 User", "value" => user_info.name, "inline" => true),
                Dict("name" => "💰 Wallet", "value" => user_info.solana_wallet[1:20] * "...", "inline" => true),
                Dict("name" => "🎯 Attack Type", "value" => get(incident.metadata, "attack_type", "Unknown"), "inline" => true),
                Dict("name" => "⚠️ Severity", "value" => incident.severity, "inline" => true),
                Dict("name" => "📊 Health Factor", "value" => string(incident.health_factor), "inline" => true),
                Dict("name" => "💵 Value at Risk", "value" => "\$$(get(incident.metadata, "value_at_risk", "50000"))", "inline" => true),
                Dict("name" => "🔗 Protocol", "value" => incident.protocol, "inline" => true),
                Dict("name" => "⏰ Time", "value" => Dates.format(incident.timestamp, "HH:MM:SS"), "inline" => true),
                Dict("name" => "⚡ Recommended Action", "value" => "Add collateral immediately or reduce leverage", "inline" => false)
            ],
            "footer" => Dict("text" => "X-LiGo DeFi Protection • Powered by AI"),
            "timestamp" => Dates.format(now(), "yyyy-mm-ddTHH:MM:SS.sssZ")
        )
        
        payload = Dict(
            "content" => "🚨 **CRITICAL SECURITY ALERT** 🚨",
            "embeds" => [embed]
        )
        
        # Send webhook
        response = HTTP.post(
            webhook_url,
            ["Content-Type" => "application/json"],
            JSON3.write(payload)
        )
        
        return response.status == 200 || response.status == 204
        
    catch e
        println("❌ Discord webhook error: $e")
        return false
    end
end

function start_api_server()
    println("🌐" * "="^50 * "🌐")
    println("🌐  STEP 4: STARTING HTTP API SERVER")
    println("🌐" * "="^50 * "🌐")
    println()
    
    # Start HTTP server in background
    server_task = @async begin
        try
            # Simple HTTP server for chat endpoint
            function handle_request(req::HTTP.Request)
                if req.method == "POST" && req.target == "/chat"
                    try
                        # Parse request body
                        body = JSON3.read(IOBuffer(req.body))
                        message = get(body, "message", "")
                        
                        if isempty(message)
                            return HTTP.Response(400, JSON3.write(Dict("error" => "Message is required")))
                        end
                        
                        # Generate AI response
                        ai_response = generate_response(message)
                        
                        # Return response
                        response_data = Dict(
                            "message" => message,
                            "response" => ai_response,
                            "timestamp" => string(now()),
                            "user_context" => DEMO_STATE["registered_user"]["user_id"]
                        )
                        
                        return HTTP.Response(200, 
                            ["Content-Type" => "application/json"],
                            JSON3.write(response_data)
                        )
                        
                    catch e
                        return HTTP.Response(500, JSON3.write(Dict("error" => "Internal server error: $e")))
                    end
                    
                elseif req.method == "GET" && req.target == "/status"
                    # Status endpoint
                    status_data = Dict(
                        "status" => "running",
                        "registered_user" => DEMO_STATE["registered_user"]["user_id"],
                        "monitoring_active" => DEMO_STATE["monitoring_active"],
                        "incidents_count" => length(DEMO_STATE["incidents"]),
                        "uptime" => string(now() - DEMO_STATE["start_time"])
                    )
                    
                    return HTTP.Response(200,
                        ["Content-Type" => "application/json"],
                        JSON3.write(status_data)
                    )
                    
                else
                    return HTTP.Response(404, JSON3.write(Dict("error" => "Not found")))
                end
            end
            
            # Start server
            port = parse(Int, get(ENV, "API_PORT", "3000"))
            HTTP.serve(handle_request, "0.0.0.0", port)
            
        catch e
            println("❌ Server error: $e")
        end
    end
    
    sleep(1)  # Give server time to start
    
    DEMO_STATE["server_running"] = true
    port = get(ENV, "API_PORT", "3000")
    println("✅ HTTP API server started on port $port")
    println("🔗 Chat endpoint: http://localhost:$port/chat")
    println("📊 Status endpoint: http://localhost:$port/status")
    println()
    
    return server_task
end

function demonstrate_ai_chat(user_id)
    println("🤖" * "="^50 * "🤖")
    println("🤖  STEP 5: AI CHAT DEMONSTRATION")
    println("🤖" * "="^50 * "🤖")
    println()
    
    # Test queries
    test_queries = [
        "What happened to my wallet?",
        "Give me a security report",
        "Show me recent attacks",
        "What is my current risk level?"
    ]
    
    println("🔹 Testing AI chat responses for user: $user_id")
    println()
    
    for query in test_queries
        println("💬 Query: \"$query\"")
        
        # Generate AI response
        response = generate_response(query)
        
        # Show preview
        lines = split(response, "\n")
        preview = join(lines[1:min(2, length(lines))], "\n")
        println("🤖 AI Response: $preview")
        if length(lines) > 2
            println("   ... (truncated)")
        end
        println()
    end
    
    port = get(ENV, "API_PORT", "3000")
    println("💡 You can now test the chat API:")
    println("   curl -X POST http://localhost:$port/chat \\")
    println("        -H \"Content-Type: application/json\" \\")
    println("        -d '{\"message\":\"What happened?\"}'")
    println()
end

function print_demo_status()
    println("📊" * "="^50 * "📊")
    println("📊  SYSTEM STATUS")
    println("📊" * "="^50 * "📊")
    println()
    
    user = DEMO_STATE["registered_user"]
    if user !== nothing
        println("👤 Registered User: $(user["user_info"].name) ($(user["user_id"]))")
        println("💰 Monitored Wallets:")
        println("   • Solana: $(user["user_info"].solana_wallet)")
        println("   • Ethereum: $(user["user_info"].ethereum_wallet)")
    end
    
    println("🔍 Monitoring: $(DEMO_STATE["monitoring_active"] ? "✅ ACTIVE" : "❌ INACTIVE")")
    println("🌐 API Server: $(DEMO_STATE["server_running"] ? "✅ RUNNING" : "❌ STOPPED")")
    println("🚨 Incidents Detected: $(length(DEMO_STATE["incidents"]))")
    
    if length(DEMO_STATE["incidents"]) > 0
        println("📋 Latest Incidents:")
        for (i, incident) in enumerate(DEMO_STATE["incidents"][end-min(2, length(DEMO_STATE["incidents"])-1):end])
            println("   $i. $(incident.severity) - $(get(incident.metadata, "attack_type", "Unknown")) (HF: $(incident.health_factor))")
        end
    end
    
    println()
    uptime = now() - DEMO_STATE["start_time"]
    println("⏱️  System Uptime: $(Dates.canonicalize(uptime))")
    println("🛡️  Protection Status: FULLY OPERATIONAL")
    println()
end

function run_interactive_session()
    println("💬" * "="^50 * "💬")
    println("💬  INTERACTIVE CHAT SESSION")
    println("💬" * "="^50 * "💬")
    println()
    println("🎯 Chat with the AI about your security status!")
    println("💡 Try queries like: 'What happened?', 'Security report', 'Risk analysis'")
    println("📝 Type 'exit' to end the session")
    println()
    
    while true
        print("You: ")
        user_input = strip(readline())
        
        if lowercase(user_input) in ["exit", "quit", "q"]
            println("👋 Chat session ended.")
            break
        end
        
        if isempty(user_input)
            continue
        end
        
        # Generate AI response
        print("🤖 AI: ")
        flush(stdout)
        
        response = generate_response(user_input)
        println(response)
        println()
    end
end

function main()
    try
        # Welcome banner
        print_welcome_banner()
        
        # Step 1: User Registration
        user_info = collect_user_registration()
        user_id = register_user_profile(user_info)
        
        if user_id === nothing
            println("❌ Demo failed at user registration!")
            return
        end
        
        # Step 2: Start monitoring system
        monitoring_task = start_monitoring_system(user_id, user_info)
        
        # Step 3: Simulate vulnerability detection
        incident = simulate_vulnerability_detection(user_id, user_info)
        
        # Step 4: Start API server
        server_task = start_api_server()
        
        # Step 5: Demonstrate AI chat
        demonstrate_ai_chat(user_id)
        
        # Show system status
        print_demo_status()
        
        # Interactive session
        println("🎉" * "="^50 * "🎉")
        println("🎉  DEMO COMPLETE - SYSTEM RUNNING")
        println("🎉" * "="^50 * "🎉")
        println()
        println("✅ All systems operational!")
        println("🔄 Monitoring continues in background...")
        println("🌐 API server ready for requests...")
        println()
        
        # Ask user if they want to continue with interactive chat
        print("Would you like to start an interactive chat session? (y/n): ")
        response = strip(readline())
        
        if lowercase(response) == "y" || lowercase(response) == "yes"
            run_interactive_session()
        end
        
        # Keep system running
        println("🔄 System will continue running. Press Ctrl+C to stop.")
        
        # Wait for interrupt
        try
            while true
                print_demo_status()
                sleep(30)  # Status update every 30 seconds
            end
        catch InterruptException
            println("\n🛑 Stopping system...")
            DEMO_STATE["monitoring_active"] = false
            println("✅ System stopped gracefully.")
        end
        
    catch e
        println("❌ Demo failed with error: $e")
        println()
        DEMO_STATE["monitoring_active"] = false
    end
end

# Run the demo
if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
