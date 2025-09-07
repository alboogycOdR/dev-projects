
//|                                                    MasterEA.mq5 |
//|       Ported from TradingView strategy                          |
//|                                                                  |
//|  This EA executes trades on a prop account and writes hedge      |
//|  instructions for a second terminal.                             |
//+------------------------------------------------------------------+
#property copyright ""
#property version   "1.00"
#property strict

#include <Trade/Trade.mqh>
#include <Files/File.mqh>


#include <Dashboard.mqh>
#include <HedgeEngine.mqh>
#include <Dashboard.mqh>
#include <Pivot.mqh>
#include <Synergy.mqh>
#include <MarketBias.mqh>
#include <ADXFilter.mqh>


CTrade      trade;

//--- input parameters
input double   RiskPercent    = 0.3;   // risk per trade in percent
input double   FixedLot       = 1.0;   // fixed lot size when RiskPercent=0
input bool     UseRiskPercent = true;  // use risk percent or fixed lot

input double   HedgeFactor    = 1.0;   // hedge lot multiplier
input string   SignalFile     = "hedge_signal.txt"; // file for hedge instructions

//--- synergy inputs
input bool     UseSynergy     = true;   // enable multi-timeframe synergy filter
input double   RSIWeight      = 1.0;    // RSI contribution
input double   TrendWeight    = 1.0;    // EMA trend contribution
input double   MacdSlopeWeight= 1.0;    // MACD slope contribution
input bool     UseTF5m        = true;   // use 5 minute timeframe
input bool     UseTF15m       = true;   // use 15 minute timeframe
input bool     UseTF1h        = true;   // use 1 hour timeframe
input double   Weight5m       = 1.0;    // weight for 5m timeframe
input double   Weight15m      = 1.0;    // weight for 15m timeframe
input double   Weight1h       = 1.0;    // weight for 1h timeframe

//--- pivot inputs
input int      PivotLookback  = 50;     // lookback bars for pivot SL/TP
input int      PivotLeft      = 6;      // pivot length left
input int      PivotRight     = 6;      // pivot length right
input bool     DrawZigZag     = true;   // draw zigzag between pivots

input double   ChallengeFee   = 700;  // challenge fee (C)
input double   MaxDD          = 4000; // max drawdown (M)
input double   SlipBuffer     = 0.10; // slip buffer
input double   DailyDDCap     = 1700; // daily drawdown cap
input double   StageTarget    = 1000; // stage target for bleed


//--- trading session inputs (HHMM-HHMM)
input bool     UseSessions    = true;
input string   MonSession1    = "0000-2359";  
input string   MonSession2    = "0000-2359";
input string   TueSession1    = "0000-2359";
input string   TueSession2    = "0000-2359";
input string   WedSession1    = "0000-2359";
input string   WedSession2    = "0000-2359";
input string   ThuSession1    = "0000-2359";
input string   ThuSession2    = "0000-2359";
input string   FriSession1    = "0000-2359";
input string   FriSession2    = "0000-2359";
input string   SatSession1    = "0000-2359";
input string   SatSession2    = "0000-2359";
input string   SunSession1    = "0000-2359";
input string   SunSession2    = "0000-2359";

//--- market bias settings
input bool              UseMarketBias = true;
input ENUM_TIMEFRAMES   BiasTimeframe = PERIOD_H1;
input int               BiasMAPeriod  = 100;

//--- ADX filter settings
input bool   EnableADXFilter    = true;
input int    ADXPeriod          = 14;
input bool   UseDynamicADX      = true;
input double StaticADXThreshold = 25;
input int    ADXLookbackPeriod  = 20;
input double ADXMultiplier      = 0.8;
input double ADXMinThreshold    = 15;

input bool     UseBreakEven   = true;  // enable breakeven management
input double   BETriggerPts   = 100;   // profit in points to trigger BE
input double   BEOffsetPts    = 0;     // extra points past entry for stop

// scale-out and breakeven settings
input bool     EnableScaleOut = true;    // enable partial profit taking
input double   ScaleOutPct    = 50;      // percent of distance to TP for scale-out
input double   ScaleOutSize   = 50;      // percent of position to close
input bool     ScaleOutBE     = true;    // set breakeven after scale-out
input bool     EnableBreakEven = false;  // enable breakeven without scale-out
input double   BreakEvenTrigger = 100;   // profit in points to trigger breakeven

