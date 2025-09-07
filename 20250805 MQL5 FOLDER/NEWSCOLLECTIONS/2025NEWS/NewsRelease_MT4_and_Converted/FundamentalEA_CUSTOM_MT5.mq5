/*



todo:

  mechanism not to query ENDPOINT so persistently


*/




//===NEWSRELEASE   EA=================================================================================================================================================//
#property description "CUSTOM _ This expert is a fully automated trading system. It get econimic news and place orders"

//#property icon        "\\Images\\NewsRelease_Logo.ico";
/*

      Information

      Please make some test on a demo account to see how works expert before using it on a real account.

      For 0.01 lot size on account with leverage 1:500 needed initial balance at least for each pair 100 to working safely.

      The expert can't make backtesting, because use economical news on real time. The orders on back testing are totally random to pass tests.




      News to use and pairs to trade per news

      In EUR news can trade: EURGBP, EURAUD, EURNZD, EURUSD, EURCAD, EURCHF, EURJPY.
      In GBP news can trade: EURGBP, GBPAUD, GBPNZD, GBPUSD, GBPCAD, GBPCHF, GBPJPY.
      In AUD news can trade: EURAUD, GBPAUD, AUDNZD, AUDUSD, AUDCAD, AUDCHF, AUDJPY.
      In NZD news can trade: EURNZD, GBPNZD, AUDNZD, NZDUSD, NZDCAD, NZDCHF, NZDJPY.
      In USD news can trade: EURUSD, GBPUSD, AUDUSD, NZDUSD, USDCAD, USDCHF, USDJPY.
      In CAD news can trade: EURCAD, GBPCAD, AUDCAD, NZDCAD, USDCAD, CADCHF, CADJPY.
      In CHF news can trade: EURCHF, GBPCHF, AUDCHF, NZDCHF, USDCHF, CADCHF, CHFJPY.
      In JPY news can trade: EURJPY, GBPJPY, AUDJPY, NZDJPY, EURJPY, CADJPY, CHFJPY.
      In CNY news can trade: EURCNY/EURCNH, USDCNY/USDCNH, JPYCNY/JPYCNH. (Some broker use CNY symbol, and some use CNH for yu�n)



*/
#property strict
struct news_event_struct
  {
   string            currency;
   string            event_title;
   datetime          event_time;
   string            event_impact;
  } news_events[500];
  int event_count=0,time_offset=0;
  input string title_phrase="Non-Farm,Unemployment,ISM,PMI,CPI,FOMC,Retail Sales,Final GDP q/q,Core PCE Price Index m/m,Empire State Manufacturing Index,Advance GDP q/q,JOLTS";//title keyword (comma seperated)
input bool   include_high = true;       // Include high
input bool   include_medium = true;    // Include medium
input bool   include_low = false;       // Include low
//====================================================================================================================================================//
enum ModeWorkEnum {SlowMode_EveryTick, FastMode_PerMinute};

enum Strategies {
   Custom_Stategy,
   Recovery_Orders_Strategy,
   Basket_Orders_Strategy,
   Separate_Orders_Strategy,
   Replace_Orders_Strategy
};

enum ImpactEnum {Low_Medium_High, Medium_High, Only_High};
enum TradeWay {
   Not_Trade,
   Trade_In_News,
   Trade_From_Panel
};
enum Levels {Fixed_SL_TP, Based_On_ATR_SL_TP};
enum TimeInfoEnum {Time_In_Minutes, Format_D_H_M};
//====================================================================================================================================================//
#define TITLE      0
#define COUNTRY    1
#define DATE       2
#define TIME       3
#define IMPACT     4
#define FORECAST   5
#define PREVIOUS   6
#define PairsTrade 60
#define Currency   10
#define NoOfImages 60
//====================================================================================================================================================//
input group  "||====== Read News And GMT Settings ======||";
input ModeWorkEnum ModeReadNews        = FastMode_PerMinute;//Mode To Read News
input string ReadNewsURL               = "https://nfs.faireconomy.media/ff_calendar_thisweek.xml";//URL To Get News
input int    GMT_OffsetHours           = 2;//GMT Offset
input int    MillisecondTimer          = 1000;//Set Timer Milliseconds
int    _MillisecondTimer          = MillisecondTimer;//Set Timer Milliseconds


input group "||====== Strategies Settings ======||";
input Strategies StrategyToUse         = Custom_Stategy;//Select Mode Of Strategy
input group  "||====== Money Management Settings ======||";
input bool   MoneyManagement           = false;//Automatically Lot Size
input double RiskFactor                = 10;//Risk Factor For Automatically Lot Size
input double ManualLotSize             = 0.01;//Manually Lot Size


input group  "||====== Advanced Settings ======||";
input int    MinutesBeforeNewsStart    = 5;//Minutes Befor Events Start Trade
int    _MinutesBeforeNewsStart    = MinutesBeforeNewsStart;//Minutes Befor Events Start Trade
input int    MinutesAfterNewsStop      = 5;//Minutes After Events Stop Trade
int    _MinutesAfterNewsStop      = MinutesAfterNewsStop;//Minutes After Events Stop Trade
input bool   TradeOneTimePerNews       = true;//Trade One Time Per Event
input ImpactEnum ImpactToTrade         = Only_High;//Impact Of Events Trade
input bool   IncludeSpeaks             = true;//Includ Speaks As Events

input group  "||====== EUR News Release Settings ======||";
input TradeWay EUR_TradeInNewsRelease  = Trade_In_News;//Set Mode Trade On EUR Events
TradeWay _EUR_TradeInNewsRelease  = EUR_TradeInNewsRelease;//Set Mode Trade On EUR Events
input string EUR_TimeStartSession      = "00:00:00";//Set Time Start Trade On EUR Events
input string EUR_TimeEndSession        = "00:00:00";//Set Time Stop Trade On EUR Events
input bool   EUR_Trade_EURGBP          = true;//Trade EURGBP On EUR Events
input bool   EUR_Trade_EURAUD          = true;//Trade EURAUD On EUR Events
input bool   EUR_Trade_EURNZD          = true;//Trade EURNZD On EUR Events
input bool   EUR_Trade_EURUSD          = true;//Trade EURUSD On EUR Events
input bool   EUR_Trade_EURCAD          = true;//Trade EURCAD On EUR Events
input bool   EUR_Trade_EURCHF          = true;//Trade EURCHF On EUR Events
input bool   EUR_Trade_EURJPY          = true;//Trade EURJPY On EUR Events



input group "||====== GBP News Release Settings ======||";
input TradeWay GBP_TradeInNewsRelease  = Trade_In_News;//Set Mode Trade On GBP Events
TradeWay _GBP_TradeInNewsRelease  = GBP_TradeInNewsRelease;//Set Mode Trade On GBP Events
input string GBP_TimeStartSession      = "00:00:00";//Set Time Start Trade On GBP Events
input string GBP_TimeEndSession        = "00:00:00";//Set Time Stop Trade On GBP Events
input bool   GBP_TradeIn_EURGBP        = true;//Trade EURGBP On GBP Events
input bool   GBP_TradeIn_GBPAUD        = true;//Trade GBPAUD On GBP Events
input bool   GBP_TradeIn_GBPNZD        = true;//Trade GBPNZD On GBP Events
input bool   GBP_TradeIn_GBPUSD        = true;//Trade GBPUSD On GBP Events
input bool   GBP_TradeIn_GBPCAD        = true;//Trade GBPCAD On GBP Events
input bool   GBP_TradeIn_GBPCHF        = true;//Trade GBPCHF On GBP Events
input bool   GBP_TradeIn_GBPJPY        = true;//Trade GBPJPY On GBP Events



input group  "||====== AUD News Release Settings ======||";
input TradeWay AUD_TradeInNewsRelease  = Trade_In_News;//Set Mode Trade On AUD Events
TradeWay _AUD_TradeInNewsRelease  = AUD_TradeInNewsRelease;//Set Mode Trade On AUD Events
input string AUD_TimeStartSession      = "00:00:00";//Set Time Start Trade On AUD Events
input string AUD_TimeEndSession        = "00:00:00";//Set Time Stop Trade On AUD Events
input bool   AUD_TradeIn_EURAUD        = true;//Trade EURAUD On AUD Events
input bool   AUD_TradeIn_GBPAUD        = true;//Trade GBPAUD On AUD Events
input bool   AUD_TradeIn_AUDNZD        = true;//Trade AUDNZD On AUD Events
input bool   AUD_TradeIn_AUDUSD        = true;//Trade AUDUSD On AUD Events
input bool   AUD_TradeIn_AUDCAD        = true;//Trade AUDCAD On AUD Events
input bool   AUD_TradeIn_AUDCHF        = true;//Trade AUDCHF On AUD Events
input bool   AUD_TradeIn_AUDJPY        = true;//Trade AUDJPY On AUD Events



input group  "||====== NZD News Release Settings ======||";
input TradeWay NZD_TradeInNewsRelease  = Trade_In_News;//Set Mode Trade On NZD Events
TradeWay _NZD_TradeInNewsRelease  = NZD_TradeInNewsRelease;//Set Mode Trade On NZD Events
input string NZD_TimeStartSession      = "00:00:00";//Set Time Start Trade On NZD Events
input string NZD_TimeEndSession        = "00:00:00";//Set Time Stop Trade On NZD Events
input bool   NZD_TradeIn_EURNZD        = true;//Trade EURNZD On NZD Events
input bool   NZD_TradeIn_GBPNZD        = true;//Trade GBPNZD On NZD Events
input bool   NZD_TradeIn_AUDNZD        = true;//Trade AUDNZD On NZD Events
input bool   NZD_TradeIn_NZDUSD        = true;//Trade NZDUSD On NZD Events
input bool   NZD_TradeIn_NZDCAD        = true;//Trade NZDCAD On NZD Events
input bool   NZD_TradeIn_NZDCHF        = true;//Trade NZDCHF On NZD Events
input bool   NZD_TradeIn_NZDJPY        = true;//Trade NZDJPY On NZD Events



input group  "||====== USD News Release Settings ======||";
input TradeWay USD_TradeInNewsRelease  = Trade_In_News;//Set Mode Trade On USD Events
TradeWay _USD_TradeInNewsRelease  = USD_TradeInNewsRelease;//Set Mode Trade On USD Events
input string USD_TimeStartSession      = "00:00:00";//Set Time Start Trade On USD Events
input string USD_TimeEndSession        = "00:00:00";//Set Time Stop Trade On USD Events
input bool   USD_TradeIn_EURUSD        = true;//Trade EURUSD On USD Events
input bool   USD_TradeIn_GBPUSD        = true;//Trade GBPUSD On USD Events
input bool   USD_TradeIn_AUDUSD        = true;//Trade AUDUSD On USD Events
input bool   USD_TradeIn_NZDUSD        = true;//Trade NZDUSD On USD Events
input bool   USD_TradeIn_USDCAD        = true;//Trade USDCAD On USD Events
input bool   USD_TradeIn_USDCHF        = true;//Trade USDCHF On USD Events
input bool   USD_TradeIn_USDJPY        = true;//Trade USDJPY On USD Events


input group "||====== CAD News Release Settings ======||";
input TradeWay CAD_TradeInNewsRelease  = Trade_In_News;//Set Mode Trade On CAD Events
TradeWay _CAD_TradeInNewsRelease  = CAD_TradeInNewsRelease;//Set Mode Trade On CAD Events
input string CAD_TimeStartSession      = "00:00:00";//Set Time Start Trade On CAD Events
input string CAD_TimeEndSession        = "00:00:00";//Set Time Stop Trade On CAD Events
input bool   CAD_TradeIn_EURCAD        = true;//Trade EURCAD On CAD Events
input bool   CAD_TradeIn_GBPCAD        = true;//Trade GBPCAD On CAD Events
input bool   CAD_TradeIn_AUDCAD        = true;//Trade AUDCAD On CAD Events
input bool   CAD_TradeIn_NZDCAD        = true;//Trade NZDCAD On CAD Events
input bool   CAD_TradeIn_USDCAD        = true;//Trade USDCAD On CAD Events
input bool   CAD_TradeIn_CADCHF        = true;//Trade CADCHF On CAD Events
input bool   CAD_TradeIn_CADJPY        = true;//Trade CADJPY On CAD Events



input group  "||====== CHF News Release Settings ======||";
input TradeWay CHF_TradeInNewsRelease  = Trade_In_News;//Set Mode Trade On CHF Events
TradeWay _CHF_TradeInNewsRelease  = CHF_TradeInNewsRelease;//Set Mode Trade On CHF Events
input string CHF_TimeStartSession      = "00:00:00";//Set Time Start Trade On CHF Events
input string CHF_TimeEndSession        = "00:00:00";//Set Time Stop Trade On CHF Events
input bool   CHF_TradeIn_EURCHF        = true;//Trade EURCHF On CHF Events
input bool   CHF_TradeIn_GBPCHF        = true;//Trade GBPCHF On CHF Events
input bool   CHF_TradeIn_AUDCHF        = true;//Trade AUDCHF On CHF Events
input bool   CHF_TradeIn_NZDCHF        = true;//Trade NZDCHF On CHF Events
input bool   CHF_TradeIn_USDCHF        = true;//Trade USDCHF On CHF Events
input bool   CHF_TradeIn_CADCHF        = true;//Trade CADCHF On CHF Events
input bool   CHF_TradeIn_CHFJPY        = true;//Trade CHFJPY On CHF Events



input group  "||====== JPY News Release Settings ======||";
input TradeWay JPY_TradeInNewsRelease  = Trade_In_News;//Set Mode Trade On JPY Events
TradeWay _JPY_TradeInNewsRelease  = JPY_TradeInNewsRelease;//Set Mode Trade On JPY Events
input string JPY_TimeStartSession      = "00:00:00";//Set Time Start Trade On JPY Events
input string JPY_TimeEndSession        = "00:00:00";//Set Time Stop Trade On JPY Events
input bool   JPY_TradeIn_EURJPY        = true;//Trade EURJPY On JPY Events
input bool   JPY_TradeIn_GBPJPY        = true;//Trade GBPJPY On JPY Events
input bool   JPY_TradeIn_AUDJPY        = true;//Trade AUDJPY On JPY Events
input bool   JPY_TradeIn_NZDJPY        = true;//Trade NZDJPY On JPY Events
input bool   JPY_TradeIn_USDJPY        = true;//Trade USDJPY On JPY Events
input bool   JPY_TradeIn_CADJPY        = true;//Trade CADJPY On JPY Events
input bool   JPY_TradeIn_CHFJPY        = true;//Trade CHFJPY On JPY Events



input group "||====== CNY News Release Settings ======||";
input TradeWay CNY_TradeInNewsRelease  = Not_Trade;//Set Mode Trade On CNY Events
TradeWay _CNY_TradeInNewsRelease  = CNY_TradeInNewsRelease;//Set Mode Trade On CNY Events
input string CNY_TimeStartSession      = "00:00:00";//Set Time Start Trade On CNY Events
input string CNY_TimeEndSession        = "00:00:00";//Set Time Stop Trade On CNY Events
input bool   CNY_TradeIn_EURCNY        = false;//Trade EURCNY On CNY Events
input bool   CNY_TradeIn_USDCNY        = false;//Trade USDCNY On CNY Events
input bool   CNY_TradeIn_JPYCNY        = false;//Trade JPYCNY On CNY Events
input string BrokerSymbolFor_CNY       = "CNY";//Set Broker's Symbol For Yuan

input group  "||====== Pending Orders Settings ======||";
input double DistancePendingOrders     = 10.0;//Distance Pips For Pending Orders
input bool   UseModifyPending          = false;//Modify Pending Orders
bool   _UseModifyPending          = UseModifyPending;//Modify Pending Orders
input double StepModifyPending         = 1.0;//Step Pips Modify Pending Orders
input int    DelayModifyPending        = 30;//Ticks Delay Modify Pending Orders
input bool   ModifyAfterEvent          = false;//Modify Pending Orders After Events
bool   _ModifyAfterEvent          = ModifyAfterEvent;//Modify Pending Orders After Events
input bool   DeleteOrphanPending       = true;//Delete Remaining Order When One Of The two Triggered
bool   _DeleteOrphanPending       = DeleteOrphanPending;//Delete Remaining Order When One Of The two Triggered
input bool   DeleteOrdersAfterEvent    = true;//Delete Pending Orders After Event
bool   _DeleteOrdersAfterEvent    = DeleteOrdersAfterEvent;//Delete Pending Orders After Event
input int    MinutesExpireOrders       = 60;//Minutes Expiry Pending Orders
int    _MinutesExpireOrders       = MinutesExpireOrders;//Minutes Expiry Pending Orders

input group "||====== Market Orders Setting ======||";
input Levels TypeOf_TP_and_SL          = Fixed_SL_TP;//Uses Fixed Or Based ATR Levels Profit And Loss
input bool   UseTralingStopLoss        = false;//Run Trailing Stop
bool   _UseTralingStopLoss        = UseTralingStopLoss;//Run Trailing Stop
input double TrailingStopStep          = 1.0;//Trailing Stop's Pips
input bool   UseStopLoss               = true;//Use Stop Loss
bool   _UseStopLoss               = UseStopLoss;//Use Stop Loss
input double OrdersStopLoss            = 10.0;//Set Stop Loss (If TypeOf_TP_and_SL=Fixed_SL_TP)
double _OrdersStopLoss            = OrdersStopLoss;//Set Stop Loss (If TypeOf_TP_and_SL=Fixed_SL_TP)
input bool   UseTakeProfit             = true;//Use Take Profit
bool   _UseTakeProfit             = UseTakeProfit;//Use Take Profit
input double OrdersTakeProfit          = 15.0;//Set Take Profit (If TypeOf_TP_and_SL=Fixed_SL_TP)
input bool   UseBreakEven              = true;//Use Break Even
input double BreakEvenPips             = 15.0;//Break Even's Pips
input double BreakEVenAfter            = 5.0;//Pips Profit To Activate Break Even
input bool   CloseOrdersAfterEvent     = false;//Close All Orders After Event
bool   _CloseOrdersAfterEvent     = CloseOrdersAfterEvent;//Close All Orders After Event

input group  "||====== ATR Indicator Setting ======||";
input int    ATR_Period                = 7;//ATR Period
input double ATR_Multiplier            = 3.5;//ATR Multiplier Value For Stop Loss
input double TakeProfitMultiplier      = 1.5;//Stop Loss Multiplier For Take Profit

input group  "||====== Basket Orders Setting ======||";
input bool   CloseAllOrdersAsOne       = false;//Run Basket Mode Manage Orders
bool   _CloseAllOrdersAsOne       = CloseAllOrdersAsOne;//Run Basket Mode Manage Orders
input bool   WaitToTriggeredAllOrders  = false;//Whait To Triggered All Pending
bool   _WaitToTriggeredAllOrders  = WaitToTriggeredAllOrders;//Whait To Triggered All Pending
input double LevelCloseAllInLoss       = 500.0;//Level Close All In Losses
input double LevelCloseAllInProfit     = 100.0;//Level Close All In Profits

input group  "||====== Replace Mode Setting ======||";
input bool   UseReplaceMode            = false;//Run Replace Mode When Closed All Orders
bool   _UseReplaceMode            = UseReplaceMode;//Run Replace Mode When Closed All Orders
input bool   RunReplaceAfterNewsEnd    = false;//Run Replace Mode After Events
bool   _RunReplaceAfterNewsEnd    = RunReplaceAfterNewsEnd;//Run Replace Mode After Events
input double ReplaceOrdersStopLoss     = 10.0;//Set Stop Loss (If TypeOf_TP_and_SL=Fixed_SL_TP)
input double ReplaceOrdersTakeProfit   = 15.0;//Set Take Profit (If TypeOf_TP_and_SL=Fixed_SL_TP)
input bool   DeleteOrphanIfGetProfit   = true;//Delete Remaining Order When One Of The two Triggered
bool   _DeleteOrphanIfGetProfit   = DeleteOrphanIfGetProfit;//Delete Remaining Order When One Of The two Triggered
input group  "||====== Recovery Mode Setting ======||";
//input bool   _UseRecoveryMode           = false;//Run Recovery Mode If Loss Order
//input bool   _RunRecoveryAfterNewsEnd   = false;//Run Recovery Mode After Events
input bool   UseRecoveryMode           = false;//Run Recovery Mode If Loss Order
bool   _UseRecoveryMode           = UseRecoveryMode;//Run Recovery Mode If Loss Order
input bool   RunRecoveryAfterNewsEnd   = false;//Run Recovery Mode After Events
bool   _RunRecoveryAfterNewsEnd   = RunRecoveryAfterNewsEnd;//Run Recovery Mode After Events
input double RecoveryMultiplierLot     = 3.0;//Recovery Multiplier Lot Size
input double RecoveryOrdersStopLoss    = 10.0;//Set Stop Loss (If TypeOf_TP_and_SL=Fixed_SL_TP)
input double RecoveryOrdersTakeProfit  = 15.0;//Set Take Profit (If TypeOf_TP_and_SL=Fixed_SL_TP)


input group "||========= Button Panel Sets =========||";
input bool   UseConfirmationMessage    = true;//Use Confirmation Message For Buttons
input color  ColorOpenButton           = clrDodgerBlue;//Open Buttons's Color
input color  ColorCloseButton          = clrFireBrick;//Close Buttons's Color
input color  ColorDeleteButton         = clrOrange;//Delete Buttons's Color
input color  ColorFontButton           = clrBlack;//Buttons's Text Color
input group  "||====== Analyzer Setting ======||";
input bool   RunAnalyzerTrades         = true;//Run Trades Analyzer
input int    SizeFontsOfInfo           = 10;//Text's Size
input color  ColorOfTitle              = clrMaroon;//Title Text's Color
input color  ColorOfInfo               = clrBeige;//Info Text's Color
input color  ColorLineTitles           = clrOrange;//Title Line's Color
input color  ColorOfLine1              = clrMidnightBlue;//First Line's Color
input color  ColorOfLine2              = clrDarkSlateGray;//Second Line's Color
input group  "||====== Set Text In Screen ======||";
input TimeInfoEnum ShowInfoTime        = Time_In_Minutes;//Show Time's Format
input color  TextColor1                = clrPowderBlue;//Text's Color
input color  TextColor2                = clrKhaki;//Text's Color
input color  TextColor3                = clrFireBrick;//Text's Color
input color  TextColor4                = clrDodgerBlue;//Text's Color

input group  "||====== Delete Objects/Orders Settings ======||";
input bool   DeletePendingInExit       = false;//Delete Pending Orders If Unload Expert
input bool   DeleteObjectsAfterEvent   = false;//Delete All Objects After Events

input group  "||====== General Settings ======||";
input string PairPrefix                = "";//Pairs' Prefix
input int    Slippage                  = 3;//Maximum Accepted Slippage
int    MagicNumber               = 0;//Magic Number (if MagicNumber=0, expert generate automatically)
input string OrdersComments            = "FundamentalEA";//Order's Comment
input group "||====== Chart Interface Settings ======||";
input bool   SetChartInterface         = true;//Set Chart's Interface
//====================================================================================================================================================//
//global fields
string ExpertName;
string PairSuffix;
string CommentPrefix;
string Pair[PairsTrade];
double STOPLEVELVALUE;
double HistoryProfitLoss;
double OrderLotSize=0;
double PipsLevelPending;
double PipsLoss;
double PipsProfits;
double RecoveryPipsLoss;
double RecoveryPipsProfits;
double TotalProfitLoss;
double TotalOrdesLots;
double ProfitLoss[99];
double OrdesLots[99];
double TPVALUE=0;
double SLVALUE=0;
double ResultsCurrencies[PairsTrade];
int I_INDEXER;
int j;
int SecondsBeforeNewsStart;
int SecondsAfterNewsStop;
int OpenMarketOrders[99];
int OpenPendingOrders[99];
int TotalOpenMarketOrders;
int TotalOpenPendingOrders;
int TotalOpenOrders;
int HistoryTrades;
int MultiplierPoint;
int OrdersID;
int PairID[PairsTrade];
int BuyOrders[PairsTrade];
int SellOrders[PairsTrade];
int BuyStopOrders[PairsTrade];
int SellStopOrders[PairsTrade];
int CountTickBuyStop[PairsTrade];
int CountTickSellStop[PairsTrade];
int TotalPairs=PairsTrade;
bool AvailablePair[PairsTrade];
int TotalImages=NoOfImages;
bool CheckOrdersBaseNews;
bool TimeToTrade_USD=false;
bool TimeToTrade_EUR=false;
bool TimeToTrade_GBP=false;
bool TimeToTrade_NZD=false;
bool TimeToTrade_JPY=false;
bool TimeToTrade_AUD=false;
bool TimeToTrade_CHF=false;
bool TimeToTrade_CAD=false;
bool TimeToTrade_CNY=false;
datetime Expire=0;
datetime LastTradeTime[PairsTrade];
static int iPrevMinute=-1;
bool OpenSession[Currency];
int LoopTimes=0;
int LastTradeType[PairsTrade];
int WarningMessage;
int TotalHistoryOrders[PairsTrade];
double TotalHistoryProfit[PairsTrade];
//---------------------------------------------------------------------
double PriceOpenBuyStopOrder[99];
double PriceOpenSellStopOrder[99];
double LastTradeLot[PairsTrade];
double LastTradeProfitLoss[PairsTrade];
double SecondsSinceNews_USD=0;
double SecondsToNews_USD=0;
double ImpactSinceNews_USD=0;
double ImpactToNews_USD=0;
double SecondsSinceNews_EUR=0;
double SecondsToNews_EUR=0;
double ImpactSinceNews_EUR=0;
double ImpactToNews_EUR=0;
double SecondsSinceNews_GBP=0;
double SecondsToNews_GBP=0;
double ImpactSinceNews_GBP=0;
double ImpactToNews_GBP=0;
double SecondsSinceNews_NZD=0;
double SecondsToNews_NZD=0;
double ImpactSinceNews_NZD=0;
double ImpactToNews_NZD=0;
double SecondsSinceNews_JPY=0;
double SecondsToNews_JPY=0;
double ImpactSinceNews_JPY=0;
double ImpactToNews_JPY=0;
double SecondsSinceNews_AUD=0;
double SecondsToNews_AUD=0;
double ImpactSinceNews_AUD=0;
double ImpactToNews_AUD=0;
double SecondsSinceNews_CHF=0;
double SecondsToNews_CHF=0;
double ImpactSinceNews_CHF=0;
double ImpactToNews_CHF=0;
double SecondsSinceNews_CAD=0;
double SecondsToNews_CAD=0;
double ImpactSinceNews_CAD=0;
double ImpactToNews_CAD=0;
double SecondsSinceNews_CNY=0;
double SecondsToNews_CNY=0;
double ImpactSinceNews_CNY=0;
double ImpactToNews_CNY=0;
string ShowImpact[Currency];
string ShowSecondsUntil[Currency];
string ShowSecondsSince[Currency];
//---------------------------------------------------------------------
int ExtMapBuffer0[Currency][PairsTrade];
double ExtBufferSeconds[Currency][PairsTrade];
double ExtBufferImpact[Currency][5];
string mainData[PairsTrade][7];
bool SessionBeforeEvent[Currency];
string sData;
string sTags[7]= {"<title>", "<country>", "<date><![CDATA[", "<time><![CDATA[", "<impact><![CDATA[", "<forecast><![CDATA[", "<previous><![CDATA["};
string eTags[7]= {"</title>", "</country>", "]]></date>", "]]></time>", "]]></impact>", "]]></forecast>", "]]></previous>"};
int xmlHandle;
int LogHandle=-1;
int BoEvent;
int EndWeek;
int BeginWeek;
datetime minsTillNews=0;
datetime tmpMins;
static bool NeedToGetFile=false;
static int PrevMinute=-1;
string xmlFileName;
datetime CurrentTime=0;
datetime ChcekLockedDay=0;
bool FileIsOk=false;
bool StartOperations=false;
bool CallMain;
//---------------------------------------------------------------------
int hSession_IEType;
int hSession_Direct;
int Internet_Open_Type_Preconfig=0;
int Internet_Open_Type_Direct=1;
int Internet_Open_Type_Proxy=3;
int Buffer_LEN=80;
int CountTicks=0;
//---------------------------------------------------------------------
double SpreadPips;
double PriceAsk;
double PriceBid;
int SetBuffers=0;
int DistText;
int DistanceText[NoOfImages];
int TextFontSize=Currency;
int TextFontSizeTitle=12;
string TextFontType="Arial";
string TextFontTypeTitle="Arial Black";
//---------------------------------------------------------------------
string ButtonOpen_EUR="Open EUR";
string ButtonClose_EUR="Close EUR";
string ButtonOpen_GBP="Open GBP";
string ButtonClose_GBP="Close GBP";
string ButtonOpen_AUD="Open AUD";
string ButtonClose_AUD="Close AUD";
string ButtonOpen_NZD="Open NZD";
string ButtonClose_NZD="Close NZD";
string ButtonOpen_USD="Open USD";
string ButtonClose_USD="Close USD";
string ButtonOpen_CAD="Open CAD";
string ButtonClose_CAD="Close CAD";
string ButtonOpen_CHF="Open CHF";
string ButtonClose_CHF="Close CHF";
string ButtonOpen_JPY="Open JPY";
string ButtonClose_JPY="Close JPY";
string ButtonOpen_CNY="Open CNY";
string ButtonClose_CNY="Close CNY";
string ButtonDelete_EUR="Delete EUR";
string ButtonDelete_GBP="Delete GBP";
string ButtonDelete_AUD="Delete AUD";
string ButtonDelete_NZD="Delete NZD";
string ButtonDelete_USD="Delete USD";
string ButtonDelete_CAD="Delete CAD";
string ButtonDelete_CHF="Delete CHF";
string ButtonDelete_JPY="Delete JPY";
string ButtonDelete_CNY="Delete CNY";
//---------------------------------------------------------------------
bool Open_EUR=false;
bool Open_GBP=false;
bool Open_AUD=false;
bool Open_NZD=false;
bool Open_USD=false;
bool Open_CAD=false;
bool Open_CHF=false;
bool Open_JPY=false;
bool Open_CNY=false;
bool Close_EUR=false;
bool Close_GBP=false;
bool Close_AUD=false;
bool Close_NZD=false;
bool Close_USD=false;
bool Close_CAD=false;
bool Close_CHF=false;
bool Close_JPY=false;
bool Close_CNY=false;
bool Delete_EUR=false;
bool Delete_GBP=false;
bool Delete_AUD=false;
bool Delete_NZD=false;
bool Delete_USD=false;
bool Delete_CAD=false;
bool Delete_CHF=false;
bool Delete_JPY=false;
bool Delete_CNY=false;
/*


         imports start


*/

