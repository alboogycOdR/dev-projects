//+------------------------------------------------------------------+
//|                                  Auto Copy My Trade Internet.mq5 |
//|                         Copyright 2024, Vestor Finance (Pty) Ltd |
//|                                    https://www.vestorfinance.com |
//|                                      Property of David Richchild |
//+------------------------------------------------------------------+

#property copyright        "Copyright 2025, Arrissa AI Trade."
#property link             "https://www.arrissa.trade"
#property description      "This EA trades using Arrissa API system. Familarise yourself with the strategy before use."
#property description      "Make sure that https://arrissa.trade is allowed Web Request URLs in Tools > Options > Experts"
#property version          "3.9"
#property strict
#resource               "\\Images\\arrissa-api-logo.bmp"

#include <Trade/Trade.mqh>
CTrade trade;

string orderNumber;

int MaxSlippage = 100;
ENUM_ORDER_TYPE_FILLING FOTypeEnum;

#define RATE_LIMIT 429

enum YESNO{
   
   YES=1,
   NO=0
   
};

enum LimitType{

   Limited = 1,
   Unlimited = 0

};

enum TradingDirection{
   
   Both = 0,
   BuyOnly=1, // Buy only
   SellOnly=2 // Sell only
   
};

// Define an enumeration for server options
enum ServerOptions {
    RealSignals,  //ZA Real Signal Server     
    RealSignals2,// ZA Real Signal Server 2
    VestorFinance // Vestor Finance Server
};

#include <JAson.mqh>
CJAVal jjs;

//Graphic Declations
string currname;
string ObjPrefix; 
int boxVmargin = 20, boxHmargin = 10, boxcorner = 2;
int boxwidth = 220, boxheight = 68;
int rowmargin = 10, colmargin1 = 6;
int InputBw = 90, InputBh = 19;

int boxYdist, boxXdist, tractorX, tractorY;
string fonttype = "Arial Bold";
string fonttype2 = "Arial";

int fontsizeB = 9, fontsizeL = 14, fontsizeM = 10;
color fontcolor = clrWhite, BoxBGCol = clrBlack;

// PANEL FORMATTING
int boxVmarginP = 200, boxHmarginP = 5, boxcornerP = 0;
int boxwidthP = 350, boxheightP = 340;
int rowmarginP = 22, colmargin1P = 30;
color BoxBGColP = C'222,52,61', BoxBorderColP = clrRed;   //C'34,238,91';
//End Graphic Declarations

//leverage
long previousLeverage = 0;

// Declare a unique array to store processed timestamps
datetime handledTradeTimestamps[]; // Unique array for processed timestamps

//Define Lot Size Constant
double Lotsize;

//Define good price
double GoodByPoints; 

// Global variables to store the last trade price and count of trades
double lastTradePrice = 0;
int tradeCount = 0;

//Function to get account number nad return it as a string
long accountNumber = AccountInfoInteger(ACCOUNT_LOGIN);

// Global flags and settings
bool SuspendedCloseActive = false;  // Tracks if a closure was suspended






//Declare All Inputs
input string UserName_input = "";
input string APIkey_input = "";
// Inputs
input bool ActivateOffsetEntry_input = true;  // Toggle the offset entry feature
input double OffsetPoints_input = 10;         // Number of points the current price must be lower than the previous entry

input string S20_input = " ***** Auto Trading *****"; //
input bool ActivateArrissaAutoTrader_input = true;

input string S10_input = " ***** Trading Settings *****"; // 
input int MagicNumber_TP1_input = 312431; // Magic number
input int MagicNumber_TP2_input = 312432; // Magic number
input int MagicNumber_TP3_input = 312433; // Magic number
input int MagicNumber_TP4_input = 312434; // Magic number
input string ExpertName_input = "EA"; // Expert name
input ulong Max_Slippage_input = 0; // Maximum slippage (Points)
input TradingDirection Direction_input = Both; // Trading direction
input bool AllowTradeNews_input = false; // Allow trading with news signal

input string S19_input = " ***** Position Sizing *****"; //
input double GeneralLot_input = 0.01; // Lot size for Currencies
input double IndicesLot_input = 0.01; // Lot size for NASDAQ,US30 & GER30
input double GoldLot_input = 0.01; // Lot size for GOLD (XAUUSD)
input double BTCLot_input = 0.01; // Lot size for BTCUSD

input double Volatility10IndexLot_input = 0.5; // Lot for VIX 10 Index
input double Volatility25IndexLot_input = 0.5; // Lot for VIX 25 Index
input double Volatility50IndexLot_input = 4.0; // Lot for VIX 50 Index
input double Volatility75IndexLot_input = 0.01; // Lot for VIX 75 Index
input double Volatility100IndexLot_input = 0.5; // Lot for VIX 100 Index

input double Volatility10_1s_IndexLot_input = 0.5; // Lot for VIX 10 (1s) Index
input double Volatility25_1s_IndexLot_input = 0.005; // Lot for VIX 25 (1s) Index
input double Volatility50_1s_IndexLot_input = 0.005; // Lot for VIX 50 (1s) Index
input double Volatility75_1s_IndexLot_input = 0.05; // Lot for VIX 75 (1s) Index
input double Volatility100_1s_IndexLot_input = 0.2; // Lot for VIX 100 (1s) Index

input YESNO CopyTPValue_input = YES; // Copy TP value

// (Next lines are not "input" originally; see the 'Standalone Variables' section below.)

// Resuming input lines:
input bool Trigger_Close_All_input = true;  // Set to true to trigger Close All Workers
input string S4_input = " ***** Stoploss *****"; // 
input YESNO CopySLValues_input = YES; // Copy SL values
input double StoplossOffset_input = 100; //Stop Loss offset % (Adjust Stop loss by this percentage 100=Same as signal)

input string S5_input = " ***** Trailing stop *****"; // 
input YESNO ActivateTrailingStoploss_input = NO; // Activate trailing stoploss
input double TrailingStart_input = 700; // Start trailing
input double TrailingStop_input = 300; // Trailing stop
input double TrailingStep_input = 200; // Trailing step

input string S6_input = " ***** Breakeven *****"; // 
input YESNO ActivateBreakeven_input = NO; // Activate breakeven
input double BreakevenPoints_input = 500; // Points need to activate breakeven

input string S7_input = " ***** Symbol Mapping *****"; // 
input string ListOfSymbolFormat_input = "USDCAD,USDCHF,USDJPY,CADCHF,GBPUSD,GBPJPY,EURUSD,EURJPY,AUDUSD,AUDCAD,NZDUSD,XAUUSD"; // List of master symbol format
input string MatchesFromClient_input = "USDCAD,USDCHF,USDJPY,CADCHF,GBPUSD,GBPJPY,EURUSD,EURJPY,AUDUSD,AUDCAD,NZDUSD,XAUUSD"; // *Change to match your symbols

input string S8_input = " ***** Trading time *****"; // 
input YESNO AllowTradingTime_input = NO; // Allow trading time
input string _StartTime_input = "16:30"; // Start trading time
input string _EndTime_input = "22:00"; // End trading time

input string S9_input = " ***** GoodPrice Mode *****"; //
input bool UseGoodPriceMode_input = true; // Use Good Price Mode: Yes/No
input bool UseGoodPriceExpansion_input = true; // Use Good Price Expansion: Yes/No

input string S18_input = " ***** GoodPrice Mode *****"; //
input int ExpansionPercentage_input = 20; // Expansion Percentage (e.g., 20 for 20%)

input double GoodByPointsGold_input = 200; // Good Price Points GOLD
input double GoodByPointsCurrencies_input = 5; // Good Price Points Currencies
input double GoodByPointsUSDJPY_input = 30; // Good Price Points USDJPY
input double GoodByPointsIndices_input = 100; // Good Price Points Indices
input double GoodByPointsBTCUSD_input = 9000; // Good Price Points BTCUSD
input double GoodByPointsBTCJPY_input = 7000; // Good Price Points BTCJPY
input double GoodByPointsBTCXAU_input = 2000; // Good Price Points BTCXAU

input string S17_input = " ***** GoodPrice Mode *****"; //
input double GoodbyPointsVolatility10Index_input = 900; // Good Price Points VIX 10 Index
input double GoodbyPointsVolatility25Index_input = 1500; // Good Price Points VIX 25 Index
input double GoodbyPointsVolatility50Index_input = 4500; // Good Price Points VIX 50 Index
input double GoodbyPointsVolatility75Index_input = 22000; // Good Price Points VIX 75 Index
input double GoodbyPointsVolatility100Index_input = 500; // Good Price Points VIX 100 Index

input double GoodbyPointsVolatility10_1s_Index_input = 150; // Good Price Points VIX 10 (1s) Index
input double GoodbyPointsVolatility25_1s_Index_input = 45000; // Good Price Points VIX 25 (1s) Index
input double GoodbyPointsVolatility50_1s_Index_input = 28000; // Good Price Points VIX 50 (1s) Index
input double GoodbyPointsVolatility75_1s_Index_input = 1700; // Good Price Points VIX 75 (1s) Index
input double GoodbyPointsVolatility100_1s_Index_input = 500; // Good Price Points VIX 100 (1s) Index

input string S11_input = " ***** GoodPrice Martingale *****"; //
// New inputs for incremental martingale
input bool EnableIncrementalMartingale_input = true; // Enable/disable incremental martingale strategy
input double IncrementalStep_input = 0;           // Incremental step for each trade in the martingale strategy
// Existing inputs
input bool AllowMartingale_input = true;             // Enable/disable martingale strategy
input double MartingaleMultiplier_input = 2.0;       // Multiplier for the martingale strategy

// Weakest Link settings
input string S12_input = " ***** Eliminate Weakest Link *****"; //
input bool EliminateWeakLink_input = false;  // Enable/disable weakest link elimination

input string S13_input = " ***** Equity Protect *****"; //
input bool EnableEquityProtect_input = true;              // Enable or disable equity protection
input double CloseWhenProfitInMoney_input = 10000;         // Profit threshold for closing all trades
input double CloseWhenLossInMoney_input = 10000;           // Loss threshold for closing all trades

input string S14_input = " ***** Equity Protect *****"; //
// Inputs for profit trailing
input bool ActivateProfitTrailing_input = true;          // Enable or disable profit trailing
input double StartTrailingWhenInProFitMoney_input = 50; // Profit level to start trailing
input double LockingAmountPercentage_input = 50;         // Percentage of profit to lock
input bool EnableParabolicLock_input = true;      // Enable parabolic lock feature
input double ParabolicIncrement_input = 5;      // Increment in percentage per step (e.g., 50%)
input double StepSizePercentage_input = 20;      // Step size percentage (e.g., 30%)

//Inputs for Symbol Profit Trailing
input string S30_input                                   = " ***** Profit Trailing By Symbol *****";
input bool   EnableManageSymbolProfitTrailing_input             = true;
input double StartTrailingWhenInProFitMoney_symbol_input = 1000;    // Profit to start trailing
input double LockingAmountPercentage_symbol_input        = 50;    // % of profit to lock
input bool   EnableParabolicLock_symbol_input            = true;  
input double ParabolicIncrement_symbol_input             = 5;     // % increment per step
input double StepSizePercentage_symbol_input             = 20;    // % step size

//— globals (track per-symbol state) —
string  tr_symbols[];          // symbols under trailing
bool    tr_activated[];        // has trailing begun?
double  tr_highestProfit[];    // highest profit seen
double  tr_lockProfit[];       // current lock level


input string S15_input = " ***** Command or Manual *****"; //
// Inputs for profit trailing
input bool ManualSignal_input = true;          // Enable or disable Manual Signal
// Global input declarations
input int TradeStartHour_input = 0; // Trading start hour (e.g., 9 AM)
input int TradeEndHour_input = 24;  // Trading end hour (e.g., 5 PM)

input string S16_input = " ***** Number of Trades *****";
// Inputs
input int MaxNumberOfTradesPerOrderNumber_input = 10;
input int MaxNumberOfTradesPerSymbol_input = 30;
input int MaxNumberOfTradesEver_input = 300;


//Declare All Variables set from inputs
string UserName = UserName_input;
string APIkey = APIkey_input;
// Inputs
bool ActivateOffsetEntry = ActivateOffsetEntry_input;  // Toggle the offset entry feature
double OffsetPoints = OffsetPoints_input;         // Number of points the current price must be lower than the previous entry

string S20 = S20_input; //
bool ActivateArrissaAutoTrader = ActivateArrissaAutoTrader_input;

string S10 = S10_input; // 
int MagicNumber_TP1 = MagicNumber_TP1_input; // Magic number
int MagicNumber_TP2 = MagicNumber_TP2_input; // Magic number
int MagicNumber_TP3 = MagicNumber_TP3_input; // Magic number
int MagicNumber_TP4 = MagicNumber_TP4_input; // Magic number
string ExpertName = ExpertName_input; // Expert name
ulong Max_Slippage = Max_Slippage_input; // Maximum slippage (Points)
TradingDirection Direction = Direction_input; // Trading direction
bool AllowTradeNews = AllowTradeNews_input; // Allow trading with news signal

string S19 = S19_input; //
double GeneralLot = GeneralLot_input; // Lot size for Currencies
double IndicesLot = IndicesLot_input; // Lot size for NASDAQ,US30 & GER30
double GoldLot = GoldLot_input; // Lot size for GOLD (XAUUSD)
double BTCLot = BTCLot_input; // Lot size for BTCUSD

double Volatility10IndexLot = Volatility10IndexLot_input; // Lot for VIX 10 Index
double Volatility25IndexLot = Volatility25IndexLot_input; // Lot for VIX 25 Index
double Volatility50IndexLot = Volatility50IndexLot_input; // Lot for VIX 50 Index
double Volatility75IndexLot = Volatility75IndexLot_input; // Lot for VIX 75 Index
double Volatility100IndexLot = Volatility100IndexLot_input; // Lot for VIX 100 Index

double Volatility10_1s_IndexLot = Volatility10_1s_IndexLot_input; // Lot for VIX 10 (1s) Index
double Volatility25_1s_IndexLot = Volatility25_1s_IndexLot_input; // Lot for VIX 25 (1s) Index
double Volatility50_1s_IndexLot = Volatility50_1s_IndexLot_input; // Lot for VIX 50 (1s) Index
double Volatility75_1s_IndexLot = Volatility75_1s_IndexLot_input; // Lot for VIX 75 (1s) Index
double Volatility100_1s_IndexLot = Volatility100_1s_IndexLot_input; // Lot for VIX 100 (1s) Index

YESNO CopyTPValue = CopyTPValue_input; // Copy TP value

// (No assignments here for lines that weren't originally "input")

bool Trigger_Close_All = Trigger_Close_All_input;  // Set to true to trigger Close All Workers
string S4 = S4_input; // 
YESNO CopySLValues = CopySLValues_input; // Copy SL values
double StoplossOffset = StoplossOffset_input; //Stop Loss offset % (Adjust Stop loss by this percentage 100=Same as signal)

string S5 = S5_input; // 
YESNO ActivateTrailingStoploss = ActivateTrailingStoploss_input; // Activate trailing stoploss
double TrailingStart = TrailingStart_input; // Start trailing
double TrailingStop = TrailingStop_input; // Trailing stop
double TrailingStep = TrailingStep_input; // Trailing step

string S6 = S6_input; // 
YESNO ActivateBreakeven = ActivateBreakeven_input; // Activate breakeven
double BreakevenPoints = BreakevenPoints_input; // Points need to activate breakeven

string S7 = S7_input; // 
string ListOfSymbolFormat = ListOfSymbolFormat_input; // List of master symbol format
string MatchesFromClient = MatchesFromClient_input; // *Change to match your symbols

string S8 = S8_input; // 
YESNO AllowTradingTime = AllowTradingTime_input; // Allow trading time
string _StartTime = _StartTime_input; // Start trading time
string _EndTime = _EndTime_input; // End trading time

string S9 = S9_input; //
bool UseGoodPriceMode = UseGoodPriceMode_input; // Use Good Price Mode: Yes/No
bool UseGoodPriceExpansion = UseGoodPriceExpansion_input; // Use Good Price Expansion: Yes/No

string S18 = S18_input; //
int ExpansionPercentage = ExpansionPercentage_input; // Expansion Percentage (e.g., 20 for 20%)

double GoodByPointsGold = GoodByPointsGold_input; // Good Price Points GOLD
double GoodByPointsCurrencies = GoodByPointsCurrencies_input; // Good Price Points Currencies
double GoodByPointsUSDJPY = GoodByPointsUSDJPY_input; // Good Price Points USDJPY
double GoodByPointsIndices = GoodByPointsIndices_input; // Good Price Points Indices
double GoodByPointsBTCUSD = GoodByPointsBTCUSD_input; // Good Price Points BTCUSD
double GoodByPointsBTCJPY = GoodByPointsBTCJPY_input; // Good Price Points BTCJPY
double GoodByPointsBTCXAU = GoodByPointsBTCXAU_input; // Good Price Points BTCXAU

string S17 = S17_input; //
double GoodbyPointsVolatility10Index = GoodbyPointsVolatility10Index_input; // Good Price Points VIX 10 Index
double GoodbyPointsVolatility25Index = GoodbyPointsVolatility25Index_input; // Good Price Points VIX 25 Index
double GoodbyPointsVolatility50Index = GoodbyPointsVolatility50Index_input; // Good Price Points VIX 50 Index
double GoodbyPointsVolatility75Index = GoodbyPointsVolatility75Index_input; // Good Price Points VIX 75 Index
double GoodbyPointsVolatility100Index = GoodbyPointsVolatility100Index_input; // Good Price Points VIX 100 Index

double GoodbyPointsVolatility10_1s_Index = GoodbyPointsVolatility10_1s_Index_input; // Good Price Points VIX 10 (1s) Index
double GoodbyPointsVolatility25_1s_Index = GoodbyPointsVolatility25_1s_Index_input; // Good Price Points VIX 25 (1s) Index
double GoodbyPointsVolatility50_1s_Index = GoodbyPointsVolatility50_1s_Index_input; // Good Price Points VIX
double GoodbyPointsVolatility75_1s_Index = GoodbyPointsVolatility75_1s_Index_input; // Good Price Points VIX 75 (1s) Index
double GoodbyPointsVolatility100_1s_Index = GoodbyPointsVolatility100_1s_Index_input; // Good Price Points VIX 100 (1s) Index

