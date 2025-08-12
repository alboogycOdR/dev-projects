I'll create a comprehensive TradingView indicator and strategy for your ORB + ICT hybrid system. This will include all the key components from your document.Now let me create the strategy version with backtesting capabilities:## 📊 ORB + ICT Hybrid Trading System - Complete Solution

I've created two comprehensive Pine Script solutions for your ORB + ICT hybrid trading system:

### **1. Indicator Version (with Alerts & Webhooks)**
The indicator provides full visualization and real-time alerts for:

#### **Core Features:**
- **15-minute Opening Range Box** - Automatically marks the high/low during the first 15 minutes
- **Liquidity Grab Detection** - Identifies false breakouts that sweep stops
- **Market Structure Shift (MSS)** - Confirms directional bias after liquidity grabs
- **Fair Value Gap (FVG) Identification** - Marks imbalance zones for precision entries
- **Entry Signals** - Generated when price taps into FVG after MSS confirmation
- **Real-time Dashboard** - Shows current market state and setup status

#### **Alert System:**
- Liquidity grab alerts (bullish/bearish)
- Market structure shift notifications
- Entry signal alerts with price levels
- Webhook support for automation
- Customizable alert messages with entry, SL, and TP levels

### **2. Strategy Version (with Backtesting)**
The strategy includes all indicator features plus:

#### **Advanced Trade Management:**
- **Automated Position Sizing** - Based on risk percentage per trade
- **Multiple Stop Loss Options:**
  - Liquidity sweep level
  - Opposite ORB boundary
  - 50% of ORB range
  - ATR-based stops
  
- **Profit Taking Features:**
  - Partial take profit (50% at 1R, rest at full target)
  - Move to breakeven functionality
  - Optional trailing stop
  - Customizable risk:reward ratios (1:2 default)

#### **Risk Controls:**
- Maximum trades per day limit
- Date range for backtesting
- Position size based on account equity
- Session-specific trading (NY/London)

### **📈 How the System Works:**

1. **Opening Range Formation** (9:30-9:45 AM for NY)
   - System marks the high and low of the first 15 minutes
   - Creates a visual box showing the range

2. **Liquidity Grab Detection**
   - Watches for price to break above/below ORB
   - Identifies when price reverses back inside (false breakout)
   - This is the "smart money" sweeping retail stops

3. **Market Structure Shift Confirmation**
   - After liquidity grab, looks for break of recent structure
   - Confirms the market is ready to move in opposite direction

4. **FVG Entry Zone**
   - Identifies fair value gaps (price imbalances)
   - Waits for price to retrace into FVG
   - Generates entry signal when price taps the zone

5. **Trade Execution**
   - Enter on FVG tap after MSS
   - Stop loss below/above liquidity sweep
   - Target 1:2 or better risk:reward

### **💡 Key Advantages:**

- **Combines momentum (ORB) with institutional logic (ICT)**
- **Catches reversals after manipulation, not breakout chasing**
- **Multiple confirmation layers reduce false signals**
- **Flexible settings for different market conditions**
- **Full automation capability with webhooks**

### **⚙️ Recommended Settings:**

**For Indices (ES, NQ):**
- Session: New York (9:30-11:30 AM)
- ORB Duration: 15 minutes
- Risk per trade: 1%
- R:R Ratio: 1:2

**For Forex:**
- Session: London (3:00-5:00 AM EST)
- ORB Duration: 30 minutes
- Risk per trade: 0.5-1%
- R:R Ratio: 1:2-3

### **📊 Dashboard Metrics:**
- Current session and ORB levels
- Liquidity grab status
- MSS detection
- Entry signal status
- Win rate and P&L tracking
- Trade count for the day

### **🔔 Alert Integration:**
Both scripts support TradingView alerts that can be connected to:
- Discord/Telegram bots
- Auto-trading platforms via webhooks
- Email/SMS notifications
- Custom automation systems

The system is designed to identify high-probability reversal trades by combining the structure of ORB with the manipulation concepts from ICT, giving you an edge by trading with institutional order flow rather than against it.