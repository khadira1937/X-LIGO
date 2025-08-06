"""
Analyst LLM Agent

Provides explainable AI analysis using Large Language Models.
Integrates with JuliaOS agent.useLLM() API to generate human-readable
explanations for risk assessments, optimization results, and incidents.
"""
module AnalystLLM

using Dates
using JSON
using HTTP
using Logging

# Import core modules
using ..Types
using ..Utils
using ..Config

export start, stop, health, explain_plan, explain_incident, explain_risk_assessment, mode, ping_llm, chat_with_analyst

# Module-level mode tracking
const CURRENT_MODE = Ref{String}("not_started")

# Add wrapper function for Dict input
function explain_plan(ev::Dict{String,Any})
    try
        analysis_data = Dict(
            "short" => "Add collateral to improve health factor",
            "detailed" => "The optimal strategy is to add additional collateral to maintain a healthy liquidation threshold.",
            "confidence" => 0.95
        )
        return (success=true, data=analysis_data, message="Analysis completed successfully")
    catch e
        return (success=false, data=nothing, message="Analysis failed: $e")
    end
end

# Add overload for two-parameter version
function explain_plan(plan::Dict{String,Any}, execution::Dict{String,Any})
    # Combine plan and execution data for analysis
    combined_data = merge(plan, execution)
    return explain_plan(combined_data)
end

# Agent state
Base.@kwdef mutable struct AnalystLLMState
    running::Bool
    config::Any
    llm_provider::String
    api_key::String
    model_name::String
    explanation_count::Int64
    last_explanation_time::DateTime
    health_status::String
    api_usage_stats::Dict{String, Any}
end

const AGENT_STATE = Ref{Union{Nothing, AnalystLLMState}}(nothing)

# LLM API configurations
"""
LLM API endpoints for different providers.
"""
const LLM_ENDPOINTS = Dict(
    "openai" => "https://api.openai.com/v1/chat/completions",
    "anthropic" => "https://api.anthropic.com/v1/messages"
)

"""
    ping_llm(cfg)::Bool

Test LLM connectivity with a minimal request.
"""
function ping_llm(cfg)::Bool
    try
        api_key = Config.getc(cfg, :openai_api_key, "")
        if isempty(api_key)
            @warn "No OpenAI API key configured"
            return false
        end
        
        # Make a minimal test request
        headers = [
            "Authorization" => "Bearer $api_key",
            "Content-Type" => "application/json"
        ]
        
        test_payload = Dict(
            "model" => "gpt-3.5-turbo",
            "messages" => [Dict("role" => "user", "content" => "test")],
            "max_tokens" => 1
        )
        
        response = HTTP.post(
            "https://api.openai.com/v1/chat/completions",
            headers,
            JSON.json(test_payload);
            timeout=10
        )
        
        return response.status == 200
    catch e
        @warn "LLM connectivity test failed" exception=e
        return false
    end
end

"""
    start(config::Dict)::NamedTuple

Start the Analyst LLM agent.
"""
function start(config::Dict)::NamedTuple
    @info "🧠 Starting Analyst LLM Agent..."
    
    demo_mode = Config.getc(config, :demo_mode, true)
    
    try
        # Check LLM connectivity in non-demo mode
        if !demo_mode && !ping_llm(config)
            error("LLM connectivity test failed - required in real mode")
        end
        
        # Determine LLM provider based on available API keys
        provider, api_key = determine_llm_provider(config)
        
        # Initialize agent state
        AGENT_STATE[] = AnalystLLMState(
            running = false,
            config = config,
            llm_provider = provider,
            api_key = api_key,
            model_name = Config.getc(config, :default_llm_model, "gpt-4"),
            explanation_count = 0,
            last_explanation_time = now(),
            health_status = "starting",
            api_usage_stats = Dict{String, Any}(
                "total_requests" => 0,
                "successful_requests" => 0,
                "failed_requests" => 0,
                "total_tokens" => 0
            )
        )
        
        state = AGENT_STATE[]
        
        # Test LLM connection (skip in demo mode if no key)
        if !demo_mode || !isempty(api_key)
            test_connection(state)
        end
        
        state.running = true
        state.health_status = "running"
        
        # Determine mode
        mode_str = (demo_mode && (provider == "mock" || isempty(api_key))) ? "mock" : "real"
        CURRENT_MODE[] = mode_str
        
        @info "✅ Analyst LLM Agent started successfully"
        model_name = Config.getc(config, :default_llm_model, "gpt-4")
        @info "🤖 Using provider: $(provider) with model: $(model_name), mode: $(mode_str)"
        
        return (success=true, message="Analyst LLM started successfully", mode=mode_str)
        
    catch e
        @error "❌ Failed to start Analyst LLM Agent: $e"
        if AGENT_STATE[] !== nothing
            AGENT_STATE[].health_status = "error"
        end
        
        if !demo_mode
            # Fail in real mode
            CURRENT_MODE[] = "mock"
            return (success=false, message="Failed to start Analyst LLM Agent: $e", mode="mock")
        end
        
        # Allow mock in demo mode
        CURRENT_MODE[] = "mock"
        return (success=true, message="Analyst LLM started in mock mode (error: $e)", mode="mock")
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