input int      PivotLookback  = 50;    // lookback bars for pivot SL/TP
input int      PivotLeft      = 6;     // pivot length left
input int      PivotRight     = 6;     // pivot length right
input bool     DrawZigZag     = true;  // show zigzag lines

// Synergy inputs
input bool   UseSynergyScore = true;
input double RsiWeight       = 1.0;
input double TrendWeight     = 1.0;
input double MacdSlopeWeight = 1.0;
input bool   UseTF5m         = true;
input double WeightM5        = 1.0;
input bool   UseTF15m        = true;
input double WeightM15       = 1.0;
input bool   UseTF1h         = true;
input double WeightH1        = 1.0;

// Market bias inputs
input bool   UseMarketBias   = true;
input ENUM_TIMEFRAMES BiasTimeframe = PERIOD_H1;
input int    BiasHALen       = 100;
input int    BiasOscLen      = 7;

// ADX filter inputs
input bool   EnableADXFilter   = true;
input int    ADXPeriod         = 14;
input bool   UseDynamicADX     = true;
input double StaticADXThreshold= 25.0;
input int    ADXLookback       = 20;
input double ADXMultiplier     = 0.8;
input double ADXMinThreshold   = 15.0;



//--- global variables
bool hasPosition=false;
double lastLots=0.0;
double lastSL=0.0;
double lastTP=0.0;

SynergySettings syn;
PivotSettings   piv;


double lastHedgeLots=0.0;
CHedgeEngine hedge;

bool   beApplied=false;  // has breakeven been set



bool  scaleOutDone=false;
bool  breakEvenDone=false;

datetime lastBarTime=0;
PivotZigZag zz;
double synergyScore=0.0;
datetime lastBarTime=0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   DashboardInit();

   syn.useSynergy=UseSynergy;
   syn.rsiWeight=RSIWeight;
   syn.trendWeight=TrendWeight;
   syn.macdSlopeWeight=MacdSlopeWeight;
   syn.useTF5m=UseTF5m;
   syn.useTF15m=UseTF15m;
   syn.useTF1h=UseTF1h;
   syn.weight5m=Weight5m;
   syn.weight15m=Weight15m;
   syn.weight1h=Weight1h;

   piv.lookback=PivotLookback;
   piv.leftLen=PivotLeft;
   piv.rightLen=PivotRight;
   piv.drawZigZag=DrawZigZag;



   hedge.Init(SignalFile,ChallengeFee,MaxDD,SlipBuffer,StageTarget,DailyDDCap);



   zz.Init(DrawZigZag);
   


   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   DashboardShutdown();
  }

//+------------------------------------------------------------------+
//| Calculate lots based on risk settings                             |
//+------------------------------------------------------------------+
double CalcLots(double sl_points)
  {
   if(!UseRiskPercent || sl_points<=0)
      return(FixedLot);

   double risk_money=AccountInfoDouble(ACCOUNT_BALANCE)*RiskPercent/100.0;
   double lotstep=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   double tick_value=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE);
   double tick_size=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   double value_per_point=tick_value/tick_size;
   double lots=risk_money/(sl_points*value_per_point);
   lots=MathMax(lotstep,MathFloor(lots/lotstep)*lotstep);
   return(NormalizeDouble(lots,2));
  }

//+------------------------------------------------------------------+
//| Send hedge instruction to file                                    |
//+------------------------------------------------------------------+
void SendHedgeSignal(string direction,double lots,double sl,double tp)
  {
   int file=FileOpen(SignalFile,FILE_WRITE|FILE_TXT|FILE_COMMON);
   if(file!=INVALID_HANDLE)
     {
      string line=StringFormat("%s,%s,%f,%f,%f",TimeToString(TimeCurrent(),TIME_DATE|TIME_SECONDS),direction,lots,sl,tp);
      FileWriteString(file,line+"\n");
      FileClose(file);
     }
  }

//+------------------------------------------------------------------+

//| Helper: check if current time falls inside session string         |
//+------------------------------------------------------------------+
bool InSession(const string session)
  {
   if(StringLen(session)<9)
      return(true);
   int sh=(int)StringToInteger(StringSubstr(session,0,2));
   int sm=(int)StringToInteger(StringSubstr(session,2,2));
   int eh=(int)StringToInteger(StringSubstr(session,5,2));
   int em=(int)StringToInteger(StringSubstr(session,7,2));
   datetime t=TimeCurrent();
   int cur=TimeHour(t)*60+TimeMinute(t);
   int start=sh*60+sm;
   int end=eh*60+em;
   if(start<=end)
      return(cur>=start && cur<=end);
   return(cur>=start || cur<=end);
  }

