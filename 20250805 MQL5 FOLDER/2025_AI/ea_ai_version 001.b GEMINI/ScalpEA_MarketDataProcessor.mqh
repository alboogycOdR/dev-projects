// **6. Market Data Processor Module**

// *   **Path:** `...\MQL5\Include\ScalpEA\ScalpEA_MarketDataProcessor.mqh`
// *   **Filename:** `ScalpEA_MarketDataProcessor.mqh`

// ```mql5
//+------------------------------------------------------------------+
//| ScalpEA_MarketDataProcessor.mqh                                  |
//| Market Data Processor Module for Scalp EA                        |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025"
#property link      "https://www.example.com"
#property strict

// Include required libraries
#include <Arrays\ArrayDouble.mqh>
#include <Arrays\ArrayLong.mqh>   // For tick volume
//#include <Arrays\ArrayTime.mqh>   // For time
#include <Indicators\Indicators.mqh>
#include <Trade\SymbolInfo.mqh>
#include <Trade\PositionInfo.mqh>
//#include <MarketData\BookInfo.mqh> // For Order Book

//--- Market Data Processor Class
class CMarketDataProcessor
  {
private:
   // Configuration
   int               m_dataBars;          // Number of bars to collect
   ENUM_TIMEFRAMES   m_dataTimeframe; // Timeframe for collection
   bool              m_includeIndicators; // Include indicators?
   bool              m_includeOrderBook;  // Include order book?
   string            m_symbol;            // Symbol

   // State
   bool              m_isInitialized;

   // Objects
   CSymbolInfo       m_symbolInfo;
   CPositionInfo     m_posInfo;
   //CBookInfo     m_bookInfo;

   // Indicator Handles
   CIndicators       m_indicators;
   int               m_handleRSI;
   int               m_handleMA;
   int               m_handleMACD;
   int               m_handleATR;

   // --- JSON Formatting Helpers ---
   string            EscapeJsonString(string v) {string r=v; StringReplace(r,"\\","\\\\"); StringReplace(r,"\"","\\\""); /*StringReplace(r,"/","\\/");*/ StringReplace(r,"\b","\\b"); StringReplace(r,"\f","\\f"); StringReplace(r,"\n","\\n"); StringReplace(r,"\r","\\r"); StringReplace(r,"\t","\\t"); return "\""+r+"\"";}
   string            DoubleArrayToJson(double &a[], int d=5) {string j="["; int s=ArraySize(a); for(int i=0;i<s;i++) {j+=DoubleToString(a[i],d); if(i<s-1)j+=",";} return j+"]";}
   string            LongArrayToJson(long &a[]) {string j="["; int s=ArraySize(a); for(int i=0;i<s;i++) {j+=(string)a[i]; if(i<s-1)j+=",";} return j+"]";}
   string            TimeArrayToJson(datetime &a[]) {string j="["; int s=ArraySize(a); for(int i=0;i<s;i++) {j+=EscapeJsonString(TimeToString(a[i],TIME_DATE|TIME_SECONDS)); if(i<s-1)j+=",";} return j+"]";}
   void              AddJsonPair(string &j,string k,string v,bool c=true) {j+=EscapeJsonString(k)+":"+v; if(c)j+=",";}
   void              AddJsonPair(string &j,string k,int v,bool c=true) {AddJsonPair(j,k,IntegerToString(v),c);}
   void              AddJsonPair(string &j,string k,double v,int d=5,bool c=true) {AddJsonPair(j,k,DoubleToString(v,d),c);}
   void              AddJsonPair(string &j,string k,bool v,bool c=true) {AddJsonPair(j,k,v?"true":"false",c);}
   void              AddJsonPairRaw(string &j,string k,string rv,bool c=true) {j+=EscapeJsonString(k)+":"+rv; if(c)j+=",";}

   // Get indicator data buffer
   bool              GetIndicatorData(int h, int bIdx, double &b[], int count)
     {
      if(h==INVALID_HANDLE||count<=0)
         return false;
      ArraySetAsSeries(b,true);
      ArrayResize(b,count);
      if(CopyBuffer(h,bIdx,0,count,b)==count)
         return true;
      /* else { Print("Err CopyBuffer h:",h," b:",bIdx," Err:",GetLastError());} */ return false;
     }

   // Get Order Book JSON block
   string            GetOrderBookDataJson()
     {
      string j="{";
      if(!m_includeOrderBook)
        {
         AddJsonPair(j,"available",false,false);
         j+="}";
         return j;
        }
      MqlBookInfo book[];
      if(MarketBookGet(m_symbol, book))
        {
         AddJsonPair(j,"available",true);
         string bidsJ="[", asksJ="[";
         int bidC=0, askC=0;
         double bidV=0, askV=0;
         int depth=ArraySize(book);
         for(int i=0; i<depth; i++)
           {
            string iJ="{";
            AddJsonPair(iJ,"p",book[i].price,m_symbolInfo.Digits());
            AddJsonPair(iJ,"v",book[i].volume,2,false);
            iJ+="}";
            if(book[i].type==BOOK_TYPE_SELL)
              {
               if(askC>0)
                  asksJ+=",";
               asksJ+=iJ;
               askC++;
               askV+=book[i].volume;
              }
            else
               if(book[i].type==BOOK_TYPE_BUY)
                 {
                  if(bidC>0)
                     bidsJ+=",";
                  bidsJ+=iJ;
                  bidC++;
                  bidV+=book[i].volume;
                 }
           }
         bidsJ+="]";
         asksJ+="]";
         AddJsonPair(j,"bid_c",bidC);
         AddJsonPair(j,"ask_c",askC);
         AddJsonPair(j,"bid_v",bidV,2);
         AddJsonPair(j,"ask_v",askV,2);
         double imbalance=0.0;
         double totalV=bidV+askV;
         if(totalV>0)
            imbalance=bidV/totalV;
         else
            if(bidV>0)
               imbalance=1.0;
         AddJsonPair(j,"imb_r",imbalance,2);
         AddJsonPairRaw(j,"b",bidsJ);
         AddJsonPairRaw(j,"a",asksJ,false);
        }
      else
        {
         AddJsonPair(j,"available",false);
         AddJsonPair(j,"err",(int)GetLastError(),false);
        }
      j+="}";
      return j;
     }

   // Get Sentiment JSON block
   string            GetMarketSentimentDataJson()
     {
      if(!m_isInitialized||!m_includeIndicators)
         return "{\"avail\":false}";
      string j="{";
      AddJsonPair(j,"avail",true);
      int dc=1;
      double v;
      int bs=0;
      int ti=0;
      double rb[];
      // RSI Check
      if(GetIndicatorData(m_handleRSI,0,rb,dc))
        {
         v=rb[0];
         AddJsonPair(j,"rsi",v,2);
         if(v>50.0)
            bs++;
         ti++;
        }
      // MACD Check
      double mm[], ms[];
      if(m_handleMACD!=INVALID_HANDLE && GetIndicatorData(m_handleMACD,0,mm,dc) && GetIndicatorData(m_handleMACD,1,ms,dc))
        {
         AddJsonPair(j,"macd_m",mm[0],5);
         AddJsonPair(j,"macd_s",ms[0],5);
         if(mm[0]>ms[0])
            bs++;
         ti++;
        }
      // MA Check
      double ma[];
      m_symbolInfo.RefreshRates();
      double currentPrice = m_symbolInfo.Last(); // Get current price correctly
      if(GetIndicatorData(m_handleMA,0,ma,dc) && currentPrice > 0)
        {
         v=ma[0];
         AddJsonPair(j,"ma",v,m_symbolInfo.Digits());
         if(currentPrice > v)
            bs++;
         ti++; // Use 'currentPrice' here <<< CORRECTED
         ti++; // This indicator was checked, increment total count
        }
      double score = (ti > 0) ? (double)bs/ti : 0.5;
      AddJsonPair(j,"score",score,2,false);
      j+="}";
      return j;
     }

   // Get Volatility JSON block
   string            GetVolatilityDataJson()
     {
      if(!m_isInitialized)
         return "{\"avail\":false}";
      string j="{";
      AddJsonPair(j,"avail",true);
      double ab[];
      bool atrOK = m_includeIndicators && GetIndicatorData(m_handleATR,0,ab,1);
      double atrV = atrOK?ab[0]:0.0;
      bool addedAtr=false;
      if(atrOK)
        {
         AddJsonPair(j,"atr",atrV,m_symbolInfo.Digits());
         m_symbolInfo.RefreshRates();
         double cp=m_symbolInfo.Last();
         double atrP=(cp>0&&atrV>0)?(atrV/cp)*100.0:0.0;
         AddJsonPair(j,"atr_p",atrP,2);
         addedAtr=true;
        }
      int rBars=MathMin(10,m_dataBars);
      MqlRates r[];
      int copied=CopyRates(m_symbol,m_dataTimeframe,0,rBars,r);
      bool addedRange=false;
      if(copied==rBars)
        {
         ArraySetAsSeries(r,true);
         double mh=r[0].high;
         double ml=r[0].low;
         for(int i=1;i<rBars;i++)
           {
            if(r[i].high>mh)
               mh=r[i].high;
            if(r[i].low<ml)
               ml=r[i].low;
           }
         double range=mh-ml;
         double rangeP=(ml>0)?(range/ml)*100.0:0.0;
         AddJsonPair(j,"rng_b",rBars,addedAtr);
         AddJsonPair(j,"rng_a",range,m_symbolInfo.Digits(), addedAtr);
         AddJsonPair(j,"rng_p",rangeP,2, addedAtr);
         addedRange=true;
        }
      if(addedAtr && !addedRange)
        {
         if(StringFind(j, ",", StringLen(j) - 1) == StringLen(j) - 1)
            j = StringSubstr(j, 0, StringLen(j) - 1);
        }
      if(!addedAtr && !addedRange)
         AddJsonPair(j,"error","Could not get Vol data",false); // Indicate if nothing worked
      else
         if(!addedAtr && addedRange)
           {
            if(StringFind(j, ",", StringLen(j) - 1) == StringLen(j) - 1)
               j = StringSubstr(j, 0, StringLen(j) - 1);
           }
      j+="}";
      return j;
     }

   // Initialize indicators
   bool              InitializeIndicators()
     {
      // CIndicators object doesn't store handles, it's a factory.
      // We call indicator creation functions directly.
      ReleaseIndicatorHandles(); // Release any existing handles first
      Print("Initializing standard indicators for ", m_symbol, "/", EnumToString(m_dataTimeframe), "...");
      // RSI (Relative Strength Index) - Example: Period 14
      m_handleRSI = iRSI(m_symbol, m_dataTimeframe, 14, PRICE_CLOSE);
      if(m_handleRSI == INVALID_HANDLE)
         Print("Failed creating RSI. Error: ", GetLastError());
      // Moving Average - Example: Period 50 EMA
      m_handleMA = iMA(m_symbol, m_dataTimeframe, 50, 0, MODE_EMA, PRICE_CLOSE);
      if(m_handleMA == INVALID_HANDLE)
         Print("Failed creating MA50. Error: ", GetLastError());
      // MACD (Moving Average Convergence/Divergence) - Example: Standard 12, 26, 9
      m_handleMACD = iMACD(m_symbol, m_dataTimeframe, 12, 26, 9, PRICE_CLOSE);
      if(m_handleMACD == INVALID_HANDLE)
         Print("Failed creating MACD. Error: ", GetLastError());
      // ATR (Average True Range) - Example: Period 14
      m_handleATR = iATR(m_symbol, m_dataTimeframe, 14);
      if(m_handleATR == INVALID_HANDLE)
         Print("Failed creating ATR. Error: ", GetLastError());
      // Check if ALL required indicators were created successfully
      if(m_handleRSI == INVALID_HANDLE || m_handleMA == INVALID_HANDLE ||
         m_handleMACD == INVALID_HANDLE || m_handleATR == INVALID_HANDLE)
        {
         Print("Error: One or more indicators failed to initialize.");
         ReleaseIndicatorHandles(); // Release any handles that were created successfully before failing
         return false;
        }
      Print("Indicators initialized successfully (RSI, MA50, MACD, ATR). Handles: ", m_handleRSI, ",", m_handleMA, ",", m_handleMACD, ",", m_handleATR);
      return true;
     }

   // Release indicator handles
   void              ReleaseIndicatorHandles()
     {
      //if(m_handleRSI!=INVALID_HANDLE)
      //   IndicatorRelease(m_handleRSI);
      //m_handleRSI=INVALID_HANDLE;
      //if(m_handleMA!=INVALID_HANDLE)
      //   IndicatorRelease(m_handleMA);
      //m_handleMA=INVALID_HANDLE;
      //if(m_handleMACD!=INVALID_HANDLE)
      //   IndicatorRelease(m_handleMACD);
      //m_handleMACD=INVALID_HANDLE;
      //if(m_handleATR!=INVALID_HANDLE)
      //   IndicatorRelease(m_handleATR);
      //m_handleATR=INVALID_HANDLE;
      //m_indicators.Release();
      if(m_handleRSI!=INVALID_HANDLE)IndicatorRelease(m_handleRSI); m_handleRSI=INVALID_HANDLE;
        if(m_handleMA!=INVALID_HANDLE)IndicatorRelease(m_handleMA); m_handleMA=INVALID_HANDLE;
        if(m_handleMACD!=INVALID_HANDLE)IndicatorRelease(m_handleMACD); m_handleMACD=INVALID_HANDLE;
        if(m_handleATR!=INVALID_HANDLE)IndicatorRelease(m_handleATR); m_handleATR=INVALID_HANDLE;
     }

public:
                     CMarketDataProcessor() { m_isInitialized=false; m_dataBars=50; m_dataTimeframe=PERIOD_H1; m_includeIndicators=true; m_includeOrderBook=false; m_symbol=""; m_handleRSI=INVALID_HANDLE; m_handleMA=INVALID_HANDLE; m_handleMACD=INVALID_HANDLE; m_handleATR=INVALID_HANDLE; }
                    ~CMarketDataProcessor() { ReleaseIndicatorHandles(); if(m_includeOrderBook&&m_symbol!="")MarketBookRelease(m_symbol);}

   // Initialize the module
   bool              Initialize(string symbol, int dataBars, ENUM_TIMEFRAMES dataTimeframe, bool includeIndicators, bool includeOrderBook)
     {
      m_symbol=symbol;
      if(!m_symbolInfo.Name(m_symbol))
        {
         Print("DataProc Init Err: Bad Symbol ",m_symbol);
         return false;
        }
      m_dataBars=dataBars>5?dataBars:5;
      m_dataTimeframe=dataTimeframe;
      m_includeIndicators=includeIndicators;
      m_includeOrderBook=includeOrderBook;
      if(m_includeIndicators && !InitializeIndicators())
        {
         Print("DataProc Init Err: Indicator Init Failed.");
         return false;
        }
      if(m_includeOrderBook && !MarketBookAdd(m_symbol))
        {
         Print("Warn: MarketBookAdd failed for ",m_symbol," Err:",GetLastError());
        }
      m_isInitialized=true;
      // Print("Market Data Processor Initialized. Bars:",m_dataBars," TF:",EnumToString(m_dataTimeframe));
      return true;
     }

   // Collect market data context for AI
   string            CollectMarketData()
     {
      if(!m_isInitialized)
         return "";
     // long barsAvail=SeriesInfoInteger(m_symbol,m_dataTimeframe,SERIES_BARS_COUNT_MAIN);
      long barsAvailable = SeriesInfoInteger(m_symbol, m_dataTimeframe, SERIES_BARS_COUNT); 
      if(barsAvailable<m_dataBars) {/*Print("Data Coll Err: Need ",m_dataBars," bars, have ",barsAvail);*/ return "";}
      string json = "{"; // Start main JSON object
      AddJsonPair(json,"symbol",EscapeJsonString(m_symbol));
      AddJsonPair(json,"tf",EscapeJsonString(EnumToString(m_dataTimeframe)));
      AddJsonPair(json,"bars",m_dataBars);
      //AddJsonPair(json,"ts_utc",EscapeJsonString(TimeToString(TimeUTC(),TIME_DATE|TIME_SECONDS)));
      AddJsonPair(json, "timestamp_gmt", EscapeJsonString(TimeToString(TimeGMT(), TIME_DATE|TIME_SECONDS))); // <-- CORRECTED function and key name
      MqlRates r[];
      int copied=CopyRates(m_symbol,m_dataTimeframe,0,m_dataBars,r);
      if(copied!=m_dataBars)
        {
         Print("Data Coll Err: CopyRates failed. Copied ",copied," of ",m_dataBars);
         return "";
        }
      ArraySetAsSeries(r,true);
      double o[],h[],l[],c[];
      long v[];
      datetime t[];
      int s[];
      ArrayResize(o,m_dataBars);
      ArrayResize(h,m_dataBars);
      ArrayResize(l,m_dataBars);
      ArrayResize(c,m_dataBars);
      ArrayResize(v,m_dataBars);
      ArrayResize(t,m_dataBars);
      ArrayResize(s,m_dataBars);
      for(int i=0;i<m_dataBars;i++)
        {
         t[i]=r[i].time;
         o[i]=r[i].open;
         h[i]=r[i].high;
         l[i]=r[i].low;
         c[i]=r[i].close;
         v[i]=r[i].tick_volume;
         s[i]=r[i].spread;
        }
      string priceJ="{";
      AddJsonPairRaw(priceJ,"t",TimeArrayToJson(t));
      AddJsonPairRaw(priceJ,"o",DoubleArrayToJson(o,m_symbolInfo.Digits()));
      AddJsonPairRaw(priceJ,"h",DoubleArrayToJson(h,m_symbolInfo.Digits()));
      AddJsonPairRaw(priceJ,"l",DoubleArrayToJson(l,m_symbolInfo.Digits()));
      AddJsonPairRaw(priceJ,"c",DoubleArrayToJson(c,m_symbolInfo.Digits()));
      AddJsonPairRaw(priceJ,"v",LongArrayToJson(v),false);
      priceJ+="}";
      AddJsonPairRaw(json,"price",priceJ);
      m_symbolInfo.RefreshRates();
      string marketJ="{";
      AddJsonPair(marketJ,"b",m_symbolInfo.Bid(),m_symbolInfo.Digits());
      AddJsonPair(marketJ,"a",m_symbolInfo.Ask(),m_symbolInfo.Digits());
      AddJsonPair(marketJ,"l",m_symbolInfo.Last(),m_symbolInfo.Digits());
      AddJsonPair(marketJ,"sprd_pts",(int)m_symbolInfo.Spread());
      AddJsonPair(marketJ,"pt",m_symbolInfo.Point(),8);
      AddJsonPair(marketJ,"digits",m_symbolInfo.Digits());
      AddJsonPair(marketJ,"stops_lvl",(int)m_symbolInfo.StopsLevel());
      AddJsonPair(marketJ,"tick_v",m_symbolInfo.TickValue(),8);
      AddJsonPair(marketJ,"tick_s",m_symbolInfo.TickSize(),8);
      AddJsonPair(marketJ,"lot_size",m_symbolInfo.ContractSize(),2,false);
      marketJ+="}";
      AddJsonPairRaw(json,"market",marketJ);
      if(m_includeIndicators)
        {
         string indJ="{";
         AddJsonPair(indJ,"avail",true);
         int indD=5;
         double rb[];
         if(GetIndicatorData(m_handleRSI,0,rb,m_dataBars))
           {
            AddJsonPairRaw(indJ,"rsi",DoubleArrayToJson(rb,2));
           }
         else
            AddJsonPair(indJ,"rsi_err",true);
         double ma[];
         if(GetIndicatorData(m_handleMA,0,ma,m_dataBars))
           {
            AddJsonPairRaw(indJ,"ma",DoubleArrayToJson(ma,m_symbolInfo.Digits()));
           }
         else
            AddJsonPair(indJ,"ma_err",true);
         double mm[],ms[],mh[];
         if(m_handleMACD!=INVALID_HANDLE && GetIndicatorData(m_handleMACD,0,mm,m_dataBars) && GetIndicatorData(m_handleMACD,1,ms,m_dataBars))
           {
            ArrayResize(mh,m_dataBars);
            for(int i=0;i<m_dataBars;i++)
               mh[i]=mm[i]-ms[i];
            AddJsonPairRaw(indJ,"macd_m",DoubleArrayToJson(mm,indD));
            AddJsonPairRaw(indJ,"macd_s",DoubleArrayToJson(ms,indD));
            AddJsonPairRaw(indJ,"macd_h",DoubleArrayToJson(mh,indD));
           }
         else
            AddJsonPair(indJ,"macd_err",true);
         double ab[];
         if(GetIndicatorData(m_handleATR,0,ab,m_dataBars))
           {
            AddJsonPairRaw(indJ,"atr",DoubleArrayToJson(ab,m_symbolInfo.Digits()));
           }
         else
            AddJsonPair(indJ,"atr_err",true);
         AddJsonPairRaw(indJ,"sentiment",GetMarketSentimentDataJson());
         AddJsonPairRaw(indJ,"volatility",GetVolatilityDataJson(),false);
         indJ+="}";
         AddJsonPairRaw(json,"indicators",indJ);
        }
      else
        {
         AddJsonPairRaw(json,"indicators","{\"avail\":false}");
        }
      AddJsonPairRaw(json,"order_book",GetOrderBookDataJson(),false);
      json+="}"; // Print(json);
      return json;
     }


   // Collect specific data context for an existing trade
   string            CollectTradeData(ulong ticket)
     {
      if(!m_isInitialized || !ValidateTicketForData(ticket))
         return "";
      string json="{"; // Start Trade Data
      AddJsonPair(json,"tkt",(long)ticket);
      string ptStr=(m_posInfo.PositionType()==POSITION_TYPE_BUY)?"BUY":"SELL";
      AddJsonPair(json,"type",EscapeJsonString(ptStr));
      AddJsonPair(json,"vol",m_posInfo.Volume(),2);
      AddJsonPair(json,"sym",EscapeJsonString(m_posInfo.Symbol()));
      AddJsonPair(json,"magic",(long)m_posInfo.Magic());
      double ep=m_posInfo.PriceOpen();
      double cp=m_posInfo.PriceCurrent();
      double sl=m_posInfo.StopLoss();
      double tp=m_posInfo.TakeProfit();
      int dg=m_symbolInfo.Digits();
      AddJsonPair(json,"p_entry",ep,dg);
      AddJsonPair(json,"p_curr",cp,dg);
      AddJsonPair(json,"p_sl",sl,dg);
      AddJsonPair(json,"p_tp",tp,dg);
      AddJsonPair(json,"usd_profit",m_posInfo.Profit(),2);
      AddJsonPair(json,"usd_swap",m_posInfo.Swap(),2);
      AddJsonPair(json,"usd_comm",m_posInfo.Commission(),2);
      double pips=0;
      double pnt=m_symbolInfo.Point();
      if(pnt>0)
        {
         double pM=(dg==2||dg==4)?1.0:10.0;
         if(m_symbol=="XAUUSD")
            pM=10.0;
         if(ptStr=="BUY")
            pips=(cp-ep)/(pnt*pM);
         else
            pips=(ep-cp)/(pnt*pM);
        }
      AddJsonPair(json,"pips_profit",pips,1);
      double rr=0;
      if(sl>0)
        {
         double rDist=MathAbs(ep-sl);
         if(rDist>pnt)
           {
            double cDist=0;
            if(ptStr=="BUY")
               cDist=cp-ep;
            else
               cDist=ep-cp;
            rr=cDist/rDist;
           }
        }
      AddJsonPair(json,"r_r_current",rr,2);
      datetime ot=m_posInfo.Time();
      AddJsonPair(json,"t_open",EscapeJsonString(TimeToString(ot,TIME_DATE|TIME_SECONDS)));
      AddJsonPair(json,"t_dur_min",(long)((TimeCurrent()-ot)/60));
      m_symbolInfo.RefreshRates();
      string marketC="{";
      AddJsonPair(marketC,"b",m_symbolInfo.Bid(),dg);
      AddJsonPair(marketC,"a",m_symbolInfo.Ask(),dg);
      AddJsonPair(marketC,"sprd_pts",(int)m_symbolInfo.Spread(),false);
      marketC+="}";
      AddJsonPairRaw(json,"market_ctx",marketC);
      if(m_includeIndicators)
        {
         string indC="{";
         AddJsonPair(indC,"avail",true);
         int dc=1;
         double v;
         double rb[];
         if(GetIndicatorData(m_handleRSI,0,rb,dc))
            AddJsonPair(indC,"rsi",rb[0],2);
         double mm[],ms[];
         if(m_handleMACD!=INVALID_HANDLE && GetIndicatorData(m_handleMACD,0,mm,dc) && GetIndicatorData(m_handleMACD,1,ms,dc))
           {
            AddJsonPair(indC,"macd_m",mm[0],5);
            AddJsonPair(indC,"macd_s",ms[0],5);
           }
         double ma[];
         if(GetIndicatorData(m_handleMA,0,ma,dc))
            AddJsonPair(indC,"ma",ma[0],dg);
         double ab[];
         if(GetIndicatorData(m_handleATR,0,ab,dc))
           {
            AddJsonPair(indC,"atr",ab[0],dg);
            double atrP=(cp>0&&ab[0]>0)?(ab[0]/cp)*100.0:0.0;
            AddJsonPair(indC,"atr_p",atrP,2);
           }
         if(StringFind(indC, ",", StringLen(indC) - 1) == StringLen(indC) - 1)
            indC = StringSubstr(indC, 0, StringLen(indC) - 1);
         indC+="}";
         AddJsonPairRaw(json,"indicator_ctx",indC,false);
        }
      else
        {
         AddJsonPairRaw(json,"indicator_ctx","{\"avail\":false}",false);
        }
      json+="}";
      return json;
     }

   // Validate ticket exists and belongs to the symbol for data collection
   bool              ValidateTicketForData(ulong ticket)
     {
      return (m_isInitialized && ticket>0 && m_posInfo.Select(ticket) && m_posInfo.Symbol() == m_symbol);
     }

   // Format Trade Data (for SL Validation AI prompt)
   string            FormatTradeData(ulong ticket)
     {
      if(!m_isInitialized || ticket <= 0)
         return "ERROR: Processor not initialized or bad ticket.";
      if(!m_posInfo.Select(ticket) || m_posInfo.Symbol() != m_symbol)
         return "ERROR: Could not select trade or wrong symbol.";
      string direction = (m_posInfo.PositionType()==POSITION_TYPE_BUY)?"BUY":"SELL";
      // ... existing code ...
     };
  };
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