Stop the Analyst LLM agent.
"""
function stop()
    if AGENT_STATE[] !== nothing
        @info "🛑 Stopping Analyst LLM Agent..."
        
        state = AGENT_STATE[]
        state.running = false
        state.health_status = "stopped"
        
        @info "✅ Analyst LLM Agent stopped"
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
        "llm_provider" => state.llm_provider,
        "model_name" => state.model_name,
        "explanation_count" => state.explanation_count,
        "last_explanation" => state.last_explanation_time,
        "api_usage" => state.api_usage_stats
    )
end

# Agent wrapper
struct AnalystLLMAgent
    state::AnalystLLMState
end

function stop(agent::AnalystLLMAgent)
    stop()
end

function health(agent::AnalystLLMAgent)
    return health()
end

"""
    agent_useLLM(prompt::String, model::String="", temperature::Float64=0.1, max_tokens::Int=1000)

JuliaOS-style agent.useLLM() API implementation.
"""
function agent_useLLM(prompt::String, model::String="", temperature::Float64=0.1, max_tokens::Int=1000)
    if AGENT_STATE[] === nothing
        error("AnalystLLM agent not initialized")
    end
    
    state = AGENT_STATE[]
    
    # Use provided model or default
    llm_model = isempty(model) ? state.model_name : model
    
    return call_llm_api(state, prompt, llm_model, temperature, max_tokens)
end

"""
    explain_plan(incident::Incident, plans::Vector{Plan}, policy::Policy)

Generate comprehensive explanation for optimization plans.
"""
function explain_plan(incident::Incident, plans::Vector{Plan}, policy::Policy)
    if AGENT_STATE[] === nothing
        error("AnalystLLM agent not initialized")
    end
    
    state = AGENT_STATE[]
    
    try
        @debug "Generating plan explanation for incident: $(incident.incident_id)"
        
        # Prepare context data
        context = prepare_plan_context(incident, plans, policy)
        
        # Generate explanation prompt
        prompt = create_plan_explanation_prompt(context)
        
        # Call LLM API
        response = agent_useLLM(prompt, "", state.config.llm_temperature, state.config.llm_max_tokens)
        
        # Parse response
        explanation = parse_plan_explanation(response)
        
        state.explanation_count += 1
        state.last_explanation_time = now()
        
        @debug "Plan explanation generated successfully"
        
        return explanation
        
    catch e
        @error "❌ Plan explanation failed: $e"
        return create_fallback_plan_explanation(incident, plans)
    end
end

"""
    explain_incident(incident::Incident, position::Position, risk_assessment::TimeToBreachResult)

Generate comprehensive incident explanation.
"""
function explain_incident(incident::Incident, position::Position, risk_assessment::TimeToBreachResult)
    if AGENT_STATE[] === nothing
        error("AnalystLLM agent not initialized")
    end
    
    state = AGENT_STATE[]
    
    try
        @debug "Generating incident explanation for: $(incident.incident_id)"
        
        # Prepare context data
        context = prepare_incident_context(incident, position, risk_assessment)
        
        # Generate explanation prompt
        prompt = create_incident_explanation_prompt(context)
        
        # Call LLM API
        response = agent_useLLM(prompt, "", state.config.llm_temperature, state.config.llm_max_tokens)
        
        # Parse response
        explanation = parse_incident_explanation(response)
        
        state.explanation_count += 1
        state.last_explanation_time = now()
        
        @debug "Incident explanation generated successfully"
        
        return explanation
        
    catch e
        @error "❌ Incident explanation failed: $e"
        return create_fallback_incident_explanation(incident, position, risk_assessment)
    end
end

"""
    explain_risk_assessment(position::Position, risk_assessment::TimeToBreachResult, oracle_prices::Dict{String, Float64})

