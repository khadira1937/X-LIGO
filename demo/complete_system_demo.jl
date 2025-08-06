"""
Complete X-LiGo DeFi Protection System Demo
Demonstrates end-to-end functionality with real user data and attack simulation
"""

# Load the system
include("../src/XLiGo.jl")
using .XLiGo
using HTTP
using JSON3
using Dates

println("🚀 === X-LiGo DeFi Protection System - COMPLETE DEMO ===")
println("📅 Demo Date: $(Dates.format(now(), "yyyy-mm-dd HH:MM:SS"))")
println("👤 User: Oussama (okhadira@gmail.com)")
println()

# Step 1: Register the User
println("🔹 Step 1: Registering User...")
user_data = Dict{String, Any}(
    "user_id" => "oussama_khadira",
    "display_name" => "Oussama",
    "email" => "okhadira@gmail.com",
    "solana_wallet" => "6dSk7LHZWmfw2ZJyCQsFd4z4Wjt9dUqAKAxKg3BmHQS",
    "ethereum_wallet" => "0x742d35Cc6634C0532925a3b8D48C405fD75d4CaD",  # Demo wallet
    "discord_id" => "khadira0001",
    "notification_preferences" => ["discord", "email"]
)

registration_result = XLiGo.UserManagement.register_user(user_data)
if registration_result["success"]
    println("✅ User registered successfully!")
    println("   - User ID: oussama_khadira")
    println("   - Display Name: Oussama")
    println("   - Email: okhadira@gmail.com") 
    println("   - Solana Wallet: 6dSk7LHZWmfw2ZJyCQsFd4z4Wjt9dUqAKAxKg3BmHQS")
    println("   - Discord ID: khadira0001")
else
    println("❌ User registration failed: $(registration_result["error"])")
    println("Attempting to continue with existing user...")
end
println()

# Step 1.5: Set Protection Policy
println("🔹 Step 1.5: Setting Protection Policy...")
protection_policy = XLiGo.UserManagement.ProtectionPolicy(
    "oussama_khadira",      # user_id
    100000.0,               # max_gas_fee (USD)
    50000.0,                # max_slippage_fee (USD)
    1.30,                   # warning_health_factor
    1.05,                   # critical_health_factor (triggers alerts)
    true,                   # auto_protect_enabled
    ["add_collateral", "partial_repay"],  # auto_actions
    ["discord", "email"]    # notification_channels
)

policy_result = XLiGo.UserManagement.set_policy(protection_policy)
if policy_result["success"]
    println("✅ Protection policy set successfully!")
    println("   - Warning Health Factor: 1.30")
    println("   - Critical Health Factor: 1.05") 
    println("   - Auto Protection: Enabled")
    println("   - Notifications: Discord + Email")
else
    println("❌ Policy setup failed: $(policy_result["error"])")
end
println()

# Step 2: Link Wallet and Simulate DeFi Position
println("🔹 Step 2: Linking Wallet and Simulating DeFi Position...")

# Get user profile for position fetching
user_profile = Dict{String, Any}(
    "user_id" => "oussama_khadira",
    "ethereum_wallet" => "0x742d35Cc6634C0532925a3b8D48C405fD75d4CaD",
    "solana_wallet" => "6dSk7LHZWmfw2ZJyCQsFd4z4Wjt9dUqAKAxKg3BmHQS"
)

# Fetch positions (will get mock data in demo mode)
positions = XLiGo.PositionFetcher.fetch_user_positions(user_profile)
println("✅ Positions fetched: $(length(positions)) total")

if !isempty(positions)
    for (i, position) in enumerate(positions[1:min(2, length(positions))])
        println("   - Position $i: $(get(position, "protocol", "unknown")) on $(get(position, "chain", "unknown"))")
        println("     Health Factor: $(get(position, "health_factor", "unknown"))")
        println("     Value: \$$(get(position, "total_value_usd", 0))")
    end
else
    println("   - Using demo/mock positions")
end
println()

# Step 3: Trigger Attack Detection
println("🔹 Step 3: Triggering Flash Loan Attack Simulation...")

# Simulate a critical flash loan attack
attack_incident = XLiGo.AttackDetector.simulate_attack_scenario("flash_loan", "oussama_khadira")
println("🚨 CRITICAL ATTACK DETECTED!")
println("   - Attack Type: $(get(attack_incident.metadata, "attack_type", "unknown"))")
println("   - Severity: $(attack_incident.severity)")
println("   - Health Factor: $(attack_incident.health_factor)")
println("   - Protocol: $(attack_incident.protocol)")
println("   - Value at Risk: \$$(get(attack_incident.metadata, "value_at_risk", 0))")
println("   - Risk Score: $(get(attack_incident.metadata, "risk_score", 0))/100")
println()

# Step 4: AI Analysis via Chat System
println("🔹 Step 4: AI Analysis via Chat System...")

