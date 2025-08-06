#!/usr/bin/env bash
# X-LiGo Quality Control Script
# Validates system readiness for real mode operation

set -euo pipefail

echo "🔧 X-LiGo QC - Preparing environment..."

# Ensure we're in the right directory
cd "$(dirname "$0")/.."

# Install and precompile dependencies
echo "📦 Installing and precompiling dependencies..."
julia --project=. -e "using Pkg; Pkg.instantiate(); Pkg.precompile()"

# Run QC validation
echo "🎯 Running QC validation..."
julia --project=. qc.jl

echo "🎉 QC validation completed!"
