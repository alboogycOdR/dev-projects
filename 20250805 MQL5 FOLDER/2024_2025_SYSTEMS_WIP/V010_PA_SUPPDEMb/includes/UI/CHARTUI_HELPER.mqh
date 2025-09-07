//+------------------------------------------------------------------+
//|                                                      ProjectName |
//|                                      Copyright 2020, CompanyName |
//|                                       http://www.companyname.net |
//+------------------------------------------------------------------+
//--- custom colors
#define           COLOR_BACK      clrBlack
#define           COLOR_BORDER    clrDimGray
#define           COLOR_CAPTION   clrDodgerBlue
#define           COLOR_TEXT      clrLightGray
#define           COLOR_WIN       clrLimeGreen
#define           COLOR_LOSS      clrOrangeRed
bool              InpAutoColors=false;//Comment Auto Colors
bool              InpGraphMode=true;

//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Display data from the specified timeseries index to the panel    |
//+------------------------------------------------------------------+
void DrawData(const int index,const datetime time)
  {
//  Print(__FUNCTION__);
////--- Declare the variables to receive data in them
//   MqlTick  tick= {0};
//   MqlRates rates[1];
//
////--- Exit if unable to get the current prices
//   if(!SymbolInfoTick(Symbol(),tick))
//      return;
////--- Exit if unable to get the bar data by the specified index
//   if(CopyRates(Symbol(),PERIOD_CURRENT,index,1,rates)!=1)
//      return;
//
//Print(__LINE__);
////--- Display the current prices and data of the specified bar on the panel
//   dashboard.DrawText("Bid",        dashboard.CellX(0,0)+2,   dashboard.CellY(0,0)+2);
//   dashboard.DrawText(DoubleToString(tick.bid,Digits()),       dashboard.CellX(0,1)+2,   dashboard.CellY(0,1)+2,90);
//   dashboard.DrawText("Ask",        dashboard.CellX(1,0)+2,   dashboard.CellY(1,0)+2);
//   dashboard.DrawText(DoubleToString(tick.ask,Digits()),       dashboard.CellX(1,1)+2,   dashboard.CellY(1,1)+2,90);
//   dashboard.DrawText("Date",       dashboard.CellX(2,0)+2,   dashboard.CellY(2,0)+2);
//   dashboard.DrawText(TimeToString(rates[0].time,TIME_DATE),   dashboard.CellX(2,1)+2,   dashboard.CellY(2,1)+2,90);
//   dashboard.DrawText("Time",       dashboard.CellX(3,0)+2,   dashboard.CellY(3,0)+2);
//   dashboard.DrawText(TimeToString(rates[0].time,TIME_MINUTES),dashboard.CellX(3,1)+2,   dashboard.CellY(3,1)+2,90);
//
//   dashboard.DrawText("Open",       dashboard.CellX(4,0)+2,   dashboard.CellY(4,0)+2);
//   dashboard.DrawText(DoubleToString(rates[0].open,Digits()),  dashboard.CellX(4,1)+2,   dashboard.CellY(4,1)+2,90);
//   dashboard.DrawText("High",       dashboard.CellX(5,0)+2,   dashboard.CellY(5,0)+2);
//   dashboard.DrawText(DoubleToString(rates[0].high,Digits()),  dashboard.CellX(5,1)+2,   dashboard.CellY(5,1)+2,90);
//   dashboard.DrawText("Low",        dashboard.CellX(6,0)+2,   dashboard.CellY(6,0)+2);
//   dashboard.DrawText(DoubleToString(rates[0].low,Digits()),   dashboard.CellX(6,1)+2,   dashboard.CellY(6,1)+2,90);
//   dashboard.DrawText("Close",      dashboard.CellX(7,0)+2,   dashboard.CellY(7,0)+2);
//   dashboard.DrawText(DoubleToString(rates[0].close,Digits()), dashboard.CellX(7,1)+2,   dashboard.CellY(7,1)+2,90);
//
//   dashboard.DrawText("Volume",     dashboard.CellX(8,0)+2,   dashboard.CellY(8,0)+2);
//   dashboard.DrawText((string)rates[0].real_volume,            dashboard.CellX(8,1)+2,   dashboard.CellY(8,1)+2,90);
//   dashboard.DrawText("Tick Volume",dashboard.CellX(9,0)+2,   dashboard.CellY(9,0)+2);
//   dashboard.DrawText((string)rates[0].tick_volume,            dashboard.CellX(9,1)+2,   dashboard.CellY(9,1)+2,90);
//   dashboard.DrawText("Spread",     dashboard.CellX(10,0)+2,  dashboard.CellY(10,0)+2);
//   dashboard.DrawText((string)rates[0].spread,                 dashboard.CellX(10,1)+2,  dashboard.CellY(10,1)+2,90);
//
////dashboard.DrawText(plot_label,   dashboard.CellX(11,0)+2,  dashboard.CellY(11,0)+2); dashboard.DrawText(DoubleToString(BufferMA[index],Digits()),dashboard.CellX(11,1)+2,  dashboard.CellY(11,1)+2,90);
////--- Redraw the chart to immediately display all changes on the panel
//   ChartRedraw(ChartID());
  }




