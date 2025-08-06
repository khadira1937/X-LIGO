# X-LiGo Quality Control (QC) Mode Documentation

## Overview
The X-LiGo QC Mode provides comprehensive validation for production readiness with fail-fast behavior when critical components are missing.

## Usage

### One-Command QC (Recommended)
```bash
# Run QC in demo mode (allows mocks)
./scripts/qc.sh

# Run QC in real mode (requires all services)
DEMO_MODE=false ./scripts/qc.sh
```

### Direct QC Script
```bash
# Demo mode
julia --project=. qc.jl

# Real mode
DEMO_MODE=false julia --project=. qc.jl
```

## QC Features

### ✅ Implemented
1. **Configuration Doctor** - Validates all required config keys
2. **Agent Mode Detection** - Reports mock vs real status for each agent
3. **Connectivity Checks** - Tests LLM, Solana, and EVM connections
4. **Fail-Fast Behavior** - Exit code 1 if critical components missing in real mode
5. **API Status Endpoint** - HTTP server with `/status` endpoint
6. **Demo Mode Support** - Graceful degradation with mock services
7. **Comprehensive Logging** - Detailed validation results
8. **Environment Integration** - Respects DEMO_MODE env variable
9. **One-Command Interface** - `./scripts/qc.sh` for easy CI/CD

### QC Validation Process
1. Load configuration from `.env` file
2. Run configuration doctor to check required keys
3. Start X-LiGo swarm with fail-fast enabled
4. Validate agent modes (mock vs real)
5. Check connectivity for critical services
6. Report final status with appropriate exit code

### Exit Codes
- **0**: QC passed - system ready for operation
- **1**: QC failed - critical components missing or failing

### Configuration Requirements

#### Demo Mode (DEMO_MODE=true)
- No strict requirements
- Missing services gracefully degrade to mocks
- Always passes QC validation

#### Real Mode (DEMO_MODE=false)  
- **Required**: OpenAI API key (`openai_api_key`)
- **Optional**: Solana signing keys
- **Optional**: EVM RPC endpoints
- Fails fast if required services unavailable

## API Server
The QC system includes an HTTP API server for monitoring:

```bash
# Start API server (background)
julia --project=. -e "using XLiGo; XLiGo.start_api_server(8080)"

# Check system status
curl http://localhost:8080/status
curl http://localhost:8080/health
```

## Integration
- **CI/CD**: Use `./scripts/qc.sh` in deployment pipelines
- **Development**: Run `DEMO_MODE=false ./scripts/qc.sh` before production deployments
- **Monitoring**: Query `/status` endpoint for system health checks
- **Debugging**: Check agent modes and connectivity status in QC output

## Example Outputs

### Demo Mode Success
```
✅ QC PASSED - X-LiGo system is ready!
🎯 System validated for DEMO mode
```

### Real Mode Failure
```
❌ QC FAILED: Configuration incomplete
Missing required keys: ["openai_api_key"]
```

The QC system ensures production readiness while maintaining development flexibility through intelligent mock fallbacks in demo mode.
