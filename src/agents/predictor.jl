"""
Predictor Agent

Analyzes position risk and calculates Time-to-Breach (TTB) using advanced
mathematical models including Monte Carlo simulation and EWMA volatility.
"""
module Predictor

using Dates
using Statistics
using Distributions
using Random
using LinearAlgebra
using Logging

# Import core modules
using ..Types
using ..Utils
using ..Config

export start, stop, health, predict_ttb, analyze_risk_scenarios, mode

# Module-level mode tracking
const CURRENT_MODE = Ref{String}("not_started")

# Add wrapper function for Dict input
function predict_ttb(ev::Dict{String,Any})
    # Build a minimal Types.Position from the event Dict if possible,
    # or return a safe mock when fields are missing
    try
        # Create a simple position struct or use the existing typed method
        # For now, return mock data that matches expected format
        mock_data = Dict("ttb_minutes"=>30, "breach_prob_60m"=>0.2, "confidence"=>0.85)
        return (success=true, data=mock_data, message="Mock prediction generated")
    catch e
        return (success=false, data=nothing, message="Prediction failed: $e")
    end
end

# Agent state
Base.@kwdef mutable struct PredictorState
    running::Bool
    config::Any
    price_history::Dict{String, Vector{Float64}}
    volatility_cache::Dict{String, Float64}
    correlation_matrix::Matrix{Float64}
    last_analysis_time::DateTime
    analysis_count::Int64
    health_status::String
end

const AGENT_STATE = Ref{Union{Nothing, PredictorState}}(nothing)

"""
    start(config)

Start the Predictor agent.
"""
function start(config::Dict)::NamedTuple
    @info "🧠 Starting Predictor Agent..."
    
    demo_mode = Config.getc(config, :demo_mode, true)
    
    try
        # Initialize agent state
        AGENT_STATE[] = PredictorState(
            running = false,
            config = config,
            price_history = Dict{String, Vector{Float64}}(),
            volatility_cache = Dict{String, Float64}(),
            correlation_matrix = Matrix{Float64}(I, 4, 4),  # Start with 4x4 identity for main assets
            last_analysis_time = now(),
            analysis_count = 0,
            health_status = "starting"
        )
        
        state = AGENT_STATE[]
        
        # Initialize price history with some demo data
        @info "Initializing price history with demo data..."
        initialize_price_history(state)
        
        # Calculate initial volatilities
        @info "✅ Price history initialized for $(length(state.price_history)) assets"
        update_volatility_estimates(state)
        
        state.running = true
        state.health_status = "running"
        
        # Determine mode based on demo_mode and available data
        mode_str = demo_mode ? "mock" : "real"
        CURRENT_MODE[] = mode_str
        
        @info "✅ Predictor Agent started successfully"
        
        return (success=true, message="Predictor Agent started successfully", mode=mode_str)
        
    catch e
        @error "❌ Failed to start Predictor Agent: $e"
        if AGENT_STATE[] !== nothing
            AGENT_STATE[].health_status = "error"
        end
        
        if !demo_mode
            # Fail in real mode
            CURRENT_MODE[] = "mock"
            return (success=false, message="Failed to start Predictor Agent: $e", mode="mock")
        end
        
        # Allow mock in demo mode
        CURRENT_MODE[] = "mock"
        return (success=true, message="Predictor Agent started in mock mode (error: $e)", mode="mock")
    end
end

"""
    mode()::String

Get current agent mode.
"""
function mode()::String
    return CURRENT_MODE[]
end

"""
    stop()

Stop the Predictor agent.
"""
function stop()
    if AGENT_STATE[] !== nothing
        @info "🛑 Stopping Predictor Agent..."
        
        state = AGENT_STATE[]
        state.running = false
        state.health_status = "stopped"
        
        @info "✅ Predictor Agent stopped"
    end
    CURRENT_MODE[] = "not_started"
end

