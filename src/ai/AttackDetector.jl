"""
AttackDetector Module

Enhanced incident classification with attack pattern detection.
Analyzes transaction patterns, position changes, and market conditions to identify attack vectors.
"""
module AttackDetector

using Dates
using ..IncidentStore
using ..PositionFetcher

export enhance_incident_classification, detect_attack_patterns, simulate_attack_scenario

# Attack detection thresholds
const FLASH_LOAN_THRESHOLD = 1_000_000.0  # $1M+
const RAPID_CHANGE_THRESHOLD = 0.15        # 15% price change
const BOT_FREQUENCY_THRESHOLD = 5          # 5+ transactions in 1 minute
const MEV_SLIPPAGE_THRESHOLD = 0.05        # 5% slippage

"""
Enhance incident classification with attack pattern detection.

# Arguments
- `incident::IncidentStore.Incident`: Base incident to enhance
- `position_data::Dict`: Additional position and transaction data

# Returns
- `IncidentStore.Incident`: Enhanced incident with attack classification
"""
function enhance_incident_classification(incident::IncidentStore.Incident, position_data::Dict{String, Any})::IncidentStore.Incident
    # Create enhanced metadata
    enhanced_metadata = copy(incident.metadata)
    
    # Detect attack patterns
    attack_patterns = detect_attack_patterns(incident, position_data)
    
    # Merge attack pattern data
    for (key, value) in attack_patterns
        enhanced_metadata[key] = value
    end
    
    # Determine attack type
    attack_type = classify_attack_type(incident, attack_patterns)
    enhanced_metadata["attack_type"] = attack_type
    
    # Calculate risk score
    risk_score = calculate_risk_score(incident, attack_patterns)
    enhanced_metadata["risk_score"] = risk_score
    
    # Update severity if attack detected
    new_severity = determine_enhanced_severity(incident.severity, attack_patterns, risk_score)
    
    # Create enhanced incident by copying the original and updating metadata
    enhanced_incident = IncidentStore.Incident(
        incident.user_id,
        incident.position_id,
        incident.protocol,
        incident.chain,
        new_severity,
        incident.reason,
        incident.health_factor,
        incident.threshold,
        incident.collateral_token,
        incident.collateral_amount,
        incident.debt_token,
        incident.debt_amount,
        incident.timestamp,
        enhanced_metadata
    )
    
    @info "Attack pattern analysis completed" attack_type=attack_type risk_score=risk_score enhanced_severity=new_severity
    
    return enhanced_incident
end

"""
Detect various attack patterns from incident and position data.
"""
function detect_attack_patterns(incident::IncidentStore.Incident, position_data::Dict{String, Any})::Dict{String, Any}
    patterns = Dict{String, Any}()
    
    # Flash loan detection
    patterns["flash_loan_detected"] = detect_flash_loan(position_data)
    patterns["large_transaction"] = detect_large_transaction(position_data)
    
    # Price manipulation detection
    patterns["rapid_price_change"] = detect_rapid_price_change(position_data)
    patterns["oracle_manipulation"] = detect_oracle_manipulation(position_data)
    
    # MEV and sandwich attacks
    patterns["mev_detected"] = detect_mev_activity(position_data)
    patterns["sandwich_attack"] = detect_sandwich_pattern(position_data)
    
    # Bot behavior detection
    patterns["bot_behavior"] = detect_bot_behavior(position_data)
    patterns["high_frequency"] = detect_high_frequency_trading(position_data)
    
    # Liquidation attacks
    patterns["liquidation_attack"] = detect_liquidation_attack(incident, position_data)
    patterns["collateral_drain"] = detect_collateral_drain(position_data)
    
    return patterns
end

"""
Detect flash loan patterns.
"""
function detect_flash_loan(position_data::Dict{String, Any})::Bool
    # Check for large loan amounts
    if haskey(position_data, "borrowed_amount")
        borrowed = get(position_data, "borrowed_amount", 0.0)
        if borrowed > FLASH_LOAN_THRESHOLD
            return true
        end
    end
    
    # Check for rapid borrow-repay cycles
    if haskey(position_data, "transaction_pattern")
        pattern = position_data["transaction_pattern"]
        if occursin("borrow", lowercase(pattern)) && occursin("repay", lowercase(pattern))
            return true
        end
    end
    
    # Check transaction timing (same block or very close)
    if haskey(position_data, "transaction_timing")
        timing = position_data["transaction_timing"]
        if haskey(timing, "same_block") && timing["same_block"]
            return true
        end
    end
    
    return false
end

"""
Detect large transaction volumes.
"""
function detect_large_transaction(position_data::Dict{String, Any})::Bool
    transaction_value = get(position_data, "transaction_value", 0.0)
    return transaction_value > FLASH_LOAN_THRESHOLD
end

