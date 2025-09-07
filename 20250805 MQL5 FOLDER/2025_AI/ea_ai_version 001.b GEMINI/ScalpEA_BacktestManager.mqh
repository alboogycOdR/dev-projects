
// **8. Backtest Manager Module**

// *   **Path:** `...\MQL5\Include\ScalpEA\ScalpEA_BacktestManager.mqh`
// *   **Filename:** `ScalpEA_BacktestManager.mqh`

// ```mql5
//+------------------------------------------------------------------+
//| ScalpEA_BacktestManager.mqh                                      |
//| Backtesting Manager Module for Scalp EA                          |
//| Designed to be used within the OnTester() function or standalone.|
//+------------------------------------------------------------------+
#property copyright "Copyright 2025"
#property link      "https://www.example.com"
#property strict

// Include required libraries
#include <Arrays\ArrayDouble.mqh>
#include <Arrays\ArrayString.mqh>
#include <Arrays\ArrayObj.mqh>
#include <Files\FileTxt.mqh>
#include <Math\Stat\Stat.mqh>
#include <Object.mqh>
#include <Trade\SymbolInfo.mqh> // Need for digits etc in reporting

// Include necessary project modules
#include "ScalpEA_ConfigManager.mqh" // Must exist
// Backtest Trade Record Structure (as defined before)
struct STradeRecord {
   ulong ticket; datetime openTime; datetime closeTime; string direction;
   double openPrice; double closePrice; double stopLoss; double takeProfit;
   double volume; double profit; double commission; double swap; string comment;
   double maxFavorableExcursion; double maxAdverseExcursion; // Can be added later if needed
};

// --- Structs & Classes ---

// Wrapper class for STradeRecord to use with CArrayObj
class STradeRecordWrapper : public CObject { public: STradeRecord record; };


// Backtest Period Class (as defined before)
class CBacktestPeriod : public CObject { public: datetime startDate; datetime endDate; string description; CBacktestPeriod(datetime s=0,datetime e=0,string d=""){startDate=s;endDate=e;description=d;} };
// Optimization Parameter Class (as defined before)
class COptimizationParam : public CObject { public: string name; double startValue; double stepValue; double endValue; bool enabled; COptimizationParam(string n="",double s=0,double st=0,double e=0,bool en=true){name=n;startValue=s;stepValue=st;endValue=e;enabled=en;} virtual int Compare(const CObject*n,const int m=0)const override{return StringCompare(name,((COptimizationParam*)n).name);} };

// Backtest Result Class (with calculations)
class CBacktestResult : public CObject {
public:
    string profileName; string symbol; ENUM_TIMEFRAMES timeframe; datetime startDate; datetime endDate; int backtestDurationDays;
    double initialBalance; double finalBalance; int totalTrades; int winTrades; int lossTrades; double winRate; double netProfit;
    double grossProfit; double grossLoss; double profitFactor; double averageTradeNet; double avgWin; double avgLoss; double payoffRatio;
    double maxDrawdownValue; double maxDrawdownPercent; double sharpeRatio; double sortinoRatio; double recoveryFactor;
    int maxConsecutiveWins; int maxConsecutiveLosses; double avgTradeDurationHours;
    CArrayDouble equityCurve; CArrayDouble balanceCurve; CArrayObj tradeRecords; // Array of STradeRecordWrapper*
    CSymbolInfo symbolInfo; // Store symbol info for reporting digits etc.

    CBacktestResult(){/*Zero everything*/symbolInfo.Name(_Symbol); /* Set symbol for default digits */}
    ~CBacktestResult(){tradeRecords.DeleteFreeObjects();} // Cleanup wrappers