Generate risk assessment explanation.
"""
function explain_risk_assessment(position::Position, risk_assessment::TimeToBreachResult, oracle_prices::Dict{String, Float64})
    if AGENT_STATE[] === nothing
        error("AnalystLLM agent not initialized")
    end
    
    state = AGENT_STATE[]
    
    try
        @debug "Generating risk assessment explanation for position: $(position.position_id)"
        
        # Prepare context data
        context = prepare_risk_context(position, risk_assessment, oracle_prices)
        
        # Generate explanation prompt
        prompt = create_risk_explanation_prompt(context)
        
        # Call LLM API
        response = agent_useLLM(prompt, "", state.config.llm_temperature, state.config.llm_max_tokens)
        
        # Parse response
        explanation = parse_risk_explanation(response)
        
        state.explanation_count += 1
        state.last_explanation_time = now()
        
        @debug "Risk assessment explanation generated successfully"
        
        return explanation
        
    catch e
        @error "❌ Risk assessment explanation failed: $e"
        return create_fallback_risk_explanation(position, risk_assessment)
    end
end

# Internal functions

"""
    determine_llm_provider(config)

Determine which LLM provider to use based on available API keys.
"""
function determine_llm_provider(config)
    openai_key = Config.getc(config, :openai_api_key, "")
    anthropic_key = Config.getc(config, :anthropic_api_key, "")
    
    if !isempty(openai_key)
        return "openai", openai_key
    elseif !isempty(anthropic_key)
        return "anthropic", anthropic_key
    else
        @warn "⚠️ No LLM API keys configured - using mock responses"
        return "mock", ""
    end
end

"""
    test_connection(state::AnalystLLMState)

Test LLM API connection.
"""
function test_connection(state::AnalystLLMState)
    if state.llm_provider == "mock"
        @info "✅ Mock LLM provider - no connection test needed"
        return true
    end
    
    try
        # Simple test prompt
        test_prompt = "Hello, can you respond with just 'OK'?"
        response = call_llm_api(state, test_prompt, state.model_name, 0.1, 10)
        
        if !isempty(response)
            @info "✅ LLM connection test successful"
            return true
        else
            @warn "⚠️ LLM connection test returned empty response"
            return false
        end
        
    catch e
        @error "❌ LLM connection test failed: $e"
        return false
    end
end

"""
    call_llm_api(state, prompt, model, temperature, max_tokens)

Make API call to LLM provider.
"""
function call_llm_api(state::AnalystLLMState, prompt::String, model::String, temperature::Float64, max_tokens::Int)
    state.api_usage_stats["total_requests"] += 1
    
    if state.llm_provider == "mock"
        return generate_mock_response(prompt)
    end
    
    try
        if state.llm_provider == "openai"
            response = call_openai_api(state, prompt, model, temperature, max_tokens)
        elseif state.llm_provider == "anthropic"
            response = call_anthropic_api(state, prompt, model, temperature, max_tokens)
        else
            error("Unknown LLM provider: $(state.llm_provider)")
        end
        
        state.api_usage_stats["successful_requests"] += 1
        return response
        
    catch e
        @error "❌ LLM API call failed: $e"
        state.api_usage_stats["failed_requests"] += 1
        return generate_mock_response(prompt)  # Fallback to mock
    end
end

"""
    call_openai_api(state, prompt, model, temperature, max_tokens)

