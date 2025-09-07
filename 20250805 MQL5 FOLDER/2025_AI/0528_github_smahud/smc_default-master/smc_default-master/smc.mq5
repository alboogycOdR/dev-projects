//+------------------------------------------------------------------+
//|                                                          smc.mq5 |
//|                                  Copyright 2024, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

#include <Trade\Trade.mqh>
      CTrade                  trade;
      CPositionInfo           posinfo;
      COrderInfo              ordinfo;

   input group "=== Trading Inputs ==="   
      input double                  minVolume                        = 0.01;              // Min volume to start (Fixed volume + Risk Percent = 0)
      input double                  RiskPercent                      = 2;                 // Risk as % of Trading Capital
      input int                     Tppoints                         = 250;               // Take Profit (10 Points = 1 pip)
      input int                     Slpoints                         = 150;               // Stoploss Points (10 Points = 1 pip)
      input int                     TslTriggerPoints                 = 30;                // Points in Profit before Trailing Sl in actived (10 Points = 1 pip)
      input int                     TslPoints                        = 15;                // Trailing Stoploss Points (10 Points = 1 pip)
      
      enum wayTrade { one_way = 1, two_way = 2};
      input wayTrade                InpWayTrade                      = 1;                 // Enable 1-way or 2-way trading
      
      enum confirmLowTF { no = 0, yes = 1};
      input confirmLowTF            InpCpLowTF                       = 1;                 // Confirmation on lower time frame
      
      input int                     InpMaxSpread                     = 15;                // Max spread accept trade
      input ENUM_TIMEFRAMES         InpTimeframe                     = PERIOD_CURRENT;    // Time frame to run
      
      enum typeTrade {Marjor = 0, Minnor = 1};
      input typeTrade               InpTrade                         = 0;                 // Type go to trade of major struct or minor struct 
      
      enum StartHour {Inactive=0, _1=1, _2=2, _3=3, _4=4, _5=5, _6=6, _7=7, _8=8, _9=9, _10=10, _11=11, _12=12, _13=13, _14=14, _15=15, _16=16, _17=17, _18=18, _19=19, _20=20, _21=21, _22=22, _23=23, _24=24 };
      input StartHour SHInput = 0; // Start Hour
      
      enum EndHour {Inactive=0, _1=1, _2=2, _3=3, _4=4, _5=5, _6=6, _7=7, _8=8, _9=9, _10=10, _11=11, _12=12, _13=13, _14=14, _15=15, _16=16, _17=17, _18=18, _19=19, _20=20, _21=21, _22=22, _23=23, _24=24 };
      input EndHour EHInput = 0; // End Hour
      
      int SHChoice;
      int EHChoice;
      
      int         BarsN = 5;
      int         ExpirationBars = 100;
      int         OrderDistPoints= InpMaxSpread; // 100
      
      input int                     InpMagic                         = 298368;            // EA indentification no
      input string                  TradeComment                     = "SMC Scalping";    //Trade Comment   
      string dotSpace = "----------------------------------------------------";

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
   bool gComment = false; // Show or Off comment => For develop object
   bool enabledComment = true;
   bool disableComment = false;
   MqlRates waveRates[],rates[];
   double high, low, high2, low2;
   datetime time, time2;
   
   int GANN_STRUCTURE = 1;
   int INTERNAL_STRUCTURE = 2;
   int INTERNAL_STRUCTURE_KEY = 3;
   int MAJOR_STRUCTURE = 4;
   bool enabledDraw = true;
   bool disableDraw = false;
   
   // Gann Wave
   double highEst, lowEst;
   double Highs[], Lows[];
   datetime hightime, lowtime;
   datetime HighsTime[], LowsTime[];
   int LastSwingMeter = 0; // finding high or low 1 is high; -1 is low
   int gTrend = 0; // Gann trend    : trend is Up wave or Down wave, 1 is Up; -1 is Down
   
   // Internal Structure
   double intSHighs[], intSLows[];
   datetime intSHighTime[], intSLowTime[];
   int LastSwingInternal = 0; // finding high or low 1 is high; -1 is low
   int iTrend = 0; // Minor trend   : trend is Up wave or Down wave, 1 is Up; -1 is down 
   
   
   // array pullback swing high or low
   double arrTop[], arrBot[];
   datetime arrTopTime[], arrBotTime[];
   int mTrend = 0; // Marjor trend  : trend is Up wave or Down wave, 1 is Up; -1 is down 
   int sTrend = 0; // Super trend   : trend is Up wave or Down wave, 1 is Up; -1 is down 
   datetime arrPbHTime[];
   double arrPbHigh[];
   datetime arrPbLTime[];
   double arrPbLow[];
   
   double arrChoHigh[], arrChoLow[];
   datetime arrChoHighTime[], arrChoLowTime[];
   double arrBoHigh[], arrBoLow[];
   datetime arrBoHighTime[], arrBoLowTime[];
   
   int LastSwingMajor = 0; // finding high or low 1 is high; -1 is low
   //high low
   //double puHigh, puLow, L, H, idmLow, idmHigh, lastH, lastL, H_lastH, L_lastHH, H_lastLL, L_lastL, motherHigh, motherLow;
   datetime lastTimeH = 0;
   datetime lastTimeL = 0;
   double L, H, idmLow, idmHigh, L_idmLow, L_idmHigh , lastH, lastL, H_lastH, L_lastHH, H_lastLL, L_lastL, motherHigh, motherLow;
   double findHigh, findLow;
   int touchIdmHigh, touchIdmLow;
   MqlRates L_bar, H_bar;
   
   //bar indexes
   //datetime motherBar, puBar, puHBar, puLBar, idmLBar, idmHBar, HBar, LBar, lastHBar, lastLBar;
   datetime idmLowTime, idmHighTime, L_idmLowTime, L_idmHighTime , HTime, LTime;
   
   //structure confirm
   //bool mnStrc, prevMnStrc, isPrevBos, findIDM, isBosUp, isBosDn, isCocUp, isCocDn;
   
   // POI
   struct PoiZone {
      double high, low, open, close;
      datetime time;
      int mitigated;
      double priceKey;
      datetime timeKey;
   };
   PoiZone zHighs[], zLows[], zIntSHighs[], zIntSLows[], zArrTop[], zArrBot[];
   PoiZone zArrPbHigh[], zArrPbLow[];
   // Extreme Poi
   PoiZone zPoiExtremeLow[], zPoiExtremeHigh[], zPoiLow[], zPoiHigh[];
   // Decisional Poi
   PoiZone zPoiDecisionalLow[], zPoiDecisionalHigh[];
   double arrDecisionalHigh[], arrDecisionalLow[];
   datetime arrDecisionalHighTime[], arrDecisionalLowTime[];
   PoiZone zArrDecisionalHigh[], zArrDecisionalLow[];

//---
//--- -----------------------------------------------------------------
//---
   input group "=== SMC settings ===" 
      input ENUM_TIMEFRAMES Timeframe = PERIOD_CURRENT;
      //#region variable declaration
      input int _PointSpace = 1000; // space for draw with swing, line
      input int poi_limit = 30; // poi limit save to array
   
   //Constant
   string IDM_TEXT = "idm";
   string IDM_TEXT_LIVE = "idm-l";
   string CHOCH_TEXT = "CHoCH";
   string I_CHOCH_TEXT = "i-choch";
   string BOS_TEXT = "BOS";
   string I_BOS_TEXT = "i-bos";
   string PDH_TEXT = "PDH";
   string PDL_TEXT = "PDL";
   string MID_TEXT = "0.5";
   string ULTRAVOLUME = " has UltraVolume";
   string SWEEPT = "";
   
   int iWingding_gann_high = 159;
   int iWingding_gann_low = 159;
   int iWingding_internal_high = 225;
   int iWingding_internal_low = 226;
   int iWingding_internal_key_high = 225;
   int iWingding_internal_key_low = 226;
   
   //poi
   bool isSweepOBS = false;
   int current_OBS = 0;
   double high_MOBS ,low_MOBS;
   
   bool isSweepOBD = false;
   int current_OBD;
   double low_MOBD;
   double high_MOBD;
   
   //demandZone[];
   //supplyZone[];
   //mitigatedZoneSupply[];
   //mitigatedZoneDemand[];
   
   double arrIdmHigh[];
   double arrIdmLow[];
   datetime arrIdmHBar[];
   datetime arrIdmLBar[];
   double arrLastH[];
   datetime arrLastHBar[];
   double arrLastL[];
   datetime arrLastLBar[];
   //arrIdmLine[];
   //arrIdmLabel[];
   //arrBCLine[];
   //arrBCLabel[];
   //arrHLLabel[];
   //arrHLCircle[];

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   trade.SetExpertMagicNumber(InpMagic);
   ChartSetInteger(0, CHART_SHOW_GRID, false);
   //--- Disable autoscroll
   ChartSetInteger(0,CHART_AUTOSCROLL,true);
   //--- Set the indent of the right border of the chart
   ChartSetInteger(0,CHART_SHIFT,true);
   //--- Display as candlesticks
   ChartSetInteger(0,CHART_MODE,CHART_CANDLES);
   //--- Set the tick volume display mode
   ChartSetInteger(0,CHART_SHOW_VOLUMES,CHART_VOLUME_TICK);
   
//--- SMC Init
   ArraySetAsSeries(waveRates, true);
   ArraySetAsSeries(rates, true);
   
   // Khai bao ban dau
   definedFunction();
   
   // draw swing wave before function active
   gannWave();
//--- End SMC Init
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
   
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   TrailStop();
   showTotal();
//---
   int copied = CopyRates(_Symbol, PERIOD_CURRENT, 0, 50, rates);
   high = rates[1].high;
   low = rates[1].low;
   
   if(!IsNewBar()) return;
   
   realGannWave();
   
   // Begin trade
   beginTrade();
  }
//+------------------------------------------------------------------+

void firstArray(double price, double& array[], datetime _time, datetime& arrayTime[]) {
   ArrayResize(array, MathMin(ArraySize(array) + 1, 10));
   array[0] = price;
   ArrayResize(arrayTime, MathMin(ArraySize(arrayTime) + 1, 10));
   arrayTime[0] = _time;
}

void firstZone(MqlRates& bar, PoiZone& array[]) {
   ArrayResize(array, MathMin(ArraySize(array) + 1, 10));
   array[0].high = bar.high;
   array[0].low = bar.low;
   array[0].open = bar.open;
   array[0].close = bar.close;
   array[0].time = bar.time;
   array[0].mitigated = 0;
   array[0].priceKey = -1;
   array[0].timeKey = -1;
}

//#region define function
void definedFunction() {
   int copied = CopyRates(_Symbol, PERIOD_CURRENT, 0, 100, waveRates);
   
   int firstBar = ArraySize(waveRates) - 1;
   MqlRates Bar1 = waveRates[firstBar];
   double firstBarHigh     = waveRates[firstBar].high;
   double firstBarLow      = waveRates[firstBar].low;
   datetime firstBarTime   = waveRates[firstBar].time;
      
   highEst = firstBarHigh;
   lowEst = firstBarLow;
   hightime = firstBarTime;
   lowtime = firstBarTime;
   // Gann structure
   firstArray(firstBarHigh, Highs, firstBarTime, HighsTime);
   firstArray(firstBarLow, Lows, firstBarTime, LowsTime);
      
   // internal structure
   firstArray(firstBarHigh, intSHighs, firstBarTime, intSHighTime);
   firstArray(firstBarLow, intSLows, firstBarTime, intSLowTime);
   
   // pullback structure
   firstArray(firstBarHigh, arrTop, firstBarTime, arrTopTime);
   firstArray(firstBarLow, arrBot, firstBarTime, arrBotTime);
   
   firstArray(firstBarHigh, arrPbHigh, firstBarTime, arrPbHTime);
   firstArray(firstBarLow, arrPbLow, firstBarTime, arrPbLTime);
   
   firstArray(0, arrChoHigh, firstBarTime, arrChoHighTime);
   firstArray(0, arrChoLow, firstBarTime, arrChoLowTime);
   firstArray(0, arrBoHigh, firstBarTime, arrBoHighTime);
   firstArray(0, arrBoLow, firstBarTime, arrBoLowTime);
   
   firstArray(firstBarHigh, arrDecisionalHigh, firstBarTime, arrDecisionalHighTime);
   firstArray(firstBarLow, arrDecisionalLow, firstBarTime, arrDecisionalLowTime);
   
   // first Zone
   firstZone(Bar1, zPoiLow);
   firstZone(Bar1, zPoiHigh);
   firstZone(Bar1, zPoiExtremeLow);
   firstZone(Bar1, zPoiExtremeHigh);
   firstZone(Bar1, zArrTop);
   firstZone(Bar1, zArrBot);
   firstZone(Bar1, zHighs);
   firstZone(Bar1, zLows);
   firstZone(Bar1, zIntSHighs);
   firstZone(Bar1, zIntSLows);
   firstZone(Bar1, zArrPbHigh);
   firstZone(Bar1, zArrPbLow);
   firstZone(Bar1, zPoiDecisionalHigh);
   firstZone(Bar1, zPoiDecisionalLow);
   firstZone(Bar1, zArrDecisionalHigh);
   firstZone(Bar1, zArrDecisionalLow);
   
   high = iHigh(_Symbol, PERIOD_CURRENT, 1);
   low = iLow(_Symbol, PERIOD_CURRENT, 1);
   time = iTime(_Symbol, PERIOD_CURRENT, 1);
   
   high2 = iHigh(_Symbol, PERIOD_CURRENT, 2);
   low2 = iLow(_Symbol, PERIOD_CURRENT, 2);
   time2 = iTime(_Symbol, PERIOD_CURRENT, 2);
   
   //high low   
   lastH = high;
   lastL = low;
   
//   puHigh = high;
//   puLow = low;
//   L = low;
//   H = high;
//   idmLow = low;
//   idmHigh = high;
//   
//   H_lastH = high;
//   L_lastHH = low;
//   H_lastLL = high;
//   L_lastL = low;
//   motherHigh = high2;
//   motherLow = low2;
//   
//   //bar indexes
//   motherBar = time2;
//   HBar = time;
//   LBar = time;
//   lastHBar = time;
//   lastLBar = time;
//   
//   //structure confirm
//   findIDM = false;
//   isBosUp = false;
//   isBosDn = false;
//   isCocUp = true;
//   isCocDn = true;
//   
//   //poi
//   isSweepOBS = false;
//   isSweepOBD = false;
}

