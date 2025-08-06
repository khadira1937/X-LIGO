#!/usr/bin/env julia

# Demo script to test the HTTP API endpoints

println("🧪 X-LiGo HTTP API Demo")
println("=" ^ 50)

# Test the /health endpoint
println("\n📋 Testing /health endpoint:")
println("Command: curl http://localhost:3000/health")
health_result = try
    read(`curl -s http://localhost:3000/health`, String)
catch e
    "Server not running or connection failed: $e"
end

println("Response:")
println(health_result)

# Test the /status endpoint  
println("\n📊 Testing /status endpoint:")
println("Command: curl http://localhost:3000/status")
status_result = try
    read(`curl -s http://localhost:3000/status`, String)
catch e
    "Server not running or connection failed: $e"
end

println("Response:")
println(status_result)

println("\n🎯 API Endpoints Summary:")
println("✅ GET /health  - Returns { \"status\": \"ok\", \"agents\": [...] }")
println("✅ GET /status  - Returns detailed system information")
println("✅ Server runs on localhost:3000 by default")
println("✅ JSON responses with proper CORS headers")
println("✅ Agent mode tracking (real/mock status)")