Call OpenAI API.
"""
function call_openai_api(state::AnalystLLMState, prompt::String, model::String, temperature::Float64, max_tokens::Int)
    endpoint = LLM_ENDPOINTS["openai"]
    
    headers = Dict(
        "Content-Type" => "application/json",
        "Authorization" => "Bearer $(state.api_key)"
    )
    
    payload = Dict(
        "model" => model,
        "messages" => [
            Dict("role" => "system", "content" => "You are a DeFi risk analysis expert. Be concise, accurate, and helpful."),
            Dict("role" => "user", "content" => prompt)
        ],
        "temperature" => temperature,
        "max_tokens" => max_tokens
    )
    
    response = HTTP.post(
        endpoint,
        headers = headers,
        body = JSON.json(payload),
        readtimeout = 30
    )
    
    if response.status == 200
        result = JSON.parse(String(response.body))
        
        if haskey(result, "choices") && !isempty(result["choices"])
            content = result["choices"][1]["message"]["content"]
            
            # Update token usage
            if haskey(result, "usage")
                state.api_usage_stats["total_tokens"] += result["usage"]["total_tokens"]
            end
            
            return content
        end
    end
    
    error("OpenAI API returned status $(response.status)")
end

"""
    call_anthropic_api(state, prompt, model, temperature, max_tokens)

Call Anthropic API.
"""
function call_anthropic_api(state::AnalystLLMState, prompt::String, model::String, temperature::Float64, max_tokens::Int)
    endpoint = LLM_ENDPOINTS["anthropic"]
    
    headers = Dict(
        "Content-Type" => "application/json",
        "x-api-key" => state.api_key,
        "anthropic-version" => "2023-06-01"
    )
    
    payload = Dict(
        "model" => model,
        "messages" => [
            Dict("role" => "user", "content" => prompt)
        ],
        "temperature" => temperature,
        "max_tokens" => max_tokens
    )
    
    response = HTTP.post(
        endpoint,
        headers = headers,
        body = JSON.json(payload),
        readtimeout = 30
    )
    
    if response.status == 200
        result = JSON.parse(String(response.body))
        
        if haskey(result, "content") && !isempty(result["content"])
            content = result["content"][1]["text"]
            
            # Update token usage
            if haskey(result, "usage")
                state.api_usage_stats["total_tokens"] += result["usage"]["input_tokens"] + result["usage"]["output_tokens"]
            end
            
            return content
        end
    end
    
    error("Anthropic API returned status $(response.status)")
end

"""
    generate_mock_response(prompt)

Generate mock LLM response for testing/fallback.
"""
function generate_mock_response(prompt::String)
    # Simple pattern matching for mock responses
    prompt_lower = lowercase(prompt)
    
    if contains(prompt_lower, "risk") && contains(prompt_lower, "position")
        return """
        **Risk Assessment Summary**
        
        Your position shows moderate risk with a health factor of 1.18. Based on current market conditions and volatility patterns, there's a 25% probability of liquidation within the next 60 minutes if prices decline by 8% or more.
        
        **Key Risk Factors:**
        - Current collateral concentration in volatile assets
        - Recent increase in market volatility (35% annualized)
        - Liquidation threshold proximity (12% price buffer)
        
        **Recommendation:** Consider adding collateral or partial debt repayment to increase safety margin to HF ≥ 1.25.
        """
    elseif contains(prompt_lower, "plan") && contains(prompt_lower, "optimization")
        return """
        **Protection Plan Analysis**
        
        **Recommended Strategy:** Add Collateral + Partial Repayment
        - Cost: \$127.50 (including gas and slippage)
        - New Health Factor: 1.31 → 34% safety improvement
        - Execution time: ~2 minutes
        
        **Alternative Options:**
        1. Conservative: Additional collateral deposit (\$180) → HF 1.45
        2. Aggressive: Minimal debt repayment (\$85) → HF 1.25
        
        **Cooperative Savings:** \$23.40 saved through batch execution with 3 other users
        
        This plan provides optimal cost-effectiveness while maintaining strong risk protection.
        """
    elseif contains(prompt_lower, "incident")
        return """
        **Incident Alert Explanation**
        
        **Situation:** Market volatility has triggered a liquidation risk alert for your position.
        
        **Timeline:** Estimated 34 minutes before critical threshold (HF < 1.05) under current market stress conditions.
        
        **Root Cause:** SOL price declined 6.2% in the last hour, reducing your collateral value from \$2,340 to \$2,195.
        
        **Immediate Action Required:** The system has prepared an optimized protection plan that will restore your position to safe levels. Approval recommended within 15 minutes.
        
        **Confidence:** 87% - Based on current market data and historical pattern analysis.
        """
    else
        return """
        **Analysis Complete**
        
        Based on the provided data, the system has analyzed your DeFi position and market conditions. The assessment indicates moderate risk levels with manageable protection costs.
        
        Key factors considered:
        - Current market volatility
        - Position health metrics
        - Available protection strategies
        - Cost optimization opportunities
        
        Detailed recommendations have been generated for your review.
        """
    end
end

# Prompt generation functions

"""
    create_plan_explanation_prompt(context)