//#region drawing function
bool isGreenBar(double open, double close) {
   return (close > open)? true : false;
}

int textCenter(int left, int right) {
  return (left + right) / 2;
}

string getValueTrend() {
   string text =  "STrend: "+ (string) sTrend + " ; mTrend: "+(string) mTrend+ " ; iTrend: "+(string) iTrend+ " ; gTrend: "+(string) gTrend + " ; LastSwingMajor: "+(string) LastSwingMajor+ "\n"+
                  " | findHigh: "+(string) findHigh+" idmHigh: "+(string) idmHigh+" ; findLow: "+(string) findLow+" idmLow: "+ (string) idmLow+
                   "; touchIdmHigh: " + (string) touchIdmHigh + "; touchIdmLow: " + (string) touchIdmLow + "\n"+
                  " | H: "+ (string) H +" - L: "+(string) L +" - highEst: "+(string) highEst +" - lowEst: "+(string) lowEst;
   return text;
}

string inInfoBar(MqlRates& bar1, MqlRates& bar2, MqlRates& bar3) {
   string text = " Bar1 high: "+ (string) bar1.high +" - low: "+ (string) bar1.low + " --- "+" Bar2 high: "+ (string) bar2.high +" - low: "+ (string) bar2.low+ " --- "+" Bar3 high: "+ (string) bar3.high +" - low: "+ (string) bar3.low;
   return text;
}

void showComment() {
   //Print("Highs: "); ArrayPrint(Highs);
   //Print("Lows: "); ArrayPrint(Lows);
   //Print("intSHighs: "); ArrayPrint(intSHighs); 
   //Print("intSLows: "); ArrayPrint(intSLows); 
   //Print("arrTop: "); ArrayPrint(arrTop); 
   //Print("arrBot: "); ArrayPrint(arrBot); 
   //Print("arrPbHigh: "); ArrayPrint(arrPbHigh); 
   //Print("arrPbLow: "); ArrayPrint(arrPbLow); 
   
   //Print("arrDecisionalHigh: "); ArrayPrint(arrDecisionalHigh);
   //Print("arrDecisionalLow: "); ArrayPrint(arrDecisionalLow);
   
   //Print("arrBoHigh: "+(string) arrBoHigh[0]);
   //Print("arrBoLow: "+(string) arrBoLow[0]);
   //Print("arrChoHigh: "+(string) arrChoHigh[0]);
   //Print("arrChoLow: "+(string) arrChoLow[0]);
   
   //ArrayPrint(zHighs);
   //ArrayPrint(zLows);
   //ArrayPrint(zIntSHighs);
   //ArrayPrint(zIntSLows);
   //ArrayPrint(zArrTop);
   //ArrayPrint(zArrBot);
   //Print("zArrPbHigh"); ArrayPrint(zArrPbHigh); 
   //Print("zArrPbLow"); ArrayPrint(zArrPbLow);
   
//   Print("zPoiExtremeHigh: "); ArrayPrint(zPoiExtremeHigh);
//   Print("zPoiExtremeLow: "); ArrayPrint(zPoiExtremeLow);
//   
//   Print("zPoiDecisionalHigh: "); ArrayPrint(zPoiDecisionalHigh);
//   Print("zPoiDecisionalLow: "); ArrayPrint(zPoiDecisionalLow);
   
}

void realGannWave() {
   string text = "";
   MqlRates bar1, bar2, bar3;
   bar1 = rates[1];
   bar2 = rates[2];
   bar3 = rates[3];
   if (gComment) {
      text += "--------------Real Gann Wave----------------";
      text += "\n "+inInfoBar(bar1, bar2, bar3);
      text += "\n First: "+getValueTrend();
      Print(text);
   }
   
   int resultStructure = drawStructureInternal(bar1, bar2, bar3, disableComment);
   updatePointTopBot(bar1, bar2, bar3, disableComment);
   
   // POI
   getZoneValid();
   drawZone(bar1);
   
   setZone(bar1);
   if (gComment) {
      text = "\n Final: "+getValueTrend();
      text += "\n ------------------------------------------------------ End ---------------------------------------------------------\n";
      Print(text);
   }
   
}

void gannWave(){
   MqlRates bar1, bar2, bar3; 
   // danh dau vi tri bat dau
   createObj(waveRates[ArraySize(waveRates) - 1].time, waveRates[ArraySize(waveRates) - 1].low, 238, -1, clrRed, "Start");
   for (int j = ArraySize(waveRates) - 3; j >=0; j--){
      if (gComment) {
         Print("No:" + (string) j);
         Print(inInfoBar(bar1, bar2, bar3));
         Print("First: "+getValueTrend());
      }
      
      bar1 = waveRates[j];
      bar2 = waveRates[j+1];
      bar3 = waveRates[j+2];
      
      int resultStructure = drawStructureInternal(bar1, bar2, bar3, disableComment);
      updatePointTopBot(bar1, bar2, bar3, disableComment);
      
      // POI
      getZoneValid();
      drawZone(bar1);
      
      setZone(bar1);
      
      if (gComment) {
         Print("\n Final: "+getValueTrend());
         Print(" ------------------------------------------------------ End ---------------------------------------------------------\n");
      }
      
   }
   // danh dau vi tri ket thuc
   createObj(waveRates[0].time, waveRates[0].low, 238, -1, clrRed, "Stop");
}

void setZone(MqlRates& bar) {
   // kiem tra mitigation extreme zone
   // High
   checkMitigateZone(zPoiExtremeHigh, bar, 1,enabledComment);
   // Low
   checkMitigateZone(zPoiExtremeLow, bar, -1,enabledComment);
   //// kiem tra mitigation desicional zone
   //// High
   //checkMitigateZone(zPoiDecisionalHigh, bar, 1, enabledComment);
   //// Low
   //checkMitigateZone(zPoiDecisionalLow, bar, -1, enabledComment);
}

void checkMitigateZone(PoiZone& zone[], MqlRates& bar, int type, bool isComment = false) {
    string text = "";
    if (ArraySize(zone) > 0) {
      text += "Ton tai zone can check.";
      for(int i=ArraySize(zone) - 1;i >= 0;i--) {
         if (zone[i].mitigated == 0) {
            // Check High or Low
            if ((type == 1 && bar.high >= zone[i].low ) || (type == -1 && bar.low <=  zone[i].high)) {
               text += "\n Zone position is "+ (string) i+ " is type = "+ ((type == 1)? "High": "Low") + " mitigate with bar high:" + 
               (string) bar.high + "; bar low: " + (string) bar.low+ "; bar time: "+ (string) bar.time;  
               zone[i].mitigated = 1;
            }
         }
      }
      
    } else {
      text += "Khong ton tai phan tu Zone nao can check. Bo qua";
    }
    if (isComment) {
      //Print(text);
      //ArrayPrint(zone);
    }
}

void getZoneValid() {
   showComment();
   // Pre arr Decisional
   getDecisionalValue(disableComment);
   // Extreme Poi
   setValueToZone(1, zArrPbHigh, zPoiExtremeHigh, disableComment, "Extreme");
   setValueToZone(-1, zArrPbLow, zPoiExtremeLow, disableComment, "Extreme");
   // Decisional Poi
   setValueToZone(1, zArrDecisionalHigh, zPoiDecisionalHigh, disableComment, "Decisional");
   setValueToZone(-1, zArrDecisionalLow, zPoiDecisionalLow, disableComment, "Decisional");
}

void setValueToZone(int _type,PoiZone& zoneDefault[], PoiZone& zoneTarget[], bool isComment = false, string str_poi = ""){
   string text = "";
   // type = 1 is High, -1 is Low
   double priceKey = (_type == 1) ? zoneDefault[0].high : zoneDefault[0].low;
   datetime timeKey = zoneDefault[0].time;
   // check default has new value?? 
   if (ArraySize(zoneDefault) > 1 && priceKey != zoneTarget[0].priceKey && timeKey != zoneTarget[0].timeKey && priceKey != 0) {
      text += ( "--> "+ str_poi +" "+ (( _type == 1)? "High" : "Low") +". Xuat hien value: "+(string)priceKey+" co time: "+(string)timeKey+" moi. them vao Extreme Zone");
      int indexH; 
      MqlRates barH;
      
      int result = -1;
      indexH = iBarShift(_Symbol, Timeframe, timeKey, true);
      if (indexH != -1) {
         // result = -1 => is nothing; result = 0 => is Default; result = index => update
         result = isFVG(indexH, _type); // High is type = 1 or Low is type = -1
         // set Value to barH
         if (result != -1) {
            getValueBar(barH, (result != 0) ? result : indexH);
            updatePointZone(barH, zoneTarget, false, poi_limit, priceKey, timeKey);
         }
      } else {
         text += ("Khong lam gi");
      }
      if(isComment) {
         Print(text);
      }
   }
}

//--- Set all value Index to Bar Default
void getValueBar(MqlRates& bar, int index) {
   bar.high = iHigh(_Symbol, Timeframe, index);
   bar.low = iLow(_Symbol, Timeframe, index);
   bar.open = iOpen(_Symbol, Timeframe, index);
   bar.close = iClose(_Symbol, Timeframe, index);
   bar.time = iTime(_Symbol, Timeframe, index);
   //Print("- Bar -"+index + " - "+ " High: "+ bar.high+" Low: "+bar.low + " Time: "+ bar.time);
}

//--- Return position bar on chart
int isFVG(int index, int type){ // type = 1 is High (Bearish) or type = -1 is Low (Bullish) 
   string text = "-------------- Check FVG";
   int indexOrigin = index;
   int result = -1;
   bool stop = false;
   MqlRates bar1, bar2, bar3;
   int i = 0;
   while(stop == false && index >=0) {
      text += "\n Number " + (string)i;
      // gia tri lay tu xa ve gan 
      getValueBar(bar1, index-2);
      getValueBar(bar2, index-1);
      getValueBar(bar3, index); // Bar current
      text += "\n bar 1: "+ " High: "+ (string) bar1.high + " Low: "+ (string) bar1.low;
      text += "\n bar 2: "+ " High: "+ (string) bar2.high + " Low: "+ (string) bar2.low;
      text += "\n bar 3: "+ " High: "+ (string) bar3.high + " Low: "+ (string) bar3.low;
      if (( type == -1 && bar1.high > arrTop[0]) || (type == 1 && bar1.low < arrBot[0])) { // gia vuot qua dinh gan nhat. Bo qua
         text += "\n gia vuot qua dinh, day gan nhat. Bo qua";
         result = 0;
         stop = true;
         break;
      }
      if (type == -1) { // Bull FVG
         if (  bar1.low > bar3.high && // has space
               bar2.close > bar3.high && bar1.close > bar1.open && bar3.close > bar3.open // is Green Bar
            ) {
            result = index;
            stop = true;
            text += "\n Bull FVG: Tim thay nen co FVG. High= "+ (string) bar1.high +" Low= "+(string)  bar1.low;
            break;
         }
      } else if (type == 1) { // Bear FVG 
         if (
            bar1.high < bar3.low && // has space
            bar2.close < bar3.low && bar1.close < bar1.open && bar3.close < bar3.open // is Red Bar
         ) {
            result = index;
            stop = true;
            text += "\n Bear FVG: Tim thay nen co FVG. High= "+ (string) bar1.high +" Low= "+ (string) bar1.low;
            break;
         }
      }
      if (stop == false) {
         i++;
         index--;
      }
   }
   //Print(text);
   return result;
}