string S11 = S11_input; //
bool EnableIncrementalMartingale = EnableIncrementalMartingale_input; // Enable/disable incremental martingale strategy
double IncrementalStep = IncrementalStep_input;           // Incremental step for each trade in the martingale strategy
bool AllowMartingale = AllowMartingale_input;             // Enable/disable martingale strategy
double MartingaleMultiplier = MartingaleMultiplier_input; // Multiplier for the martingale strategy

// Weakest Link settings
string S12 = S12_input; //
bool EliminateWeakLink = EliminateWeakLink_input;  // Enable/disable weakest link elimination

string S13 = S13_input; //
bool EnableEquityProtect = EnableEquityProtect_input;              // Enable or disable equity protection
double CloseWhenProfitInMoney = CloseWhenProfitInMoney_input;      // Profit threshold for closing all trades
double CloseWhenLossInMoney = CloseWhenLossInMoney_input;          // Loss threshold for closing all trades

string S14 = S14_input; //
// Inputs for profit trailing
bool ActivateProfitTrailing = ActivateProfitTrailing_input;          // Enable or disable profit trailing
double StartTrailingWhenInProFitMoney = StartTrailingWhenInProFitMoney_input; // Profit level to start trailing
double LockingAmountPercentage = LockingAmountPercentage_input;      // Percentage of profit to lock
bool EnableParabolicLock = EnableParabolicLock_input;                // Enable parabolic lock feature
double ParabolicIncrement = ParabolicIncrement_input;                // Increment in percentage per step (e.g., 50%)
double StepSizePercentage = StepSizePercentage_input;                // Step size percentage (e.g., 30%)

string S15 = S15_input; // 
// Inputs for profit trailing
bool ManualSignal = ManualSignal_input;          // Enable or disable Manual Signal
// Global input declarations
int TradeStartHour = TradeStartHour_input; // Trading start hour (e.g., 9 AM)
int TradeEndHour = TradeEndHour_input;     // Trading end hour (e.g., 5 PM)

string S16 = S16_input;
int MaxNumberOfTradesPerOrderNumber = MaxNumberOfTradesPerOrderNumber_input;
int MaxNumberOfTradesPerSymbol = MaxNumberOfTradesPerSymbol_input;
int MaxNumberOfTradesEver = MaxNumberOfTradesEver_input;


//Inputs for Symbol Profit Trailing
string S30 = S30_input;
bool   EnableManageSymbolProfitTrailing = EnableManageSymbolProfitTrailing_input;
double StartTrailingWhenInProFitMoney_symbol = StartTrailingWhenInProFitMoney_symbol_input;
double LockingAmountPercentage_symbol = LockingAmountPercentage_symbol_input;
bool   EnableParabolicLock_symbol = EnableParabolicLock_symbol_input;  
double ParabolicIncrement_symbol = ParabolicIncrement_symbol_input;
double StepSizePercentage_symbol = StepSizePercentage_symbol_input;






//Variable Constant
int NumberofTradeTP1 = 100; // Number of trades for TP1 per signal
int NumberofTradeTP2 = 10; // Number of trades for TP2 per signal
int NumberofTradeTP3 = 10; // Number of trades for TP3 per signal
int NumberofTradeTP4 = 10; // Number of trades for TP4 per signal

string S3 = " ***** Trade Quantity *****"; // 
LimitType MaximumTradeType = Unlimited; // Maximum number of running trades
int NumberofTradeIfHasTP1Only = 100; // Number of trade if has TP1 only
int MaximumTrade_TP1 = 100; // Limit number of open trades of TP 1
int MaximumTrade_TP2 = 20; // Limit number of open trades of TP 2
int MaximumTrade_TP3 = 20; // Limit number of open trades of TP 3
int MaximumTrade_TP4 = 20; // Limit number of open trades of TP 4








int offsetID;
bool BlockBot=false;
datetime blockingTime = 0;


bool firstInit=true;

string MasterPair[];
string ClientPair[];

datetime GetTime(string timedata,datetime sourceTime){
   datetime currentTime = sourceTime;
   MqlDateTime mqlTime;
   TimeToStruct(currentTime, mqlTime);
   // Construct datetime for 16:30 today
   return StringToTime(StringFormat("%d.%02d.%02d "+timedata, mqlTime.year, mqlTime.mon, mqlTime.day));
}

string FilterSender;
string StartTime;
string EndTime;
int timeDifference;
uint savedTicks;
string signalData;

datetime GetTime(datetime sourceTime){
   datetime currentTime = sourceTime;
   MqlDateTime mqlTime;
   TimeToStruct(currentTime, mqlTime);
   // Construct datetime for 16:30 today
   return StringToTime(StringFormat("%d.%02d.%02d "+IntegerToString(mqlTime.hour)+":"+IntegerToString(mqlTime.min)+":00", mqlTime.year, mqlTime.mon, mqlTime.day));
   
}


struct GoodPriceEntry {
    string symbol;
    double TP1;
    double TP2;
    double TP3;
    double TP4;
    double SL;
    double LowestPriceInSeries;
    int magicNumber;
    int currentTradeCount;
    bool seriesComplete;
    string initialComment;  // Stores the comment from the first trade
};


// Array to store each Good Price entry
GoodPriceEntry goodPriceEntries[];



struct GoodPriceEntrySell {
    string symbol;
    double TP1;
    double TP2;
    double TP3;
    double TP4;
    double SL;
    double HighestPriceInSeries;
    int magicNumber;
    int currentTradeCount;
    bool seriesComplete;
    string initialComment;  // Stores the comment from the first trade
};


// Array to store each Good Price entry for sell series
GoodPriceEntrySell goodPriceEntriesSell[];


// Variables to track trailing state
bool trailingActivated = false;
double highestProfitLevel = 0.0;
double lockProfitLevel = 0.0;

string buttonName4 = "LockInfoButton";  // Unique identifier for the button
string ProfitMessage = "Profit lock not activated yet";
string AccountCurrency = AccountInfoString(ACCOUNT_CURRENCY);
color ProfitBGColor = C'22,22,22';
string LastClosedProfit = "";
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{ 
     SetEAFromInternetVariables();
     GlobalVariableSet("CLOSE_ALL_TRADES", 0.0);  // Ensure reset on startup
     EnsureSymbolsInMarketWatch(MatchesFromClient);
     CreateLogo();
     
     CreateLockInfoButton();
    
    //Initalize Weekdays
    WeekDays_Init();


   //Apply Chart Colors
   ThemeApply();
   
   //GRAPHICS
   ObjPrefix = "1234563245";//IntegerToString(MagicNumber);
   boxYdist = boxVmargin + (boxcorner==1 || boxcorner==2)*boxheight;
   boxXdist = boxHmargin + (boxcorner>1)*boxwidth;
   tractorX = 1 - 2*(boxcorner>1);
   tractorY = 1 - 2*(int) MathMod(boxcorner,2);
   //GRAPHICS
   
   GlobalVariableSet("CopyTradeDatabase_"+ExpertName,savedTicks);
   
   trade.SetDeviationInPoints(Max_Slippage);

   // Construct the URL
   string constructedURL = "https://arrissa.trade/trade-auth/authentication.php";
   
    // // Print the constructed URL for debugging
    // // Print("Constructed URL: ", constructedURL);
   
   // Use the constructed URL
   string mess = ReadMessage(constructedURL);

   if(jjs.Deserialize(mess)){
   
      int data = (int)jjs[0]["Result"].ToInt();
      if(data == 1){
         string t = jjs[1]["Timestamp"].ToStr();
         //Retrieve time difference
         datetime tempDatetime = StringToTime(t);
         timeDifference = (int)GetTime(TimeCurrent()) - (int)tempDatetime;
         // Allowed
      }else{
         Comment("EA will not trade. Validation Failed. Contact @david_richchild of Telegram");
         Alert("Unable to verify your account, please contact our support for more infomation");
         
         return INIT_FAILED;
         
      }
      
   }else{
   
      Alert("Cannot retrieve data from server, please try again later !");
      Comment("EA will not trade. Validation Failed. Contact @david_richchild of Telegram");
      return INIT_FAILED;
   
   }

   //Load mapping
   int lengthMasterList = StringSplit(ListOfSymbolFormat,',',MasterPair);
   int lengthClientList = StringSplit(MatchesFromClient,',',ClientPair);
   
   if(lengthClientList != lengthMasterList){
      Alert("Master symbol list format and Client symbol list format need to be the same size");
      return INIT_FAILED;
   }
   
   StartTime = StartTime + ":00";
   EndTime = EndTime + ":00";
   
   SendProfitData();
   
   EventSetMillisecondTimer(10);
   
   return(INIT_SUCCEEDED);
    // Print("EA Reset");
}
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
   
  }

  
void OnTimer(){
   SetEAFromInternetVariables();
   
   if (ActivateArrissaAutoTrader){
         ArrissaAutoTrade();
         }

   if (ActivateProfitTrailing) {
        ManageProfitTrailing();
    }
    
    if(EnableManageSymbolProfitTrailing){
      ManageSymbolProfitTrailing();
     }

   
   CreateLockInfoButton();
   
   
   // Call EquityProtect to check and potentially close trades
   EquityProtect();
   GetOrdersProfitAndSendRequest();


      MonitorAndResetEA();
   
   // Check and eliminate the weakest link if enabled
    EliminateWeakestLink();
    

if (UseGoodPriceMode){
   // Only execute Good Price checks if there is an active series awaiting trades
   for (int i = 0; i < ArraySize(goodPriceEntries); i++) {
       GoodPriceEntry entry = goodPriceEntries[i];
       if (!entry.seriesComplete && entry.currentTradeCount < NumberofTradeTP1) {
           // Run Good Price trade checks for active series
                 CheckAndExecuteGoodPriceTrades();
                 break;  // Exit loop once an active series is found and checked 
       }
   }
   
   // Only execute Good Price checks if there is an active sell series awaiting trades
   for (int i = 0; i < ArraySize(goodPriceEntriesSell); i++) {
       GoodPriceEntrySell entry = goodPriceEntriesSell[i];
       if (!entry.seriesComplete && entry.currentTradeCount < NumberofTradeTP1) {
           // Run Good Price trade checks for active sell series
                 CheckAndExecuteGoodPriceTradesSell();
                 break;  // Exit loop once an active series is found and checked
       }
   }
   
}

   if(GlobalVariableGet("CopyTradeDatabase_"+ExpertName) != savedTicks){
      Alert("You only need to open this EA once and set the symbol for trading");
      ExpertRemove();
   }

   if((TimeCurrent() >= GetTime(StartTime,TimeCurrent())   && TimeCurrent() < GetTime(EndTime,TimeCurrent()) && AllowTradingTime) || !AllowTradingTime){
   
      if(!BlockBot){
      string message;
      //Only allow trading manually if explicitly specified
      if (ManualSignal){
         message = ReadMessage("https://arrissa.trade/trade.php?username="+UserName+"&api_key="+APIkey);
         //Print(message);
       } else{
         return;
       }
         jjs.Clear();
         StringTrimLeft(message);
         StringTrimRight(message);
         
         if(jjs.Deserialize(message)){
            
            int index = 0;
            
            while(true){
               
               string symbol = jjs[index]["Symbol"].ToStr();
               //Symbol Lot Mapping
               if (symbol == "NASDAQ" || symbol == "US30" || symbol == "GER30") {
                      Lotsize = IndicesLot;
                  }
                  else if (symbol == "XAUUSD") {
                     Lotsize = GoldLot;
                  } 
                  else if (symbol == "BTCUSD") {
                     Lotsize = BTCLot;
                  } 
                  else {
                      Lotsize = GeneralLot;
                     }
               //End Symbol Lot Mapping
               
               
               
               
               
                if (StringLen(symbol) > 0) {

    string ordertype = jjs[index]["OrderType"].ToStr();
    StringTrimLeft(ordertype);
    StringTrimRight(ordertype);
    StringToLower(ordertype);

    StringTrimLeft(symbol);
    StringTrimRight(symbol);
    symbol = MapSymbol(symbol);

    string TP1s, TP2s, TP3s, TP4s, SLs;
    double TP1 = -1, TP2 = -1, TP3 = -1, TP4 = -1, SL = -1;
    double price;
    string isNew = jjs[index]["isNews"].ToStr();
    datetime tradeTimestamp = StringToTime(jjs[index]["TimeStamp"].ToStr()) + timeDifference;
    orderNumber = jjs[index]["Order"].ToStr();
    //Print("order number:" + orderNumber);
    string orderTicket = jjs[index]["Ticket"].ToStr();

    // Check if the timestamp has already been processed
    bool isTimestampProcessed = false; // Flag for timestamp processing
    for (int i = 0; i < ArraySize(handledTradeTimestamps); i++) {
        if (handledTradeTimestamps[i] == tradeTimestamp) {
            isTimestampProcessed = true;
            break;
        }
    }

    if (!isTimestampProcessed) { // Proceed only if timestamp is new
        if (((isNew == "TRUE" && AllowTradeNews) || (!AllowTradeNews && isNew == "FALSE") || 
            (isNew == "FALSE" && AllowTradeNews)) && 
            (int)TimeCurrent() - (int)tradeTimestamp <= 50 && tradeTimestamp != 0 && 
            IsTradeAllowed(symbol, DayOfWeekConverter())) {

            if (StringFind(signalData, "#" + orderNumber) < 0) {
                signalData += "#" + orderNumber;
                string comment = ExpertName + orderNumber;

                // Parse additional trade parameters
                TP1s = jjs[index]["TP1"].ToStr();
                TP2s = jjs[index]["TP2"].ToStr();
                TP3s = jjs[index]["TP3"].ToStr();
                TP4s = jjs[index]["TP4"].ToStr();
                SLs = jjs[index]["recommendedSL"].ToStr();

                if (StringLen(TP1s) > 0) TP1 = StringToDouble(TP1s);
                if (StringLen(TP2s) > 0) TP2 = StringToDouble(TP2s);
                if (StringLen(TP3s) > 0) TP3 = StringToDouble(TP3s);
                if (StringLen(TP4s) > 0) TP4 = StringToDouble(TP4s);
                if (StringLen(SLs) > 0) SL = StringToDouble(SLs);

                price = StringToDouble(jjs[index]["Price"].ToStr());

                if (StringLen(symbol) > 0) {
                    // Execute trades based on order type
                    if (ordertype == "buy" && (Direction == Both || Direction == BuyOnly) && symbol != "") {
                        if (!CheckMaxNumberOfTradesPerSymbol(symbol) && !CheckMaxNumberOfTradesEver() && !CheckMaxNumberOfTradesPerOrderComment(comment)) {
                            Buy(symbol, TP1, TP2, TP3, TP4, SL, orderNumber);
                        } else {
                             // Print("Max Number of Trades Reached");
                        }
                    } else if (ordertype == "buy limit" && (Direction == Both || Direction == BuyOnly) && symbol != "") {
                        if (!CheckMaxNumberOfTradesPerSymbol(symbol) && !CheckMaxNumberOfTradesEver() && !CheckMaxNumberOfTradesPerOrderComment(comment)) {
                            BuyLimit(symbol, TP1, TP2, TP3, TP4, SL, price, orderTicket);
                        } else {
                             // Print("Max Number of Trades Reached");
                        }
                    } else if (ordertype == "buy stop" && (Direction == Both || Direction == BuyOnly) && symbol != "") {
                        if (!CheckMaxNumberOfTradesPerSymbol(symbol) && !CheckMaxNumberOfTradesEver() && !CheckMaxNumberOfTradesPerOrderComment(comment)) {
                            BuyStop(symbol, TP1, TP2, TP3, TP4, SL, price, orderTicket);
                        } else {
                             // Print("Max Number of Trades Reached");
                        }
                    } else if (ordertype == "sell" && (Direction == Both || Direction == SellOnly) && symbol != "") {
                        if (!CheckMaxNumberOfTradesPerSymbol(symbol) && !CheckMaxNumberOfTradesEver() && !CheckMaxNumberOfTradesPerOrderComment(comment)) {
                            Sell(symbol, TP1, TP2, TP3, TP4, SL, orderNumber);
                        } else {
                             // Print("Max Number of Trades Reached");
                        }
                    } else if (ordertype == "sell limit" && (Direction == Both || Direction == SellOnly) && symbol != "") {
                        if (!CheckMaxNumberOfTradesPerSymbol(symbol) && !CheckMaxNumberOfTradesEver() && !CheckMaxNumberOfTradesPerOrderComment(comment)) {
                            SellLimit(symbol, TP1, TP2, TP3, TP4, SL, price, orderTicket);
                        } else {
                             // Print("Max Number of Trades Reached");
                        }
                    } else if (ordertype == "sell stop" && (Direction == Both || Direction == SellOnly) && symbol != "") {
                        if (!CheckMaxNumberOfTradesPerSymbol(symbol) && !CheckMaxNumberOfTradesEver() && !CheckMaxNumberOfTradesPerOrderComment(comment)) {
                            SellStop(symbol, TP1, TP2, TP3, TP4, SL, price, orderTicket);
                        } else {
                             // Print("Max Number of Trades Reached");
                        }
                    }
                }

                // Add the current timestamp to the processed list
                ArrayResize(handledTradeTimestamps, ArraySize(handledTradeTimestamps) + 1);
                handledTradeTimestamps[ArraySize(handledTradeTimestamps) - 1] = tradeTimestamp;
            }
        }
    }
} 
              else
                  break;
               
               index++;
            }
            
// Access money management
  

message = ReadMessage("https://arrissa.trade/trade-management-api.php?username="+UserName+"&api_key="+APIkey);


jjs.Clear();
StringTrimLeft(message);
StringTrimRight(message);


//Print("Fetched JSON message: " + message); // Log the fetched JSON message

// Define a static array to store processed timestamps
static string processedTimestamps[]; 

if (jjs.Deserialize(message)) {
    // // Print("JSON deserialization successful.");

    index = 0;
    while (true) {
        string symbol = jjs[index]["Symbol"].ToStr();

        if (StringLen(symbol) > 0) {
            StringTrimLeft(symbol);
            StringTrimRight(symbol);
            symbol = MapSymbol(symbol);
            orderNumber = jjs[index]["Order"].ToStr();
            string action = jjs[index]["Action"].ToStr(); // Retrieve the "Action" field
            string timestamp = jjs[index]["Timestamp"].ToStr(); // Retrieve the "Timestamp" field

             // Print("Processing index: " + IntegerToString(index) + ", Symbol: " + symbol + ", Order: " + orderNumber + ", Action: " + action + ", Timestamp: " + timestamp);

            // Check if the timestamp has already been processed
            bool alreadyProcessed = false;
            for (int i = 0; i < ArraySize(processedTimestamps); i++) {
                if (processedTimestamps[i] == timestamp) {
                    alreadyProcessed = true;
                     // Print("Action with Timestamp " + timestamp + " has already been processed. Skipping.");
                    break;
                }
            }

             if (!alreadyProcessed) {
                        if (action == "Close50") {
                            CloseHalfTrades(orderNumber, symbol);
                        } else if (action == "CloseAll") {
                            FindAndCloseTrade(orderNumber, symbol);
                        } else if (action == "DeleteBreakEven") {
                            RemoveAllStopLosses(orderNumber, symbol);
                        } else if (action == "Lock50") {
                            SetStopLossAtMidpoint(orderNumber, symbol);
                        } else if (action == "BreakEvenGlobal") {
                            AdjustStopLossToEntry();
                        } else if (action == "DeleteBreakEvenGlobal") {
                            RemoveAllStopLossesGlobal();
                        } else if (action == "CloseAllGlobal") {
                            CloseAllGlobal();
                        } 

                // Add the processed timestamp to the list
                ArrayResize(processedTimestamps, ArraySize(processedTimestamps) + 1);
                processedTimestamps[ArraySize(processedTimestamps) - 1] = timestamp;
            }

        } else {
             // Print("Empty or invalid symbol at index: " + IntegerToString(index) + ". Exiting loop.");
            break;
        }

        index++;
    }
} else {
     // // Print("JSON deserialization failed.");
}




            
         }
      
      }
   
   }
   
   
if (UseGoodPriceMode){   
   // Only execute Good Price checks if there is an active series awaiting trades
   for (int i = 0; i < ArraySize(goodPriceEntries); i++) {
       GoodPriceEntry entry = goodPriceEntries[i];
       if (!entry.seriesComplete && entry.currentTradeCount < NumberofTradeTP1) {
           // Run Good Price trade checks for active series
           CheckAndExecuteGoodPriceTrades();
           break;  // Exit loop once an active series is found and checked
       }
   }
   
   // Only execute Good Price checks if there is an active sell series awaiting trades
   for (int i = 0; i < ArraySize(goodPriceEntriesSell); i++) {
       GoodPriceEntrySell entry = goodPriceEntriesSell[i];
       if (!entry.seriesComplete && entry.currentTradeCount < NumberofTradeTP1) {
           // Run Good Price trade checks for active sell series
           CheckAndExecuteGoodPriceTradesSell();
           break;  // Exit loop once an active series is found and checked
       }
   }
}   
   
   
   
   
   
    
   
   if(ActivateTrailingStoploss){
      SetTrailingStop(TrailingStart,TrailingStop,TrailingStep);
   }
   
   if(ActivateBreakeven)
      HandleBreakeven();

}