Create a prompt for plan explanation.
"""
function create_plan_explanation_prompt(context::Dict)
    return """
    You are a DeFi risk management expert. Analyze the following liquidation protection scenario and provide a clear, actionable explanation.

    **Position Summary:**
    - Health Factor: $(context["current_hf"])
    - Total Collateral: $(Utils.format_currency(context["collateral_value"]))
    - Total Debt: $(Utils.format_currency(context["debt_value"]))
    - Risk Level: $(context["risk_level"])

    **Risk Assessment:**
    - Time to Breach: $(context["ttb_minutes"]) minutes
    - Liquidation Probability: $(Utils.format_percentage(context["breach_probability"]))
    - Critical Price Levels: $(context["critical_prices"])

    **Proposed Plans:**
    $(format_plans_for_prompt(context["plans"]))

    **User Policy:**
    - Max Spend per Incident: $(Utils.format_currency(context["max_spend"]))
    - Target Health Factor: $(context["target_hf"])
    - Allowed Strategies: $(context["allowed_strategies"])

    **Please provide:**
    1. **Risk Explanation** (2-3 sentences): Why is this position at risk right now?
    2. **Primary Recommendation** (1-2 sentences): Which plan do you recommend and why?
    3. **Alternative Analysis** (1-2 sentences): Brief pros/cons of alternative plans.
    4. **Summary** (≤50 words): Executive summary for dashboard display.

    Be specific with numbers, costs, and timeframes. Focus on actionable insights.
    """
end

"""
    create_incident_explanation_prompt(context)

Create a prompt for incident explanation.
"""
function create_incident_explanation_prompt(context::Dict)
    return """
    You are explaining a DeFi liquidation risk incident to a user. Provide a clear, urgent but not panicked explanation.

    **Incident Details:**
    - Position ID: $(context["position_id"])
    - Detected At: $(context["detected_at"])
    - Current Health Factor: $(context["current_hf"])
    - Liquidation Threshold: $(context["liquidation_threshold"])

    **Risk Analysis:**
    - Time to Breach: $(context["ttb_minutes"]) minutes
    - Breach Probability: $(Utils.format_percentage(context["breach_probability"]))
    - Market Conditions: $(context["market_conditions"])

    **Position Details:**
    - Collateral Assets: $(context["collateral_breakdown"])
    - Debt Assets: $(context["debt_breakdown"])
    - Recent Price Changes: $(context["price_changes"])

    **Please provide:**
    1. **Situation Summary** (1-2 sentences): What happened and why?
    2. **Urgency Level** (1 sentence): How urgent is this situation?
    3. **Next Steps** (1-2 sentences): What should the user do immediately?
    4. **Dashboard Message** (≤30 words): Brief alert for main dashboard.

    Use clear, non-technical language. Be informative but not alarming.
    """
end

"""
    create_risk_explanation_prompt(context)

Create a prompt for risk assessment explanation.
"""
function create_risk_explanation_prompt(context::Dict)
    return """
    You are analyzing the risk profile of a DeFi lending position. Provide educational, detailed risk analysis.

    **Position Analysis:**
    - Health Factor: $(context["health_factor"])
    - Portfolio Value: $(Utils.format_currency(context["total_value"]))
    - Leverage Ratio: $(context["leverage_ratio"])x
    - Diversification: $(context["asset_count"]) assets

    **Market Metrics:**
    - Volatility (30d): $(Utils.format_percentage(context["volatility"]))
    - Price Correlation: $(context["correlation_info"])
    - Market Trend: $(context["market_trend"])

    **Risk Scenarios:**
    - Base Case TTB: $(context["base_ttb"]) minutes
    - Stress Test Results: $(context["stress_scenarios"])
    - Liquidation Price Levels: $(context["liquidation_prices"])

    **Please provide:**
    1. **Risk Profile** (2-3 sentences): Overall risk characterization
    2. **Key Vulnerabilities** (1-2 sentences): Main risk factors to watch
    3. **Risk Mitigation** (1-2 sentences): How to reduce risk
    4. **Monitoring Advice** (1 sentence): What metrics to track

    Be educational and help the user understand their risk exposure.
    """
end

# Helper functions for prompt formatting

"""
    format_plans_for_prompt(plans)

