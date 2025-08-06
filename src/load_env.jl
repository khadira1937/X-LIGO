"""
Environment variable loading utility for X-LiGo
"""

function load_env_file(env_file = ".env")
    if !isfile(env_file)
        @warn "Environment file not found: $env_file"
        return
    end
    
    try
        for line in readlines(env_file)
            line = strip(line)
            
            # Skip empty lines and comments
            if isempty(line) || startswith(line, "#")
                continue
            end
            
            # Parse key=value pairs
            if contains(line, "=")
                key, value = split(line, "=", limit=2)
                key = strip(key)
                value = strip(value)
                
                # Remove quotes if present
                if (startswith(value, '"') && endswith(value, '"')) || 
                   (startswith(value, "'") && endswith(value, "'"))
                    value = value[2:end-1]
                end
                
                ENV[key] = value
            end
        end
        
        println("✅ Environment variables loaded from $env_file")
    catch e
        @error "Failed to load environment file: $e"
    end
end
