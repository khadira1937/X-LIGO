"""
ChatResponder Module

Provides natural language analysis and explanation of security incidents.
Uses AI reasoning to interpret user queries and fetch relevant incident data.
"""
module ChatResponder

using JSON3
using Dates
using ..IncidentStore
using ..UserManagement
using ..PositionFetcher

export generate_response

"""
Generate a natural language response to user queries about security incidents.

# Arguments
- `message::String`: User's natural language query

# Returns
- `String`: AI-generated response with incident analysis
"""
function generate_response(message::String)::String
    @info "[AI] ChatResponder triggered for message: \"$message\""
    
    # Parse intent from message
    intent = parse_message_intent(message)
    
    # Fetch relevant data based on intent
    incidents = fetch_relevant_incidents(intent)
    
    # Generate contextual response
    response = generate_contextual_response(intent, incidents, message)
    
    return response
end

"""
Parse user message to determine intent and extract parameters.
"""
function parse_message_intent(message::String)::Dict{String, Any}
    msg_lower = lowercase(message)
    
    intent = Dict{String, Any}(
        "type" => "general",
        "scope" => "recent",
        "user_id" => nothing,
        "timeframe" => "24h"
    )
    
    # Detect intent patterns
    if occursin(r"what.*happen|what.*going|status|incident", msg_lower)
        intent["type"] = "incident_summary"
    elseif occursin(r"attack|exploit|hack|flash.*loan|sandwich", msg_lower)
        intent["type"] = "attack_analysis"
    elseif occursin(r"last.*incident|recent.*incident|latest", msg_lower)
        intent["type"] = "latest_incident"
    elseif occursin(r"health.*factor|liquidation|risk", msg_lower)
        intent["type"] = "health_analysis"
    elseif occursin(r"user.*\w+|my.*position", msg_lower)
        intent["type"] = "user_specific"
        # Try to extract user ID from message
        user_match = match(r"user[:\s]+(\w+)", msg_lower)
        if user_match !== nothing
            intent["user_id"] = user_match.captures[1]
        end
    end
    
    # Detect timeframe
    if occursin(r"last.*hour|past.*hour", msg_lower)
        intent["timeframe"] = "1h"
    elseif occursin(r"today", msg_lower)
        intent["timeframe"] = "24h"
    elseif occursin(r"week", msg_lower)
        intent["timeframe"] = "7d"
    end
    
    return intent
end

"""
Fetch incidents relevant to the parsed intent.
"""
function fetch_relevant_incidents(intent::Dict{String, Any})::Vector{IncidentStore.Incident}
    if intent["user_id"] !== nothing
        return IncidentStore.get_user_incidents(intent["user_id"])
    else
        # Get recent incidents for general queries
        recent_incidents = IncidentStore.get_recent_incidents()
        
        # Filter by type if specific attack analysis requested
        if intent["type"] == "attack_analysis"
            return filter(inc -> inc.severity in ["HIGH", "CRITICAL"], recent_incidents)
        end
        
        return recent_incidents
    end
end

"""
Generate contextual response based on intent and incidents.
"""
function generate_contextual_response(intent::Dict{String, Any}, incidents::Vector{IncidentStore.Incident}, original_message::String)::String
    if isempty(incidents)
        return generate_no_incidents_response(intent)
    end
    
    latest_incident = incidents[1]  # Most recent
    
    if intent["type"] == "incident_summary"
        return generate_incident_summary(incidents)
    elseif intent["type"] == "attack_analysis"
        return generate_attack_analysis(incidents)
    elseif intent["type"] == "latest_incident"
        return generate_latest_incident_response(latest_incident)
    elseif intent["type"] == "health_analysis"
        return generate_health_analysis(incidents)
    elseif intent["type"] == "user_specific"
        return generate_user_specific_response(incidents, intent["user_id"])
    else
        return generate_general_response(incidents, original_message)
    end
end

"""
Generate response when no incidents are found.
"""
function generate_no_incidents_response(intent::Dict{String, Any})::String
    if intent["type"] == "attack_analysis"
        return "🛡️ **Security Status: CLEAR**\n\nNo recent attack patterns or security incidents detected. All monitored positions appear to be secure.\n\n✅ System is actively monitoring for:\n- Flash loan attacks\n- Sandwich attacks\n- Oracle manipulations\n- Liquidation risks"
    else
        return "🌟 **All Clear!**\n\nNo recent security incidents detected. Your DeFi positions are being monitored continuously.\n\n📊 **Current Status:**\n- Position monitoring: Active\n- Health factors: Within safe ranges\n- No alerts triggered in the last 24 hours"
    end
end

"""
Generate comprehensive incident summary.
"""
function generate_incident_summary(incidents::Vector{IncidentStore.Incident})::String
    total_incidents = length(incidents)
    critical_count = count(inc -> inc.severity == "CRITICAL", incidents)
    high_count = count(inc -> inc.severity == "HIGH", incidents)
    
    response = "🚨 **Security Incident Summary**\n\n"
    response *= "📊 **Overview:**\n"
    response *= "- Total incidents: $total_incidents\n"
    response *= "- Critical: $critical_count\n"
    response *= "- High severity: $high_count\n\n"
    
    if total_incidents > 0
        latest = incidents[1]
        response *= "🔍 **Latest Incident:**\n"
        response *= format_incident_details(latest)
    end
    
    return response
end