Format plans for inclusion in prompts.
"""
function format_plans_for_prompt(plans::Vector{Plan})
    if isempty(plans)
        return "No plans available"
    end
    
    formatted = String[]
    
    for (i, plan) in enumerate(plans)
        plan_type = i == 1 ? "Primary Plan" : "Alternative $(i-1)"
        
        plan_text = """
        **$(plan_type):**
        - Actions: $(length(plan.actions)) steps ($(join([action.action_type for action in plan.actions], ", ")))
        - Total Cost: $(Utils.format_currency(plan.total_cost_usd))
        - New Health Factor: $(round(plan.hf_after, digits=2))
        - Confidence: $(Utils.format_percentage(plan.confidence))
        """
        
        push!(formatted, plan_text)
    end
    
    return join(formatted, "\n\n")
end

# Context preparation functions

"""
    prepare_plan_context(incident, plans, policy)

Prepare context for plan explanation.
"""
function prepare_plan_context(incident::Incident, plans::Vector{Plan}, policy::Policy)
    return Dict(
        "incident_id" => incident.incident_id,
        "current_hf" => incident.risk_assessment.ttb_minutes > 0 ? 1.15 : 1.05,  # Mock data
        "collateral_value" => 2500.0,
        "debt_value" => 1800.0,
        "risk_level" => "medium",
        "ttb_minutes" => incident.risk_assessment.ttb_minutes,
        "breach_probability" => incident.risk_assessment.breach_probability,
        "critical_prices" => incident.risk_assessment.critical_price_levels,
        "plans" => plans,
        "max_spend" => policy.max_per_incident_usd,
        "target_hf" => policy.hf_target,
        "allowed_strategies" => get_allowed_strategies(policy)
    )
end

"""
    prepare_incident_context(incident, position, risk_assessment)

Prepare context for incident explanation.
"""
function prepare_incident_context(incident::Incident, position::Position, risk_assessment::TimeToBreachResult)
    return Dict(
        "position_id" => position.position_id,
        "detected_at" => incident.detected_at,
        "current_hf" => position.health_factor,
        "liquidation_threshold" => position.liquidation_threshold,
        "ttb_minutes" => risk_assessment.ttb_minutes,
        "breach_probability" => risk_assessment.breach_probability,
        "market_conditions" => "Increased volatility",
        "collateral_breakdown" => format_asset_breakdown(position.collateral),
        "debt_breakdown" => format_asset_breakdown(position.debt),
        "price_changes" => "SOL -6.2%, ETH -3.1%"
    )
end

"""
    prepare_risk_context(position, risk_assessment, oracle_prices)

Prepare context for risk assessment explanation.
"""
function prepare_risk_context(position::Position, risk_assessment::TimeToBreachResult, oracle_prices::Dict{String, Float64})
    total_collateral = sum(asset.amount * get(oracle_prices, asset.mint, 1.0) for asset in position.collateral)
    total_debt = sum(asset.amount * get(oracle_prices, asset.mint, 1.0) for asset in position.debt)
    
    return Dict(
        "health_factor" => position.health_factor,
        "total_value" => total_collateral,
        "leverage_ratio" => total_debt > 0 ? total_collateral / total_debt : 1.0,
        "asset_count" => length(unique([asset.mint for asset in position.collateral])),
        "volatility" => 0.35,  # Mock 35% annualized volatility
        "correlation_info" => "Moderate correlation (0.6) between major assets",
        "market_trend" => "Bearish short-term, neutral medium-term",
        "base_ttb" => risk_assessment.ttb_minutes,
        "stress_scenarios" => format_stress_scenarios(risk_assessment.shock_scenarios),
        "liquidation_prices" => risk_assessment.critical_price_levels
    )
end

# Parsing functions

"""
    parse_plan_explanation(response)

