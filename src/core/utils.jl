"""
Utility functions for X-LiGo system.

Common helper functions for mathematical calculations, data processing,
cryptographic operations, and system utilities.
"""
module Utils

using Dates
using Statistics
using LinearAlgebra
using Distributions
using Random
using UUIDs
using JSON
using Logging

export calculate_health_factor, estimate_liquidation_price
export geometric_brownian_motion, ewma_volatility
export format_currency, format_percentage, format_duration
export sign_data, verify_signature, encrypt_data, decrypt_data
export rate_limit, exponential_backoff
export generate_correlation_matrix, calculate_var

"""
    calculate_health_factor(collateral_value::Float64, debt_value::Float64, ltv_ratio::Float64)

Calculate health factor for a lending position.
"""
function calculate_health_factor(collateral_value::Float64, debt_value::Float64, ltv_ratio::Float64)
    if debt_value <= 0.0
        return Inf  # No debt means infinite health factor
    end
    
    if collateral_value <= 0.0
        return 0.0  # No collateral means zero health factor
    end
    
    # Health Factor = (Collateral * LTV) / Debt
    return (collateral_value * ltv_ratio) / debt_value
end

"""
    estimate_liquidation_price(current_price::Float64, health_factor::Float64, target_hf::Float64 = 1.0)

Estimate the asset price at which liquidation occurs.
"""
function estimate_liquidation_price(current_price::Float64, health_factor::Float64, target_hf::Float64 = 1.0)
    if health_factor <= 0.0
        return 0.0
    end
    
    # Price multiplier to reach target health factor
    price_multiplier = target_hf / health_factor
    
    return current_price * price_multiplier
end

"""
    geometric_brownian_motion(S0::Float64, mu::Float64, sigma::Float64, T::Float64, n_steps::Int, n_paths::Int)

Generate geometric Brownian motion paths for Monte Carlo simulation.

# Arguments
- `S0`: Initial price
- `mu`: Drift rate (annualized)
- `sigma`: Volatility (annualized)
- `T`: Time horizon in years
- `n_steps`: Number of time steps
- `n_paths`: Number of simulation paths

# Returns
- Matrix of size (n_steps+1, n_paths) containing price paths
"""
function geometric_brownian_motion(S0::Float64, mu::Float64, sigma::Float64, T::Float64, n_steps::Int, n_paths::Int)
    dt = T / n_steps
    
    # Pre-allocate price matrix
    prices = zeros(n_steps + 1, n_paths)
    prices[1, :] .= S0
    
    # Generate random increments
    Z = randn(n_steps, n_paths)
    
    # Calculate price paths
    for i in 1:n_steps
        for j in 1:n_paths
            drift = (mu - 0.5 * sigma^2) * dt
            diffusion = sigma * sqrt(dt) * Z[i, j]
            prices[i + 1, j] = prices[i, j] * exp(drift + diffusion)
        end
    end
    
    return prices
end

"""
    ewma_volatility(prices::Vector{Float64}, lambda::Float64 = 0.94)

Calculate Exponentially Weighted Moving Average volatility.

# Arguments
- `prices`: Vector of historical prices
- `lambda`: Decay factor (typically 0.94)

# Returns
- Current volatility estimate (annualized)
"""
function ewma_volatility(prices::Vector{Float64}, lambda::Float64 = 0.94)
    if length(prices) < 2
        return 0.0
    end
    
    # Calculate log returns
    returns = diff(log.(prices))
    
    if isempty(returns)
        return 0.0
    end
    
    # Initialize with first return squared
    ewma_var = returns[1]^2
    
    # Calculate EWMA variance
    for i in 2:length(returns)
        ewma_var = lambda * ewma_var + (1 - lambda) * returns[i]^2
    end
    
    # Convert to annualized volatility (assuming daily data)
    return sqrt(ewma_var * 365.25)
end

"""
    format_currency(amount::Float64, currency::String = "USD", decimals::Int = 2)

Format currency amount for display.
"""
function format_currency(amount::Float64, currency::String = "USD", decimals::Int = 2)
    if abs(amount) >= 1_000_000
        return "$(round(amount / 1_000_000, digits=1))M $currency"
    elseif abs(amount) >= 1_000
        return "$(round(amount / 1_000, digits=1))K $currency"
    else
        return "$(round(amount, digits=decimals)) $currency"
    end