"""
Generate attack-focused analysis.
"""
function generate_attack_analysis(incidents::Vector{IncidentStore.Incident})::String
    attack_incidents = filter(inc -> inc.severity in ["HIGH", "CRITICAL"], incidents)
    
    if isempty(attack_incidents)
        return "🛡️ **Attack Analysis: NO THREATS DETECTED**\n\nNo high-severity incidents indicating attack patterns.\n\nSystem continues monitoring for suspicious activity."
    end
    
    latest_attack = attack_incidents[1]
    
    response = "⚔️ **ATTACK DETECTED**\n\n"
    response *= "🎯 **Attack Vector Analysis:**\n"
    response *= format_incident_details(latest_attack)
    
    # Add attack pattern analysis
    if latest_attack.health_factor < 1.1
        response *= "\n💡 **Analysis:** Possible liquidation attack - health factor critically low\n"
    elseif haskey(latest_attack.metadata, "large_transaction")
        response *= "\n💡 **Analysis:** Large transaction detected - possible flash loan attack\n"
    end
    
    return response
end

"""
Generate response for latest incident query.
"""
function generate_latest_incident_response(incident::IncidentStore.Incident)::String
    time_ago = format_time_ago(incident.timestamp)
    
    response = "🕐 **Latest Incident ($time_ago ago)**\n\n"
    response *= format_incident_details(incident)
    
    return response
end

"""
Generate health factor focused analysis.
"""
function generate_health_analysis(incidents::Vector{IncidentStore.Incident})::String
    health_incidents = filter(inc -> inc.health_factor < 1.5, incidents)
    
    response = "💓 **Health Factor Analysis**\n\n"
    
    if isempty(health_incidents)
        response *= "✅ All monitored positions have healthy collateralization ratios.\n"
        response *= "No liquidation risks detected."
    else
        avg_health = sum(inc.health_factor for inc in health_incidents) / length(health_incidents)
        min_health = minimum(inc.health_factor for inc in health_incidents)
        
        response *= "⚠️ **Risk Assessment:**\n"
        response *= "- Positions at risk: $(length(health_incidents))\n"
        response *= "- Average health factor: $(round(avg_health, digits=3))\n"
        response *= "- Lowest health factor: $(round(min_health, digits=3))\n\n"
        
        if min_health < 1.1
            response *= "🚨 **CRITICAL:** Immediate liquidation risk detected!\n"
        elseif min_health < 1.3
            response *= "⚠️ **WARNING:** Close to liquidation threshold\n"
        end
    end
    
    return response
end

"""
Generate user-specific response.
"""
function generate_user_specific_response(incidents::Vector{IncidentStore.Incident}, user_id::Union{String, Nothing})::String
    if user_id === nothing
        return "❓ Please specify a user ID for user-specific analysis."
    end
    
    response = "👤 **User Analysis: $user_id**\n\n"
    
    if isempty(incidents)
        response *= "✅ No security incidents found for this user.\n"
        response *= "All positions appear secure."
    else
        response *= "📊 **Incident History:**\n"
        for (i, incident) in enumerate(incidents[1:min(3, length(incidents))])
            response *= "$(i). $(format_incident_summary(incident))\n"
        end
        
        if length(incidents) > 3
            response *= "\n... and $(length(incidents) - 3) more incidents"
        end
    end
    
    return response
end

"""
Generate general response for unclassified queries.
"""
function generate_general_response(incidents::Vector{IncidentStore.Incident}, message::String)::String
    response = "🤖 **AI Analysis**\n\n"
    response *= "I detected $(length(incidents)) recent security incidents.\n\n"
    
    if length(incidents) > 0
        response *= "**Most Recent:**\n"
        response *= format_incident_details(incidents[1])
    end
    
    response *= "\n\n💬 **Available Commands:**\n"
    response *= "- \"What happened?\" - Get incident summary\n"
    response *= "- \"Show attacks\" - View attack analysis\n"
    response *= "- \"Health status\" - Check health factors\n"
    response *= "- \"User [user_id]\" - User-specific analysis"
    
    return response
end

"""
Format incident details for display.
"""
function format_incident_details(incident::IncidentStore.Incident)::String
    severity_emoji = incident.severity == "CRITICAL" ? "🔴" : 
                    incident.severity == "HIGH" ? "🟠" : "🟡"
    
    # Extract incident type from reason or metadata
    incident_type = get(incident.metadata, "attack_type", "health_factor_violation")
    
    details = "$severity_emoji **$(incident.severity)** - $(incident_type)\n"
    details *= "- User: $(incident.user_id)\n"
    details *= "- Position: $(incident.position_id)\n"
    details *= "- Health Factor: $(round(incident.health_factor, digits=3))\n"
    details *= "- Time: $(Dates.format(incident.timestamp, "yyyy-mm-dd HH:MM:SS"))\n"
    
    if !isempty(incident.protocol)
        details *= "- Protocol: $(incident.protocol)\n"
    end
    
    if haskey(incident.metadata, "value_at_risk")
        details *= "- Value at Risk: \$$(incident.metadata["value_at_risk"])\n"
    end
    
    return details
end

"""
Format incident summary for lists.
"""
function format_incident_summary(incident::IncidentStore.Incident)::String
    time_ago = format_time_ago(incident.timestamp)
    incident_type = get(incident.metadata, "attack_type", "health_factor_violation")
    return "$(incident.severity) $(incident_type) ($time_ago ago, HF: $(round(incident.health_factor, digits=2)))"
end

"""
Format time difference in human-readable format.
"""
function format_time_ago(timestamp::DateTime)::String
    diff = now() - timestamp
    
    if diff < Dates.Minute(1)
        return "just now"
    elseif diff < Dates.Hour(1)
        minutes = Dates.value(Dates.Minute(diff))
        return "$(minutes)m"
    elseif diff < Dates.Day(1)
        hours = Dates.value(Dates.Hour(diff))
        return "$(hours)h"
    else
        days = Dates.value(Dates.Day(diff))
        return "$(days)d"
    end
end

end # module ChatResponder
