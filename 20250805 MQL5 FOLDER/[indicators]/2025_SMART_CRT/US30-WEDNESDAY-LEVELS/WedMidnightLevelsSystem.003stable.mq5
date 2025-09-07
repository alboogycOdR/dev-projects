//+------------------------------------------------------------------+
//|                                     WedMidnightLevelsSystem.mq5  |
//|                      Copyright 2023, Custom MQL5 Development     |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, Custom MQL5 Development"
#property link      ""
#property version   "1.10"
#property indicator_chart_window
#property indicator_buffers 0
#property indicator_plots   0

#include <Arrays\ArrayObj.mqh>

//+------------------------------------------------------------------+
//| Input Parameters                                                 |
//+------------------------------------------------------------------+
// --- Alerts ---
input group           "Alerts"
input bool            InpSendAlert = false;         // Enable Terminal Alerts
input bool            InpSendEmail = false;         // Send Email
input bool            InpSendPush = false;          // Send Push Notification
input int             InpAlertCooldown = 30;        // Cooldown (seconds)

// --- Wednesday SAST Lines ---
input group           "Wednesday SAST Lines (UTC+2)"
input bool            InpShowWednesdays = true;     // Show Wednesday High/Low Lines
input bool            InpShowWednesdayOpen = false; // Show Wednesday Open Line

// 1st Wednesday
input bool            InpShowW1 = false;            // Show 1st Wednesday
input color           InpHiC1 = clrIndianRed;       //   High Color
input int             InpHiW1 = 2;                  //   High Width
input color           InpLoC1 = clrSteelBlue;       //   Low Color
input int             InpLoW1 = 2;                  //   Low Width
input color           InpOpC1 = clrGray;            //   Open Color
input int             InpOpW1 = 2;                  //   Open Width

// 2nd Wednesday
input bool            InpShowW2 = false;            // Show 2nd Wednesday
input color           InpHiC2 = clrIndianRed;       //   High Color
input int             InpHiW2 = 2;                  //   High Width
input color           InpLoC2 = clrSteelBlue;       //   Low Color
input int             InpLoW2 = 2;                  //   Low Width
input color           InpOpC2 = clrGray;            //   Open Color
input int             InpOpW2 = 2;                  //   Open Width

// 3rd Wednesday
input bool            InpShowW3 = true;             // Show 3rd Wednesday
input color           InpHiC3 = clrIndianRed;       //   High Color
input int             InpHiW3 = 2;                  //   High Width
input color           InpLoC3 = clrSteelBlue;       //   Low Color
input int             InpLoW3 = 2;                  //   Low Width
input color           InpOpC3 = clrGray;            //   Open Color
input int             InpOpW3 = 2;                  //   Open Width

// 4th Wednesday
input bool            InpShowW4 = true;             // Show 4th Wednesday
input color           InpHiC4 = clrIndianRed;       //   High Color
input int             InpHiW4 = 2;                  //   High Width
input color           InpLoC4 = clrSteelBlue;       //   Low Color
input int             InpLoW4 = 2;                  //   Low Width
input color           InpOpC4 = clrGray;            //   Open Color
input int             InpOpW4 = 2;                  //   Open Width

// 5th Wednesday
input bool            InpShowW5 = false;            // Show 5th Wednesday
input color           InpHiC5 = clrIndianRed;       //   High Color
input int             InpHiW5 = 2;                  //   High Width
input color           InpLoC5 = clrSteelBlue;       //   Low Color
input int             InpLoW5 = 2;                  //   Low Width
input color           InpOpC5 = clrGray;            //   Open Color
input int             InpOpW5 = 2;                  //   Open Width

// --- Midnight Levels ---
input group           "Midnight Levels (UTC+2)"
input bool            InpShowMidnight = false;      // Show Midnight Levels
input int             InpMidnightLookback = 21;     // Lookback (Days)
input color           InpMidnightHighColor = clrOrange; // High Color
input ENUM_LINE_STYLE InpMidnightHighStyle = STYLE_SOLID; // High Style
input int             InpMidnightHighWidth = 1;     // High Width
input color           InpMidnightLowColor = clrDarkViolet; // Low Color
input ENUM_LINE_STYLE InpMidnightLowStyle = STYLE_SOLID; // Low Style
input int             InpMidnightLowWidth = 1;      // Low Width