void drawZone(MqlRates& bar1) {
   // IDM Live 
   if (sTrend == 1 && findLow == 0 && L_idmHigh != 0) {
      if (L_idmHigh > 0) {
         deleteObj(L_idmHighTime, L_idmHigh, 0, "");
         deleteLine(L_idmHighTime, L_idmHigh, IDM_TEXT_LIVE);
         deleteObj(L_idmHighTime, L_idmHigh, 0, IDM_TEXT_LIVE);
      }
      drawLine(IDM_TEXT_LIVE, idmHighTime, idmHigh, bar1.time, idmHigh, 1, IDM_TEXT_LIVE, clrAliceBlue, STYLE_DOT);
   }
   if (sTrend == -1 && findHigh == 0 && L_idmLow != 0) {
      if (L_idmLow > 0) {
         deleteObj(L_idmLowTime, L_idmLow, 0, "");
         deleteLine(L_idmLowTime, L_idmLow, IDM_TEXT_LIVE);
         deleteObj(L_idmLowTime, L_idmLow, 0, IDM_TEXT_LIVE);
      }
      drawLine(IDM_TEXT_LIVE, idmLowTime, idmLow, bar1.time, idmLow, -1, IDM_TEXT_LIVE, clrRed, STYLE_DOT);
   }
   
   // Extreme Zone.
   if (
      //sTrend == 1 && 
      ArraySize(zPoiExtremeHigh) > 0) { // care PB Low
      for(int i=0;i<ArraySize(zPoiExtremeHigh) - 1;i++) {
         //Print("zone "+ i);
         drawBox("ePOI", zPoiExtremeHigh[i].time, zPoiExtremeHigh[i].low, bar1.time, zPoiExtremeHigh[i].high,1, clrMaroon, 1);
      }
   }
   
   if (
      //sTrend == -1 && 
      ArraySize(zPoiExtremeLow) > 0) { // care PB High
      for(int i=0;i<ArraySize(zPoiExtremeLow) - 1;i++) {
         //Print("zone "+ i);
         drawBox("ePOI", zPoiExtremeLow[i].time, zPoiExtremeLow[i].high, bar1.time, zPoiExtremeLow[i].low,1, clrDarkGreen, 1);
      }
   }  
   
   // Decisional Zone.
   if (
      //sTrend == 1 && 
      ArraySize(zPoiDecisionalHigh) > 0) { // care PB Low
      for(int i=0;i<ArraySize(zPoiDecisionalHigh) - 1;i++) {
         //Print("zone "+ i);
         drawBox("dPOI", zPoiDecisionalHigh[i].time, zPoiDecisionalHigh[i].low, bar1.time, zPoiDecisionalHigh[i].high,1, clrSaddleBrown, 1);
      }
   }
   
   if (
      //sTrend == -1 && 
      ArraySize(zPoiDecisionalLow) > 0) { // care PB High
      for(int i=0;i<ArraySize(zPoiDecisionalLow) - 1;i++) {
         //Print("zone "+ i);
         drawBox("dPOI", zPoiDecisionalLow[i].time, zPoiDecisionalLow[i].high, bar1.time, zPoiDecisionalLow[i].low,1, clrDarkBlue, 1);
      }
   }  
   
}

// Todo: dang setup chua xong, can verify Decisinal POI moi khi chay. Luu gia tri High, Low vao 1 gia tri cố định để so sánh
// 
void getDecisionalValue(bool isComment = false) {
   string text = "Function getDecisionalValue:";
   // High
   if (ArraySize(intSHighs) > 1 && arrDecisionalHigh[0] != intSHighs[1]) {
      text += "\n Checking intSHighs[1]: "+ (string) intSHighs[1];
      // intSHigh[1] not include Extrempoi
      int isExist = -1;
      if (ArraySize(arrPbHigh) > 0) {
         isExist = checkExist(intSHighs[1], arrPbHigh);
         text += ": Tim thay vi tri "+(string) isExist+" trong arrPbHigh. (Extreme)";
      }
      // Neu khong phai la extreme POI. update if isExist == -1
      if (isExist == -1) {
         updatePointStructure(intSHighs[1], intSHighTime[1], arrDecisionalHigh, arrDecisionalHighTime, false, poi_limit);
         // Get Bar Index
         MqlRates iBar;
         int indexH = iBarShift(_Symbol, Timeframe, intSHighTime[1], true);
         if (indexH != -1) {
            getValueBar(iBar, indexH);
            updatePointZone(iBar, zArrDecisionalHigh, false, poi_limit);
         }
      } else {
         text += "\n Da ton tai o vi tri : "+(string) isExist+" trong arrPbHigh. Bo qua.";
      }
   }
   
   // Low
   if (ArraySize(intSLows) > 1 && arrDecisionalLow[0] != intSLows[1]) {
      text += "\n Checking intSLows[1]: "+ (string) intSLows[1];
      // intSLow[1] not include Extrempoi
      int isExist = -1;
      if (ArraySize(arrPbLow) > 0) {
         isExist = checkExist(intSLows[1], arrPbLow);
         text += ": Tim thay vi tri "+(string) isExist+" trong arrPbLow. (Extreme)";
      }
      // Neu khong phai la extreme POI. update if isExist == -1
      if (isExist == -1) {
         updatePointStructure(intSLows[1], intSLowTime[1], arrDecisionalLow, arrDecisionalLowTime, false, poi_limit);
         // Get Bar Index
         MqlRates iBar;
         int indexH = iBarShift(_Symbol, Timeframe, intSLowTime[1], true);
         if (indexH != -1) {
            getValueBar(iBar, indexH);
            updatePointZone(iBar, zArrDecisionalLow, false, poi_limit);
         }
      } else {
         text += "\n Da ton tai o vi tri : "+(string) isExist+" trong arrPbLow. Bo qua.";
      }
   }
   if (isComment) Print(text);
}

int checkExist(double value, double& array[]){
   int checkExist = -1;
   if (ArraySize(array) > 0) {
      for(int i=0;i<ArraySize(array);i++) {
         if (array[i] == value) {
            checkExist = i;
            break;
         }
      }
   }
   return checkExist;
}