///*   STATS ENGINE REFERENCE   */
//
//
//
// //IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN)));
////---col#1
//   Print("InitialDeposit   "+StringFormat("%.2f",stat.InitialDeposit()));  /*          */
//   Print("net profit   "+StringFormat("%.2f",stat.Profit()));/*         total net profit */
//   Print("GrossProfit   "+StringFormat("%.2f",stat.GrossProfit()));/*          */
//   Print("GrossLoss   "+StringFormat("%.2f",stat.GrossLoss()));/*          */
//   Print("ProfitFactor   "+StringFormat("%.2f",stat.ProfitFactor()));/*          */
//   Print("RecoveryFactor   "+StringFormat("%.2f",stat.RecoveryFactor()));/*          */
//   Print("aphr   "+StringFormat("%.4f(%.2f%%)",stat.AHPR(),stat.AHPRPercent()));/*   aphr          */
//   Print("ghpr   "+StringFormat("%.4f(%.2f%%)",stat.GHPR(),stat.GHPRPercent()));/*    ghpr      */
//   Print("z-score   "+StringFormat("%.2f(%.2f%%)",stat.ZScore(),stat.ZScorePercent())); /*    z-score      */
//   Print("TOTAL TRADES   "+StringFormat("%d",stat.Trades()));/*         TOTAL TRADES */
//   Print("TOTAL DEALS   "+StringFormat("%d",stat.Deals()));/*         TOTAL DEALS */
////---col#2
//   Print("ExpectedPayoff   "+StringFormat("%.2f",stat.ExpectedPayoff())); /*    */
//   Print("SharpeRatio   "+StringFormat("%.2f",stat.SharpeRatio()));
//   Print("LRCorrelation   "+StringFormat("%.2f",stat.LRCorrelation()));
//   Print("LRStandardError   "+StringFormat("%.2f",stat.LRStandardError()));
//   Print("SHORT TRADES NUMBER, %   "+StringFormat("%.d(%.2f%%)",stat.ShortTrades(),stat.Percent("   "+Stat.ProfitShortTrades(),stat.ShortTrades())));    /*    SHORT TRADES NUMBER, %  */
//   Print("PROFIT TRADES NUMBER, %   "+StringFormat("%.d(%.2f%%)",stat.ProfitTrades(),stat.Percent("   "+Stat.ProfitTrades(),stat.Trades())));/*    PROFIT TRADES NUMBER, %  */
//   Print("LARGEST PROFIT TRADE   "+StringFormat("%.2f",stat.LargestProfitTrade()));/*      LARGEST PROFIT TRADE*/
//   Print("AVG PROFIT TRADE   "+StringFormat("%.2f",stat.Divide("   "+Stat.GrossProfit(),stat.ProfitTrades())));/*    AVG PROFIT TRADE  */
//   Print("MAX.CONS.WINS    "+StringFormat("%.d(%.2f)",stat.MaxConProfitTrades(),stat.MaxConWins()));/*     MAX.CONS.WINS  */
//   Print("MAX CONS PROFIT   "+StringFormat("%.2f(%.d)",stat.ConProfitMax(),stat.ConProfitMaxTrades()));/*     MAX CONS PROFIT */
//   Print("AVG CONS WINS   "+StringFormat("%.d",stat.ProfitTradesAvgCon()));/*      AVG CONS WINS*/
////---col#3
//   Print("BALANCE DR. ABS   "+StringFormat("%.2f",stat.InitialDeposit()-stat.BalanceMin()));          /* BALANCE DR. ABS*/
//   Print("BALANCE DR. MAX   "+StringFormat("%.2f(%.2f%%)",stat.BalanceDD(),stat.BalanceDDPercent()));/*BALANCE DR. MAX */
//   Print("BALANCE DR. REL   "+StringFormat("%.2f(%.2f%%)",stat.BalanceDDRelative(),stat.BalanceDDRelativePercent()));/*BALANCE DR. REL */
//   Print("LONG TRADES   "+StringFormat("%.d(%.2f%%)",stat.LongTrades(),stat.Percent("   "+Stat.ProfitLongTrades(),stat.LongTrades())));     /*LONG TRADES */
//   Print("LOSS TRADES   "+StringFormat("%.d(%.2f%%)",stat.LossTrades(),stat.Percent("   "+Stat.LossTrades(),stat.Trades())));/* LOSS TRADES*/
//   Print("LARGEST LOSS TRADE   "+StringFormat("%.2f",stat.LargestLossTrade()));/* LARGEST LOSS TRADE*/
//   Print("AVG LOSS TRADE   "+StringFormat("%.2f",stat.Divide("   "+Stat.GrossLoss(),stat.LossTrades())));/*AVG LOSS TRADE*/
//   Print("MAX CONS. LOSSES   "+StringFormat("%.d(%.2f)",stat.MaxConLossTrades(),stat.MaxConLosses()));/*MAX CONS. LOSSES*/
//   Print("MAX CONS. LOSS   "+StringFormat("%.2f(%.d)",stat.ConLossMax(),stat.ConLossMaxTrades()));/*MAX CONS. LOSS*/
//   Print("AVG CONS LOSS   "+StringFormat("%.d",stat.LossTradesAvgCon()));/*AVG CONS LOSS*/
//   Print("==============================================================");



