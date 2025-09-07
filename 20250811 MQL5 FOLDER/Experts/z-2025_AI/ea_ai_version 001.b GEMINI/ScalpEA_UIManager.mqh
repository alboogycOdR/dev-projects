// **7. UI Manager Module**

// *   **Path:** `...\MQL5\Include\ScalpEA\ScalpEA_UIManager.mqh`
// *   **Filename:** `ScalpEA_UIManager.mqh`

// ```mql5
//+------------------------------------------------------------------+
//| ScalpEA_UIManager.mqh                                            |
//| UI Manager Module for Scalp EA                                   |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025"
#property link      "https://www.example.com"
#property strict

// Include required libraries
#include <ChartObjects\ChartObjectsTxtControls.mqh> // For Labels etc.
#include <ChartObjects\ChartObjectsShapes.mqh>     // For RectangleLabel
#include <ChartObjects\ChartObjectsLines.mqh>      // For HLine
#include <Arrays\ArrayString.mqh>
#include <Object.mqh> // Base for CString

// Arrow code constants
#define ARROW_UP_CODE      233  // Up arrow symbol code
#define ARROW_DOWN_CODE    234  // Down arrow symbol code

//--- UI Manager Class
class CUIManager {
private:
   long     m_chartId;           // Chart ID
   string   m_prefix;            // Object prefix
   int      m_fontSize;          // Base font size
   string   m_fontName;          // Font name
   color    m_textColor;         // Text color
   color    m_buyColor;          // Buy signal color
   color    m_sellColor;         // Sell signal color
   color    m_slColor;           // SL line color
   color    m_tpColor;           // TP line color
   color    m_bgColor;           // Panel background color
   color    m_titleColor;        // Panel title color
   bool     m_isInitialized;

   CArrayString m_logMessages;   // Log message storage
   int      m_maxLogMessages;    // Max log lines displayed

   // UI Element Positions/Dimensions
   int      m_panelX, m_panelY, m_panelW, m_panelH;
   int      m_logPanelY, m_logPanelH;
   int      m_analysisX, m_analysisY, m_analysisW, m_analysisH;

   // Using standard Object functions for simplicity now, less dependency
   // CLabel             m_uiTitle; CLabel m_uiStatus; CLabel m_uiLogTitle;
   // CLabel             m_uiLogText; CLabel m_uiAnalysis;
   // CRectangleLabel    m_uiPanel; CRectangleLabel m_uiLogPanel; // etc.

   // Helper to create object names
   string ObjName(string base) { return m_prefix + base; }

   // Cleanup chart objects
   void CleanupChartObjects() { ObjectsDeleteAll(m_chartId, m_prefix); ChartRedraw(m_chartId); }