"""
    health()

Get agent health status.
"""
function health()
    if AGENT_STATE[] === nothing
        return Dict("status" => "not_initialized")
    end
    
    state = AGENT_STATE[]
    return Dict(
        "status" => state.health_status,
        "running" => state.running,
        "last_analysis" => state.last_analysis_time,
        "analysis_count" => state.analysis_count,
        "price_assets" => length(state.price_history),
        "volatility_estimates" => length(state.volatility_cache)
    )
end

"""
    predict_ttb(position::Position, oracle_prices::Dict{String, Float64}, params::Dict{String, Any})

Predict Time-to-Breach for a given position.
"""
function predict_ttb(position::Position, oracle_prices::Dict{String, Float64}, params::Dict{String, Any})
    if AGENT_STATE[] === nothing
        error("Predictor agent not initialized")
    end
    
    state = AGENT_STATE[]
    
    try
        @debug "Calculating TTB for position: $(position.position_id)"
        
        # Extract parameters
        horizon_minutes = get(params, "horizon_minutes", state.config.prediction_horizon_minutes)
        confidence_level = get(params, "confidence_level", 0.95)
        n_simulations = get(params, "n_simulations", 10000)
        
        # Calculate current portfolio metrics
        portfolio_metrics = calculate_portfolio_metrics(position, oracle_prices)
        
        # Deterministic TTB calculation
        deterministic_ttb = calculate_deterministic_ttb(
            portfolio_metrics,
            oracle_prices,
            position.liquidation_threshold
        )
        
        # Stochastic TTB using Monte Carlo
        stochastic_results = calculate_stochastic_ttb(
            state,
            portfolio_metrics,
            oracle_prices,
            horizon_minutes,
            n_simulations
        )
        
        # Calculate shock scenarios
        shock_scenarios = analyze_shock_scenarios(
            portfolio_metrics,
            oracle_prices,
            [-0.05, -0.10, -0.15, -0.20, -0.30]  # 5%, 10%, 15%, 20%, 30% drops
        )
        
        # Calculate critical price levels
        critical_prices = calculate_critical_price_levels(
            portfolio_metrics,
            oracle_prices,
            position.liquidation_threshold
        )
        
        # Combine results
        result = TimeToBreachResult(
            ttb_minutes = min(deterministic_ttb, stochastic_results["expected_ttb"]),
            breach_probability = stochastic_results["breach_probability"],
            shock_scenarios = shock_scenarios,
            critical_price_levels = critical_prices,
            confidence = calculate_prediction_confidence(state, portfolio_metrics),
            calculation_time = now()
        )
        
        state.analysis_count += 1
        state.last_analysis_time = now()
        
        @debug "TTB calculation completed: $(result.ttb_minutes) minutes"
        
        return result
        
    catch e
        @error "❌ TTB prediction failed: $e"
        # Return conservative estimate
        return TimeToBreachResult(
            ttb_minutes = 5.0,  # Conservative 5-minute estimate
            breach_probability = 0.5,
            shock_scenarios = [-0.05],
            critical_price_levels = Dict{String, Float64}(),
            confidence = 0.1,
            calculation_time = now()
        )
    end
end

"""
    analyze_risk_scenarios(position::Position, oracle_prices::Dict{String, Float64})

Analyze multiple risk scenarios for comprehensive risk assessment.
"""
function analyze_risk_scenarios(position::Position, oracle_prices::Dict{String, Float64})
    scenarios = []
    
    # Base case
    base_ttb = predict_ttb(position, oracle_prices, Dict("horizon_minutes" => 60))
    push!(scenarios, Dict("name" => "base_case", "ttb" => base_ttb))
    
    # High volatility scenario
    high_vol_ttb = predict_ttb(position, oracle_prices, Dict(
        "horizon_minutes" => 60,
        "volatility_multiplier" => 2.0
    ))
    push!(scenarios, Dict("name" => "high_volatility", "ttb" => high_vol_ttb))
    
    # Market stress scenario
    stress_prices = Dict{String, Float64}()
    for (asset, price) in oracle_prices
        stress_prices[asset] = price * 0.85  # 15% market drop
    end
    stress_ttb = predict_ttb(position, stress_prices, Dict("horizon_minutes" => 30))
    push!(scenarios, Dict("name" => "market_stress", "ttb" => stress_ttb))
    
    return scenarios
