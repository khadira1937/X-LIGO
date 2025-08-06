"""
User Management Module

Handles user onboarding, wallet address validation, and profile management.
Supports both in-memory (demo mode) and MongoDB (production) storage.
"""
module UserManagement

using Dates
using ..Config
using ..Database
using Logging

export UserProfile, ProtectionPolicy, register_user, set_policy, get_user_profile, get_user_policy, list_active_users
export is_valid_solana_address, is_valid_ethereum_address

# Global in-memory storage for demo mode
const DEMO_USERS = Dict{String, Any}()
const DEMO_POLICIES = Dict{String, Any}()

"""
User profile structure
"""
struct UserProfile
    user_id::String
    display_name::String
    solana_wallet::Union{String, Nothing}
    ethereum_wallet::Union{String, Nothing}
    email::Union{String, Nothing}
    discord_id::Union{String, Nothing}
    created_at::DateTime
    last_active::DateTime
end

"""
Protection policy configuration
"""
struct ProtectionPolicy
    user_id::String
    max_daily_spend_usd::Float64
    max_per_incident_usd::Float64
    target_health_factor::Float64
    critical_health_factor::Float64
    auto_protection_enabled::Bool
    allowed_strategies::Vector{String}
    notification_preferences::Vector{String}
end

"""
Validation helper for Solana wallet addresses
"""
function is_valid_solana_address(address::Union{String, Nothing})::Bool
    address === nothing && return false
    isempty(address) && return false
    
    # Basic Solana address validation: base58, 32-44 characters
    if length(address) < 32 || length(address) > 44
        return false
    end
    
    # Check if it's valid base58 (simplified check)
    base58_chars = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"
    return all(c -> c in base58_chars, address)
end

"""
Validation helper for Ethereum wallet addresses  
"""
function is_valid_ethereum_address(address::Union{String, Nothing})::Bool
    address === nothing && return false
    isempty(address) && return false
    
    # Basic Ethereum address validation: 0x + 40 hex characters
    if !startswith(address, "0x") || length(address) != 42
        return false
    end
    
    # Check if the rest is valid hex
    hex_part = address[3:end]
    return all(c -> c in "0123456789abcdefABCDEF", hex_part)
end

"""
Convert UserProfile to Dict for JSON serialization
"""
function profile_to_dict(profile::UserProfile)::Dict{String, Any}
    return Dict(
        "user_id" => profile.user_id,
        "display_name" => profile.display_name,
        "solana_wallet" => profile.solana_wallet,
        "ethereum_wallet" => profile.ethereum_wallet,
        "email" => profile.email,
        "discord_id" => profile.discord_id,
        "created_at" => string(profile.created_at),
        "last_active" => string(profile.last_active)
    )
end

"""
Convert ProtectionPolicy to Dict for JSON serialization
"""
function policy_to_dict(policy::ProtectionPolicy)::Dict{String, Any}
    return Dict(
        "user_id" => policy.user_id,
        "max_daily_spend_usd" => policy.max_daily_spend_usd,
        "max_per_incident_usd" => policy.max_per_incident_usd,
        "target_health_factor" => policy.target_health_factor,
        "critical_health_factor" => policy.critical_health_factor,
        "auto_protection_enabled" => policy.auto_protection_enabled,
        "allowed_strategies" => policy.allowed_strategies,
        "notification_preferences" => policy.notification_preferences
    )
end

"""
Register a new user profile
"""
function register_user(user_data::Dict)::Dict{String, Any}
    try
        # Validate required fields
        if !haskey(user_data, "user_id") || isempty(get(user_data, "user_id", ""))
            return Dict("success" => false, "error" => "user_id is required")
        end
        
        user_id = user_data["user_id"]
        
        # Check if user already exists
        existing_profile = get_user_profile(user_id)
        if existing_profile !== nothing
            return Dict("success" => false, "error" => "User already exists")
        end
        
        # Validate required fields
        display_name = get(user_data, "display_name", "")
        if isempty(display_name)
            return Dict("success" => false, "error" => "display_name is required")
        end
        
        # Validate wallet addresses
        solana_wallet = get(user_data, "solana_wallet", nothing)
        ethereum_wallet = get(user_data, "ethereum_wallet", nothing)
        
        # Validate Solana wallet if provided
        if solana_wallet !== nothing && !isempty(solana_wallet)
            if !is_valid_solana_address(solana_wallet)
                return Dict("success" => false, "error" => "Invalid Solana wallet address")
            end
        else
            solana_wallet = nothing  # Normalize empty strings to nothing
        end
        
        # Validate Ethereum wallet if provided  
        if ethereum_wallet !== nothing && !isempty(ethereum_wallet)
            if !is_valid_ethereum_address(ethereum_wallet)
                return Dict("success" => false, "error" => "Invalid Ethereum wallet address")
            end
        else
            ethereum_wallet = nothing  # Normalize empty strings to nothing
        end
        
        # At least one wallet is required
        if solana_wallet === nothing && ethereum_wallet === nothing
            return Dict("success" => false, "error" => "At least one wallet address is required")
        end
        
        # Create user profile
        profile = UserProfile(
            user_id,
            display_name,
            solana_wallet,
            ethereum_wallet,
            get(user_data, "email", nothing),
            get(user_data, "discord_id", nothing),
            Dates.now(),
            Dates.now()
        )
        
        # Store based on mode
        demo_mode = get(ENV, "DEMO_MODE", "false") == "true"
        
        if demo_mode
            # Store in memory
            DEMO_USERS[user_id] = profile_to_dict(profile)
            @info "User registered in demo mode" user_id=user_id
        else
            # Store in MongoDB
            try
                store_user_profile(profile)
                @info "User registered in production mode" user_id=user_id
            catch e
                @error "Failed to store user profile in database" exception=e
                return Dict("success" => false, "error" => "Database storage failed")
            end
        end
        
        return Dict(
            "success" => true,
            "user_id" => user_id,
            "message" => "User registered successfully"
        )
        
    catch e
        @error "User registration failed" exception=e
        return Dict("success" => false, "error" => "Registration failed: $(string(e))")
    end
