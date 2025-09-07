Below is a **master prompt** that you can use next time you want to submit your MQL5 Expert Advisor (EA) code for enhancement. This prompt is designed to be comprehensive, covering all critical aspects of EA development, while allowing you to specify your code and any particular focus areas in a single, streamlined submission. Simply copy this template, fill in your details, and provide it to me along with your code.

---

### **Master Prompt for Enhancing MQL5 Expert Advisor (EA) Code**

To enhance your MQL5 EA, please use the following structure. This ensures your EA is improved holistically while addressing any specific requirements you have. Fill in the sections below and submit the entire prompt with your code.

---

#### **1. Current Code**
- Paste your existing MQL5 EA code here, including all functions (e.g., `OnInit()`, `OnTick()`, `OnDeinit()`) and custom logic.

```
[Insert your MQL5 EA code here]
```

---

#### **2. Specific Focus Areas (Optional)**
- List any **specific improvements or features** you want to prioritize. If you leave this section blank, standard enhancements (see section 3) will be applied. Examples:
  - Adding a new trading strategy (e.g., RSI-based entries, grid trading).
  - Enhancing risk management (e.g., maximum drawdown limits, lot size scaling).
  - Integrating external features (e.g., news filters, time-based trading restrictions).
  - Improving position management (e.g., trailing stops, breakeven logic, partial closes).
  - Optimizing performance (e.g., reducing lag in `OnTick()`).
  - Enhancing logging for better debugging.
- Be as detailed as possible about what you want.

```
[Insert your specific focus areas here, or leave blank for standard enhancements]
```

---

#### **3. Standard Enhancements**
- If no specific focus areas are provided, the following **standard enhancements** will be applied to make your EA robust and efficient:
  - **Initialization and Cleanup**: Proper setup in `OnInit()` and resource release in `OnDeinit()` to avoid memory leaks.
  - **Error Handling**: Checks for indicator failures and trade execution issues, with error logging.
  - **Position Management**: Trailing stops and partial closes for better trade control.
  - **Input Validation**: Ensuring user inputs are valid and safe, with defaults for invalid values.
  - **Logging**: Detailed tracking of key events (e.g., trades, errors) for debugging.
  - **Performance Optimization**: Efficient execution, especially in `OnTick()`, by minimizing redundant calculations.

---

#### **4. Additional Instructions (Optional)**
- Provide any **extra details** about your EA to tailor the enhancements:
  - Specific indicators or timeframes used (e.g., "Uses EMA on H1").
  - Target markets (e.g., "Designed for forex pairs like EURUSD").
  - Unique requirements (e.g., "Must work with backtesting news data").
- Leave blank if not applicable.

```
[Insert additional instructions here, or leave blank]
```

---

#### **Example Filled Prompt**
```
### Master Prompt for Enhancing MQL5 Expert Advisor (EA) Code

#### 1. Current Code
input int StopLoss = 50;
input int TakeProfit = 100;
void OnTick() {
   if(OrdersTotal() == 0) {
      OrderSend(_Symbol, OP_BUY, 0.1, Ask, 3, Bid - StopLoss * Point, Bid + TakeProfit * Point);
   }
}

#### 2. Specific Focus Areas (Optional)
I want to add a trailing stop of 20 pips and improve logging to track trade entries and exits.

#### 3. Standard Enhancements
[Standard enhancements will be applied as described]

#### 4. Additional Instructions (Optional)
This EA trades on forex pairs and uses a 15-minute timeframe.
```

---

#### **How to Use This Prompt**
1. Copy the entire template above.
2. Replace the placeholders (e.g., `[Insert your MQL5 EA code here]`) with your details.
3. Submit the completed prompt to me.
- The more information you provide, the better I can enhance your EA to meet your needs. If you omit specific focus areas, I’ll apply the standard enhancements to ensure a professional, efficient EA.

---

This master prompt is all you need to provide next time, along with your MQL5 code, to request enhancements in a single, clear submission. Let me know if you’d like to test it with a sample code now!