end

"""
    format_percentage(value::Float64, decimals::Int = 2)

Format percentage for display.
"""
function format_percentage(value::Float64, decimals::Int = 2)
    return "$(round(value * 100, digits=decimals))%"
end

"""
    format_duration(seconds::Float64)

Format duration in human-readable format.
"""
function format_duration(seconds::Float64)
    if seconds < 60
        return "$(round(Int, seconds))s"
    elseif seconds < 3600
        minutes = round(Int, seconds / 60)
        return "$(minutes)m"
    elseif seconds < 86400
        hours = round(Int, seconds / 3600)
        minutes = round(Int, (seconds % 3600) / 60)
        return "$(hours)h $(minutes)m"
    else
        days = round(Int, seconds / 86400)
        hours = round(Int, (seconds % 86400) / 3600)
        return "$(days)d $(hours)h"
    end
end

"""
    sign_data(data::Dict, private_key::String)

Create a cryptographic signature for data integrity.
"""
function sign_data(data::Dict, private_key::String)
    # Serialize data to JSON
    json_data = JSON.json(data, 2)  # Pretty print for consistency
    
    # Create a simple hash-based signature (in production, use proper cryptographic signing)
    data_hash = string(hash(json_data))
    signature_hash = string(hash(string(data_hash, private_key)))
    
    return Dict(
        "data" => data,
        "signature" => signature_hash,
        "timestamp" => now(),
        "algorithm" => "simple_hash"  # In production, use "ECDSA" or similar
    )
end

"""
    verify_signature(signed_data::Dict, public_key::String)

Verify a cryptographic signature.
"""
function verify_signature(signed_data::Dict, public_key::String)
    try
        data = signed_data["data"]
        signature = signed_data["signature"]
        
        # Recreate signature
        json_data = JSON.json(data, 2)
        data_hash = string(hash(json_data))
        expected_signature = string(hash(string(data_hash, public_key)))
        
        return signature == expected_signature
    catch e
        @warn "Signature verification failed: $e"
        return false
    end
end

"""
    encrypt_data(data::String, key::String)

Simple encryption for sensitive data (in production, use proper encryption).
"""
function encrypt_data(data::String, key::String)
    # Simple XOR-based encryption (NOT for production use)
    key_bytes = Vector{UInt8}(key)
    data_bytes = Vector{UInt8}(data)
    
    encrypted = UInt8[]
    for (i, byte) in enumerate(data_bytes)
        key_idx = ((i - 1) % length(key_bytes)) + 1
        encrypted_byte = byte ⊻ key_bytes[key_idx]
        push!(encrypted, encrypted_byte)
    end
    
    return base64encode(encrypted)
end

"""
    decrypt_data(encrypted_data::String, key::String)

Decrypt data encrypted with encrypt_data.
"""
function decrypt_data(encrypted_data::String, key::String)
    try
        encrypted_bytes = base64decode(encrypted_data)
        key_bytes = Vector{UInt8}(key)
        
        decrypted = UInt8[]
        for (i, byte) in enumerate(encrypted_bytes)
            key_idx = ((i - 1) % length(key_bytes)) + 1
            decrypted_byte = byte ⊻ key_bytes[key_idx]
            push!(decrypted, decrypted_byte)
        end
        
        return String(decrypted)
    catch e
        @error "Decryption failed: $e"
        return ""
    end
end

# Rate limiting utilities
const RATE_LIMIT_CACHE = Dict{String, Vector{DateTime}}()

"""
    rate_limit(key::String, max_requests::Int, window_seconds::Int)

Simple rate limiting implementation.
"""
function rate_limit(key::String, max_requests::Int, window_seconds::Int)
    current_time = now()
    cutoff_time = current_time - Dates.Second(window_seconds)
    
    # Initialize or get existing requests
    if !haskey(RATE_LIMIT_CACHE, key)
        RATE_LIMIT_CACHE[key] = DateTime[]
    end
    
    requests = RATE_LIMIT_CACHE[key]
    
    # Remove old requests
    filter!(t -> t > cutoff_time, requests)
    
    # Check if limit exceeded
    if length(requests) >= max_requests
        return false
    end
    
    # Add current request
    push!(requests, current_time)
    RATE_LIMIT_CACHE[key] = requests
    
    return true