   // Helper to create or update label text/properties
   bool CreateOrUpdateLabel(string name, string text, int x, int y, color clr, int size, string font = "Arial", ENUM_ANCHOR_POINT anchor = ANCHOR_LEFT_UPPER) {
       if(ObjectFind(m_chartId, name) < 0) { // Create if not exists
           if(!ObjectCreate(m_chartId, name, OBJ_LABEL, 0, 0, 0)) { Print("UI Err: Create Label '",name,"' fail ",GetLastError()); return false; }
           ObjectSetInteger(m_chartId, name, OBJPROP_XDISTANCE, x);
           ObjectSetInteger(m_chartId, name, OBJPROP_YDISTANCE, y);
           ObjectSetInteger(m_chartId, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
           ObjectSetInteger(m_chartId, name, OBJPROP_ANCHOR, anchor);
           ObjectSetInteger(m_chartId, name, OBJPROP_COLOR, clr);
           ObjectSetInteger(m_chartId, name, OBJPROP_FONTSIZE, size);
           ObjectSetString(m_chartId, name, OBJPROP_FONT, font);
           ObjectSetInteger(m_chartId, name, OBJPROP_SELECTABLE, false);
           ObjectSetInteger(m_chartId, name, OBJPROP_HIDDEN, false);
           ObjectSetInteger(m_chartId, name, OBJPROP_ZORDER, 1); // Ensure labels are above panels
       }
       // Always update text description
       ObjectSetString(m_chartId, name, OBJPROP_TEXT, text);
       return true;
   }
   // Helper to create or update rectangle panel
   bool CreateOrUpdatePanel(string name, int x, int y, int w, int h, color bg, color border) {
        if(ObjectFind(m_chartId, name) < 0) { // Create if not exists
           if(!ObjectCreate(m_chartId, name, OBJ_RECTANGLE_LABEL, 0, 0, 0)) { Print("UI Err: Create Panel '",name,"' fail ",GetLastError()); return false; }
           ObjectSetInteger(m_chartId, name, OBJPROP_XDISTANCE, x);
           ObjectSetInteger(m_chartId, name, OBJPROP_YDISTANCE, y);
           ObjectSetInteger(m_chartId, name, OBJPROP_XSIZE, w);
           ObjectSetInteger(m_chartId, name, OBJPROP_YSIZE, h);
           ObjectSetInteger(m_chartId, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
           ObjectSetInteger(m_chartId, name, OBJPROP_BGCOLOR, bg);
           ObjectSetInteger(m_chartId, name, OBJPROP_COLOR, border);
           ObjectSetInteger(m_chartId, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
           ObjectSetInteger(m_chartId, name, OBJPROP_STYLE, STYLE_SOLID);
           ObjectSetInteger(m_chartId, name, OBJPROP_SELECTABLE, false);
           ObjectSetInteger(m_chartId, name, OBJPROP_BACK, true); // Put panel behind text
           ObjectSetInteger(m_chartId, name, OBJPROP_ZORDER, 0);
        }
        // Can update properties here if needed on subsequent calls
        return true;
   }
   // Truncate helper
   string TruncateString(string text, int maxLen) { if(StringLen(text)>maxLen) return StringSubstr(text,0,maxLen-3)+"..."; return text; }

public:
   CUIManager() {
      m_isInitialized = false; m_chartId = ChartID(); m_prefix = "ScalpEA_" + (string)m_chartId + "_";
      m_fontSize = 9; m_fontName = "Segoe UI"; m_textColor = clrWhite;
      m_buyColor = clrLimeGreen; m_sellColor = clrTomato; m_slColor = clrOrangeRed; m_tpColor = clrDodgerBlue;
      m_bgColor = C'30,30,30'; m_titleColor = clrGoldenrod; m_maxLogMessages = 8; // Adjust as needed
      m_panelX = 5; m_panelY = 25; m_panelW = 210; m_panelH = 80; // Adjust dimensions
      m_logPanelY = m_panelY + m_panelH + 5; m_logPanelH = 100;
      m_analysisX = m_panelX + m_panelW + 5; m_analysisY = m_panelY; m_analysisW = 300; m_analysisH = m_panelH + m_logPanelH + 5; // Full height
   }
   ~CUIManager() { if (m_isInitialized) CleanupChartObjects(); m_logMessages.Clear(); }

   // Initialize the UI
   bool Initialize() {
       CleanupChartObjects(); m_logMessages.Clear();
       // Status Panel
       if(!CreateOrUpdatePanel(ObjName("StatusPanel"), m_panelX, m_panelY, m_panelW, m_panelH, m_bgColor, clrDimGray)) return false;
       if(!CreateOrUpdateLabel(ObjName("Title"), "ScalpEA AI", m_panelX+5, m_panelY+5, m_titleColor, m_fontSize+1, m_fontName)) return false;
       if(!CreateOrUpdateLabel(ObjName("StatusText"), "Initializing...", m_panelX+5, m_panelY+25, m_textColor, m_fontSize, m_fontName)) return false;
       // Log Panel
       if(!CreateOrUpdatePanel(ObjName("LogPanel"), m_panelX, m_logPanelY, m_panelW, m_logPanelH, m_bgColor, clrDimGray)) return false;
       if(!CreateOrUpdateLabel(ObjName("LogTitle"), "Log:", m_panelX+5, m_logPanelY+5, m_titleColor, m_fontSize, m_fontName)) return false;
       if(!CreateOrUpdateLabel(ObjName("LogText"), "Log Initialized.", m_panelX+5, m_logPanelY+20, m_textColor, m_fontSize-1, m_fontName)) return false;
       // Analysis Panel (initially empty)
       if(!CreateOrUpdatePanel(ObjName("AnalysisPanel"), m_analysisX, m_analysisY, m_analysisW, m_analysisH, m_bgColor, clrDimGray)) return false;
       if(!CreateOrUpdateLabel(ObjName("AnalysisText"), "", m_analysisX+5, m_analysisY+5, m_textColor, m_fontSize-1, m_fontName)) return false; // Starts empty
       m_isInitialized = true; ChartRedraw(m_chartId); // Print("UI Manager Initialized.");
       return true;
   }

   // Update dashboard text
   void UpdateDashboard(string mode, string model, int openTrades, int maxTrades, double profit, int errorCount) {
      if (!m_isInitialized) return;
      string status = StringFormat("Mode: %s\nModel: %s\nTrades: %d/%d\nP/L: %.2f\nErrors: %d",
                                   mode, TruncateString(model, 25), openTrades, maxTrades, profit, errorCount);
      CreateOrUpdateLabel(ObjName("StatusText"), status, m_panelX+5, m_panelY+25, m_textColor, m_fontSize, m_fontName);
      // Note: Log display is updated by LogTradeAction
      ChartRedraw(m_chartId); // Consider less frequent redraws if performance issues arise
   }

   // Log message to UI panel
   void LogTradeAction(string message, bool printToJournal = true) {
       if (!m_isInitialized) return;
       string timestamp = TimeToString(TimeCurrent(), TIME_SECONDS); string logMsg = timestamp + ": " + message;
       m_logMessages.Insert(logMsg, 0); // Insert newest at the beginning
       while (m_logMessages.Total() > m_maxLogMessages) m_logMessages.Delete(m_logMessages.Total()-1); // Remove oldest
       string logText = ""; int numToShow = MathMin(m_logMessages.Total(), m_maxLogMessages);
       for(int i=0; i<numToShow; i++) logText += m_logMessages.At(i) + "\n";
       CreateOrUpdateLabel(ObjName("LogText"), logText, m_panelX+5, m_logPanelY+20, m_textColor, m_fontSize-1, m_fontName);
       if (printToJournal) Print(message);
       ChartRedraw(m_chartId);
   }

   // Draw signal arrow
   void DrawSignal(string direction, double price) {
       if (!m_isInitialized || price <= 0) return;
       string sigName = m_prefix+"Sig_"+TimeToString(TimeCurrent(),TIME_SECONDS)+(string)MathRand(); // Unique name
       if(!ObjectCreate(m_chartId, sigName, OBJ_ARROW, 0, TimeCurrent(), price)) { Print("UI Err: Create Arrow fail ",GetLastError()); return; }
       color clr=clrGray; int code=0;
       if(direction=="BUY"){code=ARROW_UP_CODE;clr=m_buyColor;} else if(direction=="SELL"){code=ARROW_DOWN_CODE;clr=m_sellColor;} else{ObjectDelete(m_chartId,sigName);return;}
       ObjectSetInteger(m_chartId,sigName,OBJPROP_ARROWCODE,code); ObjectSetInteger(m_chartId,sigName,OBJPROP_COLOR,clr);
       ObjectSetInteger(m_chartId,sigName,OBJPROP_WIDTH,1); ObjectSetInteger(m_chartId,sigName,OBJPROP_SELECTABLE,false); ObjectSetInteger(m_chartId,sigName,OBJPROP_BACK,false);
       ChartRedraw(m_chartId);
   }

   // Draw SL/TP lines
   void DrawTradeLevels(ulong ticket, double entryPrice, double stopLoss, double takeProfit) {
      if (!m_isInitialized || ticket == 0) return;
      string slName=m_prefix+"SL_"+(string)ticket; string tpName=m_prefix+"TP_"+(string)ticket;
      ObjectDelete(m_chartId,slName); ObjectDelete(m_chartId,tpName); // Delete previous first

      if (stopLoss > 0) { if(ObjectCreate(m_chartId,slName,OBJ_HLINE,0,0,stopLoss)){ ObjectSetInteger(m_chartId,slName,OBJPROP_COLOR,m_slColor); ObjectSetInteger(m_chartId,slName,OBJPROP_STYLE,STYLE_DOT); ObjectSetInteger(m_chartId,slName,OBJPROP_WIDTH,1); ObjectSetString(m_chartId,slName,OBJPROP_TEXT," SL "+(string)ticket); ObjectSetInteger(m_chartId,slName,OBJPROP_SELECTABLE,false); ObjectSetInteger(m_chartId,slName,OBJPROP_BACK,true); } else { /* Print("UI Err: Create SL Line fail ",GetLastError()); */ } }
      if (takeProfit > 0) { if(ObjectCreate(m_chartId,tpName,OBJ_HLINE,0,0,takeProfit)){ ObjectSetInteger(m_chartId,tpName,OBJPROP_COLOR,m_tpColor); ObjectSetInteger(m_chartId,tpName,OBJPROP_STYLE,STYLE_DOT); ObjectSetInteger(m_chartId,tpName,OBJPROP_WIDTH,1); ObjectSetString(m_chartId,tpName,OBJPROP_TEXT," TP "+(string)ticket); ObjectSetInteger(m_chartId,tpName,OBJPROP_SELECTABLE,false); ObjectSetInteger(m_chartId,tpName,OBJPROP_BACK,true); } else { /* Print("UI Err: Create TP Line fail ",GetLastError()); */ } }
      ChartRedraw(m_chartId);
   }

   // Remove SL/TP lines for a closed/deleted trade
   void RemoveTradeLevels(ulong ticket) {
      if (!m_isInitialized || ticket == 0) return;
      ObjectDelete(m_chartId, m_prefix+"SL_"+(string)ticket); ObjectDelete(m_chartId, m_prefix+"TP_"+(string)ticket);
      ChartRedraw(m_chartId);
   }

   // Display AI analysis text
   void DisplayAIAnalysis(string analysis) {
      if (!m_isInitialized) return;
      string text="AI Analysis ("+TimeToString(TimeCurrent(),TIME_SECONDS)+"):\n"+TruncateString(analysis,800); // Limit length displayed
      CreateOrUpdateLabel(ObjName("AnalysisText"), text, m_analysisX+5, m_analysisY+5, m_textColor, m_fontSize-1, m_fontName);
      ChartRedraw(m_chartId);
   }

   // Simulate confirmation - logs message, always returns true
   bool ConfirmTrade(string direction, double entryPrice, double stopLoss, double takeProfit) {
      if (!m_isInitialized) return false;
      string msg = StringFormat("CONFIRM? %s @ %.4f SL=%.4f TP=%.4f", direction, entryPrice, stopLoss, takeProfit);
      LogTradeAction(msg, true); // Log to UI and Journal
      // In real Hybrid mode, would need UI interaction. For now, auto-confirm.
      return true;
   }

   // Process chart events (basic placeholder)
   void ProcessChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam) {
       if (!m_isInitialized) return;
       // if(id==CHARTEVENT_OBJECT_CLICK) { /* Handle clicks on future buttons */ }
   }
};
//+------------------------------------------------------------------+