///// FOR BUY

//+------------------------------------------------------------------+
//| Function to continuously check for Good Price entries            |
//+------------------------------------------------------------------+
void CheckAndExecuteGoodPriceTrades() {

if (UseGoodPriceMode){
    for (int i = 0; i < ArraySize(goodPriceEntries); i++) {
        // Access the element directly without using '&'
        if (!goodPriceEntries[i].seriesComplete && goodPriceEntries[i].currentTradeCount < NumberofTradeTP1) {
            CheckGoodPriceForTP(goodPriceEntries[i]);
        }
    }
   }           
}


double SetGoodByPoints(string symbol) {
    string masterSymbols[];
    StringSplit(ListOfSymbolFormat, ',', masterSymbols);
    
    string clientSymbols[];
    StringSplit(MatchesFromClient, ',', clientSymbols);
    
    for (int i = 0; i < ArraySize(masterSymbols); i++) {
        if (symbol == clientSymbols[i]) {
            string masterSymbol = masterSymbols[i];
            
            if (masterSymbol == "NASDAQ" || masterSymbol == "US30" || masterSymbol == "GER30") {
                return GoodByPointsIndices;
            }else if (masterSymbol == "USDJPY") {
                return GoodByPointsUSDJPY;
            }else if (masterSymbol == "XAUUSD") {
                return GoodByPointsGold;
            }
            else if (masterSymbol == "BTCUSD") {
                return GoodByPointsBTCUSD;
            }
            else if (masterSymbol == "BTCJPY") {
                return GoodByPointsBTCJPY;
            } 
            else if (masterSymbol == "BTCXAU") {
                return GoodByPointsBTCXAU;
            }
            else {
                return GoodByPointsCurrencies;
            }
        }
    }
    
    // Default value if symbol is not found in MatchesFromClient
    return GoodByPointsCurrencies;
}


// Function to handle Good Price entries for Buy trades
// Function to handle Good Price entries for Buy trades
void CheckGoodPriceForTP(GoodPriceEntry &entry) {
    if (UseGoodPriceMode && !CheckMaxNumberOfTradesPerOrderComment(entry.initialComment)) {
        MqlTick lastTick;
        if (!SymbolInfoTick(entry.symbol, lastTick)) return;  // Skip if no price data

        double price = lastTick.ask;
        double lotSize = Lotsize;  // Base lot size

        // Apply incremental or multiplier-based martingale if enabled
        if (AllowMartingale && entry.currentTradeCount > 0) {
            if (EnableIncrementalMartingale) {
                // If IncrementalStep is 0 then open trades with the same base lot size
                if (IncrementalStep != 0) {
                    // Use incremental martingale: Increase lot size by IncrementalStep per trade
                    lotSize = Lotsize + (IncrementalStep * entry.currentTradeCount);
                } else {
                    lotSize = Lotsize;
                }
            } else {
                // Use multiplier-based martingale
                lotSize = Lotsize * MathPow(MartingaleMultiplier, entry.currentTradeCount);
            }
        }

        // Check if the trade count has reached the limit for this series
        if (MaximumTradeType == Limited && CountTrade(entry.magicNumber) >= MaximumTrade_TP1) {
            entry.seriesComplete = true; // Mark the series as complete
            return; // Exit the function if maximum trades reached in Limited mode
        }

        // Calculate GoodByPoints with expansion if enabled
        GoodByPoints = SetGoodByPoints(entry.symbol);
        if (UseGoodPriceExpansion && entry.currentTradeCount > 0) {
            GoodByPoints *= MathPow(1 + ExpansionPercentage / 100.0, entry.currentTradeCount);
            GoodByPoints = MathRound(GoodByPoints); // Round to nearest integer
        }

        // Only enter a new trade if the price has dropped below LowestPriceInSeries by GoodByPoints
        if (price <= (entry.LowestPriceInSeries - GoodByPoints * SymbolInfoDouble(entry.symbol, SYMBOL_POINT))) {
            // Set the initial comment on the first trade
            if (entry.currentTradeCount == 0) {
                entry.initialComment = ExpertName + orderNumber;  // Use the initial comment
            }

            int ticket = trade.Buy(lotSize, entry.symbol, price, CalculateStopLoss(entry.SL, entry.symbol), entry.TP1, entry.initialComment);
            
            if (ticket != -1) {
                // Update the LowestPriceInSeries if this new trade is executed at a lower price
                entry.LowestPriceInSeries = MathMin(entry.LowestPriceInSeries, price);
                entry.currentTradeCount++; // Increment the count of trades executed in this series

                // Check if the series has reached the maximum number of trades
                if (entry.currentTradeCount >= NumberofTradeTP1) {
                    entry.seriesComplete = true; // Mark the series as complete
                }
            }
        }
    }
}






//+------------------------------------------------------------------+
//| Reset function to clear entry for next series                    |
//+------------------------------------------------------------------+
void ResetGoodPriceEntry(GoodPriceEntry &entry) {
    entry.LowestPriceInSeries = 0;
    entry.currentTradeCount = 0;
    entry.seriesComplete = false;
}

//+------------------------------------------------------------------+
//| Function to calculate Stop Loss dynamically                      |
//+------------------------------------------------------------------+
double CalculateStopLoss(double SL, string symbol) {
    if (!CopySLValues) return 0;
    double points = MathAbs(iClose(symbol, PERIOD_CURRENT, 0) - SL) / SymbolInfoDouble(symbol, SYMBOL_POINT);
    points = points * (StoplossOffset / 100);
    return NormalizeDouble(iClose(symbol, PERIOD_CURRENT, 0) - points * SymbolInfoDouble(symbol, SYMBOL_POINT), (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS));
}



//// FOR SELL

//+------------------------------------------------------------------+
//| Function to continuously check for Good Price entries for sells  |
//+------------------------------------------------------------------+
void CheckAndExecuteGoodPriceTradesSell() {
    for (int i = 0; i < ArraySize(goodPriceEntriesSell); i++) {
        
        // Access each entry directly without using '&'
        if (!goodPriceEntriesSell[i].seriesComplete && goodPriceEntriesSell[i].currentTradeCount < NumberofTradeTP1) {
            CheckGoodPriceForTPSell(goodPriceEntriesSell[i]);
        }
    }
}


// Function to handle Good Price entries for Sell trades
void CheckGoodPriceForTPSell(GoodPriceEntrySell &entry) {
    if (UseGoodPriceMode && !CheckMaxNumberOfTradesPerOrderComment(entry.initialComment)) {
        MqlTick lastTick;
        if (!SymbolInfoTick(entry.symbol, lastTick)) return;  // Skip if no price data available

        double price = lastTick.bid; // Use bid price for sell trades
        double lotSize = Lotsize;  // Base lot size

        // Apply incremental or multiplier-based martingale if enabled
        if (AllowMartingale && entry.currentTradeCount > 0) {
            if (EnableIncrementalMartingale) {
                // If IncrementalStep is 0 then open trades with the same base lot size
                if (IncrementalStep != 0) {
                    // Use incremental martingale: Increase lot size by IncrementalStep per trade
                    lotSize = Lotsize + (IncrementalStep * entry.currentTradeCount);
                } else {
                    lotSize = Lotsize;
                }
            } else {
                // Use multiplier-based martingale
                lotSize = Lotsize * MathPow(MartingaleMultiplier, entry.currentTradeCount);
            }
        }

        // Check if the trade count has reached the limit for this series
        if (MaximumTradeType == Limited && CountTrade(entry.magicNumber) >= MaximumTrade_TP1) {
            entry.seriesComplete = true; // Mark the series as complete
            return; // Exit the function if maximum trades reached in Limited mode
        }

        // Calculate GoodByPoints with expansion if enabled
        GoodByPoints = SetGoodByPoints(entry.symbol);
        if (UseGoodPriceExpansion && entry.currentTradeCount > 0) {
            GoodByPoints *= MathPow(1 + ExpansionPercentage / 100.0, entry.currentTradeCount);
            GoodByPoints = MathRound(GoodByPoints); // Round to nearest integer
        }

        // Only enter a new trade if the price has risen above HighestPriceInSeries by GoodByPoints
        if (price >= (entry.HighestPriceInSeries + GoodByPoints * SymbolInfoDouble(entry.symbol, SYMBOL_POINT))) {
            // Set the initial comment on the first trade
            if (entry.currentTradeCount == 0) {
                entry.initialComment = ExpertName + orderNumber;  // Use the initial comment
            }

            int ticket = trade.Sell(lotSize, entry.symbol, price, CalculateStopLossSell(entry.SL, entry.symbol), entry.TP1, entry.initialComment);
            
            if (ticket != -1) {
                // Update the HighestPriceInSeries if this new trade is executed at a higher price
                entry.HighestPriceInSeries = MathMax(entry.HighestPriceInSeries, price);
                entry.currentTradeCount++; // Increment the count of trades executed in this series

                // Check if the series has reached the maximum number of trades
                if (entry.currentTradeCount >= NumberofTradeTP1) {
                    entry.seriesComplete = true; // Mark the series as complete
                    
                    // Reset entry for next series
                    ResetGoodPriceEntrySell(entry);
                }
            }
        }
    }
}



//+------------------------------------------------------------------+
//| Reset function to clear entry for next sell series               |
//+------------------------------------------------------------------+
void ResetGoodPriceEntrySell(GoodPriceEntrySell &entry) {
    entry.HighestPriceInSeries = 0;
    entry.currentTradeCount = 0;
    entry.seriesComplete = false;
}

//+------------------------------------------------------------------+
//| Function to calculate Stop Loss dynamically for sells            |
//+------------------------------------------------------------------+
double CalculateStopLossSell(double SL, string symbol) {
    if (!CopySLValues) return 0;
    double points = MathAbs(iClose(symbol, PERIOD_CURRENT, 0) - SL) / SymbolInfoDouble(symbol, SYMBOL_POINT);
    points = points * (StoplossOffset / 100);
    return NormalizeDouble(iClose(symbol, PERIOD_CURRENT, 0) + points * SymbolInfoDouble(symbol, SYMBOL_POINT), (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS)); // Added for Sell
}













void FindAndCloseTrade(string orderNumber, string symbol) {
    ulong ticket;

    // Close positions
    for (int i = PositionsTotal() - 1; i >= 0; i--) {
        ticket = PositionGetTicket(i);

        if (PositionSelectByTicket(ticket)) {
            if (PositionGetString(POSITION_COMMENT) == ExpertName + orderNumber && PositionGetString(POSITION_SYMBOL) == symbol) {
                if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY || PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL) {
                    bool b = trade.PositionClose(ticket);
                    ResetEA();
                }
            }
        }
    }

    // Delete pending orders
    for (int i = OrdersTotal() - 1; i >= 0; i--) {
        ticket = OrderGetTicket(i);
        if (OrderSelect(ticket)) {
            if (OrderGetString(ORDER_COMMENT) == ExpertName + orderNumber && OrderGetString(ORDER_SYMBOL) == symbol) {
                bool b = trade.OrderDelete(ticket);
                ResetEA();
            }
        }
    }
}






void CloseHalfTrades(string orderNumber, string symbol) {
    ulong ticket;
    int totalPositions = 0;
    int closedPositions = 0;

    // First, count the total positions with the specified comment and symbol
    for (int i = PositionsTotal() - 1; i >= 0; i--) {
        ticket = PositionGetTicket(i);
        if (PositionSelectByTicket(ticket)) {
            if (PositionGetString(POSITION_COMMENT) == ExpertName + orderNumber && PositionGetString(POSITION_SYMBOL) == symbol) {
                totalPositions++;
            }
        }
    }

    // Calculate half of the total positions to close
    int positionsToClose = totalPositions / 2;

    // Close half of the positions
    for (int i = PositionsTotal() - 1; i >= 0 && closedPositions < positionsToClose; i--) {
        ticket = PositionGetTicket(i);
        if (PositionSelectByTicket(ticket)) {
            if (PositionGetString(POSITION_COMMENT) == ExpertName + orderNumber && PositionGetString(POSITION_SYMBOL) == symbol) {
                if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY || PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL) {
                    bool b = trade.PositionClose(ticket);
                    if (b) {
                        closedPositions++;
                    }
                }
            }
        }
    }

    int totalOrders = 0;
    int closedOrders = 0;

    // Count the total orders with the specified comment and symbol
    for (int i = OrdersTotal() - 1; i >= 0; i--) {
        ticket = OrderGetTicket(i);
        if (OrderSelect(ticket)) {
            if (OrderGetString(ORDER_COMMENT) == ExpertName + orderNumber && OrderGetString(ORDER_SYMBOL) == symbol) {
                totalOrders++;
            }
        }
    }

    // Calculate half of the total orders to close
    int ordersToClose = totalOrders / 2;

    // Close half of the orders
    for (int i = OrdersTotal() - 1; i >= 0 && closedOrders < ordersToClose; i--) {
        ticket = OrderGetTicket(i);
        if (OrderSelect(ticket)) {
            if (OrderGetString(ORDER_COMMENT) == ExpertName + orderNumber && OrderGetString(ORDER_SYMBOL) == symbol) {
                bool b = trade.OrderDelete(ticket);
                if (b) {
                    closedOrders++;
                }
            }
        }
    }
}





  
string MapSymbol(string symbol){
   
   string validSymbol = "";
   string sym;
   
   for(int i = 0; i < ArraySize(MasterPair); i++){
      
      sym = MasterPair[i];

      if(StringFind(symbol,sym) >= 0 || StringFind(sym,symbol) >= 0){
         validSymbol = ClientPair[i];
         break;
      }
      
   }
   
   
   return validSymbol;
   
}
  
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
string ReadMessage(string url){
   
   string response = "";
   char post[];
   char result[];
   string headers;
   int timeout = 5000; // Timeout in milliseconds

   int res = WebRequest("GET", url, "", "", timeout, post, 0, result, headers);
   if(res == -1)
   {
        // Print("Error in WebRequest. Error code: ", GetLastError());
   }
   else
   {
       response = CharArrayToString(result, 0, ArraySize(result));
       
       //Reached rates limit
       if(res == RATE_LIMIT){
          BlockBot = true;
          blockingTime = TimeCurrent()+2*60; // Block 2 minutes
       }
   }

   return response;
   
}


//