//+------------------------------------------------------------------+
//void output_trade_stats()
//  {
////reference
////static CTradeStatistics stat_priceaction_ea; // Static object declaration
////static CTradeStatistics stat_vwap_ea; // Static object declaration
//
//
//
//
//   if(enablePriceAction)
//     {
//      if(stat_priceaction_ea.Calculate())
//        {
//         Print("PRICEACTION EA STATISTICS");//PrintDataPanel(); //PrintData();
//         Print("===========================");
//        }
//      else
//        {
//         Print("Stats error:  "+stat_priceaction_ea.GetLastErrorString());
//         return;
//        }
//
//
//      //Print("magic   "+StringFormat("%d",MAGICNUMBR));/*         TOTAL TRADES */
//      //IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN)));
//      //---col#1
//      Print("InitialDeposit   "+StringFormat("%.2f",stat_priceaction_ea.InitialDeposit()));  /*          */
//      Print("net profit   "+StringFormat("%.2f",stat_priceaction_ea.Profit()));/*         total net profit */
//      Print("GrossProfit   "+StringFormat("%.2f",stat_priceaction_ea.GrossProfit()));/*          */
//      Print("GrossLoss   "+StringFormat("%.2f",stat_priceaction_ea.GrossLoss()));/*          */
//      Print("ProfitFactor   "+StringFormat("%.2f",stat_priceaction_ea.ProfitFactor()));/*          */
//      Print("RecoveryFactor   "+StringFormat("%.2f",stat_priceaction_ea.RecoveryFactor()));/*          */
//      Print("aphr   "+StringFormat("%.4f(%.2f%%)",stat_priceaction_ea.AHPR(),stat_priceaction_ea.AHPRPercent()));/*   aphr          */
//      Print("ghpr   "+StringFormat("%.4f(%.2f%%)",stat_priceaction_ea.GHPR(),stat_priceaction_ea.GHPRPercent()));/*    ghpr      */
//      Print("z-score   "+StringFormat("%.2f(%.2f%%)",stat_priceaction_ea.ZScore(),stat_priceaction_ea.ZScorePercent())); /*    z-score      */
//      Print("TOTAL TRADES   "+StringFormat("%d",stat_priceaction_ea.Trades()));/*         TOTAL TRADES */
//      Print("TOTAL DEALS   "+StringFormat("%d",stat_priceaction_ea.Deals()));/*         TOTAL DEALS */
//      //---col#2
//      Print("ExpectedPayoff   "+StringFormat("%.2f",stat_priceaction_ea.ExpectedPayoff())); /*    */
//      Print("SharpeRatio   "+StringFormat("%.2f",stat_priceaction_ea.SharpeRatio()));
//      Print("LRCorrelation   "+StringFormat("%.2f",stat_priceaction_ea.LRCorrelation()));
//      Print("LRStandardError   "+StringFormat("%.2f",stat_priceaction_ea.LRStandardError()));
//      Print("SHORT TRADES NUMBER, %   "+StringFormat("%.d(%.2f%%)",stat_priceaction_ea.ShortTrades(),stat_priceaction_ea.Percent("   "+stat_priceaction_ea.ProfitShortTrades(),stat_priceaction_ea.ShortTrades())));    /*    SHORT TRADES NUMBER, %  */
//      Print("PROFIT TRADES NUMBER, %   "+StringFormat("%.d(%.2f%%)",stat_priceaction_ea.ProfitTrades(),stat_priceaction_ea.Percent("   "+stat_priceaction_ea.ProfitTrades(),stat_priceaction_ea.Trades())));/*    PROFIT TRADES NUMBER, %  */
//      Print("LARGEST PROFIT TRADE   "+StringFormat("%.2f",stat_priceaction_ea.LargestProfitTrade()));/*      LARGEST PROFIT TRADE*/
//      Print("AVG PROFIT TRADE   "+StringFormat("%.2f",stat_priceaction_ea.Divide("   "+stat_priceaction_ea.GrossProfit(),stat_priceaction_ea.ProfitTrades())));/*    AVG PROFIT TRADE  */
//      Print("MAX.CONS.WINS    "+StringFormat("%.d(%.2f)",stat_priceaction_ea.MaxConProfitTrades(),stat_priceaction_ea.MaxConWins()));/*     MAX.CONS.WINS  */
//      Print("MAX CONS PROFIT   "+StringFormat("%.2f(%.d)",stat_priceaction_ea.ConProfitMax(),stat_priceaction_ea.ConProfitMaxTrades()));/*     MAX CONS PROFIT */
//      Print("AVG CONS WINS   "+StringFormat("%.d",stat_priceaction_ea.ProfitTradesAvgCon()));/*      AVG CONS WINS*/
//      //---col#3
//      Print("BALANCE DR. ABS   "+StringFormat("%.2f",stat_priceaction_ea.InitialDeposit()-stat_priceaction_ea.BalanceMin()));          /* BALANCE DR. ABS*/
//      Print("BALANCE DR. MAX   "+StringFormat("%.2f(%.2f%%)",stat_priceaction_ea.BalanceDD(),stat_priceaction_ea.BalanceDDPercent()));/*BALANCE DR. MAX */
//      Print("BALANCE DR. REL   "+StringFormat("%.2f(%.2f%%)",stat_priceaction_ea.BalanceDDRelative(),stat_priceaction_ea.BalanceDDRelativePercent()));/*BALANCE DR. REL */
//      Print("LONG TRADES   "+StringFormat("%.d(%.2f%%)",stat_priceaction_ea.LongTrades(),stat_priceaction_ea.Percent("   "+stat_priceaction_ea.ProfitLongTrades(),stat_priceaction_ea.LongTrades())));     /*LONG TRADES */
//      Print("LOSS TRADES   "+StringFormat("%.d(%.2f%%)",stat_priceaction_ea.LossTrades(),stat_priceaction_ea.Percent("   "+stat_priceaction_ea.LossTrades(),stat_priceaction_ea.Trades())));/* LOSS TRADES*/
//      Print("LARGEST LOSS TRADE   "+StringFormat("%.2f",stat_priceaction_ea.LargestLossTrade()));/* LARGEST LOSS TRADE*/
//      Print("AVG LOSS TRADE   "+StringFormat("%.2f",stat_priceaction_ea.Divide("   "+stat_priceaction_ea.GrossLoss(),stat_priceaction_ea.LossTrades())));/*AVG LOSS TRADE*/
//      Print("MAX CONS. LOSSES   "+StringFormat("%.d(%.2f)",stat_priceaction_ea.MaxConLossTrades(),stat_priceaction_ea.MaxConLosses()));/*MAX CONS. LOSSES*/
//      Print("MAX CONS. LOSS   "+StringFormat("%.2f(%.d)",stat_priceaction_ea.ConLossMax(),stat_priceaction_ea.ConLossMaxTrades()));/*MAX CONS. LOSS*/
//      Print("AVG CONS LOSS   "+StringFormat("%.d",stat_priceaction_ea.LossTradesAvgCon()));/*AVG CONS LOSS*/
//      Print("==============================================================");
//     }
//
//   if(enableVwapStrategy)
//     {
//      if(stat_vwap_ea.Calculate())
//        {
//         Print("VWAP EA STATISTICS");//PrintDataPanel(); //PrintData();
//         Print("===========================");
//        }
//      else
//        {
//         Print("Stats error:  "+stat_vwap_ea.GetLastErrorString());
//         return;
//        }
//
//      //Print("magic   "+StringFormat("%d",MAGICNUMBR));/*         TOTAL TRADES */
//      //IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN)));
//      //---col#1
//      Print("InitialDeposit   "+StringFormat("%.2f",stat_vwap_ea.InitialDeposit()));  /*          */
//      Print("net profit   "+StringFormat("%.2f",stat_vwap_ea.Profit()));/*         total net profit */
//      Print("GrossProfit   "+StringFormat("%.2f",stat_vwap_ea.GrossProfit()));/*          */
//      Print("GrossLoss   "+StringFormat("%.2f",stat_vwap_ea.GrossLoss()));/*          */
//      Print("ProfitFactor   "+StringFormat("%.2f",stat_vwap_ea.ProfitFactor()));/*          */
//      Print("RecoveryFactor   "+StringFormat("%.2f",stat_vwap_ea.RecoveryFactor()));/*          */
//      Print("aphr   "+StringFormat("%.4f(%.2f%%)",stat_vwap_ea.AHPR(),stat_vwap_ea.AHPRPercent()));/*   aphr          */
//      Print("ghpr   "+StringFormat("%.4f(%.2f%%)",stat_vwap_ea.GHPR(),stat_vwap_ea.GHPRPercent()));/*    ghpr      */
//      Print("z-score   "+StringFormat("%.2f(%.2f%%)",stat_vwap_ea.ZScore(),stat_vwap_ea.ZScorePercent())); /*    z-score      */
//      Print("TOTAL TRADES   "+StringFormat("%d",stat_vwap_ea.Trades()));/*         TOTAL TRADES */
//      Print("TOTAL DEALS   "+StringFormat("%d",stat_vwap_ea.Deals()));/*         TOTAL DEALS */
//      //---col#2
//      Print("ExpectedPayoff   "+StringFormat("%.2f",stat_vwap_ea.ExpectedPayoff())); /*    */
//      Print("SharpeRatio   "+StringFormat("%.2f",stat_vwap_ea.SharpeRatio()));
//      Print("LRCorrelation   "+StringFormat("%.2f",stat_vwap_ea.LRCorrelation()));
//      Print("LRStandardError   "+StringFormat("%.2f",stat_vwap_ea.LRStandardError()));
//      Print("SHORT TRADES NUMBER, %   "+StringFormat("%.d(%.2f%%)",stat_vwap_ea.ShortTrades(),stat_vwap_ea.Percent("   "+stat_vwap_ea.ProfitShortTrades(),stat_vwap_ea.ShortTrades())));    /*    SHORT TRADES NUMBER, %  */
//      Print("PROFIT TRADES NUMBER, %   "+StringFormat("%.d(%.2f%%)",stat_vwap_ea.ProfitTrades(),stat_vwap_ea.Percent("   "+stat_vwap_ea.ProfitTrades(),stat_vwap_ea.Trades())));/*    PROFIT TRADES NUMBER, %  */
//      Print("LARGEST PROFIT TRADE   "+StringFormat("%.2f",stat_vwap_ea.LargestProfitTrade()));/*      LARGEST PROFIT TRADE*/
//      Print("AVG PROFIT TRADE   "+StringFormat("%.2f",stat_vwap_ea.Divide("   "+stat_vwap_ea.GrossProfit(),stat_vwap_ea.ProfitTrades())));/*    AVG PROFIT TRADE  */
//      Print("MAX.CONS.WINS    "+StringFormat("%.d(%.2f)",stat_vwap_ea.MaxConProfitTrades(),stat_vwap_ea.MaxConWins()));/*     MAX.CONS.WINS  */
//      Print("MAX CONS PROFIT   "+StringFormat("%.2f(%.d)",stat_vwap_ea.ConProfitMax(),stat_vwap_ea.ConProfitMaxTrades()));/*     MAX CONS PROFIT */
//      Print("AVG CONS WINS   "+StringFormat("%.d",stat_vwap_ea.ProfitTradesAvgCon()));/*      AVG CONS WINS*/
//      //---col#3
//      Print("BALANCE DR. ABS   "+StringFormat("%.2f",stat_vwap_ea.InitialDeposit()-stat_vwap_ea.BalanceMin()));          /* BALANCE DR. ABS*/
//      Print("BALANCE DR. MAX   "+StringFormat("%.2f(%.2f%%)",stat_vwap_ea.BalanceDD(),stat_vwap_ea.BalanceDDPercent()));/*BALANCE DR. MAX */
//      Print("BALANCE DR. REL   "+StringFormat("%.2f(%.2f%%)",stat_vwap_ea.BalanceDDRelative(),stat_vwap_ea.BalanceDDRelativePercent()));/*BALANCE DR. REL */
//      Print("LONG TRADES   "+StringFormat("%.d(%.2f%%)",stat_vwap_ea.LongTrades(),stat_vwap_ea.Percent("   "+stat_vwap_ea.ProfitLongTrades(),stat_vwap_ea.LongTrades())));     /*LONG TRADES */
//      Print("LOSS TRADES   "+StringFormat("%.d(%.2f%%)",stat_vwap_ea.LossTrades(),stat_vwap_ea.Percent("   "+stat_vwap_ea.LossTrades(),stat_vwap_ea.Trades())));/* LOSS TRADES*/
//      Print("LARGEST LOSS TRADE   "+StringFormat("%.2f",stat_vwap_ea.LargestLossTrade()));/* LARGEST LOSS TRADE*/
//      Print("AVG LOSS TRADE   "+StringFormat("%.2f",stat_vwap_ea.Divide("   "+stat_vwap_ea.GrossLoss(),stat_vwap_ea.LossTrades())));/*AVG LOSS TRADE*/
//      Print("MAX CONS. LOSSES   "+StringFormat("%.d(%.2f)",stat_vwap_ea.MaxConLossTrades(),stat_vwap_ea.MaxConLosses()));/*MAX CONS. LOSSES*/
//      Print("MAX CONS. LOSS   "+StringFormat("%.2f(%.d)",stat_vwap_ea.ConLossMax(),stat_vwap_ea.ConLossMaxTrades()));/*MAX CONS. LOSS*/
//      Print("AVG CONS LOSS   "+StringFormat("%.d",stat_vwap_ea.LossTradesAvgCon()));/*AVG CONS LOSS*/
//      Print("==============================================================");
//     }
//
//  }
//+------------------------------------------------------------------+
 
 


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
  {
 
//--- Call the panel event handler
// dashboard.OnChartEvent(id,lparam,dparam,sparam);
//--- If the cursor moves or a click is made on the chart
   if(id==CHARTEVENT_MOUSE_MOVE || id==CHARTEVENT_CLICK)
     {
      //--- Declare the variables to record time and price coordinates in them
      datetime time=0;
      double price=0;
      int wnd=0;
      //--- If the cursor coordinates are converted to date and time
      //if(ChartXYToTimePrice(ChartID(),(int)lparam,(int)dparam,wnd,time,price))
      //  {
      //   //--- write the bar index where the cursor is located to a global variable
      //   mouse_bar_index=iBarShift(Symbol(),PERIOD_CURRENT,time);
      //   //--- Display the bar data under the cursor on the panel
      //   DrawData(mouse_bar_index,time);
      //  }
     }
//--- If we received a custom event, display the appropriate message in the journal
   if(id>CHARTEVENT_CUSTOM)
     {
      //--- Here we can implement handling a click on the close button on the panel
      PrintFormat("%s: Event id=%ld, object id (lparam): %lu, event message (sparam): %s",__FUNCTION__,id,lparam,sparam);
     }
   if(id == CHARTEVENT_CHART_CHANGE)
      if(EnableWallpaper)
         WallPaper.Resize();
   /*

   UI : TICKER SYMBOL WATERMARK

   */
   if(enableWaterMark)
      watermark.updateLabelsOnChart();
  }