//+------------------------------------------------------------------+
//| Determine if trading is allowed based on sessions                  |
//+------------------------------------------------------------------+
bool TradingAllowed()
  {
   if(!UseSessions)
      return(true);

   int dow=DayOfWeek(); // 0=Sunday
   switch(dow)
     {
      case 1: return(InSession(MonSession1)||InSession(MonSession2));
      case 2: return(InSession(TueSession1)||InSession(TueSession2));
      case 3: return(InSession(WedSession1)||InSession(WedSession2));
      case 4: return(InSession(ThuSession1)||InSession(ThuSession2));
      case 5: return(InSession(FriSession1)||InSession(FriSession2));
      case 6: return(InSession(SatSession1)||InSession(SatSession2));
      default: return(InSession(SunSession1)||InSession(SunSession2));
     }
  }

//+------------------------------------------------------------------+
//| Determine current market bias                                     |
//+------------------------------------------------------------------+
bool BiasBullish()
  {
   if(!UseMarketBias)
      return(true);
   double maClose=iMA(_Symbol,BiasTimeframe,BiasMAPeriod,0,MODE_EMA,PRICE_CLOSE,0);
   double maOpen =iMA(_Symbol,BiasTimeframe,BiasMAPeriod,0,MODE_EMA,PRICE_OPEN,0);
   return(maClose>maOpen);
  }

//+------------------------------------------------------------------+
//| ADX trend condition                                               |
//+------------------------------------------------------------------+
bool ADXTrendOk()
  {
   if(!EnableADXFilter)
      return(true);
   double adx=iADX(_Symbol,_Period,ADXPeriod,PRICE_CLOSE,MODE_MAIN,0);
   double threshold=StaticADXThreshold;
   if(UseDynamicADX)
     {
      double sum=0;
      for(int i=0;i<ADXLookbackPeriod;i++)
         sum+=iADX(_Symbol,_Period,ADXPeriod,PRICE_CLOSE,MODE_MAIN,i);
      double avg=sum/ADXLookbackPeriod;
      double dyn=MathMax(ADXMinThreshold,avg*ADXMultiplier);
      threshold=dyn;
     }
   return(adx>threshold);
  }