#include <MT4Bridge/MT4MarketInfo.mqh>
#include <MT4Bridge/MT4Account.mqh>
#include <MT4Bridge/MT4Orders.mqh>
#include <mt4objects_1.mqh>
#define HistoryTotal OrdersHistoryTotal
#include <errordescription.mqh>



input bool   use_title  = true;   // Filter News based on title
bool TitleSelected(string title)
  {
   if(!use_title)
     {
      return true;
     }
   else
     {
      string titles = title_phrase;
      string keywords[];
      if(StringGetCharacter(titles, 0) == 44)
         titles = StringSubstr(titles,1,StringLen(titles)-1);

      if(StringGetCharacter(titles, StringLen(titles)-1) == 44)
         titles = StringSubstr(titles,0,StringLen(titles)-2);

      if(StringFind(titles,",")!=-1)
        {
         string sep=",";
         ushort u_sep;
         u_sep=StringGetCharacter(sep,0);
         int k=StringSplit(titles,u_sep,keywords);

         ArrayResize(keywords,k,k);

         if(k>0)
           {
            for(int i=0;i<k;i++)
              {
               if(StringFind(title,keywords[i]) != -1)
                  return true;
              }
           }

        }
     }
   return false;
  }
//====================================================================================================================================================//
//OnInit function
//====================================================================================================================================================//
int OnInit()
{
//---------------------------------------------------------------------
//Reset value
   LoopTimes=0;
   CallMain=false;
//---------------------------------------------------------------------
//Set timer
   EventSetMillisecondTimer(_MillisecondTimer);
//---------------------------------------------------------------------
//Text in screen
   DistText=TextFontSize*2;
   for(I_INDEXER=1; I_INDEXER<TotalImages; I_INDEXER++) {
      DistanceText[I_INDEXER]=DistText*I_INDEXER;
   }
//---------------------------------------------------------------------
//Set chart
   if(SetChartInterface==true) {
      ChartSetInteger(0,CHART_SHOW_GRID,false);//Hide grid
      ChartSetInteger(0,CHART_MODE,0);//Set price in bars
      ChartSetInteger(0,CHART_SCALE,1);//Set scale
      ChartSetInteger(0,CHART_SHOW_VOLUMES,CHART_VOLUME_HIDE);//Hide value
      ChartSetInteger(0,CHART_COLOR_CHART_UP,clrNONE);//Hide line up
      ChartSetInteger(0,CHART_COLOR_CHART_DOWN,clrNONE);//Hide line down
      ChartSetInteger(0,CHART_COLOR_CHART_LINE,clrNONE);//Hide chart line
   }
//---------------------------------------------------------------------
//Set strategy trade
   /*

      STRATEGIES REMOVED , INSERTED IN STRAT VERSION

   */
   if(StrategyToUse==Recovery_Orders_Strategy) { //Recovery_Orders_Strategy
      _UseModifyPending=false;
      _ModifyAfterEvent=false;
      _DeleteOrphanPending=true;
      _DeleteOrdersAfterEvent=true;
      _MinutesExpireOrders=0;
      _UseTralingStopLoss=false;
      _UseStopLoss=true;
      _UseTakeProfit=true;
      _CloseAllOrdersAsOne=false;
      _WaitToTriggeredAllOrders=false;
      _CloseOrdersAfterEvent=false;
      _UseReplaceMode=false;
      _RunReplaceAfterNewsEnd=false;
      _UseRecoveryMode=true;
      _RunRecoveryAfterNewsEnd=true;
   }
   if(StrategyToUse==Basket_Orders_Strategy) { //Basket_Orders_Strategy,
      _UseModifyPending=false;
      _ModifyAfterEvent=false;
      _DeleteOrphanPending=true;
      _DeleteOrdersAfterEvent=true;
      _MinutesExpireOrders=0;
      _UseTralingStopLoss=false;
      _UseStopLoss=false;
      _UseTakeProfit=false;
      _CloseAllOrdersAsOne=true;
      _WaitToTriggeredAllOrders=true;
      _CloseOrdersAfterEvent=false;
      _UseReplaceMode=false;
      _RunReplaceAfterNewsEnd=false;
      _UseRecoveryMode=false;
      _RunRecoveryAfterNewsEnd=false;
   }
   if(StrategyToUse==Separate_Orders_Strategy) { //Separate_Orders_Strategy,
      _UseModifyPending=false;
      _ModifyAfterEvent=false;
      _DeleteOrphanPending=false;
      _DeleteOrdersAfterEvent=true;
      _MinutesExpireOrders=0;
      _UseTralingStopLoss=false;
      _UseStopLoss=true;
      _UseTakeProfit=true;
      _CloseAllOrdersAsOne=false;
      _WaitToTriggeredAllOrders=false;
      _CloseOrdersAfterEvent=false;
      _UseReplaceMode=false;
      _RunReplaceAfterNewsEnd=false;
      _UseRecoveryMode=false;
      _RunRecoveryAfterNewsEnd=false;
   }
   if(StrategyToUse==Replace_Orders_Strategy) { //Replace_Orders_Strategy
      _UseModifyPending=true;
      _ModifyAfterEvent=false;
      _DeleteOrphanPending=false;
      _DeleteOrdersAfterEvent=true;
      _MinutesExpireOrders=0;
      _UseTralingStopLoss=false;
      _UseStopLoss=true;
      _UseTakeProfit=true;
      _CloseAllOrdersAsOne=false;
      _WaitToTriggeredAllOrders=false;
      _CloseOrdersAfterEvent=false;
      _UseReplaceMode=true;
      _DeleteOrphanIfGetProfit=true;
      _RunReplaceAfterNewsEnd=false;
      _UseRecoveryMode=false;
      _RunRecoveryAfterNewsEnd=false;
   }
//---------------------------------------------------------------------
//Confirm sets
   if(UseBreakEven==true) {
      _UseTralingStopLoss=true;
      _UseStopLoss=true;
      _OrdersStopLoss=BreakEvenPips;
   }
//---
   if(_MillisecondTimer<1)
      _MillisecondTimer=1;
   if(_MillisecondTimer>100000)
      _MillisecondTimer=100000;
//---------------------------------------------------------------------
//Started information
//if(OrdersComments=="")
//   ExpertName=WindowExpertName();
//else
   ExpertName=OrdersComments;
   ArrayInitialize(AvailablePair,false);
   ArrayInitialize(OpenSession,true);
   iPrevMinute=-1;
   xmlFileName=IntegerToString(Month())+"-"+IntegerToString(Day())+"-"+IntegerToString(Year())+"-"+MQLInfoString(MQL_PROGRAM_NAME)+".xml";
//---------------------------------------------------------------------
//Suffix
   if(StringLen(Symbol())>6)
      PairSuffix=StringSubstr(Symbol(),6);
//---------------------------------------------------------------------
//Set time before/after in seconds
   if(_MinutesBeforeNewsStart<0)
      _MinutesBeforeNewsStart=0;
   if(_MinutesAfterNewsStop<0)
      _MinutesAfterNewsStop=0;
   SecondsBeforeNewsStart=_MinutesBeforeNewsStart*60;
   SecondsAfterNewsStop=_MinutesAfterNewsStop*60;
//---------------------------------------------------------------------
//Set pairs
   Pair[1]=PairPrefix+"EURGBP"+PairSuffix;
   Pair[2]=PairPrefix+"EURAUD"+PairSuffix;
   Pair[3]=PairPrefix+"EURNZD"+PairSuffix;
   Pair[4]=PairPrefix+"EURUSD"+PairSuffix;
   Pair[5]=PairPrefix+"EURCAD"+PairSuffix;
   Pair[6]=PairPrefix+"EURCHF"+PairSuffix;
   Pair[7]=PairPrefix+"EURJPY"+PairSuffix;
//---
   Pair[8]=PairPrefix+"EURGBP"+PairSuffix;
   Pair[9]=PairPrefix+"GBPAUD"+PairSuffix;
   Pair[10]=PairPrefix+"GBPNZD"+PairSuffix;
   Pair[11]=PairPrefix+"GBPUSD"+PairSuffix;
   Pair[12]=PairPrefix+"GBPCAD"+PairSuffix;
   Pair[13]=PairPrefix+"GBPCHF"+PairSuffix;
   Pair[14]=PairPrefix+"GBPJPY"+PairSuffix;
//---
   Pair[15]=PairPrefix+"EURAUD"+PairSuffix;
   Pair[16]=PairPrefix+"GBPAUD"+PairSuffix;
   Pair[17]=PairPrefix+"AUDNZD"+PairSuffix;
   Pair[18]=PairPrefix+"AUDUSD"+PairSuffix;
   Pair[19]=PairPrefix+"AUDCAD"+PairSuffix;
   Pair[20]=PairPrefix+"AUDCHF"+PairSuffix;
   Pair[21]=PairPrefix+"AUDJPY"+PairSuffix;
//---
   Pair[22]=PairPrefix+"EURNZD"+PairSuffix;
   Pair[23]=PairPrefix+"GBPNZD"+PairSuffix;
   Pair[24]=PairPrefix+"AUDNZD"+PairSuffix;
   Pair[25]=PairPrefix+"NZDUSD"+PairSuffix;
   Pair[26]=PairPrefix+"NZDCAD"+PairSuffix;
   Pair[27]=PairPrefix+"NZDCHF"+PairSuffix;
   Pair[28]=PairPrefix+"NZDJPY"+PairSuffix;
//---
   Pair[29]=PairPrefix+"EURUSD"+PairSuffix;
   Pair[30]=PairPrefix+"GBPUSD"+PairSuffix;
   Pair[31]=PairPrefix+"AUDUSD"+PairSuffix;
   Pair[32]=PairPrefix+"NZDUSD"+PairSuffix;
   Pair[33]=PairPrefix+"USDCAD"+PairSuffix;
   Pair[34]=PairPrefix+"USDCHF"+PairSuffix;
   Pair[35]=PairPrefix+"USDJPY"+PairSuffix;
//---
   Pair[36]=PairPrefix+"EURCAD"+PairSuffix;
   Pair[37]=PairPrefix+"GBPCAD"+PairSuffix;
   Pair[38]=PairPrefix+"AUDCAD"+PairSuffix;
   Pair[39]=PairPrefix+"NZDCAD"+PairSuffix;
   Pair[40]=PairPrefix+"USDCAD"+PairSuffix;
   Pair[41]=PairPrefix+"CADCHF"+PairSuffix;
   Pair[42]=PairPrefix+"CADJPY"+PairSuffix;
//---
   Pair[43]=PairPrefix+"EURCHF"+PairSuffix;
   Pair[44]=PairPrefix+"GBPCHF"+PairSuffix;
   Pair[45]=PairPrefix+"AUDCHF"+PairSuffix;
   Pair[46]=PairPrefix+"NZDCHF"+PairSuffix;
   Pair[47]=PairPrefix+"USDCHF"+PairSuffix;
   Pair[48]=PairPrefix+"CADCHF"+PairSuffix;
   Pair[49]=PairPrefix+"CHFJPY"+PairSuffix;
//---
   Pair[50]=PairPrefix+"EURJPY"+PairSuffix;
   Pair[51]=PairPrefix+"GBPJPY"+PairSuffix;
   Pair[52]=PairPrefix+"AUDJPY"+PairSuffix;
   Pair[53]=PairPrefix+"NZDJPY"+PairSuffix;
   Pair[54]=PairPrefix+"USDJPY"+PairSuffix;
   Pair[55]=PairPrefix+"CADJPY"+PairSuffix;
   Pair[56]=PairPrefix+"CHFJPY"+PairSuffix;
//---
   Pair[57]=PairPrefix+"EUR"+BrokerSymbolFor_CNY+PairSuffix;
   Pair[58]=PairPrefix+"USD"+BrokerSymbolFor_CNY+PairSuffix;
   Pair[59]=PairPrefix+"JPY"+BrokerSymbolFor_CNY+PairSuffix;
//---------------------------------------------------------------------
//Expert ID
   if(MagicNumber<0)
      MagicNumber*=(-1);
   OrdersID=MagicNumber;
//---Set ID base impact news set
   if(MagicNumber==0) {
      OrdersID=0;
      if(ImpactToTrade==0)
         OrdersID+=101010;
      if(ImpactToTrade==1)
         OrdersID+=202020;
      if(ImpactToTrade==2)
         OrdersID+=303030;
   }
//--Set ID per symbol and check available pairs
   for(I_INDEXER=0; I_INDEXER<TotalPairs; I_INDEXER++) {
      PairID[I_INDEXER]=OrdersID+I_INDEXER;
      if(SymbolInfoDouble(Pair[I_INDEXER],SYMBOL_BID)!=0)
         AvailablePair[I_INDEXER]=true;
   }
//---------------------------------------------------------------------
//Not_Trade,//0
//Trade_In_News,//1
//Trade_From_Panel//2
//Set trade pairs
   if((EUR_Trade_EURGBP==false) && (EUR_Trade_EURAUD==false) && (EUR_Trade_EURNZD==false) &&
         (EUR_Trade_EURUSD==false) && (EUR_Trade_EURCAD==false) && (EUR_Trade_EURCHF==false) && (EUR_Trade_EURJPY==false))
      _EUR_TradeInNewsRelease=0;
//---
   if((GBP_TradeIn_EURGBP==false) && (GBP_TradeIn_GBPAUD==false) && (GBP_TradeIn_GBPNZD==false) &&
         (GBP_TradeIn_GBPUSD==false) && (GBP_TradeIn_GBPCAD==false) && (GBP_TradeIn_GBPCHF==false) && (GBP_TradeIn_GBPJPY==false))
      _GBP_TradeInNewsRelease=0;
//---
   if((AUD_TradeIn_EURAUD==false) && (AUD_TradeIn_GBPAUD==false) && (AUD_TradeIn_AUDNZD==false) &&
         (AUD_TradeIn_AUDUSD==false) && (AUD_TradeIn_AUDCAD==false) && (AUD_TradeIn_AUDCHF==false) && (AUD_TradeIn_AUDJPY==false))
      _AUD_TradeInNewsRelease=0;
//---
   if((NZD_TradeIn_EURNZD==false) && (NZD_TradeIn_GBPNZD==false) && (NZD_TradeIn_AUDNZD==false) &&
         (NZD_TradeIn_NZDUSD==false) && (NZD_TradeIn_NZDCAD==false) && (NZD_TradeIn_NZDCHF==false) && (NZD_TradeIn_NZDJPY==false))
      _NZD_TradeInNewsRelease=0;
//---
   if((USD_TradeIn_EURUSD==false) && (USD_TradeIn_GBPUSD==false) && (USD_TradeIn_AUDUSD==false) &&
         (USD_TradeIn_NZDUSD==false) && (USD_TradeIn_USDCAD==false) && (USD_TradeIn_USDCHF==false) && (USD_TradeIn_USDJPY==false))
      _USD_TradeInNewsRelease=0;
//---
   if((CAD_TradeIn_EURCAD==false) && (CAD_TradeIn_GBPCAD==false) && (CAD_TradeIn_AUDCAD==false) &&
         (CAD_TradeIn_NZDCAD==false) && (CAD_TradeIn_USDCAD==false) && (CAD_TradeIn_CADCHF==false) && (CAD_TradeIn_CADJPY==false))
      _CAD_TradeInNewsRelease=0;
//---
   if((CHF_TradeIn_EURCHF==false) && (CHF_TradeIn_GBPCHF==false) && (CHF_TradeIn_AUDCHF==false) &&
         (CHF_TradeIn_NZDCHF==false) && (CHF_TradeIn_USDCHF==false) && (CHF_TradeIn_CADCHF==false) && (CHF_TradeIn_CHFJPY==false))
      _CHF_TradeInNewsRelease=0;
//---
   if((JPY_TradeIn_EURJPY==false) && (JPY_TradeIn_GBPJPY==false) && (JPY_TradeIn_AUDJPY==false) &&
         (JPY_TradeIn_NZDJPY==false) && (JPY_TradeIn_USDJPY==false) && (JPY_TradeIn_CADJPY==false) && (JPY_TradeIn_CHFJPY==false))
      _JPY_TradeInNewsRelease=0;
//---
   if((CNY_TradeIn_EURCNY==false) && (CNY_TradeIn_USDCNY==false) && (CNY_TradeIn_JPYCNY==false))
      _CNY_TradeInNewsRelease=0;
//---------------------------------------------------------------------
//Broker 4 or 5 digits
   MultiplierPoint=1;
   if(SymbolInfoInteger(Symbol(), SYMBOL_DIGITS)==3||SymbolInfoInteger(Symbol(), SYMBOL_DIGITS)==5)
      MultiplierPoint=10;
   if(SymbolInfoInteger(Symbol(), SYMBOL_DIGITS)==2)
      MultiplierPoint=100;
//---------------------------------------------------------------------
//Background
   if(ObjectFind("Background")==-1)
      ChartBackground("Background",clrBlack,0,15,260,363);
//---------------------------------------------------------------------
   if(!IsTesting())
      OnTick();//For show comment if market is closed
//---------------------------------------------------------------------
   return(INIT_SUCCEEDED);
//---------------------------------------------------------------------
}
//====================================================================================================================================================//
//OnDeinit function
//====================================================================================================================================================//
void OnDeinit(const int reason)
{
//---------------------------------------------------------------------
//Delete pending order if unload expert
   if(DeletePendingInExit) {
      bool DeleteOrderID=false;
      for(int iPos=OrdersTotal()-1; iPos>=0; iPos--) {
         if(OrderSelect(iPos,SELECT_BY_POS,MODE_TRADES)) {
            for(int iID=0; iID<TotalPairs; iID++) {
               if((OrderMagicNumber()==PairID[iID]) && ((OrderType()==OP_BUYSTOP) || (OrderType()==OP_SELLSTOP)))
                  DeleteOrderID=OrderDelete(OrderTicket());
            }
         }
      }
   }
//---------------------------------------------------------------------
//Delete file of folder if unload expert
   xmlHandle=FileOpen(xmlFileName,FILE_BIN|FILE_READ|FILE_WRITE);
   if(xmlHandle>=0) {
      FileClose(xmlHandle);
      FileDelete(xmlFileName);
   }
//---------------------------------------------------------------------
//Delete objects of screen if unload expert
   if(ObjectFind("Background")>-1)
      ObjectDelete("Background");
//---
   for(I_INDEXER=0; I_INDEXER<TotalImages; I_INDEXER++) {
      if(ObjectFind("Text"+IntegerToString(I_INDEXER))>-1)
         ObjectDelete("Text"+IntegerToString(I_INDEXER));
      if(ObjectFind("BackgroundLine1"+IntegerToString(I_INDEXER))>-1)
         ObjectDelete("BackgroundLine1"+IntegerToString(I_INDEXER));
      if(ObjectFind("BackgroundLine2"+IntegerToString(I_INDEXER))>-1)
         ObjectDelete("BackgroundLine2"+IntegerToString(I_INDEXER));
      if(ObjectFind("Comm1"+IntegerToString(I_INDEXER))>-1)
         ObjectDelete("Comm1"+IntegerToString(I_INDEXER));
      if(ObjectFind("Comm2"+IntegerToString(I_INDEXER))>-1)
         ObjectDelete("Comm2"+IntegerToString(I_INDEXER));
      if(ObjectFind("Comm3"+IntegerToString(I_INDEXER))>-1)
         ObjectDelete("Comm3"+IntegerToString(I_INDEXER));
      if(ObjectFind("Comm4"+IntegerToString(I_INDEXER))>-1)
         ObjectDelete("Comm4"+IntegerToString(I_INDEXER));
      if(ObjectFind("Comm5"+IntegerToString(I_INDEXER))>-1)
         ObjectDelete("Comm5"+IntegerToString(I_INDEXER));
      if(ObjectFind("Str"+IntegerToString(I_INDEXER))>-1)
         ObjectDelete("Str"+IntegerToString(I_INDEXER));
      if(ObjectFind("Res"+IntegerToString(I_INDEXER))>-1)
         ObjectDelete("Res"+IntegerToString(I_INDEXER));
   }
//---------------------------------------------------------------------
//Delete buttons
   if(ObjectFind(ButtonOpen_EUR)>-1)
      ObjectDelete(ButtonOpen_EUR);
   if(ObjectFind(ButtonClose_EUR)>-1)
      ObjectDelete(ButtonClose_EUR);
   if(ObjectFind(ButtonOpen_GBP)>-1)
      ObjectDelete(ButtonOpen_GBP);
   if(ObjectFind(ButtonClose_GBP)>-1)
      ObjectDelete(ButtonClose_GBP);
   if(ObjectFind(ButtonOpen_AUD)>-1)
      ObjectDelete(ButtonOpen_AUD);
   if(ObjectFind(ButtonClose_AUD)>-1)
      ObjectDelete(ButtonClose_AUD);
   if(ObjectFind(ButtonOpen_NZD)>-1)
      ObjectDelete(ButtonOpen_NZD);
   if(ObjectFind(ButtonClose_NZD)>-1)
      ObjectDelete(ButtonClose_NZD);
   if(ObjectFind(ButtonOpen_USD)>-1)
      ObjectDelete(ButtonOpen_USD);
   if(ObjectFind(ButtonClose_USD)>-1)
      ObjectDelete(ButtonClose_USD);
   if(ObjectFind(ButtonOpen_CAD)>-1)
      ObjectDelete(ButtonOpen_CAD);
   if(ObjectFind(ButtonClose_CAD)>-1)
      ObjectDelete(ButtonClose_CAD);
   if(ObjectFind(ButtonOpen_CHF)>-1)
      ObjectDelete(ButtonOpen_CHF);
   if(ObjectFind(ButtonClose_CHF)>-1)
      ObjectDelete(ButtonClose_CHF);
   if(ObjectFind(ButtonOpen_JPY)>-1)
      ObjectDelete(ButtonOpen_JPY);
   if(ObjectFind(ButtonClose_JPY)>-1)
      ObjectDelete(ButtonClose_JPY);
   if(ObjectFind(ButtonOpen_CNY)>-1)
      ObjectDelete(ButtonOpen_CNY);
   if(ObjectFind(ButtonClose_CNY)>-1)
      ObjectDelete(ButtonClose_CNY);
   if(ObjectFind(ButtonDelete_EUR)>-1)
      ObjectDelete(ButtonDelete_EUR);
   if(ObjectFind(ButtonDelete_GBP)>-1)
      ObjectDelete(ButtonDelete_GBP);
   if(ObjectFind(ButtonDelete_AUD)>-1)
      ObjectDelete(ButtonDelete_AUD);
   if(ObjectFind(ButtonDelete_NZD)>-1)
      ObjectDelete(ButtonDelete_NZD);
   if(ObjectFind(ButtonDelete_USD)>-1)
      ObjectDelete(ButtonDelete_USD);
   if(ObjectFind(ButtonDelete_CAD)>-1)
      ObjectDelete(ButtonDelete_CAD);
   if(ObjectFind(ButtonDelete_CHF)>-1)
      ObjectDelete(ButtonDelete_CHF);
   if(ObjectFind(ButtonDelete_JPY)>-1)
      ObjectDelete(ButtonDelete_JPY);
   if(ObjectFind(ButtonDelete_CNY)>-1)
      ObjectDelete(ButtonDelete_CNY);
//---------------------------------------------------------------------
//Destroy timer
   EventKillTimer();
//---------------------------------------------------------------------
//Delete comments of screen if unload expert
   Comment("");
//---------------------------------------------------------------------
}
//====================================================================================================================================================//
//OnChartEvent function
//====================================================================================================================================================//
void OnChartEvent(const int id,const long &lparam,const double &dparam,const string &sparam)
{
//---------------------------------------------------------------------
//Set and reset values
   int DistanceButtons;
   int SetPosition=0;
   if(RunAnalyzerTrades==false)
      SetPosition=330;
//---------------------------------------------------------------------
// enum TradeWay {   {reference}
//       Not_Trade,
//       Trade_In_News,
//       Trade_From_Panel};
//Make buttons
   if(_EUR_TradeInNewsRelease==Trade_From_Panel) {
      DistanceButtons=16;
      if(ObjectFind(ButtonOpen_EUR)==-1)
         ButtonsPanel(ButtonOpen_EUR,"Open on EUR",600-SetPosition,DistanceButtons,ColorOpenButton);
      if(ObjectFind(ButtonClose_EUR)==-1)
         ButtonsPanel(ButtonClose_EUR,"Close on EUR",705-SetPosition,DistanceButtons,ColorCloseButton);
      if(ObjectFind(ButtonDelete_EUR)==-1)
         ButtonsPanel(ButtonDelete_EUR,"Delete on EUR",810-SetPosition,DistanceButtons,ColorDeleteButton);
   }
//---
   if(_GBP_TradeInNewsRelease==Trade_From_Panel) {
      DistanceButtons=16+((MathMax(_EUR_TradeInNewsRelease-1,0))*30);
      if(ObjectFind(ButtonOpen_GBP)==-1)
         ButtonsPanel(ButtonOpen_GBP,"Open on GBP",600-SetPosition,DistanceButtons,ColorOpenButton);
      if(ObjectFind(ButtonClose_GBP)==-1)
         ButtonsPanel(ButtonClose_GBP,"Close on GBP",705-SetPosition,DistanceButtons,ColorCloseButton);
      if(ObjectFind(ButtonDelete_GBP)==-1)
         ButtonsPanel(ButtonDelete_GBP,"Delete on GBP",810-SetPosition,DistanceButtons,ColorDeleteButton);
   }
//---
   if(_AUD_TradeInNewsRelease==Trade_From_Panel) {
      DistanceButtons=16+((MathMax(_EUR_TradeInNewsRelease-1,0))*30)+((MathMax(_GBP_TradeInNewsRelease-1,0))*30);
      if(ObjectFind(ButtonOpen_AUD)==-1)
         ButtonsPanel(ButtonOpen_AUD,"Open on AUD",600-SetPosition,DistanceButtons,ColorOpenButton);
      if(ObjectFind(ButtonClose_AUD)==-1)
         ButtonsPanel(ButtonClose_AUD,"Close on AUD",705-SetPosition,DistanceButtons,ColorCloseButton);
      if(ObjectFind(ButtonDelete_AUD)==-1)
         ButtonsPanel(ButtonDelete_AUD,"Delete on AUD",810-SetPosition,DistanceButtons,ColorDeleteButton);
   }
//---
   if(_NZD_TradeInNewsRelease==Trade_From_Panel) {
      DistanceButtons=16+((MathMax(_EUR_TradeInNewsRelease-1,0))*30)+((MathMax(_GBP_TradeInNewsRelease-1,0))*30)+((MathMax(_AUD_TradeInNewsRelease-1,0))*30);
      if(ObjectFind(ButtonOpen_NZD)==-1)
         ButtonsPanel(ButtonOpen_NZD,"Open on NZD",600-SetPosition,DistanceButtons,ColorOpenButton);
      if(ObjectFind(ButtonClose_NZD)==-1)
         ButtonsPanel(ButtonClose_NZD,"Close on NZD",705-SetPosition,DistanceButtons,ColorCloseButton);
      if(ObjectFind(ButtonDelete_NZD)==-1)
         ButtonsPanel(ButtonDelete_NZD,"Delete on NZD",810-SetPosition,DistanceButtons,ColorDeleteButton);
   }
//---
   if(_USD_TradeInNewsRelease==Trade_From_Panel) {
      DistanceButtons=16+((MathMax(_EUR_TradeInNewsRelease-1,0))*30)+((MathMax(_GBP_TradeInNewsRelease-1,0))*30)+((MathMax(_AUD_TradeInNewsRelease-1,0))*30)+((MathMax(_NZD_TradeInNewsRelease-1,0))*30);
      if(ObjectFind(ButtonOpen_USD)==-1)
         ButtonsPanel(ButtonOpen_USD,"Open on USD",600-SetPosition,DistanceButtons,ColorOpenButton);
      if(ObjectFind(ButtonClose_USD)==-1)
         ButtonsPanel(ButtonClose_USD,"Close on USD",705-SetPosition,DistanceButtons,ColorCloseButton);
      if(ObjectFind(ButtonDelete_USD)==-1)
         ButtonsPanel(ButtonDelete_USD,"Delete on USD",810-SetPosition,DistanceButtons,ColorDeleteButton);
   }
//---
   if(_CAD_TradeInNewsRelease==Trade_From_Panel) {
      DistanceButtons=16+((MathMax(_EUR_TradeInNewsRelease-1,0))*30)+((MathMax(_GBP_TradeInNewsRelease-1,0))*30)+((MathMax(_AUD_TradeInNewsRelease-1,0))*30)+((MathMax(_NZD_TradeInNewsRelease-1,0))*30)+((MathMax(_USD_TradeInNewsRelease-1,0))*30);
      if(ObjectFind(ButtonOpen_CAD)==-1)
         ButtonsPanel(ButtonOpen_CAD,"Open on CAD",600-SetPosition,DistanceButtons,ColorOpenButton);
      if(ObjectFind(ButtonClose_CAD)==-1)
         ButtonsPanel(ButtonClose_CAD,"Close on CAD",705-SetPosition,DistanceButtons,ColorCloseButton);
      if(ObjectFind(ButtonDelete_CAD)==-1)
         ButtonsPanel(ButtonDelete_CAD,"Delete on CAD",810-SetPosition,DistanceButtons,ColorDeleteButton);
   }
//---
   if(_CHF_TradeInNewsRelease==Trade_From_Panel) {
      DistanceButtons=16+((MathMax(_EUR_TradeInNewsRelease-1,0))*30)+((MathMax(_GBP_TradeInNewsRelease-1,0))*30)+((MathMax(_AUD_TradeInNewsRelease-1,0))*30)+((MathMax(_NZD_TradeInNewsRelease-1,0))*30)+((MathMax(_USD_TradeInNewsRelease-1,0))*30)+((MathMax(_CAD_TradeInNewsRelease-1,0))*30);
      if(ObjectFind(ButtonOpen_CHF)==-1)
         ButtonsPanel(ButtonOpen_CHF,"Open on CHF",600-SetPosition,DistanceButtons,ColorOpenButton);
      if(ObjectFind(ButtonClose_CHF)==-1)
         ButtonsPanel(ButtonClose_CHF,"Close on CHF",705-SetPosition,DistanceButtons,ColorCloseButton);
      if(ObjectFind(ButtonDelete_CHF)==-1)
         ButtonsPanel(ButtonDelete_CHF,"Delete on CHF",810-SetPosition,DistanceButtons,ColorDeleteButton);
   }
//---
   if(_JPY_TradeInNewsRelease==Trade_From_Panel) {
      DistanceButtons=16+((MathMax(_EUR_TradeInNewsRelease-1,0))*30)+((MathMax(_GBP_TradeInNewsRelease-1,0))*30)+((MathMax(_AUD_TradeInNewsRelease-1,0))*30)+((MathMax(_NZD_TradeInNewsRelease-1,0))*30)+((MathMax(_USD_TradeInNewsRelease-1,0))*30)+((MathMax(_CAD_TradeInNewsRelease-1,0))*30)+((MathMax(_CHF_TradeInNewsRelease-1,0))*30);
      if(ObjectFind(ButtonOpen_JPY)==-1)
         ButtonsPanel(ButtonOpen_JPY,"Open on JPY",600-SetPosition,DistanceButtons,ColorOpenButton);
      if(ObjectFind(ButtonClose_JPY)==-1)
         ButtonsPanel(ButtonClose_JPY,"Close on JPY",705-SetPosition,DistanceButtons,ColorCloseButton);
      if(ObjectFind(ButtonDelete_JPY)==-1)
         ButtonsPanel(ButtonDelete_JPY,"Delete on JPY",810-SetPosition,DistanceButtons,ColorDeleteButton);
   }
//---
   if(_CNY_TradeInNewsRelease==Trade_From_Panel) {
      DistanceButtons=16+((MathMax(_EUR_TradeInNewsRelease-1,0))*30)+((MathMax(_GBP_TradeInNewsRelease-1,0))*30)+((MathMax(_AUD_TradeInNewsRelease-1,0))*30)+((MathMax(_NZD_TradeInNewsRelease-1,0))*30)+((MathMax(_USD_TradeInNewsRelease-1,0))*30)+((MathMax(_CAD_TradeInNewsRelease-1,0))*30)+((MathMax(_CHF_TradeInNewsRelease-1,0))*30)+((MathMax(_JPY_TradeInNewsRelease-1,0))*30);
      if(ObjectFind(ButtonOpen_CNY)==-1)
         ButtonsPanel(ButtonOpen_CNY,"Open on CNY",600-SetPosition,DistanceButtons,ColorOpenButton);
      if(ObjectFind(ButtonClose_CNY)==-1)
         ButtonsPanel(ButtonClose_CNY,"Close on CNY",705-SetPosition,DistanceButtons,ColorCloseButton);
      if(ObjectFind(ButtonDelete_CNY)==-1)
         ButtonsPanel(ButtonDelete_CNY,"Delete on CNY",810-SetPosition,DistanceButtons,ColorDeleteButton);
   }
//---------------------------------------------------------------------
//Clicked buttons
   bool selected=false;
   if(id==CHARTEVENT_OBJECT_CLICK) {
      string clickedChartObject=sparam;
      //---------------------------------------------------------------------
      //Open on EUR
      if(clickedChartObject==ButtonOpen_EUR) {
         selected=ObjectGetInteger(0,ButtonOpen_EUR,OBJPROP_STATE,true);
         if(selected) {
            if(UseConfirmationMessage==true) {
               if(ConfirmOperation("OPEN","EUR")==true)
                  Open_EUR=true;
            }
            else
               Open_EUR=true;
            Sleep(100);
            ObjectSetInteger(0,ButtonOpen_EUR,OBJPROP_STATE,false);
         }
      }
      //---------------------------------------------------------------------
      //Close on EUR
      if(clickedChartObject==ButtonClose_EUR) {
         selected=ObjectGetInteger(0,ButtonClose_EUR,OBJPROP_STATE,true);
         if(selected) {
            if(UseConfirmationMessage==true) {
               if(ConfirmOperation("CLOSE","EUR")==true)
                  Close_EUR=true;
            }
            else
               Close_EUR=true;
            Sleep(100);
            ObjectSetInteger(0,ButtonClose_EUR,OBJPROP_STATE,false);
         }
      }
      //---------------------------------------------------------------------
      //Delete on EUR
      if(clickedChartObject==ButtonDelete_EUR) {
         selected=ObjectGetInteger(0,ButtonDelete_EUR,OBJPROP_STATE,true);
         if(selected) {
            if(UseConfirmationMessage==true) {
               if(ConfirmOperation("DELETE","EUR")==true)
                  Delete_EUR=true;
            }
            else
               Delete_EUR=true;
            Sleep(100);
            ObjectSetInteger(0,ButtonDelete_EUR,OBJPROP_STATE,false);
         }
      }
      //---------------------------------------------------------------------
      //Open on GBP
      if(clickedChartObject==ButtonOpen_GBP) {
         selected=ObjectGetInteger(0,ButtonOpen_GBP,OBJPROP_STATE,true);
         if(selected) {
            if(UseConfirmationMessage==true) {
               if(ConfirmOperation("OPEN","GBP")==true)
                  Open_GBP=true;
            }
            else
               Open_GBP=true;
            Sleep(100);
            ObjectSetInteger(0,ButtonOpen_GBP,OBJPROP_STATE,false);
         }
      }
      //---------------------------------------------------------------------
      //Close on GBP
      if(clickedChartObject==ButtonClose_GBP) {
         selected=ObjectGetInteger(0,ButtonClose_GBP,OBJPROP_STATE,true);
         if(selected) {
            if(UseConfirmationMessage==true) {
               if(ConfirmOperation("CLOSE","GBP")==true)
                  Close_GBP=true;
            }
            else
               Close_GBP=true;
            Sleep(100);
            ObjectSetInteger(0,ButtonClose_GBP,OBJPROP_STATE,false);
         }
      }
      //---------------------------------------------------------------------
      //Delete on GBP
      if(clickedChartObject==ButtonDelete_GBP) {
         selected=ObjectGetInteger(0,ButtonDelete_GBP,OBJPROP_STATE,true);
         if(selected) {
            if(UseConfirmationMessage==true) {
               if(ConfirmOperation("DELETE","GBP")==true)
                  Delete_GBP=true;
            }
            else
               Delete_GBP=true;
            Sleep(100);
            ObjectSetInteger(0,ButtonDelete_GBP,OBJPROP_STATE,false);
         }
      }
      //---------------------------------------------------------------------
      //Open on AUD
      if(clickedChartObject==ButtonOpen_AUD) {
         selected=ObjectGetInteger(0,ButtonOpen_AUD,OBJPROP_STATE,true);
         if(selected) {
            if(UseConfirmationMessage==true) {
               if(ConfirmOperation("OPEN","AUD")==true)
                  Open_AUD=true;
            }
            else
               Open_AUD=true;
            Sleep(100);
            ObjectSetInteger(0,ButtonOpen_AUD,OBJPROP_STATE,false);
         }
      }
      //---------------------------------------------------------------------
      //Close on AUD
      if(clickedChartObject==ButtonClose_AUD) {
         selected=ObjectGetInteger(0,ButtonClose_AUD,OBJPROP_STATE,true);
         if(selected) {
            if(UseConfirmationMessage==true) {
               if(ConfirmOperation("CLOSE","AUD")==true)
                  Close_AUD=true;
            }
            else
               Close_AUD=true;
            Sleep(100);
            ObjectSetInteger(0,ButtonClose_AUD,OBJPROP_STATE,false);
         }
      }
      //---------------------------------------------------------------------
      //Delete on AUD
      if(clickedChartObject==ButtonDelete_AUD) {
         selected=ObjectGetInteger(0,ButtonDelete_AUD,OBJPROP_STATE,true);
         if(selected) {
            if(UseConfirmationMessage==true) {
               if(ConfirmOperation("DELETE","AUD")==true)
                  Delete_AUD=true;
            }
            else
               Delete_AUD=true;
            Sleep(100);
            ObjectSetInteger(0,ButtonDelete_AUD,OBJPROP_STATE,false);
         }
      }
      //---------------------------------------------------------------------
      //Open on NZD
      if(clickedChartObject==ButtonOpen_NZD) {
         selected=ObjectGetInteger(0,ButtonOpen_NZD,OBJPROP_STATE,true);
         if(selected) {
            if(UseConfirmationMessage==true) {
               if(ConfirmOperation("OPEN","NZD")==true)
                  Open_NZD=true;
            }
            else
               Open_NZD=true;
            Sleep(100);
            ObjectSetInteger(0,ButtonOpen_NZD,OBJPROP_STATE,false);
         }
      }
      //---------------------------------------------------------------------
      //Close on NZD
      if(clickedChartObject==ButtonClose_NZD) {
         selected=ObjectGetInteger(0,ButtonClose_NZD,OBJPROP_STATE,true);
         if(selected) {
            if(UseConfirmationMessage==true) {
               if(ConfirmOperation("CLOSE","NZD")==true)
                  Close_NZD=true;
            }
            else
               Close_NZD=true;
            Sleep(100);
            ObjectSetInteger(0,ButtonClose_NZD,OBJPROP_STATE,false);
         }
      }
      //---------------------------------------------------------------------
      //Delete on NZD
      if(clickedChartObject==ButtonDelete_NZD) {
         selected=ObjectGetInteger(0,ButtonDelete_NZD,OBJPROP_STATE,true);
         if(selected) {
            if(UseConfirmationMessage==true) {
               if(ConfirmOperation("DELETE","NZD")==true)
                  Delete_NZD=true;
            }
            else
               Delete_NZD=true;
            Sleep(100);
            ObjectSetInteger(0,ButtonDelete_NZD,OBJPROP_STATE,false);
         }
      }
      //---------------------------------------------------------------------
      //Open on USD
      if(clickedChartObject==ButtonOpen_USD) {
         selected=ObjectGetInteger(0,ButtonOpen_USD,OBJPROP_STATE,true);
         if(selected) {
            if(UseConfirmationMessage==true) {
               if(ConfirmOperation("OPEN","USD")==true)
                  Open_USD=true;
            }
            else
               Open_USD=true;
            Sleep(100);
            ObjectSetInteger(0,ButtonOpen_USD,OBJPROP_STATE,false);
         }
      }
      //---------------------------------------------------------------------
      //Close on USD
      if(clickedChartObject==ButtonClose_USD) {
         selected=ObjectGetInteger(0,ButtonClose_USD,OBJPROP_STATE,true);
         if(selected) {
            if(UseConfirmationMessage==true) {
               if(ConfirmOperation("CLOSE","USD")==true)
                  Close_USD=true;
            }
            else
               Close_USD=true;
            Sleep(100);
            ObjectSetInteger(0,ButtonClose_USD,OBJPROP_STATE,false);
         }
      }
      //---------------------------------------------------------------------
      //Delete on USD
      if(clickedChartObject==ButtonDelete_USD) {
         selected=ObjectGetInteger(0,ButtonDelete_USD,OBJPROP_STATE,true);
         if(selected) {
            if(UseConfirmationMessage==true) {
               if(ConfirmOperation("DELETE","USD")==true)
                  Delete_USD=true;
            }
            else
               Delete_USD=true;
            Sleep(100);
            ObjectSetInteger(0,ButtonDelete_USD,OBJPROP_STATE,false);
         }
      }
      //---------------------------------------------------------------------
      //Open on CAD
      if(clickedChartObject==ButtonOpen_CAD) {
         selected=ObjectGetInteger(0,ButtonOpen_CAD,OBJPROP_STATE,true);
         if(selected) {
            if(UseConfirmationMessage==true) {
               if(ConfirmOperation("OPEN","CAD")==true)
                  Open_CAD=true;
            }
            else
               Open_CAD=true;
            Sleep(100);
            ObjectSetInteger(0,ButtonOpen_CAD,OBJPROP_STATE,false);
         }
      }
      //---------------------------------------------------------------------
      //Close on CAD
      if(clickedChartObject==ButtonClose_CAD) {
         selected=ObjectGetInteger(0,ButtonClose_CAD,OBJPROP_STATE,true);
         if(selected) {
            if(UseConfirmationMessage==true) {
               if(ConfirmOperation("CLOSE","CAD")==true)
                  Close_CAD=true;
            }
            else
               Close_CAD=true;
            Sleep(100);
            ObjectSetInteger(0,ButtonClose_CAD,OBJPROP_STATE,false);
         }
      }
      //---------------------------------------------------------------------
      //Delete on CAD
      if(clickedChartObject==ButtonDelete_CAD) {
         selected=ObjectGetInteger(0,ButtonDelete_CAD,OBJPROP_STATE,true);
         if(selected) {
            if(UseConfirmationMessage==true) {
               if(ConfirmOperation("DELETE","CAD")==true)
                  Delete_CAD=true;
            }
            else
               Delete_CAD=true;
            Sleep(100);
            ObjectSetInteger(0,ButtonDelete_CAD,OBJPROP_STATE,false);
         }
      }
      //---------------------------------------------------------------------
      //Open on CHF
      if(clickedChartObject==ButtonOpen_CHF) {
         selected=ObjectGetInteger(0,ButtonOpen_CHF,OBJPROP_STATE,true);
         if(selected) {
            if(UseConfirmationMessage==true) {
               if(ConfirmOperation("OPEN","CHF")==true)
                  Open_CHF=true;
            }
            else
               Open_CHF=true;
            Sleep(100);
            ObjectSetInteger(0,ButtonOpen_CHF,OBJPROP_STATE,false);
         }
      }
      //---------------------------------------------------------------------
      //Close on CHF
      if(clickedChartObject==ButtonClose_CHF) {
         selected=ObjectGetInteger(0,ButtonClose_CHF,OBJPROP_STATE,true);
         if(selected) {
            if(UseConfirmationMessage==true) {
               if(ConfirmOperation("CLOSE","CHF")==true)
                  Close_CHF=true;
            }
            else
               Close_CHF=true;
            Sleep(100);
            ObjectSetInteger(0,ButtonClose_CHF,OBJPROP_STATE,false);
         }
      }
      //---------------------------------------------------------------------
      //Delete on CHF
      if(clickedChartObject==ButtonDelete_CHF) {
         selected=ObjectGetInteger(0,ButtonDelete_CHF,OBJPROP_STATE,true);
         if(selected) {
            if(UseConfirmationMessage==true) {
               if(ConfirmOperation("DELETE","CHF")==true)
                  Delete_CHF=true;
            }
            else
               Delete_CHF=true;
            Sleep(100);
            ObjectSetInteger(0,ButtonDelete_CHF,OBJPROP_STATE,false);
         }
      }
      //---------------------------------------------------------------------
      //Open on JPY
      if(clickedChartObject==ButtonOpen_JPY) {
         selected=ObjectGetInteger(0,ButtonOpen_JPY,OBJPROP_STATE,true);
         if(selected) {
            if(UseConfirmationMessage==true) {
               if(ConfirmOperation("OPEN","JPY")==true)
                  Open_JPY=true;
            }
            else
               Open_JPY=true;
            Sleep(100);
            ObjectSetInteger(0,ButtonOpen_JPY,OBJPROP_STATE,false);
         }
      }
      //---------------------------------------------------------------------
      //Close on JPY
      if(clickedChartObject==ButtonClose_JPY) {
         selected=ObjectGetInteger(0,ButtonClose_JPY,OBJPROP_STATE,true);
         if(selected) {
            if(UseConfirmationMessage==true) {
               if(ConfirmOperation("CLOSE","JPY")==true)
                  Close_JPY=true;
            }
            else
               Close_JPY=true;
            Sleep(100);
            ObjectSetInteger(0,ButtonClose_JPY,OBJPROP_STATE,false);
         }
      }
      //---------------------------------------------------------------------
      //Delete on JPY
      if(clickedChartObject==ButtonDelete_JPY) {
         selected=ObjectGetInteger(0,ButtonDelete_JPY,OBJPROP_STATE,true);
         if(selected) {
            if(UseConfirmationMessage==true) {
               if(ConfirmOperation("DELETE","JPY")==true)
                  Delete_JPY=true;
            }
            else
               Delete_JPY=true;
            Sleep(100);
            ObjectSetInteger(0,ButtonDelete_JPY,OBJPROP_STATE,false);
         }
      }
      //---------------------------------------------------------------------
      //Open on CNY
      if(clickedChartObject==ButtonOpen_CNY) {
         selected=ObjectGetInteger(0,ButtonOpen_CNY,OBJPROP_STATE,true);
         if(selected) {
            if(UseConfirmationMessage==true) {
               if(ConfirmOperation("OPEN","CNY")==true)
                  Open_CNY=true;
            }
            else
               Open_CNY=true;
            Sleep(100);
            ObjectSetInteger(0,ButtonOpen_CNY,OBJPROP_STATE,false);
         }
      }
      //---------------------------------------------------------------------
      //Close on CNY
      if(clickedChartObject==ButtonClose_CNY) {
         selected=ObjectGetInteger(0,ButtonClose_CNY,OBJPROP_STATE,true);
         if(selected) {
            if(UseConfirmationMessage==true) {
               if(ConfirmOperation("CLOSE","CNY")==true)
                  Close_CNY=true;
            }
            else
               Close_CNY=true;
            Sleep(100);
            ObjectSetInteger(0,ButtonClose_CNY,OBJPROP_STATE,false);
         }
      }
      //---------------------------------------------------------------------
      //Delete on CNY
      if(clickedChartObject==ButtonDelete_CNY) {
         selected=ObjectGetInteger(0,ButtonDelete_CNY,OBJPROP_STATE,true);
         if(selected) {
            if(UseConfirmationMessage==true) {
               if(ConfirmOperation("DELETE","CNY")==true)
                  Delete_CNY=true;
            }
            else
               Delete_CNY=true;
            Sleep(100);
            ObjectSetInteger(0,ButtonDelete_CNY,OBJPROP_STATE,false);
         }
      }
      //---------------------------------------------------------------------
      ChartRedraw();
   }
//---------------------------------------------------------------------
}
//====================================================================================================================================================//
//ConfirmOperation function
//====================================================================================================================================================//
bool ConfirmOperation(string Oper, string Curr)
{
   int SignalsMessageWarning;
//---
   SignalsMessageWarning=MessageBox("Are you sure to "+Oper+" orders on "+Curr+"?\n\nBy clicking YES expert will "+Oper+" the orders. \n\nYOY WANT CONTINUE?","RISK DISCLAIMER - "+MQLInfoString(MQL_PROGRAM_NAME),MB_YESNO|MB_ICONEXCLAMATION);
   if(SignalsMessageWarning==IDNO)
      return(false);
   else
      return(true);
}
//====================================================================================================================================================//
//OnTick function
//====================================================================================================================================================//
void OnTick()
{
   /*//---------------------------------------------------------------------
   //Pass trades to approval on the market
      int OpenedOrders=0;
      int iSendOrder1=0;
      int iSendOrder2=0;
      bool iCloseOrder1=false;
      bool iCloseOrder2=false;
      double Profit1=0;
      double Profit2=0;
      double _OrdersTakeProfit=10;
      double _OrdersStopLoss=10;
      double LotsSize=1.0;
   //---------------------------------------------------------------------
      if((IsTesting())||(IsVisualMode())||(IsOptimization()))
        {
         if(OrdersTotal()>0)
           {
            for(I_INDEXER=OrdersTotal()-1; I_INDEXER>=0; I_INDEXER--)
              {
               if(OrderSelect(I_INDEXER,SELECT_BY_POS)==true)
                 {
                  if(OrderMagicNumber()==123321)
                    {
                     OpenedOrders++;
                     if(OrderType()==OP_BUY)
                       {
                        Profit1=OrderProfit()+OrderCommission()+OrderSwap();
                        if((Profit1>=(OrderLots()*_OrdersTakeProfit)*MarketInfo(Symbol(),MODE_TICKVALUE)*10)||(Profit1<=-((OrderLots()*_OrdersStopLoss)*MarketInfo(Symbol(),MODE_TICKVALUE)*10)))
                          {
                           iCloseOrder1=OrderClose(OrderTicket(),OrderLots(),Bid,3,clrNONE);
                          }
                       }
                     if(OrderType()==OP_SELL)
                       {
                        Profit2=OrderProfit()+OrderCommission()+OrderSwap();
                        if((Profit2>=(OrderLots()*_OrdersTakeProfit)*MarketInfo(Symbol(),MODE_TICKVALUE)*10)||(Profit2<=-((OrderLots()*_OrdersStopLoss)*MarketInfo(Symbol(),MODE_TICKVALUE)*10)))
                          {
                           iCloseOrder2=OrderClose(OrderTicket(),OrderLots(),Ask,3,clrNONE);
                          }
                       }
                    }
                 }
              }
           }
         else
            if(Hour()==12)
              {
               if((OpenedOrders==0)&&(AccountFreeMargin()-((AccountFreeMargin()-AccountFreeMarginCheck(Symbol(),OP_BUY,LotsSize))+(AccountFreeMargin()-AccountFreeMarginCheck(Symbol(),OP_SELL,LotsSize)))>0))
                 {
                  iSendOrder1=OrderSend(Symbol(),OP_BUY,LotsSize,Ask,3,0,0,"",123321,0,clrBlue);
                  iSendOrder2=OrderSend(Symbol(),OP_SELL,LotsSize,Bid,3,0,0,"",123321,0,clrRed);
                 }
              }
         return;
        }*/
//---------------------------------------------------------------------
//Reset value
   CallMain=false;
//---------------------------------------------------------------------
//Warning message
   if(!IsExpertEnabled()) {
      Comment("\n      The trading terminal",
              "\n      of experts do not run",
              "\n\n\n      Turn ON EA Please .......");
      return;
   }
//---
   if((!IsTradeAllowed()) /* || (IsTradeContextBusy())*/) {
      Comment("\n      Trade is disabled",
              "\n      or trade flow is busy.",
              "\n\n\n      Wait Please .......");
      return;
   }
//---------------------------------------------------------------------
//Count 3 ticks before read news and start trade
   if(CountTicks<3)
      CountTicks++;
//---
   if(CountTicks>=3) {
      CallMain=true;
      StartOperations=true;
   }
   else {
      MainFunction();
   }
//---------------------------------------------------------------------
}
//====================================================================================================================================================//
//OnTimer function
//====================================================================================================================================================//
void OnTimer()
{
//---------------------------------------------------------------------
//Call main function
   if(CallMain==true)
      MainFunction();
//---------------------------------------------------------------------
}
//====================================================================================================================================================//
//Main function
//====================================================================================================================================================//
void MainFunction()
{
//---------------------------------------------------------------------
//Reset value
   SetBuffers=0;
//---------------------------------------------------------------------
//Set time with GMT offset
   CurrentTime=TimeCurrent()+(GMT_OffsetHours*3600);
//---------------------------------------------------------------------
//Set expiry time
   if(_MinutesExpireOrders>0)
      Expire=TimeCurrent()+(MathMax((SecondsBeforeNewsStart+SecondsAfterNewsStop)/60,_MinutesExpireOrders)*60);
//---------------------------------------------------------------------
//Check connection
   if(!IsConnected()) {
      Print(ExpertName+" can not receive events, because can not connect to broker server!");
      Sleep(30000);
      return;
   }
//---------------------------------------------------------------------
//Check signals and count orders current and history
   HistoryResults();
   CountOrders();
   GetSignal();
   if(RunAnalyzerTrades)
      AnalyzerTrades();
//---------------------------------------------------------------------
//Reset counters
   for(I_INDEXER=0; I_INDEXER<TotalPairs; I_INDEXER++) {
      if(BuyStopOrders[I_INDEXER]==0)
         CountTickBuyStop[I_INDEXER]=0;
      if(SellStopOrders[I_INDEXER]==0)
         CountTickSellStop[I_INDEXER]=0;
   }
//---------------------------------------------------------------------
//Delete objects
   if(TotalOpenOrders==0) {
      if(DeleteObjectsAfterEvent==true)
         ClearChart();
   }
//---------------------------------------------------------------------
//Start manage orders
   if(StartOperations) {
      if(_EUR_TradeInNewsRelease>0) {
         SetBuffers=1;
         CommentPrefix="EUR";
         if((AvailablePair[1]==true)&&(EUR_Trade_EURGBP==true))
            ManagePairs(TimeToTrade_EUR,1,SetBuffers,CommentPrefix);
         if((AvailablePair[2]==true)&&(EUR_Trade_EURAUD==true))
            ManagePairs(TimeToTrade_EUR,2,SetBuffers,CommentPrefix);
         if((AvailablePair[3]==true)&&(EUR_Trade_EURNZD==true))
            ManagePairs(TimeToTrade_EUR,3,SetBuffers,CommentPrefix);
         if((AvailablePair[4]==true)&&(EUR_Trade_EURUSD==true))
            ManagePairs(TimeToTrade_EUR,4,SetBuffers,CommentPrefix);
         if((AvailablePair[5]==true)&&(EUR_Trade_EURCAD==true))
            ManagePairs(TimeToTrade_EUR,5,SetBuffers,CommentPrefix);
         if((AvailablePair[6]==true)&&(EUR_Trade_EURCHF==true))
            ManagePairs(TimeToTrade_EUR,6,SetBuffers,CommentPrefix);
         if((AvailablePair[7]==true)&&(EUR_Trade_EURJPY==true))
            ManagePairs(TimeToTrade_EUR,7,SetBuffers,CommentPrefix);
         //---Reset vallues
         if(_EUR_TradeInNewsRelease==2) {
            Open_EUR=false;
            Close_EUR=false;
            Delete_EUR=false;
         }
      }
      //---------------------------------------------------------------------
      if(_GBP_TradeInNewsRelease>0) {
         SetBuffers=2;
         CommentPrefix="GBP";
         if((AvailablePair[8]==true)&&(GBP_TradeIn_EURGBP==true))
            ManagePairs(TimeToTrade_GBP,8,SetBuffers,CommentPrefix);
         if((AvailablePair[9]==true)&&(GBP_TradeIn_GBPAUD==true))
            ManagePairs(TimeToTrade_GBP,9,SetBuffers,CommentPrefix);
         if((AvailablePair[10]==true)&&(GBP_TradeIn_GBPNZD==true))
            ManagePairs(TimeToTrade_GBP,10,SetBuffers,CommentPrefix);
         if((AvailablePair[11]==true)&&(GBP_TradeIn_GBPUSD==true))
            ManagePairs(TimeToTrade_GBP,11,SetBuffers,CommentPrefix);
         if((AvailablePair[12]==true)&&(GBP_TradeIn_GBPCAD==true))
            ManagePairs(TimeToTrade_GBP,12,SetBuffers,CommentPrefix);
         if((AvailablePair[13]==true)&&(GBP_TradeIn_GBPCHF==true))
            ManagePairs(TimeToTrade_GBP,13,SetBuffers,CommentPrefix);
         if((AvailablePair[14]==true)&&(GBP_TradeIn_GBPJPY==true))
            ManagePairs(TimeToTrade_GBP,14,SetBuffers,CommentPrefix);
         //---Reset vallues
         if(_GBP_TradeInNewsRelease==2) {
            Open_GBP=false;
            Close_GBP=false;
            Delete_GBP=false;
         }
      }
      //---------------------------------------------------------------------
      if(_AUD_TradeInNewsRelease>0) {
         SetBuffers=3;
         CommentPrefix="AUD";
         if((AvailablePair[15]==true)&&(AUD_TradeIn_EURAUD==true))
            ManagePairs(TimeToTrade_AUD,15,SetBuffers,CommentPrefix);
         if((AvailablePair[16]==true)&&(AUD_TradeIn_GBPAUD==true))
            ManagePairs(TimeToTrade_AUD,16,SetBuffers,CommentPrefix);
         if((AvailablePair[17]==true)&&(AUD_TradeIn_AUDNZD==true))
            ManagePairs(TimeToTrade_AUD,17,SetBuffers,CommentPrefix);
         if((AvailablePair[18]==true)&&(AUD_TradeIn_AUDUSD==true))
            ManagePairs(TimeToTrade_AUD,18,SetBuffers,CommentPrefix);
         if((AvailablePair[19]==true)&&(AUD_TradeIn_AUDCAD==true))
            ManagePairs(TimeToTrade_AUD,19,SetBuffers,CommentPrefix);
         if((AvailablePair[20]==true)&&(AUD_TradeIn_AUDCHF==true))
            ManagePairs(TimeToTrade_AUD,20,SetBuffers,CommentPrefix);
         if((AvailablePair[21]==true)&&(AUD_TradeIn_AUDJPY==true))
            ManagePairs(TimeToTrade_AUD,21,SetBuffers,CommentPrefix);
         //---Reset vallues
         if(_AUD_TradeInNewsRelease==2) {
            Open_AUD=false;
            Close_AUD=false;
            Delete_AUD=false;
         }
      }
      //---------------------------------------------------------------------
      if(_NZD_TradeInNewsRelease>0) {
         SetBuffers=4;
         CommentPrefix="NZD";
         if((AvailablePair[22]==true)&&(NZD_TradeIn_EURNZD==true))
            ManagePairs(TimeToTrade_NZD,22,SetBuffers,CommentPrefix);
         if((AvailablePair[23]==true)&&(NZD_TradeIn_GBPNZD==true))
            ManagePairs(TimeToTrade_NZD,23,SetBuffers,CommentPrefix);
         if((AvailablePair[24]==true)&&(NZD_TradeIn_AUDNZD==true))
            ManagePairs(TimeToTrade_NZD,24,SetBuffers,CommentPrefix);
         if((AvailablePair[25]==true)&&(NZD_TradeIn_NZDUSD==true))
            ManagePairs(TimeToTrade_NZD,25,SetBuffers,CommentPrefix);
         if((AvailablePair[26]==true)&&(NZD_TradeIn_NZDCAD==true))
            ManagePairs(TimeToTrade_NZD,26,SetBuffers,CommentPrefix);
         if((AvailablePair[27]==true)&&(NZD_TradeIn_NZDCHF==true))
            ManagePairs(TimeToTrade_NZD,27,SetBuffers,CommentPrefix);
         if((AvailablePair[28]==true)&&(NZD_TradeIn_NZDJPY==true))
            ManagePairs(TimeToTrade_NZD,28,SetBuffers,CommentPrefix);
         //---Reset vallues
         if(_NZD_TradeInNewsRelease==2) {
            Open_NZD=false;
            Close_NZD=false;
            Delete_NZD=false;
         }
      }
      //---------------------------------------------------------------------
      if(_USD_TradeInNewsRelease>0) {
         SetBuffers=5;
         CommentPrefix="USD";
         if((AvailablePair[29]==true)&&(USD_TradeIn_EURUSD==true))
            ManagePairs(TimeToTrade_USD,29,SetBuffers,CommentPrefix);
         if((AvailablePair[30]==true)&&(USD_TradeIn_GBPUSD==true))
            ManagePairs(TimeToTrade_USD,30,SetBuffers,CommentPrefix);
         if((AvailablePair[31]==true)&&(USD_TradeIn_AUDUSD==true))
            ManagePairs(TimeToTrade_USD,31,SetBuffers,CommentPrefix);
         if((AvailablePair[32]==true)&&(USD_TradeIn_NZDUSD==true))
            ManagePairs(TimeToTrade_USD,32,SetBuffers,CommentPrefix);
         if((AvailablePair[33]==true)&&(USD_TradeIn_USDCAD==true))
            ManagePairs(TimeToTrade_USD,33,SetBuffers,CommentPrefix);
         if((AvailablePair[34]==true)&&(USD_TradeIn_USDCHF==true))
            ManagePairs(TimeToTrade_USD,34,SetBuffers,CommentPrefix);
         if((AvailablePair[35]==true)&&(USD_TradeIn_USDJPY==true))
            ManagePairs(TimeToTrade_USD,35,SetBuffers,CommentPrefix);
         //---Reset vallues
         if(_USD_TradeInNewsRelease==2) {
            Open_USD=false;
            Close_USD=false;
            Delete_USD=false;
         }
      }
      //---------------------------------------------------------------------
      if(_CAD_TradeInNewsRelease>0) {
         SetBuffers=6;
         CommentPrefix="CAD";
         if((AvailablePair[36]==true)&&(CAD_TradeIn_EURCAD==true))
            ManagePairs(TimeToTrade_CAD,36,SetBuffers,CommentPrefix);
         if((AvailablePair[37]==true)&&(CAD_TradeIn_GBPCAD==true))
            ManagePairs(TimeToTrade_CAD,37,SetBuffers,CommentPrefix);
         if((AvailablePair[38]==true)&&(CAD_TradeIn_AUDCAD==true))
            ManagePairs(TimeToTrade_CAD,38,SetBuffers,CommentPrefix);
         if((AvailablePair[39]==true)&&(CAD_TradeIn_NZDCAD==true))
            ManagePairs(TimeToTrade_CAD,39,SetBuffers,CommentPrefix);
         if((AvailablePair[40]==true)&&(CAD_TradeIn_USDCAD==true))
            ManagePairs(TimeToTrade_CAD,40,SetBuffers,CommentPrefix);
         if((AvailablePair[41]==true)&&(CAD_TradeIn_CADCHF==true))
            ManagePairs(TimeToTrade_CAD,41,SetBuffers,CommentPrefix);
         if((AvailablePair[42]==true)&&(CAD_TradeIn_CADJPY==true))
            ManagePairs(TimeToTrade_CAD,42,SetBuffers,CommentPrefix);
         //---Reset vallues
         if(_CAD_TradeInNewsRelease==2) {
            Open_CAD=false;
            Close_CAD=false;
            Delete_CAD=false;
         }
      }
      //---------------------------------------------------------------------
      if(_CHF_TradeInNewsRelease>0) {
         SetBuffers=7;
         CommentPrefix="CHF";
         if((AvailablePair[43]==true)&&(CHF_TradeIn_EURCHF==true))
            ManagePairs(TimeToTrade_CHF,43,SetBuffers,CommentPrefix);
         if((AvailablePair[44]==true)&&(CHF_TradeIn_GBPCHF==true))
            ManagePairs(TimeToTrade_CHF,44,SetBuffers,CommentPrefix);
         if((AvailablePair[45]==true)&&(CHF_TradeIn_AUDCHF==true))
            ManagePairs(TimeToTrade_CHF,45,SetBuffers,CommentPrefix);
         if((AvailablePair[46]==true)&&(CHF_TradeIn_NZDCHF==true))
            ManagePairs(TimeToTrade_CHF,46,SetBuffers,CommentPrefix);
         if((AvailablePair[47]==true)&&(CHF_TradeIn_USDCHF==true))
            ManagePairs(TimeToTrade_CHF,47,SetBuffers,CommentPrefix);
         if((AvailablePair[48]==true)&&(CHF_TradeIn_CADCHF==true))
            ManagePairs(TimeToTrade_CHF,48,SetBuffers,CommentPrefix);
         if((AvailablePair[49]==true)&&(CHF_TradeIn_CHFJPY==true))
            ManagePairs(TimeToTrade_CHF,49,SetBuffers,CommentPrefix);
         //---Reset vallues
         if(_CHF_TradeInNewsRelease==2) {
            Open_CHF=false;
            Close_CHF=false;
            Delete_CHF=false;
         }
      }
      //---------------------------------------------------------------------
      if(_JPY_TradeInNewsRelease>0) {
         SetBuffers=8;
         CommentPrefix="JPY";
         if((AvailablePair[50]==true)&&(JPY_TradeIn_EURJPY==true))
            ManagePairs(TimeToTrade_JPY,50,SetBuffers,CommentPrefix);
         if((AvailablePair[51]==true)&&(JPY_TradeIn_GBPJPY==true))
            ManagePairs(TimeToTrade_JPY,51,SetBuffers,CommentPrefix);
         if((AvailablePair[52]==true)&&(JPY_TradeIn_AUDJPY==true))
            ManagePairs(TimeToTrade_JPY,52,SetBuffers,CommentPrefix);
         if((AvailablePair[53]==true)&&(JPY_TradeIn_NZDJPY==true))
            ManagePairs(TimeToTrade_JPY,53,SetBuffers,CommentPrefix);
         if((AvailablePair[54]==true)&&(JPY_TradeIn_USDJPY==true))
            ManagePairs(TimeToTrade_JPY,54,SetBuffers,CommentPrefix);
         if((AvailablePair[55]==true)&&(JPY_TradeIn_CADJPY==true))
            ManagePairs(TimeToTrade_JPY,55,SetBuffers,CommentPrefix);
         if((AvailablePair[56]==true)&&(JPY_TradeIn_CHFJPY==true))
            ManagePairs(TimeToTrade_JPY,56,SetBuffers,CommentPrefix);
         //---Reset vallues
         if(_JPY_TradeInNewsRelease==2) {
            Open_JPY=false;
            Close_JPY=false;
            Delete_JPY=false;
         }
      }
      //---------------------------------------------------------------------
      if(_CNY_TradeInNewsRelease>0) {
         SetBuffers=9;
         CommentPrefix="CNY";
         if((AvailablePair[57]==true)&&(CNY_TradeIn_EURCNY==true))
            ManagePairs(TimeToTrade_CNY,57,SetBuffers,CommentPrefix);
         if((AvailablePair[58]==true)&&(CNY_TradeIn_USDCNY==true))
            ManagePairs(TimeToTrade_CNY,58,SetBuffers,CommentPrefix);
         if((AvailablePair[59]==true)&&(CNY_TradeIn_JPYCNY==true))
            ManagePairs(TimeToTrade_CNY,59,SetBuffers,CommentPrefix);
         //---Reset vallues
         if(_JPY_TradeInNewsRelease==2) {
            Open_JPY=false;
            Close_JPY=false;
            Delete_JPY=false;
         }
      }
   }
//---------------------------------------------------------------------
//Call comment function every tick
   CommentScreen();
//---------------------------------------------------------------------
}