void SetTrailingStop(double trailingStart, double trailingStop, double trailingStep) {
    
    ulong ticket;
   
    for(int i = PositionsTotal() - 1; i >= 0; i--){
       
       ticket = PositionGetInteger(POSITION_TICKET);
       
       if(PositionSelectByTicket(ticket)){
       
            if((PositionGetInteger(POSITION_MAGIC) == MagicNumber_TP1 || PositionGetInteger(POSITION_MAGIC) == MagicNumber_TP2 || PositionGetInteger(POSITION_MAGIC) == MagicNumber_TP3 || PositionGetInteger(POSITION_MAGIC) == MagicNumber_TP4) && PositionGetDouble(POSITION_PROFIT) >= 0){
              
                if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) {
                   // For a buy order
                   if(SymbolInfoDouble(PositionGetString(POSITION_SYMBOL),SYMBOL_BID) - PositionGetDouble(POSITION_PRICE_OPEN) > trailingStart * SymbolInfoDouble(PositionGetString(POSITION_SYMBOL),SYMBOL_POINT)) {
                       double newStopLoss = SymbolInfoDouble(PositionGetString(POSITION_SYMBOL),SYMBOL_BID) - trailingStop * SymbolInfoDouble(PositionGetString(POSITION_SYMBOL),SYMBOL_POINT);
                       if(newStopLoss > PositionGetDouble(POSITION_SL) + trailingStep  * SymbolInfoDouble(PositionGetString(POSITION_SYMBOL),SYMBOL_POINT) && newStopLoss >= PositionGetDouble(POSITION_PRICE_OPEN)) {
                           bool b = trade.PositionModify(ticket, PositionGetDouble(POSITION_PRICE_OPEN)+(TrailingStop * SymbolInfoDouble(PositionGetString(POSITION_SYMBOL),SYMBOL_POINT)), PositionGetDouble(POSITION_TP));
                       }
                   }
               } else if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL) {
                   // For a sell order
                   if(PositionGetDouble(POSITION_PRICE_OPEN) - SymbolInfoDouble(PositionGetString(POSITION_SYMBOL),SYMBOL_ASK) > trailingStart  * SymbolInfoDouble(PositionGetString(POSITION_SYMBOL),SYMBOL_POINT)) {
                       double newStopLoss = SymbolInfoDouble(PositionGetString(POSITION_SYMBOL),SYMBOL_ASK) + trailingStop  * SymbolInfoDouble(PositionGetString(POSITION_SYMBOL),SYMBOL_POINT);
                       
                       if(((newStopLoss < PositionGetDouble(POSITION_SL) - trailingStep  * SymbolInfoDouble(PositionGetString(POSITION_SYMBOL),SYMBOL_POINT)) || PositionGetDouble(POSITION_SL) == 0) && newStopLoss <= PositionGetDouble(POSITION_PRICE_OPEN)) {
                           bool b = trade.PositionModify(ticket, PositionGetDouble(POSITION_PRICE_OPEN)-(TrailingStop * SymbolInfoDouble(PositionGetString(POSITION_SYMBOL),SYMBOL_POINT)), PositionGetDouble(POSITION_TP));
                       }
                   }
               }
               
            }
         
       }
      
    }
    
}



//+------------------------------------------------------------------+
//| Main Buy function to initialize a Good Price entry               |
//+------------------------------------------------------------------+
void Buy(string symbol, double TP1, double TP2, double TP3, double TP4, double SL, string orderNumber)
{
    int                 ticket;
    MqlTick             lastTick;

    // get current ask
    if(!SymbolInfoTick(symbol, lastTick))
        return;
    double price = lastTick.ask;

    // build comment & entry
    string initialComment = ExpertName + orderNumber;
    GoodPriceEntry entry;
    entry.symbol                = symbol;
    entry.TP1                   = TP1;
    entry.TP2                   = TP2;
    entry.TP3                   = TP3;
    entry.TP4                   = TP4;
    entry.SL                    = SL;
    entry.LowestPriceInSeries   = price;
    entry.magicNumber           = MagicNumber_TP1;
    entry.currentTradeCount     = 1;
    entry.seriesComplete        = false;
    entry.initialComment        = initialComment;

    ArrayResize(goodPriceEntries, ArraySize(goodPriceEntries) + 1);
    goodPriceEntries[ArraySize(goodPriceEntries) - 1] = entry;

    //--- prepare raw trade request
    MqlTradeRequest  req;
    MqlTradeResult   res;
    ZeroMemory(req);
    ZeroMemory(res);

    req.action         = TRADE_ACTION_DEAL;
    req.symbol         = symbol;
    req.volume         = Lotsize;
    req.price          = price;
    req.sl             = CalculateStopLoss(SL, symbol);
    req.tp             = TP1;
    req.magic          = MagicNumber_TP1;
    req.type           = ORDER_TYPE_BUY;
    req.type_filling   = FOTypeEnum;
    req.deviation      = MaxSlippage;
    req.comment        = initialComment;

    //--- send order
    if(OrderSend(req, res))
        ticket = (int)res.order;
    else
        ticket = -1;

    //--- if success, update series price
    if(ticket != -1)
        goodPriceEntries[ArraySize(goodPriceEntries) - 1].LowestPriceInSeries = price;
}



//+------------------------------------------------------------------+
//| Main Sell function to initialize a Good Price entry for sells    |
//+------------------------------------------------------------------+
void Sell(string symbol, double TP1, double TP2, double TP3, double TP4, double SL, string orderNumber)
{
    int                 ticket;
    MqlTick             lastTick;

    // get current bid
    if(!SymbolInfoTick(symbol, lastTick))
        return;
    double price = lastTick.bid;

    // build comment & entry
    string initialComment = ExpertName + orderNumber;
    GoodPriceEntrySell entry;
    entry.symbol                 = symbol;
    entry.TP1                    = TP1;
    entry.TP2                    = TP2;
    entry.TP3                    = TP3;
    entry.TP4                    = TP4;
    entry.SL                     = SL;
    entry.HighestPriceInSeries   = price;
    entry.magicNumber            = MagicNumber_TP1;
    entry.currentTradeCount      = 1;
    entry.seriesComplete         = false;
    entry.initialComment         = initialComment;

    ArrayResize(goodPriceEntriesSell, ArraySize(goodPriceEntriesSell) + 1);
    goodPriceEntriesSell[ArraySize(goodPriceEntriesSell) - 1] = entry;

    //--- prepare raw trade request
    MqlTradeRequest  req;
    MqlTradeResult   res;
    ZeroMemory(req);
    ZeroMemory(res);

    req.action         = TRADE_ACTION_DEAL;
    req.symbol         = symbol;
    req.volume         = Lotsize;
    req.price          = price;
    req.sl             = SL;
    req.tp             = TP1;
    req.magic          = MagicNumber_TP1;
    req.type           = ORDER_TYPE_SELL;
    req.type_filling   = FOTypeEnum;
    req.deviation      = MaxSlippage;
    req.comment        = initialComment;

    //--- send order
    if(OrderSend(req, res))
        ticket = (int)res.order;
    else
        ticket = -1;

    //--- if success, update series price
    if(ticket != -1)
        goodPriceEntriesSell[ArraySize(goodPriceEntriesSell) - 1].HighestPriceInSeries = price;
}












void BuyStop(string symbol,double TP1,double TP2,double TP3,double TP4,double SL,double price,string orderNumber){
   
   if(price == -1)
      return;
   
   int ticket;
   double stoploss;
   double points;
   
   if(!CopySLValues)
      stoploss=0;
   else{
      
      if(SL > 0){
      
         points = MathAbs(iClose(symbol,PERIOD_CURRENT,0) - SL)/SymbolInfoDouble(symbol,SYMBOL_POINT);
         points = points * (StoplossOffset/100);
         stoploss = iClose(symbol,PERIOD_CURRENT,0) - points*SymbolInfoDouble(symbol,SYMBOL_POINT);
         
      }else
         stoploss = 0;
      
   }
   
   stoploss = NormalizeDouble(stoploss,(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS));
   
   if(TP2 != -1 || TP3 != -1 || TP4 != -1){
      
      for(int i = 0; i < NumberofTradeTP1; i++){
         trade.SetExpertMagicNumber(MagicNumber_TP1);
         if(TP1 != -1 && ((CountTrade(MagicNumber_TP1) < MaximumTrade_TP1 && MaximumTradeType == Limited) || MaximumTradeType == Unlimited))
            ticket = trade.BuyStop(Lotsize,price,symbol,stoploss,TP1,0,0,ExpertName+orderNumber);
      }
      
   }else{
      for(int i = 0; i < NumberofTradeIfHasTP1Only; i++){
         trade.SetExpertMagicNumber(MagicNumber_TP1);
         if(TP1 != -1 && ((CountTrade(MagicNumber_TP1) < MaximumTrade_TP1 && MaximumTradeType == Limited) || MaximumTradeType == Unlimited))
            ticket = trade.BuyStop(Lotsize,price,symbol,stoploss,TP1,0,0,ExpertName+orderNumber);
      }
   }
   
   for(int i = 0; i < NumberofTradeTP2; i++){
      trade.SetExpertMagicNumber(MagicNumber_TP2);
      if(TP2 != -1 && ((CountTrade(MagicNumber_TP2) < MaximumTrade_TP2 && MaximumTradeType == Limited) || MaximumTradeType == Unlimited))
         ticket = trade.BuyStop(Lotsize,price,symbol,stoploss,TP2,0,0,ExpertName+orderNumber);
   }
   
   for(int i = 0; i < NumberofTradeTP3; i++){
      trade.SetExpertMagicNumber(MagicNumber_TP3);
      if(TP3 != -1 && ((CountTrade(MagicNumber_TP3) < MaximumTrade_TP3 && MaximumTradeType == Limited) || MaximumTradeType == Unlimited))
         ticket = trade.BuyStop(Lotsize,price,symbol,stoploss,TP3,0,0,ExpertName+orderNumber);
   }
   
   for(int i = 0; i < NumberofTradeTP4; i++){
      trade.SetExpertMagicNumber(MagicNumber_TP4);
      if(TP4 != -1 && ((CountTrade(MagicNumber_TP4) < MaximumTrade_TP4 && MaximumTradeType == Limited) || MaximumTradeType == Unlimited))
         ticket = trade.BuyStop(Lotsize,price,symbol,stoploss,TP4,0,0,ExpertName+orderNumber);
   }
   
}

void BuyLimit(string symbol,double TP1,double TP2,double TP3,double TP4,double SL,double price,string orderNumber){
   
   if(price == -1)
      return;
   
   int ticket;
   double stoploss;
   double points;
   
   if(!CopySLValues)
      stoploss=0;
   else{
      
      if(SL > 0){
      
         points = MathAbs(iClose(symbol,PERIOD_CURRENT,0) - SL)/SymbolInfoDouble(symbol,SYMBOL_POINT);
         points = points * (StoplossOffset/100);
         stoploss = iClose(symbol,PERIOD_CURRENT,0) - points*SymbolInfoDouble(symbol,SYMBOL_POINT);
         
      }else
         stoploss = 0;
      
   }
   
   stoploss = NormalizeDouble(stoploss,(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS));
   
   if(TP2 != -1 || TP3 != -1 || TP4 != -1){
   
      for(int i = 0; i < NumberofTradeTP1; i++){
         trade.SetExpertMagicNumber(MagicNumber_TP1);
         if(TP1 != -1 && ((CountTrade(MagicNumber_TP1) < MaximumTrade_TP1 && MaximumTradeType == Limited) || MaximumTradeType == Unlimited))
            ticket = trade.BuyLimit(Lotsize,price,symbol,stoploss,TP1,0,0,ExpertName+orderNumber);
      }
   
   }else{
      for(int i = 0; i < NumberofTradeIfHasTP1Only; i++){
         trade.SetExpertMagicNumber(MagicNumber_TP1);
         if(TP1 != -1 && ((CountTrade(MagicNumber_TP1) < MaximumTrade_TP1 && MaximumTradeType == Limited) || MaximumTradeType == Unlimited))
            ticket = trade.BuyLimit(Lotsize,price,symbol,stoploss,TP1,0,0,ExpertName+orderNumber);
      }
   }
   
   for(int i = 0; i < NumberofTradeTP2; i++){
      trade.SetExpertMagicNumber(MagicNumber_TP2);
      if(TP2 != -1 && ((CountTrade(MagicNumber_TP2) < MaximumTrade_TP2 && MaximumTradeType == Limited) || MaximumTradeType == Unlimited))
         ticket = trade.BuyLimit(Lotsize,price,symbol,stoploss,TP2,0,0,ExpertName+orderNumber);
   }
   
   for(int i = 0; i < NumberofTradeTP3; i++){
      trade.SetExpertMagicNumber(MagicNumber_TP3);
      if(TP3 != -1 && ((CountTrade(MagicNumber_TP3) < MaximumTrade_TP3 && MaximumTradeType == Limited) || MaximumTradeType == Unlimited))
         ticket = trade.BuyLimit(Lotsize,price,symbol,stoploss,TP3,0,0,ExpertName+orderNumber);
   }
   
   for(int i = 0; i < NumberofTradeTP4; i++){
      trade.SetExpertMagicNumber(MagicNumber_TP4);
      if(TP4 != -1 && ((CountTrade(MagicNumber_TP4) < MaximumTrade_TP4 && MaximumTradeType == Limited) || MaximumTradeType == Unlimited))
         ticket = trade.BuyLimit(Lotsize,price,symbol,stoploss,TP4,0,0,ExpertName+orderNumber);
   }
   
}




void SellStop(string symbol,double TP1,double TP2,double TP3,double TP4,double SL,double price,string orderNumber){
   
   if(price == -1)
      return;
   
   int ticket;
   double stoploss;
   double points;
   
   if(!CopySLValues)
      stoploss=0;
   else{
      
      if(SL > 0){
         
         points = MathAbs(iClose(symbol,PERIOD_CURRENT,0) - SL)/SymbolInfoDouble(symbol,SYMBOL_POINT);
         points = points * (StoplossOffset/100);
         stoploss = iClose(symbol,PERIOD_CURRENT,0) + points*SymbolInfoDouble(symbol,SYMBOL_POINT);
         
      }else
         stoploss = 0;
      
   }
   
   stoploss = NormalizeDouble(stoploss,(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS));
   
   if(TP2 != -1 || TP3 != -1 || TP4 != -1){
      for(int i = 0; i < NumberofTradeTP1; i++){
         trade.SetExpertMagicNumber(MagicNumber_TP1);
         if(TP1 != -1 && ((CountTrade(MagicNumber_TP1) < MaximumTrade_TP1 && MaximumTradeType == Limited) || MaximumTradeType == Unlimited))
            ticket = trade.SellStop(Lotsize,price,symbol,stoploss,TP1,0,0,ExpertName+orderNumber);
      }
   }else{
      for(int i = 0; i < NumberofTradeIfHasTP1Only; i++){
         trade.SetExpertMagicNumber(MagicNumber_TP1);
         if(TP1 != -1 && ((CountTrade(MagicNumber_TP1) < MaximumTrade_TP1 && MaximumTradeType == Limited) || MaximumTradeType == Unlimited))
            ticket = trade.SellStop(Lotsize,price,symbol,stoploss,TP1,0,0,ExpertName+orderNumber);
      }
   }
   
   for(int i = 0; i < NumberofTradeTP2; i++){
      trade.SetExpertMagicNumber(MagicNumber_TP2);
      if(TP2 != -1 && ((CountTrade(MagicNumber_TP2) < MaximumTrade_TP2 && MaximumTradeType == Limited) || MaximumTradeType == Unlimited))
         ticket = trade.SellStop(Lotsize,price,symbol,stoploss,TP2,0,0,ExpertName+orderNumber);
   }
   
   for(int i = 0; i < NumberofTradeTP3; i++){
      trade.SetExpertMagicNumber(MagicNumber_TP3);
      if(TP3 != -1 && ((CountTrade(MagicNumber_TP3) < MaximumTrade_TP3 && MaximumTradeType == Limited) || MaximumTradeType == Unlimited))
         ticket = trade.SellStop(Lotsize,price,symbol,stoploss,TP3,0,0,ExpertName+orderNumber);
   }
   
   for(int i = 0; i < NumberofTradeTP4; i++){
      trade.SetExpertMagicNumber(MagicNumber_TP4);
      if(TP4 != -1 && ((CountTrade(MagicNumber_TP4) < MaximumTrade_TP4 && MaximumTradeType == Limited) || MaximumTradeType == Unlimited))
         ticket = trade.SellStop(Lotsize,price,symbol,stoploss,TP4,0,0,ExpertName+orderNumber);
   }
   
}

void SellLimit(string symbol,double TP1,double TP2,double TP3,double TP4,double SL,double price,string orderNumber){
   
   if(price == -1)
      return;
   
   int ticket;
   double stoploss;
   double points;
   
   if(!CopySLValues)
      stoploss=0;
   else{
      
      if(SL > 0){
         
         points = MathAbs(iClose(symbol,PERIOD_CURRENT,0) - SL)/SymbolInfoDouble(symbol,SYMBOL_POINT);
         points = points * (StoplossOffset/100);
         stoploss = iClose(symbol,PERIOD_CURRENT,0) + points*SymbolInfoDouble(symbol,SYMBOL_POINT);
         
      }else
         stoploss = 0;
      
   }
   
   stoploss = NormalizeDouble(stoploss,(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS));
   
   if(TP2 != -1 || TP3 != -1 || TP4 != -1){
      for(int i = 0; i < NumberofTradeTP1; i++){
         trade.SetExpertMagicNumber(MagicNumber_TP1);
         if(TP1 != -1 && ((CountTrade(MagicNumber_TP1) < MaximumTrade_TP1 && MaximumTradeType == Limited) || MaximumTradeType == Unlimited))
            ticket = trade.SellLimit(Lotsize,price,symbol,stoploss,TP1,0,0,ExpertName+orderNumber);
      }
   }else{
      for(int i = 0; i < NumberofTradeIfHasTP1Only; i++){
         trade.SetExpertMagicNumber(MagicNumber_TP1);
         if(TP1 != -1 && ((CountTrade(MagicNumber_TP1) < MaximumTrade_TP1 && MaximumTradeType == Limited) || MaximumTradeType == Unlimited))
            ticket = trade.SellLimit(Lotsize,price,symbol,stoploss,TP1,0,0,ExpertName+orderNumber);
      }
   }
   
   for(int i = 0; i < NumberofTradeTP2; i++){
      trade.SetExpertMagicNumber(MagicNumber_TP2);
      if(TP2 != -1 && ((CountTrade(MagicNumber_TP2) < MaximumTrade_TP2 && MaximumTradeType == Limited) || MaximumTradeType == Unlimited))
         ticket = trade.SellLimit(Lotsize,price,symbol,stoploss,TP2,0,0,ExpertName+orderNumber);
   }
   
   for(int i = 0; i < NumberofTradeTP3; i++){
      trade.SetExpertMagicNumber(MagicNumber_TP3);
      if(TP3 != -1 && ((CountTrade(MagicNumber_TP3) < MaximumTrade_TP3 && MaximumTradeType == Limited) || MaximumTradeType == Unlimited))
         ticket = trade.SellLimit(Lotsize,price,symbol,stoploss,TP3,0,0,ExpertName+orderNumber);
   }
   
   for(int i = 0; i < NumberofTradeTP4; i++){
      trade.SetExpertMagicNumber(MagicNumber_TP4);
      if(TP4 != -1 && ((CountTrade(MagicNumber_TP4) < MaximumTrade_TP4 && MaximumTradeType == Limited) || MaximumTradeType == Unlimited))
         ticket = trade.SellLimit(Lotsize,price,symbol,stoploss,TP4,0,0,ExpertName+orderNumber);
   }
   
}












