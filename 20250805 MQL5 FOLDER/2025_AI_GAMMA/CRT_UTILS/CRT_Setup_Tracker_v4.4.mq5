//+------------------------------------------------------------------+
//|                    CRT_Setup_Tracker_v4.3.mq5                    |
//|              Fixes, Optimisations + Bias & Entry Alerts          |
//+------------------------------------------------------------------+
#property copyright "v4.4 – The Synthesis"
#property link      "https://beta.character.ai/"
#property version   "4.40"
#property description "Scanner only – adds GMT-aware CRT hour, de-duplicated assets, alerts."

#include <ChartObjects\ChartObjectsTxtControls.mqh>

//--- ENUMS ----------------------------------------------------------
enum ENUM_SETUP_STATE { IDLE, SWEEP, MSS, FVG, ENTRY, INVALID };
enum ENUM_BIAS        { NEUTRAL, BULLISH, BEARISH };
enum ENUM_POSITION    { POS_TOP_RIGHT, POS_TOP_LEFT, POS_MIDDLE_RIGHT,
                        POS_MIDDLE_LEFT, POS_BOTTOM_RIGHT, POS_BOTTOM_LEFT };
enum ENUM_THEME       { THEME_DARK, THEME_LIGHT, THEME_BLUEPRINT };

//--- STRUCTS --------------------------------------------------------
struct SymbolState
{
   string           symbol_name;
   ENUM_SETUP_STATE bull_state;
   ENUM_SETUP_STATE bear_state;
   double           crt_high;
   double           crt_low;
   double           mss_level;
   double           fvg_high;
   double           fvg_low;
   ENUM_BIAS        h4_bias;
   ENUM_BIAS        h4_bias_prev;      // cached for alert
   ENUM_SETUP_STATE bull_prev;         // cached for alert
   ENUM_SETUP_STATE bear_prev;         // cached for alert
};

//--- INPUTS ---------------------------------------------------------
input group "Asset Configuration"
 
input string        s1 = "EURUSD", s2 = "GBPUSD", s3 = "USDJPY", s4 = "USDCHF", s5 = "USDCAD", s6 = "AUDUSD", s7 = "NZDUSD", s8 = "EURGBP";
input string        s9 = "EURJPY", s10= "EURCHF", s11="EURAUD", s12="GBPJPY", s13="GBPCHF", s14="AUDJPY", s15="CHFJPY", s16="CADJPY";
input group "CRT Session Settings"
input int    CRT_Hour = 8;            // Hour (broker time) that defines CRT range
input int    Broker_GMT_Offset = 3;   // GMT offset of broker server (auto-detect if 0)

input group "Visual & Alerts"
input ENUM_THEME   i_theme = THEME_LIGHT;
input ENUM_POSITION i_table_pos = POS_TOP_RIGHT;
input int           i_update_interval_sec = 60;
input bool          Alert_Entry = false;      // ENTRY state alert
input bool          Alert_Bias  = false;      // New daily bias alert

//--- GLOBALS --------------------------------------------------------
SymbolState symbol_states[16];
string      object_prefix = "CRT_V43_";
color       c_bg, c_header, c_text, c_bull, c_bear, c_neutral,
            c_sweep, c_mss, c_entry;
string      icon_up="▲", icon_dn="▼", icon_sd="↔", icon_none="—";

//--- CHART SETTINGS BACKUP ------------------------------------------
struct ChartCfg {
   bool  ohlc, grid, vol, pscale, dscale, bid, ask;
   color bull, bear, up, dn, fg, gridc, volc;
} orig;

