# X-LiGo DeFi Protection System - PRODUCTION DEMO GUIDE
## Complete Step-by-Step Demo Instructions

🎯 **Objective**: Demonstrate the complete X-LiGo DeFi protection workflow from user registration to AI-powered threat detection and Discord alerts.

---

## 🚀 **STEP 1: System Validation (Pre-Demo Check)**

First, validate all components are working:

```bash
cd /home/oussama/JuliaOS
julia --project=. demo/validate_system.jl
```

**Expected Output**: All 5 tests should pass ✅
- Environment Configuration ✅
- User Registration ✅  
- Attack Simulation ✅
- AI Chat Response ✅
- Discord Webhook ✅

---

## 👤 **STEP 2: Run Complete Production Demo**

### Option A: Interactive Demo (Manual Input)
```bash
julia --project=. demo/start_full_demo.jl
```

When prompted, enter:
- **Display Name**: Your real name (e.g., "Oussama Khadira")
- **Email**: Your email address
- **Solana Wallet**: Your actual Solana wallet or use: `6dSk7LHZWmfw2ZJyCQsFd4z4Wjt9dUqAKAxKg3BmHQS`
- **Ethereum Wallet**: Your ETH wallet or leave blank for auto-generation
- **Discord Username**: Your Discord username

### Option B: Automated Demo (Pre-filled Data)
```bash
julia --project=. demo/start_full_demo.jl < demo/demo_input_full.txt
```

---

## 🔍 **STEP 3: What Happens During the Demo**

### Phase 1: User Registration (30 seconds)
- ✅ User profile created with unique ID
- ✅ Protection policy configured (Health Factor < 1.05 = CRITICAL)
- ✅ Wallets registered for monitoring

### Phase 2: Real-Time Monitoring Starts (Automatic)
- ✅ Background monitoring task initiated
- ✅ Position fetching every 5 seconds
- ✅ Vulnerability scanning active

### Phase 3: Attack Simulation & Detection (1 minute)
- ✅ Flash loan attack simulated on registered wallet
- ✅ Critical incident generated (Health Factor: 1.05)
- ✅ **Discord Alert Sent Automatically** 🚨

### Phase 4: AI Analysis System (1 minute)
- ✅ HTTP API server starts on port 3000
- ✅ AI chat endpoint available: `/chat`
- ✅ Multiple test queries demonstrated

### Phase 5: Interactive Chat Session (Optional)
- ✅ Real-time chat with AI about security status
- ✅ Natural language queries about incidents
- ✅ User-specific responses based on registered wallet

---

## 💬 **STEP 4: Test the Chat API**

While the demo is running, open a new terminal and test:

```bash
# Test 1: General security query
curl -X POST http://localhost:3000/chat \
     -H "Content-Type: application/json" \
     -d '{"message":"What happened?"}'

# Test 2: Specific user analysis  
curl -X POST http://localhost:3000/chat \
     -H "Content-Type: application/json" \
     -d '{"message":"Give me a security report"}'

# Test 3: Risk assessment
curl -X POST http://localhost:3000/chat \
     -H "Content-Type: application/json" \
     -d '{"message":"What is my current risk level?"}'

# Test 4: System status
curl -X GET http://localhost:3000/status
```

---

## 🔔 **STEP 5: Verify Discord Integration**

1. **Check Discord Channel**: You should receive a critical security alert
2. **Alert Contains**:
   - 👤 User name and wallet address
   - 🎯 Attack type (Flash Loan Attack)  
   - ⚠️ Severity level (CRITICAL)
   - 📊 Health factor (1.05)
   - 💵 Value at risk ($50,000)
   - ⚡ Recommended actions

---

## 📊 **STEP 6: Monitor System Status**

The demo provides real-time status updates every 30 seconds showing:

- 👤 **Registered User**: Name and user ID
- 💰 **Monitored Wallets**: Solana and Ethereum addresses
- 🔍 **Monitoring Status**: Active/Inactive
- 🌐 **API Server Status**: Running/Stopped  
- 🚨 **Incidents Count**: Number of threats detected
- ⏱️ **System Uptime**: Total runtime

---

## 🎮 **STEP 7: Interactive Features**

### Real-Time Chat Session
When prompted "Would you like to start an interactive chat session? (y/n)", type `y` to:

- Ask questions about your wallet security
- Get real-time risk assessments  
- Analyze detected incidents
- Receive personalized recommendations

### Example Chat Queries:
- "What happened to my wallet?"
- "Show me recent attacks"  
- "What is my current risk level?"
- "How can I improve my security?"
- "Give me a detailed security report"

---

## 🛑 **STEP 8: Stop the Demo**

- **Interactive Session**: Type `exit` to end chat
- **Full System**: Press `Ctrl+C` to stop all monitoring and services

The system will gracefully shutdown:
- ✅ Stop background monitoring
- ✅ Close API server
- ✅ Save final status

---

## ✅ **Expected Demo Results**

After successful completion, you should have:

1. ✅ **User Registered**: Profile stored with protection policies
2. ✅ **Attack Detected**: Flash loan vulnerability identified  
3. ✅ **Discord Alert Sent**: Rich notification with incident details
4. ✅ **AI Chat Working**: Natural language security analysis
5. ✅ **API Functional**: HTTP endpoints responding correctly
6. ✅ **Monitoring Active**: Real-time wallet protection running

---

## 🚨 **Troubleshooting**

### If Discord alerts don't work:
- Verify `DISCORD_WEBHOOK_URL` in `.env` file
- Test webhook: `julia --project=. demo/test_discord.jl`

### If AI chat fails:
- Check `OPENAI_API_KEY` in `.env` file  
- Verify internet connection

### If monitoring doesn't start:
- Ensure demo mode is enabled
- Check for Julia package dependencies

---

## 🎉 **Demo Success Criteria**

✅ User registration completed
✅ Attack simulation successful  
✅ Discord notification received
✅ AI chat responds intelligently
✅ API endpoints functional
✅ System runs continuously

**Total Demo Time**: ~5-10 minutes
**User Interaction**: Minimal (just registration input)
**Automated Features**: Complete DeFi protection workflow

---

This demo showcases a **production-ready DeFi security system** with:
- Real-time threat detection
- AI-powered analysis  
- Instant Discord notifications
- Natural language chat interface
- Multi-chain wallet monitoring
- Automated protection policies