int CountTrade(int magic){
   
   int count=0;
   ulong ticket;
   
   for(int i = PositionsTotal()-1;i>=0;i--){
      ticket = PositionGetInteger(POSITION_TICKET);
      if(PositionSelectByTicket(ticket)){
         
         if(PositionGetInteger(POSITION_MAGIC) == magic){
            count++;
         }
         
      }
      
   }
   
   //
   
   for(int i = OrdersTotal()-1;i>=0;i--){
      ticket = OrderGetInteger(ORDER_TICKET);
      if(OrderSelect(ticket)){
         
         if(OrderGetInteger(ORDER_MAGIC) == magic){
            count++;
         }
         
      }
      
   }
   
   return count;
   
}

void HandleBreakeven(){

    double points;
    bool b;
    ulong ticket;
   
    for(int i = PositionsTotal()-1;i>=0;i--){
      ticket = PositionGetTicket(i);
      
      if(PositionSelectByTicket(ticket)){
         
         if((PositionGetInteger(POSITION_MAGIC) == MagicNumber_TP1 || PositionGetInteger(POSITION_MAGIC) == MagicNumber_TP2 || PositionGetInteger(POSITION_MAGIC) == MagicNumber_TP3 || PositionGetInteger(POSITION_MAGIC) == MagicNumber_TP4)){
            
            if(PositionGetDouble(POSITION_PROFIT) > 0){
               
               points = MathAbs( (iClose(PositionGetString(POSITION_SYMBOL),PERIOD_CURRENT,0) - PositionGetDouble(POSITION_PRICE_OPEN))/SymbolInfoDouble(PositionGetString(POSITION_SYMBOL),SYMBOL_POINT) );
               
               if(points >= BreakevenPoints){
                  
                  if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY){
                  
                     if(PositionGetDouble(POSITION_SL) < PositionGetDouble(POSITION_PRICE_OPEN)){
                        b = trade.PositionModify(ticket,PositionGetDouble(POSITION_PRICE_OPEN),PositionGetDouble(POSITION_TP));
                     }
                     
                  }else if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL){
                  
                     if(PositionGetDouble(POSITION_SL) > PositionGetDouble(POSITION_PRICE_OPEN)){
                         b = trade.PositionModify(ticket,PositionGetDouble(POSITION_PRICE_OPEN),PositionGetDouble(POSITION_TP));
                     }
                     
                  }
                  
               }
               
               
            }
            
         }
         
      }
      
   }
   
}

datetime Time(int shift=0){
   return iTime(_Symbol,PERIOD_CURRENT,shift);
}

double Close(int shift=0){
   return iClose(_Symbol,PERIOD_CURRENT,shift);
}

double Open(int shift=0){
   return iOpen(_Symbol,PERIOD_CURRENT,shift);
}

double Low(int shift=0){
   return iLow(_Symbol,PERIOD_CURRENT,shift);
}

double High(int shift=0){
   return iHigh(_Symbol,PERIOD_CURRENT,shift);
}

int DayOfWeek(datetime time){
   MqlDateTime mql;
   TimeToStruct(time,mql);
   return mql.day_of_week;
}

int TimeHour(datetime time){
   MqlDateTime mql;
   TimeToStruct(time,mql);
   return mql.hour;
}

int TimeMinute(datetime time){
   MqlDateTime mql;
   TimeToStruct(time,mql);
   return mql.min;
}

int TimeSecond(datetime time){
   MqlDateTime mql;
   TimeToStruct(time,mql);
   return mql.sec;
}

int TimeDay(datetime time){
   MqlDateTime mql;
   TimeToStruct(time,mql);
   return mql.day;
}

int TimeMonth(datetime time){
   MqlDateTime mql;
   TimeToStruct(time,mql);
   return mql.mon;
}

//+------------------------------------------------------------------+
//|  Display information about trade sessions                        |
//+------------------------------------------------------------------+
bool IsTradeAllowed(string symbol,ENUM_DAY_OF_WEEK day)
  {
//--- Start and end of a session
   datetime ss,finish;
   uint session_index=0;
   bool session_exist=true;
   string tm,te;

//--- get over all sessions of the current day
   while(session_exist)
     {
      //--- check if there is a trade session with the number session_index
      session_exist=SymbolInfoSessionTrade(symbol,day,session_index,ss,finish);

      //--- if such session exists
      if(session_exist)
      {
          MqlDateTime dtime;
          TimeToStruct(ss,dtime);
          datetime curTime = TimeCurrent();
          
          tm = "";
          te = "";
          
          StringAdd(tm,TimeToString(curTime, TIME_DATE));
          StringAdd(tm," ");
          StringAdd(tm,IntegerToString(dtime.hour));
          StringAdd(tm," ");
          StringAdd(tm,IntegerToString(dtime.min));
          StringAdd(tm," ");
          StringAdd(tm,IntegerToString(dtime.sec));
          
          datetime dayStart = StringToTime(tm);
          TimeToStruct(finish-1,dtime);
          
          StringAdd(te,TimeToString(curTime, TIME_DATE));
          StringAdd(te," ");
          StringAdd(te,IntegerToString(dtime.hour));
          StringAdd(te," ");
          StringAdd(te,IntegerToString(dtime.min));
          StringAdd(te," ");
          StringAdd(te,IntegerToString(dtime.sec));
          
          datetime dayEnd = StringToTime(te);
          
          te=NULL;
          tm=NULL;
          
          if(TimeCurrent() > dayStart && TimeCurrent() <= dayEnd )
            return true;
          
      }
      //--- increase the counter of sessions
      session_index++;
     }
     
     return false;
     
  }
  
  ENUM_DAY_OF_WEEK DayOfWeekConverter(){
   
   MqlDateTime mql;
   TimeToStruct(TimeCurrent(),mql);
   if(mql.day_of_week == 0)
      return SUNDAY;
   else if(mql.day_of_week == 6)
      return SATURDAY;
   else if(mql.day_of_week == 5)
      return FRIDAY;
   else if(mql.day_of_week == 4)
      return THURSDAY;
   else if(mql.day_of_week == 3)
      return WEDNESDAY;
   else if(mql.day_of_week == 2)
      return TUESDAY;
   else
      return MONDAY;
   
}

//Addition
void ThemeApply(){
   ChartSetInteger(ChartID(), CHART_SHOW_GRID, 0);
   ChartSetInteger(ChartID(), CHART_SHOW_PERIOD_SEP, 0);
   ChartSetInteger(ChartID(), CHART_SHOW_VOLUMES, 0);
   ChartSetInteger(ChartID(), CHART_SHOW_ASK_LINE, 1);
   ChartSetInteger(ChartID(), CHART_COLOR_BACKGROUND, C'18,18,18');
   ChartSetInteger(ChartID(), CHART_COLOR_FOREGROUND, C'238,238,238');
   ChartSetInteger(ChartID(), CHART_COLOR_CHART_LINE, C'68,68,68');
   ChartSetInteger(ChartID(), CHART_COLOR_CHART_UP, C'68,68,68');
   ChartSetInteger(ChartID(), CHART_COLOR_CHART_DOWN, C'33,33,33');
   ChartSetInteger(ChartID(), CHART_COLOR_CANDLE_BULL, C'68,68,68');
   ChartSetInteger(ChartID(), CHART_COLOR_CANDLE_BEAR, C'33,33,33');
   ChartSetInteger(ChartID(), CHART_COLOR_GRID, C'4,9,28');
   ChartSetInteger(ChartID(), CHART_COLOR_BID, clrLightSlateGray);
   ChartSetInteger(ChartID(), CHART_COLOR_ASK, clrPurple);
   ChartSetInteger(ChartID(), CHART_COLOR_LAST, 49152);
   ChartSetInteger(ChartID(), CHART_COLOR_STOP_LEVEL, clrRed);
}



void DefaultColorTheme() {
        // Set default chart colors
   ChartSetInteger(ChartID(), CHART_SHOW_GRID, 1);
   ChartSetInteger(ChartID(), CHART_SHOW_PERIOD_SEP, 0);
   ChartSetInteger(ChartID(), CHART_SHOW_VOLUMES, 0);
   ChartSetInteger(ChartID(), CHART_SHOW_ASK_LINE, 1);
   ChartSetInteger(ChartID(), CHART_COLOR_BACKGROUND, C'237,246,255');
   ChartSetInteger(ChartID(), CHART_COLOR_FOREGROUND, clrWhite);
   ChartSetInteger(ChartID(), CHART_COLOR_CHART_LINE, clrLime);
   ChartSetInteger(ChartID(), CHART_COLOR_CHART_UP, clrLime);
   ChartSetInteger(ChartID(), CHART_COLOR_CHART_DOWN, clrLime);
   ChartSetInteger(ChartID(), CHART_COLOR_CANDLE_BULL, clrBlack);
   ChartSetInteger(ChartID(), CHART_COLOR_CANDLE_BEAR, clrWhite);
   ChartSetInteger(ChartID(), CHART_COLOR_GRID, clrLightSlateGray);
   ChartSetInteger(ChartID(), CHART_COLOR_BID, clrLightSlateGray);
   ChartSetInteger(ChartID(), CHART_COLOR_ASK, clrRed);
   ChartSetInteger(ChartID(), CHART_COLOR_LAST, 49152);
   ChartSetInteger(ChartID(), CHART_COLOR_STOP_LEVEL, clrRed);
}


void AdjustStopLossToEntry() {
    for(int i = PositionsTotal() - 1; i >= 0; i--) {  // Iterate through all open positions
        ulong ticket = PositionGetTicket(i);  // Get the position ticket
        if(ticket > 0) {
            double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);  // Get the entry price
            double currentSL = PositionGetDouble(POSITION_SL);  // Get the current stop loss
            long type = PositionGetInteger(POSITION_TYPE);  // Get the position type using long to avoid data loss

            // Check if adjustment is needed (stop loss is not already at the entry point)
            if((type == POSITION_TYPE_BUY && (currentSL == 0 || currentSL < entryPrice)) ||
               (type == POSITION_TYPE_SELL && (currentSL == 0 || currentSL > entryPrice))) {
                if(type == POSITION_TYPE_BUY) {
                    // Adjust stop loss for a BUY position
                    trade.PositionModify(ticket, entryPrice, PositionGetDouble(POSITION_TP));
                } else if(type == POSITION_TYPE_SELL) {
                    // Adjust stop loss for a SELL position
                    trade.PositionModify(ticket, entryPrice, PositionGetDouble(POSITION_TP));
                }
            }
        }
    }
}


void RemoveAllStopLosses(string orderNumber, string symbol) {
    ulong ticket;

    // Iterate through all open positions
    for (int i = PositionsTotal() - 1; i >= 0; i--) {
        ticket = PositionGetTicket(i);  // Get the position ticket

        if (PositionSelectByTicket(ticket)) {  // Select the position by ticket
            // Check if the position matches the specified comment and symbol
            string positionComment = PositionGetString(POSITION_COMMENT);
            string positionSymbol = PositionGetString(POSITION_SYMBOL);

            if (positionComment == ExpertName + orderNumber && positionSymbol == symbol) {
                double currentTP = PositionGetDouble(POSITION_TP);  // Get the current take profit

                // Set stop loss to zero for positions that match the criteria
                bool modified = trade.PositionModify(ticket, 0.0, currentTP);

                if (modified) {
                     // Print("Stop loss removed for ticket: ", ticket);
                } else {
                     // Print("Failed to remove stop loss for ticket: ", ticket, " Error: ", GetLastError());
                }
            }
        }
    }
}


void RemoveAllStopLossesGlobal() {
    ulong ticket;

    // Iterate through all open positions
    for (int i = PositionsTotal() - 1; i >= 0; i--) {
        ticket = PositionGetTicket(i);  // Get the position ticket

        if (PositionSelectByTicket(ticket)) {  // Select the position by ticket
            double currentTP = PositionGetDouble(POSITION_TP);  // Get the current take profit

            // Set stop loss to zero for all positions
            bool modified = trade.PositionModify(ticket, 0.0, currentTP);

            if (modified) {
                 // Print("Stop loss removed for ticket: ", ticket);
            } else {
                 // Print("Failed to remove stop loss for ticket: ", ticket, " Error: ", GetLastError());
            }
        } else {
             // Print("Failed to select position for ticket: ", ticket, " Error: ", GetLastError());
        }
    }
}






void SetStopLossAtMidpoint(string orderNumber, string symbol) {
    ulong ticket;

    // Iterate through all open positions
    for (int i = PositionsTotal() - 1; i >= 0; i--) {
        ticket = PositionGetTicket(i);  // Get the position ticket

        if (PositionSelectByTicket(ticket)) {  // Select the position by ticket
            // Check if the position matches the specified comment and symbol
            string positionComment = PositionGetString(POSITION_COMMENT);
            string positionSymbol = PositionGetString(POSITION_SYMBOL);
            
            if (positionComment == ExpertName + orderNumber && positionSymbol == symbol) {
                double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);  // Get the entry price
                double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);  // Get the current market price
                double currentTP = PositionGetDouble(POSITION_TP);  // Get the current take profit
                long type = PositionGetInteger(POSITION_TYPE);  // Get the position type

                // Initialize the new stop loss to zero
                double newStopLoss = 0.0;

                // Calculate the 50% level between the entry price and current market price
                if (type == POSITION_TYPE_BUY) {
                    newStopLoss = entryPrice + (currentPrice - entryPrice) / 2.0;  // Midpoint for BUY position
                } else if (type == POSITION_TYPE_SELL) {
                    newStopLoss = entryPrice - (entryPrice - currentPrice) / 2.0;  // Midpoint for SELL position
                }

                // Modify the stop loss to the new calculated level
                bool modified = trade.PositionModify(ticket, newStopLoss, currentTP);

                if (modified) {
                     // Print("Stop loss set to 50% midpoint for ticket: ", ticket);
                } else {
                     // Print("Failed to set stop loss at 50% midpoint for ticket: ", ticket, " Error: ", GetLastError());
                }
            }
        }
    }
}

void CloseAllGlobal() {
    ulong ticket;
    
    while (true) {
        bool allClosed = true; // Assume all trades are closed, set to false if any remain

        // Close all open positions
        for (int i = PositionsTotal() - 1; i >= 0; i--) {
            ticket = PositionGetTicket(i);

            if (PositionSelectByTicket(ticket)) {
                bool closed = trade.PositionClose(ticket);

                if (closed) {
                     // Print("Position closed for ticket: ", ticket);
                } else {
                     // Print("Failed to close position for ticket: ", ticket, " Error: ", GetLastError());
                    allClosed = false; // Set to false to retry closing this position
                }
            }
        }

        // Delete all pending orders
        for (int i = OrdersTotal() - 1; i >= 0; i--) {
            ticket = OrderGetTicket(i);

            if (OrderSelect(ticket)) {
                bool deleted = trade.OrderDelete(ticket);

                if (deleted) {
                     // Print("Pending order deleted for ticket: ", ticket);
                } else {
                     // Print("Failed to delete pending order for ticket: ", ticket, " Error: ", GetLastError());
                    allClosed = false; // Set to false to retry deleting this order
                }
            }
        }

        // Exit loop if all positions and orders have been successfully closed
        if (allClosed) {
            break;
        }

        // Small delay to avoid excessive CPU usage
        Sleep(500);
    }

     // Print("All trades and orders have been successfully closed.");
    ResetEA();
}




void GetOrdersProfitAndSendRequest() {
    // Step 1: Identify unique orders and gather profit/loss data
    ulong ticket;
    string processedOrders[]; // To keep track of processed orders
    string jsonData = "["; // Will hold the JSON data for the web request
    double totalFloatingProfit = 0.0; // To track the total floating profit

    // Structure to hold order data
    struct OrderInfo {
        string orderNumber;
        double profit; // This will be in money (currency)
    };
    OrderInfo uniqueOrders[];

    // Loop through all open positions
    for (int i = PositionsTotal() - 1; i >= 0; i--) {
        ticket = PositionGetTicket(i);
        if (PositionSelectByTicket(ticket)) {
            string orderNumber = PositionGetString(POSITION_COMMENT); // Get the order number from the comment
            double profitInCurrency = PositionGetDouble(POSITION_PROFIT); // Get the profit in account currency directly

            // Add to the total floating profit
            totalFloatingProfit += profitInCurrency;

            // Check if the order number has already been processed (to avoid duplicates)
            bool isProcessed = false;
            for (int j = 0; j < ArraySize(processedOrders); j++) {
                if (processedOrders[j] == orderNumber) {
                    isProcessed = true;
                    break;
                }
            }

            // If the order has not been processed yet, add it to the uniqueOrders array
            if (!isProcessed) {
                OrderInfo order;
                order.orderNumber = orderNumber;
                order.profit = profitInCurrency; // Store the exact profit in money (currency)
                ArrayResize(uniqueOrders, ArraySize(uniqueOrders) + 1);
                uniqueOrders[ArraySize(uniqueOrders) - 1] = order;

                // Track processed orders to avoid duplicates
                ArrayResize(processedOrders, ArraySize(processedOrders) + 1);
                processedOrders[ArraySize(processedOrders) - 1] = orderNumber;
            }
        }
    }

    // Step 2: Check if there are any unique orders before proceeding
    if (ArraySize(uniqueOrders) == 0) {
         // Print("No orders to process. No web request will be made.");
        return; // Exit the function if no orders are found
    }

    // Step 3: Create JSON data from the unique orders and include the total floating profit
    jsonData = "{\"floating_profit\":\"" + DoubleToString(totalFloatingProfit, 2) + "\",\"orders\":[";
    for (int i = 0; i < ArraySize(uniqueOrders); i++) {
        // Add a + sign for positive values
        string profitStr = DoubleToString(uniqueOrders[i].profit, 2);
        if (uniqueOrders[i].profit > 0) {
            profitStr = "+" + profitStr;
        }

        jsonData += "{\"order\":\"" + uniqueOrders[i].orderNumber + "\",\"profit\":\"" + profitStr + "\"}";
        if (i < ArraySize(uniqueOrders) - 1) {
            jsonData += ","; // Add a comma between JSON objects
        }
    }
    jsonData += "]}"; // Close the orders array and the JSON object

    // Step 4: Send a web request with the orders, profits, and floating profit
    string url = "https://vestorfinance.com/trade-assistant/api/v1/send-profit.php?data=" + jsonData;
     // Print(url);
    char post[]; // Empty post data
    char result[]; // Will hold the result
    string headers;
    int timeout = 5000; // 5 seconds timeout for the request

    int res = WebRequest("POST", url, "", "", timeout, post, 0, result, headers);
    if (res == -1) {
         // Print("Error in WebRequest. Error code: ", GetLastError());
    } else {
         // Print("WebRequest successful! Response: ", CharArrayToString(result, 0, ArraySize(result)));
    }
}