"""
Detect rapid price changes.
"""
function detect_rapid_price_change(position_data::Dict{String, Any})::Bool
    if haskey(position_data, "price_change")
        price_change = abs(get(position_data, "price_change", 0.0))
        return price_change > RAPID_CHANGE_THRESHOLD
    end
    
    if haskey(position_data, "slippage")
        slippage = abs(get(position_data, "slippage", 0.0))
        return slippage > RAPID_CHANGE_THRESHOLD
    end
    
    return false
end

"""
Detect oracle manipulation attempts.
"""
function detect_oracle_manipulation(position_data::Dict{String, Any})::Bool
    # Check for price discrepancies between oracles
    if haskey(position_data, "oracle_deviation")
        deviation = abs(get(position_data, "oracle_deviation", 0.0))
        return deviation > 0.10  # 10% deviation threshold
    end
    
    # Check for unusual oracle update patterns
    if haskey(position_data, "oracle_updates")
        updates = position_data["oracle_updates"]
        if haskey(updates, "unusual_pattern") && updates["unusual_pattern"]
            return true
        end
    end
    
    return false
end

"""
Detect MEV (Maximal Extractable Value) activity.
"""
function detect_mev_activity(position_data::Dict{String, Any})::Bool
    # Check for high slippage
    if haskey(position_data, "slippage")
        slippage = abs(get(position_data, "slippage", 0.0))
        if slippage > MEV_SLIPPAGE_THRESHOLD
            return true
        end
    end
    
    # Check for frontrunning patterns
    if haskey(position_data, "frontrun_detected") && position_data["frontrun_detected"]
        return true
    end
    
    # Check for arbitrage activity
    if haskey(position_data, "arbitrage_detected") && position_data["arbitrage_detected"]
        return true
    end
    
    return false
end

"""
Detect sandwich attack patterns.
"""
function detect_sandwich_pattern(position_data::Dict{String, Any})::Bool
    # Check for transaction sandwich pattern
    if haskey(position_data, "transaction_sequence")
        sequence = position_data["transaction_sequence"]
        if haskey(sequence, "sandwich_pattern") && sequence["sandwich_pattern"]
            return true
        end
    end
    
    # Check for price manipulation around user transaction
    if haskey(position_data, "price_manipulation")
        manipulation = position_data["price_manipulation"]
        if haskey(manipulation, "before_transaction") && haskey(manipulation, "after_transaction")
            return manipulation["before_transaction"] && manipulation["after_transaction"]
        end
    end
    
    return false
end

"""
Detect bot behavior patterns.
"""
function detect_bot_behavior(position_data::Dict{String, Any})::Bool
    # Check transaction frequency
    if haskey(position_data, "transaction_frequency")
        freq = get(position_data, "transaction_frequency", 0)
        if freq > BOT_FREQUENCY_THRESHOLD
            return true
        end
    end
    
    # Check for programmatic patterns
    if haskey(position_data, "gas_usage")
        gas = position_data["gas_usage"]
        if haskey(gas, "consistent_pattern") && gas["consistent_pattern"]
            return true
        end
    end
    
    # Check for non-human timing patterns
    if haskey(position_data, "timing_analysis")
        timing = position_data["timing_analysis"]
        if haskey(timing, "non_human_pattern") && timing["non_human_pattern"]
            return true
        end
    end
    
    return false
end

"""
Detect high-frequency trading patterns.
"""
function detect_high_frequency_trading(position_data::Dict{String, Any})::Bool
    # Check transaction count in short timeframe
    if haskey(position_data, "recent_transaction_count")
        count = get(position_data, "recent_transaction_count", 0)
        timeframe = get(position_data, "timeframe_minutes", 60)
        
        if timeframe <= 5 && count >= 10  # 10+ transactions in 5 minutes
            return true
        end
    end
    
    return false
end

"""
Detect liquidation attack patterns.
"""
function detect_liquidation_attack(incident::IncidentStore.Incident, position_data::Dict{String, Any})::Bool
    # Must have low health factor
    if incident.health_factor > 1.2
        return false
    end
    
    # Check for coordinated price movements
    if haskey(position_data, "coordinated_attack") && position_data["coordinated_attack"]
        return true
    end
    
    # Check for unusual collateral removal
    if haskey(position_data, "collateral_removal")
        removal = position_data["collateral_removal"]
        if haskey(removal, "unusual_timing") && removal["unusual_timing"]
            return true
        end
    end
    
    return false
end

"""
Detect collateral drain attacks.
"""
function detect_collateral_drain(position_data::Dict{String, Any})::Bool
    # Check for rapid collateral reduction
    if haskey(position_data, "collateral_change")
        change = get(position_data, "collateral_change", 0.0)
        if change < -0.20  # 20% reduction
            return true
        end
    end
    
    return false
end

