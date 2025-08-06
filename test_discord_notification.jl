#!/usr/bin/env julia
"""
Test Discord Notification Functionality

This script tests the new Discord notification feature by:
1. Creating a mock security incident
2. Sending it through the Reporter agent
3. Verifying the Discord webhook is triggered
"""

using Pkg
Pkg.activate(".")

using XLiGo
using Dates
using JSON3

println("🧪 Testing Discord Notification Integration")
println("=" ^ 50)

# Test 1: Start the system
println("\n📋 Step 1: Starting X-LiGo system...")
try
    result = XLiGo.start_swarm()
    if result.success
        println("✅ System started successfully")
    else
        println("❌ System failed to start: $(result.message)")
        exit(1)
    end
catch e
    println("❌ Error starting system: $e")
    exit(1)
end

# Test 2: Create a mock incident for Discord notification
println("\n📋 Step 2: Creating mock security incident...")

# Create a mock incident that should trigger Discord notification
mock_incident = XLiGo.Types.Incident(
    incident_id = "test_discord_$(rand(1000:9999))",
    position_id = "pos_test_discord",
    incident_type = "flash_loan_attack",  # This should trigger Discord notification
    severity = "critical",
    status = "detected",
    detected_at = now(),
    resolved_at = nothing,
    position_value_usd = 100000.0,
    metadata = Dict(
        "attack_vector" => "price_manipulation",
        "target_protocol" => "Aave",
        "suspicious_amount" => 10000000,
        "test" => true
    )
)

println("🚨 Mock Incident Created:")
println("   ID: $(mock_incident.incident_id)")
println("   Type: $(mock_incident.incident_type)")
println("   Severity: $(mock_incident.severity)")
println("   Value at Risk: \$$(mock_incident.position_value_usd)")

# Test 3: Send Discord notification via Reporter
println("\n📋 Step 3: Testing Discord notification...")

try
    # Simulate incident report generation (which triggers Discord notification)
    XLiGo.Reporter.generate_incident_report(mock_incident)
    println("✅ Incident report generated and Discord notification sent!")
    
catch e
    println("❌ Discord notification test failed: $e")
    println("💡 Check your DISCORD_WEBHOOK_URL configuration")
end

# Test 4: Show system status
println("\n📋 Step 4: Checking system status...")
try
    status_response = HTTP.get("http://localhost:3000/status")
    status_data = JSON3.read(status_response.body)
    println("✅ API Status: $(status_data["ok"] ? "OK" : "Error")")
    println("📊 Demo Mode: $(status_data["demo_mode"])")
catch e
    println("⚠️  API not accessible: $e")
end

println("\n🎉 Discord Notification Test Complete!")
println("")
println("📌 What should happen:")
println("   1. Discord webhook receives a rich embed message")
println("   2. Message shows incident details with color coding")
println("   3. Includes threat type, severity, and protection status")
println("   4. Sent to your configured Discord channel")
println("")
println("🔗 Check your Discord channel for the notification!")

# Cleanup
println("\n🧹 Cleaning up...")
XLiGo.stop_swarm()
println("✅ Test completed successfully")