void ResetEA() {
    // Call OnDeinit to perform any necessary cleanup actions
    OnDeinit(REASON_REMOVE);

    // Clear all arrays by resizing them to 0
    ArrayResize(goodPriceEntries, 0);      // Reset buy entries array
    ArrayResize(goodPriceEntriesSell, 0);  // Reset sell entries array
    // Add any other arrays that need resetting
    // Example:
    // ArrayResize(otherArray, 0);

    // Reinitialize the EA by calling OnInit
    OnInit();
}


bool eaResetDone = false;  // Tracks if EA has already been reset after trades are closed

void MonitorAndResetEA() {
    // Check if there are any active trades (positions or orders)
    int totalTrades = PositionsTotal() + OrdersTotal();

    // If no trades are running and EA has not been reset yet
    if (totalTrades == 0 && !eaResetDone) {
        ResetEA();          // Reset EA once when no trades are running
        eaResetDone = true;  // Set the flag to indicate EA has been reset
    } 
    // If trades are running, reset the flag so EA can reset again in the future
    else if (totalTrades > 0) {
        eaResetDone = false;  // Clear the flag, allowing a future reset if trades close
    }
}


//+------------------------------------------------------------------+
//| Function to monitor and set stop loss for the weakest link       |
//+------------------------------------------------------------------+
void EliminateWeakestLink() {
    if (!EliminateWeakLink) return; // Exit if functionality is disabled

    int totalTrades = PositionsTotal();
    ulong weakestTradeTicket = 0;
    double lowestProfit = 0.0;

    // Find the position with the lowest profit
    for (int i = 0; i < totalTrades; i++) {
        ulong ticket = PositionGetTicket(i);  // Ensure ticket is of type ulong
        
        if (PositionSelect(IntegerToString(ticket))) {  // Use PositionSelect with ticket directly
            double profit = PositionGetDouble(POSITION_PROFIT);
            datetime openTime = PositionGetInteger(POSITION_TIME); // Get the position opening time
            
            // Check if the position has been open for at least 5 seconds and is in profit
            if ((TimeCurrent() - openTime >= 5) && profit > 0.0) {
                // Initialize lowest profit with the first valid trade's profit
                if (weakestTradeTicket == 0 || profit < lowestProfit) {
                    lowestProfit = profit;
                    weakestTradeTicket = ticket;
                }
            }
        }
    }

    // If no eligible trade is found, exit the function
    if (weakestTradeTicket == 0) return;

    // Select the weakest position by ticket
    if (PositionSelect(IntegerToString(weakestTradeTicket))) {
        double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
        double currentSL = PositionGetDouble(POSITION_SL);  // Get the current stop loss
        long type = PositionGetInteger(POSITION_TYPE);  // Get the position type

        // Check if stop loss adjustment is needed (SL not already at entry)
        if ((type == POSITION_TYPE_BUY && (currentSL == 0 || currentSL < entryPrice)) ||
            (type == POSITION_TYPE_SELL && (currentSL == 0 || currentSL > entryPrice))) {
            if (type == POSITION_TYPE_BUY) {
                // Set stop loss to entry price for BUY position
                trade.PositionModify(weakestTradeTicket, entryPrice, PositionGetDouble(POSITION_TP));
                 // Print("Stop loss set to entry level for weakest BUY position with ticket: ", IntegerToString((int)weakestTradeTicket));
            } else if (type == POSITION_TYPE_SELL) {
                // Set stop loss to entry price for SELL position
                trade.PositionModify(weakestTradeTicket, entryPrice, PositionGetDouble(POSITION_TP));
                 // Print("Stop loss set to entry level for weakest SELL position with ticket: ", IntegerToString((int)weakestTradeTicket));
            }
        }
    }
}



//+------------------------------------------------------------------+
//| Equity Protection Function                                       |
//+------------------------------------------------------------------+
void EquityProtect() {
    if (!EnableEquityProtect) return; // Exit if equity protection is disabled

    // Get the total floating profit or loss for all trades in the terminal
    double totalFloatingProfit = AccountInfoDouble(ACCOUNT_PROFIT);

    // Check if the total floating profit meets the specified thresholds
    if (totalFloatingProfit >= CloseWhenProfitInMoney) {
         // Print("Equity protection activated: Closing all trades due to profit threshold.");
        CloseAllGlobal(); // Call to close all trades when profit threshold is met
    } else if (totalFloatingProfit <= -CloseWhenLossInMoney) {
         // Print("Equity protection activated: Closing all trades due to loss threshold.");
        CloseAllGlobal(); // Call to close all trades when loss threshold is met
    }
}


//REAL TIME PROFIT TRACKING



//+------------------------------------------------------------------+
//| Round to 2 decimal places for accurate comparison                |
//+------------------------------------------------------------------+
double RoundToTwoDecimals(double value) {
    return NormalizeDouble(value, 2);
}


//Proft Trailing with Parabolic
//+------------------------------------------------------------------+
//| Profit Trailing Management Function                              |
//+------------------------------------------------------------------+
void ManageProfitTrailing() {
    Comment("Trailing Profit Running");
    double currentTotalProfit = AccountInfoDouble(ACCOUNT_PROFIT);

    // Check if profit has reached or exceeded the start threshold
    if (currentTotalProfit >= StartTrailingWhenInProFitMoney) {
        if (!trailingActivated) {
            // Activate trailing for the first time
            trailingActivated = true;
            highestProfitLevel = currentTotalProfit;

            // Determine effective lock percentage dynamically if needed
            double effectiveLockPercentage = LockingAmountPercentage;
            if(EnableParabolicLock) {
                // At initial activation, no steps have been taken yet
                effectiveLockPercentage = LockingAmountPercentage;
            }

            lockProfitLevel = highestProfitLevel * (effectiveLockPercentage / 100.0);
            ProfitBGColor = C'1,18,252';
            ProfitMessage = ("Trailing activated. Initial lock level: " 
                             + DoubleToString(lockProfitLevel,2) + " " + AccountCurrency);
        }
        else if (currentTotalProfit > highestProfitLevel) {
            // Update highest profit and adjust lock level if a new high is reached
            highestProfitLevel = currentTotalProfit;

            double effectiveLockPercentage = LockingAmountPercentage; // base percentage
            if(EnableParabolicLock) {
                // Calculate how much profit is above the initial threshold
                double profitAbove = highestProfitLevel - StartTrailingWhenInProFitMoney;
                // Determine the size of each step based on the input StepSizePercentage
                double stepSize = StartTrailingWhenInProFitMoney * (StepSizePercentage/100.0);
                // Count how many full steps have been completed
                int steps = 0;
                if(stepSize > 0) {
                    steps = (int)(profitAbove / stepSize);
                }
                // Increase the base percentage by ParabolicIncrement for each completed step
                effectiveLockPercentage += steps * ParabolicIncrement;
            }

            // Update lock level using the effective (possibly dynamic) percentage
            lockProfitLevel = highestProfitLevel * (effectiveLockPercentage / 100.0);

            ProfitBGColor = C'1,18,252';
            ProfitMessage = ("Lock level updated to: " 
                             + DoubleToString(lockProfitLevel,2) + " " + AccountCurrency +
                             " | Highest Profit: " 
                             + DoubleToString(highestProfitLevel,2) + " " + AccountCurrency);
        }
    }

    // Close trades if profit falls to or below the lock level
    if (trailingActivated && currentTotalProfit <= lockProfitLevel) {
        ProfitMessage = ("Closed all at Profit level: " 
                         + DoubleToString(lockProfitLevel,2) + " " + AccountCurrency +
                         " | Highest Profit: " + DoubleToString(highestProfitLevel,2) + " " + AccountCurrency);
                         
        LastClosedProfit = DoubleToString(lockProfitLevel);
        GlobalVariableSet("CLOSE_ALL_TRADES", 1.0);  // Trigger Close Trade workers
        Print("Close all trades triggered.");
        CloseAllGlobal();
        ResetTrailing();
        ProfitBGColor = C'22,22,22';
        ProfitMessage = ("No Lock | Last Trade +" 
                         + DoubleToString(LastClosedProfit,2) +
                         " | Highest Profit: " + DoubleToString(highestProfitLevel,2) + " " + AccountCurrency);
    }
    
    if (GlobalVariableGet("CLOSE_ALL_TRADES") == 0.0 && OrdersTotal() == 0 && Trigger_Close_All) {
      // Print("All trades successfully closed.");
      }
}

//+------------------------------------------------------------------+
//| Function to Reset Trailing Variables                             |
//+------------------------------------------------------------------+
void ResetTrailing() {
    trailingActivated = false;
    highestProfitLevel = 0.0;
    lockProfitLevel = 0.0;
     // Print("DEBUG: Trailing variables reset. Ready for the next cycle.");
}



int TradeCount() {
    int count = 0;

    // Loop through all open orders by their ticket numbers
    for (int i = 0; i < PositionsTotal(); i++) {
        ulong ticket = PositionGetTicket(i); // Get the ticket number for each position
        if (PositionSelectByTicket(ticket)) { // Select the position by its ticket
            count++; // Increment the counter for each active trade
        }
    }
    

    return count; // Return the total count of running trades
    
}



input bool Sunday   = true;
input bool Monday   = true;
input bool Tuesday  = true;
input bool Wednesday= true;
input bool Thursday = true;
input bool Friday   = true;
input bool Saturday = true;

bool WeekDays[7];

// Initialize trading days array
void WeekDays_Init() {
    WeekDays[0] = Sunday;
    WeekDays[1] = Monday;
    WeekDays[2] = Tuesday;
    WeekDays[3] = Wednesday;
    WeekDays[4] = Thursday;
    WeekDays[5] = Friday;
    WeekDays[6] = Saturday;
}

double GetProfit(datetime from_date, datetime to_date) {
    double totalProfit = 0.0;

    // Select deals within the specified range
    if (HistorySelect(from_date, to_date)) {
        for (int i = HistoryDealsTotal() - 1; i >= 0; i--) {
            ulong deal_ticket = HistoryDealGetTicket(i);

            // Check if it's a closed deal (DEAL_ENTRY_OUT)
            if (HistoryDealGetInteger(deal_ticket, DEAL_ENTRY) == DEAL_ENTRY_OUT) {
                double profit = HistoryDealGetDouble(deal_ticket, DEAL_PROFIT);
                double commission = HistoryDealGetDouble(deal_ticket, DEAL_COMMISSION);
                double swap = HistoryDealGetDouble(deal_ticket, DEAL_SWAP);
                
                // Accumulate total profit including commission and swap
                totalProfit += profit + commission + swap;
            }
        }
    }
    return totalProfit;
}

// Function to get today's profit
double GetTodayProfit() {
    datetime todayStart = StringToTime(TimeToString(TimeLocal(), TIME_DATE) + " 00:00:00");
    datetime currentTime = TimeLocal();
    return GetProfit(todayStart, currentTime);
}

// Function to get this week's profit (from Sunday to current time)
double GetThisWeekProfit() {
    MqlDateTime stm;
    TimeToStruct(TimeLocal(), stm);
    datetime thisSunday = TimeLocal() - stm.day_of_week * 86400;
    return GetProfit(thisSunday, TimeLocal());
}

// Function to get last week's profit (from previous Sunday to Saturday)
double GetLastWeekProfit() {
    MqlDateTime stm;
    TimeToStruct(TimeLocal(), stm);
    datetime lastSunday = TimeLocal() - (stm.day_of_week + 7) * 86400;
    datetime lastSaturday = lastSunday + 6 * 86400 + 86399;
    return GetProfit(lastSunday, lastSaturday);
}

// Function to get last month's profit
double GetLastMonthProfit() {
    MqlDateTime currentTimeStruct;
    TimeToStruct(TimeLocal(), currentTimeStruct);

    // Calculate the first day of the previous month
    if (currentTimeStruct.mon == 1) {
        currentTimeStruct.mon = 12;
        currentTimeStruct.year -= 1;
    } else {
        currentTimeStruct.mon -= 1;
    }
    currentTimeStruct.day = 1;
    currentTimeStruct.hour = 0;
    currentTimeStruct.min = 0;
    currentTimeStruct.sec = 0;
    datetime monthStart = StructToTime(currentTimeStruct);

    // Calculate the last day of the previous month
    currentTimeStruct.mon += 1;
    if (currentTimeStruct.mon > 12) {
        currentTimeStruct.mon = 1;
        currentTimeStruct.year += 1;
    }
    currentTimeStruct.day = 1;
    datetime monthEnd = StructToTime(currentTimeStruct) - 1;

    return GetProfit(monthStart, monthEnd);
}

// Function to get last year's profit
double GetLastYearProfit() {
    MqlDateTime currentTimeStruct;
    TimeToStruct(TimeLocal(), currentTimeStruct);

    // Calculate the first day of the previous year
    currentTimeStruct.year -= 1;
    currentTimeStruct.mon = 1;
    currentTimeStruct.day = 1;
    currentTimeStruct.hour = 0;
    currentTimeStruct.min = 0;
    currentTimeStruct.sec = 0;
    datetime yearStart = StructToTime(currentTimeStruct);

    // Calculate the last day of the previous year
    currentTimeStruct.year += 1;
    datetime yearEnd = StructToTime(currentTimeStruct) - 1;

    return GetProfit(yearStart, yearEnd);
}

// Function to get all-time profit
double GetAllTimeProfit() {
    // Select all deals from the beginning of the account history
    if (!HistorySelect(0, TimeLocal())) {
         // Print("Failed to select history for all time.");
        return 0.0;
    }

    double totalProfit = 0.0;
    for (int i = HistoryDealsTotal() - 1; i >= 0; i--) {
        ulong deal_ticket = HistoryDealGetTicket(i);

        // Check if it's a closed deal (DEAL_ENTRY_OUT)
        if (HistoryDealGetInteger(deal_ticket, DEAL_ENTRY) == DEAL_ENTRY_OUT) {
            double profit = HistoryDealGetDouble(deal_ticket, DEAL_PROFIT);
            double commission = HistoryDealGetDouble(deal_ticket, DEAL_COMMISSION);
            double swap = HistoryDealGetDouble(deal_ticket, DEAL_SWAP);

            // Accumulate total profit including commission and swap
            totalProfit += profit + commission + swap;
        }
    }
    return totalProfit;
}

// Function to get unrealized (floating) profit
double GetUnrealizedProfit() {
    double floatingProfit = 0.0;
    int totalPositions = PositionsTotal();

    for (int i = 0; i < totalPositions; i++) {
        ulong ticket = PositionGetTicket(i);
        if (PositionSelect(IntegerToString(ticket))) {
            floatingProfit += PositionGetDouble(POSITION_PROFIT);
        }
    }
    return floatingProfit;
}

void SendProfitData() {
    // Retrieve profit data
    double lastMonthProfit = GetLastMonthProfit();
    double lastWeekProfit = GetLastWeekProfit();
    double thisWeekProfit = GetThisWeekProfit();
    double todayProfit = GetTodayProfit(); // Today's profit
    double lastYearProfit = GetLastYearProfit();
    double allTimeProfit = GetAllTimeProfit();
    double unrealizedProfit = GetUnrealizedProfit();

    // Retrieve broker name, balance, and account currency symbol
    string brokerName = AccountInfoString(ACCOUNT_COMPANY);
    double balance = AccountInfoDouble(ACCOUNT_BALANCE);
    string currency = AccountInfoString(ACCOUNT_CURRENCY); // Correctly get the account currency symbol (e.g., USD, ZAR)

    // Construct the base URL
    string url = "https://vestorfinance.com/trade-assistant/api/v1/profit-updater.php";
    
    // Construct the URL parameters
    string parameters = 
        "?mt5_number=" + IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN)) +
        "&broker_name=" + brokerName +
        "&balance=" + DoubleToString(balance, 2) +
        "&currency=" + currency + // Include the actual currency symbol
        "&all_time_profit=" + DoubleToString(allTimeProfit, 2) +
        "&last_year_profit=" + DoubleToString(lastYearProfit, 2) +
        "&last_month_profit=" + DoubleToString(lastMonthProfit, 2) +
        "&last_week_profit=" + DoubleToString(lastWeekProfit, 2) +
        "&this_week_profit=" + DoubleToString(thisWeekProfit, 2) +
        "&today_profit=" + DoubleToString(todayProfit, 2) +
        "&unrealised_profit=" + DoubleToString(unrealizedProfit, 2);

    // Full URL with parameters
    string fullUrl = url + parameters;

     // // Print the full constructed URL for debugging
     // // Print("Constructed URL: ", fullUrl);

    // Use the existing ReadMessage function to send the request
    string response = ReadMessage(fullUrl);

     // // Print the server response
    if (StringLen(response) > 0) {
         // Print("Data sent successfully. Response: ", response);
    } else {
         // Print("Failed to send data. No response received.");
    }
}