    void CalculateMetrics(double initBalance) {
         initialBalance=initBalance; if(equityCurve.Total()>0)finalBalance=equityCurve.At(equityCurve.Total()-1); else finalBalance=initialBalance;
         netProfit=finalBalance-initialBalance; totalTrades=tradeRecords.Total(); backtestDurationDays=(endDate>startDate)?(int)((endDate-startDate)/(24*3600)):0; if(backtestDurationDays==0&&totalTrades>0)backtestDurationDays=1;
         winTrades=0; lossTrades=0; grossProfit=0; grossLoss=0; maxConsecutiveWins=0; maxConsecutiveLosses=0; int curW=0,curL=0; double totalDur=0; CArrayDouble tProfits;
         for(int i=0;i<totalTrades;i++){ STradeRecordWrapper*w=tradeRecords.At(i);if(w==NULL)continue; STradeRecord r=w.record; double np=r.profit+r.commission+r.swap; tProfits.Add(np); if(np>0){winTrades++;grossProfit+=np;curW++;curL=0;if(curW>maxConsecutiveWins)maxConsecutiveWins=curW;}else if(np<0){lossTrades++;grossLoss+=MathAbs(np);curL++;curW=0;if(curL>maxConsecutiveLosses)maxConsecutiveLosses=curL;}else{curW=0;curL=0;} if(r.closeTime>r.openTime)totalDur+=(double)(r.closeTime-r.openTime);}
         if(totalTrades>0){winRate=(double)winTrades/totalTrades*100.0; averageTradeNet=netProfit/totalTrades; avgTradeDurationHours=(totalDuration/totalTrades)/3600.0;}
         if(grossLoss>0)profitFactor=grossProfit/grossLoss; else if(grossProfit>0)profitFactor=1000.0; else profitFactor=0;
         if(winTrades>0)avgWin=grossProfit/winTrades; if(lossTrades>0)avgLoss=grossLoss/lossTrades; if(avgLoss>0)payoffRatio=avgWin/avgLoss; else payoffRatio=0;
         maxDrawdownValue=CalculateDrawdown(equityCurve,maxDrawdownPercent); if(maxDrawdownValue>0)recoveryFactor=netProfit/maxDrawdownValue; else recoveryFactor=(netProfit>0)?1000.0:0.0;
         CArrayDouble returns; CalculateReturns(equityCurve,returns); if(returns.Total()>1){sharpeRatio=CalculateSharpeRatio(returns); sortinoRatio=CalculateSortinoRatio(returns);} else {sharpeRatio=0; sortinoRatio=0;}
         balanceCurve.Clear(); balanceCurve.Add(initialBalance); double runBal=initialBalance; for(int i=0;i<totalTrades;i++){STradeRecordWrapper*w=tradeRecords.At(i); if(w==NULL)continue; runBal+=w.record.profit+w.record.commission+w.record.swap; balanceCurve.Add(runBal);}
    }
    private: double CalculateDrawdown(CArrayDouble &eq, double &pct){ maxDrawdownValue=0.0; pct=0.0; int total=eq.Total(); if(total<=1) return 0.0; double peak=eq.At(0); for(int i=1;i<total;i++){double cur=eq.At(i); if(cur>peak)peak=cur; else{double dd=peak-cur; if(dd>maxDrawdownValue){maxDrawdownValue=dd; if(peak>0)pct=(dd/peak)*100.0;}}} return maxDrawdownValue; }
    void CalculateReturns(CArrayDouble &eq, CArrayDouble &r){r.Clear(); int total=eq.Total(); if(total<=1) return; for(int i=1;i<total;i++){double pEq=eq.At(i-1); double cEq=eq.At(i); if(pEq<=0)continue; r.Add((cEq-pEq)/pEq);}}
    double CalculateSharpeRatio(CArrayDouble &r){int n=r.Total();if(n<=1)return 0.0; double mean=StatMean(r); double sd=StatStandardDeviation(r); return (sd<=0.0)?0.0:(mean/sd);}
    double CalculateSortinoRatio(CArrayDouble &r){int n=r.Total();if(n<=1)return 0.0; double mean=StatMean(r); double sumSqNeg=0.0; int negC=0; for(int i=0;i<n;i++){double ret=r.At(i);if(ret<0){sumSqNeg+=ret*ret;negC++;}} if(negC<=1||sumSqNeg<=0)return 0.0; double dd=MathSqrt(sumSqNeg/negC); return (dd<=0.0)?0.0:(mean/dd);}
    public: string GetSummaryString() { // Formatted summary string
        string s = ""; int d=symbolInfo.Digits(); if(d<0) d=2; // Ensure valid digits
        s+=StringFormat("Backtest: %s (%s->%s, %d Days)\n", profileName, TimeToString(startDate,TIME_DATE),TimeToString(endDate,TIME_DATE),backtestDurationDays);
        s+=StringFormat("Symbol: %s, TF: %s\n", symbol, EnumToString(timeframe)); s+="--------------------------------------\n";
        s+=StringFormat("Balance: %.2f -> %.2f (Net: %.2f, %.2f%%)\n", initialBalance,finalBalance,netProfit,(initialBalance>0)?(netProfit/initialBalance*100.0):0.0);
        s+=StringFormat("Trades: %d (W:%d L:%d), WinRate: %.2f%%\n",totalTrades,winTrades,lossTrades,winRate);
        s+=StringFormat("Profit Factor: %.2f (Gross P: %.2f, L: %.2f)\n", profitFactor, grossProfit, grossLoss);
        s+=StringFormat("Avg Trade: %.2f, Payoff Ratio: %.2f (W:%.2f, L:%.2f)\n", averageTradeNet, payoffRatio, avgWin, avgLoss);
        s+=StringFormat("Max DD: %.2f (%.2f%%), Recovery Factor: %.2f\n",maxDrawdownValue, maxDrawdownPercent, recoveryFactor);
        s+=StringFormat("Max Consec W: %d, L: %d, Avg Dur: %.1fh\n",maxConsecutiveWins, maxConsecutiveLosses, avgTradeDurationHours);
        s+=StringFormat("Sharpe: %.2f (approx), Sortino: %.2f (approx)\n", sharpeRatio, sortinoRatio); s+="--------------------------------------\n"; return s;
    }
    bool SaveTradeLog(string filePath) { if(totalTrades==0)return true; CFileTxt file; if(!file.Open(filePath,FILE_WRITE|FILE_CSV|FILE_ANSI,',',FILE_COMMON)){Print("Backtest Err: Open log fail '",filePath,"' Err:",GetLastError()); return false;} file.WriteString("Ticket,OpenTime,CloseTime,Dir,Vol,Open,Close,SL,TP,Profit,Comm,Swap,Comment\n"); int d=symbolInfo.Digits(); if(d<0) d=5; for(int i=0;i<totalTrades;i++){STradeRecordWrapper*w=tradeRecords.At(i); if(w==NULL)continue; STradeRecord r=w.record; string cmt=r.comment;StringReplace(cmt,",",";"); string l=(string)r.ticket+","+TimeToString(r.openTime,TIME_DATE|TIME_SECONDS)+","+TimeToString(r.closeTime,TIME_DATE|TIME_SECONDS)+","+r.direction+","+DoubleToString(r.volume,2)+","+DoubleToString(r.openPrice,d)+","+DoubleToString(r.closePrice,d)+","+DoubleToString(r.stopLoss,d)+","+DoubleToString(r.takeProfit,d)+","+DoubleToString(r.profit,2)+","+DoubleToString(r.commission,2)+","+DoubleToString(r.swap,2)+","+cmt+"\n"; file.WriteString(l); } file.Close(); Print("Backtest trade log saved: ",filePath); return true; }
};

