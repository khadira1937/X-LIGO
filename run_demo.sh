#!/bin/bash

# X-LiGo DeFi Protection System Demo
# Run this script to see the complete end-to-end demo

echo "🎯 X-LiGo DeFi Protection Demo Launcher"
echo "======================================"

# Check if Julia is available
if ! command -v julia &> /dev/null; then
    echo "❌ Julia not found. Please install Julia first."
    echo "   Download from: https://julialang.org/downloads/"
    exit 1
fi

echo "✅ Julia found: $(julia --version)"

# Navigate to project directory
cd "$(dirname "$0")"
echo "📁 Working directory: $(pwd)"

# Check if Project.toml exists
if [ ! -f "Project.toml" ]; then
    echo "❌ Project.toml not found. Make sure you're in the X-LiGo project directory."
    exit 1
fi

echo "✅ X-LiGo project found"

# Check if .env file exists and has required keys
if [ ! -f ".env" ]; then
    echo "❌ .env file not found. Please create it with your API keys."
    exit 1
fi

echo "✅ Configuration file found"

# Set environment for real mode
export DEMO_MODE=false

echo ""
echo "🚀 Starting X-LiGo Complete Demo..."
echo "   This will demonstrate:"
echo "   • Real-time threat detection"
echo "   • AI-powered analysis"
echo "   • Automatic protection execution"
echo "   • Human-readable explanations"
echo ""
echo "📋 Note: If some agents show 'mock' status, that's normal"
echo "   when API keys are not configured for all services."
echo ""

# Run the demo
julia demo_run.jl

echo ""
echo "🎉 Demo completed!"
echo "💡 To test API endpoints manually:"
echo "   curl http://localhost:3000/health"
echo "   curl http://localhost:3000/status" 
echo "   curl -X POST http://localhost:3000/chat \\"
echo "        -H 'Content-Type: application/json' \\"
echo "        -d '{\"message\":\"What is a flash loan attack?\"}'"