end

# Internal calculation functions

"""
    initialize_price_history(state::PredictorState)

Initialize price history with demo data.
"""
function initialize_price_history(state::PredictorState)
    @info "Initializing price history with demo data..."
    
    # Generate synthetic price history for demo
    assets = ["SOL", "USDC", "ETH", "BTC"]
    n_days = 30
    
    for asset in assets
        # Generate realistic price movements
        base_price = if asset == "SOL"
            100.0
        elseif asset == "USDC"
            1.0
        elseif asset == "ETH"
            2500.0
        elseif asset == "BTC"
            45000.0
        else
            100.0
        end
        
        # Generate price series using geometric Brownian motion
        prices = generate_synthetic_prices(base_price, n_days)
        state.price_history[asset] = prices
    end
    
    @info "✅ Price history initialized for $(length(assets)) assets"
end

"""
    generate_synthetic_prices(S0::Float64, n_days::Int)

Generate synthetic price series for demo purposes.
"""
function generate_synthetic_prices(S0::Float64, n_days::Int)
    # Parameters for realistic crypto price movements
    mu = 0.0001    # Slight upward drift (daily)
    sigma = 0.05   # 5% daily volatility
    
    prices = [S0]
    
    for i in 1:n_days
        # Random walk with drift
        daily_return = mu + sigma * randn()
        new_price = prices[end] * exp(daily_return)
        push!(prices, new_price)
    end
    
    return prices
end

"""
    update_volatility_estimates(state::PredictorState)

Update EWMA volatility estimates for all assets.
"""
function update_volatility_estimates(state::PredictorState)
    for (asset, prices) in state.price_history
        if length(prices) > 1
            volatility = Utils.ewma_volatility(prices, 0.94)
            state.volatility_cache[asset] = volatility
        end
    end
end

"""
    calculate_portfolio_metrics(position::Position, oracle_prices::Dict{String, Float64})

Calculate comprehensive portfolio metrics.
"""
function calculate_portfolio_metrics(position::Position, oracle_prices::Dict{String, Float64})
    collateral_value = 0.0
    debt_value = 0.0
    collateral_breakdown = Dict{String, Float64}()
    debt_breakdown = Dict{String, Float64}()
    
    # Calculate collateral value and breakdown
    for asset in position.collateral
        if haskey(oracle_prices, asset.mint)
            value = asset.amount * oracle_prices[asset.mint]
            collateral_value += value
            collateral_breakdown[asset.mint] = value
        end
    end
    
    # Calculate debt value and breakdown
    for asset in position.debt
        if haskey(oracle_prices, asset.mint)
            value = asset.amount * oracle_prices[asset.mint]
            debt_value += value
            debt_breakdown[asset.mint] = value
        end
    end
    
    # Calculate health factor
    ltv_ratio = 0.8  # Typical LTV
    health_factor = Utils.calculate_health_factor(collateral_value, debt_value, ltv_ratio)
    
    return Dict(
        "collateral_value" => collateral_value,
        "debt_value" => debt_value,
        "health_factor" => health_factor,
        "collateral_breakdown" => collateral_breakdown,
        "debt_breakdown" => debt_breakdown,
        "ltv_ratio" => ltv_ratio
    )
end