// --- Backtest Manager Class ---
class CBacktestManager {
private:
    CConfigManager* m_configManager; bool m_ownConfigManager; string m_symbol; ENUM_TIMEFRAMES m_timeframe;
    datetime m_startDate; datetime m_endDate; double m_initialBalance; double m_commissionPerLot; double m_swapRateLong; double m_swapRateShort;
    int m_leverage; bool m_useTickData; bool m_isInitialized; bool m_isRunning; CBacktestResult m_results; CSymbolInfo symbolInfo;
    CArrayObj m_predefinedPeriods; CArrayObj m_optimizationParams;

    // --- Simulation Helpers --- (Simplified placeholders)
    string SimulateAIResponse(string reqType, datetime t){ int r=MathRand(); int d=symbolInfo.Digits(); double pnt=symbolInfo.Point(); double cP=iClose(m_symbol,m_timeframe,iBarShift(m_symbol,m_timeframe,t)); if(cP<=0)cP=iOpen(m_symbol,m_timeframe,iBarShift(m_symbol,m_timeframe,t)); if(cP<=0)return(reqType=="TradingSignal")?"NO_TRADE":"VALID"; if(reqType=="TradingSignal"){ if(r%10<4){double sl=Norm(cP-PipsToPrice(50),d);double tp=Norm(cP+PipsToPrice(100),d);return StringFormat("BUY at %.4f SL=%.4f TP=%.4f R:SimBuy",cP,sl,tp);} else if(r%10<8){double sl=Norm(cP+PipsToPrice(50),d);double tp=Norm(cP-PipsToPrice(100),d);return StringFormat("SELL at %.4f SL=%.4f TP=%.4f R:SimSell",cP,sl,tp);} else return "NO_TRADE R:SimNeut"; } else if(reqType=="StopLossValidation"){if(r%10<6)return"VALID";else if(r%10<8)return"ADJUST_UP";else if(r%10<9)return"ADJUST_DOWN";else return"CLOSE";} return "";}
    bool ParseSimulatedSignal(string s,string &dir,double &e,double &sl,double &tp){dir="";e=0;sl=0;tp=0;if(StringFind(s,"NO_TRADE")>=0)return false;if(StringFind(s,"BUY")>=0)dir="BUY";else if(StringFind(s,"SELL")>=0)dir="SELL";else return false; string p[];int n=StringSplit(s,' ',p); if(n>=6){for(int i=0;i<n;i++){if(p[i]=="at"&&i+1<n)e=StrToD(p[i+1]);if(StringFind(p[i],"SL=")==0)sl=StrToD(StringSubstr(p[i],3));if(StringFind(p[i],"TP=")==0)tp=StrToD(StringSubstr(p[i],3));}} if(e<=0||sl<=0)return false; return true;}
    double PipsToPrice(double pips){double pnt=symbolInfo.Point(); int d=symbolInfo.Digits(); double pM=10.0; if(d==4||d==2||d==0)pM=1.0; if(m_symbol=="XAUUSD")pM=10.0; return pips*pnt*pM;}
    double Norm(double v, int d){ return NormalizeDouble(v,d);} string StrTrim(string s){return StringTrimLeft(StringTrimRight(s));} double StrToD(string s){return StringToDouble(s);}
    void CleanupArrays(){m_predefinedPeriods.DeleteFreeObjects();m_optimizationParams.DeleteFreeObjects();m_results.tradeRecords.Clear();m_results.equityCurve.Clear();m_results.balanceCurve.Clear();}

public:
    CBacktestManager(CConfigManager* cfg=NULL){ m_isInitialized=false; m_isRunning=false; if(cfg!=NULL){m_configManager=cfg;m_ownConfigManager=false;}else{m_configManager=new CConfigManager();m_ownConfigManager=true;} m_predefinedPeriods.SetOwner(true); m_optimizationParams.SetOwner(true); m_results.tradeRecords.SetOwner(true); m_symbol=_Symbol;m_timeframe=_Period; m_initialBalance=10000;m_commissionPerLot=0;m_swapRateLong=0;m_swapRateShort=0;m_leverage=100;m_useTickData=false;}
    ~CBacktestManager(){ CleanupArrays(); if(m_ownConfigManager&&m_configManager!=NULL) delete m_configManager;}

