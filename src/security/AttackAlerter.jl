"""
Attack alerting module for sending Discord notifications and updating system state
when attacks are detected.
"""
module AttackAlerter

using Dates, HTTP, JSON3, Logging
using ..Config

export send_attack_alert, update_latest_incident

# Global state for latest security incident
const LATEST_SECURITY_INCIDENT = Ref{Union{Nothing, Dict}}(nothing)

"""
    get_latest_security_incident()

Get the latest security incident for use by chat/status endpoints.
"""
function get_latest_security_incident()
    return LATEST_SECURITY_INCIDENT[]
end

"""
    update_latest_incident(incident::Dict)

Update the global latest security incident state.
"""
function update_latest_incident(incident::Dict)
    try
        LATEST_SECURITY_INCIDENT[] = Dict(
            "incident_id" => get(incident, "incident_id", "unknown"),
            "user_id" => get(incident, "user_id", "unknown"),
            "attack_type" => get(incident, "attack_type", "unknown"),
            "severity" => get(incident, "severity", "unknown"),
            "confidence" => get(incident, "confidence", 0.0),
            "timestamp" => get(incident, "timestamp", Dates.now()),
            "tx_hash" => get(incident, "tx_hash", ""),
            "protocol" => get(incident, "protocol", ""),
            "chain" => get(incident, "chain", ""),
            "indicators" => get(incident, "indicators", Vector{String}()),
            "recommendations" => get(incident, "recommendations", Vector{String}()),
            "alert_sent" => get(incident, "alert_sent", false)
        )
        
        @info "Updated latest security incident" incident_id=incident["incident_id"] user_id=incident["user_id"]
        return true
    catch e
        @error "Failed to update latest security incident" exception=e
        return false
    end
end

"""
    send_attack_alert(user_id::String, analysis::Dict, tx::Dict)

Send attack alert via Discord webhook and update latest incident.
"""
function send_attack_alert(user_id::String, analysis::Dict, tx::Dict)
    try
        @info "Sending attack alert for user $user_id"
        
        # Generate incident ID
        incident_id = "incident_$(Int(floor(Dates.datetime2unix(Dates.now()))))"
        
        # Prepare incident data
        incident = Dict(
            "incident_id" => incident_id,
            "user_id" => user_id,
            "attack_type" => get(analysis, "attack_type", "unknown"),
            "severity" => get(analysis, "severity", "unknown"),
            "confidence" => get(analysis, "confidence", 0.0),
            "timestamp" => Dates.now(),
            "tx_hash" => get(tx, "hash", get(analysis, "tx_hash", "")),
            "protocol" => get(tx, "protocol", "unknown"),
            "chain" => get(tx, "chain", "unknown"),
            "indicators" => get(analysis, "indicators", Vector{String}()),
            "recommendations" => get(analysis, "recommendations", Vector{String}()),
            "alert_sent" => false
        )
        
        # Update latest incident first
        update_latest_incident(incident)
        
        # Get Discord webhook URL
        cfg = Config.load_config()
        discord_webhook_url = get(cfg, "DISCORD_WEBHOOK_URL", "")
        
        if isempty(discord_webhook_url)
            @warn "DISCORD_WEBHOOK_URL not configured, skipping Discord alert"
            incident["alert_sent"] = false
            incident["alert_error"] = "Discord webhook URL not configured"
            update_latest_incident(incident)
            return (success=false, message="Discord webhook not configured")
        end
        
        # Prepare Discord embed
        embed_color = Dict(
            "critical" => 16711680,  # Red
            "high" => 16753920,      # Orange  
            "medium" => 16776960,    # Yellow
            "low" => 8421504         # Gray
        )
        
        severity = incident["severity"]
        color = get(embed_color, severity, 8421504)
        
        # Format indicators and recommendations
        indicators_text = isempty(incident["indicators"]) ? 
            "No specific indicators detected" : 
            join(["• " * ind for ind in incident["indicators"]], "\n")
            
        recommendations_text = isempty(incident["recommendations"]) ? 
            "Monitor situation closely" : 
            join(["• " * rec for rec in incident["recommendations"]], "\n")
        
        # Create Discord embed
        embed = Dict(
            "title" => "🚨 Security Alert: $(uppercase(incident["attack_type"])) Attack Detected",
            "description" => "Potential attack detected affecting user positions",
            "color" => color,
            "timestamp" => string(incident["timestamp"]),
            "fields" => [
                Dict(
                    "name" => "User ID",
                    "value" => user_id,
                    "inline" => true
                ),
                Dict(
                    "name" => "Severity",
                    "value" => uppercase(severity),
                    "inline" => true
                ),
                Dict(
                    "name" => "Confidence",
                    "value" => "$(round(incident["confidence"] * 100, digits=1))%",
                    "inline" => true
                ),
                Dict(
                    "name" => "Protocol",
                    "value" => incident["protocol"],
                    "inline" => true
                ),
                Dict(
                    "name" => "Chain",
                    "value" => incident["chain"],
                    "inline" => true
                ),
                Dict(
                    "name" => "Incident ID",
                    "value" => incident_id,
                    "inline" => true
                ),
                Dict(
                    "name" => "Indicators",
                    "value" => indicators_text,
                    "inline" => false
                ),
                Dict(
                    "name" => "Recommendations",
                    "value" => recommendations_text,
                    "inline" => false
                )
            ]
        )
        
        # Add transaction hash if available
        if !isempty(incident["tx_hash"])
            push!(embed["fields"], Dict(
                "name" => "Transaction Hash",
                "value" => "`$(incident["tx_hash"])`",
                "inline" => false
            ))
        end
        
        # Add footer
        embed["footer"] = Dict(
            "text" => "X-LiGo Security Monitor • Incident $(incident_id)",
            "icon_url" => "https://cdn.discordapp.com/embed/avatars/0.png"
        )
        
        # Send Discord webhook
        webhook_payload = Dict(
            "username" => "X-LiGo Security Alert",
            "embeds" => [embed]
        )
        
        try
            @debug "Sending Discord webhook" url=discord_webhook_url
            
            response = HTTP.post(
                discord_webhook_url,
                ["Content-Type" => "application/json"],
                JSON3.write(webhook_payload)
            )
            
            if response.status == 204
                @info "Attack alert sent successfully via Discord" incident_id=incident_id user_id=user_id
                incident["alert_sent"] = true
                update_latest_incident(incident)
                return (success=true, message="Attack alert sent successfully", incident_id=incident_id)
            else
                @error "Discord webhook failed" status=response.status
                incident["alert_sent"] = false
                incident["alert_error"] = "Discord webhook returned status $(response.status)"
                update_latest_incident(incident)
                return (success=false, message="Discord webhook failed with status $(response.status)")
            end
            
        catch e
            @error "Failed to send Discord webhook" exception=e
            incident["alert_sent"] = false
            incident["alert_error"] = "Exception: $e"
            update_latest_incident(incident)
            return (success=false, message="Failed to send Discord alert: $e")
        end
        
    catch e
        @error "Failed to send attack alert" exception=e user_id=user_id
        return (success=false, message="Failed to send attack alert: $e")
    end