//+------------------------------------------------------------------+
//| Function to count the total number of trades for a specific symbol |
//+------------------------------------------------------------------+
int TradeCountBySymbol(string symbol)
{
    int count = 0;

    // Loop through all open positions
    for (int i = 0; i < PositionsTotal(); i++)
    {
        ulong ticket = PositionGetTicket(i);
        if (PositionSelectByTicket(ticket))
        {
            // Check if the position matches the specified symbol
            if (PositionGetString(POSITION_SYMBOL) == symbol)
            {
                count++;
            }
        }
    }
    return count;
}


//+------------------------------------------------------------------+
//| Function to check if the max trades per symbol limit is reached   |
//+------------------------------------------------------------------+
bool CheckMaxNumberOfTradesPerSymbol(string symbol)
{
    int symbolCount = TradeCountBySymbol(symbol);
    return symbolCount >= MaxNumberOfTradesPerSymbol;
}

//+------------------------------------------------------------------+
//| Function to check if the max trades ever limit is reached         |
//+------------------------------------------------------------------+
bool CheckMaxNumberOfTradesEver()
{
    int totalTrades = TradeCount();
    return totalTrades >= MaxNumberOfTradesEver;
}


//+------------------------------------------------------------------+
//| Function to check if the max trades per order comment limit is   |
//| reached                                                          |
//+------------------------------------------------------------------+
bool CheckMaxNumberOfTradesPerOrderComment(string comment)
{
    int commentCount = TradeCountByComment(comment);
    return commentCount >= MaxNumberOfTradesPerOrderNumber;
}

//+------------------------------------------------------------------+
//| Function to count the number of positions with a given comment   |
//| using PositionSelectByTicket rather than positional index        |
//+------------------------------------------------------------------+
int TradeCountByComment(string comment)
{
   int count = 0;
   int total = PositionsTotal();
   for(int i = 0; i < total; i++)
   {
       // Get the ticket of the i-th position.
       ulong ticket = PositionGetTicket(i);
       // Use PositionSelectByTicket to select the position.
       if(PositionSelectByTicket(ticket))
       {
           if(PositionGetString(POSITION_COMMENT) == comment)
              count++;
       }
   }
   return count;
}

//+------------------------------------------------------------------+
//| Function to ensure specified symbols are visible in Market Watch |
//+------------------------------------------------------------------+
void EnsureSymbolsInMarketWatch(string symbolsList)
{
    // Split the input string into individual symbols using a comma as a delimiter
    string symbols[];
    int symbolCount = StringSplit(symbolsList, ',', symbols);

    // Loop through each symbol and ensure it's visible in Market Watch
    for (int i = 0; i < symbolCount; i++)
    {
        string symbol = symbols[i];

        // Check if the symbol is already available in Market Watch
        if (!SymbolSelect(symbol, true))
        {
             // Print("Failed to add symbol: ", symbol, " to Market Watch");
        }
        else
        {
             // Print("Symbol added to Market Watch: ", symbol);
        }
    }
}


void CreateLogo() {
   string LogoName = "Logo";
   ObjectCreate(ChartID(), ObjPrefix+LogoName, OBJ_BITMAP_LABEL, 0, 0, 0);
   ObjectSetString(ChartID(), ObjPrefix+LogoName, OBJPROP_BMPFILE, "::Images\\arrissa-api-logo.bmp");
   ObjectSetInteger(ChartID(), ObjPrefix+LogoName, OBJPROP_HIDDEN, true);
   ObjectSetInteger(ChartID(), ObjPrefix+LogoName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(ChartID(), ObjPrefix+LogoName, OBJPROP_CORNER, 0);   
   ObjectSetInteger(ChartID(), ObjPrefix+LogoName, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
   ObjectSetInteger(ChartID(), ObjPrefix+LogoName, OBJPROP_XDISTANCE, 5); 
   ObjectSetInteger(ChartID(), ObjPrefix+LogoName, OBJPROP_YDISTANCE, 45);
   return;
}

//+------------------------------------------------------------------+
//| Function to create and setup the Close All Trades button         |
//+------------------------------------------------------------------+
bool CreateLockInfoButton()
{
    // Create a button
    if (!ObjectCreate(0, buttonName4, OBJ_BUTTON, 0, 0, 0))
        return false;  // Return false if creation failed

    // Set button properties for position
    ObjectSetInteger(0, buttonName4, OBJPROP_CORNER, CORNER_LEFT_LOWER); // Position from the bottom-right corner
    ObjectSetInteger(0, buttonName4, OBJPROP_XDISTANCE, 5); // 20 pixels from the right edge of the chart
    ObjectSetInteger(0, buttonName4, OBJPROP_YDISTANCE, 32); // 20 pixels from the bottom edge of the chart

    // Set button dimensions
    ObjectSetInteger(0, buttonName4, OBJPROP_XSIZE, 500);    // Width of the button
    ObjectSetInteger(0, buttonName4, OBJPROP_YSIZE, 35);     // Height of the button
    
    //CountryNames();

    // Set text on the button
   ObjectSetString(0, buttonName4, OBJPROP_TEXT, ProfitMessage);

    // Set colors
    ObjectSetInteger(0, buttonName4, OBJPROP_COLOR, clrWhite); // Set text color to white
    ObjectSetInteger(0, buttonName4, OBJPROP_BGCOLOR, ProfitBGColor);  // Set background color to red
    ObjectSetInteger(0, buttonName4, OBJPROP_BORDER_COLOR,ProfitBGColor); // Set border color to black
    ObjectSetInteger(0, buttonName4, OBJPROP_WIDTH, 10);

    return true; // Return true if creation was successful
}




void ArrissaAutoTrade() {
    if ((TimeCurrent() >= GetTime(StartTime, TimeCurrent()) &&
         TimeCurrent() < GetTime(EndTime, TimeCurrent()) && AllowTradingTime) ||
        !AllowTradingTime) {

        if (!BlockBot) {
            string message;
            // Only allow trading manually if explicitly specified
            if (ManualSignal) {
                message = ReadMessage("https://arrissa.trade/auto_trade_api.php?username=" + UserName + "&api_key=" + APIkey);
                // Print(message);
            }
            else {
                return;
            }

            jjs.Clear();
            StringTrimLeft(message);
            StringTrimRight(message);

            if (jjs.Deserialize(message)) {
                int index = 0;
                while (true) {
                    string symbol = jjs[index]["Symbol"].ToStr();
                    // Symbol Lot Mapping
                    if (symbol == "NASDAQ" || symbol == "US30" || symbol == "GER30") {
                        Lotsize = IndicesLot;
                    }
                    else if (symbol == "XAUUSD") {
                        Lotsize = GoldLot;
                    }
                    else if (symbol == "BTCUSD") {
                        Lotsize = BTCLot;
                    }
                    else {
                        Lotsize = GeneralLot;
                    }
                    // End Symbol Lot Mapping

                    if (StringLen(symbol) > 0) {
                        string ordertype = jjs[index]["OrderType"].ToStr();
                        StringTrimLeft(ordertype);
                        StringTrimRight(ordertype);
                        StringToLower(ordertype);

                        StringTrimLeft(symbol);
                        StringTrimRight(symbol);
                        symbol = MapSymbol(symbol);

                        string TP1s, TP2s, TP3s, TP4s, SLs;
                        double TP1 = -1, TP2 = -1, TP3 = -1, TP4 = -1, SL = -1;
                        double price;
                        string isNew = jjs[index]["isNews"].ToStr();
                        datetime tradeTimestamp = StringToTime(jjs[index]["TimeStamp"].ToStr()) + timeDifference;
                        orderNumber = jjs[index]["Order"].ToStr();
                        // Print("order number:" + orderNumber);
                        string orderTicket = jjs[index]["Ticket"].ToStr();

                        // Check if the timestamp has already been processed
                        bool isTimestampProcessed = false;
                        for (int i = 0; i < ArraySize(handledTradeTimestamps); i++) {
                            if (handledTradeTimestamps[i] == tradeTimestamp) {
                                isTimestampProcessed = true;
                                break;
                            }
                        }

                        if (!isTimestampProcessed) { // Proceed only if timestamp is new
                            if (((isNew == "TRUE" && AllowTradeNews) ||
                                 (!AllowTradeNews && isNew == "FALSE") ||
                                 (isNew == "FALSE" && AllowTradeNews)) &&
                                (int)TimeCurrent() - (int)tradeTimestamp <= 1200 &&
                                tradeTimestamp != 0 &&
                                IsTradeAllowed(symbol, DayOfWeekConverter())) {

                                if (StringFind(signalData, "#" + orderNumber) < 0) {
                                    signalData += "#" + orderNumber;
                                    string comment = ExpertName + orderNumber;

                                    // Parse additional trade parameters
                                    TP1s = jjs[index]["TP1"].ToStr();
                                    TP2s = jjs[index]["TP2"].ToStr();
                                    TP3s = jjs[index]["TP3"].ToStr();
                                    TP4s = jjs[index]["TP4"].ToStr();
                                    SLs = jjs[index]["recommendedSL"].ToStr();

                                    if (StringLen(TP1s) > 0)
                                        TP1 = StringToDouble(TP1s);
                                    if (StringLen(TP2s) > 0)
                                        TP2 = StringToDouble(TP2s);
                                    if (StringLen(TP3s) > 0)
                                        TP3 = StringToDouble(TP3s);
                                    if (StringLen(TP4s) > 0)
                                        TP4 = StringToDouble(TP4s);
                                    if (StringLen(SLs) > 0)
                                        SL = StringToDouble(SLs);

                                    price = StringToDouble(jjs[index]["Price"].ToStr());

                                    if (StringLen(symbol) > 0) {
                                        // Execute trades based on order type
                                        if (ordertype == "buy" &&
                                            (Direction == Both || Direction == BuyOnly) &&
                                            symbol != "") {
                                            if (!CheckMaxNumberOfTradesPerSymbol(symbol) &&
                                                !CheckMaxNumberOfTradesEver() &&
                                                !CheckMaxNumberOfTradesPerOrderComment(comment)) {
                                                Buy(symbol, TP1, TP2, TP3, TP4, SL, orderNumber);
                                            }
                                            else {
                                                // Print("Max Number of Trades Reached");
                                            }
                                        }
                                        else if (ordertype == "buy limit" &&
                                                 (Direction == Both || Direction == BuyOnly) &&
                                                 symbol != "") {
                                            if (!CheckMaxNumberOfTradesPerSymbol(symbol) &&
                                                !CheckMaxNumberOfTradesEver() &&
                                                !CheckMaxNumberOfTradesPerOrderComment(comment)) {
                                                BuyLimit(symbol, TP1, TP2, TP3, TP4, SL, price, orderTicket);
                                            }
                                            else {
                                                // Print("Max Number of Trades Reached");
                                            }
                                        }
                                        else if (ordertype == "buy stop" &&
                                                 (Direction == Both || Direction == BuyOnly) &&
                                                 symbol != "") {
                                            if (!CheckMaxNumberOfTradesPerSymbol(symbol) &&
                                                !CheckMaxNumberOfTradesEver() &&
                                                !CheckMaxNumberOfTradesPerOrderComment(comment)) {
                                                BuyStop(symbol, TP1, TP2, TP3, TP4, SL, price, orderTicket);
                                            }
                                            else {
                                                // Print("Max Number of Trades Reached");
                                            }
                                        }
                                        else if (ordertype == "sell" &&
                                                 (Direction == Both || Direction == SellOnly) &&
                                                 symbol != "") {
                                            if (!CheckMaxNumberOfTradesPerSymbol(symbol) &&
                                                !CheckMaxNumberOfTradesEver() &&
                                                !CheckMaxNumberOfTradesPerOrderComment(comment)) {
                                                Sell(symbol, TP1, TP2, TP3, TP4, SL, orderNumber);
                                            }
                                            else {
                                                // Print("Max Number of Trades Reached");
                                            }
                                        }
                                        else if (ordertype == "sell limit" &&
                                                 (Direction == Both || Direction == SellOnly) &&
                                                 symbol != "") {
                                            if (!CheckMaxNumberOfTradesPerSymbol(symbol) &&
                                                !CheckMaxNumberOfTradesEver() &&
                                                !CheckMaxNumberOfTradesPerOrderComment(comment)) {
                                                SellLimit(symbol, TP1, TP2, TP3, TP4, SL, price, orderTicket);
                                            }
                                            else {
                                                // Print("Max Number of Trades Reached");
                                            }
                                        }
                                        else if (ordertype == "sell stop" &&
                                                 (Direction == Both || Direction == SellOnly) &&
                                                 symbol != "") {
                                            if (!CheckMaxNumberOfTradesPerSymbol(symbol) &&
                                                !CheckMaxNumberOfTradesEver() &&
                                                !CheckMaxNumberOfTradesPerOrderComment(comment)) {
                                                SellStop(symbol, TP1, TP2, TP3, TP4, SL, price, orderTicket);
                                            }
                                            else {
                                                // Print("Max Number of Trades Reached");
                                            }
                                        }
                                    }

                                    // Add the current timestamp to the processed list
                                    ArrayResize(handledTradeTimestamps, ArraySize(handledTradeTimestamps) + 1);
                                    handledTradeTimestamps[ArraySize(handledTradeTimestamps) - 1] = tradeTimestamp;
                                }
                            }
                        }
                    }
                    else {
                        break;
                    }
                    index++;
                }
            }

            // Access money management
            message = ReadMessage("https://arrissa.trade/trade-management-api.php?username=" + UserName + "&api_key=" + APIkey);

            jjs.Clear();
            StringTrimLeft(message);
            StringTrimRight(message);

            // Print("Fetched JSON message: " + message); // Log the fetched JSON message

            // Define a static array to store processed timestamps
            static string processedTimestamps[];

            if (jjs.Deserialize(message)) {
                // Print("JSON deserialization successful.");

                int index = 0;
                while (true) {
                    string symbol = jjs[index]["Symbol"].ToStr();

                    if (StringLen(symbol) > 0) {
                        StringTrimLeft(symbol);
                        StringTrimRight(symbol);
                        symbol = MapSymbol(symbol);
                        orderNumber = jjs[index]["Order"].ToStr();
                        string action = jjs[index]["Action"].ToStr();      // Retrieve the "Action" field
                        string timestamp = jjs[index]["Timestamp"].ToStr(); // Retrieve the "Timestamp" field

                        //Print("Processing index: " + IntegerToString(index) + ", Symbol: " + symbol + ", Order: " + orderNumber + ", Action: " + action + ", Timestamp: " + timestamp);

                        // Check if the timestamp has already been processed
                        bool alreadyProcessed = false;
                        for (int i = 0; i < ArraySize(processedTimestamps); i++) {
                            if (processedTimestamps[i] == timestamp) {
                                alreadyProcessed = true;
                                // Print("Action with Timestamp " + timestamp + " has already been processed. Skipping.");
                                break;
                            }
                        }

                        if (!alreadyProcessed) {
                            if (action == "Close50") {
                                CloseHalfTrades(orderNumber, symbol);
                            }
                            else if (action == "CloseAll") {
                                FindAndCloseTrade(orderNumber, symbol);
                                
                            }
                            else if (action == "DeleteBreakEven") {
                                RemoveAllStopLosses(orderNumber, symbol);
                            }
                            else if (action == "Lock50") {
                                SetStopLossAtMidpoint(orderNumber, symbol);
                            }
                            else if (action == "BreakEvenGlobal") {
                                AdjustStopLossToEntry();
                            }
                            else if (action == "DeleteBreakEvenGlobal") {
                                RemoveAllStopLossesGlobal();
                            }
                            else if (action == "CloseAllGlobal") {
                                CloseAllGlobal();
                            }

                            // Add the processed timestamp to the list
                            ArrayResize(processedTimestamps, ArraySize(processedTimestamps) + 1);
                            processedTimestamps[ArraySize(processedTimestamps) - 1] = timestamp;
                        }
                    }
                    else {
                        // Print("Empty or invalid symbol at index: " + IntegerToString(index) + ". Exiting loop.");
                        break;
                    }
                    index++;
                }
            }
            else {
                // Print("JSON deserialization failed.");
            }
        }
    }
}



void SetEAFromInternetVariables(){

//+------------------------------------------------------------------+
//| Example: RetrieveEASettings.mq5                                  |
//| Demonstrates fetching all JSON fields from ea_settings_api.php   |
//| and assigning them to MQL5 variables named *_json.               |
//+------------------------------------------------------------------+
   // Build the full URL
   string message = ReadMessage("https://arrissa.trade/settings/ea_settings_api.php?username=" + UserName + "&api_key=" + APIkey);

   // Clear the JSON parser and trim the returned message
   jjs.Clear();
   StringTrimLeft(message);
   StringTrimRight(message);

   // Print("Fetched JSON message: " + message); // (Optional) Log the fetched JSON message
   
   // Attempt to deserialize the JSON
   if (jjs.Deserialize(message))
     {
      // Print("JSON deserialization successful.");

      // String fields
      bool ActivateArrissaAutoTrader_json   = jjs["ActivateArrissaAutoTrader"].ToBool();
      string Direction_json                   = jjs["Direction"].ToStr();
      string ListOfSymbolFormat_json          = jjs["ListOfSymbolFormat"].ToStr();
      string MatchesFromClient_json           = jjs["MatchesFromClient"].ToStr();
      
      // Boolean fields
      bool AllowTradeNews_json                = jjs["AllowTradeNews"].ToBool();
      bool UseGoodPriceMode_json              = jjs["UseGoodPriceMode"].ToBool();
      bool UseGoodPriceExpansion_json         = jjs["UseGoodPriceExpansion"].ToBool();
      bool EnableIncrementalMartingale_json   = jjs["EnableIncrementalMartingale"].ToBool();
      bool AllowMartingale_json               = jjs["AllowMartingale"].ToBool();
      bool EnableEquityProtect_json           = jjs["EnableEquityProtect"].ToBool();
      bool ActivateProfitTrailing_json        = jjs["ActivateProfitTrailing"].ToBool();
      bool EnableParabolicLock_json           = jjs["EnableParabolicLock"].ToBool();
      bool ManualSignal_json                  = jjs["ManualSignal"].ToBool();
      
      // Integer fields
      int MaxNumberOfTradesPerOrderNumber_json = jjs["MaxNumberOfTradesPerOrderNumber"].ToInt();
      int ExpansionPercentage_json             = jjs["ExpansionPercentage"].ToInt();
      int GoodByPointsGold_json                = jjs["GoodByPointsGold"].ToInt();
      int GoodByPointsCurrencies_json          = jjs["GoodByPointsCurrencies"].ToInt();
      int GoodByPointsUSDJPY_json              = jjs["GoodByPointsUSDJPY"].ToInt();
      int GoodByPointsIndices_json             = jjs["GoodByPointsIndices"].ToInt();
      int GoodByPointsBTCUSD_json              = jjs["GoodByPointsBTCUSD"].ToInt();
      int GoodByPointsBTCJPY_json              = jjs["GoodByPointsBTCJPY"].ToInt();
      int GoodByPointsBTCXAU_json              = jjs["GoodByPointsBTCXAU"].ToInt();
      int GoodbyPointsVolatility10Index_json   = jjs["GoodbyPointsVolatility10Index"].ToInt();
      int GoodbyPointsVolatility25Index_json   = jjs["GoodbyPointsVolatility25Index"].ToInt();
      int GoodbyPointsVolatility50Index_json   = jjs["GoodbyPointsVolatility50Index"].ToInt();
      int GoodbyPointsVolatility75Index_json   = jjs["GoodbyPointsVolatility75Index"].ToInt();
      int GoodbyPointsVolatility100Index_json  = jjs["GoodbyPointsVolatility100Index"].ToInt();
      int GoodbyPointsVolatility10_1s_Index_json  = jjs["GoodbyPointsVolatility10_1s_Index"].ToInt();
      int GoodbyPointsVolatility25_1s_Index_json  = jjs["GoodbyPointsVolatility25_1s_Index"].ToInt();
      int GoodbyPointsVolatility50_1s_Index_json  = jjs["GoodbyPointsVolatility50_1s_Index"].ToInt();
      int GoodbyPointsVolatility75_1s_Index_json  = jjs["GoodbyPointsVolatility75_1s_Index"].ToInt();
      int GoodbyPointsVolatility100_1s_Index_json = jjs["GoodbyPointsVolatility100_1s_Index"].ToInt();
      int IncrementalStep_json                 = jjs["IncrementalStep"].ToInt();
      int MartingaleMultiplier_json            = jjs["MartingaleMultiplier"].ToInt();
      int CloseWhenProfitInMoney_json          = jjs["CloseWhenProfitInMoney"].ToInt();
      int CloseWhenLossInMoney_json            = jjs["CloseWhenLossInMoney"].ToInt();
      int StartTrailingWhenInProFitMoney_json    = jjs["StartTrailingWhenInProFitMoney"].ToInt();
      int LockingAmountPercentage_json         = jjs["LockingAmountPercentage"].ToInt();
      int ParabolicIncrement_json              = jjs["ParabolicIncrement"].ToInt();
      int StepSizePercentage_json              = jjs["StepSizePercentage"].ToInt();
      int TradeStartHour_json                  = jjs["TradeStartHour"].ToInt();
      int TradeEndHour_json                    = jjs["TradeEndHour"].ToInt();
      int MaxNumberOfTradesPerSymbol_json      = jjs["MaxNumberOfTradesPerSymbol"].ToInt();
      int MaxNumberOfTradesEver_json           = jjs["MaxNumberOfTradesEver"].ToInt();
      
      // Double fields
      double GeneralLot_json                   = jjs["GeneralLot"].ToDbl();
      double IndicesLot_json                   = jjs["IndicesLot"].ToDbl();
      double GoldLot_json                      = jjs["GoldLot"].ToDbl();
      double BTCLot_json                       = jjs["BTCLot"].ToDbl();
      double Volatility10IndexLot_json         = jjs["Volatility10IndexLot"].ToDbl();
      double Volatility25IndexLot_json         = jjs["Volatility25IndexLot"].ToDbl();
      double Volatility50IndexLot_json         = jjs["Volatility50IndexLot"].ToDbl();
      double Volatility75IndexLot_json         = jjs["Volatility75IndexLot"].ToDbl();
      double Volatility100IndexLot_json        = jjs["Volatility100IndexLot"].ToDbl();
      double Volatility10_1s_IndexLot_json      = jjs["Volatility10_1s_IndexLot"].ToDbl();
      double Volatility25_1s_IndexLot_json      = jjs["Volatility25_1s_IndexLot"].ToDbl();
      double Volatility50_1s_IndexLot_json      = jjs["Volatility50_1s_IndexLot"].ToDbl();
      double Volatility75_1s_IndexLot_json      = jjs["Volatility75_1s_IndexLot"].ToDbl();
      double Volatility100_1s_IndexLot_json     = jjs["Volatility100_1s_IndexLot"].ToDbl();
      
      //Symbol Trailing From Internet Variables
     bool EnableManageSymbolProfitTrailing_json          = jjs["EnableManageSymbolProfitTrailing"].ToBool();
     int StartTrailingWhenInProFitMoney_symbol_json     = jjs["StartTrailingWhenInProFitMoney_symbol"].ToInt();
     int LockingAmountPercentage_symbol_json            = jjs["LockingAmountPercentage_symbol"].ToInt();
     bool EnableParabolicLock_symbol_json               = jjs["EnableParabolicLock_symbol"].ToBool();  
     int ParabolicIncrement_symbol_json                 = jjs["ParabolicIncrement_symbol"].ToInt(); 
     int StepSizePercentage_symbol_json                 = jjs["StepSizePercentage_symbol"].ToInt();

      // Now do whatever you need with these variables:
      // (For demo, we'll just print a few of them.)
      //Print("=== EA Settings JSON retrieved ===");
      //Print("UserName_json: ",                  UserName_json);
      //Print("ExpertName_json: ",                ExpertName_json);
      //Print("ActivateOffsetEntry_json: ",        ActivateOffsetEntry_json);
      //Print("OffsetPoints_json: ",              OffsetPoints_json);
      //Print("GeneralLot_json: ",                GeneralLot_json);
      //Print("Volatility100_1s_IndexLot_json: ", Volatility100_1s_IndexLot_json);
      // ... etc.


     
      //Trading Settings
      ActivateArrissaAutoTrader = ActivateArrissaAutoTrader_json; //true/false
      ManualSignal = ManualSignal_json;          // Enable or disable Manual Signal
      Direction = Direction_json; // Trading direction
      AllowTradeNews = AllowTradeNews_json; // Allow trading with news signal
      
      //Position Quantity
      MaxNumberOfTradesPerOrderNumber = MaxNumberOfTradesPerOrderNumber_json;
      MaxNumberOfTradesPerSymbol = MaxNumberOfTradesPerSymbol_json;
      MaxNumberOfTradesEver = MaxNumberOfTradesEver_json;
      
      //Symbol Mapping
      ListOfSymbolFormat = ListOfSymbolFormat_json; // List of master symbol format
      MatchesFromClient = MatchesFromClient_json; // *Change to match your symbols
      
      // Position Sizing General
      GeneralLot = GeneralLot_json; // Lot size for Currencies
      IndicesLot = IndicesLot_json; // Lot size for NASDAQ,US30 & GER30
      GoldLot = GoldLot_json; // Lot size for GOLD (XAUUSD)
      BTCLot = BTCLot_json; // Lot size for BTCUSD
      
      // Position Sizing VIX
      Volatility10IndexLot = Volatility10IndexLot_json; // Lot for VIX 10 Index
      Volatility25IndexLot = Volatility25IndexLot_json; // Lot for VIX 25 Index
      Volatility50IndexLot = Volatility50IndexLot_json; // Lot for VIX 50 Index
      Volatility75IndexLot = Volatility75IndexLot_json; // Lot for VIX 75 Index
      Volatility100IndexLot = Volatility100IndexLot_json; // Lot for VIX 100 Index
      Volatility10_1s_IndexLot = Volatility10_1s_IndexLot_json; // Lot for VIX 10 (1s) Index
      Volatility25_1s_IndexLot = Volatility25_1s_IndexLot_json; // Lot for VIX 25 (1s) Index
      Volatility50_1s_IndexLot = Volatility50_1s_IndexLot_json; // Lot for VIX 50 (1s) Index
      Volatility75_1s_IndexLot = Volatility75_1s_IndexLot_json; // Lot for VIX 75 (1s) Index
      Volatility100_1s_IndexLot = Volatility100_1s_IndexLot_json; // Lot for VIX 100 (1s) Index
 
      // Good Price Settings
      UseGoodPriceMode = UseGoodPriceMode_json; // Use Good Price Mode: Yes/No
      UseGoodPriceExpansion = UseGoodPriceExpansion_json; // Use Good Price Expansion: Yes/No
      ExpansionPercentage = ExpansionPercentage_json; // Expansion Percentage (e.g., 20 for 20%)
      
      //Good Price Control
      EnableIncrementalMartingale = EnableIncrementalMartingale_json; // Enable/disable incremental martingale strategy
      IncrementalStep = IncrementalStep_json;           // Incremental step for each trade in the martingale strategy
      AllowMartingale = AllowMartingale_json;             // Enable/disable martingale strategy
      MartingaleMultiplier = MartingaleMultiplier_json; // Multiplier for the martingale strategy
      
      // Good Price General
      GoodByPointsGold = GoodByPointsGold_json; // Good Price Points GOLD
      GoodByPointsCurrencies = GoodByPointsCurrencies_json; // Good Price Points Currencies
      GoodByPointsUSDJPY = GoodByPointsUSDJPY_json; // Good Price Points USDJPY
      GoodByPointsIndices = GoodByPointsIndices_json; // Good Price Points Indices
      GoodByPointsBTCUSD = GoodByPointsBTCUSD_json; // Good Price Points BTCUSD
      GoodByPointsBTCJPY = GoodByPointsBTCJPY_json; // Good Price Points BTCJPY
      GoodByPointsBTCXAU = GoodByPointsBTCXAU_json; // Good Price Points BTCXAU
      
      // Good Price VIX
      GoodbyPointsVolatility10Index = GoodbyPointsVolatility10Index_json; // Good Price Points VIX 10 Index
      GoodbyPointsVolatility25Index = GoodbyPointsVolatility25Index_json; // Good Price Points VIX 25 Index
      GoodbyPointsVolatility50Index = GoodbyPointsVolatility50Index_json; // Good Price Points VIX 50 Index
      GoodbyPointsVolatility75Index = GoodbyPointsVolatility75Index_json; // Good Price Points VIX 75 Index
      GoodbyPointsVolatility100Index = GoodbyPointsVolatility100Index_json; // Good Price Points VIX 100 Index
      GoodbyPointsVolatility10_1s_Index = GoodbyPointsVolatility10_1s_Index_json; // Good Price Points VIX 10 (1s) Index
      GoodbyPointsVolatility25_1s_Index = GoodbyPointsVolatility25_1s_Index_json; // Good Price Points VIX 25 (1s) Index
      GoodbyPointsVolatility50_1s_Index = GoodbyPointsVolatility50_1s_Index_json; // Good Price Points VIX
      GoodbyPointsVolatility75_1s_Index = GoodbyPointsVolatility75_1s_Index_json; // Good Price Points VIX 75 (1s) Index
      GoodbyPointsVolatility100_1s_Index = GoodbyPointsVolatility100_1s_Index_json; // Good Price Points VIX 100 (1s) Index
      
      //Equity Protection
      EnableEquityProtect = EnableEquityProtect_json;              // Enable or disable equity protection
      CloseWhenProfitInMoney = CloseWhenProfitInMoney_json;      // Profit threshold for closing all trades
      CloseWhenLossInMoney = CloseWhenLossInMoney_json;          // Loss threshold for closing all trades
      
      
      // Profity Trailing
      ActivateProfitTrailing = ActivateProfitTrailing_json;          // Enable or disable profit trailing
      StartTrailingWhenInProFitMoney = StartTrailingWhenInProFitMoney_json; // Profit level to start trailing
      LockingAmountPercentage = LockingAmountPercentage_json;      // Percentage of profit to lock
      EnableParabolicLock = EnableParabolicLock_json;                // Enable parabolic lock feature
      ParabolicIncrement = ParabolicIncrement_json;                // Increment in percentage per step (e.g., 50%)
      StepSizePercentage = StepSizePercentage_json;                // Step size percentage (e.g., 30%)
      
      // Profit By Symbol Trailing
      EnableManageSymbolProfitTrailing       = EnableManageSymbolProfitTrailing_json;
      StartTrailingWhenInProFitMoney_symbol  = StartTrailingWhenInProFitMoney_symbol_json;    // Profit to start trailing
      LockingAmountPercentage_symbol         = LockingAmountPercentage_symbol_json;    // % of profit to lock
      EnableParabolicLock_symbol             = EnableParabolicLock_symbol_json;  
      ParabolicIncrement_symbol              = ParabolicIncrement_symbol_json;     // % increment per step
      StepSizePercentage_symbol              = StepSizePercentage_symbol_json;    // % step size
      }
         else
         {
            // Print("JSON deserialization failed.");
         }
      
}

//+------------------------------------------------------------------+
//| Find symbol index in array (–1 if not found)                     |
//+------------------------------------------------------------------+
int ArrayFindSymbol(string &arr[], string symbol)
{
   for(int i=0; i<ArraySize(arr); i++)
      if(arr[i] == symbol)
         return i;
   return -1;
}

//+------------------------------------------------------------------+
//| Aggregate floating profit for a given symbol                     |
//+------------------------------------------------------------------+
double SymbolFloatingProfit(string sym)
{
   double total = 0.0;
   int    cnt   = PositionsTotal();
   for(int i=0; i<cnt; i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) 
         continue;
      if(PositionGetString(POSITION_SYMBOL) != sym) 
         continue;
      total += PositionGetDouble(POSITION_PROFIT);
   }
   return(total);
}

//+------------------------------------------------------------------+
//| Close all positions for a single symbol                          |
//+------------------------------------------------------------------+
void CloseOrdersBySymbol(string sym)
{
   PrintFormat("[%s] Closing all positions for symbol", sym);
   int cnt = PositionsTotal();
   for(int i=cnt-1; i>=0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) 
         continue;
      if(PositionGetString(POSITION_SYMBOL) != sym) 
         continue;

      // Close full position by ticket only (uses default volume)
      if(!trade.PositionClose(ticket))
         PrintFormat("[%s] Failed to close ticket %I64u, error %d", sym, ticket, GetLastError());
      else
         PrintFormat("[%s] Successfully closed ticket %I64u", sym, ticket);
   }
}