// --- Interaction Visuals ---
input group           "Interaction Visuals"
input bool            InpShowWickInteractions = false; // Show Wick Interactions
input ushort          InpMarkerStyle = 159;         // Marker Style (e.g., 159 for Circle)

// --- General Settings ---
input group           "General Settings"
input int             InpStartYear = 2025;          // Year to start calculations from
input bool            InpExtendLines = true;        // Extend Lines into Future
input bool            InpShowLabels = true;         // Show Date Labels
input int             InpEndLabelFontSize = 6;      // End Label Font Size

//+------------------------------------------------------------------+
//| Custom Data Structures                                           |
//+------------------------------------------------------------------+
struct LevelProperties
{
   color             line_color;
   ENUM_LINE_STYLE   line_style;
   int               line_width;
};

// Function to convert month integer to string
string MonthToString(int month)
{
    switch(month)
    {
        case 1:  return "Jan";
        case 2:  return "Feb";
        case 3:  return "Mar";
        case 4:  return "Apr";
        case 5:  return "May";
        case 6:  return "Jun";
        case 7:  return "Jul";
        case 8:  return "Aug";
        case 9:  return "Sep";
        case 10: return "Oct";
        case 11: return "Nov";
        case 12: return "Dec";
        default: return "";
    }
}

// Function to determine if a color is dark to choose contrasting text color
bool IsColorDark(color c)
{
  int r = (c >> 16) & 0xFF;
  int g = (c >> 8) & 0xFF;
  int b = c & 0xFF;
  double brightness = (0.299 * r + 0.587 * g + 0.114 * b);
  return brightness < 128;
}

// Base class for a price level
class CPriceLevel : public CObject
{
public:
   datetime          time;         // Timestamp of the M15 bar
   double            price;        // Price of the level
   string            obj_name;     // Unique name for the line object
   string            label_name;   // Unique name for the label object
   string            level_id;     // Identifier for the level type (e.g., "1st Wed High")
   LevelProperties   props;        // Visual properties
   bool              is_drawn;

                     CPriceLevel(datetime t, double p, string id) : time(t), price(p), level_id(id), is_drawn(false) {}

   void              Draw()
   {
      // Create trend line
      obj_name = MQLInfoString(MQL_PROGRAM_NAME) + "_" + level_id + "_" + (string)time;
      if(ObjectFind(0, obj_name) != 0)
      {
         datetime end_time = InpExtendLines ? TimeCurrent() : (datetime)(time + PeriodSeconds(PERIOD_D1) - 1);
         ObjectCreate(0, obj_name, OBJ_TREND, 0, time, price, end_time, price);
         
         ObjectSetInteger(0, obj_name, OBJPROP_COLOR, props.line_color);
         ObjectSetInteger(0, obj_name, OBJPROP_STYLE, props.line_style);
         ObjectSetInteger(0, obj_name, OBJPROP_WIDTH, props.line_width);
         ObjectSetInteger(0, obj_name, OBJPROP_BACK, true);
      }
      
      // Create end label if enabled
      if(InpShowLabels)
      {
         string end_label_name = obj_name + "_LBL";
         if(ObjectFind(0, end_label_name) == 0) ObjectDelete(0, end_label_name);
         
         MqlDateTime dt;
         TimeToStruct(time, dt);
         string date_str = StringFormat("%d %s", dt.day, MonthToString(dt.mon));
         
         // *** FIX: Use a more robust price offset based on Tick Size to prevent labels from overlapping ***
         double price_offset = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE) * 15; // Offset by 15 ticks
         if(price_offset == 0) // Fallback for symbols with no tick size
         {
             price_offset = _Point * 15 * InpEndLabelFontSize;
         }

         double label_price = price;
         ENUM_ANCHOR_POINT anchor = ANCHOR_LEFT_UPPER;

         if(StringFind(level_id, "High") != -1)
         {
            label_price = price + price_offset;
            anchor = ANCHOR_LEFT_LOWER;
         }
         else
         {
            label_price = price - price_offset;
            anchor = ANCHOR_LEFT_UPPER;
         }

         ObjectCreate(0, end_label_name, OBJ_TEXT, 0, TimeCurrent(), label_price);
         ObjectSetString(0, end_label_name, OBJPROP_TEXT, date_str + " " + level_id + " " + DoubleToString(price, _Digits));
         ObjectSetInteger(0, end_label_name, OBJPROP_COLOR, IsColorDark(props.line_color) ? clrWhite : clrBlack);
         ObjectSetInteger(0, end_label_name, OBJPROP_FONTSIZE, InpEndLabelFontSize);
         ObjectSetString(0, end_label_name, OBJPROP_FONT, "Arial");
         ObjectSetInteger(0, end_label_name, OBJPROP_ANCHOR, anchor);
         ObjectSetInteger(0, end_label_name, OBJPROP_BACK, false);
         ObjectSetInteger(0, end_label_name, OBJPROP_SELECTABLE, false);
      }
      