end

"""
    send_position_alert(user_id::String, position::Dict, health_factor::Float64, threshold::Float64)

Send alert when a user's position health factor crosses dangerous thresholds.
"""
function send_position_alert(user_id::String, position::Dict, health_factor::Float64, threshold::Float64)
    try
        @info "Sending position health alert for user $user_id"
        
        # Create mock analysis for position alert
        analysis = Dict(
            "attack_type" => "position_risk",
            "severity" => health_factor < 1.1 ? "critical" : "high",
            "confidence" => 0.9,
            "indicators" => [
                "Health factor dropped to $(round(health_factor, digits=3))",
                "Below threshold of $(round(threshold, digits=3))",
                "Position at risk of liquidation"
            ],
            "recommendations" => [
                "Add more collateral immediately",
                "Reduce debt position",
                "Monitor position closely"
            ]
        )
        
        # Create mock transaction for position alert
        tx = Dict(
            "hash" => "",
            "protocol" => get(position, "protocol", "unknown"),
            "chain" => get(position, "chain", "unknown")
        )
        
        return send_attack_alert(user_id, analysis, tx)
        
    catch e
        @error "Failed to send position alert" exception=e user_id=user_id
        return (success=false, message="Failed to send position alert: $e")
    end
end

"""
    get_incident_summary(incident_id::String)

Get a human-readable summary of a security incident for chat responses.
"""
function get_incident_summary(incident_id::String)
    try
        latest = get_latest_security_incident()
        
        if latest === nothing
            return "No security incidents recorded yet."
        end
        
        if incident_id != "latest" && get(latest, "incident_id", "") != incident_id
            return "Incident $incident_id not found. Latest incident ID: $(get(latest, "incident_id", "unknown"))"
        end
        
        severity = get(latest, "severity", "unknown")
        attack_type = get(latest, "attack_type", "unknown")
        confidence = get(latest, "confidence", 0.0)
        timestamp = get(latest, "timestamp", Dates.now())
        user_id = get(latest, "user_id", "unknown")
        indicators = get(latest, "indicators", Vector{String}())
        
        summary = """
        **Latest Security Incident Summary**
        
        • **Incident ID**: $(get(latest, "incident_id", "unknown"))
        • **Type**: $(uppercase(attack_type)) attack
        • **Severity**: $(uppercase(severity))
        • **Confidence**: $(round(confidence * 100, digits=1))%
        • **Affected User**: $user_id
        • **Detected**: $(Dates.format(timestamp, "yyyy-mm-dd HH:MM:SS"))
        • **Protocol**: $(get(latest, "protocol", "unknown"))
        • **Chain**: $(get(latest, "chain", "unknown"))
        
        **Key Indicators**:
        $(isempty(indicators) ? "No specific indicators" : join(["• " * ind for ind in indicators], "\n"))
        
        **Status**: $(get(latest, "alert_sent", false) ? "Alert sent to Discord" : "Alert pending")
        """
        
        return summary
        
    catch e
        @error "Failed to get incident summary" exception=e
        return "Error retrieving incident summary: $e"
    end
end

end # module AttackAlerter