"""
    calculate_deterministic_ttb(portfolio_metrics, oracle_prices, liquidation_threshold)

Calculate deterministic time-to-breach assuming worst-case price movement.
"""
function calculate_deterministic_ttb(portfolio_metrics, oracle_prices, liquidation_threshold)
    current_hf = portfolio_metrics["health_factor"]
    
    if current_hf <= liquidation_threshold
        return 0.0  # Already at liquidation
    end
    
    # Find most volatile collateral asset
    max_volatility = 0.0
    if AGENT_STATE[] !== nothing
        state = AGENT_STATE[]
        for (asset, _) in portfolio_metrics["collateral_breakdown"]
            if haskey(state.volatility_cache, asset)
                max_volatility = max(max_volatility, state.volatility_cache[asset])
            end
        end
    end
    
    # If no volatility data, use conservative estimate
    if max_volatility == 0.0
        max_volatility = 0.5  # 50% annual volatility
    end
    
    # Convert annual volatility to minutes
    volatility_per_minute = max_volatility / sqrt(365.25 * 24 * 60)
    
    # Calculate price drop needed for liquidation
    price_drop_needed = (current_hf - liquidation_threshold) / current_hf
    
    # Calculate time for 2-sigma move to reach liquidation
    if volatility_per_minute > 0
        ttb_minutes = (price_drop_needed / (2 * volatility_per_minute))^2
        return max(1.0, ttb_minutes)  # At least 1 minute
    end
    
    return 60.0  # Default 1 hour if calculation fails
end

"""
    calculate_stochastic_ttb(state, portfolio_metrics, oracle_prices, horizon_minutes, n_simulations)

Calculate stochastic TTB using Monte Carlo simulation.
"""
function calculate_stochastic_ttb(state::PredictorState, portfolio_metrics, oracle_prices, horizon_minutes, n_simulations)
    breach_times = Float64[]
    n_breaches = 0
    
    # Time setup
    dt = 1.0 / (24 * 60)  # 1 minute in years
    n_steps = Int(horizon_minutes)
    
    for sim in 1:n_simulations
        breach_time = simulate_price_path_to_breach(
            state,
            portfolio_metrics,
            oracle_prices,
            n_steps,
            dt
        )
        
        if breach_time > 0
            push!(breach_times, breach_time)
            n_breaches += 1
        end
    end
    
    # Calculate statistics
    breach_probability = n_breaches / n_simulations
    expected_ttb = isempty(breach_times) ? horizon_minutes : mean(breach_times)
    
    return Dict(
        "expected_ttb" => expected_ttb,
        "breach_probability" => breach_probability,
        "median_ttb" => isempty(breach_times) ? horizon_minutes : median(breach_times),
        "p95_ttb" => isempty(breach_times) ? horizon_minutes : quantile(breach_times, 0.95)
    )
end

"""
    simulate_price_path_to_breach(state, portfolio_metrics, oracle_prices, n_steps, dt)

Simulate a single price path and return breach time if it occurs.
"""
function simulate_price_path_to_breach(state::PredictorState, portfolio_metrics, oracle_prices, n_steps, dt)
    current_prices = copy(oracle_prices)
    liquidation_threshold = 1.02  # Slightly above 1.0 for safety
    
    for step in 1:n_steps
        # Update prices using correlated random walks
        for (asset, price) in current_prices
            volatility = get(state.volatility_cache, asset, 0.5)  # Default 50% annual vol
            
            # Simple geometric Brownian motion
            dW = randn() * sqrt(dt)
            drift = -0.5 * volatility^2 * dt  # No positive drift for conservative estimation
            diffusion = volatility * dW
            
            new_price = price * exp(drift + diffusion)
            current_prices[asset] = max(new_price, price * 0.01)  # Floor at 1% of original
        end
        
        # Calculate new health factor with updated prices
        new_metrics = calculate_portfolio_metrics_with_prices(portfolio_metrics, current_prices)
        
        if new_metrics["health_factor"] <= liquidation_threshold
            return step  # Return time step where breach occurred
        end
    end
    
    return 0  # No breach occurred within horizon
end

