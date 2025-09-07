#property copyright "Copyright 2023, GwDs, new implementation by phade"
#property version   "1.01"

/*---  Buffer declaration */
#property   indicator_buffers 4      // Number of buffer displayed    
#property indicator_plots 2      // number of plot on the graph   


/*--- Indicator preference */
input uchar          g_StoKPeriod     = 60;           // K-period (number of bars for calculations
input uchar          g_StoDPeriod     = 5;           // D period (the period of primary
input uchar          g_StoSlowing     = 5;           // Period of final smoothing
input ENUM_MA_METHOD g_StoMethod      = MODE_SMA;    // Type of smoothing  
input ENUM_STO_PRICE g_StoPrice_field = STO_LOWHIGH; // Method of calculation
input int            shift            = 0;           // Shift


input int MA_Period = 30; // Period


/*--- Graph placement */
#property indicator_separate_window

/*--- Graph heigh */
#property indicator_minimum 0
#property indicator_maximum 100


int      g_ptStochastic = INVALID_HANDLE; // Pointer of the Stochastic

double   g_BuffSto[];                     // Buffer Stochastic
double   g_BuffStoSignal[];               // Buffer Stochastic Signal
double plotting_buffer_sig[];
double plotting_buffer_sto[];

double ma[]; 

/*--- Buffer plot characteristics */
/*--- Signal Stochastic */

#property indicator_label1       "Stochastic"     // Plot Label
   #property indicator_type1        DRAW_LINE        // Plot Type
   #property indicator_color1       clrGreen         // Plot color
   #property indicator_style1       STYLE_SOLID      // Plot Style
   #property indicator_width1       1                // Plot width

#property indicator_label2       "Stochastic Signal"
   #property indicator_type2        DRAW_LINE
   #property indicator_color2       clrRed
   #property indicator_style2       STYLE_DOT
   #property indicator_width2       1

#property indicator_label3       "MA Line"
   #property indicator_type3        DRAW_LINE
   #property indicator_color3       clrSilver
   #property indicator_width3       2

#property indicator_levelcolor   clrRed      // Oversold and overBuy color thresholds
#property indicator_levelstyle   STYLE_DASH  // Oversold and OverBuy Style thresholds
#property indicator_levelwidth   1           // Oversold and OverBuy Thickness Thresholds
#property indicator_level1       80          // Hard-coded value
#property indicator_level2       20          


int ma_handle = INVALID_HANDLE; 

double LEVEL_80 = 1.0855;
double LEVEL_20 = 1.0829;
//+------------------------------------------------------------------+
//|   OnInit                                                         |
//+------------------------------------------------------------------+  
int OnInit()
  {
     /*--- Handle Creation */
      g_ptStochastic = iStochastic( Symbol(), Period(), 
         g_StoKPeriod, g_StoDPeriod, g_StoSlowing, g_StoMethod, 
         g_StoPrice_field);
          
      /*--- Transforms the array into display buffer */        
      SetIndexBuffer(0, plotting_buffer_sig, INDICATOR_DATA);
      SetIndexBuffer(1, plotting_buffer_sto, INDICATOR_DATA);   
     // SetIndexBuffer(2, ma, INDICATOR_DATA);    
        
      SetIndexBuffer(2, g_BuffSto, INDICATOR_CALCULATIONS);
      SetIndexBuffer(3, g_BuffStoSignal, INDICATOR_CALCULATIONS);
      
      
      ma_handle = iMA(Symbol(), Period(), MA_Period, 0, MODE_LWMA, PRICE_WEIGHTED);                 
      ChartIndicatorAdd(0, 1, ma_handle);

      return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//|   OnCalculate                                                    |
//+------------------------------------------------------------------+
int OnCalculate( const int        rates_total,      // Total number of bars to be processed
                 const int        prev_calculated,  // Number of bars calculated in the previous call
                 const datetime   &time[],          // Array of bar times  
                 const double     &open[],          // Array of bar open prices
                 const double     &high[],          // Array of bar high prices
                 const double     &low[],           // Array of bar low prices  
                 const double     &close[],         // Array of bar close prices
                 const long       &tick_volume[],   // Array of tick volumes for each bar
                 const long       &volume[],        // Array of real volumes for each bar
                 const int        &spread[])        // Array of spreads for each bar
{

   
   if (prev_calculated < 0){
      return 0;
   }
   
   if (CopyBuffer(g_ptStochastic, 0, 0, rates_total, g_BuffSto)<=0){
      PrintFormat("Error retrieving data for Stochastic");
      return (0);
   }
   
   if (CopyBuffer(g_ptStochastic, 1, 0, rates_total, g_BuffStoSignal)<=0){
      PrintFormat("Error retrieving data for Stochastic Signal");
      return (0);
   }
   
   
   if (CopyBuffer(ma_handle, 0, 0, rates_total, ma)<=0){
      PrintFormat("Error retrieving data for MA");
      return (0);
   }   
   

   for(int i=rates_total-1; i>=shift; i--){
    
        plotting_buffer_sig[i - shift] = g_BuffStoSignal[i];
        plotting_buffer_sto[i - shift] = g_BuffSto[i];
   }

   //ChartIndicatorGet(0, 1, ChartIndicatorName(0,1,1));

   int j = rates_total-1;
   
  // Print("TEST latest MA val: ", ma[j]);
    
   if(NormalizeDouble(ma[j-1], 4) > LEVEL_80 && NormalizeDouble(ma[j], 4) < LEVEL_80){
      
      Print("SIGNAL: MA CROSSED THE 80 LEVEL DOWN FROM TOP");
   }
   
   else if(NormalizeDouble(ma[j-1], 4) < LEVEL_20 && NormalizeDouble(ma[j], 4) > LEVEL_20){
      
      Print("SIGNAL: MA CROSSED THE 20 LEVEL UP FROM BOTTOM"); 
   }


   return(rates_total);
  
}
  
//+------------------------------------------------------------------+
//|   OnDeinit                                                       |
//+------------------------------------------------------------------+  
void OnDeinit(const int reason)
{

     /* release the indicator resource */
     IndicatorRelease( g_ptStochastic);
}        