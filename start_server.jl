#!/usr/bin/env julia

using Pkg
Pkg.activate(".")

# Load environment variables from .env file automatically
function load_env_file(env_file=".env")
    if isfile(env_file)
        println("📁 Loading environment variables from $env_file...")
        
        for line in readlines(env_file)
            # Skip comments and empty lines
            line = strip(line)
            if isempty(line) || startswith(line, "#")
                continue
            end
            
            # Parse KEY=VALUE format
            if contains(line, "=")
                key, value = split(line, "=", limit=2)
                key = strip(key)
                value = strip(value)
                
                # Remove quotes if present
                if (startswith(value, "\"") && endswith(value, "\"")) || 
                   (startswith(value, "'") && endswith(value, "'"))
                    value = value[2:end-1]
                end
                
                # Set environment variable
                ENV[key] = value
                println("  ✅ Loaded: $key")
            end
        end
        
        println("📋 Environment variables loaded successfully!")
    else
        println("⚠️  No .env file found - using system environment variables only")
    end
end

# Load environment variables first
load_env_file()

using XLiGo

println("🚀 Starting X-LiGo system with HTTP server...")

# Start the swarm (which will also start the API server)
result = XLiGo.start_swarm()

if result.success
    println("✅ System started successfully!")
    println("🌐 API server is running on http://localhost:3000")
    println("📋 Available endpoints:")
    println("  - GET /health   - Agent status")
    println("  - GET /status   - Detailed system status")
    println("")
    println("🧪 Test with: curl http://localhost:3000/health")
    println("")
    println("Press Ctrl+C to stop the server...")
    
    try
        # Keep the script running
        while true
            sleep(1)
        end
    catch InterruptException
        println("\n🛑 Stopping X-LiGo system...")
        XLiGo.stop_swarm()
        println("✅ System stopped.")
    end
else
    println("❌ Failed to start system: $(result.message)")
    exit(1)
end