      is_drawn = true;
   }

   void              Update()
   {
      if(is_drawn && InpExtendLines)
      {
         // Update trendline end point
         if(ObjectFind(0, obj_name) == 0)
         {
            ObjectSetInteger(0, obj_name, OBJPROP_TIME, 1, TimeCurrent());
         }
         
         // Update end label position
         if(InpShowLabels)
         {
            string end_label_name = obj_name + "_LBL";
            if(ObjectFind(0, end_label_name) == 0)
            {
               ObjectSetInteger(0, end_label_name, OBJPROP_TIME, 0, TimeCurrent());
            }
         }
      }
   }

   void              Delete()
   {
      if(ObjectFind(0, obj_name) == 0) ObjectDelete(0, obj_name);
      
      // Delete end label
      if(InpShowLabels)
      {
         string end_label_name = obj_name + "_LBL";
         if(ObjectFind(0, end_label_name) == 0) ObjectDelete(0, end_label_name);
      }
      
      is_drawn = false;
   }
};

//+------------------------------------------------------------------+
//| Global Variables                                                 |
//+------------------------------------------------------------------+
CArrayObj* g_wednesday_levels;
CArrayObj* g_midnight_levels;

// Alert cooldown management
long g_last_alert_times[100]; // Map level_id string to time
string g_alert_level_ids[100];
int g_alert_map_size = 0;

// Wednesday properties arrays
bool g_show_wednesday[5];
LevelProperties g_wed_high_props[5];
LevelProperties g_wed_low_props[5];
LevelProperties g_wed_open_props[5];

string g_indicator_short_name;

//+------------------------------------------------------------------+
//| Helper Functions                                                 |
//+------------------------------------------------------------------+

// Get unique index for an alert ID
int GetAlertMapIndex(string level_id)
{
    for(int i = 0; i < g_alert_map_size; i++)
    {
        if(g_alert_level_ids[i] == level_id)
            return i;
    }
    if(g_alert_map_size < 100)
    {
        g_alert_level_ids[g_alert_map_size] = level_id;
        g_last_alert_times[g_alert_map_size] = 0;
        return g_alert_map_size++;
    }
    return -1; // Should not happen
}

void SendAlertNotification(string level_id, double price)
{
    int map_idx = GetAlertMapIndex(level_id);
    if(map_idx == -1) return;

    if(TimeCurrent() - g_last_alert_times[map_idx] < InpAlertCooldown)
    {
        return; // Cooldown active
    }

    string message = "WICK TOUCH - " + level_id + " (" + DoubleToString(price, _Digits) + ") on " + _Symbol;
    if(InpSendAlert) Alert(message);
    if(InpSendEmail) SendMail(_Symbol + " Level Alert", message);
    if(InpSendPush) SendNotification(message);

    g_last_alert_times[map_idx] = TimeCurrent();
}