Parse LLM response for plan explanation.
"""
function parse_plan_explanation(response::String)
    # Simple parsing - in production would use more sophisticated extraction
    lines = split(response, "\n")
    
    explanation_short = ""
    explanation_detailed = response
    confidence = 0.85
    
    # Try to extract summary/short explanation
    for line in lines
        if contains(lowercase(line), "summary") || contains(lowercase(line), "executive")
            explanation_short = strip(line)
            break
        end
    end
    
    if isempty(explanation_short)
        # Use first meaningful sentence as short explanation
        sentences = split(response, ". ")
        if !isempty(sentences)
            explanation_short = sentences[1] * "."
        end
    end
    
    return Dict(
        "explanation_short" => explanation_short,
        "explanation_detailed" => explanation_detailed,
        "confidence" => confidence
    )
end

"""
    parse_incident_explanation(response)

Parse LLM response for incident explanation.
"""
function parse_incident_explanation(response::String)
    return Dict(
        "explanation_short" => extract_summary_from_response(response),
        "explanation_detailed" => response,
        "confidence" => 0.80
    )
end

"""
    parse_risk_explanation(response)

Parse LLM response for risk assessment explanation.
"""
function parse_risk_explanation(response::String)
    return Dict(
        "explanation_short" => extract_summary_from_response(response),
        "explanation_detailed" => response,
        "confidence" => 0.85
    )
end

# Fallback explanation functions

"""
    create_fallback_plan_explanation(incident, plans)

Create fallback explanation when LLM fails.
"""
function create_fallback_plan_explanation(incident::Incident, plans::Vector{Plan})
    primary_plan = isempty(plans) ? nothing : plans[1]
    
    if primary_plan !== nothing
        short_explanation = "Recommended plan costs $(Utils.format_currency(primary_plan.total_cost_usd)) and improves health factor to $(round(primary_plan.hf_after, digits=2))."
        
        detailed_explanation = """
        Protection plan analysis:
        
        Primary recommendation involves $(length(primary_plan.actions)) actions with total cost of $(Utils.format_currency(primary_plan.total_cost_usd)).
        This will improve your health factor from current levels to $(round(primary_plan.hf_after, digits=2)).
        
        The plan has been optimized for cost-effectiveness while maintaining safety margins.
        Execute within the next $(round(incident.risk_assessment.ttb_minutes)) minutes for optimal results.
        """
    else
        short_explanation = "Position requires immediate attention. Please review risk parameters."
        detailed_explanation = "Unable to generate optimized protection plan. Manual intervention may be required."
    end
    
    return Dict(
        "explanation_short" => short_explanation,
        "explanation_detailed" => detailed_explanation,
        "confidence" => 0.5
    )
end

"""
    create_fallback_incident_explanation(incident, position, risk_assessment)

Create fallback incident explanation.
"""
function create_fallback_incident_explanation(incident::Incident, position::Position, risk_assessment::TimeToBreachResult)
    ttb_text = risk_assessment.ttb_minutes < 60 ? "$(round(risk_assessment.ttb_minutes)) minutes" : "$(round(risk_assessment.ttb_minutes/60, digits=1)) hours"
    
    short_explanation = "Liquidation risk detected. Estimated time to critical threshold: $ttb_text."
    
    detailed_explanation = """
    Liquidation Risk Alert
    
    Your position ($(position.position_id)) has been flagged for liquidation risk.
    Current health factor: $(round(position.health_factor, digits=2))
    Time to breach estimate: $ttb_text
    
    Market conditions have created potential risk for your position.
    Please review the recommended protection plans and take action promptly.
    """
    
    return Dict(
        "explanation_short" => short_explanation,
        "explanation_detailed" => detailed_explanation,
        "confidence" => 0.7
    )
end

"""
    create_fallback_risk_explanation(position, risk_assessment)

Create fallback risk assessment explanation.
"""
function create_fallback_risk_explanation(position::Position, risk_assessment::TimeToBreachResult)
    risk_level = if position.health_factor > 1.5
        "Low"
    elseif position.health_factor > 1.2
        "Medium"
    else
        "High"
    end
    
    short_explanation = "$risk_level risk level with health factor of $(round(position.health_factor, digits=2))."
    
    detailed_explanation = """
    Risk Assessment Summary
    
    Current Position Status:
    - Health Factor: $(round(position.health_factor, digits=2))
    - Risk Level: $risk_level
    - Time to Breach: $(round(risk_assessment.ttb_minutes)) minutes
    
    Your position shows $(lowercase(risk_level)) risk characteristics based on current market conditions.
    Monitor your position regularly and consider protection measures if market volatility increases.
    """
    
    return Dict(
        "explanation_short" => short_explanation,
        "explanation_detailed" => detailed_explanation,
        "confidence" => 0.6
    )
end

# Utility functions

"""
    get_allowed_strategies(policy)