//====================================================================================================================================================//
//Manage pairs
//====================================================================================================================================================//
void ManagePairs(bool TradeSession,int ModePair,int SetCountry,string CountryComOrdr)
{
//---------------------------------------------------------------------
//Reset value
   TotalOpenPendingOrders=0;
   TotalOpenMarketOrders=0;
   TotalProfitLoss=0;
   TotalOrdesLots=0;
//---------------------------------------------------------------------
//Get prices
   PriceAsk=NormalizeDouble(SymbolInfoDouble(Pair[ModePair],SYMBOL_ASK),(int)SymbolInfoInteger(Pair[ModePair], SYMBOL_DIGITS));
   PriceBid=NormalizeDouble(SymbolInfoDouble(Pair[ModePair],SYMBOL_BID),(int)SymbolInfoInteger(Pair[ModePair], SYMBOL_DIGITS));
//---------------------------------------------------------------------
//Set check manually orders from buttons
   if(((_EUR_TradeInNewsRelease==Trade_From_Panel)&&(CountryComOrdr=="EUR"))||
         ((_GBP_TradeInNewsRelease==Trade_From_Panel)&&(CountryComOrdr=="GBP"))||
         ((_AUD_TradeInNewsRelease==Trade_From_Panel)&&(CountryComOrdr=="AUD"))||
         ((_NZD_TradeInNewsRelease==Trade_From_Panel)&&(CountryComOrdr=="NZD"))||
         ((_USD_TradeInNewsRelease==Trade_From_Panel)&&(CountryComOrdr=="USD"))||
         ((_CAD_TradeInNewsRelease==Trade_From_Panel)&&(CountryComOrdr=="CAD"))||
         ((_CHF_TradeInNewsRelease==Trade_From_Panel)&&(CountryComOrdr=="CHF"))||
         ((_JPY_TradeInNewsRelease==Trade_From_Panel)&&(CountryComOrdr=="JPY"))||
         ((_CNY_TradeInNewsRelease==Trade_From_Panel)&&(CountryComOrdr=="CNY")))
      CheckOrdersBaseNews=true;
//---------------------------------------------------------------------
//Modify market orders
   if((_UseTralingStopLoss==true) && (BuyOrders[ModePair]+SellOrders[ModePair]>0)) {
      if(BuyOrders[ModePair]>0)
         ModifyOrders(OP_BUY,ModePair);
      if(SellOrders[ModePair]>0)
         ModifyOrders(OP_SELL,ModePair);
   }
//---------------------------------------------------------------------
//Delete if trigered 1 of pending orders
   if((_DeleteOrphanPending==true) && (BuyOrders[ModePair]+SellOrders[ModePair]>0)) {
      if(BuyStopOrders[ModePair]>0)
         DeleteOrders(OP_BUYSTOP,ModePair);
      if(SellStopOrders[ModePair]>0)
         DeleteOrders(OP_SELLSTOP,ModePair);
   }
//---------------------------------------------------------------------
//Modify pending orders
   if(CheckOrdersBaseNews==true) {
      if((_UseModifyPending==true)
            && (TradeSession==true)
            && (BuyStopOrders[ModePair]+SellStopOrders[ModePair]>0)
            && ((SessionBeforeEvent[SetCountry]==true) || (_ModifyAfterEvent==true))) {
         if(BuyStopOrders[ModePair]>0)
            ModifyOrders(OP_BUYSTOP,ModePair);
         if(SellStopOrders[ModePair]>0)
            ModifyOrders(OP_SELLSTOP,ModePair);
      }
      //---------------------------------------------------------------------
      //Delete pending orders out of trade session
      if((_DeleteOrdersAfterEvent==true) && (TradeSession==false)) {
         if(((_EUR_TradeInNewsRelease!=Trade_From_Panel)&&(CountryComOrdr=="EUR"))||
               ((_GBP_TradeInNewsRelease!=Trade_From_Panel)&&(CountryComOrdr=="GBP"))||
               ((_AUD_TradeInNewsRelease!=Trade_From_Panel)&&(CountryComOrdr=="AUD"))||
               ((_NZD_TradeInNewsRelease!=Trade_From_Panel)&&(CountryComOrdr=="NZD"))||
               ((_USD_TradeInNewsRelease!=Trade_From_Panel)&&(CountryComOrdr=="USD"))||
               ((_CAD_TradeInNewsRelease!=Trade_From_Panel)&&(CountryComOrdr=="CAD"))||
               ((_CHF_TradeInNewsRelease!=Trade_From_Panel)&&(CountryComOrdr=="CHF"))||
               ((_JPY_TradeInNewsRelease!=Trade_From_Panel)&&(CountryComOrdr=="JPY"))||
               ((_CNY_TradeInNewsRelease!=Trade_From_Panel)&&(CountryComOrdr=="CNY"))) {
            if(BuyStopOrders[ModePair]>0)
               DeleteOrders(OP_BUYSTOP,ModePair);
            if(SellStopOrders[ModePair]>0)
               DeleteOrders(OP_SELLSTOP,ModePair);
         }
      }
      //---------------------------------------------------------------------
      //Delete pending orders from buttons
      if(((_EUR_TradeInNewsRelease==Trade_From_Panel)&&(CountryComOrdr=="EUR")&&(Delete_EUR==true))||
            ((_GBP_TradeInNewsRelease==Trade_From_Panel)&&(CountryComOrdr=="GBP")&&(Delete_GBP==true))||
            ((_AUD_TradeInNewsRelease==Trade_From_Panel)&&(CountryComOrdr=="AUD")&&(Delete_AUD==true))||
            ((_NZD_TradeInNewsRelease==Trade_From_Panel)&&(CountryComOrdr=="NZD")&&(Delete_NZD==true))||
            ((_USD_TradeInNewsRelease==Trade_From_Panel)&&(CountryComOrdr=="USD")&&(Delete_USD==true))||
            ((_CAD_TradeInNewsRelease==Trade_From_Panel)&&(CountryComOrdr=="CAD")&&(Delete_CAD==true))||
            ((_CHF_TradeInNewsRelease==Trade_From_Panel)&&(CountryComOrdr=="CHF")&&(Delete_CHF==true))||
            ((_JPY_TradeInNewsRelease==Trade_From_Panel)&&(CountryComOrdr=="JPY")&&(Delete_JPY==true))||
            ((_CNY_TradeInNewsRelease==Trade_From_Panel)&&(CountryComOrdr=="CNY")&&(Delete_CNY==true))) {
         if(BuyStopOrders[ModePair]>0)
            DeleteOrders(OP_BUYSTOP,ModePair);
         if(SellStopOrders[ModePair]>0)
            DeleteOrders(OP_SELLSTOP,ModePair);
      }
      //---------------------------------------------------------------------
      //Close market orders from buttons
      if(((_EUR_TradeInNewsRelease==Trade_From_Panel)&&(CountryComOrdr=="EUR")&&(Close_EUR==true))||
            ((_GBP_TradeInNewsRelease==Trade_From_Panel)&&(CountryComOrdr=="GBP")&&(Close_GBP==true))||
            ((_AUD_TradeInNewsRelease==Trade_From_Panel)&&(CountryComOrdr=="AUD")&&(Close_AUD==true))||
            ((_NZD_TradeInNewsRelease==Trade_From_Panel)&&(CountryComOrdr=="NZD")&&(Close_NZD==true))||
            ((_USD_TradeInNewsRelease==Trade_From_Panel)&&(CountryComOrdr=="USD")&&(Close_USD==true))||
            ((_CAD_TradeInNewsRelease==Trade_From_Panel)&&(CountryComOrdr=="CAD")&&(Close_CAD==true))||
            ((_CHF_TradeInNewsRelease==Trade_From_Panel)&&(CountryComOrdr=="CHF")&&(Close_CHF==true))||
            ((_JPY_TradeInNewsRelease==Trade_From_Panel)&&(CountryComOrdr=="JPY")&&(Close_JPY==true))||
            ((_CNY_TradeInNewsRelease==Trade_From_Panel)&&(CountryComOrdr=="CNY")&&(Close_CNY==true))) {
         if(BuyOrders[ModePair]>0)
            CloseOrders(OP_BUY,ModePair);
         if(SellOrders[ModePair]>0)
            CloseOrders(OP_SELL,ModePair);
      }
      //---------------------------------------------------------------------
      //Close market orders out of trade session
      if((_CloseOrdersAfterEvent==true) && (TradeSession==false)) {
         if(BuyOrders[ModePair]>0)
            CloseOrders(OP_BUY,ModePair);
         if(SellOrders[ModePair]>0)
            CloseOrders(OP_SELL,ModePair);
      }
      //---------------------------------------------------------------------
      //Open orders
      if((TradeSession==true) && (BuyOrders[ModePair]+SellOrders[ModePair]==0) && ((TimeCurrent()-LastTradeTime[ModePair]>SecondsBeforeNewsStart+SecondsAfterNewsStop) || (TradeOneTimePerNews==false))) {
         if(BuyStopOrders[ModePair]==0)
            OpenOrders(OP_BUYSTOP,ModePair,CountryComOrdr,-1);
         if(SellStopOrders[ModePair]==0)
            OpenOrders(OP_SELLSTOP,ModePair,CountryComOrdr,-1);
      }
   }
//---------------------------------------------------------------------
//Replace pending order in loss
   if(_UseReplaceMode==true) {
      if(LastTradeProfitLoss[ModePair]>=0) {
         if(_DeleteOrphanIfGetProfit==true) {
            if((BuyStopOrders[ModePair]==1) && (SellStopOrders[ModePair]==0) && (SellOrders[ModePair]==0))
               DeleteOrders(OP_BUYSTOP,ModePair);
            if((SellStopOrders[ModePair]==1) && (BuyStopOrders[ModePair]==0) && (BuyOrders[ModePair]==0))
               DeleteOrders(OP_SELLSTOP,ModePair);
         }
      }
      //---
      if((LastTradeProfitLoss[ModePair]<0) && (BuyOrders[ModePair]+SellOrders[ModePair]==0) && ((BuyStopOrders[ModePair]==1) || (SellStopOrders[ModePair]==1)) && ((TradeSession==true) || (_RunReplaceAfterNewsEnd==true))) {
         if((SellStopOrders[ModePair]==1) && (BuyStopOrders[ModePair]==0) && (BuyOrders[ModePair]==0) && (PriceAsk-PriceOpenSellStopOrder[ModePair]<=DistancePendingOrders*SymbolInfoDouble(Pair[ModePair],SYMBOL_POINT)*MultiplierPoint))
            OpenOrders(OP_BUYSTOP,ModePair,CountryComOrdr,4);
         if((BuyStopOrders[ModePair]==1) && (SellStopOrders[ModePair]==0) && (SellOrders[ModePair]==0) && (PriceOpenBuyStopOrder[ModePair]-PriceBid<=DistancePendingOrders*SymbolInfoDouble(Pair[ModePair],SYMBOL_POINT)*MultiplierPoint))
            OpenOrders(OP_SELLSTOP,ModePair,CountryComOrdr,4);
      }
   }
//---------------------------------------------------------------------
//Recovery market order in loss
   if(_UseRecoveryMode==true) {
      if((LastTradeProfitLoss[ModePair]<0) && (BuyOrders[ModePair]+SellOrders[ModePair]==0) && (BuyStopOrders[ModePair]+SellStopOrders[ModePair]==0) && ((TradeSession==true) || (_RunRecoveryAfterNewsEnd==true))) {
         if(LastTradeType[ModePair]==OP_SELL)
            OpenOrders(OP_BUY,ModePair,CountryComOrdr,1);
         if(LastTradeType[ModePair]==OP_BUY)
            OpenOrders(OP_SELL,ModePair,CountryComOrdr,1);
      }
   }
//---------------------------------------------------------------------
//Close orders as basket
   if(_CloseAllOrdersAsOne==true) {
      //---Set values
      TotalOpenPendingOrders=OpenPendingOrders[SetCountry];
      TotalOpenMarketOrders=OpenMarketOrders[SetCountry];
      TotalProfitLoss=ProfitLoss[SetCountry];
      TotalOrdesLots=OrdesLots[SetCountry];
      //---Check to close
      if(((TotalOpenPendingOrders==0) || (_WaitToTriggeredAllOrders==false)) && (TotalOpenMarketOrders>0)) {
         if(((TotalProfitLoss>=TotalOrdesLots*LevelCloseAllInProfit) && (LevelCloseAllInProfit>0)) || ((TotalProfitLoss<=-(TotalOrdesLots*LevelCloseAllInLoss)) && (LevelCloseAllInLoss>0))) {
            if(BuyOrders[ModePair]>0)
               CloseOrders(OP_BUY,ModePair);
            if(SellOrders[ModePair]>0)
               CloseOrders(OP_SELL,ModePair);
         }
      }
   }
//---------------------------------------------------------------------
}
//====================================================================================================================================================//
//Delete orders
//====================================================================================================================================================//
void DeleteOrders(int TypeOfOrder,int ModePair)
{
//---------------------------------------------------------------------
   bool DeletePending=false;
//---------------------------------------------------------------------
//Delete pending orders
   for(I_INDEXER=OrdersTotal()-1; I_INDEXER>=0; I_INDEXER--) {
      if(OrderSelect(I_INDEXER,SELECT_BY_POS)==true) {
         if((OrderSymbol()==Pair[ModePair]) && (OrderMagicNumber()==PairID[ModePair]) && (OrderMagicNumber()!=0)) {
            if(((OrderType()==OP_BUYSTOP) && ((TypeOfOrder==OP_BUYSTOP) || (TypeOfOrder==0))) || ((OrderType()==OP_SELLSTOP) && ((TypeOfOrder==OP_SELLSTOP) || (TypeOfOrder==0)))) {
               DeletePending=OrderDelete(OrderTicket(),clrNONE);
               if(DeletePending==true)
                  Print("Pending order has deleted");
               else {
                  //RefreshRates();//TODO
                  Print("Error: ",DoubleToString(GetLastError(),0)+" || "+ExpertName+": receives new data and try again delete order");
               }
            }
            //---------------------------------------------------------------------
            if((GetLastError()==1) || (GetLastError()==3) || (GetLastError()==130) || (GetLastError()==132) || (GetLastError()==133) || (GetLastError()==137) || (GetLastError()==4108) || (GetLastError()==4109)) {
               Print("Error: ",DoubleToString(GetLastError(),0)+" || "+ExpertName+": receives a error to delete order");
            }
            //---------------------------------------------------------------------
         }
      }
   }
//---------------------------------------------------------------------
}
//====================================================================================================================================================//
//Open orders
//====================================================================================================================================================//
void OpenOrders(int TypeOfOrder,int ModePair,string CommentByCoyntry,int StrategyMode)
{
//---------------------------------------------------------------------
   long SendOrder=0;
   double MultiLot=1;
   double CheckMargin=0;
   double Price=0;
   double ATRvalue=0;
   color Color=clrNONE;
   int TryTimes=0;
   PipsLoss=0;
   PipsProfits=0;
   TPVALUE=0;
   SLVALUE=0;
//---------------------------------------------------------------------
//Set lot size
   OrderLotSize=CalcLots(ModePair);
//---------------------------------------------------------------------
//Set stop loss and take profit
   if(TypeOf_TP_and_SL==0) { //Fixed
      if(_UseStopLoss==true)
         PipsLoss=_OrdersStopLoss;
      if(_UseTakeProfit==true)
         PipsProfits=OrdersTakeProfit;
      //---For replace mode
      if(StrategyMode==Replace_Orders_Strategy) {
         if(_UseStopLoss==true)
            PipsLoss=ReplaceOrdersStopLoss;
         if(_UseTakeProfit==true)
            PipsProfits=ReplaceOrdersTakeProfit;
      }
      //---For recovery mode
      RecoveryPipsLoss=RecoveryOrdersStopLoss;
      RecoveryPipsProfits=RecoveryOrdersTakeProfit;
   }
//---
//todo:
//skip atr based method
//if(TypeOf_TP_and_SL==1)//Based ATR
//  {
//   ATRvalue=iATR(Pair[ModePair],0,ATR_Period,1)/(SymbolInfoDouble(Pair[ModePair],SYMBOL_POINT)*MultiplierPoint);
//   if(_UseStopLoss==true)
//      PipsLoss=ATRvalue*ATR_Multiplier;
//   if(UseTakeProfit==true)
//      PipsProfits=PipsLoss*TakeProfitMultiplier;
//   //---For replace mode
//   if(StrategyMode==4)
//     {
//      if(_UseStopLoss==true)
//         PipsLoss=ATRvalue*ATR_Multiplier;
//      if(UseTakeProfit==true)
//         PipsProfits=PipsLoss*TakeProfitMultiplier;
//     }
//   //---For recovery mode
//   RecoveryPipsLoss=ATRvalue*ATR_Multiplier;
//   RecoveryPipsProfits=RecoveryPipsLoss*TakeProfitMultiplier;
//  }
//---------------------------------------------------------------------
//Set distance
   PipsLevelPending=DistancePendingOrders;
//---------------------------------------------------------------------
//Get stop level
   STOPLEVELVALUE=MathMax((double)SymbolInfoInteger(Pair[ModePair],SYMBOL_TRADE_FREEZE_LEVEL)/MultiplierPoint,(double)SymbolInfoInteger(Pair[ModePair],SYMBOL_TRADE_STOPS_LEVEL)/MultiplierPoint);
//---------------------------------------------------------------------
// Confirm pips distance, stop loss and take profit
   if(PipsLevelPending<STOPLEVELVALUE)
      PipsLevelPending=STOPLEVELVALUE;
   if((PipsLoss<STOPLEVELVALUE) && (_UseStopLoss==true))
      PipsLoss=STOPLEVELVALUE;
   if((PipsProfits<STOPLEVELVALUE) && (_UseTakeProfit==true))
      PipsProfits=STOPLEVELVALUE;
   if(RecoveryPipsLoss<STOPLEVELVALUE)
      RecoveryPipsLoss=STOPLEVELVALUE;
   if(RecoveryPipsProfits<STOPLEVELVALUE)
      RecoveryPipsProfits=STOPLEVELVALUE;
//---------------------------------------------------------------------
//Set buy stop
   if(TypeOfOrder==OP_BUYSTOP) {
      Price=NormalizeDouble(PriceAsk+PipsLevelPending*(SymbolInfoDouble(Pair[ModePair],SYMBOL_POINT)*MultiplierPoint),(int)SymbolInfoInteger(Pair[ModePair], SYMBOL_DIGITS));
      if(PipsProfits>0)
         TPVALUE=NormalizeDouble(PriceAsk+(PipsLevelPending+PipsProfits)*(SymbolInfoDouble(Pair[ModePair],SYMBOL_POINT)*MultiplierPoint),(int)SymbolInfoInteger(Pair[ModePair], SYMBOL_DIGITS));
      if(PipsLoss>0)
         SLVALUE=NormalizeDouble(PriceBid+(PipsLevelPending-PipsLoss)*(SymbolInfoDouble(Pair[ModePair],SYMBOL_POINT)*MultiplierPoint),(int)SymbolInfoInteger(Pair[ModePair], SYMBOL_DIGITS));
      Color=clrBlue;
   }
//---------------------------------------------------------------------
//Set sell stop
   if(TypeOfOrder==OP_SELLSTOP) {
      Price=NormalizeDouble(PriceBid-PipsLevelPending*(SymbolInfoDouble(Pair[ModePair],SYMBOL_POINT)*MultiplierPoint),(int)SymbolInfoInteger(Pair[ModePair], SYMBOL_DIGITS));
      if(PipsProfits>0)
         TPVALUE=NormalizeDouble(PriceBid-(PipsLevelPending+PipsProfits)*(SymbolInfoDouble(Pair[ModePair],SYMBOL_POINT)*MultiplierPoint),(int)SymbolInfoInteger(Pair[ModePair], SYMBOL_DIGITS));
      if(PipsLoss>0)
         SLVALUE=NormalizeDouble(PriceAsk-(PipsLevelPending-PipsLoss)*(SymbolInfoDouble(Pair[ModePair],SYMBOL_POINT)*MultiplierPoint),(int)SymbolInfoInteger(Pair[ModePair], SYMBOL_DIGITS));
      Color=clrRed;
   }
//---------------------------------------------------------------------
//Set buy
   if(TypeOfOrder==OP_BUY) {
      OrderLotSize=(MathMin(MathMax((MathRound((LastTradeLot[ModePair]*RecoveryMultiplierLot)/SymbolInfoDouble(Pair[ModePair],SYMBOL_VOLUME_STEP))*SymbolInfoDouble(Pair[ModePair],SYMBOL_VOLUME_STEP)),SymbolInfoDouble(Pair[ModePair],SYMBOL_VOLUME_MIN)),SymbolInfoDouble(Pair[ModePair],SYMBOL_VOLUME_MAX)));
      if(PipsProfits>0)
         TPVALUE=NormalizeDouble(PriceAsk+(RecoveryPipsProfits*SymbolInfoDouble(Pair[ModePair],SYMBOL_POINT)*MultiplierPoint),(int)SymbolInfoInteger(Pair[ModePair], SYMBOL_DIGITS));
      if(PipsLoss>0)
         SLVALUE=NormalizeDouble(PriceBid-(RecoveryPipsLoss*SymbolInfoDouble(Pair[ModePair],SYMBOL_POINT)*MultiplierPoint),(int)SymbolInfoInteger(Pair[ModePair], SYMBOL_DIGITS));
      Color=clrBlue;
   }
//---------------------------------------------------------------------
//Set sell stop
   if(TypeOfOrder==OP_SELL) {
      OrderLotSize=(MathMin(MathMax((MathRound((LastTradeLot[ModePair]*RecoveryMultiplierLot)/SymbolInfoDouble(Pair[ModePair],SYMBOL_VOLUME_STEP))*SymbolInfoDouble(Pair[ModePair],SYMBOL_VOLUME_STEP)),SymbolInfoDouble(Pair[ModePair],SYMBOL_VOLUME_MIN)),SymbolInfoDouble(Pair[ModePair],SYMBOL_VOLUME_MAX)));
      if(PipsProfits>0)
         TPVALUE=NormalizeDouble(PriceBid-(RecoveryPipsProfits*SymbolInfoDouble(Pair[ModePair],SYMBOL_POINT)*MultiplierPoint),(int)SymbolInfoInteger(Pair[ModePair], SYMBOL_DIGITS));
      if(PipsLoss>0)
         SLVALUE=NormalizeDouble(PriceAsk+(RecoveryPipsLoss*SymbolInfoDouble(Pair[ModePair],SYMBOL_POINT)*MultiplierPoint),(int)SymbolInfoInteger(Pair[ModePair], SYMBOL_DIGITS));
      Color=clrRed;
   }
//---------------------------------------------------------------------
//Check margin
   int CorrectedTypeOfOrder=-1;
   if((TypeOfOrder==OP_BUYSTOP)||(TypeOfOrder==OP_BUY))
      CorrectedTypeOfOrder=OP_BUY;
   if((TypeOfOrder==OP_SELLSTOP)||(TypeOfOrder==OP_SELL))
      CorrectedTypeOfOrder=OP_SELL;
//---
//todo
//   todo: freemargin check override
//if(AccountFreeMargin()>AccountFreeMarginCheck(Pair[ModePair],CorrectedTypeOfOrder,OrderLotSize))
//   CheckMargin=AccountFreeMargin()-AccountFreeMarginCheck(Pair[ModePair],CorrectedTypeOfOrder,OrderLotSize);
//if(AccountFreeMargin()<AccountFreeMarginCheck(Pair[ModePair],CorrectedTypeOfOrder,OrderLotSize))
//   CheckMargin=AccountFreeMargin()+(AccountFreeMargin()-AccountFreeMarginCheck(Pair[ModePair],CorrectedTypeOfOrder,OrderLotSize));
//---------------------------------------------------------------------
//Send order
//todo
   CheckMargin=1;
   if(CheckMargin>0) {
      while(true) {
         TryTimes++;
         SendOrder=OrderSend(Pair[ModePair],TypeOfOrder,OrderLotSize,Price,Slippage,SLVALUE,TPVALUE,ExpertName+"_"+CommentByCoyntry,PairID[ModePair],Expire,Color);
         if(SendOrder>0)
            break;
         if(TryTimes==3) {
            Print("Error: ",DoubleToString(GetLastError(),0)+" || "+ExpertName+": Could not open new order");
            break;
         }
         else {
            Print("Error: ",DoubleToString(GetLastError(),0)+" || "+ExpertName+": receives new data and try again open order");
            //RefreshRates(); todo
         }
         //---------------------------------------------------------------------
         if((GetLastError()==1) || (GetLastError()==132) || (GetLastError()==133) || (GetLastError()==137) || (GetLastError()==4108) || (GetLastError()==4109))
            break;
      }
   }
   else
      Print(ExpertName+": account free margin is too low!!!");
//---------------------------------------------------------------------
}
//====================================================================================================================================================//
//Modify orders
//====================================================================================================================================================//
void ModifyOrders(int TypeOrder,int ModePair)
{
//---------------------------------------------------------------------
   bool ModifyBuyStop=false;
   bool ModifySellStop=false;
   bool ModifyBuy=false;
   bool ModifySell=false;
   double StepModify=0;
   double DistanceBuy=0;
   double DistanceSell=0;
   double ATRvalue=0;
   int TryCnt=0;
   TPVALUE=0;
   SLVALUE=0;
   PipsLoss=0;
   PipsProfits=0;
//---------------------------------------------------------------------
//Set distance, stop loss and take profit
   if(TypeOf_TP_and_SL==0) {
      if(_UseStopLoss==true)
         PipsLoss=_OrdersStopLoss;
      if(_UseTakeProfit==true)
         PipsProfits=OrdersTakeProfit;
   }
//---
//todo
//atr based modification
//if(TypeOf_TP_and_SL==1)
//  {
//   ATRvalue=iATR(Pair[ModePair],0,ATR_Period,1)/(SymbolInfoDouble(Pair[ModePair],SYMBOL_POINT)*MultiplierPoint);
//   if(_UseStopLoss==true)
//      PipsLoss=ATRvalue*ATR_Multiplier;
//   if(UseTakeProfit==true)
//      PipsProfits=PipsLoss*TakeProfitMultiplier;
//  }
//---------------------------------------------------------------------
   for(I_INDEXER=0; I_INDEXER<OrdersTotal(); I_INDEXER++) {
      if(OrderSelect(I_INDEXER,SELECT_BY_POS)==true) {
         if((OrderSymbol()==Pair[ModePair]) && (OrderMagicNumber()==PairID[ModePair]) && (OrderMagicNumber()!=0)) {
            if(_UseModifyPending==true) {
               //---Modify Buy Stop
               if((OrderType()==OP_BUYSTOP) && (TypeOrder==OP_BUYSTOP)) {
                  //---Start count ticks
                  if((NormalizeDouble(PriceAsk,(int)SymbolInfoInteger(Pair[ModePair], SYMBOL_DIGITS))>NormalizeDouble(OrderOpenPrice()-DistanceBuy+StepModify,(int)SymbolInfoInteger(Pair[ModePair], SYMBOL_DIGITS))) ||
                        (NormalizeDouble(PriceAsk,(int)SymbolInfoInteger(Pair[ModePair], SYMBOL_DIGITS))<NormalizeDouble(OrderOpenPrice()-DistanceBuy-StepModify,(int)SymbolInfoInteger(Pair[ModePair], SYMBOL_DIGITS))))
                     CountTickBuyStop[ModePair]++;
                  //---
                  DistanceBuy=NormalizeDouble(PipsLevelPending*(SymbolInfoDouble(Pair[ModePair],SYMBOL_POINT)*MultiplierPoint),(int)SymbolInfoInteger(Pair[ModePair], SYMBOL_DIGITS));
                  StepModify=NormalizeDouble(StepModifyPending*(SymbolInfoDouble(Pair[ModePair],SYMBOL_POINT)*MultiplierPoint),(int)SymbolInfoInteger(Pair[ModePair], SYMBOL_DIGITS));
                  if(_UseTakeProfit==true)
                     TPVALUE=NormalizeDouble((PriceAsk+DistanceBuy)+PipsProfits*(SymbolInfoDouble(Pair[ModePair],SYMBOL_POINT)*MultiplierPoint),(int)SymbolInfoInteger(Pair[ModePair], SYMBOL_DIGITS));
                  if(_UseStopLoss==true)
                     SLVALUE=NormalizeDouble((PriceBid+DistanceBuy)-PipsLoss*(SymbolInfoDouble(Pair[ModePair],SYMBOL_POINT)*MultiplierPoint),(int)SymbolInfoInteger(Pair[ModePair], SYMBOL_DIGITS));
                  //---
                  if(((((NormalizeDouble(PriceAsk,(int)SymbolInfoInteger(Pair[ModePair], SYMBOL_DIGITS))>NormalizeDouble(OrderOpenPrice()-DistanceBuy+StepModify,(int)SymbolInfoInteger(Pair[ModePair], SYMBOL_DIGITS))) ||
                        (NormalizeDouble(PriceAsk,(int)SymbolInfoInteger(Pair[ModePair], SYMBOL_DIGITS))<NormalizeDouble(OrderOpenPrice()-DistanceBuy-StepModify,(int)SymbolInfoInteger(Pair[ModePair], SYMBOL_DIGITS)))) &&
                        (NormalizeDouble(PriceAsk+DistanceBuy,(int)SymbolInfoInteger(Pair[ModePair], SYMBOL_DIGITS))!=NormalizeDouble(OrderOpenPrice(),(int)SymbolInfoInteger(Pair[ModePair], SYMBOL_DIGITS))) && (CountTickBuyStop[ModePair]>=DelayModifyPending))) ||
                        (OrderStopLoss()==0)) {
                     TryCnt=0;
                     while(true) {
                        TryCnt++;
                        ModifyBuyStop=OrderModify(OrderTicket(),NormalizeDouble(PriceAsk+DistanceBuy,(int)SymbolInfoInteger(Pair[ModePair], SYMBOL_DIGITS)),SLVALUE,TPVALUE,Expire,clrBlue);
                        //---
                        if(ModifyBuyStop==true) {
                           CountTickBuyStop[ModePair]=0;
                           break;
                        }
                        //---
                        if(TryCnt==3) {
                           Print("Error: ",DoubleToString(GetLastError(),0)+" || "+ExpertName+": Could not modify, ticket: "+DoubleToString(OrderTicket(),0));
                           break;
                        }
                        else {
                           Print("Error: ",DoubleToString(GetLastError(),0)+" || "+ExpertName+": receives new data and try again modify order - "+DoubleToString(OrderTicket(),0));
                           //RefreshRates(); todo
                        }
                     }//End while(...
                  }
               }
               //---Modify Sell Stop
               if((OrderType()==OP_SELLSTOP) && (TypeOrder==OP_SELLSTOP)) {
                  //---Start count ticks
                  if((NormalizeDouble(PriceBid,(int)SymbolInfoInteger(Pair[ModePair], SYMBOL_DIGITS))<NormalizeDouble(OrderOpenPrice()+DistanceSell-StepModify,(int)SymbolInfoInteger(Pair[ModePair], SYMBOL_DIGITS))) ||
                        (NormalizeDouble(PriceBid,(int)SymbolInfoInteger(Pair[ModePair], SYMBOL_DIGITS))>NormalizeDouble(OrderOpenPrice()+DistanceSell+StepModify,(int)SymbolInfoInteger(Pair[ModePair], SYMBOL_DIGITS))))
                     CountTickSellStop[ModePair]++;
                  //---
                  DistanceSell=NormalizeDouble(PipsLevelPending*(SymbolInfoDouble(Pair[ModePair],SYMBOL_POINT)*MultiplierPoint),(int)SymbolInfoInteger(Pair[ModePair], SYMBOL_DIGITS));
                  StepModify=NormalizeDouble(StepModifyPending*(SymbolInfoDouble(Pair[ModePair],SYMBOL_POINT)*MultiplierPoint),(int)SymbolInfoInteger(Pair[ModePair], SYMBOL_DIGITS));
                  if(_UseTakeProfit==true)
                     TPVALUE=NormalizeDouble((PriceBid-DistanceSell)-PipsProfits*(SymbolInfoDouble(Pair[ModePair],SYMBOL_POINT)*MultiplierPoint),(int)SymbolInfoInteger(Pair[ModePair], SYMBOL_DIGITS));
                  if(_UseStopLoss==true)
                     SLVALUE=NormalizeDouble((PriceAsk-DistanceSell)+PipsLoss*(SymbolInfoDouble(Pair[ModePair],SYMBOL_POINT)*MultiplierPoint),(int)SymbolInfoInteger(Pair[ModePair], SYMBOL_DIGITS));
                  //---
                  if(((((NormalizeDouble(PriceBid,(int)SymbolInfoInteger(Pair[ModePair], SYMBOL_DIGITS))<NormalizeDouble(OrderOpenPrice()+DistanceSell-StepModify,(int)SymbolInfoInteger(Pair[ModePair], SYMBOL_DIGITS))) ||
                        (NormalizeDouble(PriceBid,(int)SymbolInfoInteger(Pair[ModePair], SYMBOL_DIGITS))>NormalizeDouble(OrderOpenPrice()+DistanceSell+StepModify,(int)SymbolInfoInteger(Pair[ModePair], SYMBOL_DIGITS)))) &&
                        (NormalizeDouble(PriceBid-DistanceSell,(int)SymbolInfoInteger(Pair[ModePair], SYMBOL_DIGITS))!=NormalizeDouble(OrderOpenPrice(),(int)SymbolInfoInteger(Pair[ModePair], SYMBOL_DIGITS))) && (CountTickSellStop[ModePair]>=DelayModifyPending))) ||
                        (OrderStopLoss()==0)) {
                     TryCnt=0;
                     while(true) {
                        TryCnt++;
                        ModifySellStop=OrderModify(OrderTicket(),NormalizeDouble(PriceBid-DistanceSell,(int)SymbolInfoInteger(Pair[ModePair], SYMBOL_DIGITS)),SLVALUE,TPVALUE,Expire,clrRed);
                        //---
                        if(ModifySellStop==true) {
                           CountTickSellStop[ModePair]=0;
                           break;
                        }
                        //---
                        if(TryCnt==3) {
                           Print("Error: ",DoubleToString(GetLastError(),0)+" || "+ExpertName+": Could not modify, ticket: "+DoubleToString(OrderTicket(),0));
                           break;
                        }
                        else {
                           Print("Error: ",DoubleToString(GetLastError(),0)+" || "+ExpertName+": receives new data and try again modify order - "+DoubleToString(OrderTicket(),0));
                           //RefreshRates();   todo
                        }
                     }//End while(...
                  }
               }
            }
            //---------------------------------------------------------------------
            //Start trailing stop loss
            if(_UseTralingStopLoss==true) {
               //---Modify Buy
               if((OrderType()==OP_BUY) && (TypeOrder==OP_BUY)) {
                  if((OrderTakeProfit()==0)&&(_UseTakeProfit==true))
                     TPVALUE=NormalizeDouble(SymbolInfoDouble(Pair[ModePair],SYMBOL_ASK)+PipsProfits*(SymbolInfoDouble(Pair[ModePair],SYMBOL_POINT)*MultiplierPoint),(int)SymbolInfoInteger(Pair[ModePair], SYMBOL_DIGITS));
                  else
                     TPVALUE=OrderTakeProfit();
                  //---
                  if(UseBreakEven) {
                     if((SymbolInfoDouble(Pair[ModePair],SYMBOL_BID)-OrderOpenPrice())>((BreakEvenPips+BreakEVenAfter)*(SymbolInfoDouble(Pair[ModePair],SYMBOL_POINT)*MultiplierPoint)))
                        SLVALUE=NormalizeDouble(SymbolInfoDouble(Pair[ModePair],SYMBOL_BID)-(BreakEvenPips*(SymbolInfoDouble(Pair[ModePair],SYMBOL_POINT)*MultiplierPoint)),(int)SymbolInfoInteger(Pair[ModePair], SYMBOL_DIGITS));
                  }
                  //---
                  if(UseBreakEven==false) {
                     if((SymbolInfoDouble(Pair[ModePair],SYMBOL_BID)-OrderOpenPrice())>(PipsLoss*(SymbolInfoDouble(Pair[ModePair],SYMBOL_POINT)*MultiplierPoint)))
                        SLVALUE=NormalizeDouble(SymbolInfoDouble(Pair[ModePair],SYMBOL_BID)-(PipsLoss*(SymbolInfoDouble(Pair[ModePair],SYMBOL_POINT)*MultiplierPoint)),(int)SymbolInfoInteger(Pair[ModePair], SYMBOL_DIGITS));
                  }
                  //---
                  if((NormalizeDouble(OrderStopLoss(),(int)SymbolInfoInteger(Pair[ModePair], SYMBOL_DIGITS))<NormalizeDouble(SLVALUE-(TrailingStopStep*(SymbolInfoDouble(Pair[ModePair],SYMBOL_POINT)*MultiplierPoint)),(int)SymbolInfoInteger(Pair[ModePair], SYMBOL_DIGITS)))&&(SLVALUE!=0.0)) {
                     TryCnt=0;
                     while(true) {
                        TryCnt++;
                        ModifyBuy=OrderModify(OrderTicket(),0,SLVALUE,TPVALUE,0,clrBlue);
                        //---
                        if(ModifyBuy==true)
                           break;
                        //---
                        if(TryCnt==3) {
                           Print("Error: ",DoubleToString(GetLastError(),0)+" || "+ExpertName+": Could not modify, ticket: "+DoubleToString(OrderTicket(),0));
                           break;
                        }
                        else {
                           Print("Error: ",DoubleToString(GetLastError(),0)+" || "+ExpertName+": receives new data and try again modify order - "+DoubleToString(OrderTicket(),0));
                           //RefreshRates();  todo
                        }
                     }//End while(...
                  }
               }
               //---Modify Sell
               if((OrderType()==OP_SELL) && (TypeOrder==OP_SELL)) {
                  if((OrderTakeProfit()==0)&&(_UseTakeProfit==true))
                     TPVALUE=NormalizeDouble(SymbolInfoDouble(Pair[ModePair],SYMBOL_BID)-PipsProfits*(SymbolInfoDouble(Pair[ModePair],SYMBOL_POINT)*MultiplierPoint),(int)SymbolInfoInteger(Pair[ModePair], SYMBOL_DIGITS));
                  else
                     TPVALUE=OrderTakeProfit();
                  //---
                  if(UseBreakEven==true) {
                     if((OrderOpenPrice()-SymbolInfoDouble(Pair[ModePair],SYMBOL_ASK))>((BreakEvenPips+BreakEVenAfter)*(SymbolInfoDouble(Pair[ModePair],SYMBOL_POINT)*MultiplierPoint)))
                        SLVALUE=NormalizeDouble(SymbolInfoDouble(Pair[ModePair],SYMBOL_ASK)+(BreakEvenPips*(SymbolInfoDouble(Pair[ModePair],SYMBOL_POINT)*MultiplierPoint)),(int)SymbolInfoInteger(Pair[ModePair], SYMBOL_DIGITS));
                  }
                  //---
                  if(UseBreakEven==false) {
                     if((OrderOpenPrice()-SymbolInfoDouble(Pair[ModePair],SYMBOL_ASK))>(PipsLoss*(SymbolInfoDouble(Pair[ModePair],SYMBOL_POINT)*MultiplierPoint)))
                        SLVALUE=NormalizeDouble(SymbolInfoDouble(Pair[ModePair],SYMBOL_ASK)+(PipsLoss*(SymbolInfoDouble(Pair[ModePair],SYMBOL_POINT)*MultiplierPoint)),(int)SymbolInfoInteger(Pair[ModePair], SYMBOL_DIGITS));
                  }
                  //---
                  if((NormalizeDouble(OrderStopLoss(),(int)SymbolInfoInteger(Pair[ModePair], SYMBOL_DIGITS))>NormalizeDouble(SLVALUE+(TrailingStopStep*(SymbolInfoDouble(Pair[ModePair],SYMBOL_POINT)*MultiplierPoint)),(int)SymbolInfoInteger(Pair[ModePair], SYMBOL_DIGITS)))&&(SLVALUE!=0.0)) {
                     TryCnt=0;
                     while(true) {
                        TryCnt++;
                        ModifySell=OrderModify(OrderTicket(),0,SLVALUE,TPVALUE,0,clrRed);
                        //---
                        if(ModifySell==true)
                           break;
                        //---
                        if(TryCnt==3) {
                           Print("Error: ",DoubleToString(GetLastError(),0)+" || "+ExpertName+": Could not modify, ticket: "+DoubleToString(OrderTicket(),0));
                           break;
                        }
                        else {
                           Print("Error: ",DoubleToString(GetLastError(),0)+" || "+ExpertName+": receives new data and try again modify order - "+DoubleToString(OrderTicket(),0));
                           //RefreshRates();todo
                        }
                     }//End while(...
                  }
               }
            }
            //---------------------------------------------------------------------
            //Errors
            if((GetLastError()==1) || (GetLastError()==3) || (GetLastError()==130) || (GetLastError()==132) || (GetLastError()==133) || (GetLastError()==137) || (GetLastError()==4108) || (GetLastError()==4109)) {
               Print("Error: ",DoubleToString(GetLastError(),0)+" || "+ExpertName+": receives a error modify order");
               break;
            }
            //---------------------------------------------------------------------
            //todo
            //RefreshRates();todo
         }
      }
   }
//---------------------------------------------------------------------
}
//====================================================================================================================================================//
//Close orders
//====================================================================================================================================================//
void CloseOrders(int OrdersType,int ModePair)
{
//---------------------------------------------------------------------
   int TryCnt=0;
   bool WasOrderClosed;
   datetime StartTimeClose=TimeCurrent();
//---------------------------------------------------------------------
   for(I_INDEXER=OrdersTotal()-1; I_INDEXER>=0; I_INDEXER--) {
      if(OrderSelect(I_INDEXER,SELECT_BY_POS,MODE_TRADES)==true) {
         if((OrderSymbol()==Pair[ModePair]) && (OrderMagicNumber()==PairID[ModePair]) && (OrderMagicNumber()!=0)) {
            //---------------------------------------------------------------------
            //Close buy
            if((OrderType()==OP_BUY) && (OrdersType==OP_BUY)) {
               TryCnt=0;
               WasOrderClosed=false;
               //---close order
               while(true) {
                  TryCnt++;
                  WasOrderClosed=OrderClose(OrderTicket(),OrderLots(),NormalizeDouble(PriceBid,(int)SymbolInfoInteger(Pair[ModePair], SYMBOL_DIGITS)),Slippage,clrMediumAquamarine);
                  if(WasOrderClosed>0)
                     break;
                  //---Errors
                  if((GetLastError()==1) || (GetLastError()==132) || (GetLastError()==133) || (GetLastError()==137) || (GetLastError()==4108) || (GetLastError()==4109))
                     break;
                  //---try 3 times to close
                  if(TryCnt==3) {
                     Print("Error: ",DoubleToString(GetLastError(),0)+" || "+ExpertName+": Could not close, ticket: "+DoubleToString(OrderTicket(),0));
                     break;
                  }
                  else {
                     Print("Error: ",DoubleToString(GetLastError(),0)+" || "+ExpertName+": receives new data and try again close order - "+DoubleToString(OrderTicket(),0));
                     //RefreshRates(); todo
                  }
               }//End while(...
            }//End if(OrderType()==OP_BUY)
            //---------------------------------------------------------------------
            //Close sell
            if((OrderType()==OP_SELL) && (OrdersType==OP_SELL)) {
               TryCnt=0;
               WasOrderClosed=false;
               //---close order
               while(true) {
                  TryCnt++;
                  WasOrderClosed=OrderClose(OrderTicket(),OrderLots(),NormalizeDouble(PriceAsk,(int)SymbolInfoInteger(Pair[ModePair], SYMBOL_DIGITS)),Slippage,clrDarkSalmon);
                  if(WasOrderClosed>0)
                     break;
                  //---Errors
                  if((GetLastError()==1) || (GetLastError()==132) || (GetLastError()==133) || (GetLastError()==137) || (GetLastError()==4108) || (GetLastError()==4109))
                     break;
                  //---try 3 times to close
                  if(TryCnt==3) {
                     Print("Error: ",DoubleToString(GetLastError(),0)+" || "+ExpertName+": Could not close, ticket: "+DoubleToString(OrderTicket(),0));
                     break;
                  }
                  else {
                     Print("Error: ",DoubleToString(GetLastError(),0)+" || "+ExpertName+": receives new data and try again close order - "+DoubleToString(OrderTicket(),0));
                     //RefreshRates();todo
                  }
               }//End while(...
            }//End if(OrderType()==OP_SELL)
            //---------------------------------------------------------------------
         }//End if((OrderSymbol()...
      }//End OrderSelect(...
   }//End for(...
//---------------------------------------------------------------------
}
//====================================================================================================================================================//
//Count orders
//====================================================================================================================================================//
void CountOrders()
{
//---------------------------------------------------------------------
   ArrayInitialize(BuyOrders,0);
   ArrayInitialize(SellOrders,0);
   ArrayInitialize(BuyStopOrders,0);
   ArrayInitialize(SellStopOrders,0);
   ArrayInitialize(OpenMarketOrders,0);
   ArrayInitialize(OpenPendingOrders,0);
   ArrayInitialize(PriceOpenBuyStopOrder,0);
   ArrayInitialize(PriceOpenSellStopOrder,0);
   ArrayInitialize(ProfitLoss,0);
   ArrayInitialize(OrdesLots,0);
   TotalOpenOrders=0;
//---------------------------------------------------------------------
   for(I_INDEXER=0; I_INDEXER<OrdersTotal(); I_INDEXER++) {
      if(OrderSelect(I_INDEXER,SELECT_BY_POS,MODE_TRADES)) {
         for(j=0; j<TotalPairs; j++) {
            if((OrderMagicNumber()==PairID[j]) && (OrderMagicNumber()!=0)) {
               TotalOpenOrders++;
               if(OrderType()==OP_BUY)
                  BuyOrders[j]++;
               if(OrderType()==OP_SELL)
                  SellOrders[j]++;
               if(OrderType()==OP_BUYSTOP) {
                  BuyStopOrders[j]++;
                  PriceOpenBuyStopOrder[j]=OrderOpenPrice();
               }
               if(OrderType()==OP_SELLSTOP) {
                  SellStopOrders[j]++;
                  PriceOpenSellStopOrder[j]=OrderOpenPrice();
               }
               //---1
               if((j>=1) && (j<=7)) {
                  OrdesLots[1]+=OrderLots();
                  ProfitLoss[1]+=OrderProfit()+OrderCommission()+OrderSwap();
                  if((OrderType()==OP_BUY)||(OrderType()==OP_SELL))
                     OpenMarketOrders[1]++;
                  if((OrderType()==OP_BUYSTOP)||(OrderType()==OP_SELLSTOP))
                     OpenPendingOrders[1]++;
               }
               //---2
               if((j>=8) && (j<=14)) {
                  OrdesLots[2]+=OrderLots();
                  ProfitLoss[2]+=OrderProfit()+OrderCommission()+OrderSwap();
                  if((OrderType()==OP_BUY)||(OrderType()==OP_SELL))
                     OpenMarketOrders[2]++;
                  if((OrderType()==OP_BUYSTOP)||(OrderType()==OP_SELLSTOP))
                     OpenPendingOrders[2]++;
               }
               //---3
               if((j>=15) && (j<=21)) {
                  OrdesLots[3]+=OrderLots();
                  ProfitLoss[3]+=OrderProfit()+OrderCommission()+OrderSwap();
                  if((OrderType()==OP_BUY)||(OrderType()==OP_SELL))
                     OpenMarketOrders[3]++;
                  if((OrderType()==OP_BUYSTOP)||(OrderType()==OP_SELLSTOP))
                     OpenPendingOrders[3]++;
               }
               //---4
               if((j>=22) && (j<=28)) {
                  OrdesLots[4]+=OrderLots();
                  ProfitLoss[4]+=OrderProfit()+OrderCommission()+OrderSwap();
                  if((OrderType()==OP_BUY)||(OrderType()==OP_SELL))
                     OpenMarketOrders[4]++;
                  if((OrderType()==OP_BUYSTOP)||(OrderType()==OP_SELLSTOP))
                     OpenPendingOrders[4]++;
               }
               //---5
               if((j>=29) && (j<=35)) {
                  OrdesLots[5]+=OrderLots();
                  ProfitLoss[5]+=OrderProfit()+OrderCommission()+OrderSwap();
                  if((OrderType()==OP_BUY)||(OrderType()==OP_SELL))
                     OpenMarketOrders[5]++;
                  if((OrderType()==OP_BUYSTOP)||(OrderType()==OP_SELLSTOP))
                     OpenPendingOrders[5]++;
               }
               //---6
               if((j>=36) && (j<=42)) {
                  OrdesLots[6]+=OrderLots();
                  ProfitLoss[6]+=OrderProfit()+OrderCommission()+OrderSwap();
                  if((OrderType()==OP_BUY)||(OrderType()==OP_SELL))
                     OpenMarketOrders[6]++;
                  if((OrderType()==OP_BUYSTOP)||(OrderType()==OP_SELLSTOP))
                     OpenPendingOrders[6]++;
               }
               //---7
               if((j>=43) && (j<=49)) {
                  OrdesLots[7]+=OrderLots();
                  ProfitLoss[7]+=OrderProfit()+OrderCommission()+OrderSwap();
                  if((OrderType()==OP_BUY)||(OrderType()==OP_SELL))
                     OpenMarketOrders[7]++;
                  if((OrderType()==OP_BUYSTOP)||(OrderType()==OP_SELLSTOP))
                     OpenPendingOrders[7]++;
               }
               //---8
               if((j>=50) && (j<=56)) {
                  OrdesLots[8]+=OrderLots();
                  ProfitLoss[8]+=OrderProfit()+OrderCommission()+OrderSwap();
                  if((OrderType()==OP_BUY)||(OrderType()==OP_SELL))
                     OpenMarketOrders[8]++;
                  if((OrderType()==OP_BUYSTOP)||(OrderType()==OP_SELLSTOP))
                     OpenPendingOrders[8]++;
               }
               //---9
               if((j>=57) && (j<=59)) {
                  OrdesLots[9]+=OrderLots();
                  ProfitLoss[9]+=OrderProfit()+OrderCommission()+OrderSwap();
                  if((OrderType()==OP_BUY)||(OrderType()==OP_SELL))
                     OpenMarketOrders[9]++;
                  if((OrderType()==OP_BUYSTOP)||(OrderType()==OP_SELLSTOP))
                     OpenPendingOrders[9]++;
               }
               //---
            }
         }
      }
   }
//---------------------------------------------------------------------
}
//====================================================================================================================================================//
//Count history results
//====================================================================================================================================================//
void HistoryResults()
{
//---------------------------------------------------------------------
   HistoryTrades=0;
   HistoryProfitLoss=0;
   ArrayInitialize(LastTradeTime,0);
   ArrayInitialize(LastTradeProfitLoss,0);
   ArrayInitialize(LastTradeType,-1);
   ArrayInitialize(LastTradeLot,0);
   ArrayInitialize(TotalHistoryOrders,0);
   ArrayInitialize(TotalHistoryProfit,0);
   ArrayInitialize(ResultsCurrencies,0);
//---------------------------------------------------------------------
   for(I_INDEXER=0; I_INDEXER<OrdersHistoryTotal(); I_INDEXER++) {
      if(OrderSelect(I_INDEXER,SELECT_BY_POS,MODE_HISTORY)) {
         for(j=0; j<TotalPairs; j++) {
            if((OrderMagicNumber()==PairID[j]) && (OrderMagicNumber()!=0)) {
               HistoryProfitLoss+=OrderProfit()+OrderCommission()+OrderSwap();
               if((OrderType()==OP_BUY) || (OrderType()==OP_SELL)) {
                  HistoryTrades++;
                  LastTradeTime[j]=OrderOpenTime();
                  LastTradeProfitLoss[j]=OrderProfit()+OrderCommission()+OrderSwap();
                  LastTradeType[j]=OrderType();
                  LastTradeLot[j]=OrderLots();
                  TotalHistoryOrders[j]++;
                  TotalHistoryProfit[j]+=OrderProfit()+OrderCommission()+OrderSwap();
               }
               //---1
               if((j>=1) && (j<=7)) {
                  ResultsCurrencies[1]+=OrderProfit()+OrderCommission()+OrderSwap();
               }
               //---2
               if((j>=8) && (j<=14)) {
                  ResultsCurrencies[2]+=OrderProfit()+OrderCommission()+OrderSwap();
               }
               //---3
               if((j>=15) && (j<=21)) {
                  ResultsCurrencies[3]+=OrderProfit()+OrderCommission()+OrderSwap();
               }
               //---4
               if((j>=22) && (j<=28)) {
                  ResultsCurrencies[4]+=OrderProfit()+OrderCommission()+OrderSwap();
               }
               //---5
               if((j>=29) && (j<=35)) {
                  ResultsCurrencies[5]+=OrderProfit()+OrderCommission()+OrderSwap();
               }
               //---6
               if((j>=36) && (j<=42)) {
                  ResultsCurrencies[6]+=OrderProfit()+OrderCommission()+OrderSwap();
               }
               //---7
               if((j>=43) && (j<=49)) {
                  ResultsCurrencies[7]+=OrderProfit()+OrderCommission()+OrderSwap();
               }
               //---8
               if((j>=50) && (j<=56)) {
                  ResultsCurrencies[8]+=OrderProfit()+OrderCommission()+OrderSwap();
               }
               //---9
               if((j>=57) && (j<=59)) {
                  ResultsCurrencies[9]+=OrderProfit()+OrderCommission()+OrderSwap();
               }
               //---
            }
         }
      }
   }
//---------------------------------------------------------------------
}
//====================================================================================================================================================//
//Lot size
//====================================================================================================================================================//
double CalcLots(int ModePair)
{
//---------------------------------------------------------------------
   double LotSize=0;
   string SymbolUse=Symbol();
//---------------------------------------------------------------------
   if((!IsTesting()) && (!IsOptimization()) && (!IsVisualMode()))
      SymbolUse=Pair[ModePair];//Bug of terminal
//---------------------------------------------------------------------
   if(MoneyManagement==true)
      LotSize=(AccountBalance()/SymbolInfoDouble(SymbolUse, SYMBOL_TRADE_CONTRACT_SIZE))*RiskFactor;
   if(MoneyManagement==false)
      LotSize=ManualLotSize;
//---------------------------------------------------------------------
   if(IsConnected())
      return(MathMin(MathMax((MathRound(LotSize/SymbolInfoDouble(SymbolUse,SYMBOL_VOLUME_STEP))*SymbolInfoDouble(SymbolUse,SYMBOL_VOLUME_STEP)),SymbolInfoDouble(SymbolUse,SYMBOL_VOLUME_MIN)),SymbolInfoDouble(SymbolUse,SYMBOL_VOLUME_MAX)));
   else
      return(LotSize);
//---------------------------------------------------------------------
}
//====================================================================================================================================================//
//Clear chart
//====================================================================================================================================================//
void ClearChart()
{
//---------------------------------------------------------------------
   for(I_INDEXER=ObjectsTotal()-1; I_INDEXER>=0; I_INDEXER--) {
      if((ObjectName(I_INDEXER)!="Background") && (StringSubstr(ObjectName(I_INDEXER),0,4)!="Text"))
         ObjectDelete(ObjectName(I_INDEXER));
   }
//---------------------------------------------------------------------
}
//====================================================================================================================================================//
//Comment's background
//====================================================================================================================================================//
void ChartBackground(string StringName,color ImageColor,int Xposition,int Yposition,int Xsize,int Ysize)
{
//---------------------------------------------------------------------
   if(ObjectFind(0,StringName)==-1) {
      ObjectCreate(0,StringName,OBJ_RECTANGLE_LABEL,0,0,0,0,0);
      ObjectSetInteger(0,StringName,OBJPROP_XDISTANCE,Xposition);
      ObjectSetInteger(0,StringName,OBJPROP_YDISTANCE,Yposition);
      ObjectSetInteger(0,StringName,OBJPROP_XSIZE,Xsize);
      ObjectSetInteger(0,StringName,OBJPROP_YSIZE,Ysize);
      ObjectSetInteger(0,StringName,OBJPROP_BGCOLOR,ImageColor);
      ObjectSetInteger(0,StringName,OBJPROP_BORDER_TYPE,BORDER_FLAT);
      ObjectSetInteger(0,StringName,OBJPROP_BORDER_COLOR,clrBlack);
      ObjectSetInteger(0,StringName,OBJPROP_BACK,false);
      ObjectSetInteger(0,StringName,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,StringName,OBJPROP_SELECTED,false);
      ObjectSetInteger(0,StringName,OBJPROP_HIDDEN,true);
      ObjectSetInteger(0,StringName,OBJPROP_ZORDER,0);
   }
//---------------------------------------------------------------------
}
//====================================================================================================================================================//
//Display text
//====================================================================================================================================================//
void DisplayText(string StringName,string Image,int FontSize,string FontType,color FontColor,int Xposition,int Yposition)
{
//---------------------------------------------------------------------
   ObjectCreate(StringName,OBJ_LABEL,0,0,0);
   ObjectSet(StringName,OBJPROP_CORNER,0);
   ObjectSet(StringName,OBJPROP_BACK,false);
   ObjectSet(StringName,OBJPROP_XDISTANCE,Xposition);
   ObjectSet(StringName,OBJPROP_YDISTANCE,Yposition);
   ObjectSet(StringName,OBJPROP_HIDDEN,true);
   ObjectSetText(StringName,Image,FontSize,FontType,FontColor);
//---------------------------------------------------------------------
}
//====================================================================================================================================================//
//Buttons Panel
//====================================================================================================================================================//
void ButtonsPanel(string NameObject, string NameButton, int Xdistance, int Ydistanc, color ColorButton)
{
//------------------------------------------------------
// if(ObjectFind(0,StringConcatenate(NameObject))==-1)  todo: verify
   if(ObjectFind(0,NameObject)==-1) {
      ObjectCreate(0,NameObject,OBJ_BUTTON,0,0,0);
      ObjectSetInteger(0,NameObject,OBJPROP_CORNER,0);
      ObjectSetInteger(0,NameObject,OBJPROP_XDISTANCE,Xdistance);
      ObjectSetInteger(0,NameObject,OBJPROP_YDISTANCE,Ydistanc);
      ObjectSetInteger(0,NameObject,OBJPROP_XSIZE,100);
      ObjectSetInteger(0,NameObject,OBJPROP_YSIZE,25);
      ObjectSetInteger(0,NameObject,OBJPROP_BGCOLOR,ColorButton);
      ObjectSetInteger(0,NameObject,OBJPROP_STATE,false);
      ObjectSetString(0,NameObject,OBJPROP_FONT,"Tahoma");
      ObjectSetInteger(0,NameObject,OBJPROP_FONTSIZE,10);
      ObjectSetInteger(0,NameObject,OBJPROP_COLOR,ColorFontButton);
      ObjectSetInteger(0,NameObject,OBJPROP_SELECTABLE,0);
      ObjectSetInteger(0,NameObject,OBJPROP_HIDDEN,1);
      ObjectSetString(0,NameObject,OBJPROP_TEXT,NameButton);
   }
//------------------------------------------------------
}
//====================================================================================================================================================//
//Comment in chart
//====================================================================================================================================================//
void CommentScreen()
{
//---------------------------------------------------------------------
   string MMstring="";
   string ImpactPrev="";
   string ImpactNext="";
   string ImpactTrade="";
   string Settings="";
   string StrategyUse="";
   SetBuffers=0;
//---------------------------------------------------------------------
//Delete objects to refresh
   if(ObjectFind("Text2")>-1)
      ObjectDelete("Text2");
   if(ObjectFind("Text10")>-1)
      ObjectDelete("Text10");
   if(ObjectFind("Text11")>-1)
      ObjectDelete("Text11");
   if(ObjectFind("Text12")>-1)
      ObjectDelete("Text12");
   if(ObjectFind("Text14")>-1)
      ObjectDelete("Text14");
   if(ObjectFind("Text15")>-1)
      ObjectDelete("Text15");
   if(ObjectFind("Text16")>-1)
      ObjectDelete("Text16");
   if(ObjectFind("Text18")>-1)
      ObjectDelete("Text18");
   if(ObjectFind("Text19")>-1)
      ObjectDelete("Text19");
   if(ObjectFind("Text20")>-1)
      ObjectDelete("Text20");
   if(ObjectFind("Text22")>-1)
      ObjectDelete("Text22");
   if(ObjectFind("Text23")>-1)
      ObjectDelete("Text23");
   if(ObjectFind("Text24")>-1)
      ObjectDelete("Text24");
   if(ObjectFind("Text26")>-1)
      ObjectDelete("Text26");
   if(ObjectFind("Text27")>-1)
      ObjectDelete("Text27");
   if(ObjectFind("Text28")>-1)
      ObjectDelete("Text28");
   if(ObjectFind("Text30")>-1)
      ObjectDelete("Text30");
   if(ObjectFind("Text31")>-1)
      ObjectDelete("Text31");
   if(ObjectFind("Text32")>-1)
      ObjectDelete("Text32");
   if(ObjectFind("Text34")>-1)
      ObjectDelete("Text34");
   if(ObjectFind("Text35")>-1)
      ObjectDelete("Text35");
   if(ObjectFind("Text36")>-1)
      ObjectDelete("Text36");
   if(ObjectFind("Text38")>-1)
      ObjectDelete("Text38");
   if(ObjectFind("Text39")>-1)
      ObjectDelete("Text39");
   if(ObjectFind("Text40")>-1)
      ObjectDelete("Text40");
   if(ObjectFind("Text42")>-1)
      ObjectDelete("Text42");
   if(ObjectFind("Text43")>-1)
      ObjectDelete("Text43");
   if(ObjectFind("Text44")>-1)
      ObjectDelete("Text44");
   if(ObjectFind("Text45")>-1)
      ObjectDelete("Text45");
//---------------------------------------------------------------------
//Set strategy comments
   if(StrategyToUse==0)
      StrategyUse="Custom_Stategy";
   if(StrategyToUse==1)
      StrategyUse="Recovery Orders";
   if(StrategyToUse==2)
      StrategyUse="Basket Orders";
   if(StrategyToUse==3)
      StrategyUse="Separate Orders";
   if(StrategyToUse==4)
      StrategyUse="Replace Orders";
//---------------------------------------------------------------------
//Set impact news comments
   if(ImpactToTrade==0)
      ImpactTrade="Low-Medium-High";
   if(ImpactToTrade==1)
      ImpactTrade="Medium - High";
   if(ImpactToTrade==2)
      ImpactTrade="Only High";
//---------------------------------------------------------------------
//Set impact info
   for(I_INDEXER=0; I_INDEXER<10; I_INDEXER++) {
      if(ExtBufferImpact[I_INDEXER][1]==-1)
         ShowImpact[I_INDEXER]="NONE";
      if(ExtBufferImpact[I_INDEXER][1]==0)
         ShowImpact[I_INDEXER]="Low";
      if(ExtBufferImpact[I_INDEXER][1]==1)
         ShowImpact[I_INDEXER]="Medium";
      if(ExtBufferImpact[I_INDEXER][1]==2)
         ShowImpact[I_INDEXER]="High";
      //---------------------------------------------------------------------
      //Set time info
      if(ShowInfoTime==0) { //TIME IN MINUTES
         if(ExtBufferSeconds[I_INDEXER][0]!=-9999)
            ShowSecondsSince[I_INDEXER]=DoubleToString(ExtBufferSeconds[I_INDEXER][0]/60,0);
         else
            ShowSecondsSince[I_INDEXER]="NONE";
         if(ExtBufferSeconds[I_INDEXER][1]!=9999)
            ShowSecondsUntil[I_INDEXER]=DoubleToString(ExtBufferSeconds[I_INDEXER][1]/60,0);
         else
            ShowSecondsUntil[I_INDEXER]="NONE";
      }
      //---
      if(ShowInfoTime==1) { //D...H...M
         if(ExtBufferSeconds[I_INDEXER][0]!=-9999) {
            if(ExtBufferSeconds[I_INDEXER][0]/60<60)
               ShowSecondsSince[I_INDEXER]=DoubleToString(0,0)+"/"+DoubleToString(0,0)+"/"+DoubleToString((int)(ExtBufferSeconds[I_INDEXER][0]/60),0);//Minutes
            if(MathRound((int)(ExtBufferSeconds[I_INDEXER][0]/60/60))<24)
               ShowSecondsSince[I_INDEXER]=DoubleToString(0,0)+"/"+DoubleToString((int)(ExtBufferSeconds[I_INDEXER][0]/60/60),0)+"/"+DoubleToString((int)(ExtBufferSeconds[I_INDEXER][0]/60)%60,0);//Hours and Minutes
            if(MathRound((int)(ExtBufferSeconds[I_INDEXER][0]/60/60))>=24)
               ShowSecondsSince[I_INDEXER]=DoubleToString((int)(ExtBufferSeconds[I_INDEXER][0]/60/60)/24,0)+"/"+DoubleToString((int)(ExtBufferSeconds[I_INDEXER][0]/60/60)%24,0)+"/"+DoubleToString((int)(ExtBufferSeconds[I_INDEXER][0]/60)%60,0);//Days and Hours and Minutes
         }
         else
            ShowSecondsSince[I_INDEXER]="NONE";
         //---
         if(ExtBufferSeconds[I_INDEXER][1]!=9999) {
            if(ExtBufferSeconds[I_INDEXER][1]/60<60)
               ShowSecondsUntil[I_INDEXER]=DoubleToString(0,0)+"/"+DoubleToString(0,0)+"/"+DoubleToString((int)(ExtBufferSeconds[I_INDEXER][1]/60),0);//Minutes
            if(MathRound((int)(ExtBufferSeconds[I_INDEXER][1]/60/60))<24)
               ShowSecondsUntil[I_INDEXER]=DoubleToString(0,0)+"/"+DoubleToString((int)(ExtBufferSeconds[I_INDEXER][1]/60/60),0)+"/"+DoubleToString((int)(ExtBufferSeconds[I_INDEXER][1]/60)%60,0);//Hours and Minutes
            if(MathRound((int)(ExtBufferSeconds[I_INDEXER][1]/60/60))>=24)
               ShowSecondsUntil[I_INDEXER]=DoubleToString((int)(ExtBufferSeconds[I_INDEXER][1]/60/60)/24,0)+"/"+DoubleToString((int)(ExtBufferSeconds[I_INDEXER][1]/60/60)%24,0)+"/"+DoubleToString((int)(ExtBufferSeconds[I_INDEXER][1]/60)%60,0);//Days and Hours and Minutes
         }
         else
            ShowSecondsUntil[I_INDEXER]="NONE";
      }
   }
//---------------------------------------------------------------------
//String money management
   if(MoneyManagement==true)
      MMstring="Auto";
   if(MoneyManagement==false)
      MMstring="Manual";
//---------------------------------------------------------------------
//Comment in chart
   if(ObjectFind("Text1")==-1)
      DisplayText("Text1",MQLInfoString(MQL_PROGRAM_NAME),TextFontSizeTitle,TextFontTypeTitle,clrGray,10,DistanceText[1]-6);
   if(ObjectFind("Text2")==-1)
      DisplayText("Text2","Time: "+TimeToString(CurrentTime)+"  (GMToffset: "+IntegerToString(GMT_OffsetHours)+")",TextFontSize,TextFontType,TextColor1,10,DistanceText[2]);
   if(ObjectFind("Text3")==-1)
      DisplayText("Text3","Money Management: "+MMstring+" || Lot: "+DoubleToString(CalcLots(1),2),TextFontSize,TextFontType,TextColor1,10,DistanceText[3]);
   if(ObjectFind("Text4")==-1)
      DisplayText("Text4","Strategy To Use: "+StrategyUse,TextFontSize,TextFontType,TextColor1,10,DistanceText[4]);
   if(ObjectFind("Text5")==-1)
      DisplayText("Text5","Event Impact Trade: "+ImpactTrade,TextFontSize,TextFontType,TextColor1,10,DistanceText[5]);
   if(ObjectFind("Text6")==-1)
      DisplayText("Text6","Start Trade Before Event: "+IntegerToString(_MinutesBeforeNewsStart)+" minutes",TextFontSize,TextFontType,TextColor1,10,DistanceText[6]);
   if(ObjectFind("Text7")==-1)
      DisplayText("Text7","Stop  Trade  After  Event: "+IntegerToString(_MinutesAfterNewsStop)+" minutes",TextFontSize,TextFontType,TextColor1,10,DistanceText[7]);
   if(ObjectFind("Text8")==-1)
      DisplayText("Text8","Currency Impact   TimeUntil  TimeSince",TextFontSize,TextFontType,TextColor4,10,DistanceText[8]);
//---------------------------------------------------------------------
//---EUR
   SetBuffers=1;
   if(ObjectFind("Text9")==-1)
      DisplayText("Text9","  EUR ",TextFontSize,TextFontType,TextColor3,10,DistanceText[9]);
   if(OpenSession[SetBuffers]==true) {
      if(_EUR_TradeInNewsRelease==Trade_In_News) {
         if(ObjectFind("Text10")==-1)
            DisplayText("Text10",ShowImpact[SetBuffers],TextFontSize,TextFontType,TextColor2,65,DistanceText[9]);
         if(ObjectFind("Text11")==-1)
            DisplayText("Text11",ShowSecondsUntil[SetBuffers],TextFontSize,TextFontType,TextColor2,125,DistanceText[9]);
         if(ObjectFind("Text12")==-1)
            DisplayText("Text12",ShowSecondsSince[SetBuffers],TextFontSize,TextFontType,TextColor2,190,DistanceText[9]);
      }
      else {
         if(ObjectFind("Text10")==-1)
            DisplayText("Text10","It's 'false'",TextFontSize,TextFontType,TextColor2,65,DistanceText[9]);
         if(ObjectFind("Text11")==-1)
            DisplayText("Text11","or not available",TextFontSize,TextFontType,TextColor2,120,DistanceText[9]);
         if(ObjectFind("Text12")==-1)
            DisplayText("Text12","     pair(s)",TextFontSize,TextFontType,TextColor2,190,DistanceText[9]);
      }
   }
   else {
      if(ObjectFind("Text10")==-1)
         DisplayText("Text10","Is out of",TextFontSize,TextFontType,TextColor2,65,DistanceText[9]);
      if(ObjectFind("Text11")==-1)
         DisplayText("Text11","session",TextFontSize,TextFontType,TextColor2,125,DistanceText[9]);
      if(ObjectFind("Text12")==-1)
         DisplayText("Text12","for now",TextFontSize,TextFontType,TextColor2,190,DistanceText[9]);
   }
//---------------------------------------------------------------------
//---GBP
   SetBuffers=2;
   if(ObjectFind("Text13")==-1)
      DisplayText("Text13","  GBP ",TextFontSize,TextFontType,TextColor3,10,DistanceText[10]);
   if(OpenSession[SetBuffers]==true) {
      if(_GBP_TradeInNewsRelease==Trade_In_News) {
         if(ObjectFind("Text14")==-1)
            DisplayText("Text14",ShowImpact[SetBuffers],TextFontSize,TextFontType,TextColor2,65,DistanceText[10]);
         if(ObjectFind("Text15")==-1)
            DisplayText("Text15",ShowSecondsUntil[SetBuffers],TextFontSize,TextFontType,TextColor2,125,DistanceText[10]);
         if(ObjectFind("Text16")==-1)
            DisplayText("Text16",ShowSecondsSince[SetBuffers],TextFontSize,TextFontType,TextColor2,190,DistanceText[10]);
      }
      else {
         if(ObjectFind("Text14")==-1)
            DisplayText("Text14","It's 'false'",TextFontSize,TextFontType,TextColor2,65,DistanceText[10]);
         if(ObjectFind("Text15")==-1)
            DisplayText("Text15","or not available",TextFontSize,TextFontType,TextColor2,120,DistanceText[10]);
         if(ObjectFind("Text16")==-1)
            DisplayText("Text16","     pair(s)",TextFontSize,TextFontType,TextColor2,190,DistanceText[10]);
      }
   }
   else {
      if(ObjectFind("Text14")==-1)
         DisplayText("Text14","Is out of",TextFontSize,TextFontType,TextColor2,65,DistanceText[10]);
      if(ObjectFind("Text15")==-1)
         DisplayText("Text15","session",TextFontSize,TextFontType,TextColor2,125,DistanceText[10]);
      if(ObjectFind("Text16")==-1)
         DisplayText("Text16","for now",TextFontSize,TextFontType,TextColor2,190,DistanceText[10]);
   }
//---------------------------------------------------------------------
//---AUD
   SetBuffers=3;
   if(ObjectFind("Text17")==-1)
      DisplayText("Text17","  AUD ",TextFontSize,TextFontType,TextColor3,10,DistanceText[11]);
   if(OpenSession[SetBuffers]==true) {
      if(_AUD_TradeInNewsRelease==Trade_In_News) {
         if(ObjectFind("Text18")==-1)
            DisplayText("Text18",ShowImpact[SetBuffers],TextFontSize,TextFontType,TextColor2,65,DistanceText[11]);
         if(ObjectFind("Text19")==-1)
            DisplayText("Text19",ShowSecondsUntil[SetBuffers],TextFontSize,TextFontType,TextColor2,125,DistanceText[11]);
         if(ObjectFind("Text20")==-1)
            DisplayText("Text20",ShowSecondsSince[SetBuffers],TextFontSize,TextFontType,TextColor2,190,DistanceText[11]);
      }
      else {
         if(ObjectFind("Text18")==-1)
            DisplayText("Text18","It's 'false'",TextFontSize,TextFontType,TextColor2,65,DistanceText[11]);
         if(ObjectFind("Text19")==-1)
            DisplayText("Text19","or not available",TextFontSize,TextFontType,TextColor2,120,DistanceText[11]);
         if(ObjectFind("Text20")==-1)
            DisplayText("Text20","     pair(s)",TextFontSize,TextFontType,TextColor2,190,DistanceText[11]);
      }
   }
   else {
      if(ObjectFind("Text18")==-1)
         DisplayText("Text18","Is out of",TextFontSize,TextFontType,TextColor2,65,DistanceText[11]);
      if(ObjectFind("Text19")==-1)
         DisplayText("Text19","session",TextFontSize,TextFontType,TextColor2,125,DistanceText[11]);
      if(ObjectFind("Text20")==-1)
         DisplayText("Text20","for now",TextFontSize,TextFontType,TextColor2,190,DistanceText[11]);
   }
//---------------------------------------------------------------------
//---NZD
   SetBuffers=4;
   if(ObjectFind("Text21")==-1)
      DisplayText("Text21","  NZD ",TextFontSize,TextFontType,TextColor3,10,DistanceText[12]);
   if(OpenSession[SetBuffers]==true) {
      if(_NZD_TradeInNewsRelease==Trade_In_News) {
         if(ObjectFind("Text22")==-1)
            DisplayText("Text22",ShowImpact[SetBuffers],TextFontSize,TextFontType,TextColor2,65,DistanceText[12]);
         if(ObjectFind("Text23")==-1)
            DisplayText("Text23",ShowSecondsUntil[SetBuffers],TextFontSize,TextFontType,TextColor2,125,DistanceText[12]);
         if(ObjectFind("Text24")==-1)
            DisplayText("Text24",ShowSecondsSince[SetBuffers],TextFontSize,TextFontType,TextColor2,190,DistanceText[12]);
      }
      else {
         if(ObjectFind("Text22")==-1)
            DisplayText("Text22","It's 'false'",TextFontSize,TextFontType,TextColor2,65,DistanceText[12]);
         if(ObjectFind("Text23")==-1)
            DisplayText("Text23","or not available",TextFontSize,TextFontType,TextColor2,120,DistanceText[12]);
         if(ObjectFind("Text24")==-1)
            DisplayText("Text24","     pair(s)",TextFontSize,TextFontType,TextColor2,190,DistanceText[12]);
      }
   }
   else {
      if(ObjectFind("Text22")==-1)
         DisplayText("Text22","Is out of",TextFontSize,TextFontType,TextColor2,65,DistanceText[12]);
      if(ObjectFind("Text23")==-1)
         DisplayText("Text23","session",TextFontSize,TextFontType,TextColor2,125,DistanceText[12]);
      if(ObjectFind("Text24")==-1)
         DisplayText("Text24","for now",TextFontSize,TextFontType,TextColor2,190,DistanceText[12]);
   }
//---------------------------------------------------------------------
//---USD
   SetBuffers=5;
   if(ObjectFind("Text25")==-1)
      DisplayText("Text25","  USD ",TextFontSize,TextFontType,TextColor3,10,DistanceText[13]);
   if(OpenSession[SetBuffers]==true) {
      if(_USD_TradeInNewsRelease==Trade_In_News) {
         if(ObjectFind("Text26")==-1)
            DisplayText("Text26",ShowImpact[SetBuffers],TextFontSize,TextFontType,TextColor2,65,DistanceText[13]);
         if(ObjectFind("Text27")==-1)
            DisplayText("Text27",ShowSecondsUntil[SetBuffers],TextFontSize,TextFontType,TextColor2,125,DistanceText[13]);
         if(ObjectFind("Text28")==-1)
            DisplayText("Text28",ShowSecondsSince[SetBuffers],TextFontSize,TextFontType,TextColor2,190,DistanceText[13]);
      }
      else {
         if(ObjectFind("Text26")==-1)
            DisplayText("Text26","It's 'false'",TextFontSize,TextFontType,TextColor2,65,DistanceText[13]);
         if(ObjectFind("Text27")==-1)
            DisplayText("Text27","or not available",TextFontSize,TextFontType,TextColor2,120,DistanceText[13]);
         if(ObjectFind("Text28")==-1)
            DisplayText("Text28","     pair(s)",TextFontSize,TextFontType,TextColor2,190,DistanceText[13]);
      }
   }
   else {
      if(ObjectFind("Text26")==-1)
         DisplayText("Text26","Is out of",TextFontSize,TextFontType,TextColor2,65,DistanceText[13]);
      if(ObjectFind("Text27")==-1)
         DisplayText("Text27","session",TextFontSize,TextFontType,TextColor2,125,DistanceText[13]);
      if(ObjectFind("Text28")==-1)
         DisplayText("Text28","for now",TextFontSize,TextFontType,TextColor2,190,DistanceText[13]);
   }
//---------------------------------------------------------------------
//---CAD
   SetBuffers=6;
   if(ObjectFind("Text29")==-1)
      DisplayText("Text29","  CAD ",TextFontSize,TextFontType,TextColor3,10,DistanceText[14]);
   if(OpenSession[SetBuffers]==true) {
      if(_CAD_TradeInNewsRelease==Trade_In_News) {
         if(ObjectFind("Text30")==-1)
            DisplayText("Text30",ShowImpact[SetBuffers],TextFontSize,TextFontType,TextColor2,65,DistanceText[14]);
         if(ObjectFind("Text31")==-1)
            DisplayText("Text31",ShowSecondsUntil[SetBuffers],TextFontSize,TextFontType,TextColor2,125,DistanceText[14]);
         if(ObjectFind("Text32")==-1)
            DisplayText("Text32",ShowSecondsSince[SetBuffers],TextFontSize,TextFontType,TextColor2,190,DistanceText[14]);
      }
      else {
         if(ObjectFind("Text30")==-1)
            DisplayText("Text30","It's 'false'",TextFontSize,TextFontType,TextColor2,65,DistanceText[14]);
         if(ObjectFind("Text31")==-1)
            DisplayText("Text31","or not available",TextFontSize,TextFontType,TextColor2,120,DistanceText[14]);
         if(ObjectFind("Text32")==-1)
            DisplayText("Text32","     pair(s)",TextFontSize,TextFontType,TextColor2,190,DistanceText[14]);
      }
   }
   else {
      if(ObjectFind("Text30")==-1)
         DisplayText("Text30","Is out of",TextFontSize,TextFontType,TextColor2,65,DistanceText[14]);
      if(ObjectFind("Text31")==-1)
         DisplayText("Text31","session",TextFontSize,TextFontType,TextColor2,125,DistanceText[14]);
      if(ObjectFind("Text32")==-1)
         DisplayText("Text32","for now",TextFontSize,TextFontType,TextColor2,190,DistanceText[14]);
   }
//---------------------------------------------------------------------
//---CHF
   SetBuffers=7;
   if(ObjectFind("Text33")==-1)
      DisplayText("Text33","  CHF ",TextFontSize,TextFontType,TextColor3,10,DistanceText[15]);
   if(OpenSession[SetBuffers]==true) {
      if(_CHF_TradeInNewsRelease==Trade_In_News) {
         if(ObjectFind("Text34")==-1)
            DisplayText("Text34",ShowImpact[SetBuffers],TextFontSize,TextFontType,TextColor2,65,DistanceText[15]);
         if(ObjectFind("Text35")==-1)
            DisplayText("Text35",ShowSecondsUntil[SetBuffers],TextFontSize,TextFontType,TextColor2,125,DistanceText[15]);
         if(ObjectFind("Text36")==-1)
            DisplayText("Text36",ShowSecondsSince[SetBuffers],TextFontSize,TextFontType,TextColor2,190,DistanceText[15]);
      }
      else {
         if(ObjectFind("Text34")==-1)
            DisplayText("Text34","It's 'false'",TextFontSize,TextFontType,TextColor2,65,DistanceText[15]);
         if(ObjectFind("Text35")==-1)
            DisplayText("Text35","or not available",TextFontSize,TextFontType,TextColor2,120,DistanceText[15]);
         if(ObjectFind("Text36")==-1)
            DisplayText("Text36","     pair(s)",TextFontSize,TextFontType,TextColor2,190,DistanceText[15]);
      }
   }
   else {
      if(ObjectFind("Text34")==-1)
         DisplayText("Text34","Is out of",TextFontSize,TextFontType,TextColor2,65,DistanceText[15]);
      if(ObjectFind("Text35")==-1)
         DisplayText("Text35","session",TextFontSize,TextFontType,TextColor2,125,DistanceText[15]);
      if(ObjectFind("Text36")==-1)
         DisplayText("Text36","for now",TextFontSize,TextFontType,TextColor2,190,DistanceText[15]);
   }
//---------------------------------------------------------------------
//---JPY
   SetBuffers=8;
   if(ObjectFind("Text37")==-1)
      DisplayText("Text37","  JPY ",TextFontSize,TextFontType,TextColor3,10,DistanceText[16]);
   if(OpenSession[SetBuffers]==true) {
      if(_JPY_TradeInNewsRelease==Trade_In_News) {
         if(ObjectFind("Text38")==-1)
            DisplayText("Text38",ShowImpact[SetBuffers],TextFontSize,TextFontType,TextColor2,65,DistanceText[16]);
         if(ObjectFind("Text39")==-1)
            DisplayText("Text39",ShowSecondsUntil[SetBuffers],TextFontSize,TextFontType,TextColor2,125,DistanceText[16]);
         if(ObjectFind("Text40")==-1)
            DisplayText("Text40",ShowSecondsSince[SetBuffers],TextFontSize,TextFontType,TextColor2,190,DistanceText[16]);
      }
      else {
         if(ObjectFind("Text38")==-1)
            DisplayText("Text38","It's 'false'",TextFontSize,TextFontType,TextColor2,65,DistanceText[16]);
         if(ObjectFind("Text39")==-1)
            DisplayText("Text39","or not available",TextFontSize,TextFontType,TextColor2,120,DistanceText[16]);
         if(ObjectFind("Text40")==-1)
            DisplayText("Text40","     pair(s)",TextFontSize,TextFontType,TextColor2,190,DistanceText[16]);
      }
   }
   else {
      if(ObjectFind("Text38")==-1)
         DisplayText("Text38","Is out of",TextFontSize,TextFontType,TextColor2,65,DistanceText[16]);
      if(ObjectFind("Text39")==-1)
         DisplayText("Text39","session",TextFontSize,TextFontType,TextColor2,125,DistanceText[16]);
      if(ObjectFind("Text40")==-1)
         DisplayText("Text40","for now",TextFontSize,TextFontType,TextColor2,190,DistanceText[16]);
   }
//---------------------------------------------------------------------
//---CNY
   SetBuffers=9;
   if(ObjectFind("Text41")==-1)
      DisplayText("Text41","  CNY ",TextFontSize,TextFontType,TextColor3,10,DistanceText[17]);
   if(OpenSession[SetBuffers]==true) {
      if(_CNY_TradeInNewsRelease==Trade_In_News) {
         if(ObjectFind("Text42")==-1)
            DisplayText("Text42",ShowImpact[SetBuffers],TextFontSize,TextFontType,TextColor2,65,DistanceText[17]);
         if(ObjectFind("Text43")==-1)
            DisplayText("Text43",ShowSecondsUntil[SetBuffers],TextFontSize,TextFontType,TextColor2,125,DistanceText[17]);
         if(ObjectFind("Text44")==-1)
            DisplayText("Text44",ShowSecondsSince[SetBuffers],TextFontSize,TextFontType,TextColor2,190,DistanceText[17]);
      }
      else {
         if(ObjectFind("Text42")==-1)
            DisplayText("Text42","It's 'false'",TextFontSize,TextFontType,TextColor2,65,DistanceText[17]);
         if(ObjectFind("Text43")==-1)
            DisplayText("Text43","or not available",TextFontSize,TextFontType,TextColor2,120,DistanceText[17]);
         if(ObjectFind("Text44")==-1)
            DisplayText("Text44","     pair(s)",TextFontSize,TextFontType,TextColor2,190,DistanceText[17]);
      }
   }
   else {
      if(ObjectFind("Text42")==-1)
         DisplayText("Text42","Is out of",TextFontSize,TextFontType,TextColor2,65,DistanceText[17]);
      if(ObjectFind("Text43")==-1)
         DisplayText("Text43","session",TextFontSize,TextFontType,TextColor2,125,DistanceText[17]);
      if(ObjectFind("Text44")==-1)
         DisplayText("Text44","for now",TextFontSize,TextFontType,TextColor2,190,DistanceText[17]);
   }
//---------------------------------------------------------------------
//---History
   if(ObjectFind("Text45")==-1)
      DisplayText("Text45","History Results: "+DoubleToString(HistoryProfitLoss,2)+"   ("+DoubleToString(HistoryTrades,0)+")",TextFontSize,TextFontType,TextColor1,10,DistanceText[18]);
//---Lines
   if(ObjectFind("Text46")==-1)
      DisplayText("Text46","_____________________________________",TextFontSize,TextFontType,clrGray,0,DistanceText[1]);
   if(ObjectFind("Text47")==-1)
      DisplayText("Text47","_____________________________________",TextFontSize,TextFontType,clrGray,0,DistanceText[2]);
   if(ObjectFind("Text48")==-1)
      DisplayText("Text48","_____________________________________",TextFontSize,TextFontType,clrGray,0,DistanceText[3]);
   if(ObjectFind("Text49")==-1)
      DisplayText("Text49","_____________________________________",TextFontSize,TextFontType,clrGray,0,DistanceText[4]);
   if(ObjectFind("Text50")==-1)
      DisplayText("Text50","_____________________________________",TextFontSize,TextFontType,clrGray,0,DistanceText[5]);
   if(ObjectFind("Text51")==-1)
      DisplayText("Text51","_____________________________________",TextFontSize,TextFontType,clrGray,0,DistanceText[7]);
   if(ObjectFind("Text52")==-1)
      DisplayText("Text52","_____________________________________",TextFontSize,TextFontType,clrGray,0,DistanceText[17]);
//---------------------------------------------------------------------
}
//====================================================================================================================================================//
//Analyzer trades
//====================================================================================================================================================//
void AnalyzerTrades()
{
//---------------------------------------------------------------------
//Set background
   for(I_INDEXER=0; I_INDEXER<34; I_INDEXER++) {
      color ColorLine1=ColorOfLine1;
      color ColorLine2=ColorOfLine2;
      //---
      if((I_INDEXER==0) || (I_INDEXER==4) || (I_INDEXER==8) || (I_INDEXER==12) || (I_INDEXER==16) || (I_INDEXER==20) || (I_INDEXER==24) || (I_INDEXER==28) || (I_INDEXER==32))
         ColorLine1=ColorLineTitles;
      //---Background1
      if(ObjectFind("BackgroundLine1"+IntegerToString(I_INDEXER))==-1)
         ChartBackground("BackgroundLine1"+IntegerToString(I_INDEXER),
                         ColorLine1,
                         EMPTY_VALUE,
                         true,
                         265,
                         2+(I_INDEXER*12*2),320,14);
      //---Background2
      if(ObjectFind("BackgroundLine2"+IntegerToString(I_INDEXER))==-1)
         ChartBackground("BackgroundLine2"+IntegerToString(I_INDEXER),ColorLine2,EMPTY_VALUE,true,265,14+(I_INDEXER*12*2),320,14);
   }
//---------------------------------------------------------------------
//Set currency titles
   string CurrencyInfo[10]= {"","EUR","GBP","AUD","NZD","USD","CAD","CHF","JPY","CNY"};
//---
   for(I_INDEXER=1; I_INDEXER<10; I_INDEXER++) {
      if(ObjectFind("Str"+IntegerToString(I_INDEXER))==-1)
         DisplayText("Str"+IntegerToString(I_INDEXER),"RESULTS   FOR   CURRENCY   "+CurrencyInfo[I_INDEXER],SizeFontsOfInfo,"Arial Black",ColorOfTitle,265,(12*8*(I_INDEXER-1)));
      //---
      ObjectDelete("Res"+IntegerToString(I_INDEXER));
      if(ObjectFind("Res"+IntegerToString(I_INDEXER))==-1)
         DisplayText("Res"+IntegerToString(I_INDEXER),"("+DoubleToString(ResultsCurrencies[I_INDEXER],2)+")",SizeFontsOfInfo,"Arial Black",ColorOfTitle,525,(12*8*(I_INDEXER-1)));
   }
//---------------------------------------------------------------------
//Set informations pairs'
   for(I_INDEXER=1; I_INDEXER<60; I_INDEXER++) {
      int SetPosition=I_INDEXER;
      if(SetPosition>=8)
         SetPosition+=1;
      if(SetPosition>=16)
         SetPosition+=1;
      if(SetPosition>=24)
         SetPosition+=1;
      if(SetPosition>=32)
         SetPosition+=1;
      if(SetPosition>=40)
         SetPosition+=1;
      if(SetPosition>=48)
         SetPosition+=1;
      if(SetPosition>=56)
         SetPosition+=1;
      if(SetPosition>=64)
         SetPosition+=1;
      //---
      if(ObjectFind("Comm1"+IntegerToString(I_INDEXER))==-1)
         DisplayText("Comm1"+IntegerToString(I_INDEXER),"Pair: "+Pair[I_INDEXER],SizeFontsOfInfo,"Arial",ColorOfInfo,265,(12*SetPosition));
      //---
      if(ObjectFind("Comm2"+IntegerToString(I_INDEXER))==-1)
         DisplayText("Comm2"+IntegerToString(I_INDEXER),"Orders: ",SizeFontsOfInfo,"Arial",ColorOfInfo,375,(12*SetPosition));
      //---
      if(ObjectFind("Comm3"+IntegerToString(I_INDEXER))==-1)
         DisplayText("Comm3"+IntegerToString(I_INDEXER),"Profit/Loss: ",SizeFontsOfInfo,"Arial",ColorOfInfo,455,(12*SetPosition));
      //---
      ObjectDelete("Comm4"+IntegerToString(I_INDEXER));
      if(ObjectFind("Comm4"+IntegerToString(I_INDEXER))==-1)
         DisplayText("Comm4"+IntegerToString(I_INDEXER),IntegerToString(TotalHistoryOrders[I_INDEXER]),SizeFontsOfInfo,"Arial",ColorOfInfo,422,(12*SetPosition));
      //---
      ObjectDelete("Comm5"+IntegerToString(I_INDEXER));
      if(ObjectFind("Comm5"+IntegerToString(I_INDEXER))==-1)
         DisplayText("Comm5"+IntegerToString(I_INDEXER),DoubleToString(TotalHistoryProfit[I_INDEXER],2),SizeFontsOfInfo,"Arial",ColorOfInfo,525,(12*SetPosition));
   }
//---------------------------------------------------------------------
}
//====================================================================================================================================================//
//Background for comments
//====================================================================================================================================================//
void ChartBackground(string StringName,color ImageColor,int TypeBorder,bool InBackGround,int Xposition,int Yposition,int Xsize,int Ysize)
{
//---------------------------------------------------------------------
   ObjectCreate(0,StringName,OBJ_RECTANGLE_LABEL,0,0,0,0,0);
   ObjectSetInteger(0,StringName,OBJPROP_XDISTANCE,Xposition);
   ObjectSetInteger(0,StringName,OBJPROP_YDISTANCE,Yposition);
   ObjectSetInteger(0,StringName,OBJPROP_XSIZE,Xsize);
   ObjectSetInteger(0,StringName,OBJPROP_YSIZE,Ysize);
   ObjectSetInteger(0,StringName,OBJPROP_BGCOLOR,ImageColor);
   ObjectSetInteger(0,StringName,OBJPROP_BORDER_TYPE,TypeBorder);
   ObjectSetInteger(0,StringName,OBJPROP_BORDER_COLOR,clrBlack);
   ObjectSetInteger(0,StringName,OBJPROP_BACK,InBackGround);
   ObjectSetInteger(0,StringName,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,StringName,OBJPROP_SELECTED,false);
   ObjectSetInteger(0,StringName,OBJPROP_HIDDEN,true);
   ObjectSetInteger(0,StringName,OBJPROP_ZORDER,0);
//---------------------------------------------------------------------
}
//====================================================================================================================================================//
//Orders signals
//====================================================================================================================================================//
void GetSignal()
{
//---------------------------------------------------------------------
//Reset values
   SetBuffers=0;
   CheckOrdersBaseNews=false;
   TimeToTrade_EUR=false;
   TimeToTrade_GBP=false;
   TimeToTrade_AUD=false;
   TimeToTrade_NZD=false;
   TimeToTrade_USD=false;
   TimeToTrade_CAD=false;
   TimeToTrade_CHF=false;
   TimeToTrade_JPY=false;
   TimeToTrade_CNY=false;
//---------------------------------------------------------------------
//Trade immediately from buttons
   if((_EUR_TradeInNewsRelease==Trade_From_Panel)&&(Open_EUR==true))
      TimeToTrade_EUR=true;
   if((_GBP_TradeInNewsRelease==Trade_From_Panel)&&(Open_GBP==true))
      TimeToTrade_GBP=true;
   if((_AUD_TradeInNewsRelease==Trade_From_Panel)&&(Open_AUD==true))
      TimeToTrade_AUD=true;
   if((_NZD_TradeInNewsRelease==Trade_From_Panel)&&(Open_NZD==true))
      TimeToTrade_NZD=true;
   if((_USD_TradeInNewsRelease==Trade_From_Panel)&&(Open_USD==true))
      TimeToTrade_USD=true;
   if((_CAD_TradeInNewsRelease==Trade_From_Panel)&&(Open_CAD==true))
      TimeToTrade_CAD=true;
   if((_CHF_TradeInNewsRelease==Trade_From_Panel)&&(Open_CHF==true))
      TimeToTrade_CHF=true;
   if((_JPY_TradeInNewsRelease==Trade_From_Panel)&&(Open_JPY==true))
      TimeToTrade_JPY=true;
   if((_CNY_TradeInNewsRelease==Trade_From_Panel)&&(Open_CNY==true))
      TimeToTrade_CNY=true;
//---------------------------------------------------------------------
//Call ReadNews() to make file
   if((((Minute()!=iPrevMinute) || (LoopTimes<2)) && (ModeReadNews==1)) || (ModeReadNews==0) || (StartOperations==false)) {
      if(LoopTimes<2) {
         LoopTimes++;
         ReadNews(0,"XXX");
      }
      //---------------------------------------------------------------------
      //Start check
      if(FileIsOk==true) {
         CheckOrdersBaseNews=true;
         //---------------------------------------------------------------------
         if(_EUR_TradeInNewsRelease==Trade_In_News) {
            SetBuffers=1;
            OpenSession[SetBuffers]=false;
            //---
            if(StringToTime(EUR_TimeStartSession)==StringToTime(EUR_TimeEndSession))
               OpenSession[SetBuffers]=true;
            if((StringToTime(EUR_TimeStartSession)<StringToTime(EUR_TimeEndSession))&&((CurrentTime>=StringToTime(EUR_TimeStartSession))&&(CurrentTime<StringToTime(EUR_TimeEndSession))))
               OpenSession[SetBuffers]=true;
            if((StringToTime(EUR_TimeStartSession)>StringToTime(EUR_TimeEndSession))&&((CurrentTime>=StringToTime(EUR_TimeStartSession))||(CurrentTime<StringToTime(EUR_TimeEndSession))))
               OpenSession[SetBuffers]=true;
            //---
            if(OpenSession[SetBuffers]==true) {
               ReadNews(SetBuffers,"EUR");
               SessionBeforeEvent[SetBuffers]=false;
               SecondsSinceNews_EUR=ExtBufferSeconds[SetBuffers][0];
               SecondsToNews_EUR=ExtBufferSeconds[SetBuffers][1];
               ImpactSinceNews_EUR=ExtBufferImpact[SetBuffers][0];
               ImpactToNews_EUR=ExtBufferImpact[SetBuffers][1];
               //---
               if(((ImpactToNews_EUR>=ImpactToTrade) && (SecondsToNews_EUR<=SecondsBeforeNewsStart)) || ((ImpactSinceNews_EUR>=ImpactToTrade) && (SecondsSinceNews_EUR<=SecondsAfterNewsStop)))
                  TimeToTrade_EUR=true;
               if((SecondsToNews_EUR==0) || (SecondsSinceNews_EUR==0))
                  TimeToTrade_EUR=true;
               if((TimeToTrade_EUR==true) && (ImpactToNews_EUR>=ImpactToTrade) && (SecondsToNews_EUR<=SecondsBeforeNewsStart))
                  SessionBeforeEvent[SetBuffers]=true;
            }
         }
         //---------------------------------------------------------------------
         if(_GBP_TradeInNewsRelease==Trade_In_News) {
            SetBuffers=2;
            OpenSession[SetBuffers]=false;
            //---
            if(StringToTime(GBP_TimeStartSession)==StringToTime(GBP_TimeEndSession))
               OpenSession[SetBuffers]=true;
            if((StringToTime(GBP_TimeStartSession)<StringToTime(GBP_TimeEndSession))&&((CurrentTime>=StringToTime(GBP_TimeStartSession))&&(CurrentTime<StringToTime(GBP_TimeEndSession))))
               OpenSession[SetBuffers]=true;
            if((StringToTime(GBP_TimeStartSession)>StringToTime(GBP_TimeEndSession))&&((CurrentTime>=StringToTime(GBP_TimeStartSession))||(CurrentTime<StringToTime(GBP_TimeEndSession))))
               OpenSession[SetBuffers]=true;
            //---
            if(OpenSession[SetBuffers]==true) {
               ReadNews(SetBuffers,"GBP");
               SessionBeforeEvent[SetBuffers]=false;
               SecondsSinceNews_GBP=ExtBufferSeconds[SetBuffers][0];
               SecondsToNews_GBP=ExtBufferSeconds[SetBuffers][1];
               ImpactSinceNews_GBP=ExtBufferImpact[SetBuffers][0];
               ImpactToNews_GBP=ExtBufferImpact[SetBuffers][1];
               //---
               if(((ImpactToNews_GBP>=ImpactToTrade) && (SecondsToNews_GBP<=SecondsBeforeNewsStart)) || ((ImpactSinceNews_GBP>=ImpactToTrade) && (SecondsSinceNews_GBP<=SecondsAfterNewsStop)))
                  TimeToTrade_GBP=true;
               if((SecondsToNews_GBP==0) || (SecondsSinceNews_GBP==0))
                  TimeToTrade_GBP=true;
               if((TimeToTrade_GBP==true) && (ImpactToNews_GBP>=ImpactToTrade) && (SecondsToNews_GBP<=SecondsBeforeNewsStart))
                  SessionBeforeEvent[SetBuffers]=true;
            }
         }
         //---------------------------------------------------------------------
         if(_AUD_TradeInNewsRelease==Trade_In_News) {
            SetBuffers=3;
            OpenSession[SetBuffers]=false;
            //---
            if(StringToTime(AUD_TimeStartSession)==StringToTime(AUD_TimeEndSession))
               OpenSession[SetBuffers]=true;
            if((StringToTime(AUD_TimeStartSession)<StringToTime(AUD_TimeEndSession))&&((CurrentTime>=StringToTime(AUD_TimeStartSession))&&(CurrentTime<StringToTime(AUD_TimeEndSession))))
               OpenSession[SetBuffers]=true;
            if((StringToTime(AUD_TimeStartSession)>StringToTime(AUD_TimeEndSession))&&((CurrentTime>=StringToTime(AUD_TimeStartSession))||(CurrentTime<StringToTime(AUD_TimeEndSession))))
               OpenSession[SetBuffers]=true;
            //---
            if(OpenSession[SetBuffers]==true) {
               ReadNews(SetBuffers,"AUD");
               SessionBeforeEvent[SetBuffers]=false;
               SecondsSinceNews_AUD=ExtBufferSeconds[SetBuffers][0];
               SecondsToNews_AUD=ExtBufferSeconds[SetBuffers][1];
               ImpactSinceNews_AUD=ExtBufferImpact[SetBuffers][0];
               ImpactToNews_AUD=ExtBufferImpact[SetBuffers][1];
               //---
               if(((ImpactToNews_AUD>=ImpactToTrade) && (SecondsToNews_AUD<=SecondsBeforeNewsStart)) || ((ImpactSinceNews_AUD>=ImpactToTrade) && (SecondsSinceNews_AUD<=SecondsAfterNewsStop)))
                  TimeToTrade_AUD=true;
               if((SecondsToNews_AUD==0) || (SecondsSinceNews_AUD==0))
                  TimeToTrade_AUD=true;
               if((TimeToTrade_AUD==true) && (ImpactToNews_AUD>=ImpactToTrade) && (SecondsToNews_AUD<=SecondsBeforeNewsStart))
                  SessionBeforeEvent[SetBuffers]=true;
            }
         }
         //---------------------------------------------------------------------
         if(_NZD_TradeInNewsRelease==Trade_In_News) {
            SetBuffers=4;
            OpenSession[SetBuffers]=false;
            //---
            if(StringToTime(NZD_TimeStartSession)==StringToTime(NZD_TimeEndSession))
               OpenSession[SetBuffers]=true;
            if((StringToTime(NZD_TimeStartSession)<StringToTime(NZD_TimeEndSession))&&((CurrentTime>=StringToTime(NZD_TimeStartSession))&&(CurrentTime<StringToTime(NZD_TimeEndSession))))
               OpenSession[SetBuffers]=true;
            if((StringToTime(NZD_TimeStartSession)>StringToTime(NZD_TimeEndSession))&&((CurrentTime>=StringToTime(NZD_TimeStartSession))||(CurrentTime<StringToTime(NZD_TimeEndSession))))
               OpenSession[SetBuffers]=true;
            //---
            if(OpenSession[SetBuffers]==true) {
               ReadNews(SetBuffers,"NZD");
               SessionBeforeEvent[SetBuffers]=false;
               SecondsSinceNews_NZD=ExtBufferSeconds[SetBuffers][0];
               SecondsToNews_NZD=ExtBufferSeconds[SetBuffers][1];
               ImpactSinceNews_NZD=ExtBufferImpact[SetBuffers][0];
               ImpactToNews_NZD=ExtBufferImpact[SetBuffers][1];
               //---
               if(((ImpactToNews_NZD>=ImpactToTrade) && (SecondsToNews_NZD<=SecondsBeforeNewsStart)) || ((ImpactSinceNews_NZD>=ImpactToTrade) && (SecondsSinceNews_NZD<=SecondsAfterNewsStop)))
                  TimeToTrade_NZD=true;
               if((SecondsToNews_NZD==0) || (SecondsSinceNews_NZD==0))
                  TimeToTrade_NZD=true;
               if((TimeToTrade_NZD==true) && (ImpactToNews_NZD>=ImpactToTrade) && (SecondsToNews_NZD<=SecondsBeforeNewsStart))
                  SessionBeforeEvent[SetBuffers]=true;
            }
         }
         //---------------------------------------------------------------------
         if(_USD_TradeInNewsRelease==Trade_In_News) {
            SetBuffers=5;
            OpenSession[SetBuffers]=false;
            //---
            if(StringToTime(USD_TimeStartSession)==StringToTime(USD_TimeEndSession))
               OpenSession[SetBuffers]=true;
            if((StringToTime(USD_TimeStartSession)<StringToTime(USD_TimeEndSession))&&((CurrentTime>=StringToTime(USD_TimeStartSession))&&(CurrentTime<StringToTime(USD_TimeEndSession))))
               OpenSession[SetBuffers]=true;
            if((StringToTime(USD_TimeStartSession)>StringToTime(USD_TimeEndSession))&&((CurrentTime>=StringToTime(USD_TimeStartSession))||(CurrentTime<StringToTime(USD_TimeEndSession))))
               OpenSession[SetBuffers]=true;
            //---
            if(OpenSession[SetBuffers]==true) {
               ReadNews(SetBuffers,"USD");
               SessionBeforeEvent[SetBuffers]=false;
               SecondsSinceNews_USD=ExtBufferSeconds[SetBuffers][0];
               SecondsToNews_USD=ExtBufferSeconds[SetBuffers][1];
               ImpactSinceNews_USD=ExtBufferImpact[SetBuffers][0];
               ImpactToNews_USD=ExtBufferImpact[SetBuffers][1];
               //---
               if(((ImpactToNews_USD>=ImpactToTrade) && (SecondsToNews_USD<=SecondsBeforeNewsStart)) || ((ImpactSinceNews_USD>=ImpactToTrade) && (SecondsSinceNews_USD<=SecondsAfterNewsStop)))
                  TimeToTrade_USD=true;
               if((SecondsToNews_USD==0) || (SecondsSinceNews_USD==0))
                  TimeToTrade_USD=true;
               if((TimeToTrade_USD==true) && (ImpactToNews_USD>=ImpactToTrade) && (SecondsToNews_USD<=SecondsBeforeNewsStart))
                  SessionBeforeEvent[SetBuffers]=true;
            }
         }
         //---------------------------------------------------------------------
         if(_CAD_TradeInNewsRelease==Trade_In_News) {
            SetBuffers=6;
            OpenSession[SetBuffers]=false;
            //---
            if(StringToTime(CAD_TimeStartSession)==StringToTime(CAD_TimeEndSession))
               OpenSession[SetBuffers]=true;
            if((StringToTime(CAD_TimeStartSession)<StringToTime(CAD_TimeEndSession))&&((CurrentTime>=StringToTime(CAD_TimeStartSession))&&(CurrentTime<StringToTime(CAD_TimeEndSession))))
               OpenSession[SetBuffers]=true;
            if((StringToTime(CAD_TimeStartSession)>StringToTime(CAD_TimeEndSession))&&((CurrentTime>=StringToTime(CAD_TimeStartSession))||(CurrentTime<StringToTime(CAD_TimeEndSession))))
               OpenSession[SetBuffers]=true;
            //---
            if(OpenSession[SetBuffers]==true) {
               ReadNews(SetBuffers,"CAD");
               SessionBeforeEvent[SetBuffers]=false;
               SecondsSinceNews_CAD=ExtBufferSeconds[SetBuffers][0];
               SecondsToNews_CAD=ExtBufferSeconds[SetBuffers][1];
               ImpactSinceNews_CAD=ExtBufferImpact[SetBuffers][0];
               ImpactToNews_CAD=ExtBufferImpact[SetBuffers][1];
               //---
               if(((ImpactToNews_CAD>=ImpactToTrade) && (SecondsToNews_CAD<=SecondsBeforeNewsStart)) || ((ImpactSinceNews_CAD>=ImpactToTrade) && (SecondsSinceNews_CAD<=SecondsAfterNewsStop)))
                  TimeToTrade_CAD=true;
               if((SecondsToNews_CAD==0) || (SecondsSinceNews_CAD==0))
                  TimeToTrade_CAD=true;
               if((TimeToTrade_CAD==true) && (ImpactToNews_CAD>=ImpactToTrade) && (SecondsToNews_CAD<=SecondsBeforeNewsStart))
                  SessionBeforeEvent[SetBuffers]=true;
            }
         }
         //---------------------------------------------------------------------
         if(_CHF_TradeInNewsRelease==Trade_In_News) {
            SetBuffers=7;
            OpenSession[SetBuffers]=false;
            //---
            if(StringToTime(CHF_TimeStartSession)==StringToTime(CHF_TimeEndSession))
               OpenSession[SetBuffers]=true;
            if((StringToTime(CHF_TimeStartSession)<StringToTime(CHF_TimeEndSession))&&((CurrentTime>=StringToTime(CHF_TimeStartSession))&&(CurrentTime<StringToTime(CHF_TimeEndSession))))
               OpenSession[SetBuffers]=true;
            if((StringToTime(CHF_TimeStartSession)>StringToTime(CHF_TimeEndSession))&&((CurrentTime>=StringToTime(CHF_TimeStartSession))||(CurrentTime<StringToTime(CHF_TimeEndSession))))
               OpenSession[SetBuffers]=true;
            //---
            if(OpenSession[SetBuffers]==true) {
               ReadNews(SetBuffers,"CHF");
               SessionBeforeEvent[SetBuffers]=false;
               SecondsSinceNews_CHF=ExtBufferSeconds[SetBuffers][0];
               SecondsToNews_CHF=ExtBufferSeconds[SetBuffers][1];
               ImpactSinceNews_CHF=ExtBufferImpact[SetBuffers][0];
               ImpactToNews_CHF=ExtBufferImpact[SetBuffers][1];
               //---
               if(((ImpactToNews_CHF>=ImpactToTrade) && (SecondsToNews_CHF<=SecondsBeforeNewsStart)) || ((ImpactSinceNews_CHF>=ImpactToTrade) && (SecondsSinceNews_CHF<=SecondsAfterNewsStop)))
                  TimeToTrade_CHF=true;
               if((SecondsToNews_CHF==0) || (SecondsSinceNews_CHF==0))
                  TimeToTrade_CHF=true;
               if((TimeToTrade_CHF==true) && (ImpactToNews_CHF>=ImpactToTrade) && (SecondsToNews_CHF<=SecondsBeforeNewsStart))
                  SessionBeforeEvent[SetBuffers]=true;
            }
         }
         //---------------------------------------------------------------------
         if(_JPY_TradeInNewsRelease==Trade_In_News) {
            SetBuffers=8;
            OpenSession[SetBuffers]=false;
            //---
            if(StringToTime(JPY_TimeStartSession)==StringToTime(JPY_TimeEndSession))
               OpenSession[SetBuffers]=true;
            if((StringToTime(JPY_TimeStartSession)<StringToTime(JPY_TimeEndSession))&&((CurrentTime>=StringToTime(JPY_TimeStartSession))&&(CurrentTime<StringToTime(JPY_TimeEndSession))))
               OpenSession[SetBuffers]=true;
            if((StringToTime(JPY_TimeStartSession)>StringToTime(JPY_TimeEndSession))&&((CurrentTime>=StringToTime(JPY_TimeStartSession))||(CurrentTime<StringToTime(JPY_TimeEndSession))))
               OpenSession[SetBuffers]=true;
            //---
            if(OpenSession[SetBuffers]==true) {
               ReadNews(SetBuffers,"JPY");
               SessionBeforeEvent[SetBuffers]=false;
               SecondsSinceNews_JPY=ExtBufferSeconds[SetBuffers][0];
               SecondsToNews_JPY=ExtBufferSeconds[SetBuffers][1];
               ImpactSinceNews_JPY=ExtBufferImpact[SetBuffers][0];
               ImpactToNews_JPY=ExtBufferImpact[SetBuffers][1];
               //---
               if(((ImpactToNews_JPY>=ImpactToTrade) && (SecondsToNews_JPY<=SecondsBeforeNewsStart)) || ((ImpactSinceNews_JPY>=ImpactToTrade) && (SecondsSinceNews_JPY<=SecondsAfterNewsStop)))
                  TimeToTrade_JPY=true;
               if((SecondsToNews_JPY==0) || (SecondsSinceNews_JPY==0))
                  TimeToTrade_JPY=true;
               if((TimeToTrade_JPY==true) && (ImpactToNews_JPY>=ImpactToTrade) && (SecondsToNews_JPY<=SecondsBeforeNewsStart))
                  SessionBeforeEvent[SetBuffers]=true;
            }
         }
         //---------------------------------------------------------------------
         if(_CNY_TradeInNewsRelease==Trade_In_News) {
            SetBuffers=9;
            OpenSession[SetBuffers]=false;
            //---
            if(StringToTime(CNY_TimeStartSession)==StringToTime(CNY_TimeEndSession))
               OpenSession[SetBuffers]=true;
            if((StringToTime(CNY_TimeStartSession)<StringToTime(CNY_TimeEndSession))&&((CurrentTime>=StringToTime(CNY_TimeStartSession))&&(CurrentTime<StringToTime(CNY_TimeEndSession))))
               OpenSession[SetBuffers]=true;
            if((StringToTime(CNY_TimeStartSession)>StringToTime(CNY_TimeEndSession))&&((CurrentTime>=StringToTime(CNY_TimeStartSession))||(CurrentTime<StringToTime(CNY_TimeEndSession))))
               OpenSession[SetBuffers]=true;
            //---
            if(OpenSession[SetBuffers]==true) {
               ReadNews(SetBuffers,"CNY");
               SessionBeforeEvent[SetBuffers]=false;
               SecondsSinceNews_CNY=ExtBufferSeconds[SetBuffers][0];
               SecondsToNews_CNY=ExtBufferSeconds[SetBuffers][1];
               ImpactSinceNews_CNY=ExtBufferImpact[SetBuffers][0];
               ImpactToNews_CNY=ExtBufferImpact[SetBuffers][1];
               //---
               if(((ImpactToNews_CNY>=ImpactToTrade) && (SecondsToNews_CNY<=SecondsBeforeNewsStart)) || ((ImpactSinceNews_CNY>=ImpactToTrade) && (SecondsSinceNews_CNY<=SecondsAfterNewsStop)))
                  TimeToTrade_CNY=true;
               if((SecondsToNews_CNY==0) || (SecondsSinceNews_CNY==0))
                  TimeToTrade_CNY=true;
               if((TimeToTrade_CNY==true) && (ImpactToNews_CNY>=ImpactToTrade) && (SecondsToNews_CNY<=SecondsBeforeNewsStart))
                  SessionBeforeEvent[SetBuffers]=true;
            }
         }
         //---------------------------------------------------------------------
      }
      iPrevMinute=Minute();
   }
//---------------------------------------------------------------------
}
//====================================================================================================================================================//
//Read file
//====================================================================================================================================================//
void ReadNews(int CountrySelect,string CountryCheck)
{

   Print("country select: "+CountrySelect);
   Print("country check: "+CountryCheck);

 //---------------------------------------------------------------------
   string Cookie=NULL,Headers;
   char Post[],Result[];
 
   string ImpactLastNews="";
   datetime NewsTime;
   int NextEvent;
   int NewsIDx=0;
   ulong SizeOfFile=0;
   ulong SizeOfData=0;
   string MyEvent;
   int TimeOut=5000;
   bool SkipeEvent;
   bool ReportAllForEUR=false;
   bool ReportAllForGBP=false;
   bool ReportAllForAUD=false;
   bool ReportAllForNZD=false;
   bool ReportAllForUSD=false;
   bool ReportAllForCAD=false;
   bool ReportAllForCHF=false;
   bool ReportAllForJPY=false;
   bool ReportAllForCNY=false;
   bool IncludeLow=false;
   bool IncludeMedium=false;
   bool IncludeHigh=false;
 //---------------------------------------------------------------------
 //Set report country
   if(CountrySelect==1)
      ReportAllForEUR=true;
   if(CountrySelect==2)
      ReportAllForGBP=true;
   if(CountrySelect==3)
      ReportAllForAUD=true;
   if(CountrySelect==4)
      ReportAllForNZD=true;
   if(CountrySelect==5)
      ReportAllForUSD=true;
   if(CountrySelect==6)
      ReportAllForCAD=true;
   if(CountrySelect==7)
      ReportAllForCHF=true;
   if(CountrySelect==8)
      ReportAllForJPY=true;
   if(CountrySelect==9)
      ReportAllForCNY=true;
 //---------------------------------------------------------------------
 //Set report impact
   if(ImpactToTrade==Low_Medium_High) {
      IncludeLow=true;
      IncludeMedium=true;
      IncludeHigh=true;
   }
   if(ImpactToTrade==Medium_High) {
      IncludeMedium=true;
      IncludeHigh=true;
   }
   if(ImpactToTrade==2) {
      IncludeHigh=true;
   }
    //---------------------------------------------------------------------
   //NEW
   string cookie=NULL,referer=NULL,headersInv, headers;char post[],result[];
   headersInv = "Referer: https://www.investing.com/economic-calendar/\r\n""User-Agent: Mozilla/5.0 (iPhone; CPU iPhone OS 16_3_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.3 Mobile/15E148 Safari/604.1\r\n" ;
   //string google_url="https://sslecal2.investing.com?columns=exc_currency,exc_importance&importance=1,2,3&calType=week&timeZone=15&lang=1";
   //string google_short_url="https://sslecal2.investing.com";
   string sUrl="https://nfs.faireconomy.media/ff_calendar_thisweek.xml";
   ResetLastError();
   int timeout=5000;
    //NEW \\
   int res = WebRequest("GET",
                        sUrl,
                        cookie,
                        referer,
                        timeout,
                        post,
                        sizeof(post),
                        result,
                        headersInv
                        );

   PrintFormat("Getting file from: "+sUrl);
   int ierror=GetLastError();
   
   
   
   if(res==-1) {
      Print("Error in WebRequest. Error code  =",GetLastError());
      if(ArraySize(result)<=0) {
         //int er=GetLastError();
 
 
         if(ierror==4060)
            MessageBox("Please add the address '"+"https://nfs.faireconomy.media/"
                       +"' in the list of allowed URLs in the 'Advisers' tab "
                       ,"ERROR_TXT ",MB_ICONINFORMATION);
         return ;
      }
      Sleep(5000);
   }
   else {
      if(res==200) { //--- Successful download
         PrintFormat("The file has been successfully downloaded, File size %d byte.",ArraySize(result));
         //PrintFormat("Server headers: %s",headers);
         string info = CharArrayToString(result,0,WHOLE_ARRAY,CP_UTF8);
         int start_pos = StringFind(info,"<weeklyevents>",0);
         int finish_pos = StringFind(info,"</weeklyevents>",0);
         info = StringSubstr(info,start_pos,finish_pos-start_pos);
         for(int i=0; i<500; i++) {
            news_events[i].currency = "";
            news_events[i].event_title = "";
            news_events[i].event_time = 0;
            news_events[i].event_impact = "";
         }
         if(StringFind(info,"No Events Scheduled") != -1) {
            event_count =0;
         }
         else //    we have events to be processed
         {
          //-----METHOD #1 LOOP THROUGH
            int c =0;
            while(StringFind(info,"<event>") != -1) {
               int start_event = StringFind(info,"<event>",0);
               int finish_event = StringFind(info,"</event>",start_event);
               int curr_start = StringFind(info,"<country>",start_event)+9;
               int curr_finish = StringFind(info,"</country>",start_event);
               int title_start = StringFind(info,"<title>",start_event)+7;
               int title_finish = StringFind(info,"</title>",start_event);
               int date_start = StringFind(info,"<date><![CDATA[",start_event)+15;
               int date_finish = StringFind(info, "]]></date>",start_event);
               int time_start = StringFind(info, "<time><![CDATA[",start_event)+15;
               int time_finish = StringFind(info,"]]></time>",start_event);
               int impact_start = StringFind(info,"<impact><![CDATA[",start_event)+17;
               int impact_finish = StringFind(info,"]]></impact>",start_event);
               string ev_curr = StringSubstr(info,curr_start,curr_finish-curr_start);
               string ev_title = StringSubstr(info,title_start,title_finish-title_start);
               string ev_date = StringSubstr(info,date_start,date_finish-date_start);
               string ev_time = StringSubstr(info,time_start,time_finish-time_start);
               string ev_impact = StringSubstr(info,impact_start,impact_finish-impact_start);
               info = StringSubstr(info,finish_event+8);
               if(CurrencySelected(ev_curr) && TitleSelected(ev_title) && ImpactSelected(ev_impact)) {
                  news_events[c].currency = ev_curr;
                  news_events[c].event_title = ev_title;
                  news_events[c].event_time = StringToTime(MakeDateTime(ev_date,ev_time));
                  news_events[c].event_impact = ev_impact;
                  Print(news_events[c].currency+" "+(string)news_events[c].event_time);
                  c++;
               }
            }
            event_count = c;
          //-----METHOD #2
            //Init the buffer array to zero just in case
            ArrayInitialize(ExtMapBuffer0,0);
            tmpMins=10080;//(a hole week)
            BoEvent=0;
            //Get events
            while(true) 
            {
               BoEvent=StringFind(info,"<event>",BoEvent);
               if(BoEvent==-1)
                  break;
               //---
               BoEvent+=7;
               NextEvent=StringFind(info,"</event>",BoEvent);
               if(NextEvent==-1)
                  break;
               //---
               MyEvent=StringSubstr(info,BoEvent,NextEvent-BoEvent);
               BoEvent=NextEvent;
               //---
               BeginWeek=0;
               SkipeEvent=false;
               //---
               for(int i=0; i<7; i++) {
                  mainData[NewsIDx][i]="";
                  NextEvent=StringFind(MyEvent,sTags[i],BeginWeek);
                  //---------------------------------------------------------------------
                  //Within this event,if tag not found, then it must be missing; skip it
                  if(NextEvent==-1)
                     continue;
                  else {
                     //---------------------------------------------------------------------
                     //We must have found the sTag okay...
                     BeginWeek=NextEvent+StringLen(sTags[i]);//Advance past the start tag
                     EndWeek=StringFind(MyEvent,eTags[i],BeginWeek);//Find start of end tag
                     //---------------------------------------------------------------------
                     //Get data between start and end tag
                     if((EndWeek>BeginWeek)&&(EndWeek!=-1)) {
                        mainData[NewsIDx][i]=StringSubstr(MyEvent,BeginWeek,EndWeek-BeginWeek);
                     }
                  }
               }//for loop
               //---------------------------------------------------------------------
            //Set skip switch
               if((CountryCheck!=mainData[NewsIDx][COUNTRY]) &&
                     ((!ReportAllForEUR)||(mainData[NewsIDx][COUNTRY]!="EUR"))&&
                     ((!ReportAllForGBP)||(mainData[NewsIDx][COUNTRY]!="GBP"))&&
                     ((!ReportAllForAUD)||(mainData[NewsIDx][COUNTRY]!="AUD"))&&
                     ((!ReportAllForNZD)||(mainData[NewsIDx][COUNTRY]!="NZD"))&&
                     ((!ReportAllForUSD)||(mainData[NewsIDx][COUNTRY]!="USD"))&&
                     ((!ReportAllForCAD)||(mainData[NewsIDx][COUNTRY]!="CAD"))&&
                     ((!ReportAllForCHF)||(mainData[NewsIDx][COUNTRY]!="CHF"))&&
                     ((!ReportAllForJPY)||(mainData[NewsIDx][COUNTRY]!="JPY"))&&
                     ((!ReportAllForCNY)||(mainData[NewsIDx][COUNTRY]!="CNY")))
                  SkipeEvent=true;
               //---------------------------------------------------------------------
               if((!IncludeLow)&&(mainData[NewsIDx][IMPACT]=="Low"))
                  SkipeEvent=true;
               if((!IncludeMedium)&&(mainData[NewsIDx][IMPACT]=="Medium"))
                  SkipeEvent=true;
               if((!IncludeHigh)&&(mainData[NewsIDx][IMPACT]=="High"))
                  SkipeEvent=true;
               if((mainData[NewsIDx][IMPACT]=="Holiday")||(mainData[NewsIDx][IMPACT]=="holiday"))
                  SkipeEvent=true;
               if((mainData[NewsIDx][TIME]=="All Day")||(mainData[NewsIDx][TIME]=="Tentative")||(mainData[NewsIDx][TIME]==""))
                  SkipeEvent=true;
               if((!IncludeSpeaks)&&((StringFind(mainData[NewsIDx][TITLE],"speaks")!=-1)||(StringFind(mainData[NewsIDx][TITLE],"Speaks")!=-1)))
                  SkipeEvent=true;
               //---------------------------------------------------------------------
               //Get unskip
               if(!SkipeEvent) {
                  //Get impact
                  ImpactLastNews=mainData[NewsIDx][IMPACT];
                  //First, convert the announcement time to seconds (in GMT)
                  NewsTime=StringToTime(MakeDateTime(mainData[NewsIDx][DATE],mainData[NewsIDx][TIME]));
                  //Now calculate the Seconds until this announcement (may be negative)
                  minsTillNews=NewsTime-CurrentTime;
                  if((minsTillNews<0)||(MathAbs(tmpMins)>minsTillNews))
                     tmpMins=minsTillNews;
                  ExtMapBuffer0[CountrySelect][NewsIDx]=(int)minsTillNews;
                  NewsIDx++;
               }
            }//while loop
            //---------------------------------------------------------------------
            //Reset buffers
            ExtBufferSeconds[CountrySelect][0]=-9999;
            ExtBufferSeconds[CountrySelect][1]=9999;
            ExtBufferImpact[CountrySelect][0]=-1;
            ExtBufferImpact[CountrySelect][1]=-1;
            //---------------------------------------------------------------------
            //Set buffers
            for(int i=0; i<NewsIDx; i++) {
               //---------------------------------------------------------------------
               //Seconds UNTIL
               if((ExtMapBuffer0[CountrySelect][i]>=0)&&(mainData[i][COUNTRY]==CountryCheck)) {
                  if(ExtBufferSeconds[CountrySelect][1]==9999) {
                     ExtBufferSeconds[CountrySelect][1]=ExtMapBuffer0[CountrySelect][i];
                     ExtBufferImpact[CountrySelect][1]=ImpactToNumber(mainData[i][IMPACT]);
                  }
               }
               //---------------------------------------------------------------------
               //Seconds SINCE
               if((ExtMapBuffer0[CountrySelect][i]<=0)&&(mainData[i][COUNTRY]==CountryCheck)) {
                  //if(ExtBufferSeconds[CountrySelect][0]==-9999)
                  //{
                  ExtBufferSeconds[CountrySelect][0]=MathAbs(ExtMapBuffer0[CountrySelect][i]);
                  ExtBufferImpact[CountrySelect][0]=ImpactToNumber(mainData[i][IMPACT]);
                  //}
               }
            }//for loop

            Print("Last update time: ",TimeCurrent());
            GlobalVariableSet("LastUpdateTime: ",TimeCurrent());
         }
      }//(res==200)//--- Successful download
      else 
      {
         PrintFormat("Downloading '%s' failed, error code %d",sUrl,res);
      }
   }//outer webreq IF ELSE check

}//end