void updatePointTopBot(MqlRates& bar1, MqlRates& bar2, MqlRates& bar3, bool isComment = false){
   string text;
   text += "\n"+inInfoBar(bar1, bar2, bar3);
   
   double barHigh = bar1.high;
   double barLow  = bar1.low;
   datetime barTime = bar1.time;
   
   // Lan dau tien
   if(sTrend == 0 && mTrend == 0 && LastSwingMajor == 0) {
      if (barLow < arrBot[0]){
         text += "\n 0.-1. barLow < arrBot[0]"+" => "+(string) barLow+" < "+(string) arrBot[0];
         text += " => Cap nhat idmLow = Highs[0] = "+(string) Highs[0]+"; sTrend = -1; mTrend = -1; LastSwingMajor = 1;";
         
         L_idmLow = idmLow;
         L_idmLowTime = idmLowTime;
         
         idmLow = Highs[0];
         idmLowTime = HighsTime[0];
         sTrend = -1; mTrend = -1; LastSwingMajor = 1;
         
      } else if (barHigh > arrTop[0]) { 
         text += "\n 0.1. barHigh > arrTop[0]"+" => "+(string) barHigh+" > "+(string) arrTop[0];
         text += " => Cap nhat idmHigh = Lows[0] = "+(string) Lows[0]+"; sTrend = 1; mTrend = 1; LastSwingMajor = -1;";
         
         L_idmHigh = idmHigh;
         L_idmHighTime = idmHighTime;
         
         idmHigh = Lows[0]; idmHighTime = LowsTime[0];
         sTrend = 1; mTrend = 1; LastSwingMajor = -1;
      }
   }
   // End Lan dau tien
   
   if (bar3.high < bar2.high && bar2.high > bar1.high) { // tim thay swing high
      text += "\n 0.2. Find Swing High";
      if (findHigh == 1 && bar2.high > H) {
         text += " => findhigh == 1 , H new > H old "+(string) bar2.high+" > "+(string) H+". Update new High = "+(string) bar2.high;
         
         H = bar2.high;
         HTime = bar2.time;
         H_bar = bar2;
      }
   }
   if (bar3.low > bar2.low && bar2.low < bar1.low) { // tim thay swing low 
      text += "\n 0.-2. Find Swing Low";
      if (findLow == 1 && bar2.low < L) {
         text += " => findlow == 1 , L new < L old "+(string) bar2.low+" < "+(string) L+". Update new Low = "+(string) bar2.low;
         
         L = bar2.low;
         LTime = bar2.time;
         L_bar = bar2;
      }
   }
   
   if(sTrend == 1 && mTrend == 1) {
      // continue BOS 
      if (LastSwingMajor == -1 && bar1.high > arrTop[0] && arrTop[0] != arrBoHigh[0]) {
         text += "\n 1.1. continue BOS, sTrend == 1 && mTrend == 1 && LastSwingMajor == -1 && bar1.high > arrTop[0] : "
         +(string)  bar1.high +" > "+(string) arrTop[0];
         text += "\n => Cap nhat: findLow = 0, idmHigh = Lows[0] = "+(string) Lows[0]+" ; sTrend == 1; mTrend == 1; LastSwingMajor == 1;";
         
         updatePointStructure(arrTop[0], arrTopTime[0], arrBoHigh, arrBoHighTime, false);
         updatePointStructure(intSLows[0], intSLowTime[0], arrBot, arrBotTime, false);
         // update POI Bullish
         updateZoneToZone(zIntSLows[0], zArrBot, false, poi_limit);
         // cap nhat Zone
         updateZoneToZone(zIntSLows[0], zPoiLow, false, poi_limit);
         
         L_idmHigh = idmHigh;
         L_idmHighTime = idmHighTime;
         
         sTrend = 1; mTrend = 1; LastSwingMajor = 1;
         findLow = 0; idmHigh = Lows[0]; idmHighTime = LowsTime[0];
         
         // touch idm
         touchIdmHigh = 0; touchIdmLow = 0;
      }
      
      if (bar3.high < bar2.high && bar2.high > bar1.high) { // tim thay dinh high 
         // continue BOS swing high
         if (LastSwingMajor == 1 && bar2.high > arrTop[0]) {
            text += "\n 1.2. swing high, sTrend == 1 && mTrend == 1 && LastSwingMajor == 1 && barHigh > arrTop[0]";
            text += "=> Cap nhat: arrTop[0] = bar2.high = "+(string) bar2.high+" ; sTrend == 1; mTrend == 1; LastSwingMajor == -1;";
            // Update Array Top[0]
            if(arrTop[0] != bar2.high) {
               updatePointStructure(bar2.high, bar2.time, arrTop, arrTopTime, false);
               // cap nhat Zone
               updatePointZone(bar2, zArrTop, false, poi_limit);
            } 
            
            sTrend = 1; mTrend = 1; LastSwingMajor = -1;
         }
         // HH > HH 
         if (LastSwingMajor == -1 && bar2.high > arrTop[0]) {
            text += "\n 1.3. sTrend == 1 && mTrend == 1 && LastSwingMajor == -1 && bar2.high > arrTop[0]";
            text += "=> Xoa label, Cap nhat: arrTop[0] = bar2.high = "+(string) bar2.high+" ; sTrend == 1; mTrend == 1; LastSwingMajor == -1;";
            
            // Update Array Top[0] , conditions : L new != L old
            if(arrTop[0] != bar2.high) {
               updatePointStructure(bar2.high, bar2.time, arrTop, arrTopTime, true);
               // cap nhat Zone
               updatePointZone(bar2, zArrTop, false, poi_limit);
            }
            sTrend = 1; mTrend = 1; LastSwingMajor = -1;
         }
      }
      
      //Cross IDM
      if (  
         //LastSwingMajor == 1 && 
         findLow == 0 && bar1.low < idmHigh) {
         text += "\n 1.4. Cross IDM Uptrend.  sTrend == 1 && mTrend == 1 && LastSwingMajor == random && bar1.low < idmHigh : " + (string) bar1.low + "<" + (string) idmHigh;
         // cap nhat arPBHighs
         if(arrTop[0] != arrPbHigh[0]) {
            updatePointStructure(arrTop[0], arrTopTime[0], arrPbHigh, arrPbHTime, false);
            // cap nhat Zone
            updateZoneToZone(zArrTop[0], zArrPbHigh, false);
         }
         drawPointStructure(1, arrPbHigh[0], arrPbHTime[0], MAJOR_STRUCTURE, false, enabledDraw);
         drawLine(IDM_TEXT, idmHighTime, idmHigh, bar1.time, idmHigh, 1, IDM_TEXT, clrAliceBlue, STYLE_DOT);
         text += "\n => Cap nhat findLow = 1; L = bar1.low = "+ (string) bar1.low;
         
         // active find Low
         findLow = 1; 
         L = bar1.low; LTime = bar1.time;
         L_bar = bar1;
         findHigh = 0; H = 0;
         
         touchIdmHigh = 1;
      }
      
      // CHoCH Low
      if (
         //LastSwingMajor == 1 && 
         bar1.low < arrPbLow[0] && arrPbLow[0] != arrChoLow[0]) {
         text += "\n 1.5 sTrend == 1 && mTrend == 1 && LastSwingMajor == random && bar1.low < arrPbLow[0] :" +(string)  bar1.low + "<" + (string) arrPbLow[0];
         text += "\n => Cap nhat => Ve line. sTrend = -1; mTrend = -1; LastSwingMajor = -1; findHigh = 0; idmLow = Highs[0]= "+ (string) Highs[0];
         // draw choch Low
         drawLine(CHOCH_TEXT, arrPbLTime[0], arrPbLow[0], barTime, arrPbLow[0], 1, CHOCH_TEXT, clrRed, STYLE_SOLID);
         
         updatePointStructure(arrPbLow[0], arrPbLTime[0], arrChoLow, arrChoLowTime, false);
         text += "\n => Cap nhat => POI Bearish : arrPbHigh[0] "+ (string) arrPbHigh[0];
         
         LastSwingMajor = -1;
         L_idmLow = idmLow;
         L_idmLowTime = idmLowTime;
         
         sTrend = -1; mTrend = -1; LastSwingMajor = -1;
         findHigh = 0; idmLow = Highs[0]; idmLowTime = HighsTime[0];
         
         // touch idm
         touchIdmHigh = 0; touchIdmLow = 0;
      }
      
      // continue Up, Continue BOS up
      if (
         //LastSwingMajor == -1 && 
         bar1.high > arrPbHigh[0] && arrPbHigh[0] != arrChoHigh[0]) {
         text += "\n 1.6 Continue Bos UP. sTrend == 1 && mTrend == 1 && LastSwingMajor == random && bar1.high > arrPbHigh && arrPbHigh: "+ (string) arrPbHigh[0] + " != arrChoHigh[0]: "+(string) arrChoHigh[0];
         
         updatePointStructure(arrPbHigh[0], arrPbHTime[0], arrChoHigh, arrChoHighTime, false);
         
         // update Point HL
         if (L != 0 && L != arrPbLow[0]) {
            updatePointStructure(L, LTime, arrPbLow, arrPbLTime, false);
            // update Zone
            updatePointZone(L_bar, zArrPbLow, false, poi_limit);  
         }
         text += "\n => cap nhat : POI Bullish L : "+(string) L;
         
         
         drawPointStructure(-1, arrPbLow[0], arrPbLTime[0], MAJOR_STRUCTURE, false, enabledDraw);
         drawLine(BOS_TEXT, arrPbHTime[0], arrPbHigh[0], bar1.time, arrPbHigh[0], -1, BOS_TEXT, clrAliceBlue, STYLE_SOLID);
         
         L_idmHigh = idmHigh;
         L_idmHighTime = idmHighTime;
         
         findLow = 0; idmHigh = Lows[0]; idmHighTime = LowsTime[0];
         L = 0; 
         
         // touch idm
         touchIdmHigh = 0; touchIdmLow = 0;
      }
   }

   if(sTrend == 1 && mTrend == -1) {
      // continue Up, Continue Choch up
      if (LastSwingMajor == -1 && bar1.high > arrPbHigh[0] && arrPbHigh[0] != arrChoHigh[0]) {
         text += "2.1 CHoCH up. sTrend == 1 && mTrend == -1 && LastSwingMajor == -1 && bar1.high > arrPbHigh[0]";
         
         updatePointStructure(arrPbHigh[0], arrPbHTime[0], arrChoHigh, arrChoHighTime, false);
         
         if (L != 0 && L != arrPbLow[0]) {
            updatePointStructure(L, LTime, arrPbLow, arrPbLTime, false);
            // update Zone
            updatePointZone(L_bar, zArrPbLow, false, poi_limit);
         }
         drawPointStructure(-1, arrPbLow[0], arrPbLTime[0], MAJOR_STRUCTURE, false, enabledDraw);
         drawLine(CHOCH_TEXT, arrPbHTime[0], arrPbHigh[0], bar1.time, arrPbHigh[0], -1, CHOCH_TEXT, clrAliceBlue, STYLE_SOLID);
         text += "\n => Cap nhat => POI Bullish : L = "+ (string) L;
         
         L_idmHigh = idmHigh;
         L_idmHighTime = idmHighTime;
         
         findLow = 0; idmHigh = Lows[0]; idmHighTime = LowsTime[0];
         L = 0; 
         
         // touch idm
         touchIdmHigh = 0; touchIdmLow = 0;
      }
      // CHoCH DOwn. 
      if (LastSwingMajor == -1 && bar1.low < arrPbLow[0] && arrPbLow[0] != arrChoLow[0]) {
         text += "\n 2.2 sTrend == 1 && mTrend == -1 && LastSwingMajor == -1 && bar1.low < arrPbLow[0] : " + (string) bar1.low + "<" + (string) arrPbLow[0];
         text += "\n => Cap nhat => POI Low. sTrend = -1; mTrend = -1; LastSwingMajor = -1; findHigh = 0; idmLow = Highs[0] = "+(string) Highs[0];
         updatePointStructure(arrPbLow[0], arrPbLTime[0], arrChoLow, arrChoLowTime, false);
         // draw choch low
         drawLine(CHOCH_TEXT, arrPbLTime[0], arrPbLow[0], bar1.time, arrPbLow[0], 1, CHOCH_TEXT, clrRed, STYLE_SOLID);
                  
         L_idmLow = idmLow;
         L_idmLowTime = idmLowTime;
         
         sTrend = -1; mTrend = -1; LastSwingMajor = -1;
         findHigh = 0; idmLow = Highs[0]; idmLowTime = HighsTime[0];
         
         // touch idm
         touchIdmHigh = 0; touchIdmLow = 0;
      }
   }
   
   if(sTrend == -1 && mTrend == -1) {
      // continue BOS 
      if (LastSwingMajor == 1 && bar1.low < arrBot[0] && arrBot[0] != arrBoLow[0]) {
         text += "\n -3.1. continue BOS, sTrend == -1 && mTrend == -1 && LastSwingMajor == 1 && bar1.low < arrBot[0] : "+ (string) bar1.low +" > "+(string) arrBot[0];
         text += "\n => Cap nhat: findHigh = 0, idmLow = Highs[0] = "+(string) Highs[0]+" ; sTrend == -1; mTrend == -1; LastSwingMajor == -1;";
         
         updatePointStructure(arrBot[0], arrBotTime[0], arrBoLow, arrBoLowTime, false);
         updatePointStructure(intSHighs[0], intSHighTime[0], arrTop, arrTopTime, false);
         
         // update POI Bearish
         updateZoneToZone(zIntSHighs[0], zArrTop, false, poi_limit);
         // cap nhat Zone
         updateZoneToZone(zIntSHighs[0], zPoiHigh, false, poi_limit);
                  
         L_idmLow = idmLow;
         L_idmLowTime = idmLowTime;
         
         sTrend = -1; mTrend = -1; LastSwingMajor = -1;
         findHigh = 0; idmLow = Highs[0]; idmLowTime = HighsTime[0];
         
         // touch idm
         touchIdmHigh = 0; touchIdmLow = 0;
      }
      
      if (bar3.low > bar2.low && bar2.low < bar1.low) { // tim thay swing low 
         // continue BOS swing low
         if (LastSwingMajor == -1 && bar2.low < arrBot[0]) {
            text += "\n -3.2. swing low, sTrend == -1 && mTrend == -1 && LastSwingMajor == -1 && bar2.low < arrBot[0]";
            text += "=> Cap nhat: arrBot[0] = bar2.low = "+(string) bar2.low+" ; sTrend == -1; mTrend == -1; LastSwingMajor == 1;";
            
            // Update ArrayBot[0]
            if(arrBot[0] != bar2.low) {
               updatePointStructure(bar2.low, bar2.time, arrBot, arrBotTime, false);
               // cap nhat Zone
               updatePointZone(bar2, zArrBot, false, poi_limit);
            }
            sTrend = -1; mTrend = -1; LastSwingMajor = 1;
         }

         // LL < LL
         if (LastSwingMajor == 1 && bar2.low < arrBot[0]) {
            text += "\n -3.3. sTrend == -1 && mTrend == -1 && LastSwingMajor == 1 && bar2.low < arrBot[0]";
            text += "=> Xoa label, Cap nhat: arrBot[0] = bar2.low = "+(string) bar2.low+" ; sTrend == -1; mTrend == -1; LastSwingMajor == 1;";
            
            // Update ArrayBot[0]
            if(arrBot[0] != bar2.low) {
               updatePointStructure(bar2.low, bar2.time, arrBot, arrBotTime, true);
               // cap nhat Zone
               updatePointZone(bar2, zArrBot, false, poi_limit);
            }
            sTrend = -1; mTrend = -1; LastSwingMajor = 1;   
         }
      }
   
      //Cross IDM
      if (
         //LastSwingMajor == -1 && 
         findHigh == 0 && bar1.high > idmLow) {
         text += "\n -3.4. Cross IDM Downtrend, sTrend == -1 && mTrend == -1 && LastSwingMajor == random && bar1.high > idmLow :" + (string) bar1.high + ">" + (string) idmLow;
         // cap nhat arPBLows
         if(arrBot[0] != arrPbLow[0]){
            updatePointStructure(arrBot[0], arrBotTime[0], arrPbLow, arrPbLTime, false);
            // cap nhat Zone
            updateZoneToZone(zArrBot[0], zArrPbLow, false, poi_limit);
         } 
         drawPointStructure(-1, arrPbLow[0], arrPbLTime[0], MAJOR_STRUCTURE, false, enabledDraw);
         drawLine(IDM_TEXT, idmLowTime, idmLow, bar1.time, idmLow, -1, IDM_TEXT, clrRed, STYLE_DOT);
         text += "\n => Cap nhat findHigh = 1; H = bar1.high = "+ (string) bar1.high;
         
         // active find High
         findHigh = 1; 
         H = bar1.high; HTime = bar1.time;
         H_bar = bar1;
         findLow = 0; L = 0;
         
         // touch idm
         touchIdmLow = 1;
      }
      
      // CHoCH High
      if (
         //LastSwingMajor == -1 && 
         bar1.high > arrPbHigh[0] && arrPbHigh[0] != arrChoHigh[0]) {
         text += "\n -3.5 sTrend == -1 && mTrend == -1 && LastSwingMajor == random && bar1.high > arrPbHigh[0] :" + (string) bar1.high + ">" + (string) arrPbHigh[0];
         text += "\n => Cap nhat => sTrend = 1; mTrend = 1; LastSwingMajor = 1; findLow = 0; idmHigh = Lows[0] = "+(string) Lows[0];
         text += "\n => Cap nhat => POI Bullish = arrPbLow[0] : "+ (string) arrPbLow[0];
         updatePointStructure(arrPbHigh[0], arrPbHTime[0], arrChoHigh, arrChoHighTime, false);
         
         // draw choch high
         drawLine(CHOCH_TEXT, arrPbHTime[0], arrPbHigh[0], bar1.time, arrPbHigh[0], -1, CHOCH_TEXT, clrAliceBlue, STYLE_SOLID);
         
         LastSwingMajor = 1;
         L_idmHigh = idmHigh;
         L_idmHighTime = idmHighTime;
         
         sTrend = 1; mTrend = 1; LastSwingMajor = 1;
         findHigh = 0; idmHigh = Lows[0]; idmHighTime = LowsTime[0];
         
         // touch idm
         touchIdmHigh = 0; touchIdmLow = 0;
      }
      
      // continue Down, Continue BOS down
      if (
         //LastSwingMajor == 1 && 
         bar1.low < arrPbLow[0] && arrPbLow[0] != arrChoLow[0]) {
         text += "\n -3.6 sTrend == -1 && mTrend == -1 & LastSwingMajor == random && bar1.low < arrPbLow[0]";
         
         updatePointStructure(arrPbLow[0], arrPbLTime[0], arrChoLow, arrChoLowTime, false);
         
         // update Point LH         
         if (H != 0 && H != arrPbHigh[0]) {
            updatePointStructure(H, HTime, arrPbHigh, arrPbHTime, false);
            // update Zone
            updatePointZone(H_bar, zArrPbHigh, false, poi_limit);
         }
         drawPointStructure(1, arrPbHigh[0], arrPbHTime[0], MAJOR_STRUCTURE, false, enabledDraw);
         drawLine(BOS_TEXT, arrPbLTime[0], arrPbLow[0], bar1.time, arrPbLow[0], 1, BOS_TEXT, clrRed, STYLE_SOLID);
         text += "\n => Cap nhat => POI Bearish H:" + (string) H;
         
         L_idmLow = idmLow;
         L_idmLowTime = idmLowTime;
         
         findHigh = 0; idmLow = Highs[0]; idmHighTime = LowsTime[0]; H = 0;
         
         // touch idm
         touchIdmHigh = 0; touchIdmLow = 0;
      }
      
   }
   if (sTrend == -1 && mTrend == 1) {
      // continue Down, COntinue Choch down
      if (LastSwingMajor == 1 && bar1.low < arrPbLow[0] && arrPbLow[0] != arrChoLow[0]) {
         text += "\n -4.1 sTrend == -1 && mTrend == 1 && LastSwingMajor == 1 && bar1.low < arPbLow[0]";
         updatePointStructure(arrPbLow[0], arrPbLTime[0], arrChoLow, arrChoLowTime, false);
         
         if (H != 0 && H != arrPbHigh[0]) {
            updatePointStructure(H, HTime, arrPbHigh, arrPbHTime, false);
            // update zone
            updatePointZone(H_bar, zArrPbHigh, false, poi_limit);
         }
         drawPointStructure(1, arrPbHigh[0], arrPbHTime[0], MAJOR_STRUCTURE, false, enabledDraw);
         drawLine(CHOCH_TEXT, arrPbLTime[0], arrPbLow[0], bar1.time, arrPbLow[0], 1, CHOCH_TEXT, clrRed, STYLE_SOLID);
         
         text += "\n => Cap nhat => POI bearish H: "+(string) H;
         
         L_idmLow = idmLow;
         L_idmLowTime = idmLowTime;
         
         findHigh = 0; idmLow = Highs[0]; idmHighTime = LowsTime[0]; H = 0;
         // touch idm
         touchIdmHigh = 0; touchIdmLow = 0;
      }
      // CHoCH Up. 
      if (LastSwingMajor == 1 && bar1.high > arrPbHigh[0] && arrPbHigh[0] != arrChoHigh[0]) {
            
         text += "\n -4.2 sTrend == -1 && mTrend == 1 && LastSwingMajor == 1 && bar1.high > arrPbHigh[0] : " + (string) bar1.high + ">" +(string)  arrPbHigh[0];
         text += "\n => Cap nhat => sTrend = 1; mTrend = 1; LastSwingMajor = 1; findLow = 0; idmHigh = Lows[0] = "+(string) Lows[0];
         text += "\n => Cap nhat => POI Bullish = arrPbLow[0] : "+ (string) arrPbLow[0];
         updatePointStructure(arrPbHigh[0], arrPbHTime[0], arrChoHigh, arrChoHighTime, false);
         
         // draw choch low
         drawLine(CHOCH_TEXT, arrPbHTime[0], arrPbHigh[0], bar1.time, arrPbHigh[0], -1, CHOCH_TEXT, clrAliceBlue, STYLE_SOLID);

         L_idmHigh = idmHigh;
         L_idmHighTime = idmHighTime;
         
         sTrend = 1; mTrend = 1; LastSwingMajor = 1;
         findLow = 0; idmHigh = Lows[0]; idmHighTime = LowsTime[0];
         // touch idm
         touchIdmHigh = 0; touchIdmLow = 0;
      }
   }
   
   if(isComment) {
      text += "\n Last: STrend: "+ (string) sTrend + " - mTrend: "+(string) mTrend+" - LastSwingMajor: "+(string) LastSwingMajor+ " findHigh: "+(string) findHigh+" - idmHigh: "+(string) idmHigh+" findLow: "+(string) findLow+" - idmLow: "+(string) idmLow+" H: "+ (string) H +" - L: "+(string) L;
      Print(text);
      showComment();
   }
}

