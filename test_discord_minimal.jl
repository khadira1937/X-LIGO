#!/usr/bin/env julia
"""
Minimal Discord Notification Test

This script tests ONLY the Discord webhook functionality without loading the full XLiGo system.
No complex types, no dependencies - just HTTP + JSON + Discord webhook.
"""

using HTTP
using JSON3
using Dates

println("🧪 Minimal Discord Notification Test")
println("=" ^ 40)

# Get Discord webhook URL from environment
discord_webhook_url = get(ENV, "DISCORD_WEBHOOK_URL", "")

if isempty(discord_webhook_url)
    println("❌ No DISCORD_WEBHOOK_URL found in environment")
    println("💡 Make sure your .env file is loaded or set the environment variable")
    exit(1)
end

println("✅ Discord webhook URL configured")
println("🔗 Webhook: $(discord_webhook_url[1:50])...")

# Create a minimal incident dictionary (no complex types needed)
incident = Dict(
    "incident_id" => "demo_test_$(rand(1000:9999))",
    "position_id" => "pos_demo_test",
    "protocol" => "Aave",
    "incident_type" => "flash_loan_attack",
    "severity" => "critical",
    "status" => "detected",
    "position_value_usd" => 75000.0,
    "attack_vector" => "price_manipulation",
    "detected_at" => string(now()),
    "description" => "Large flash loan detected attempting to manipulate oracle prices"
)

println("\n🚨 Test Incident Created:")
println("   ID: $(incident["incident_id"])")
println("   Type: $(incident["incident_type"])")
println("   Severity: $(incident["severity"])")
println("   Value at Risk: \$$(incident["position_value_usd"])")

# Create Discord embed message
function create_discord_embed(incident)
    # Color coding based on severity
    color = if incident["severity"] == "critical"
        15158332  # Red
    elseif incident["severity"] == "high"
        16776960  # Yellow
    else
        255       # Blue
    end
    
    embed = Dict(
        "title" => "🚨 X-LiGo Security Alert",
        "description" => "DeFi threat detected and processed by X-LiGo Protection System",
        "color" => color,
        "timestamp" => incident["detected_at"],
        "fields" => [
            Dict("name" => "Incident ID", "value" => incident["incident_id"], "inline" => true),
            Dict("name" => "Position ID", "value" => incident["position_id"], "inline" => true),
            Dict("name" => "Severity", "value" => uppercase(incident["severity"]), "inline" => true),
            Dict("name" => "Type", "value" => incident["incident_type"], "inline" => true),
            Dict("name" => "Status", "value" => uppercase(incident["status"]), "inline" => true),
            Dict("name" => "Value at Risk", "value" => "\$$(incident["position_value_usd"])", "inline" => true),
            Dict("name" => "Attack Vector", "value" => incident["attack_vector"], "inline" => false),
            Dict("name" => "Protocol", "value" => incident["protocol"], "inline" => true)
        ],
        "footer" => Dict("text" => "X-LiGo DeFi Protection System • Demo Test")
    )
    
    # Add protection status
    if incident["status"] == "protected"
        push!(embed["fields"], Dict("name" => "✅ Protection", "value" => "Threat successfully blocked", "inline" => false))
    elseif incident["status"] == "detected"
        push!(embed["fields"], Dict("name" => "🔍 Detection", "value" => "Threat detected - processing protection measures", "inline" => false))
    end
    
    return embed
end

# Send Discord notification
function send_discord_notification(incident, webhook_url)
    try
        embed = create_discord_embed(incident)
        
        # Create Discord webhook payload
        payload = Dict(
            "embeds" => [embed],
            "username" => "X-LiGo Security Bot",
            "content" => "🚨 **SECURITY ALERT** - DeFi threat detected!"
        )
        
        println("\n📤 Sending Discord notification...")
        
        # Send HTTP POST to Discord webhook
        response = HTTP.post(
            webhook_url,
            ["Content-Type" => "application/json"],
            JSON3.write(payload);
            timeout=10
        )
        
        if response.status == 204  # Discord returns 204 for successful webhook
            println("✅ Discord notification sent successfully!")
            println("📱 Check your Discord channel for the security alert")
            return true
        else
            println("⚠️  Discord webhook returned status $(response.status)")
            return false
        end
        
    catch e
        println("❌ Failed to send Discord notification: $e")
        return false
    end
end

# Test the Discord notification
println("\n📢 Testing Discord webhook...")
success = send_discord_notification(incident, discord_webhook_url)

if success
    println("\n🎉 Discord Integration Test PASSED!")
    println("")
    println("📋 What you should see in Discord:")
    println("   🚨 Red alert embed with incident details")
    println("   📊 Incident ID, severity, value at risk")
    println("   🛡️ Attack vector and protection status")
    println("   ⏰ Timestamp of detection")
    println("")
    println("✅ X-LiGo Discord notifications are working!")
else
    println("\n❌ Discord Integration Test FAILED!")
    println("💡 Check your Discord webhook URL and network connection")
end