    bool Initialize(string symbol,ENUM_TIMEFRAMES timeframe,datetime start,datetime end,double initialBalance,string profile="Default") {
        m_symbol=symbol;m_timeframe=timeframe;m_startDate=start;m_endDate=end;m_initialBalance=initialBalance;
        if(!symbolInfo.Name(m_symbol)){Print("BT Mgr Init Err: Bad Symbol ",m_symbol);return false;}
        if(m_configManager==NULL || !m_configManager.Initialize(profile)){Print("BT Mgr Init Err: Config Mgr fail/load profile '",profile,"'");return false;}
        m_results.profileName=profile; m_results.symbolInfo=symbolInfo; // Store symbol info in results
        m_commissionPerLot=symbolInfo.CommissionLot(); m_leverage=(int)AccountInfoInteger(ACCOUNT_LEVERAGE); // Get some account details
        InitializePredefinedPeriods(); InitializeOptimizationParams(); m_isInitialized=true;
        Print("Backtest Manager Initialized: ",m_symbol,"/",EnumToString(m_timeframe)," | ",TimeToString(m_startDate,TIME_DATE),"->",TimeToString(m_endDate,TIME_DATE)," | Profile:",profile," Bal:",m_initialBalance);
        return true;
    }
    void InitializePredefinedPeriods() { /* ... as defined before ... */ m_predefinedPeriods.Clear(); datetime ct=MQLInfoInteger(MQL_TESTER)?TimeTradeServer():TimeCurrent(); MqlDateTime dt;TimeToStruct(ct,dt); m_predefinedPeriods.Add(new CBacktestPeriod(ct-90*86400,ct,"Last 3 Months")); m_predefinedPeriods.Add(new CBacktestPeriod(ct-180*86400,ct,"Last 6 Months")); m_predefinedPeriods.Add(new CBacktestPeriod(ct-365*86400,ct,"Last 1 Year")); m_predefinedPeriods.Add(new CBacktestPeriod(StringToTime((string)dt.year+".01.01"),ct,"Year-to-Date")); if(dt.year>1970) m_predefinedPeriods.Add(new CBacktestPeriod(StringToTime((string)(dt.year-1)+".01.01"),StringToTime((string)(dt.year-1)+".12.31 23:59:59"),"Last Full Year")); m_predefinedPeriods.Add(new CBacktestPeriod(StrToTime("2023.01.01"),StrToTime("2023.06.30 23:59:59"),"Ex Bull 2023H1")); m_predefinedPeriods.Add(new CBacktestPeriod(StrToTime("2022.06.01"),StrToTime("2022.12.31 23:59:59"),"Ex Bear 2022H2"));}
    void GetPeriodDescriptions(CArrayString &d){d.Clear();for(int i=0;i<m_predefinedPeriods.Total();i++){CBacktestPeriod*p=m_predefinedPeriods.At(i);if(p!=NULL)d.Add(p.description);}}
    bool SetDatesByDescription(string d){for(int i=0;i<m_predefinedPeriods.Total();i++){CBacktestPeriod*p=m_predefinedPeriods.At(i);if(p!=NULL&&p.description==d){m_startDate=p.startDate;m_endDate=p.endDate;Print("BT Period set by '",d,"': ",TimeToString(m_startDate,TIME_DATE),"->",TimeToString(m_endDate,TIME_DATE));return true;}}Print("Err: Period '",d,"' not found.");return false;}
    void InitializeOptimizationParams() { /* ... as defined before ... */ m_optimizationParams.Clear(); m_optimizationParams.Add(new COptimizationParam("Inp_RiskPercent",0.5,0.5,3.0,true)); m_optimizationParams.Add(new COptimizationParam("Inp_InitialSLPips",20.0,10.0,100.0,true)); m_optimizationParams.Add(new COptimizationParam("Inp_TrailingSLPips",10.0,5.0,50.0,false)); m_optimizationParams.Add(new COptimizationParam("Inp_MinProfitToRisk",1.0,0.5,3.0,true)); m_optimizationParams.Add(new COptimizationParam("Inp_MaxTrades",1.0,1.0,5.0,true));}
    const CArrayObj* GetOptimizationParams() const { return &m_optimizationParams; }

