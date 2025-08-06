"""
Configuration management for X-LiGo system.

Handles environment variables, default settings, and configuration validation.
"""
module Config

using Logging

export load_config, getc, asdict

"""
    getc(cfg::Dict, key::Symbol, default)

Get configuration value with fallback to default.
"""
function getc(cfg::Dict, key::Symbol, default)
    return haskey(cfg, String(key)) ? cfg[String(key)] : default
end

"""
    asdict(cfg)::Dict

Convert configuration to Dict format.
"""
function asdict(cfg)::Dict
    return cfg
end

"""
    load_config()::Dict{String,Any}

Load configuration from environment variables with sensible defaults.
"""
function load_config()::Dict{String,Any}
    config = Dict{String,Any}(
        # Database Configuration
        "mongodb_uri" => get(ENV, "MONGODB_URI", "mongodb://localhost:27017/xligo"),
        "redis_url" => get(ENV, "REDIS_URL", "redis://localhost:6379"),
        
        # Blockchain Configuration
        "solana_rpc_url" => get(ENV, "SOLANA_RPC_URL", "https://api.devnet.solana.com"),
        "solana_ws_url" => get(ENV, "SOLANA_WS_URL", "wss://api.devnet.solana.com"),
        "ethereum_rpc_url" => get(ENV, "ETHEREUM_RPC_URL", "https://sepolia.infura.io/v3/demo"),
        
        # Oracle Configuration
        "pyth_program_id" => get(ENV, "PYTH_PROGRAM_ID", "gSbePebfvPy7tRqimPoVecS2UsBvYv46ynrzWocc92s"),
        "pyth_ws_url" => get(ENV, "PYTH_WS_URL", "wss://pythnet.rpcpool.com"),
        
        # API Configuration
        "api_port" => parse(Int, get(ENV, "API_PORT", "3000")),
        "ws_port" => parse(Int, get(ENV, "WS_PORT", "3001")),
        "log_level" => get(ENV, "LOG_LEVEL", "info"),
        
        # Security Configuration
        "jwt_secret" => get(ENV, "JWT_SECRET", "X-LiGo-2025-Super-Secret-Key-demo-jwt-token"),
        "encryption_key" => get(ENV, "ENCRYPTION_KEY", "XLiGo2025SecureEncryptionKey32Char"),
        
        # Agent Configuration
        "swarm_update_interval_ms" => parse(Int, get(ENV, "SWARM_UPDATE_INTERVAL_MS", "1000")),
        "prediction_horizon_minutes" => parse(Int, get(ENV, "PREDICTION_HORIZON_MINUTES", "30")),
        "max_batch_size" => parse(Int, get(ENV, "MAX_BATCH_SIZE", "10")),
        "netting_timeout_seconds" => parse(Int, get(ENV, "NETTING_TIMEOUT_SECONDS", "5")),
        
        # LLM Configuration
        "openai_api_key" => get(ENV, "OPENAI_API_KEY", ""),
        "anthropic_api_key" => get(ENV, "ANTHROPIC_API_KEY", ""),
        "default_llm_model" => get(ENV, "DEFAULT_LLM_MODEL", "gpt-4"),
        "llm_temperature" => parse(Float64, get(ENV, "LLM_TEMPERATURE", "0.1")),
        "llm_max_tokens" => parse(Int, get(ENV, "LLM_MAX_TOKENS", "1000")),
        
        # Solana Signing Configuration (optional but checked in QC)
        "solana_keypair_path" => get(ENV, "SOLANA_KEYPAIR_PATH", ""),
        "solana_private_key" => get(ENV, "SOLANA_PRIVATE_KEY", ""),
        
        # Notification Configuration
        "discord_webhook_url" => get(ENV, "DISCORD_WEBHOOK_URL", ""),
        "slack_webhook_url" => get(ENV, "SLACK_WEBHOOK_URL", ""),
        
        # Demo Configuration
        "demo_mode" => get(ENV, "DEMO_MODE", "true") == "true",
        "demo_user_count" => parse(Int, get(ENV, "DEMO_USER_COUNT", "5")),
        "simulate_price_shocks" => get(ENV, "SIMULATE_PRICE_SHOCKS", "true") == "true"
    )
    
    @info "Configuration loaded" demo_mode=config["demo_mode"]
    return config
end

end # module Config
