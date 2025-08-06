#!/usr/bin/env julia

"""
Test script to verify the demo_runner.jl works with automated input
"""

# Create a test input file to simulate user input
input_data = """Test User
test@example.com
6dSk7LHZWmfw2ZJyCQsFd4z4Wjt9dUqAKAxKg3BmHQS
testuser001
"""

open("demo_input.txt", "w") do f
    write(f, input_data)
end

println("✅ Test input file created!")
println("📝 Contents:")
println("   Name: Test User")
println("   Email: test@example.com")
println("   Wallet: 6dSk7LHZWmfw2ZJyCQsFd4z4Wjt9dUqAKAxKg3BmHQS")
println("   Discord: testuser001")
println()
println("🚀 Run with: julia --project=. demo/demo_runner.jl < demo_input.txt")