    // Run Backtest Simulation (OHLC Based)
    bool RunBacktest() {
        if(!m_isInitialized || m_isRunning){Print("BT Run Err: Not ready.");return false;} if(m_startDate>=m_endDate){Print("BT Run Err: Bad Dates."); return false;}
        m_isRunning=true; Print("Starting Backtest Simulation..."); CleanupArrays(); // Clear previous results before starting
        m_results=CBacktestResult(); m_results.symbol=m_symbol; m_results.timeframe=m_timeframe; m_results.startDate=m_startDate; m_results.endDate=m_endDate; m_results.initialBalance=m_initialBalance; m_results.profileName=m_configManager?m_configManager.GetCurrentProfile():"N/A"; m_results.equityCurve.Add(m_initialBalance); m_results.symbolInfo=symbolInfo; // Store symbol info
        // Load params from config for this run
        double riskP=m_configManager?m_configManager.GetRiskPercent():1.0; double iSLp=m_configManager?m_configManager.GetInitialSLPips():50.0; double tSLp=m_configManager?m_configManager.GetTrailingSLPips():0; double rr=m_configManager?m_configManager.GetMinProfitToRisk():1.5; int maxT=m_configManager?m_configManager.GetMaxTrades():3;
        datetime curT=m_startDate; CArrayObj openP; openP.SetOwner(false); long totalB=iBars(m_symbol,m_timeframe,m_startDate,m_endDate); Print("Total bars: ",totalB); if(totalB<=0){m_isRunning=false;return false;}
        double curEq=m_initialBalance, curBal=m_initialBalance; int digits=symbolInfo.Digits(); double point=symbolInfo.Point(); double tickV=symbolInfo.TickValue(); double tickS=symbolInfo.TickSize(); double pointV=(tickS>0)?tickV/(tickS/point):0;

        for(long bIdx=totalB-1; bIdx>=0; bIdx--){
            curT=iTime(m_symbol,m_timeframe,bIdx); if(curT<m_startDate||curT>m_endDate)continue; if(IsStopped()){Print("BT Aborted by user."); break;}
            double bO=iOpen(m_symbol,m_timeframe,bIdx); double bH=iHigh(m_symbol,m_timeframe,bIdx); double bL=iLow(m_symbol,m_timeframe,bIdx); double bC=iClose(m_symbol,m_timeframe,bIdx); double floatPnL=0;
            // Process existing trades
            for(int i=openP.Total()-1; i>=0; i--){
                STradeRecordWrapper*w=openP.At(i); if(w==NULL)continue; STradeRecord &trade=w.record; bool closed=false; double cP=bC; string cRsn="";
                if(trade.direction=="BUY"){ if(trade.takeProfit>0 && bH>=trade.takeProfit){closed=true;cP=trade.takeProfit;cRsn="TP";} else if(trade.stopLoss>0 && bL<=trade.stopLoss){closed=true;cP=trade.stopLoss;cRsn="SL";} }
                else{ if(trade.takeProfit>0 && bL<=trade.takeProfit){closed=true;cP=trade.takeProfit;cRsn="TP";} else if(trade.stopLoss>0 && bH>=trade.stopLoss){closed=true;cP=trade.stopLoss;cRsn="SL";} }
                if(!closed && bIdx%10==0){ string v=SimulateAIResponse("StopLossValidation",curT); if(v=="CLOSE"){closed=true;cP=bC;cRsn="AI Cls";} else if(v=="ADJUST_UP"){/*Widen*/if(trade.direction=="BUY")trade.stopLoss-=PipsToPrice(20); else trade.stopLoss+=PipsToPrice(20); trade.stopLoss=Norm(trade.stopLoss,digits);} else if(v=="ADJUST_DOWN"){/*Tighten*/double adj=PipsToPrice(20); if(trade.direction=="BUY"&&(trade.stopLoss+adj)<trade.openPrice)trade.stopLoss+=adj; else if(trade.direction=="SELL"&&(trade.stopLoss-adj)>trade.openPrice)trade.stopLoss-=adj; trade.stopLoss=Norm(trade.stopLoss,digits);}}
                if(!closed && tSLp>0){double trailD=PipsToPrice(tSLp);double pSL=0; if(trade.direction=="BUY"){pSL=Norm(bC-trailD,digits);if(pSL>trade.stopLoss && pSL>trade.openPrice)trade.stopLoss=pSL;}else{pSL=Norm(bC+trailD,digits);if(pSL<trade.stopLoss && pSL<trade.openPrice)trade.stopLoss=pSL;}}
                if(closed){ trade.closeTime=curT; trade.closePrice=cP; trade.comment=cRsn; double pnts=0; if(trade.direction=="BUY")pnts=(cP-trade.openPrice)/point; else pnts=(trade.openPrice-cP)/point; trade.profit=pnts*pointV*trade.volume; trade.commission=-m_commissionPerLot*trade.volume; trade.swap=0; curBal+=trade.profit+trade.commission+trade.swap; m_results.tradeRecords.Add(w); openP.Delete(i); }
                else{ double pnts=0; if(trade.direction=="BUY")pnts=(bC-trade.openPrice)/point; else pnts=(trade.openPrice-bC)/point; floatPnL+=pnts*pointV*trade.volume - m_commissionPerLot*trade.volume;}
            } // End processing open positions
            // Check for new signal
            if(openP.Total()<maxT){ string sig=SimulateAIResponse("TradingSignal",curT); string dir; double e,sl,tp; if(ParseSimulatedSignal(sig,dir,e,sl,tp)){ if(((dir=="BUY"&&sl<e)||(dir=="SELL"&&sl>e))&&((dir=="BUY"&&tp>e)||(dir=="SELL"&&tp<e))){ STradeRecordWrapper*nw=new STradeRecordWrapper(); STradeRecord &nt=nw.record; nt.ticket=m_results.tradeRecords.Total()+openP.Total()+1; nt.openTime=curT; nt.direction=dir; nt.openPrice=bO; nt.stopLoss=sl; nt.takeProfit=tp; nt.volume=0.01; /*Simple Lot*/ nt.closeTime=0; nt.profit=0; nt.commission=0; nt.swap=0; nt.comment="Opened"; openP.Add(nw); /*Print(TimeToString(curT)," Opened ",dir," #",nt.ticket);*/ }}}
            curEq=curBal+floatPnL; m_results.equityCurve.Add(curEq); // Update Equity Curve
        } // End Bar Loop
        // Close remaining positions
        for(int i=openP.Total()-1;i>=0;i--){STradeRecordWrapper*w=openP.At(i);if(w==NULL)continue; STradeRecord &t=w.record; t.closeTime=m_endDate; t.closePrice=iClose(m_symbol,m_timeframe,0); if(t.closePrice<=0)t.closePrice=t.openPrice; t.comment="End Test"; double pts=0;if(t.direction=="BUY")pts=(t.closePrice-t.openPrice)/point;else pts=(t.openPrice-t.closePrice)/point; t.profit=pts*pointV*t.volume; t.commission=-m_commissionPerLot*t.volume; t.swap=0; m_results.tradeRecords.Add(w);} openP.Clear();
        m_results.endDate=curT; m_results.CalculateMetrics(m_initialBalance); m_isRunning=false; Print("Backtest Simulation Completed."); Print(m_results.GetSummaryString()); return true;
    }
    const CBacktestResult* GetResults() const { return &m_results; }
    CConfigManager* GetConfigManager() { return m_configManager; } // Allow access to config
    bool SaveResults(string baseFileName = "ScalpEA_Backtest") { // Save summary and log
        if(m_isRunning || m_results.totalTrades==0){return false;} string path=TerminalInfoString(TERMINAL_DATA_PATH)+"\\MQL5\\Files\\"; string sumFile=path+baseFileName+"_Summary_"+m_results.profileName+".txt"; string logFile=path+baseFileName+"_TradeLog_"+m_results.profileName+".csv"; CFileTxt sFile; if(sFile.Open(sumFile,FILE_WRITE|FILE_TXT|FILE_ANSI,FILE_COMMON)){sFile.WriteString(m_results.GetSummaryString()); sFile.Close(); Print("BT Summary saved: ",sumFile);} else {Print("Err save summary: ",GetLastError());return false;} if(!m_results.SaveTradeLog(logFile)){return false;} return true;}
};
//+------------------------------------------------------------------+