//+------------------------------------------------------------------+
//| Reset trailing state for one symbol                              |
//+------------------------------------------------------------------+
void ResetTrailingSymbol(int idx)
{
   tr_activated[idx]     = false;
   tr_highestProfit[idx] = 0.0;
   tr_lockProfit[idx]    = 0.0;
}

//+------------------------------------------------------------------+
//| Profit Trailing Management Function (per-symbol)                 |
//+------------------------------------------------------------------+
void ManageSymbolProfitTrailing()
{
   // 1) Gather unique open symbols
   string openSyms[];
   int    cnt = PositionsTotal();
   for(int i=0; i<cnt; i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) 
         continue;
      string sym = PositionGetString(POSITION_SYMBOL);
      if(ArrayFindSymbol(openSyms, sym) < 0)
      {
         ArrayResize(openSyms, ArraySize(openSyms)+1);
         openSyms[ArraySize(openSyms)-1] = sym;
      }
   }

   // 2) For each symbol, apply trailing logic
   for(int s=0; s<ArraySize(openSyms); s++)
   {
      string sym    = openSyms[s];
      double profit = SymbolFloatingProfit(sym);

      // register or find this symbol in our tracking arrays
      int idx = ArrayFindSymbol(tr_symbols, sym);
      if(idx < 0)
      {
         ArrayResize(tr_symbols,       ArraySize(tr_symbols)+1);
         ArrayResize(tr_activated,     ArraySize(tr_activated)+1);
         ArrayResize(tr_highestProfit, ArraySize(tr_highestProfit)+1);
         ArrayResize(tr_lockProfit,    ArraySize(tr_lockProfit)+1);
         idx = ArraySize(tr_symbols)-1;
         tr_symbols[idx]       = sym;
         tr_activated[idx]     = false;
         tr_highestProfit[idx] = 0.0;
         tr_lockProfit[idx]    = 0.0;
      }

      // 2a) activate trailing once threshold reached
      if(!tr_activated[idx] && profit >= StartTrailingWhenInProFitMoney_symbol)
      {
         tr_activated[idx]     = true;
         tr_highestProfit[idx] = profit;
         double effLock        = LockingAmountPercentage_symbol;
         tr_lockProfit[idx]    = tr_highestProfit[idx] * (effLock/100.0);
         PrintFormat("[%s] Trailing activated at %G", sym, tr_lockProfit[idx]);
         continue;
      }

      // 2b) update on new high profit
      if(tr_activated[idx] && profit > tr_highestProfit[idx])
      {
         tr_highestProfit[idx] = profit;
         double effLock        = LockingAmountPercentage_symbol;
         if(EnableParabolicLock_symbol)
         {
            double above    = tr_highestProfit[idx] - StartTrailingWhenInProFitMoney_symbol;
            double stepSize = StartTrailingWhenInProFitMoney_symbol * (StepSizePercentage_symbol/100.0);
            int    steps    = (stepSize > 0 ? (int)(above/stepSize) : 0);
            effLock        += steps * ParabolicIncrement_symbol;
         }
         tr_lockProfit[idx] = tr_highestProfit[idx] * (effLock/100.0);
         PrintFormat("[%s] New high %G → lock at %G", sym, tr_highestProfit[idx], tr_lockProfit[idx]);
         continue;
      }

      // 2c) close if profit falls to or below lock
      if(tr_activated[idx] && profit <= tr_lockProfit[idx])
      {
         PrintFormat("[%s] Profit %G ≤ lock %G → closing symbol", sym, profit, tr_lockProfit[idx]);
         CloseOrdersBySymbol(sym);
         ResetTrailingSymbol(idx);
      }
   }
}