//---
//--- Ham cap nhat ve cau truc song gann, internal struct, major struct
//---
int drawStructureInternal(MqlRates& bar1, MqlRates& bar2, MqlRates& bar3, bool isComment = false) {
   int resultStructure = 0;
   string textGannHigh = "";
   string textGannLow = "";
   
   string textInternalHigh = "";
   string textInternalLow = "";
   
   string textTop = "";
   string textBot = "";
   
   int indexLastH = iBarShift(_Symbol,PERIOD_CURRENT,lastTimeH);
   int indexLastL = iBarShift(_Symbol,PERIOD_CURRENT,lastTimeL);
   
   // swing high
   if (bar3.high < bar2.high && bar2.high > bar1.high) { // tim thay dinh high
      textGannHigh += "\n" + "---> Find High: "+(string) bar2.high+" + Highest: "+ (string) highEst;
      // gann finding high
      if (LastSwingMeter == 1 || LastSwingMeter == 0) {
         // cap nhat high moi
         updatePointStructure(bar2.high, bar2.time, Highs, HighsTime, false);
         drawPointStructure(1, bar2.high, bar2.time, GANN_STRUCTURE, false, enabledDraw);
         LastSwingMeter = -1;
         // cap nhat Zone
         updatePointZone(bar2, zHighs, false, 10);
      }
      // gann finding low
      if (LastSwingMeter == -1) {
         // xoa high cu. viet high moi
         if (bar2.high > highEst) {
            // xoa high cu
            if (ArraySize(Highs) > 1) deleteObj(HighsTime[0], Highs[0], iWingding_gann_high, "");
            // cap nhat high moi
            updatePointStructure(bar2.high, bar2.time, Highs, HighsTime, true);
            drawPointStructure(1, bar2.high, bar2.time, GANN_STRUCTURE, true, enabledDraw);
            LastSwingMeter = -1;
            // cap nhat Zone
            updatePointZone(bar2, zHighs, true, 10);
         }
      }
      
      if (isComment) {
         Print(textGannHigh);
         ArrayPrint(Highs);
      }
      
      // Internal Structure
      textInternalHigh += "\n"+"---> Find Internal High: "+(string)  bar2.high +" ### So Sanh iTrend: " +(string) iTrend+", LastSwingInternal: "+(string) LastSwingInternal+ " , intSHighs[0]: "+ (string) intSHighs[0];
      textInternalHigh += "\n"+"lastTimeH: "+(string) lastTimeH+" lastH: "+ (string) lastH +" <----> "+" intSHighTime[0] "+(string) intSHighTime[0]+" intSHighs[0] "+ (string) intSHighs[0];
      // finding High
      
      // DONE 1
      // HH
      if ( (iTrend == 0 || (iTrend == 1 && LastSwingInternal == 1)) && bar2.high > intSHighs[0]){ // BOS
         // Update new intSHigh
         updatePointStructure(bar2.high, bar2.time, intSHighs, intSHighTime, false);
         drawPointStructure(1, bar2.high, bar2.time, INTERNAL_STRUCTURE, false, enabledDraw);
         
         iTrend = 1;
         LastSwingInternal = -1;
         resultStructure = 1;
         textInternalHigh += "\n"+"## High 1 BOS --> Update: "+ "iTrend: "+(string) iTrend + ", LastSwingInternal: "+ (string) LastSwingInternal+", Update intSHighs[0]: "+(string) bar2.high;
         // cap nhat Zone
         updatePointZone(bar2, zIntSHighs, false, 10);
      }
      
      // HH 2
      if (iTrend == 1 && LastSwingInternal == -1 && bar2.high > intSHighs[0] && bar2.high > intSHighs[1]){
         // Delete Label
         if (ArraySize(intSHighs) > 1) deleteObj(intSHighTime[0], intSHighs[0], iWingding_internal_high, "");
         // Update new intSHigh
         updatePointStructure(bar2.high, bar2.time, intSHighs, intSHighTime, true);
         drawPointStructure(1, bar2.high, bar2.time, INTERNAL_STRUCTURE, true, enabledDraw);
         
         iTrend = 1;
         LastSwingInternal = -1;
         resultStructure = 2;
         textInternalHigh += "\n"+"## High 2 --> Update: "+ "iTrend: "+(string) iTrend + ", LastSwingInternal: "+ (string) LastSwingInternal+", Update intSHighs[0]: "+(string) bar2.high + ", Xoa intSHighs[0] old: "+(string) intSHighs[0];
         // cap nhat Zone
         updatePointZone(bar2, zIntSHighs, true, 10);
         
      }
      
      // DONE 3
      if (iTrend == -1 && LastSwingInternal == 1 && bar2.high > intSHighs[0]) {  // CHoCH
         // update new intSHigh
         updatePointStructure(bar2.high, bar2.time, intSHighs, intSHighTime, false);
         drawPointStructure(1, bar2.high, bar2.time, INTERNAL_STRUCTURE, false, enabledDraw);
         
         iTrend = 1;
         LastSwingInternal = -1;
         resultStructure = 3;
         textInternalHigh += "\n"+"## High 3 CHoCH --> Update: "+ "iTrend: "+(string) iTrend + ", LastSwingInternal: "+(string)  LastSwingInternal+", Update intSHighs[0]: "+(string) bar2.high;
         
         // cap nhat Zone
         updatePointZone(bar2, zIntSHighs, false, 10);
      }
      
      // DONE 4 
      // LH
      if (iTrend == -1 && LastSwingInternal == 1 && bar2.high < intSHighs[0]) { 
         // update new intSHigh
         updatePointStructure(bar2.high, bar2.time, intSHighs, intSHighTime, false);
         drawPointStructure(1, bar2.high, bar2.time, INTERNAL_STRUCTURE, false, enabledDraw);
         iTrend = -1;
         LastSwingInternal = -1;
         resultStructure = 4;
         textInternalHigh += "\n"+ "## High 4 --> Update: "+ "iTrend: "+(string) iTrend + ", LastSwingInternal: "+(string)  LastSwingInternal+", Update intSHighs[0]: "+(string) bar2.high;
         
         // cap nhat Zone
         updatePointZone(bar2, zIntSHighs, false, 10);
      }
      
      // DONE 5
      if (iTrend == -1 && LastSwingInternal == -1 && bar2.high > intSHighs[0] ) {    // CHoCH
         // Delete prev label
         if (ArraySize(intSHighs) > 1) deleteObj(intSHighTime[0], intSHighs[0], iWingding_internal_high, "");
         // Update new intSHigh
         updatePointStructure(bar2.high, bar2.time, intSHighs, intSHighTime, true);
         drawPointStructure(1, bar2.high, bar2.time, INTERNAL_STRUCTURE, true, enabledDraw);
                  
         iTrend = (bar2.high <= intSHighs[1])? -1 : 1;
         LastSwingInternal = -1;
         resultStructure = 5;
         textInternalHigh += "\n"+"## High 5 CHoCH --> Update: "+ "iTrend: "+(string) iTrend + ", LastSwingInternal: "+ (string) LastSwingInternal+", Update intSHighs[0]: "+(string) bar2.high+", Xoa intSHighs[0] old: "+(string) intSHighs[0];
         
         // cap nhat Zone
         updatePointZone(bar2, zIntSHighs, true, 10);
      }
      if( isComment) {
         Print(textInternalHigh);
         ArrayPrint(intSHighs);
      }
      
   }
   
   // swing low
   if (bar3.low > bar2.low && bar2.low < bar1.low) { // tim thay dinh low
      textGannLow += "\n"+"---> Find Low: +" +(string) bar2.low+ " + Lowest: "+(string) lowEst;
      // gann finding low
      if (LastSwingMeter == -1 || LastSwingMeter == 0) {
         // cap nhat low moi
         updatePointStructure(bar2.low, bar2.time, Lows, LowsTime, false);
         drawPointStructure(-1, bar2.low, bar2.time, GANN_STRUCTURE, false, enabledDraw);
         LastSwingMeter = 1;
         // cap nhat Zone
         updatePointZone(bar2, zLows, false, 10);
      }
      // gann finding high
      if (LastSwingMeter == 1) {
         // xoa low cu. viet high moi
         if (bar2.low < lowEst) {
            // xoa low cu
            if (ArraySize(Lows) > 1) deleteObj(LowsTime[0], Lows[0], iWingding_gann_low, "");
            // cap nhat low moi
            updatePointStructure(bar2.low, bar2.time, Lows, LowsTime, true);
            drawPointStructure(-1, bar2.low, bar2.time, GANN_STRUCTURE, true, enabledDraw);
            LastSwingMeter = 1;
            // cap nhat Zone
            updatePointZone(bar2, zLows, true, 10);
         }
      }
      if (isComment) {
         Print(textGannLow);
         ArrayPrint(Lows);
      }
      
      // Internal Structure 
      textInternalLow += "\n"+"---> Find Internal Low: "+ (string) bar2.low +" ### So Sanh iTrend: " +(string) iTrend+", LastSwingInternal: "+(string) LastSwingInternal+ " , intSLows[0]: "+ (string) intSLows[0];
      textInternalLow += "\n"+"lastTimeL: "+(string) lastTimeL+" lastL: "+(string)  lastL +" <----> "+" intSLowTime[0] "+(string) intSLowTime[0]+" intSLows[0] "+ (string) intSLows[0];
      // finding Low
      // DONE 1
      // LL
      if ((iTrend == 0 || iTrend == -1) && LastSwingInternal == -1 && bar2.low < intSLows[0]){ // BOS
         // Update new intSLows
         updatePointStructure(bar2.low, bar2.time, intSLows, intSLowTime, false);
         drawPointStructure(-1, bar2.low, bar2.time, INTERNAL_STRUCTURE, false, enabledDraw);
                  
         iTrend = -1;
         LastSwingInternal = 1;
         resultStructure = -1;
         textInternalLow += "\n"+("## Low 1 BOS --> Update: "+ "iTrend: "+(string) iTrend + ", LastSwingInternal: "+ (string) LastSwingInternal+", Update intSLows[0]: "+(string) bar2.low);
         // cap nhat Zone
         updatePointZone(bar2, zIntSLows, false, 10);
      }
      
      // LL
      if (iTrend == -1 && LastSwingInternal == 1 && bar2.low < intSLows[0] && bar2.low < intSLows[1]){
         // Delete Label
         if (ArraySize(intSLows) > 1) deleteObj(intSLowTime[0], intSLows[0], iWingding_internal_low, "");
         // Update new intSLows
         updatePointStructure(bar2.low, bar2.time, intSLows, intSLowTime, true);
         drawPointStructure(-1, bar2.low, bar2.time, INTERNAL_STRUCTURE, true, enabledDraw);
                  
         iTrend = -1;
         LastSwingInternal = 1;
         resultStructure = -2;
         textInternalLow += "\n"+("## Low 2 --> Update: "+ "iTrend: "+(string) iTrend + ", LastSwingInternal: "+ (string) LastSwingInternal+", Update intSLows[0]: "+(string) bar2.low +", Xoa intSLows[0] old: "+(string) intSLows[0]);
         // cap nhat Zone
         updatePointZone(bar2, zIntSLows, true, 10);
      }
      
      // DONE 3
      if (iTrend == 1 && LastSwingInternal == -1 && bar2.low < intSLows[0]) { // CHoCH
         // update intSLows
         updatePointStructure(bar2.low, bar2.time, intSLows, intSLowTime, false);
         drawPointStructure(-1, bar2.low, bar2.time, INTERNAL_STRUCTURE, false, enabledDraw);
         
         iTrend = -1;
         LastSwingInternal = 1;
         resultStructure = -3;
         textInternalLow += "\n"+("## Low 3 CHoCH --> Update: "+ "iTrend: "+(string) iTrend + ", LastSwingInternal: "+ (string) LastSwingInternal+", Update intSLows[0]: "+(string) bar2.low);
         // cap nhat Zone
         updatePointZone(bar2, zIntSLows, false, 10);
      }
      
      // DONE 4
      // Trend Tang. HL
      if (iTrend == 1 && LastSwingInternal == -1 && bar2.low > intSLows[0]) {
         updatePointStructure(bar2.low, bar2.time, intSLows, intSLowTime, false);
         drawPointStructure(-1, bar2.low, bar2.time, INTERNAL_STRUCTURE, false, enabledDraw);
         iTrend = 1;
         LastSwingInternal = 1;
         resultStructure = -4;
         textInternalLow += "\n"+("## Low 4 --> Update: "+ "iTrend: "+(string) iTrend + ", LastSwingInternal: "+ (string) LastSwingInternal+", Update intSLows[0]: "+(string) bar2.low);
         // cap nhat Zone
         updatePointZone(bar2, zIntSLows, false, 10);
      }
      
      // DONE 5
      if (iTrend == 1 && LastSwingInternal == 1 && bar2.low < intSLows[0] ) {  // CHoCH
         // Delete Label
         if (ArraySize(intSLows) > 1) deleteObj(intSLowTime[0], intSLows[0], iWingding_internal_low, "");
         // update intSLows
         updatePointStructure(bar2.low, bar2.time, intSLows, intSLowTime, true);
         drawPointStructure(-1, bar2.low, bar2.time, INTERNAL_STRUCTURE, true, enabledDraw);
                  
         iTrend = (bar2.low >= intSLows[1]) ? 1 : -1;
         LastSwingInternal = 1;
         resultStructure = -5;
         textInternalLow += "\n"+("## Low 5 CHoCH --> Update: "+ "iTrend: "+(string) iTrend + ", LastSwingInternal: "+ (string) LastSwingInternal+", Update intSLows[0]: "+(string) bar2.low+", Xoa intSLows[0] old: "+(string) intSLows[0]);
         // cap nhat Zone
         updatePointZone(bar2, zIntSLows, true, 10);
      }
      if(isComment) {
         Print(textInternalLow);
         ArrayPrint(intSLows);
      }
   }
   
   // Check Break Highest or Lowest value status 
   // Check break high
   if (bar1.high > highEst && isBarBreak(bar1, bar2, 1)) {
      gTrend = (gTrend > 0) ? 2: 1;
   }
   // Check break low
   if (bar1.low < lowEst && isBarBreak(bar1, bar2, -1)) {
      gTrend = (gTrend < 0) ? -2: -1;
   }
   
   return resultStructure;
}

