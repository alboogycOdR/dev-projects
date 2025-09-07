#property copyright "Copyright 2023, GwDs, phade"
#property version   "1.01"

#property indicator_separate_window
#property indicator_buffers 5   
#property indicator_plots 3     


//--- Indicator settings
input uchar          g_StoKPeriod     = 4;           // K-period (number of bars for calculations)
input uchar          g_StoDPeriod     = 2;           // D period (the period of primary smoothing)
input uchar          g_StoSlowing     = 14;          // Period of final smoothing
input ENUM_MA_METHOD g_StoMethod      = MODE_SMA;    // Type of smoothing  
input ENUM_STO_PRICE g_StoPrice_field = STO_LOWHIGH; // Method of calculation
input int            shift            = 0;           // Shift
input int            MA_Period        = 50;          // MA Period
input bool           activate_alerts  = true;        // Alerts 

//--- Indicator ranges
#property indicator_minimum 0
#property indicator_maximum 100

//--- Plot settings
#property indicator_label1  "Stochastic"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrGreen
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

#property indicator_label2  "Stochastic Signal"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrRed
#property indicator_style2  STYLE_DOT
#property indicator_width2  1

#property indicator_label3  "MA Line"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrSilver
#property indicator_style3  STYLE_SOLID 
#property indicator_width3  2

#property indicator_levelcolor   clrRed
#property indicator_levelstyle   STYLE_DASH
#property indicator_levelwidth   1
#property indicator_level1       80
#property indicator_level2       20

//--- Buffers
double g_BuffSto[];
double g_BuffStoSignal[];
double plotting_buffer_sig[];
double plotting_buffer_sto[];
double ma[];

//--- Handles
int g_ptStochastic = INVALID_HANDLE;
int ma_handle = INVALID_HANDLE;



datetime initialization_time = TimeCurrent(); 

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit() {
    //--- Handle creation
    g_ptStochastic = iStochastic(Symbol(), Period(), g_StoKPeriod, g_StoDPeriod, g_StoSlowing, g_StoMethod, g_StoPrice_field);
    ma_handle = iMA(Symbol(), Period(), MA_Period, 0, MODE_SMA, PRICE_CLOSE);

    //--- Buffer mapping
    SetIndexBuffer(0, plotting_buffer_sig, INDICATOR_DATA);
    SetIndexBuffer(1, plotting_buffer_sto, INDICATOR_DATA);              
    SetIndexBuffer(2, ma, INDICATOR_DATA);
    SetIndexBuffer(3, g_BuffSto, INDICATOR_CALCULATIONS);
    SetIndexBuffer(4, g_BuffStoSignal, INDICATOR_CALCULATIONS);
    
    ChartIndicatorAdd(0,0,ma_handle);

    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
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
                const int &spread[]) {

    int to_copy = rates_total - prev_calculated;
    if (prev_calculated > 0) to_copy++;

    if (BarsCalculated(g_ptStochastic) < rates_total || BarsCalculated(ma_handle) < rates_total){
        Print("Not all data of handles are calculated. Error ", GetLastError());
        return 0;
    }

    if (CopyBuffer(g_ptStochastic, 0, 0, to_copy, g_BuffSto) <= 0 ||
        CopyBuffer(g_ptStochastic, 1, 0, to_copy, g_BuffStoSignal) <= 0 ||
        CopyBuffer(ma_handle, 0, 0, to_copy, ma) <= 0) {
        Print("Error retrieving data. Error ", GetLastError());
        return 0;
    }

    int limit = prev_calculated == 0 ? 0 : prev_calculated - 1;

    // create a shift in the indicator
    for (int i = rates_total - 1; i >= limit+shift; i--) {
        plotting_buffer_sto[i - shift] = g_BuffSto[i];
        plotting_buffer_sig[i - shift] = g_BuffStoSignal[i];
    }
    
 
    // debug in the main loop
//    for (int i = limit; i < rates_total; i++){
//    
//        Print("Test sto ", plotting_buffer_sto[i]);
//        Print("Test ma ", ma[i]);
//    }
    
    double bid = SymbolInfoDouble(Symbol(), SYMBOL_BID);
    
    bool above_ma = bid > ma[rates_total-1] && close[rates_total-1] > ma[rates_total-1];  
    bool below_ma = bid < ma[rates_total-1] && close[rates_total-1] < ma[rates_total-1];  
    
    bool stochastic_oversold = MathFloor(plotting_buffer_sto[rates_total-1]) < 20;
    bool stochastic_overbought = MathFloor(plotting_buffer_sto[rates_total-1]) > 80;    
     
    if(activate_alerts && (above_ma && stochastic_oversold)){   
          
      string alertMessage = "Potential uptrend on " + Symbol() + " " +  timeframeToString(Period());
      TriggerAlert(time, alertMessage, rates_total-1);  
    }   
    else if(activate_alerts && (below_ma && stochastic_overbought)){
          
      string alertMessage = "Potential downtrend on " + Symbol() + " " +  timeframeToString(Period());
      TriggerAlert(time, alertMessage, rates_total-1);    
    }
 

    return rates_total;
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
    IndicatorRelease(g_ptStochastic);
    IndicatorRelease(ma_handle);
}


void TriggerAlert(const datetime &time[], string m_text, int idx){

     if(initialization_time < time[idx]){
     
          Alert(m_text);         
          initialization_time = time[idx] - (time[idx] % PeriodSeconds());
     }
}


string timeframeToString(ENUM_TIMEFRAMES period)
{
    switch (period){
    
        case PERIOD_M1: return "M1";
        case PERIOD_M2: return "M2";
        case PERIOD_M3: return "M3";
        case PERIOD_M4: return "M4";
        case PERIOD_M5: return "M5";
        case PERIOD_M6: return "M6";
        case PERIOD_M10: return "M10";
        case PERIOD_M12: return "M12";
        case PERIOD_M15: return "M15";
        case PERIOD_M20: return "M20";
        case PERIOD_M30: return "M30";
        case PERIOD_H1: return "H1";
        case PERIOD_H2: return "H2";
        case PERIOD_H3: return "H3";
        case PERIOD_H4: return "H4";
        case PERIOD_H6: return "H6";
        case PERIOD_H8: return "H8";
        case PERIOD_H12: return "H12";
        case PERIOD_D1: return "D1";
        case PERIOD_W1: return "W1";
        case PERIOD_MN1: return "MN1";
        
        default: return "Current";
    }
}
