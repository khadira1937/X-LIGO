#!/usr/bin/env julia

"""
Test Discord Webhook - Verify Discord notifications work
"""

using Pkg
Pkg.activate(".")

using HTTP
using JSON3
using Dates

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

function test_discord_webhook()
    # Load environment first
    load_env_file()
    
    println("🔔 Testing Discord Webhook...")
    
    webhook_url = get(ENV, "DISCORD_WEBHOOK_URL", "")
    
    if isempty(webhook_url)
        println("❌ No Discord webhook URL configured in .env")
        println("Please add DISCORD_WEBHOOK_URL to your .env file")
        return false
    end
    
    try
        # Create test message
        test_embed = Dict(
            "title" => "🧪 X-LiGo Test Alert",
            "description" => "Testing Discord webhook integration",
            "color" => 3447003,  # Blue
            "fields" => [
                Dict("name" => "🔔 Status", "value" => "Webhook Test", "inline" => true),
                Dict("name" => "⏰ Time", "value" => Dates.format(now(), "HH:MM:SS"), "inline" => true),
                Dict("name" => "✅ Result", "value" => "Successfully connected!", "inline" => false)
            ],
            "footer" => Dict("text" => "X-LiGo DeFi Protection • Test Mode"),
            "timestamp" => Dates.format(now(), "yyyy-mm-ddTHH:MM:SS.sssZ")
        )
        
        payload = Dict(
            "content" => "🧪 **X-LiGo Webhook Test** 🧪",
            "embeds" => [test_embed]
        )
        
        # Send test message
        response = HTTP.post(
            webhook_url,
            ["Content-Type" => "application/json"],
            JSON3.write(payload)
        )
        
        if response.status == 200 || response.status == 204
            println("✅ Discord webhook test successful!")
            println("   Check your Discord channel for the test message.")
            return true
        else
            println("❌ Discord webhook failed with status: $(response.status)")
            return false
        end
        
    catch e
        println("❌ Discord webhook error: $e")
        return false
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    test_discord_webhook()
end