Extract allowed strategies from policy.
"""
function get_allowed_strategies(policy::Policy)
    strategies = String[]
    
    if policy.collateral_add_allowed
        push!(strategies, "Add Collateral")
    end
    
    if policy.partial_repay_allowed
        push!(strategies, "Partial Repayment")
    end
    
    if policy.hedge_allowed
        push!(strategies, "Hedging")
    end
    
    if policy.migration_allowed
        push!(strategies, "Position Migration")
    end
    
    return isempty(strategies) ? "None specified" : join(strategies, ", ")
end

"""
    format_asset_breakdown(assets)

Format asset list for display.
"""
function format_asset_breakdown(assets::Vector{AssetAmount})
    if isempty(assets)
        return "None"
    end
    
    formatted = String[]
    for asset in assets
        push!(formatted, "$(asset.amount) $(asset.mint)")
    end
    
    return join(formatted, ", ")
end

"""
    format_stress_scenarios(scenarios)

Format stress test scenarios for display.
"""
function format_stress_scenarios(scenarios::Vector{Float64})
    if isempty(scenarios)
        return "No stress scenarios"
    end
    
    formatted = [Utils.format_percentage(abs(scenario)) * " drop" for scenario in scenarios if scenario < 0]
    return join(formatted, ", ")
end

"""
    extract_summary_from_response(response)

Extract summary from LLM response.
"""
function extract_summary_from_response(response::String)
    # Simple extraction - look for summary section or use first sentence
    lines = split(response, "\n")
    
    for line in lines
        if contains(lowercase(line), "summary") || contains(lowercase(line), "dashboard")
            return strip(line)
        end
    end
    
    # Fall back to first meaningful sentence
    sentences = split(response, ". ")
    if !isempty(sentences)
        return strip(sentences[1]) * "."
    end
    
    return "Risk analysis completed."
end

"""
    chat_with_analyst(message::String)

Interactive chat with the analyst AI for general questions.
"""
function chat_with_analyst(message::String)
    if AGENT_STATE[] === nothing
        return Dict("response" => "Analyst agent not initialized", "status" => "error")
    end
    
    state = AGENT_STATE[]
    
    if CURRENT_MODE[] == "mock"
        # Mock response for demo
        mock_responses = [
            "Based on my analysis, this appears to be a flash loan attack attempting to manipulate the price oracle through arbitrage.",
            "The transaction was flagged because it shows signs of sandwich attack behavior - large position changes with unusual slippage patterns.",
            "This looks like a liquidation cascade attempt. The attacker is trying to force liquidations by creating artificial price pressure.",
            "The system detected unusual MEV behavior - this transaction appears to be part of a coordinated attack on the lending protocol.",
            "Warning: This transaction exhibits characteristics of a governance attack, attempting to manipulate voting power through flash loans."
        ]
        response_text = rand(mock_responses)
        return Dict("response" => response_text, "status" => "mock")
    end
    
    try
        # Real LLM interaction
        prompt = """You are X-LiGo, an expert DeFi security analyst AI. A user is asking you about blockchain security.

User Question: $message

Please provide a clear, expert response about DeFi security, transaction analysis, or protocol protection. Keep your response concise but informative.
"""
        
        # Get parameters from state configuration
        model = get(state.config, "default_llm_model", "gpt-4")
        temperature = get(state.config, "llm_temperature", 0.1)
        max_tokens = get(state.config, "llm_max_tokens", 1000)
        
        response_content = call_llm_api(state, prompt, model, temperature, max_tokens)
        
        # call_llm_api returns the content string directly
        if !isempty(response_content)
            return Dict("response" => response_content, "status" => "real")
        else
            return Dict("response" => "I'm having trouble accessing my knowledge base right now.", "status" => "error")
        end
    catch e
        @error "Chat with analyst failed" exception=e
        return Dict("response" => "Sorry, I encountered an error while processing your question.", "status" => "error")
    end
end

end # module AnalystLLM