"""
Classify the overall attack type based on detected patterns.
"""
function classify_attack_type(incident::IncidentStore.Incident, patterns::Dict{String, Any})::String
    # Priority order for attack classification
    if patterns["flash_loan_detected"]
        return "flash_loan_attack"
    elseif patterns["sandwich_attack"]
        return "sandwich_attack"
    elseif patterns["oracle_manipulation"]
        return "oracle_manipulation"
    elseif patterns["liquidation_attack"]
        return "liquidation_attack"
    elseif patterns["mev_detected"]
        return "mev_extraction"
    elseif patterns["bot_behavior"] && incident.health_factor < 1.3
        return "automated_attack"
    elseif patterns["collateral_drain"]
        return "collateral_drain"
    else
        return "none"
    end
end

"""
Calculate risk score based on incident and attack patterns.
"""
function calculate_risk_score(incident::IncidentStore.Incident, patterns::Dict{String, Any})::Float64
    base_score = 0.0
    
    # Health factor contribution (50% weight)
    if incident.health_factor < 1.05
        base_score += 50.0
    elseif incident.health_factor < 1.1
        base_score += 40.0
    elseif incident.health_factor < 1.2
        base_score += 30.0
    elseif incident.health_factor < 1.5
        base_score += 20.0
    else
        base_score += 10.0
    end
    
    # Attack pattern contributions
    if patterns["flash_loan_detected"]
        base_score += 25.0
    end
    
    if patterns["oracle_manipulation"]
        base_score += 20.0
    end
    
    if patterns["sandwich_attack"]
        base_score += 15.0
    end
    
    if patterns["liquidation_attack"]
        base_score += 15.0
    end
    
    if patterns["bot_behavior"]
        base_score += 10.0
    end
    
    if patterns["mev_detected"]
        base_score += 10.0
    end
    
    if patterns["large_transaction"]
        base_score += 5.0
    end
    
    return min(base_score, 100.0)  # Cap at 100
end

"""
Determine enhanced severity based on attack patterns and risk score.
"""
function determine_enhanced_severity(original_severity::String, patterns::Dict{String, Any}, risk_score::Float64)::String
    # Escalate severity for confirmed attacks
    if risk_score >= 80.0
        return "CRITICAL"
    elseif risk_score >= 60.0
        return "HIGH"
    elseif risk_score >= 40.0
        return "MEDIUM"
    elseif risk_score >= 20.0
        return "LOW"
    else
        return original_severity
    end
end

"""
Simulate attack scenario for testing purposes.
"""
function simulate_attack_scenario(attack_type::String, user_id::String)::IncidentStore.Incident
    @info "Simulating attack scenario" attack_type=attack_type user_id=user_id
    
    # Generate base incident data
    base_metadata = Dict{String, Any}(
        "protocol" => "aave",
        "value_at_risk" => 50000.0,
        "simulated" => true
    )
    
    # Customize based on attack type
    if attack_type == "flash_loan"
        health_factor = 1.05
        metadata = merge(base_metadata, Dict(
            "flash_loan_detected" => true,
            "large_transaction" => true,
            "borrowed_amount" => 2_000_000.0,
            "attack_type" => "flash_loan_attack",
            "risk_score" => 85.0
        ))
        incident_type = "flash_loan_attack"
        severity = "CRITICAL"
        
    elseif attack_type == "sandwich"
        health_factor = 1.15
        metadata = merge(base_metadata, Dict(
            "sandwich_attack" => true,
            "mev_detected" => true,
            "slippage" => 0.08,
            "attack_type" => "sandwich_attack",
            "risk_score" => 70.0
        ))
        incident_type = "sandwich_attack"
        severity = "HIGH"
        
    elseif attack_type == "liquidation"
        health_factor = 1.02
        metadata = merge(base_metadata, Dict(
            "liquidation_attack" => true,
            "bot_behavior" => true,
            "coordinated_attack" => true,
            "attack_type" => "liquidation_attack",
            "risk_score" => 90.0
        ))
        incident_type = "liquidation_attack"
        severity = "CRITICAL"
        
    else  # Default health factor violation
        health_factor = 1.08
        metadata = merge(base_metadata, Dict(
            "attack_type" => "none",
            "risk_score" => 45.0
        ))
        incident_type = "health_factor_violation"
        severity = "MEDIUM"
    end
    
    # Create incident with metadata
    position_data = Dict{String, Any}(
        "position_id" => "sim_position_$(rand(1000:9999))",
        "protocol" => get(metadata, "protocol", "aave"),
        "chain" => "ethereum",
        "health_factor" => health_factor,
        "collateral_token" => "USDC",
        "collateral_amount" => get(metadata, "value_at_risk", 50000.0),
        "debt_token" => "ETH",
        "debt_amount" => get(metadata, "value_at_risk", 50000.0) * 0.8
    )
    
    incident = IncidentStore.create_incident(user_id, position_data, 1.20, severity, metadata)
    
    # Add to incident store
    IncidentStore.add_incident!(incident)
    
    @info "Attack scenario simulation completed" incident_type=incident_type severity=severity health_factor=health_factor
    
    return incident
end

end # module AttackDetector