//+------------------------------------------------------------------+
//| INIT                                                             |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("CRT v4.3 Initialising…");
   string syms[16]= {s1,s2,s3,s4,s5,s6,s7,s8,s9,s10,s11,s12,s13,s14,s15,s16};
   for(int i=0;i<16;i++)
   {
      symbol_states[i].symbol_name = syms[i];
      ResetSymbolState(i);
   }
   SetThemeColors();
   HideChart();
   CreateDashboard();
   EventSetTimer(i_update_interval_sec);
   return INIT_SUCCEEDED;
}
//+------------------------------------------------------------------+
//| DEINIT                                                           |
//+------------------------------------------------------------------+
void OnDeinit(const int r)
{
   Print("CRT v4.3 Deinitialising…");
   RestoreChart();
   EventKillTimer();
   ObjectsDeleteAll(0,object_prefix);
}
//+------------------------------------------------------------------+
//| TIMER                                                            |
//+------------------------------------------------------------------+
void OnTimer()
{
   static datetime last_day=0;
   datetime now=TimeCurrent();
   MqlDateTime t; TimeToStruct(now,t);

   if(last_day!=t.day_of_year || last_day==0)
   {
      //Print("New day detected – resetting states.");
      for(int i=0;i<16;i++) ResetSymbolState(i);
      last_day=t.day_of_year;
   }

   for(int i=0;i<16;i++) UpdateSymbolState(i);
   UpdateDashboard();
}
//+------------------------------------------------------------------+
//| CORE ENGINE                                                      |
//+------------------------------------------------------------------+
void UpdateSymbolState(int idx)
{
   string sym = symbol_states[idx].symbol_name;
   if(!SymbolInfoInteger(sym,SYMBOL_SELECT)) return;   // skip invalid

   //--- PHASE 1 : once per day --------------------------------------
   if(symbol_states[idx].crt_high==0)
   {
      // H4 bias
      MqlRates h4[]; ArraySetAsSeries(h4,true);
      if(CopyRates(sym,PERIOD_H4,0,3,h4)==3)
      {
         double c0h=h4[0].high, c0l=h4[0].low, c0c=h4[0].close;
         double c1h=h4[1].high, c1l=h4[1].low;

         ENUM_BIAS newBias=NEUTRAL;
         if(c0h>c1h && c0l<c1l) newBias=NEUTRAL;
         else if(c0h>c1h && c0c<=c1h) newBias=BEARISH;
         else if(c0l<c1l && c0c>=c1l) newBias=BULLISH;

         if (newBias != NEUTRAL)
         {
             PrintFormat("%s BIAS DETECTED: %s is %s", TimeToString(h4[0].time), sym, EnumToString(newBias));
         }

         // Bias change alert
         if(Alert_Bias && symbol_states[idx].h4_bias_prev!=NEUTRAL && newBias!=symbol_states[idx].h4_bias_prev)
         {
            Alert("CRT-BIAS CHANGE: ",sym," flipped to ",EnumToString(newBias));
            PlaySound("alert.wav");
         }
         symbol_states[idx].h4_bias      = newBias;
         symbol_states[idx].h4_bias_prev = newBias;
      }

      // CRT range (GMT-aware)
      MqlRates h1[]; ArraySetAsSeries(h1,true);
      if(CopyRates(sym,PERIOD_H1,0,24,h1)>=8)
      {
         int crt = (CRT_Hour + (Broker_GMT_Offset==0 ? (int)TimeGMTOffset() : Broker_GMT_Offset)) % 24;
         for(int i=0;i<ArraySize(h1);i++)
         {
            MqlDateTime tm; TimeToStruct(h1[i].time,tm);
            if(tm.hour==crt)
            {
               symbol_states[idx].crt_high=h1[i].high;
               symbol_states[idx].crt_low =h1[i].low;
               break;
            }
         }
      }
      if(symbol_states[idx].crt_high==0) return;
   }

   //--- PHASE 2 : M15 state machine ---------------------------------
   MqlRates m15[]; ArraySetAsSeries(m15,true);
   if(CopyRates(sym,PERIOD_M15,0,25,m15)<3) return;

   ENUM_SETUP_STATE currentState;
   if(symbol_states[idx].h4_bias==BULLISH)      currentState = symbol_states[idx].bull_state;
   else if(symbol_states[idx].h4_bias==BEARISH) currentState = symbol_states[idx].bear_state;
   else return;

   ENUM_SETUP_STATE prev = currentState;

   switch(currentState)
   {
      case IDLE:
         if(symbol_states[idx].h4_bias==BULLISH && m15[0].low<symbol_states[idx].crt_low)
         {
            symbol_states[idx].mss_level=FindSwing(m15,true);
            if(symbol_states[idx].mss_level>0) currentState=SWEEP;
         }
         else if(symbol_states[idx].h4_bias==BEARISH && m15[0].high>symbol_states[idx].crt_high)
         {
            symbol_states[idx].mss_level=FindSwing(m15,false);
            if(symbol_states[idx].mss_level>0) currentState=SWEEP;
         }
         break;

      case SWEEP:
         if(symbol_states[idx].h4_bias==BULLISH && m15[0].high>symbol_states[idx].mss_level) currentState=MSS;
         else if(symbol_states[idx].h4_bias==BEARISH && m15[0].low<symbol_states[idx].mss_level) currentState=MSS;
         break;

      case MSS:
         if(FindFVG(m15,idx,symbol_states[idx].h4_bias==BULLISH)) currentState=FVG;
         break;

      case FVG:
         if(symbol_states[idx].h4_bias==BULLISH && m15[0].low<symbol_states[idx].fvg_high) currentState=ENTRY;
         else if(symbol_states[idx].h4_bias==BEARISH && m15[0].high>symbol_states[idx].fvg_low) currentState=ENTRY;
         break;
   }

   if (currentState != prev)
   {
      string timestamp = TimeToString(m15[0].time);
      string biasStr = EnumToString(symbol_states[idx].h4_bias);
      int digits = (int)SymbolInfoInteger(sym, SYMBOL_DIGITS);

      switch(currentState)
      {
         case SWEEP:
            PrintFormat("%s M15-%s (%s): SWEEP of CRT liquidity detected. MSS Level target: %s",
                        timestamp, sym, biasStr, DoubleToString(symbol_states[idx].mss_level, digits));
            break;
         case MSS:
            PrintFormat("%s M15-%s (%s): MSS confirmed by breaking swing level %s.",
                        timestamp, sym, biasStr, DoubleToString(symbol_states[idx].mss_level, digits));
            break;
         case FVG:
            PrintFormat("%s M15-%s (%s): FVG created. Range: %s - %s.",
                        timestamp, sym, biasStr,
                        DoubleToString(symbol_states[idx].fvg_low, digits),
                        DoubleToString(symbol_states[idx].fvg_high, digits));
            break;
         case ENTRY:
            PrintFormat("%s M15-%s (%s): ENTRY condition met. Price has tapped into FVG.",
                        timestamp, sym, biasStr);
            break;
      }
   }

   if(symbol_states[idx].h4_bias==BULLISH)      symbol_states[idx].bull_state = currentState;
   else if(symbol_states[idx].h4_bias==BEARISH) symbol_states[idx].bear_state = currentState;

   // ENTRY alert
   if(Alert_Entry && currentState==ENTRY && prev!=ENTRY)
   {
      Alert("CRT-ENTRY: ",sym," ready for ",EnumToString(symbol_states[idx].h4_bias));
      PlaySound("alert.wav");
   }
}
//+------------------------------------------------------------------+
//| RESET SYMBOL STATE                                               |
//+------------------------------------------------------------------+
void ResetSymbolState(int idx)
{
   symbol_states[idx].bull_state   = IDLE;
   symbol_states[idx].bear_state   = IDLE;
   symbol_states[idx].crt_high     = 0;
   symbol_states[idx].crt_low      = 0;
   symbol_states[idx].h4_bias      = NEUTRAL;
   symbol_states[idx].h4_bias_prev = NEUTRAL;
   symbol_states[idx].bull_prev    = IDLE;
   symbol_states[idx].bear_prev    = IDLE;
}
//+------------------------------------------------------------------+
//| SWING & FVG HELPERS                                              |
//+------------------------------------------------------------------+
double FindSwing(const MqlRates &r[], bool wantHigh)
{
   for(int i=2;i<ArraySize(r)-1;i++)
   {
      if(wantHigh && r[i].high>r[i-1].high && r[i].high>r[i+1].high) return r[i].high;
      if(!wantHigh && r[i].low<r[i-1].low && r[i].low<r[i+1].low) return r[i].low;
   }
   return 0;
}
bool FindFVG(const MqlRates &r[], int idx, bool bull)
{
   for(int i=2;i<ArraySize(r);i++)
   {
      if(bull && r[i-2].high<r[i].low)
      {
         symbol_states[idx].fvg_high=r[i-2].high;
         symbol_states[idx].fvg_low =r[i].low;
         return true;
      }
      if(!bull && r[i-2].low>r[i].high)
      {
         symbol_states[idx].fvg_high=r[i].high;
         symbol_states[idx].fvg_low =r[i-2].low;
         return true;
      }
   }
   return false;
}
//+------------------------------------------------------------------+
//| CHART CLEANUP / RESTORE                                          |
//+------------------------------------------------------------------+
void HideChart()
{
   long v; color bg=clrBlack;
   ChartGetInteger(0,CHART_COLOR_BACKGROUND,0,v); bg=(color)v;
   // Save originals
   ChartGetInteger(0,CHART_SHOW_OHLC,0,v); orig.ohlc=(bool)v;
   ChartGetInteger(0,CHART_SHOW_GRID,0,v); orig.grid=(bool)v;
   ChartGetInteger(0,CHART_SHOW_VOLUMES,0,v); orig.vol=(bool)v;
   ChartGetInteger(0,CHART_SHOW_PRICE_SCALE,0,v); orig.pscale=(bool)v;
   ChartGetInteger(0,CHART_SHOW_DATE_SCALE,0,v); orig.dscale=(bool)v;
   ChartGetInteger(0,CHART_SHOW_BID_LINE,0,v); orig.bid=(bool)v;
   ChartGetInteger(0,CHART_SHOW_ASK_LINE,0,v); orig.ask=(bool)v;
   ChartGetInteger(0,CHART_COLOR_CANDLE_BULL,0,v); orig.bull=(color)v;
   ChartGetInteger(0,CHART_COLOR_CANDLE_BEAR,0,v); orig.bear=(color)v;
   ChartGetInteger(0,CHART_COLOR_CHART_UP,0,v); orig.up=(color)v;
   ChartGetInteger(0,CHART_COLOR_CHART_DOWN,0,v); orig.dn=(color)v;
   ChartGetInteger(0,CHART_COLOR_FOREGROUND,0,v); orig.fg=(color)v;
   ChartGetInteger(0,CHART_COLOR_GRID,0,v); orig.gridc=(color)v;
   ChartGetInteger(0,CHART_COLOR_VOLUME,0,v); orig.volc=(color)v;

   // Hide
   ChartSetInteger(0,CHART_COLOR_CANDLE_BULL,bg);
   ChartSetInteger(0,CHART_COLOR_CANDLE_BEAR,bg);
   ChartSetInteger(0,CHART_COLOR_CHART_UP,bg);
   ChartSetInteger(0,CHART_COLOR_CHART_DOWN,bg);
   ChartSetInteger(0,CHART_COLOR_FOREGROUND,bg);
   ChartSetInteger(0,CHART_COLOR_GRID,bg);
   ChartSetInteger(0,CHART_COLOR_VOLUME,bg);
   ChartSetInteger(0,CHART_SHOW_OHLC,false);
   ChartSetInteger(0,CHART_SHOW_GRID,false);
   ChartSetInteger(0,CHART_SHOW_VOLUMES,false);
   ChartSetInteger(0,CHART_SHOW_PRICE_SCALE,false);
   ChartSetInteger(0,CHART_SHOW_DATE_SCALE,false);
   ChartSetInteger(0,CHART_SHOW_BID_LINE,false);
   ChartSetInteger(0,CHART_SHOW_ASK_LINE,false);
}
void RestoreChart()
{
   ChartSetInteger(0,CHART_SHOW_OHLC,orig.ohlc);
   ChartSetInteger(0,CHART_SHOW_GRID,orig.grid);
   ChartSetInteger(0,CHART_SHOW_VOLUMES,orig.vol);
   ChartSetInteger(0,CHART_SHOW_PRICE_SCALE,orig.pscale);
   ChartSetInteger(0,CHART_SHOW_DATE_SCALE,orig.dscale);
   ChartSetInteger(0,CHART_SHOW_BID_LINE,orig.bid);
   ChartSetInteger(0,CHART_SHOW_ASK_LINE,orig.ask);
   ChartSetInteger(0,CHART_COLOR_CANDLE_BULL,orig.bull);
   ChartSetInteger(0,CHART_COLOR_CANDLE_BEAR,orig.bear);
   ChartSetInteger(0,CHART_COLOR_CHART_UP,orig.up);
   ChartSetInteger(0,CHART_COLOR_CHART_DOWN,orig.dn);
   ChartSetInteger(0,CHART_COLOR_FOREGROUND,orig.fg);
   ChartSetInteger(0,CHART_COLOR_GRID,orig.gridc);
   ChartSetInteger(0,CHART_COLOR_VOLUME,orig.volc);
}
//+------------------------------------------------------------------+
//| THEME & DASHBOARD                                                |
//+------------------------------------------------------------------+
void SetThemeColors()
{
   switch(i_theme)
   {
      case THEME_LIGHT:
         c_bg=clrWhiteSmoke; c_header=clrBlack; c_text=clrBlack;
         c_bull=C'38,166,154'; c_bear=C'239,83,80'; c_neutral=C'67,70,81';
         c_sweep=clrDarkOrange; c_mss=clrDodgerBlue; c_entry=C'0,128,0'; break;
      case THEME_BLUEPRINT:
         c_bg=C'42,52,73'; c_header=C'247,201,117'; c_text=C'224,227,235';
         c_bull=clrAqua; c_bear=clrFuchsia; c_neutral=clrSlateGray;
         c_sweep=clrGold; c_mss=clrAqua; c_entry=clrLime; break;
      default:
         c_bg=C'30,34,45'; c_header=C'224,227,235'; c_text=C'200,200,200';
         c_bull=C'38,166,154'; c_bear=C'220,20,60'; c_neutral=clrGray;
         c_sweep=clrGold; c_mss=clrAqua; c_entry=clrLime; break;
   }
}
void CreateDashboard()
{
   int base=150, top=80, wA=100, wB=60, wS=80, h=30, pad=15;
   ENUM_BASE_CORNER corner=GetCornerFromPos(i_table_pos);
   int W=(wA+wB+wS)*2+pad, H=h*9+30;
   CreateRect(object_prefix+"BG", base-5,top-10,W+10,H,c_bg,corner);

   int x1A=base, x1B=x1A+wA, x1S=x1B+wB;
   int x2A=x1S+wS+pad, x2B=x2A+wA, x2S=x2B+wB;

   CreateText(object_prefix+"H1","Asset",x1A,top,c_header,8,corner,ANCHOR_LEFT);
   CreateText(object_prefix+"H2","Bias", x1B,top,c_header,8,corner,ANCHOR_LEFT);
   CreateText(object_prefix+"H3","M15",  x1S,top,c_header,8,corner,ANCHOR_LEFT);
   CreateText(object_prefix+"H4","Asset",x2A,top,c_header,8,corner,ANCHOR_LEFT);
   CreateText(object_prefix+"H5","Bias", x2B,top,c_header,8,corner,ANCHOR_LEFT);
   CreateText(object_prefix+"H6","M15",  x2S,top,c_header,8,corner,ANCHOR_LEFT);

   for(int i=0;i<16;i++)
   {
      int y=top+((i%8)+1)*h;
      int xA=(i<8)?x1A:x2A, xB=(i<8)?x1B:x2B, xS=(i<8)?x1S:x2S;
      CreateText(object_prefix+"Sym_"+i,"",xA+5,y,c_text,8,corner,ANCHOR_LEFT);
      CreateText(object_prefix+"Bias_"+i,"—",xB+20,y,c_text,10,corner,ANCHOR_CENTER);
      CreateText(object_prefix+"Status_"+i,"",xS+5,y,c_text,8,corner,ANCHOR_LEFT);
   }
}
void UpdateDashboard()
{
   static string prev[16][3];   // cache to avoid flicker
   for(int i=0;i<16;i++)
   {
      string sym=symbol_states[i].symbol_name;
      ENUM_BIAS b=symbol_states[i].h4_bias;
      string ico=(b==BULLISH)?icon_up:(b==BEARISH)?icon_dn:(b==NEUTRAL)?icon_sd:icon_none;
      color col=(b==BULLISH)?c_bull:(b==BEARISH)?c_bear:c_neutral;

      string stxt="Idle"; color scol=c_text;
      if(b==BULLISH && symbol_states[i].bull_state!=IDLE)
      {
         stxt=EnumToString(symbol_states[i].bull_state);
         scol=(symbol_states[i].bull_state==ENTRY)?c_entry:(symbol_states[i].bull_state==MSS)?c_mss:c_sweep;
      }
      else if(b==BEARISH && symbol_states[i].bear_state!=IDLE)
      {
         stxt=EnumToString(symbol_states[i].bear_state);
         scol=(symbol_states[i].bear_state==ENTRY)?c_entry:(symbol_states[i].bear_state==MSS)?c_mss:c_sweep;
      }
      // Update only if changed
      if(prev[i][0]!=sym){ObjectSetString(0,object_prefix+"Sym_"+i,OBJPROP_TEXT,sym); prev[i][0]=sym;}
      if(prev[i][1]!=ico){ObjectSetString(0,object_prefix+"Bias_"+i,OBJPROP_TEXT,ico); ObjectSetInteger(0,object_prefix+"Bias_"+i,OBJPROP_COLOR,(long)col); prev[i][1]=ico;}
      if(prev[i][2]!=stxt){ObjectSetString(0,object_prefix+"Status_"+i,OBJPROP_TEXT,stxt); ObjectSetInteger(0,object_prefix+"Status_"+i,OBJPROP_COLOR,(long)scol); prev[i][2]=stxt;}
   }
}
//--- UI HELPERS -----------------------------------------------------
ENUM_BASE_CORNER GetCornerFromPos(ENUM_POSITION p)
{
   switch(p){
      case POS_TOP_LEFT:     return CORNER_LEFT_UPPER;
      case POS_BOTTOM_LEFT:  return CORNER_LEFT_LOWER;
      case POS_BOTTOM_RIGHT: return CORNER_RIGHT_LOWER;
      default:               return CORNER_RIGHT_UPPER;
   }
}
void CreateRect(string n,int x,int y,int w,int h,color clr,ENUM_BASE_CORNER c)
{
   if(ObjectCreate(0,n,OBJ_RECTANGLE_LABEL,0,0,0))
   {
      ObjectSetInteger(0,n,OBJPROP_CORNER,(long)c);
      ObjectSetInteger(0,n,OBJPROP_XDISTANCE,x);
      ObjectSetInteger(0,n,OBJPROP_YDISTANCE,y);
      ObjectSetInteger(0,n,OBJPROP_XSIZE,w);
      ObjectSetInteger(0,n,OBJPROP_YSIZE,h);
      ObjectSetInteger(0,n,OBJPROP_BGCOLOR,(long)clr);
      ObjectSetInteger(0,n,OBJPROP_BORDER_TYPE,BORDER_FLAT);
      ObjectSetInteger(0,n,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,n,OBJPROP_BACK,true);
   }
}
void CreateText(string n,string txt,int x,int y,color clr,int fs,ENUM_BASE_CORNER c,ENUM_ANCHOR_POINT a=ANCHOR_LEFT)
{
   if(ObjectCreate(0,n,OBJ_LABEL,0,0,0))
   {
      ObjectSetInteger(0,n,OBJPROP_CORNER,(long)c);
      ObjectSetInteger(0,n,OBJPROP_XDISTANCE,x);
      ObjectSetInteger(0,n,OBJPROP_YDISTANCE,y);
      ObjectSetString(0,n,OBJPROP_TEXT,txt);
      ObjectSetInteger(0,n,OBJPROP_COLOR,(long)clr);
      ObjectSetString(0,n,OBJPROP_FONT,"Calibri");
      ObjectSetInteger(0,n,OBJPROP_FONTSIZE,fs);
      ObjectSetInteger(0,n,OBJPROP_ANCHOR,(long)a);
      ObjectSetInteger(0,n,OBJPROP_SELECTABLE,false);
   }
}
//+------------------------------------------------------------------+