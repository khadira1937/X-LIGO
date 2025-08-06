#!/usr/bin/env julia
"""
QC (Quality Control) Script for X-LiGo System

This script verifies that the X-LiGo system can run in real mode without falling back to mocks.
It checks configuration, connectivity, and agent capabilities.

Usage: julia qc.jl
"""

using Pkg
Pkg.activate(".")

using XLiGo

println("🔎 X-LiGo Quality Control Starting...")
println("=" ^ 60)

# Load configuration
cfg = XLiGo.Config.load_config()
demo_mode = XLiGo.Config.getc(cfg, :demo_mode, true)

println("🔎 QC: demo_mode = $demo_mode")
println()

# Run configuration doctor
println("🩺 Running configuration doctor...")
doc = XLiGo.config_doctor(cfg)
println("🔎 QC doctor result:")
println("  ✓ ok: $(doc.ok)")
println("  ✓ missing keys: $(doc.missing)")
if !isempty(doc.notes)
    println("  ✓ notes:")
    for note in doc.notes
        println("    - $note")
    end
end
println()

# Check agent modes before start
println("👥 Agent modes (pre-start):")
modes_pre = XLiGo.agent_modes()
for (agent, mode) in modes_pre
    println("  $agent: $mode")
end
println()

# Start swarm
println("🚀 Starting X-LiGo swarm...")
result = XLiGo.start_swarm()
println("🔎 start_swarm result:")
println("  ✓ success: $(result.success)")
println("  ✓ message: $(result.message)")
println()

# Check agent modes after start
println("👥 Agent modes (after-start):")
modes_post = XLiGo.agent_modes()
for (agent, mode) in modes_post
    println("  $agent: $mode")
end
println()

# Assert conditions based on mode
if demo_mode == false
    println("🔒 Real mode validation...")
    
    # Hard requirements in real mode
    if !doc.ok
        println("❌ QC FAILED: Configuration incomplete")
        println("Missing required keys: $(doc.missing)")
        exit(1)
    end
    
    # No agent should be in mock mode in real mode
    mock_agents = [agent for (agent, mode) in modes_post if mode == "mock"]
    if !isempty(mock_agents)
        println("❌ QC FAILED: Agents running in mock mode")
        println("Mock agents: $mock_agents")
        println("In real mode (DEMO_MODE=false), all agents must use real services")
        exit(1)
    end
    
    # Check for critical agent failures
    failed_agents = [agent for (agent, mode) in modes_post if mode in ["error", "not_started"]]
    if !isempty(failed_agents)
        println("❌ QC FAILED: Critical agents failed to start")
        println("Failed agents: $failed_agents")
        exit(1)
    end
    
    println("✅ Real mode validation passed")
else
    println("🎭 Demo mode validation...")
    
    # In demo mode, it's ok to have mock agents
    mock_count = count(mode -> mode == "mock", values(modes_post))
    real_count = count(mode -> mode == "real", values(modes_post))
    
    println("  Mock agents: $mock_count")
    println("  Real agents: $real_count")
    
    if mock_count + real_count == 0
        println("❌ QC FAILED: No agents started successfully")
        exit(1)
    end
    
    println("✅ Demo mode validation passed")
end

println()
println("=" ^ 60)
println("✅ QC PASSED - X-LiGo system is ready!")
println("🎯 System validated for $(demo_mode ? "DEMO" : "PRODUCTION") mode")