//====================================================================================================================================================//
//Convert impact
//====================================================================================================================================================//
int ImpactToNumber(string Impact)
{
//---------------------------------------------------------------------
   if(Impact=="Low")
      return(0);
   if(Impact=="Medium")
      return(1);
   if(Impact=="High")
      return(2);
   else
      return(-1);
//---------------------------------------------------------------------
}



//====================================================================================================================================================//
//Convert time
//====================================================================================================================================================//
string MakeDateTime(string StrDate,string StrTime)
{
//---------------------------------------------------------------------
   int Dash_1=StringFind(StrDate,"-");
   int Dash_2=StringFind(StrDate,"-",Dash_1+1);
   string StrMonth=StringSubstr(StrDate,0,2);
   string StrDay=StringSubstr(StrDate,3,2);
   string StrYear=StringSubstr(StrDate,6,4);
   int nTimeColonPos=StringFind(StrTime,":");
   string StrHour=StringSubstr(StrTime,0,nTimeColonPos);
   string StrMinute=StringSubstr(StrTime,nTimeColonPos+1,2);
   string StrAM_PM=StringSubstr(StrTime,StringLen(StrTime)-2);
   string StrHourPad="";
   long Hour24=StringToInteger(StrHour); //todo:   was in, but changed to long becuase to stringtointeger returns long
//---------------------------------------------------------------------
   if(((StrAM_PM=="pm") || (StrAM_PM=="PM")) && (Hour24!=12))
      Hour24+=12;
//---
   if(((StrAM_PM=="am") || (StrAM_PM=="AM")) && (Hour24==12))
      Hour24=0;
//---
   if(Hour24<10)
      StrHourPad="0";
//---
   return((string)StringConcatenate(StrYear,".",StrMonth,".",StrDay," ",StrHourPad,(string)Hour24,":",StrMinute));
//---------------------------------------------------------------------
}
//====================================================================================================================================================//
//End code
//====================================================================================================================================================//

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsTradeAllowed()
{
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED)) {
      Alert("Check if automated trading is allowed in the terminal settings!");
      return(false);
   }
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED)) {
      Alert("Check if automated trading is allowed in the terminal settings!");
      return(false);
   }
   else {
      if(!MQLInfoInteger(MQL_TRADE_ALLOWED)) {
         Alert("Automated trading is forbidden in the program settings for ",__FILE__);
         return(false);
      }
   }
   if(!AccountInfoInteger(ACCOUNT_TRADE_EXPERT)) {
      Alert("Automated trading is forbidden for the account ",AccountInfoInteger(ACCOUNT_LOGIN),
            " at the trade server side");
      return(false);
   }
   if(!AccountInfoInteger(ACCOUNT_TRADE_ALLOWED)) {
      Comment("Trading is forbidden for the account ",AccountInfoInteger(ACCOUNT_LOGIN),
              ".\n Perhaps an investor password has been used to connect to the trading account.",
              "\n Check the terminal journal for the following entry:",
              "\n\'",AccountInfoInteger(ACCOUNT_LOGIN),"\': trading has been disabled - investor mode.");
      return(false);
   }
