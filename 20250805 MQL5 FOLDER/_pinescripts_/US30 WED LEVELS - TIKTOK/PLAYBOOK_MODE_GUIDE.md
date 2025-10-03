# 🎮 **How to Operate Playbook Mode**

A complete guide on how to use the new Playbook Mode feature in the WED, MIDNIGHT & NY PREMARKET DST System v0.9.

## 🔧 Step 1: Enable Playbook Mode

1. **Open the indicator settings** on your chart
2. **Navigate to "Playbook"** section (new dedicated section)
3. **Enable "Enable Playbook Mode"** - Set to `true`

## ⚙️ Step 2: Configure Playbook Settings

### **Essential Settings:**
- **Enable Playbook Mode**: `true` (master switch)
- **Level Proximity Alert**: `0.5 points` (adjustable distance for alerts)
- **Show Session Strategy**: `true` (displays current trading strategy)
- **Show Level Hierarchy**: `true` (shows Tier 1/2/3 classification)

### **Gold Fix Priority Settings:**
- **Gold Fix Priority Mode**: `true` (enhanced visibility for gold fix levels)
- **Gold Fix Line Width**: `4` (thicker lines for gold levels)
- **Gold Fix Alert Priority**: `true` (immediate alerts for gold fix touches)

## 📊 Step 3: Understanding the Visual Indicators

### **🎯 Session Strategy Display:**
The indicator will show colored labels indicating the current trading strategy:
- **Purple**: "ASIAN SESSION - MEAN REVERSION Strategy" (20:00-02:00 EST)
- **Blue**: "LONDON SESSION - BREAKOUT Strategy" (02:00-08:00 EST)
- **Green**: "LONDON/NY OVERLAP - MOMENTUM Strategy" (08:00-11:00 EST)
- **Orange**: "NY SESSION - RANGE FADE Strategy" (11:00-16:00 EST)
- **Gray**: "NY CLOSE - CONSOLIDATION" (16:00-20:00 EST)

### **🏆 Level Hierarchy Labels:**
- **Red Labels**: "TIER 1" (London Gold Fix levels - highest priority)
- **Orange Labels**: "TIER 2" (Asian Physical Open, Tokyo Open)
- **Yellow Labels**: "TIER 3" (Other levels)

## 🚨 Step 4: Alert System

### **Proximity Alerts:**
When price approaches within your set distance (default 0.5 points):
- **Email/Push Notifications**: "🎯 TIER 1 LEVEL APPROACH: 2015.50 (Distance: 0.3)"
- **Visual Indicators**: Color-coded labels appear on chart
- **Cooldown Protection**: 30-second intervals between alerts

### **London Fix Special Alerts:**
During critical windows (10:25-10:35 EST and 14:55-15:05 EST):
- **Special Notifications**: "🔥 LONDON FIX WINDOW ACTIVE - Setup C Brackets Ready"
- **Visual Warnings**: Large red labels on chart
- **Setup C Preparation**: Perfect for bracket orders

## 📈 Step 5: Trading Workflow

### **Daily Preparation (07:45 EST):**
1. **Check Session Strategy**: Look for the colored strategy label
2. **Review Level Hierarchy**: Identify TIER 1 levels (most important)
3. **Set Proximity Alerts**: Adjust distance if needed (0.1-2.0 points)

### **During Trading Sessions:**

#### **Asian Session (20:00-02:00 EST):**
- **Strategy**: MEAN REVERSION
- **Action**: Fade moves beyond 20:00 range
- **Stops**: Tight (1 point)
- **Targets**: Quick (1.5-2 points)

#### **London Session (02:00-08:00 EST):**
- **Strategy**: BREAKOUT
- **Action**: Trade breaks of Asian range
- **Stops**: Wider (2 points)
- **Targets**: 10:30 fix level