void drawPointStructure(int itype, double priceNew, datetime timeNew, int typeStructure, bool del, bool isDraw) { // type: 1 High, -1 Low
   int iWingding;
   color iColor;
   // Color and wingdings
   if (typeStructure == GANN_STRUCTURE) {
      iWingding  = (itype == 1)? iWingding_gann_high : iWingding_gann_low;
      iColor   = (itype == 1)? clrDeepSkyBlue : clrYellow;
   } else if (typeStructure == INTERNAL_STRUCTURE) {
      iWingding  = (itype == 1)? iWingding_internal_high : iWingding_internal_low;
      iColor   = (itype == 1)? clrRoyalBlue : clrLightSalmon;
   } else if (typeStructure == INTERNAL_STRUCTURE_KEY){
      iWingding  = (itype == 1)? iWingding_internal_high : iWingding_internal_low;
      iColor   = (itype == 1)? clrGreen : clrRed;
   }else if (typeStructure == MAJOR_STRUCTURE) {
      iWingding  = (itype == 1)? 116 : 116;
      iColor   = (itype == 1)? clrForestGreen : clrRed;
   }
   
   string text    = (itype == 1)? "Update High" : "Update Low";
   int iDirection = (itype == 1)? -1 : 1;
   //Print(text +" Type: "+ itype + " , Xoa swing: "+ (string) del);
   
   if (isDraw) {
      createObj(timeNew, priceNew, iWingding, iDirection, iColor, "");
   }
   // update High, Low for gann swing
   if (itype == 1) { // find high
      highEst = priceNew;
   } else if(itype == -1) { // find low
      lowEst = priceNew;
   }
   // Update Bartime high, low for BOS, CHOCH internal struct
   if (typeStructure == INTERNAL_STRUCTURE) {
      if (itype == 1) { // find high
         lastTimeH = timeNew;
         lastH = priceNew;
      } else if (itype == -1) { // find low
         lastTimeL = timeNew;
         lastL = priceNew;
      }
   }
}

void updateZoneToZone(PoiZone& zone, PoiZone& array[], bool del, int limit = 20) {
   if (ArraySize(array) >= 1 && del == true) {
      // cap nhat lai arPrice
      ArrayRemove(array, 0, 1);
   }
   // Store value in array[]
   // shift existing elements in array[] to make space for the new value
   ArrayResize(array, MathMin(ArraySize(array) + 1, limit));
   for(int i = ArraySize(array) - 1; i > 0; --i) {
      array[i] = array[i-1];   
   }
   // Store newvalue in arPrice[0], the first position
   array[0] = zone;
}

void updatePointZone(MqlRates& bar, PoiZone& array[], bool del, int limit = 30, double priceKey = -1, datetime timeKey = -1) {
   if (ArraySize(array) >= 1 && del == true) {
      // cap nhat lai arPrice
      ArrayRemove(array, 0, 1);
   }
   // Store value in array[]
   // shift existing elements in array[] to make space for the new value
   ArrayResize(array, MathMin(ArraySize(array) + 1, limit));
   for(int i = ArraySize(array) - 1; i > 0; --i) {
      array[i] = array[i-1];   
   }
   // Store newvalue in arPrice[0], the first position
   array[0].high = bar.high;
   array[0].low = bar.low;
   array[0].open = bar.open;
   array[0].close = bar.close;
   array[0].time = bar.time;
   array[0].mitigated = 0;
   array[0].priceKey = priceKey;
   array[0].timeKey = timeKey;
}

void updatePointStructure(double priceNew, datetime timeNew, double& arPrice[], datetime& arTime[], bool del, int limit = 10) {
   if (ArraySize(arPrice) >= 1 && del == true) {
      // cap nhat lai arPrice
      ArrayRemove(arPrice, 0, 1);
      ArrayRemove(arTime, 0, 1);
   }
   
   // Store value in arPrice[]
   // shift existing elements in arPrice[] to make space for the new value
   ArrayResize(arPrice, MathMin(ArraySize(arPrice) + 1, limit));
   for(int i = ArraySize(arPrice) - 1; i > 0; --i) {
      arPrice[i] = arPrice[i-1];   
   }
   // Store newvalue in arPrice[0], the first position
   arPrice[0] = priceNew;
   
   // Store newtime in arTime[]
   // shift existing elements in arTime[] to make space for the new value
   ArrayResize(arTime, MathMin(ArraySize(arTime) + 1, limit));
   for(int i = ArraySize(arTime) - 1; i > 0; --i) {
      arTime[i] = arTime[i-1];   
   }
   // Store newtime in arTime[0], the first position
   arTime[0] = timeNew;
}

//+--------------------------------Draw Box ----------------------------------+
void drawBox(string name, datetime time_start, double price_start, datetime time_end, double price_end, int style, color box_color, int width = 1) {
   string objName = name+TimeToString(time_start);
   if(ObjectFind(0, objName) < 0)
      ObjectCreate(0, objName, OBJ_RECTANGLE, 0, time_start, price_start, time_end, price_end);
   //--- set line color
   ObjectSetInteger(0, objName, OBJPROP_COLOR, box_color);
   //--- set line display style
   ObjectSetInteger(0, objName, OBJPROP_STYLE, STYLE_SOLID);
   //--- enable (true) or disable (false) the mode of filling the rectangle 
   ObjectSetInteger(0,objName,OBJPROP_FILL, true); 
   //--- display in the foreground (false) or background (true) 
   ObjectSetInteger(0,objName,OBJPROP_BACK,true); 
   //--- set line width
   ObjectSetInteger(0, objName, OBJPROP_WIDTH, width);
}


//+------------------------------- Draw Line -----------------------------------+
void drawLine(string name, datetime  time_start, double price_start, datetime time_end, double price_end, int direction, string displayName, color iColor, int styleDot){
   string objname = name + TimeToString(time_start);
   if (ObjectFind(0, objname) < 0) {
      ObjectCreate(0, objname, OBJ_TREND, 0, time_start, price_start, time_end, price_end);
      ObjectSetInteger(0, objname, OBJPROP_COLOR, iColor);
      ObjectSetInteger(0, objname, OBJPROP_WIDTH, 1);
      if (styleDot == STYLE_DASH) {
         ObjectSetInteger(0, objname, OBJPROP_STYLE, STYLE_DASH);
      } else if (styleDot == STYLE_DASHDOT) {
         ObjectSetInteger(0, objname, OBJPROP_STYLE, STYLE_DASHDOT);
      } else if (styleDot == STYLE_DASHDOTDOT) {
         ObjectSetInteger(0, objname, OBJPROP_STYLE, STYLE_DASHDOTDOT);
      } else if (styleDot == STYLE_DOT) {
         ObjectSetInteger(0, objname, OBJPROP_STYLE, STYLE_DOT);
      } else if (styleDot == STYLE_SOLID) {
         ObjectSetInteger(0, objname, OBJPROP_STYLE, STYLE_SOLID);
      }
       
      createObj(time_start, price_start, 0, direction, iColor, displayName);
   }
}

//+------------------------------------------------------------------+
void createObj(datetime _time, double price, int arrowCode, int direction, color clr, string txt)
  {
   string objName ="";
   StringConcatenate(objName, "Signal@", _time, "at", DoubleToString(price, _Digits), "(", arrowCode, ")");

   double ask=SymbolInfoDouble(Symbol(), SYMBOL_ASK);
   double bid=SymbolInfoDouble(Symbol(), SYMBOL_BID);
   double spread=ask-bid;

   if(direction > 0){
      price -= _PointSpace*spread * _Point;
   } else if(direction < 0){
      price += _PointSpace*spread * _Point;
   }

   if(ObjectCreate(0, objName, OBJ_ARROW, 0, time, price))
     {
      ObjectSetInteger(0, objName, OBJPROP_ARROWCODE, arrowCode);
      ObjectSetInteger(0, objName, OBJPROP_COLOR, clr);
      if( direction > 0)
         ObjectSetInteger(0, objName, OBJPROP_ANCHOR, ANCHOR_TOP);
      if(direction < 0)
         ObjectSetInteger(0, objName, OBJPROP_ANCHOR, ANCHOR_BOTTOM);
   }
   string objNameDesc = objName + txt;
   if (ObjectCreate(0, objNameDesc, OBJ_TEXT, 0, _time, price)) {
      ObjectSetString(0, objNameDesc, OBJPROP_TEXT, " "+txt);
      ObjectSetInteger(0, objNameDesc, OBJPROP_COLOR, clr);
      if( direction > 0)
         ObjectSetInteger(0, objNameDesc, OBJPROP_ANCHOR, ANCHOR_TOP);
      if(direction < 0)
         ObjectSetInteger(0, objNameDesc, OBJPROP_ANCHOR, ANCHOR_BOTTOM);
   }
}