end

"""
    exponential_backoff(attempt::Int, base_delay::Float64 = 1.0, max_delay::Float64 = 60.0)

Calculate exponential backoff delay.
"""
function exponential_backoff(attempt::Int, base_delay::Float64 = 1.0, max_delay::Float64 = 60.0)
    delay = base_delay * (2.0 ^ (attempt - 1))
    return min(delay, max_delay)
end

"""
    generate_correlation_matrix(assets::Vector{String}, prices::Dict{String, Vector{Float64}})

Generate correlation matrix for multiple assets.
"""
function generate_correlation_matrix(assets::Vector{String}, prices::Dict{String, Vector{Float64}})
    n_assets = length(assets)
    correlation_matrix = Matrix{Float64}(I, n_assets, n_assets)
    
    # Calculate returns for each asset
    returns = Dict{String, Vector{Float64}}()
    for asset in assets
        if haskey(prices, asset) && length(prices[asset]) > 1
            asset_prices = prices[asset]
            returns[asset] = diff(log.(asset_prices))
        else
            returns[asset] = Float64[]
        end
    end
    
    # Calculate correlations
    for i in 1:n_assets
        for j in i+1:n_assets
            asset1, asset2 = assets[i], assets[j]
            
            if haskey(returns, asset1) && haskey(returns, asset2) && 
               length(returns[asset1]) > 0 && length(returns[asset2]) > 0
                
                # Ensure same length
                min_length = min(length(returns[asset1]), length(returns[asset2]))
                r1 = returns[asset1][1:min_length]
                r2 = returns[asset2][1:min_length]
                
                if length(r1) > 1
                    corr_val = cor(r1, r2)
                    correlation_matrix[i, j] = corr_val
                    correlation_matrix[j, i] = corr_val
                end
            end
        end
    end
    
    return correlation_matrix
end

"""
    calculate_var(returns::Vector{Float64}, confidence_level::Float64 = 0.05)

Calculate Value at Risk (VaR) for a return series.
"""
function calculate_var(returns::Vector{Float64}, confidence_level::Float64 = 0.05)
    if isempty(returns)
        return 0.0
    end
    
    sorted_returns = sort(returns)
    var_index = max(1, floor(Int, length(sorted_returns) * confidence_level))
    
    return -sorted_returns[var_index]  # Negative because VaR is typically reported as positive loss
end

"""
    robust_mean(values::Vector{Float64}, trim_ratio::Float64 = 0.1)

Calculate robust mean by trimming outliers.
"""
function robust_mean(values::Vector{Float64}, trim_ratio::Float64 = 0.1)
    if isempty(values)
        return 0.0
    end
    
    n = length(values)
    trim_count = round(Int, n * trim_ratio / 2)
    
    if trim_count >= n ÷ 2
        return median(values)
    end
    
    sorted_values = sort(values)
    trimmed_values = sorted_values[(trim_count + 1):(n - trim_count)]
    
    return mean(trimmed_values)
end

"""
    moving_average(values::Vector{Float64}, window::Int)

Calculate simple moving average.
"""
function moving_average(values::Vector{Float64}, window::Int)
    if length(values) < window
        return [mean(values[1:i]) for i in 1:length(values)]
    end
    
    ma = Float64[]
    for i in window:length(values)
        push!(ma, mean(values[(i - window + 1):i]))
    end
    
    return ma
end

"""
    bollinger_bands(prices::Vector{Float64}, window::Int = 20, std_dev::Float64 = 2.0)

Calculate Bollinger Bands for price analysis.
"""
function bollinger_bands(prices::Vector{Float64}, window::Int = 20, std_dev::Float64 = 2.0)
    if length(prices) < window
        return (prices, prices, prices)  # Return original prices if insufficient data
    end
    
    ma = moving_average(prices, window)
    
    # Calculate rolling standard deviation
    rolling_std = Float64[]
    for i in window:length(prices)
        window_prices = prices[(i - window + 1):i]
        push!(rolling_std, std(window_prices))
    end
    
    # Calculate bands
    upper_band = ma .+ (std_dev .* rolling_std)
    lower_band = ma .- (std_dev .* rolling_std)
    
    return (upper_band, ma, lower_band)
end

end # module Utils