#### **London/NY Overlap (08:00-11:00 EST):**
- **Strategy**: MOMENTUM
- **Action**: Trade with trend established at 08:00
- **Targets**: 10:30 as major target/reversal

#### **NY Session (11:00-16:00 EST):**
- **Strategy**: RANGE FADE
- **Action**: Fade extremes back to 10:30/15:00 levels
- **Focus**: Consolidation except news days

## 🎯 Step 6: Key Scenarios to Watch

### **Setup A: "The First Touch Fade"**
- **Trigger**: Price approaches TIER 1 level for first time
- **Entry**: Limit order 0.2 points before level
- **Stop**: 1.5 points beyond level
- **Target**: 2 points or next institutional level

### **Setup B: "The Break and Retest"**
- **Trigger**: Price breaks level by 2+ points, then retests
- **Entry**: Limit order AT the broken level
- **Stop**: 1 point beyond retest wick
- **Target**: Minimum 1:2 Risk/Reward

### **Setup C: "The London Fix Special"**
- **Trigger**: During London Fix windows (10:25-10:35 or 14:55-15:05)
- **Action**: Place bracket orders
- **Buy Stop**: 0.5 above range high
- **Sell Stop**: 0.5 below range low
- **Cancel**: After 5 minutes if unfilled

## 💡 Step 7: Pro Tips

### **Level Priority:**
1. **TIER 1** (Red): London Gold Fix levels - Use 1% risk
2. **TIER 2** (Orange): Asian Physical Open, Tokyo Open - Use 0.75% risk
3. **TIER 3** (Yellow): Other levels - Use 0.5% risk

### **Alert Management:**
- **Adjust Distance**: Start with 0.5 points, adjust based on volatility
- **Session Awareness**: Different strategies for different times
- **London Fix Windows**: Most critical times for gold trading

### **Visual Monitoring:**
- **Watch for Color Changes**: Session strategy updates automatically
- **Level Labels**: TIER classification helps prioritize
- **Proximity Indicators**: Visual warnings before alerts

## 🔄 Step 8: Daily Routine

1. **07:45 EST**: Check Playbook Mode settings, review levels
2. **08:00 EST**: Watch for first major level reaction
3. **10:25 EST**: Prepare for London Fix window
4. **10:30-10:45 EST**: Execute Setup C if triggered
5. **14:55 EST**: Prepare for afternoon London Fix
6. **15:00 EST**: Watch for PM Fix reaction
7. **20:00 EST**: Monitor Asian Physical Open levels

## 🏆 Critical Gold Trading Times

### **Most Important Levels (TIER 1):**
- **10:30 EST**: London Gold Fix Morning (LBMA Morning Fix)
- **15:00 EST**: London Gold Fix Afternoon (LBMA Afternoon Fix)

### **Secondary Levels (TIER 2):**
- **20:00 EST**: Asian Physical Open (Shanghai Gold Exchange)
- **04:00 EST**: Tokyo Open

### **London Fix Windows:**
- **Morning**: 10:25-10:35 EST
- **Afternoon**: 14:55-15:05 EST

## 📊 Example Alert Messages

- `🎯 TIER 1 LEVEL APPROACH: 2015.50 (Distance: 0.3)`
- `🔥 LONDON FIX WINDOW ACTIVE - Setup C Brackets Ready`
- `🎯 TIER 2 LEVEL APPROACH: 2020.25 (Distance: 0.4)`

## ✅ Key Benefits

- **Preserves Existing System**: All current keylevel tracking remains unchanged
- **Semi-Automation**: Automates detection and alerts, keeps decision-making manual
- **Playbook Integration**: Implements the exact playbook scenarios
- **Session Awareness**: Knows which strategy to use when
- **Level Prioritization**: Focuses on most important levels first
- **Time-Based Triggers**: Special alerts for London Fix windows
- **Visual Feedback**: Clear chart indicators for all scenarios

---

The Playbook Mode provides **semi-automated intelligence** while keeping you in full control of execution decisions!