void CheckForWickInteraction(int i, const MqlRates &rates[])
{
    if(!InpShowWickInteractions) return;

    double high = rates[i].high;
    double low = rates[i].low;
    double open = rates[i].open;
    double close = rates[i].close;
    datetime time = rates[i].time;

    // Check Wednesday Levels
    if(InpShowWednesdays)
    {
        for(int j = 0; j < g_wednesday_levels.Total(); j++)
        {
            CPriceLevel* level = g_wednesday_levels.At(j);
            if(level == NULL || !level.is_drawn) continue;

            if(high >= level.price && low <= level.price)
            {
                if(level.price > MathMax(open, close) || level.price < MathMin(open, close))
                {
                    string marker_name = g_indicator_short_name + "_Marker_" + level.obj_name + "_" + (string)time;
                    if(ObjectFind(0, marker_name) != 0)
                    {
                        ObjectCreate(0, marker_name, OBJ_ARROW, 0, time, level.price);
                        ObjectSetInteger(0, marker_name, OBJPROP_ARROWCODE, InpMarkerStyle);
                        ObjectSetInteger(0, marker_name, OBJPROP_COLOR, level.props.line_color);
                        ObjectSetInteger(0, marker_name, OBJPROP_WIDTH, 1);
                    }
                    SendAlertNotification(level.level_id, level.price);
                }
            }
        }
    }

    // Check Midnight Levels
    if(InpShowMidnight)
    {
        for(int j = 0; j < g_midnight_levels.Total(); j++)
        {
            CPriceLevel* level = g_midnight_levels.At(j);
            if(level == NULL || !level.is_drawn) continue;

            if(high >= level.price && low <= level.price)
            {
                if(level.price > MathMax(open, close) || level.price < MathMin(open, close))
                {
                    string marker_name = g_indicator_short_name + "_Marker_" + level.obj_name + "_" + (string)time;
                    if(ObjectFind(0, marker_name) != 0)
                    {
                        ObjectCreate(0, marker_name, OBJ_ARROW, 0, time, level.price);
                        ObjectSetInteger(0, marker_name, OBJPROP_ARROWCODE, InpMarkerStyle);
                        ObjectSetInteger(0, marker_name, OBJPROP_COLOR, level.props.line_color);
                        ObjectSetInteger(0, marker_name, OBJPROP_WIDTH, 1);
                    }
                    SendAlertNotification(level.level_id, level.price);
                }
            }
        }
    }
}


void LoadWednesdaySettings()
{
    g_show_wednesday[0] = InpShowW1;
    g_wed_high_props[0].line_color = InpHiC1; g_wed_high_props[0].line_style = STYLE_SOLID; g_wed_high_props[0].line_width = InpHiW1;
    g_wed_low_props[0].line_color  = InpLoC1; g_wed_low_props[0].line_style  = STYLE_SOLID; g_wed_low_props[0].line_width  = InpLoW1;
    g_wed_open_props[0].line_color = InpOpC1; g_wed_open_props[0].line_style = STYLE_SOLID; g_wed_open_props[0].line_width = InpOpW1;

    g_show_wednesday[1] = InpShowW2;
    g_wed_high_props[1].line_color = InpHiC2; g_wed_high_props[1].line_style = STYLE_SOLID; g_wed_high_props[1].line_width = InpHiW2;
    g_wed_low_props[1].line_color  = InpLoC2; g_wed_low_props[1].line_style  = STYLE_SOLID; g_wed_low_props[1].line_width  = InpLoW2;
    g_wed_open_props[1].line_color = InpOpC2; g_wed_open_props[1].line_style = STYLE_SOLID; g_wed_open_props[1].line_width = InpOpW2;

    g_show_wednesday[2] = InpShowW3;
    g_wed_high_props[2].line_color = InpHiC3; g_wed_high_props[2].line_style = STYLE_SOLID; g_wed_high_props[2].line_width = InpHiW3;
    g_wed_low_props[2].line_color  = InpLoC3; g_wed_low_props[2].line_style  = STYLE_SOLID; g_wed_low_props[2].line_width  = InpLoW3;
    g_wed_open_props[2].line_color = InpOpC3; g_wed_open_props[2].line_style = STYLE_SOLID; g_wed_open_props[2].line_width = InpOpW3;

    g_show_wednesday[3] = InpShowW4;
    g_wed_high_props[3].line_color = InpHiC4; g_wed_high_props[3].line_style = STYLE_SOLID; g_wed_high_props[3].line_width = InpHiW4;
    g_wed_low_props[3].line_color  = InpLoC4; g_wed_low_props[3].line_style  = STYLE_SOLID; g_wed_low_props[3].line_width  = InpLoW4;
    g_wed_open_props[3].line_color = InpOpC4; g_wed_open_props[3].line_style = STYLE_SOLID; g_wed_open_props[3].line_width = InpOpW4;

    g_show_wednesday[4] = InpShowW5;
    g_wed_high_props[4].line_color = InpHiC5; g_wed_high_props[4].line_style = STYLE_SOLID; g_wed_high_props[4].line_width = InpHiW5;
    g_wed_low_props[4].line_color  = InpLoC5; g_wed_low_props[4].line_style  = STYLE_SOLID; g_wed_low_props[4].line_width  = InpLoW5;
    g_wed_open_props[4].line_color = InpOpC5; g_wed_open_props[4].line_style = STYLE_SOLID; g_wed_open_props[4].line_width = InpOpW5;
}