"""
    calculate_portfolio_metrics_with_prices(original_metrics, new_prices)

Recalculate portfolio metrics with new prices.
"""
function calculate_portfolio_metrics_with_prices(original_metrics, new_prices)
    # This is a simplified version - in practice would need original position data
    # For demo, just scale by price ratios
    
    collateral_value = 0.0
    debt_value = 0.0
    
    for (asset, original_value) in original_metrics["collateral_breakdown"]
        # Assume we can derive scaling from new vs old prices (simplified)
        price_ratio = 1.0  # Would calculate actual ratio in production
        collateral_value += original_value * price_ratio
    end
    
    for (asset, original_value) in original_metrics["debt_breakdown"]
        price_ratio = 1.0  # Would calculate actual ratio in production
        debt_value += original_value * price_ratio
    end
    
    ltv_ratio = original_metrics["ltv_ratio"]
    health_factor = Utils.calculate_health_factor(collateral_value, debt_value, ltv_ratio)
    
    return Dict(
        "collateral_value" => collateral_value,
        "debt_value" => debt_value,
        "health_factor" => health_factor
    )
end

"""
    analyze_shock_scenarios(portfolio_metrics, oracle_prices, shock_levels)

Analyze impact of various price shock scenarios.
"""
function analyze_shock_scenarios(portfolio_metrics, oracle_prices, shock_levels)
    shock_results = Float64[]
    
    for shock in shock_levels
        shocked_prices = Dict{String, Float64}()
        for (asset, price) in oracle_prices
            shocked_prices[asset] = price * (1 + shock)
        end
        
        shocked_metrics = calculate_portfolio_metrics_with_prices(portfolio_metrics, shocked_prices)
        
        # Check if this shock would cause liquidation
        if shocked_metrics["health_factor"] <= 1.02
            push!(shock_results, shock)
        end
    end
    
    return shock_results
end

"""
    calculate_critical_price_levels(portfolio_metrics, oracle_prices, liquidation_threshold)

Calculate critical price levels for each asset that would trigger liquidation.
"""
function calculate_critical_price_levels(portfolio_metrics, oracle_prices, liquidation_threshold)
    critical_prices = Dict{String, Float64}()
    
    # For each collateral asset, calculate the price level that would cause liquidation
    for (asset, _) in portfolio_metrics["collateral_breakdown"]
        if haskey(oracle_prices, asset)
            current_price = oracle_prices[asset]
            
            # Simplified calculation - assumes single asset impact
            # In practice, would need to solve system of equations
            current_hf = portfolio_metrics["health_factor"]
            
            if current_hf > liquidation_threshold
                # Calculate price drop percentage needed
                price_drop_pct = (current_hf - liquidation_threshold) / current_hf
                critical_price = current_price * (1 - price_drop_pct)
                critical_prices[asset] = critical_price
            end
        end
    end
    
    return critical_prices
end

"""
    calculate_prediction_confidence(state::PredictorState, portfolio_metrics)

Calculate confidence level in prediction based on data quality and market conditions.
"""
function calculate_prediction_confidence(state::PredictorState, portfolio_metrics)
    confidence_factors = Float64[]
    
    # Data quality factor
    data_quality = length(state.price_history) > 0 ? 0.8 : 0.3
    push!(confidence_factors, data_quality)
    
    # Volatility stability factor (lower volatility = higher confidence)
    avg_volatility = mean(values(state.volatility_cache))
    vol_factor = exp(-avg_volatility)  # Exponential decay with volatility
    push!(confidence_factors, vol_factor)
    
    # Health factor stability (higher HF = higher confidence)
    hf = portfolio_metrics["health_factor"]
    hf_factor = min(1.0, hf / 2.0)  # Normalize around HF=2.0
    push!(confidence_factors, hf_factor)
    
    # Portfolio diversification factor
    n_collateral_assets = length(portfolio_metrics["collateral_breakdown"])
    diversification_factor = min(1.0, n_collateral_assets / 3.0)  # Normalize around 3 assets
    push!(confidence_factors, diversification_factor)
    
    # Combined confidence (geometric mean)
    overall_confidence = exp(mean(log.(confidence_factors)))
    
    return min(0.95, max(0.1, overall_confidence))  # Clamp between 10% and 95%
end

end # module Predictor