//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick()
  {

   //--- update dashboard
   DashboardOnTick();

   //--- check if we have an open position
   hasPosition=(PositionSelect(_Symbol));
   //--- compute synergy score
   double synScore=CalcSynergyScore(syn);

   //--- find pivots for SL/TP
   int shift1,shift2;
   double slLong=FindPivotLowBelowClose(piv,shift1);
   double tpLong=FindPivotHighAboveClose(piv,shift2);
   UpdateZigZag(false,shift1,piv);
   UpdateZigZag(true,shift2,piv);

   int shift3,shift4;
   double slShort=FindPivotHighAboveClose(piv,shift3);
   double tpShort=FindPivotLowBelowClose(piv,shift4);
   UpdateZigZag(true,shift3,piv);
   UpdateZigZag(false,shift4,piv);

   bool longCondition=(syn.useSynergy?synScore>0:true) &&
                      slLong!=EMPTY_VALUE && tpLong!=EMPTY_VALUE &&
                      slLong<SymbolInfoDouble(_Symbol,SYMBOL_BID) && tpLong>SymbolInfoDouble(_Symbol,SYMBOL_BID);
   bool shortCondition=(syn.useSynergy?synScore<0:true) &&
                      slShort!=EMPTY_VALUE && tpShort!=EMPTY_VALUE &&
                      slShort>SymbolInfoDouble(_Symbol,SYMBOL_ASK) && tpShort<SymbolInfoDouble(_Symbol,SYMBOL_ASK);

   if(!hasPosition)
     {
  //--- update dashboard
  DashboardOnTick();

  if(!TradingAllowed() || !ADXTrendOk())
     return;


   //--- update dashboard
   DashboardOnTick();
   hedge.UpdateDailyEquity();
   

   //--- check if we have an open position
   hasPosition=(PositionSelect(_Symbol));
   if(!hasPosition)
      beApplied=false;


   //--- detect new bar for zigzag drawing
   datetime currentBar=Time[0];
   if(currentBar!=lastBarTime)
     {
      lastBarTime=currentBar;
      double ph=IsPivotHigh(PivotRight,PivotLeft,PivotRight)?High[PivotRight]:EMPTY_VALUE;
      if(ph!=EMPTY_VALUE)
         zz.AddPoint(Time[PivotRight],ph);
      double pl=IsPivotLow(PivotRight,PivotLeft,PivotRight)?Low[PivotRight]:EMPTY_VALUE;
      if(pl!=EMPTY_VALUE)
         zz.AddPoint(Time[PivotRight],pl);
     }


   //--- check if we have an open position
   hasPosition=(PositionSelect(_Symbol));

   //--- compute signals
   double fast=iMA(_Symbol,_Period,50,0,MODE_EMA,PRICE_CLOSE,0);
   double slow=iMA(_Symbol,_Period,200,0,MODE_EMA,PRICE_CLOSE,0);
   bool longCondition=(fast>slow);
   bool shortCondition=(fast<slow);

   if(!hasPosition)
     {




      //--- open position if condition met
      double sl,tp;
      if(longCondition)
        {

         sl=slLong;
         tp=tpLong;
         double lots=CalcLots(MathAbs((SymbolInfoDouble(_Symbol,SYMBOL_BID)-sl)/_Point));
         if(trade.Buy(lots,_Symbol,0,sl,tp))
           {
            lastLots=lots; lastSL=sl; lastTP=tp;
            SendHedgeSignal("SELL",lots*HedgeFactor,sl,tp);
              }

   //--- check if we have an open position
   hasPosition=(PositionSelect(_Symbol));

   //--- compute synergy, market bias and adx filter
   double synergy=CalcSynergyScore(RsiWeight,TrendWeight,MacdSlopeWeight,
                                   UseTF5m,WeightM5,UseTF15m,WeightM15,
                                   UseTF1h,WeightH1);
   dashboard.SetSynergy(synergy);

   bool bull=false,bear=false;
   double osc=MarketBiasOsc(BiasTimeframe,BiasHALen,BiasOscLen,bull,bear);
   dashboard.SetBias(bull?"Bullish":bear?"Bearish":"");

   bool adxOk=ADXTrendOk(ADXPeriod,UseDynamicADX,StaticADXThreshold,
                          ADXLookback,ADXMultiplier,ADXMinThreshold);

   bool longCondition = adxOk &&
                        (!UseSynergyScore || synergy>0) &&
                        (!UseMarketBias || bull);
   bool shortCondition = adxOk &&
                         (!UseSynergyScore || synergy<0) &&
                         (!UseMarketBias || bear);


  //--- update dashboard
  DashboardOnTick(synergyScore);

  //--- calculate synergy score on new bar
  datetime curBar=iTime(_Symbol,_Period,0);
  if(curBar!=lastBarTime)
    {
     synergyScore=CalcSynergyScore(UseTF5M,UseTF15M,UseTF1H,
                                   WeightM5,WeightM15,WeightH1,
                                   RsiWeight,TrendWeight,MacdSlopeWeight);
     lastBarTime=curBar;
    }


  //--- check if we have an open position
  hasPosition=(PositionSelect(_Symbol));

  //--- compute signals
  double fast=iMA(_Symbol,_Period,50,0,MODE_EMA,PRICE_CLOSE,0);
  double slow=iMA(_Symbol,_Period,200,0,MODE_EMA,PRICE_CLOSE,0);

  bool biasBull=BiasBullish();
  bool longCondition=(fast>slow && biasBull);
  bool shortCondition=(fast<slow && !biasBull);

   if(!hasPosition)
     {
     
  if(UseSynergyScore)
    {
     longCondition=longCondition && synergyScore>0.0;
     shortCondition=shortCondition && synergyScore<0.0;
    }



   if(!hasPosition)
     {
     
      //--- open position if condition met
      double sl,tp;  
      if(longCondition)
        {


         sl=SymbolInfoDouble(_Symbol,SYMBOL_BID)-100*_Point;
         tp=SymbolInfoDouble(_Symbol,SYMBOL_BID)+200*_Point;
         double lots=CalcLots(100);
         if(trade.Buy(lots,_Symbol,0,sl,tp))
           {
            lastLots=lots; lastSL=sl; lastTP=tp;


            lastHedgeLots=hedge.HedgeLots(lots);
            if(!hedge.DailyDDExceeded())

            beApplied=false;

            SendHedgeSignal("SELL",lots*HedgeFactor,sl,tp);


           }
        }
      else if(shortCondition)
        {

         sl=slShort;
         tp=tpShort;
         double lots=CalcLots(MathAbs((sl-SymbolInfoDouble(_Symbol,SYMBOL_ASK))/_Point));
         if(trade.Sell(lots,_Symbol,0,sl,tp))
           {
            lastLots=lots; lastSL=sl; lastTP=tp;
            SendHedgeSignal("BUY",lots*HedgeFactor,sl,tp);
              }



         sl=SymbolInfoDouble(_Symbol,SYMBOL_ASK)+100*_Point;
         tp=SymbolInfoDouble(_Symbol,SYMBOL_ASK)-200*_Point;
         double lots=CalcLots(100);
         if(trade.Sell(lots,_Symbol,0,sl,tp))
           {
            lastLots=lots; lastSL=sl; lastTP=tp;


            lastHedgeLots=hedge.HedgeLots(lots);
            if(!hedge.DailyDDExceeded())



            scaleOutDone=false;
            breakEvenDone=false;

            beApplied=false;




           }
        }
     }
   else
     {

     ulong ticket=PositionGetTicket(0);
     int type=PositionGetInteger(POSITION_TYPE);
     double entry=PositionGetDouble(POSITION_PRICE_OPEN);
     double volume=PositionGetDouble(POSITION_VOLUME);
     double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
     double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
     double profit_in_points=(type==POSITION_TYPE_BUY)? (bid-entry)/_Point : (entry-ask)/_Point;

     //--- scale-out logic
     if(EnableScaleOut && !scaleOutDone)
       {
        double scalePrice=entry;
        if(type==POSITION_TYPE_BUY)
           scalePrice=entry + (lastTP-entry)*ScaleOutPct/100.0;
        else
           scalePrice=entry - (entry-lastTP)*ScaleOutPct/100.0;

        if((type==POSITION_TYPE_BUY && bid>=scalePrice) ||
           (type==POSITION_TYPE_SELL && ask<=scalePrice))
          {
           double closeLots=NormalizeDouble(volume*(ScaleOutSize/100.0),2);
           if(closeLots>0.0 && trade.PositionClosePartial(ticket,closeLots))
             {
              scaleOutDone=true;
              lastLots-=closeLots;
              SendHedgeSignal("SO",closeLots,0,0);

              if(ScaleOutBE && !breakEvenDone)
                {
                 trade.PositionModify(ticket,entry,lastTP);
                 lastSL=entry;
                 breakEvenDone=true;
                }
             }
          }
       }

     //--- breakeven logic
     if(EnableBreakEven && !breakEvenDone && profit_in_points>=BreakEvenTrigger)
       {
        if(trade.PositionModify(ticket,entry,lastTP))
          {
           lastSL=entry;
           breakEvenDone=true;
          }
       }


      //--- manage trailing stop to breakeven
      ulong ticket=PositionGetTicket(0);
      double entry=PositionGetDouble(POSITION_PRICE_OPEN);
      double profit_in_points=(SymbolInfoDouble(_Symbol,SYMBOL_BID)-entry)/_Point;
      if(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_SELL)
         profit_in_points=(entry-SymbolInfoDouble(_Symbol,SYMBOL_ASK))/_Point;

      if(UseBreakEven && !beApplied && profit_in_points>=BETriggerPts)
        {
         double newSL=entry;
         if(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY)
            newSL=entry+BEOffsetPts*_Point;
         else
            newSL=entry-BEOffsetPts*_Point;
         if(newSL!=lastSL)
           {
            if(trade.PositionModify(ticket,newSL,lastTP))
              {
               lastSL=newSL;
               beApplied=true;
               SendHedgeSignal("ADJ",lastLots,newSL,lastTP);
              }
           }
        }

      if(profit_in_points>100)
        {
         double newSL=entry;
         if(newSL!=lastSL)
           {

           trade.PositionModify(ticket,newSL,lastTP);
           lastSL=newSL;
           if(!hedge.DailyDDExceeded())

           }
        }
      }

   hedge.CheckBleed(AccountInfoDouble(ACCOUNT_PROFIT),lastHedgeLots);


            trade.PositionModify(ticket,newSL,lastTP);
            lastSL=newSL;
            SendHedgeSignal("ADJ",lastLots,newSL,lastTP);
           }