//+------------------------------------------------------------------+
//| Indicator initialization function                                |
//+------------------------------------------------------------------+
int OnInit()
{
    g_indicator_short_name = MQLInfoString(MQL_PROGRAM_NAME);
    
    // Clean up old objects from previous runs to prevent clutter
    ObjectsDeleteAll(0, g_indicator_short_name);

    g_wednesday_levels = new CArrayObj();
    g_midnight_levels = new CArrayObj();
    
    LoadWednesdaySettings();
    
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Indicator deinitialization function                              |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    if(g_wednesday_levels != NULL)
    {
       delete g_wednesday_levels;
    }
    if(g_midnight_levels != NULL)
    {
       delete g_midnight_levels;
    }
    
    ObjectsDeleteAll(0, g_indicator_short_name);
}

//+------------------------------------------------------------------+
//| Indicator calculation function                                   |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
    static bool is_new_bar = false;
    static datetime last_bar_time = 0;
    if(rates_total > 0 && time[rates_total - 1] != last_bar_time)
    {
        is_new_bar = true;
        last_bar_time = time[rates_total - 1];
    }
    else
    {
        is_new_bar = false;
    }

    if(prev_calculated == 0 || is_new_bar)
    {
        if(InpExtendLines && is_new_bar)
        {
            for(int i = 0; i < g_wednesday_levels.Total(); i++)
            {
                CPriceLevel* level = g_wednesday_levels.At(i);
                if(level != NULL) level.Update();
            }
            for(int i = 0; i < g_midnight_levels.Total(); i++)
            {
                CPriceLevel* level = g_midnight_levels.At(i);
                if(level != NULL) level.Update();
            }
        }

        if(InpShowWednesdays)
        {
            MqlRates m15_rates[];
            int bars_to_copy = rates_total * (int)(PeriodSeconds() / PeriodSeconds(PERIOD_M15)) + 2;
            if(CopyRates(_Symbol, PERIOD_M15, 0, bars_to_copy, m15_rates) > 0)
            {
                datetime last_wed_found_time = 0;
                if(g_wednesday_levels.Total() > 0)
                {
                    CPriceLevel *last_level = g_wednesday_levels.At(g_wednesday_levels.Total() - 1);
                    if(last_level != NULL) last_wed_found_time = last_level.time;
                }

                for(int i = ArraySize(m15_rates) - 1; i >= 0; i--)
                {
                    if(m15_rates[i].time <= last_wed_found_time) continue;
                    
                    MqlDateTime dt;
                    TimeToStruct(m15_rates[i].time, dt);
                    
                    if(dt.year < InpStartYear) continue;

                    long sast_offset = 2 * 3600; // SAST is UTC+2
                    datetime sast_time = (datetime)(m15_rates[i].time - TimeGMTOffset() + sast_offset);
                    MqlDateTime sast_dt;
                    TimeToStruct(sast_time, sast_dt);

                    if(dt.day_of_week == WEDNESDAY && sast_dt.hour == 20 && sast_dt.min == 30)
                    {
                        int wed_of_month = (dt.day - 1) / 7 + 1;
                        if(wed_of_month > 5) continue;
                        
                        bool exists = false;
                        for(int k=0; k<g_wednesday_levels.Total(); k++)
                        {
                           CPriceLevel *lvl = g_wednesday_levels.At(k);
                           if(lvl.time == m15_rates[i].time) { exists = true; break; }
                        }
                        if(exists) continue;

                        string wed_id_str = IntegerToString(wed_of_month) + (wed_of_month==1?"st":wed_of_month==2?"nd":wed_of_month==3?"rd":"th") + " Wed";
                        
                        if(g_show_wednesday[wed_of_month-1])
                        {
                           CPriceLevel* high_level = new CPriceLevel(m15_rates[i].time, m15_rates[i].high, wed_id_str + " High");
                           high_level.props = g_wed_high_props[wed_of_month-1];
                           high_level.Draw();
                           g_wednesday_levels.Add(high_level);

                           CPriceLevel* low_level = new CPriceLevel(m15_rates[i].time, m15_rates[i].low, wed_id_str + " Low");
                           low_level.props = g_wed_low_props[wed_of_month-1];
                           low_level.Draw();
                           g_wednesday_levels.Add(low_level);

                           if(InpShowWednesdayOpen)
                           {
                              CPriceLevel* open_level = new CPriceLevel(m15_rates[i].time, m15_rates[i].open, wed_id_str + " Open");
                              open_level.props = g_wed_open_props[wed_of_month-1];
                              open_level.Draw();
                              g_wednesday_levels.Add(open_level);
                           }
                        }
                    }
                }
            }
        }
        
        if(InpShowMidnight)
        {
            MqlRates m15_rates[];
            if(CopyRates(_Symbol, PERIOD_M15, 0, InpMidnightLookback * 96 + 2, m15_rates) > 0)
            {
                datetime last_mid_found_time = 0;
                if(g_midnight_levels.Total() > 0)
                {
                    CPriceLevel *last_level = g_midnight_levels.At(g_midnight_levels.Total() - 1);
                    if(last_level != NULL) last_mid_found_time = last_level.time;
                }

                for(int i = ArraySize(m15_rates) - 1; i >= 0; i--)
                {
                    if(m15_rates[i].time <= last_mid_found_time) continue;

                    MqlDateTime dt;
                    TimeToStruct(m15_rates[i].time, dt);
                    if(dt.year < InpStartYear) continue;

                    long sast_offset = 2 * 3600; // SAST is UTC+2
                    datetime sast_time = (datetime)(m15_rates[i].time - TimeGMTOffset() + sast_offset);
                    MqlDateTime sast_dt;
                    TimeToStruct(sast_time, sast_dt);

                    if(sast_dt.hour == 0 && sast_dt.min == 0) // Midnight SAST (UTC+2)
                    {
                        bool exists = false;
                        for(int k=0; k<g_midnight_levels.Total(); k++)
                        {
                           CPriceLevel *lvl = g_midnight_levels.At(k);
                           if(lvl.time == m15_rates[i].time) { exists = true; break; }
                        }
                        if(exists) continue;

                        CPriceLevel* high_level = new CPriceLevel(m15_rates[i].time, m15_rates[i].high, "Midnight High");
                        high_level.props.line_color = InpMidnightHighColor;
                        high_level.props.line_style = InpMidnightHighStyle;
                        high_level.props.line_width = InpMidnightHighWidth;
                        high_level.Draw();
                        g_midnight_levels.Add(high_level);

                        CPriceLevel* low_level = new CPriceLevel(m15_rates[i].time, m15_rates[i].low, "Midnight Low");
                        low_level.props.line_color = InpMidnightLowColor;
                        low_level.props.line_style = InpMidnightLowStyle;
                        low_level.props.line_width = InpMidnightLowWidth;
                        low_level.Draw();
                        g_midnight_levels.Add(low_level);
                    }
                }
            }
            
            datetime lookback_time = (datetime)(TimeCurrent() - (long)InpMidnightLookback * 86400);
            for(int i = g_midnight_levels.Total() - 1; i >= 0; i--)
            {
                CPriceLevel* level = g_midnight_levels.At(i);
                if(level.time < lookback_time)
                {
                    level.Delete();
                    delete level;
                    g_midnight_levels.Delete(i);
                }
            }
        }
    }

    if(InpShowWickInteractions)
    {
        MqlRates current_rates[];
        int start_pos = prev_calculated > 1 ? prev_calculated - 1 : 0;
        int count = rates_total - start_pos;
        if(CopyRates(_Symbol, _Period, start_pos, count, current_rates) > 0)
        {
            for(int i = 0; i < ArraySize(current_rates); i++)
            {
                CheckForWickInteraction(i, current_rates);
            }
        }
    }
    
    ChartRedraw();
    return(rates_total);
}
//+------------------------------------------------------------------+