//+------------------------------------------------------------------+
//|   ClearData()                                                    |
//+------------------------------------------------------------------+
void ClearData()
  {
//ExtDialog.Caption("");
//for(int c=0;c<=2;c++)
//   for(int i=0;i<=11;i++)
//      ExtDialog.SetLabelParam(i,c,"");
//ChartRedraw();
  }
//+------------------------------------------------------------------+



//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void SetupSmartComment()
  {
   tester=MQLInfoInteger(MQL_TESTER);
   visual_mode=MQLInfoInteger(MQL_VISUAL_MODE);
//--- panel position
   int y=30;
   if(ChartGetInteger(0,CHART_SHOW_ONE_CLICK))
      y=120;
//--- panel name
   srand(GetTickCount());
   string name="SMARTPANEL_"+IntegerToString(MathRand());
   smartcomment.Create(name,20,y);
   smartcomment.SetAutoColors(InpAutoColors);//InpAutoColors
   smartcomment.SetGraphMode(true);
   smartcomment.SetColor(COLOR_BORDER,COLOR_BACK,255);
   smartcomment.SetFont("Lucida Console",13,false,1.7);
//_______________________________________________________________________________________________
   smartcomment.SetText(0,StringFormat("Expert: %s",MQLInfoString(MQL_PROGRAM_NAME)),COLOR_CAPTION);
   smartcomment.SetText(1,"Strategies enabled: S&RLevelTrader EA",COLOR_TEXT);
//                        +(Strategies = enablePriceAction && !enableVwapStrategy ? " PRICEACTION_SNR " :
//                                       (enableVwapStrategy && !enablePriceAction ? " VWAP_MEAN_REVERT " :
//                                        (enableVwapStrategy && enablePriceAction ? " PRICEACTION_SNR,VWAP_MEAN_REVERT " : " MONITORING ONLY ")))
//
//smartcomment.SetText(2,"Server Time: "+TimeToString(TimeCurrent(),TIME_MINUTES|TIME_SECONDS),COLOR_TEXT);
   smartcomment.SetText(3,"Price: "+DoubleToString(SymbolInfoDouble(_Symbol,SYMBOL_BID),_Digits),COLOR_TEXT);
   smartcomment.SetText(4,"Active symbol: "+Symbol(),COLOR_TEXT);
   smartcomment.SetText(6,"Time Local: "+TimeToString(TimeLocal(),TIME_MINUTES|TIME_SECONDS),COLOR_TEXT);
   smartcomment.SetText(7,"GMT time: "+TimeToString(TimeGMT(),TIME_MINUTES|TIME_SECONDS),COLOR_TEXT);
   smartcomment.SetText(9,"Open Positions #: "+(string)OpenTrades("all"),COLOR_TEXT);

   if(enableTradingStatistics)
     {
      smartcomment.SetText(10,"- - - - PERFORMANCE LAST "+(string)DAYS_OF_STATS +"DAYS- - - - ",COLOR_TEXT);
      smartcomment.SetText(11,"GROSS PROFIT :"+StringFormat("%.2f",stat_priceaction_ea.GrossProfit()),COLOR_WIN);/*          */
      smartcomment.SetText(12,"GROSS LOSS :"+StringFormat("%.2f",stat_priceaction_ea.GrossLoss()),COLOR_WIN);/*          */
      smartcomment.SetText(13,"NETT PROFIT :"+StringFormat("%.2f",stat_priceaction_ea.Profit()),COLOR_WIN);/*         total net profit */
      smartcomment.SetText(14,"TOTAL TRADES :"+StringFormat("%d",stat_priceaction_ea.Trades()),COLOR_WIN);/*         TOTAL TRADES */
      smartcomment.SetText(15,"LARGEST PROFIT TRADE :"+StringFormat("%.2f",stat_priceaction_ea.LargestProfitTrade()),COLOR_WIN);/*      LARGEST PROFIT TRADE*/
      smartcomment.SetText(16,"LARGEST LOSS TRADE :"+StringFormat("%.2f",stat_priceaction_ea.LargestLossTrade()),COLOR_WIN);/* LARGEST LOSS TRADE*/
     }


//------------------
   if(newscontrol)
     {
      //todo;  if !enableTradingStatistics then adjust count
      smartcomment.SetText(17,"Currently at news? "+((AtNews()!="No News")?("True ("+AtNews()+")"):(AtNews())),COLOR_TEXT);
      smartcomment.SetText(18,"Time to Close with Profit: "
                           +((BeforeNewsForZeroProfit()!="No News")?("True ("+BeforeNewsForZeroProfit()+")"):("False"))
                           ,COLOR_TEXT);
     }

   if(showdashboard)
      smartcomment.Show();
  }
//+------------------------------------------------------------------+