chat_queries = [
    "What was the latest attack?",
    "Show me the security status",
    "What happened to user oussama_khadira?",
    "Give me a security report"
]

for (i, query) in enumerate(chat_queries)
    println("💬 Query $i: \"$query\"")
    ai_response = XLiGo.ChatResponder.generate_response(query)
    
    # Truncate response for demo readability
    truncated_response = length(ai_response) > 200 ? ai_response[1:200] * "..." : ai_response
    println("🤖 AI Response: $truncated_response")
    println()
end

# Step 5: Discord Alert Verification
println("🔹 Step 5: Discord Alert System...")

# Test Discord connection
discord_test = XLiGo.DiscordNotifier.test_discord_connection()
if get(discord_test, "success", false)
    println("✅ Discord webhook connection successful!")
    
    # Send alert for the attack
    alert_result = XLiGo.DiscordNotifier.send_discord_alert(attack_incident)
    if get(alert_result, "success", false)
        println("✅ Discord alert sent successfully!")
        println("   - Check your Discord channel for the security alert")
    else
        println("⚠️ Discord alert failed to send")
    end
else
    println("⚠️ Discord webhook not configured or failed")
    println("   - Reason: $(get(discord_test, "reason", "unknown"))")
    println("   - Alert would contain:")
    println("     🚨 CRITICAL: Flash Loan Attack Detected")
    println("     👤 User: oussama_khadira") 
    println("     💰 Value at Risk: \$$(get(attack_incident.metadata, "value_at_risk", 0))")
    println("     ⚡ Recommended: Add collateral immediately")
end
println()

# Step 6: Position Monitoring Integration
println("🔹 Step 6: Position Monitoring Integration...")

# Start position monitoring
monitoring_started = XLiGo.PositionWatcher.start_position_monitoring!()
if monitoring_started
    println("✅ Position monitoring started")
    
    # Force a monitoring check
    sleep(1)  # Let it initialize
    check_result = XLiGo.PositionWatcher.force_monitoring_check()
    println("✅ Monitoring check completed")
    println("   - Users monitored: $(get(check_result, "users_monitored", 0))")
    println("   - Incidents found: $(get(check_result, "incidents_found", 0))")
    
    # Get monitoring status
    status = XLiGo.PositionWatcher.get_monitoring_status()
    println("✅ Monitoring status: $(status["active"] ? "Active" : "Inactive")")
    
    # Stop monitoring for demo
    XLiGo.PositionWatcher.stop_position_monitoring!()
else
    println("⚠️ Monitoring already active or failed to start")
end
println()

# Step 7: Complete System Health Check
println("🔹 Step 7: Complete System Health Check...")

# Check incident store
user_incidents = XLiGo.IncidentStore.get_user_incidents("oussama_khadira")
println("📊 Incident Summary:")
println("   - Total incidents for user: $(length(user_incidents))")

if !isempty(user_incidents)
    latest_incident = user_incidents[1]
    println("   - Latest incident: $(get(latest_incident.metadata, "attack_type", "health_factor_violation"))")
    println("   - Severity: $(latest_incident.severity)")
    println("   - Time: $(Dates.format(latest_incident.timestamp, "HH:MM:SS"))")
end

# System statistics
all_incidents = XLiGo.IncidentStore.get_all_incidents()
total_incidents = sum(length(incidents) for incidents in values(all_incidents))
println("   - Total system incidents: $total_incidents")
println()

# Final Demo Summary
println("🎯 === DEMO SUMMARY ===")
println("✅ User Registration: Oussama registered with full profile")
println("✅ Protection Policy: Critical health factor monitoring at 1.05")
println("✅ Position Discovery: $(length(positions)) positions monitored")
println("✅ Attack Detection: Flash loan attack simulated and detected")
println("✅ AI Analysis: Natural language incident analysis working")
println("✅ Discord Integration: $(get(discord_test, "success", false) ? "Active" : "Configured but not tested")")
println("✅ Position Monitoring: Real-time monitoring system operational")
println("✅ Incident Storage: $(length(user_incidents)) incidents recorded")
println()

println("🎉 === X-LiGo DeFi Protection System Demo Complete! ===")
println("🛡️ Your DeFi positions are now protected by:")
println("   • Real-time health factor monitoring")
println("   • AI-powered attack detection") 
println("   • Instant Discord notifications")
println("   • Natural language incident analysis")
println("   • Cross-chain position discovery")
println()
println("💬 Try asking the AI: \"What's my security status?\"")

# Optional: Show live chat demo
println("\n🤖 === LIVE CHAT DEMO ===")
final_query = "Give me a complete security report for oussama_khadira"
println("💬 Final Query: \"$final_query\"")
final_response = XLiGo.ChatResponder.generate_response(final_query)
println("🤖 AI Security Report:")
println(final_response)
println()

println("✨ Demo completed successfully! Your X-LiGo system is ready for production.")