//+------------------------------------------------------------------+
//| Function to delete objects created by createObj                   |
//+------------------------------------------------------------------+
void deleteObj(datetime _time, double price, int arrowCode, string txt) {
   // Create the object name using the same format as createObj
   string objName = "";
   StringConcatenate(objName, "Signal@", _time, "at", DoubleToString(price, _Digits), "(", arrowCode, ")");
   
   // Delete the arrow object
   if(ObjectFind(0, objName) != -1) // Check if the object exists
     {
      ObjectDelete(0, objName);
     }
   
   // Create the description object name
   string objNameDesc = objName + txt;
   
   // Delete the text object
   if(ObjectFind(0, objNameDesc) != -1) // Check if the object exists
     {
      ObjectDelete(0, objNameDesc);
     }
}

//+------------------------------------------------------------------+
//| Function to delete line created by drawline                      |
//+------------------------------------------------------------------+
void deleteLine(datetime _time, double price, string name) {
   // Create the object name using the same format as drawline
   string objName = name + TimeToString(_time);
   //StringConcatenate(objName, "Signal@", time, "at", DoubleToString(price, _Digits), "(", arrowCode, ")");
   
   // Delete the arrow object
   if(ObjectFind(0, objName) != -1) // Check if the object exists
     {
      ObjectDelete(0, objName);
     }
}

bool IsNewBar(){
   static datetime previousTime = 0;
   datetime currentTime = iTime(_Symbol, Timeframe, 0);
   if (previousTime != currentTime) {
      previousTime = currentTime; 
      return true;
   }
   return false;
}

bool IsLastBar() {
    return (rates[0].time == TimeCurrent());
}


//#region Inside Bar
//bool isb() {
//   high = iHigh(_Symbol, PERIOD_CURRENT, 1);
//   low = iLow(_Symbol, PERIOD_CURRENT, 1);
//   return (motherHigh > high && motherLow < low) ? true : false;
//}

// type = 1: check Break High , type = -1: check Break Low
bool isBarBreak(MqlRates& bar1, MqlRates& bar2, int type) {
   bool result = false;
   //if ((type == 1 && bar1.close > bar2.high) || (type == -1 && bar1.close < bar2.low) ) { // Body break
   if ((type == 1 && bar1.high > bar2.high) || (type == -1 && bar1.low < bar2.low) ) { // wick break
      result = true;
   }
   return result;
}

void TrailStop() {
   double sl = 0;
   double tp = 0;
   
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   for (int i = PositionsTotal() - 1; i>=0; i--) {
      if (posinfo.SelectByIndex(i)) {
         ulong ticket = posinfo.Ticket();
         if ( posinfo.Magic() == InpMagic && posinfo.Symbol() == _Symbol) {
            if (posinfo.PositionType() == POSITION_TYPE_BUY) {
               if(bid - posinfo.PriceOpen() > (TslTriggerPoints*_Point)) {
                  tp = posinfo.TakeProfit();
                  sl = bid - (TslPoints * _Point);
                  if (sl > posinfo.StopLoss() && sl != 0) {
                     Print(dotSpace+" Modify Buy: "+ "Sl: "+ DoubleToString(sl, Digits()));
                     trade.PositionModify(ticket,sl,tp);
                  }
               }
            } 
            else if (posinfo.PositionType() == POSITION_TYPE_SELL) {
               if (ask + (TslTriggerPoints * _Point) < posinfo.PriceOpen()) {
                  tp = posinfo.TakeProfit();
                  sl = ask + (TslPoints * _Point);
                  if (sl < posinfo.StopLoss() && sl != 0) {
                     Print(dotSpace+" Modify Sell: "+ "Sl: "+ DoubleToString(sl, Digits()));
                     trade.PositionModify(ticket,sl,tp);
                  }
               }
            }
         }
      }
   }
}

double showTotal() {
   MqlDateTime tm={};
   //get the time server
   datetime    time_server =TimeTradeServer(tm);
   // get the local time
   datetime ttime = TimeLocal();
   
   ////formart the time and create a string
   //string CurrentTime = TimeToString(time_server, TIME_MINUTES);
   
   int tonglenh = 0;
   int solenhbuy = 0;
   int solenhsell = 0;
   double profit = 0; 
   double lotBuy = 0;
   double lotSell =0;
   
   string text = 
         "Today is "+ EnumToString((ENUM_DAY_OF_WEEK)tm.day_of_week)+"\n"
         "Local Time = "+ (string) TimeToString(ttime, TIME_DATE) + " " +(string) TimeToString(ttime, TIME_SECONDS)+ "\n" 
         "Server Time  = " +  (string) time_server+"\n"+
         "Pair: "+_Symbol+" - "+ "Spread = "+ DoubleToString(SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID) , Digits()) +"\n"+
         "Trading Time = "+ (string) SHInput+ " -> "+ (string) EHInput+ " (Server Time)\n"+
         "---------" + "Settings EAs" + "---------" + "\n"+
         "Risk: " + (string)( (RiskPercent > 0) ? (string) RiskPercent + "% Balance" : "Fixed Lot: "+ (string) minVolume) + "\n"+
         "Take Profits: "+ DoubleToString(Tppoints*_Point, Digits()) + " Pip" + "\n"+
         "Stop Loss: "+ DoubleToString(Slpoints*_Point, Digits()) + " Pip" + "\n"+
         "Trigger Traling Stop: "+ DoubleToString(TslTriggerPoints*_Point, Digits()) + " Pip" + "\n"+
         "Traling Stop: "+ DoubleToString(TslPoints*_Point,Digits()) + " Pip" + "\n"+
         dotSpace+ "\n";
         
   string _text = "Running/ Pending Orders: "+ IntegerToString(PositionsTotal()) + "/ "+ IntegerToString(OrdersTotal());
   for(int i=0;i<=PositionsTotal()-1;i++) {
      ///_text += "\n Lenh :"+i+" : "+ PositionGetTicket(i);
      // neu khong select duoc ticket thi bo qua
      if(!PositionSelectByTicket(PositionGetTicket(i))) {
         continue;
      }
      // neu khong dung symbol dang chay thi bo qua
      string possym = PositionGetString(POSITION_SYMBOL); // eurusdc, usdjpy...
      if (possym != Symbol()) {
         continue;
      }
      ulong ticket = PositionGetInteger(POSITION_TICKET); // lay ticket cua order
      ulong type = -1; // int dinh dang lai
      type = PositionGetInteger(POSITION_TYPE); // loai lenh buy/ sell; type -> enum
      if(type == POSITION_TYPE_BUY) {
         solenhbuy ++;// solenhbuy = solenhbuy+1;
         lotBuy += PositionGetDouble(POSITION_VOLUME);
      }
      if(type == POSITION_TYPE_SELL) {
         solenhsell ++;// solenhsell = solenhsell+1;   
         lotSell += PositionGetDouble(POSITION_VOLUME);
      }
      profit += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
   }
   
   //_text += "\nSo lenh Buy: "+ (string) solenhbuy +"; Volume Buy: "+DoubleToString(lotBuy,2);
   //_text += "\nSo lenh Sell: "+ (string) solenhsell+"; Volume Sell: "+DoubleToString(lotSell,2);
   _text += "\nBalance: "+ DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE),2) +
            ". Equity: "+DoubleToString(AccountInfoDouble(ACCOUNT_EQUITY),2) +
            ". Profit: "+ DoubleToString(AccountInfoDouble(ACCOUNT_PROFIT),2) + "\n" + dotSpace+ "\n";
   _text += " Market Structure: \n";
   _text += " Trend: Major => " + ((sTrend == 1) ? " UpTrend": "DownTrend" );
   if (sTrend > 0) {
      _text += " ; Get IDM : " + ((touchIdmHigh == 1) ? "Yes": "No" );
   } else {
      _text += " ; Get IDM : " + ((touchIdmLow == 1) ? "Yes": "No" );
   }
   _text += " | minor trend => " + ((iTrend > 0) ? " iUpTrend": "iDownTrend" ) + (string) iTrend;
   _text += " | gtrend => " + ((gTrend > 0) ? " gUpTrend": "gDownTrend" );
   
   Comment(_text+ "\n "+ dotSpace +"\n"+ text);
   return profit;
}