//---
   return(true);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int Month()
{
   MqlDateTime tm;
   TimeCurrent(tm);
   return(tm.mon);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsTesting()
{
   return (bool)MQL5InfoInteger(MQL5_TESTING);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsVisualMode()
{
   return (bool)MQL5InfoInteger(MQL5_VISUAL_MODE);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string TerminalCompany()
{
   return TerminalInfoString(TERMINAL_COMPANY);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string TerminalName()
{
   return TerminalInfoString(TERMINAL_NAME);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string TerminalPath()
{
   return TerminalInfoString(TERMINAL_PATH);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsExpertEnabled()
{
   return (bool)AccountInfoInteger(ACCOUNT_TRADE_EXPERT);
}
string  sybmols_list;
bool CurrencySelected(string curr)
  {
   if(StringFind(sybmols_list,curr) != -1)
      return true;
   return false;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsConnected()
{
   return (bool)TerminalInfoInteger(TERMINAL_CONNECTED);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsOptimization()
{
   return (bool)MQL5InfoInteger(MQL5_OPTIMIZATION);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int Minute()
{
   MqlDateTime tm;
   TimeCurrent(tm);
   return(tm.min);
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int Day()
{
   MqlDateTime tm;
   TimeCurrent(tm);
   return(tm.day);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int Year()
{
   MqlDateTime tm;
   TimeCurrent(tm);
   return(tm.year);
}

//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
 bool ImpactSelected(string impact)
  {
   if(include_high && (StringFind(impact,"High") != -1))
      return true;
   if(include_medium && (StringFind(impact,"Medium") != -1))
      return true;
   if(include_low && (StringFind(impact,"Low") != -1))
      return true;
   return false;
  }