end

"""
Set protection policy for a user
"""
function set_policy(policy::ProtectionPolicy)::Dict{String, Any}
    try
        user_id = policy.user_id
        
        # Validate policy values
        if policy.max_daily_spend_usd < 0 || policy.max_per_incident_usd < 0
            return Dict("success" => false, "error" => "Spend limits must be non-negative")
        end
        
        if policy.target_health_factor <= 0 || policy.critical_health_factor <= 0
            return Dict("success" => false, "error" => "Health factors must be positive")
        end
        
        if policy.critical_health_factor >= policy.target_health_factor
            return Dict("success" => false, "error" => "Critical health factor must be lower than target")
        end
        
        # Store based on mode
        demo_mode = get(ENV, "DEMO_MODE", "false") == "true"
        
        if demo_mode
            # Store in memory
            DEMO_POLICIES[user_id] = policy_to_dict(policy)
            @info "Policy set in demo mode" user_id=user_id
        else
            # Store in MongoDB
            try
                store_user_policy(policy)
                @info "Policy set in production mode" user_id=user_id
            catch e
                @error "Failed to store user policy in database" exception=e
                return Dict("success" => false, "error" => "Database storage failed")
            end
        end
        
        return Dict(
            "success" => true,
            "user_id" => user_id,
            "message" => "Policy set successfully"
        )
        
    catch e
        @error "Policy setting failed" exception=e
        return Dict("success" => false, "error" => "Policy setting failed: $(string(e))")
    end
end

"""
Get user profile by ID
"""
function get_user_profile(user_id::String)::Union{Dict{String, Any}, Nothing}
    try
        demo_mode = get(ENV, "DEMO_MODE", "false") == "true"
        
        if demo_mode
            # Get from memory
            return get(DEMO_USERS, user_id, nothing)
        else
            # Get from MongoDB
            try
                profile = Database.get_user_profile(user_id)
                return profile === nothing ? nothing : profile_to_dict(profile)
            catch e
                @error "Failed to retrieve user profile from database" exception=e user_id=user_id
                return nothing
            end
        end
        
    catch e
        @error "Failed to get user profile" exception=e user_id=user_id
        return nothing
    end
end

"""
Get user policy by ID
"""
function get_user_policy(user_id::String)::Union{Dict{String, Any}, Nothing}
    try
        demo_mode = get(ENV, "DEMO_MODE", "false") == "true"
        
        if demo_mode
            # Get from memory
            return get(DEMO_POLICIES, user_id, nothing)
        else
            # Get from MongoDB
            try
                policy = Database.get_user_policy(user_id)
                return policy === nothing ? nothing : policy_to_dict(policy)
            catch e
                @error "Failed to retrieve user policy from database" exception=e user_id=user_id
                return nothing
            end
        end
        
    catch e
        @error "Failed to get user policy" exception=e user_id=user_id
        return nothing
    end
end

"""
List all active users
"""
function list_active_users()::Vector{Dict{String, Any}}
    try
        demo_mode = get(ENV, "DEMO_MODE", "false") == "true"
        
        if demo_mode
            # Get from memory
            return collect(values(DEMO_USERS))
        else
            # Get from MongoDB
            try
                profiles = Database.list_user_profiles()
                return [profile_to_dict(p) for p in profiles]
            catch e
                @error "Failed to list user profiles from database" exception=e
                return []
            end
        end
        
    catch e
        @error "Failed to list active users" exception=e
        return []
    end
end

"""
Get count of monitored users for health checks
"""
function get_monitored_user_count()::Int
    try
        demo_mode = get(ENV, "DEMO_MODE", "false") == "true"
        
        if demo_mode
            return length(DEMO_USERS)
        else
            try
                return Database.count_user_profiles()
            catch e
                @error "Failed to count user profiles" exception=e
                return 0
            end
        end
        
    catch e
        @error "Failed to get monitored user count" exception=e
        return 0
    end
end

end # module UserManagement