// start Trade 
void beginTrade() {
   string text = "";
   MqlDateTime ttime;
   TimeToStruct(TimeCurrent(), ttime);
   
   int Hournow = ttime.hour;
   SHChoice = SHInput;
   EHChoice = EHInput;
   
   bool accept_trade = true;
   double cSpread = SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if (InpMaxSpread*_Point < cSpread) {
      ClosePending(1);
      ClosePending(-1);
      accept_trade = false;
      return;
   }
   
   if (Hournow < SHChoice && SHChoice != 0) {
      CloseAllOrders();
      accept_trade = false;
      return;
   }
   
   if (Hournow >= EHChoice && EHChoice != 0) {
      CloseAllOrders();
      accept_trade = false;
      return;
   }
   
   int BuyTotal = 0;
   int SellTotal = 0;
   int pendingBuy = 0;
   int pendingSell = 0;
  
   for (int i=OrdersTotal()-1; i>=0; i--){ 
      ordinfo.SelectByIndex(i);
      if (ordinfo.OrderType() == ORDER_TYPE_BUY_STOP && ordinfo.Symbol() == _Symbol && ordinfo.Magic() == InpMagic) {
         BuyTotal++;
         pendingBuy++;  
      }
      if (ordinfo.OrderType() == ORDER_TYPE_SELL_STOP && ordinfo.Symbol() == _Symbol && ordinfo.Magic() == InpMagic) {
         SellTotal++;
         pendingSell++;
      } 
      if (ordinfo.OrderType() == ORDER_TYPE_BUY_LIMIT && ordinfo.Symbol() == _Symbol && ordinfo.Magic() == InpMagic) {
         BuyTotal++;
         pendingBuy++;
      }
      if (ordinfo.OrderType() == ORDER_TYPE_SELL_LIMIT && ordinfo.Symbol() == _Symbol && ordinfo.Magic() == InpMagic) {
         SellTotal++;
         pendingSell++;
      }
   }
   
   for (int i=PositionsTotal()-1; i>=0; i--){
      posinfo.SelectByIndex(i);
      if(posinfo.PositionType() == POSITION_TYPE_BUY && posinfo.Symbol() == _Symbol && posinfo.Magic() == InpMagic) BuyTotal++; 
      if(posinfo.PositionType() == POSITION_TYPE_SELL && posinfo.Symbol() == _Symbol && posinfo.Magic() == InpMagic) SellTotal++;
   }
   
   // check wrong order 
   if (pendingBuy > 0 || pendingSell > 0) {
      // Neu kich hoat trade 1 chieu Marjor
      if (InpWayTrade == 1) {
         if (pendingBuy > 0) {
            if (sTrend > 0) {
               if (InpTrade == 0) { // Only Trade Marjor
                  if (touchIdmHigh == 0) {
                     ClosePending(1);
                  } else {
                     if (InpCpLowTF == 1) { // Co xac nhan LTF
                        if (gTrend < 0) {
                           ClosePending(1);
                        }
                     } 
//                     else if (InpCpLowTF == 0) { // Khong can xac nhan LTF
//                        
//                     }
                  }
                                    
               } else if (InpTrade == 1) { // Trade with Marjor and Minnor
                  if (InpCpLowTF == 1) { // Co xac nhan LTF
                     if (gTrend < 0) {
                        ClosePending(1);
                     }
                  } 
//                  else if (InpCpLowTF == 0) { // Khong can xac nhan LTF
//                     
//                  }
               }
               
            } else if (sTrend < 0){
               ClosePending(1);
            }
            
         }
         
         if (pendingSell > 0) {
            if (sTrend < 0) {
               if (InpTrade == 0) { // Only Trade Marjor
                  if (touchIdmLow == 0) {
                     ClosePending(-1);
                  } else {
                     if (InpCpLowTF == 1) { // Co xac nhan LTF
                        if (gTrend > 0) {
                           ClosePending(-1);
                        }
                     } 
//                     else if (InpCpLowTF == 0) { // Khong can xac nhan LTF
//                        
//                     }
                  }
                                    
               } else if (InpTrade == 1) { // Trade with Marjor and Minnor
                  if (InpCpLowTF == 1) { // Co xac nhan LTF
                     if (gTrend > 0) {
                        ClosePending(-1);
                     }
                  } 
//                  else if (InpCpLowTF == 0) { // Khong can xac nhan LTF
//                     
//                  }
               }
               
            } else if (sTrend > 0){
               ClosePending(-1);
            }
         }
//         
//         
//         if (pendingBuy > 0 && ( sTrend < 0 
//            //|| (InpTrade == 0 && gTrend < 0)  // 
//             || (InpTrade == 1 && gTrend < 0 && touchIdmHigh == 0)
//            )) {
//            // Close pending Buy
//            ClosePending(1);
//         } else if ( pendingSell > 0 && ( sTrend > 0 
//               //|| (InpTrade == 0 && gTrend > 0)
//               || (InpTrade == 1 && gTrend > 0 && touchIdmLow == 0)
//               )) {
//            // Close pending Sell
//            ClosePending(-1);
//         }
      } else if (InpWayTrade == 2) { // Neu kich hoat trade 2 chieu Marjor
         if (sTrend == 1) {
            if (pendingBuy > 0) {
               if (InpCpLowTF == 1) { // Co xac nhan LTF
                  if (gTrend < 0) {
                     ClosePending(1);
                  }
               }
            }
            
            if (pendingSell > 0) {
               // Neu chua quet IDM, huy toan bo lenh sell Marjor
               if (touchIdmHigh == 0) {
                  ClosePending(-1);
               }
               if (InpCpLowTF == 1) { // Co xac nhan LTF
                  if (gTrend > 0) {
                     ClosePending(-1);
                  }
               }
            }
         } else if(sTrend == -1){
            if (pendingSell > 0) {
               if (InpCpLowTF == 1) { // Co xac nhan LTF
                  if (gTrend > 0) {
                     ClosePending(-1);
                  }
               }
            }
            
            if (pendingBuy > 0) {
               // Neu chua quet IDM, huy toan bo lenh buy Marjor
               if (touchIdmLow == 0) {
                  ClosePending(1);
               }
               if (InpCpLowTF == 1) { // Co xac nhan LTF
                  if (gTrend < 0) {
                     ClosePending(1);
                  }
               }
            } 
         }
         
//         if (sTrend == 1 && touchIdmHigh == 0) {
//            ClosePending(-1);
//         }
//         
//         if (sTrend == -1 && touchIdmLow == 0) {
//            ClosePending(1);
//         }
         
      }
      
   }
   
   //Print("Begin Trade: \n"+ getValueTrend());
   //Print("accept_trade is: "+ (string) accept_trade + " Buy total: " + (string) BuyTotal + "; Sell Total: "+ (string) SellTotal);
   
   if (accept_trade) {
      if ( InpWayTrade == 1) { // Neu kich hoat trade 1 chieu Marjor
         if (BuyTotal <= 0) {
            // Tim marjor swing truoc. neu tra ve -1 thi tim minnor
            double tHigh = tFindHigh();
            if (tHigh > 0) { // neu tim thay dinh da quet idm
               SendBuyOrder(tHigh);
            } else { // neu chua tim thay dinh quet idm
               if (InpTrade == 1) { // neu cau truc vao lenh la minor
                  tHigh = tMinorFindHigh();
                  SendBuyOrder(tHigh);
               }
            }
         }
            
         if (SellTotal <= 0) {
            // Tim marjor swing truoc. neu tra ve -1 thi tim minnor
            double tLow = tFindLow();
            if (tLow > 0) {
               SendSellOrder(tLow);
            } else { // neu chua tim thay dinh quet idm
               if (InpTrade == 1) { // neu cau truc vao lenh la minor
                  tLow = tMinorFindLow();
                  SendSellOrder(tLow);
               }
            }
         }
      } else if ( InpWayTrade == 2) {  // Neu kich hoat trade 2 chieu Marjor
         if (BuyTotal <= 0) {
            if (sTrend == 1) {
               // Buy Marjor
               double tHigh = tFindHigh();
               if (tHigh > 0) {
                  SendBuyOrder(tHigh);
               } else { // neu chua tim thay dinh quet idm
                  if (InpTrade == 1) { // neu cau truc vao lenh la minor
                     tHigh = tMinorFindHigh();
                     SendBuyOrder(tHigh);
                  }
               }
            }
            if (sTrend == -1) {
               double tHigh = tGetHigh();
               if (tHigh > 0) {
                  SendBuyOrder(tHigh);
               }
            }
         }
         
         if (SellTotal <= 0) {
            if (sTrend == -1) {
               double tLow = tFindLow();
               if (tLow > 0) {
                  SendSellOrder(tLow);
               } else { // neu chua tim thay dinh quet idm
                  if (InpTrade == 1) { // neu cau truc vao lenh la minor
                     tLow = tMinorFindLow();
                     SendSellOrder(tLow);
                  }
               }
            }
            
            if (sTrend == 1) {
               double tLow = tGetLow();
               if (tLow > 0) {
                  SendSellOrder(tLow);
               }
            }
         }
      }
      
   }
   //text += "--------------- End Begin Trade -----------------";
   //Print(text);
}


void SendBuyOrder(double entry) {
   double ask = SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   if (ask > entry - OrderDistPoints * _Point) return;
   double tp = entry + Tppoints * _Point;
   double sl = entry - Slpoints * _Point;
   double lots = 0.01;
   if(RiskPercent > 0) lots = calcLots(entry - sl);
   datetime expiration = iTime(_Symbol, Timeframe, 0) + ExpirationBars * PeriodSeconds(Timeframe);
   trade.BuyStop(lots, entry, _Symbol, sl, tp, ORDER_TIME_SPECIFIED, expiration);
}

void SendSellOrder(double entry) {
   double bid = SymbolInfoDouble(_Symbol,SYMBOL_BID);
   if (bid < entry + OrderDistPoints * _Point) return;
   double tp = entry - Tppoints * _Point;
   double sl = entry + Slpoints * _Point;
   double lots = 0.01;
   if(RiskPercent > 0) lots = calcLots(sl - entry);
   datetime expiration = iTime(_Symbol, Timeframe, 0) + ExpirationBars * PeriodSeconds(Timeframe);
   trade.SellStop(lots, entry, _Symbol, sl, tp, ORDER_TIME_SPECIFIED, expiration);
}

double calcLots (double slPoints){
   double risk = AccountInfoDouble(ACCOUNT_BALANCE) * RiskPercent / 100;
   
   double ticksize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE); 
   double tickvalue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE); 
   double lotstep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP); 
   double minvolume=SymbolInfoDouble (Symbol(), SYMBOL_VOLUME_MIN); 
   double maxvolume=SymbolInfoDouble (Symbol(), SYMBOL_VOLUME_MAX); 
   double volumelimit = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_LIMIT);

   double moneyPerLotstep = slPoints / ticksize * tickvalue * lotstep; 
   double lots = MathFloor(risk / moneyPerLotstep) * lotstep;
   
   if(volumelimit!=0) lots = MathMin(lots, volumelimit);
   if(maxvolume!=0) lots = MathMin(lots, SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX)); 
   if(minvolume!=0) lots = MathMax (lots, SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN)); 
   lots = NormalizeDouble(lots,2);
   //Print("-------------> Lots: "+ lots);
   return lots;

}

// Close all pending is Buy or Sell
void ClosePending (int type) {
   for(int i = OrdersTotal() - 1; i >= 0; i--) { // loop all Orders
      if(ordinfo.SelectByIndex(i))  // select an order
        {
         if (ordinfo.Symbol() != _Symbol) continue;
         if (
               (type == 1 && ( ordinfo.OrderType() == ORDER_TYPE_BUY_STOP || ordinfo.OrderType() == ORDER_TYPE_BUY_LIMIT)) || 
               (type == -1 && ( ordinfo.OrderType() == ORDER_TYPE_SELL_STOP || ordinfo.OrderType() == ORDER_TYPE_SELL_LIMIT))
            ) {
               trade.OrderDelete(ordinfo.Ticket()); // then delete it --period
               Sleep(100); // Relax for 100 ms   
            }
        }
    }
}

void CloseAllOrders() {
   for(int i = PositionsTotal() - 1; i >= 0; i--) { // loop all Open Positions
      if(posinfo.SelectByIndex(i))  // select a position
        {
         trade.PositionClose(posinfo.Ticket()); // then close it --period
         Sleep(100); // Relax for 100 ms
        }
    }
//--End Đóng Positions

//--Đóng Orders
   for(int i = OrdersTotal() - 1; i >= 0; i--) { // loop all Orders
      if(ordinfo.SelectByIndex(i))  // select an order
        {
         trade.OrderDelete(ordinfo.Ticket()); // then delete it --period
         Sleep(100); // Relax for 100 ms
        }
    }
//--End Đóng Orders
//--Đóng Positions lần 2 cho chắc
   for(int i = PositionsTotal() - 1; i >= 0; i--) { // loop all Open Positions
      if(posinfo.SelectByIndex(i))  // select a position
        {
         trade.PositionClose(posinfo.Ticket()); // then close it --period
         Sleep(100); // Relax for 100 ms
        }
    }
}
// Marjor swing
double tFindHigh() {
   double tHigh = -1;
   // Bo qua confirm cau truc o Low TimeFrame
   if (InpCpLowTF == 0) {
      if (sTrend == 1 && touchIdmHigh == 1 && ArraySize(arrPbHigh) > 1 && arrPbHigh[0] >= intSHighs[0]) {
         tHigh = arrPbHigh[0];
      }
   } else if (InpCpLowTF == 1) { // Xac nhan confirm cau truc o Low TimeFrame
      if (sTrend == 1 && gTrend > 0 && touchIdmHigh == 1 && ArraySize(arrPbHigh) > 1 && arrPbHigh[0] >= intSHighs[0]) {
         tHigh = arrPbHigh[0];
      }
   }
   return tHigh;
}

double tFindLow() {
   double tLow = -1;
   // Bo qua confirm cau truc o Low TimeFrame
   if (InpCpLowTF == 0) {
      if (sTrend == -1 && touchIdmLow == 1 && ArraySize(arrPbLow) > 1 && arrPbLow[0] <= intSLows[0]) {
         tLow = arrPbLow[0];
      }
   } else if (InpCpLowTF == 1) { // Xac nhan confirm cau truc o Low TimeFrame
      if (sTrend == -1 && gTrend < 0 && touchIdmLow == 1 && ArraySize(arrPbLow) > 1 && arrPbLow[0] <= intSLows[0]) {
         tLow = arrPbLow[0];
      }
   }
   return tLow;
}

// Minnor Swing
double tMinorFindHigh() {
   double tHigh = -1;
   // Bo qua confirm cau truc o Low TimeFrame
   if (InpCpLowTF == 0) {
      if (sTrend == 1 && iTrend > 0 && touchIdmHigh == 0 && ArraySize(intSHighs) > 1) {
         tHigh = intSHighs[0];
      }
   } else if (InpCpLowTF == 1) { // Xac nhan confirm cau truc o Low TimeFrame
      if (sTrend == 1 && iTrend > 0 && gTrend > 0 && touchIdmHigh == 0 && ArraySize(intSHighs) > 1) {
         tHigh = intSHighs[0];
      }
   }
   return tHigh;
}

double tMinorFindLow() {
   double tLow = -1;
   // Bo qua confirm cau truc o Low TimeFrame
   if (InpCpLowTF == 0) {
      if (sTrend == -1 && iTrend < 0 && touchIdmLow == 0 && ArraySize(intSLows) > 1) {
         tLow = intSLows[0];
      }
   } else if (InpCpLowTF == 1) { // Xac nhan confirm cau truc o Low TimeFrame
      if (sTrend == -1 && iTrend < 0 && gTrend < 0 && touchIdmLow == 0 && ArraySize(intSLows) > 1) {
         tLow = intSLows[0];
      }
   }
   return tLow;
}

double tGetHigh() {
   double tHigh = -1;
   // Bo qua confirm cau truc o Low TimeFrame
   if (InpCpLowTF == 0) {
      if ((sTrend == 1 || (sTrend == -1 && touchIdmLow == 1)) && ArraySize(arrPbHigh) > 1 && arrPbHigh[0] >= intSHighs[0]) {
         tHigh = arrPbHigh[0];
      }
   } else if (InpCpLowTF == 1) { // Xac nhan confirm cau truc o Low TimeFrame
      if (gTrend == 1 && (sTrend == 1 || (sTrend == -1 && touchIdmLow == 1)) && ArraySize(arrPbHigh) > 1 && arrPbHigh[0] >= intSHighs[0]) {
         tHigh = arrPbHigh[0];
      }
   }
   return tHigh;
}

double tGetLow() {
   double tLow = -1;
   // Bo qua confirm cau truc o Low TimeFrame
   if (InpCpLowTF == 0) {
      if ((sTrend == -1 || (sTrend == 1 && touchIdmHigh == 1))&& ArraySize(arrPbLow) > 1 && arrPbLow[0] <= intSLows[0]) {
         tLow = arrPbLow[0];
      }
   } else if (InpCpLowTF == 1) { // Xac nhan confirm cau truc o Low TimeFrame
      if (gTrend == -1 && (sTrend == -1 || (sTrend == 1 && touchIdmHigh == 1))&& ArraySize(arrPbLow) > 1 && arrPbLow[0] <= intSLows[0]) {
         tLow = arrPbLow[0];
      }
   }
   return tLow;
}