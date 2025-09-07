//+------------------------------------------------------------------+
/*
    Sharing-Is-Caring.mq5

*/
//+------------------------------------------------------------------+
//https://www.mql5.com/en/market/product/68484?source=External#description

//https://github.com/wait4signal/sharing-is-caring/blob/main/Sharing-Is-Caring.mq5
/*
Local & Remote copy
One tool can act as provider or receiver of trades
Co-exist with other positions opened manually or from other expert advisors
Can be stopped and restarted at any time without any issues such as deals getting closed mysteriously
Copy same lot or adjust according to your balance and leverage
Partial close/open
Manage max funds to use
One provider can copy to unlimited number of receivers
One receiver can copy from unlimited number of providers
Monitoring using heartbeat checks
*/
/*
Provider:
If “PROVIDER” is selected then the rest of the settings are optional and depending on features used.

Receiver:
If “RECEIVER” then you also need to specify the “PROVIDER_ACCOUNT”
which is the trading account whose trades will be copied.
The rest of the settings are optional depending on features used.


Local vs Remote copy:
[local]
Position data is written by the provider to a csv file. The receiver/s then reads from this file.
This is the preferred method as it is fastest, it is used when the provider and receivers are running on the same machine.
[remote]
if there are receivers running on a remote machine then the provider should be set to also write the data to a remote file location. The remote receivers would then also be set to read from this remote location.

By default, position data is saved locally onto a file named Terminal\Common\Files\Sharing-Is-Caring[providerAccount]-positions.csv
Trades from a remote location also get written to this file prior to use.
*To upload/share trades via ftp, you need to configure ftp server,path and credentials in the FTP tab under options
*Conversely, remote trades are downloaded via http using the "Remote Copy" EA parameters

Monitoring
The copier can be set to send health checks to a monitoring server so that alerts can be sent out if no heartbeat pings are received within a set timeframe.
We recommend the https://healthchecks.io/ platform for this as it is open-source and supports a large number of alerting mechanisms such
as email,telegram,phone call etc.
 Plus it offers up to 20 free monitoring licenses.
Note that your alert interval needs to be longer than the heartbeat interval e.g if heartbeat is set to
5 minutes then on the monitoring server you can set alerting to something like 7 minutes so that you get notified
if the terminal has not sent a ping in 7 minutes.
*Configure the email tab under options for this to work
[global variables]

following global variables can be set at terminal level to control certain program behaviour:

LOG_LEVEL [0]   Sets log level: [0 | 1 | 2 | 3 | 4] where LOG_NONE = 0; LOG_ERROR = 1; LOG_WARN = 2; LOG_INFO = 3; LOG_DEBUG = 4


*/

#property strict

//#include <Expert\Expert.mqh>

//#include <Trade\PositionInfo.mqh>
//#include <Trade\Trade.mqh>
//#include <Trade\SymbolInfo.mqh>
//#include <Trade\AccountInfo.mqh>
#include "TradeUtil.mqh"

enum ENUM_COPY_MODE
  {
   PROVIDER,
   RECEIVER
  };

enum ENUM_LOT_SIZE
  {
   SAME_AS_PROVIDER,
   PROPORTIONAL_TO_BALANCE,
   PROPORTIONAL_TO_FREE_MARGIN
  };

//--- Global Variables
/*
LOG_LEVEL                        //Sets log level: LOG_NONE  = 0; LOG_ERROR = 1; LOG_WARN  = 2; LOG_INFO  = 3; LOG_DEBUG = 4;
*/

//--- input parameters
input ENUM_COPY_MODE   COPY_MODE = RECEIVER;
input int      PROCESSING_INTERVAL_MS = 500;
input group           "Monitoring"
input string   HEARTBEAT_URL = "";
input int      HEARTBEAT_INTERVAL_MINUTES = 5;
input group           "Provider"
input bool     REMOTE_FTP_PUBLISH = false;
input group           "Receiver"
input ulong    PROVIDER_ACCOUNT = 101010101;
input int      PRICE_DEVIATION = 50;
input bool     COPY_IN_PROFIT = false;
input int      EXCLUDE_OLDER_THAN_MINUTES = 5;
input bool     COPY_BUY = true;
input bool     COPY_SELL = true;
input ENUM_LOT_SIZE   LOT_SIZE = PROPORTIONAL_TO_BALANCE;
input bool     USE_LEVERAGE_FOR_LOT_CALCULATION = true;
input double   MIN_AVALABLE_FUNDS_PERC = 0.20;
input string   EXCLUDE_TICKETS = "";
input string   INSTRUMENT_MATCH = "";
input bool     ALERT_MULTIPLE_LOSERS_CLOSE = true;
//input bool     COPY_SL=true;
//input bool     COPY_TP=true;
input bool     REMOTE_HTTP_DOWNLOAD = false;
input group          "Remote Copy"
input string   REMOTE_FILE_URL = "";
input string   REMOTE_USERNAME = "";
input string   REMOTE_PASSWORD = "";

CTrade       m_trade;

int FILE_RETRY_MS = 50;
int FILE_MAXWAIT_MS = 500;

ulong lastHeartbeatTime = 0;

string positionsFileName;

int prRecordCount;
datetime prTimeLocal;
datetime prTimeGMT;
ulong prAccountNumber;
double prAccountBalance;
double prAccountEquity;
string prAccountCurrency;
int prAccountLeverage;
int prMarginMode;
long prTradeServerGMTOffset;

struct PositionData
  {
   int               seq;
   ulong             positionMagic;
   long              positionTicket;
   ulong             positionOpenTime;
   int               positionType;
   double            positionVolume;
   double            positionPriceOpen;
   double            positionSL;
   double            positionTP;
   double            positionProfit;
   string            positionSymbol;
   string            positionComment;
   int               positionLeverage;
  };

PositionData prRecords[];
PositionData recPositions[];

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int OnInit()
  {
//Input validations
   if(RECEIVER == COPY_MODE && PROVIDER_ACCOUNT < 1000)
     {
      printHelper(LOG_ERROR, "Provider Account is required and should be at least 4 digits long.");
      return(INIT_PARAMETERS_INCORRECT);
     }
   ulong fileAccount = AccountInfoInteger(ACCOUNT_LOGIN);
   if(RECEIVER == COPY_MODE)
     {
      fileAccount = PROVIDER_ACCOUNT;
     }
   positionsFileName = "Sharing-Is-Caring\\" + fileAccount + "-positions.csv";
   if(RECEIVER == COPY_MODE)
      Print("file path on receiver: " + positionsFileName);
   if(PROVIDER == COPY_MODE)
      Print("file path on provider: " + positionsFileName);
   EventSetMillisecondTimer(PROCESSING_INTERVAL_MS);
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   EventKillTimer();
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTick()
  {
//-- Nothing to do
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTimer()
  {
   resetValues();
   if(PROVIDER == COPY_MODE)
     {
      //Write all current positions to a file
      writePositions();
      //Share signals via ftp
      if(REMOTE_FTP_PUBLISH)
        {
         SendFTP(positionsFileName);
        }
     }
   else
      if(RECEIVER == COPY_MODE)
        {
         //Download signals from web and put in same location as local provider
         if(REMOTE_HTTP_DOWNLOAD)
           {
            downloadFile();
           }
         //Read from file and save to file array
         readPositions();
         if(prMarginMode != AccountInfoInteger(ACCOUNT_MARGIN_MODE))
           {
            printHelper(LOG_ERROR, StringFormat("Can't copy between different MARGIN MODE, Provider is %d while Receiver is %d .", prMarginMode, AccountInfoInteger(ACCOUNT_MARGIN_MODE)));
            return;
           }
         //Get existing positions previously received from this provider
         int matchesCount = 0;
         int posTotal = PositionsTotal();
         for(int i = 0; i < posTotal; i++)
           {
            PositionGetSymbol(i);
            //Skip if in excluded ticket list
            if(StringFind(EXCLUDE_TICKETS,"[" + PositionGetInteger(POSITION_TICKET) + "]") != -1) //-1 means no match
              {
               continue;
              }
            ulong positionMagic = PositionGetInteger(POSITION_MAGIC);
            if(prAccountNumber == positionMagic)
              {
               matchesCount++;
               ArrayResize(recPositions,matchesCount);
               PositionData positionData;
               positionData.seq = matchesCount - 1;
               positionData.positionMagic = positionMagic;
               positionData.positionTicket = PositionGetInteger(POSITION_TICKET);
               positionData.positionOpenTime = PositionGetInteger(POSITION_TIME_MSC);
               positionData.positionType = PositionGetInteger(POSITION_TYPE);
               positionData.positionVolume = PositionGetDouble(POSITION_VOLUME);
               positionData.positionPriceOpen = PositionGetDouble(POSITION_PRICE_OPEN);
               positionData.positionSL = PositionGetDouble(POSITION_SL);
               positionData.positionTP = PositionGetDouble(POSITION_TP);
               positionData.positionProfit = PositionGetDouble(POSITION_PROFIT);
               positionData.positionSymbol = PositionGetString(POSITION_SYMBOL);
               positionData.positionComment = PositionGetString(POSITION_COMMENT);
               recPositions[matchesCount - 1] = positionData;
              }
           }
         //Update receiver positions based on what's in file
         updatePositions();
         //Close positions that are no longer in the file
         closePositions();
        }
   if(StringLen(HEARTBEAT_URL) > 4)   //Surely can't have url shorter than this...
     {
      processHeartbeat();
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void resetValues()
  {
   prRecordCount = 0;
   prTimeLocal = "";
   prTimeGMT = "";
   prAccountNumber = 0;
   prAccountBalance = 0;
   prAccountEquity = 0;
   prAccountCurrency = "";
   prAccountLeverage = 0;
   prMarginMode = 0;
   prTradeServerGMTOffset = 0;
   ArrayResize(prRecords,0);
   ArrayResize(recPositions,0);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool updatePositions()
  {
   m_trade.SetExpertMagicNumber(prAccountNumber);
   m_trade.SetMarginMode();
   m_trade.SetDeviationInPoints(PRICE_DEVIATION);
   int prRecordsSize = ArraySize(prRecords);
   for(int i = 0; i < prRecordsSize; i++)
     {
      PositionData prRecord = prRecords[i];
      string positionSymbol = prRecord.positionSymbol;
      int instrMatch = StringFind(INSTRUMENT_MATCH,"[" + positionSymbol + "=");
      if(instrMatch != -1)   //-1 means no match
        {
         int instrStartPos = instrMatch + StringLen(positionSymbol) + 2;
         int instrEndPos = StringFind(INSTRUMENT_MATCH,"]",instrMatch);
         positionSymbol = StringSubstr(INSTRUMENT_MATCH,instrStartPos,(instrEndPos - instrStartPos));
         printHelper(LOG_DEBUG, StringFormat("Found instrument match from [%s] to [%s]", prRecord.positionSymbol, positionSymbol));
        }
      //Print error and skip if symbol does not exist
      bool is_custom = false;
      if(!SymbolExist(positionSymbol,is_custom))
        {
         printHelper(LOG_ERROR, StringFormat("Can't copy trade %d as symbol %s does not exist...try setting an INSTRUMENT_MATCH config", prRecord.positionTicket, positionSymbol));
         continue;
        }
      m_trade.SetTypeFillingBySymbol(positionSymbol);
      //Skip if in excluded ticket list
      if(StringFind(EXCLUDE_TICKETS,"[" + prRecord.positionTicket + "]") != -1) //-1 means no match
        {
         continue;
        }
      bool exists = false;
      PositionData recPosition;
      int recPositionsSize = ArraySize(recPositions);
      for(int i = 0; i < recPositionsSize; i++)
        {
         if((GlobalVariableGet("VOL-" + recPositions[i].positionTicket + "-" + prRecord.positionTicket) != 0) || (StringFind(recPositions[i].positionComment,"TKT=" + prRecord.positionTicket) != -1)) //-1 means no match
           {
            exists = true;
            recPosition = recPositions[i];
            break;
           }
        }
      if(exists)
        {
         if(recPosition.positionSL != prRecord.positionSL || recPosition.positionTP != prRecord.positionTP)
           {
            m_trade.PositionModify(recPosition.positionTicket,prRecord.positionSL,prRecord.positionTP);
           }
         //Handle partial close or add(if vol increases then it must be netting account because hedge would be a new deal)
         double prCurrentVol = GlobalVariableGet("VOL-" + recPosition.positionTicket + "-" + prRecord.positionTicket); //First try using previous partial close balance if exists
         if(prCurrentVol == 0)
           {
            int volStartPos = StringFind(recPosition.positionComment,"VOL=") + 4;
            int volEndPos = StringFind(recPosition.positionComment,"]");
            prCurrentVol = StringSubstr(recPosition.positionComment,volStartPos,(volEndPos - volStartPos));
            printHelper(LOG_DEBUG, StringFormat("Current pr volume read starts at %d and ends at %d, value is %d", volStartPos, volEndPos, prCurrentVol));
           }
         double prVolDifference = MathAbs(prRecord.positionVolume - prCurrentVol);
         double volRatio = prVolDifference / prCurrentVol;
         double recVolDifference = recPosition.positionVolume * volRatio;
         recVolDifference = getNormalizedVolume(recVolDifference,positionSymbol);
         printHelper(LOG_DEBUG, StringFormat("prVolDifference is %d, using volRatio of %d we get recVolDifference of %d", prVolDifference, volRatio, recVolDifference));
         string comment = "[TKT=" + prRecord.positionTicket + ",VOL=" + DoubleToString(prRecord.positionVolume,2) + "]";
         if(prRecord.positionVolume > prCurrentVol)  //Vol size increased
           {
            if(ACCOUNT_MARGIN_MODE_RETAIL_NETTING == AccountInfoInteger(ACCOUNT_MARGIN_MODE))
              {
               if(prRecord.positionType == 0 && COPY_BUY)
                 {
                  placeBuyOrder(m_trade, prRecord.positionSL, prRecord.positionTP, recVolDifference, positionSymbol, comment);
                 }
               else
                  if(prRecord.positionType == 1 && COPY_SELL)
                    {
                     placeSellOrder(m_trade, prRecord.positionSL, prRecord.positionTP, recVolDifference, positionSymbol, comment);
                    }
              }
           }
         else
            if(prRecord.positionVolume < prCurrentVol)  //Vols size decreased
              {
               if(ACCOUNT_MARGIN_MODE_RETAIL_NETTING == AccountInfoInteger(ACCOUNT_MARGIN_MODE))
                 {
                  if(prRecord.positionType == 0 && COPY_BUY)
                    {
                     placeSellOrder(m_trade, prRecord.positionSL, prRecord.positionTP, recVolDifference, positionSymbol, comment);
                    }
                  else
                     if(prRecord.positionType == 1 && COPY_SELL)
                       {
                        placeBuyOrder(m_trade, prRecord.positionSL, prRecord.positionTP, recVolDifference, positionSymbol, comment);
                       }
                 }
               else
                  if(ACCOUNT_MARGIN_MODE_RETAIL_HEDGING == AccountInfoInteger(ACCOUNT_MARGIN_MODE))
                    {
                     m_trade.PositionClosePartial(recPosition.positionTicket,recVolDifference);
                     //Save new provider volume so we can use to handle more than 1 partial close since we can't update comments with decreased volume...plus MT5 clears comments anyway on partial close so we need global var to check if ticket existed
                     GlobalVariableSet("VOL-" + recPosition.positionTicket + "-" + prRecord.positionTicket, prRecord.positionVolume); //Kinda redundent no since we set global var either way below for all existing deals ( for both netting and hedging)
                    }
              }
         //Set record in global var so that we still have it even if comments get removed (helps fix issue of closing which no longer have comments to get provider ticket from)
         GlobalVariableSet("VOL-" + recPosition.positionTicket + "-" + prRecord.positionTicket, prRecord.positionVolume);
        }
      else
        {
         double balance = AccountInfoDouble(ACCOUNT_BALANCE);
         double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
         if(freeMargin <= (balance * MIN_AVALABLE_FUNDS_PERC))
           {
            continue;
           }
         long now = ((long)TimeGMT()) * 1000;
         long positionTimeGMT = prRecord.positionOpenTime + (prTradeServerGMTOffset * 1000);
         long millisecondsElapsed = now - positionTimeGMT;
         if(millisecondsElapsed > (EXCLUDE_OLDER_THAN_MINUTES * 60 * 1000))
           {
            continue;
           }
         if(prRecord.positionProfit > 0 && !COPY_IN_PROFIT)
           {
            continue;
           }
         double volume = prRecord.positionVolume;
         if(PROPORTIONAL_TO_BALANCE == LOT_SIZE)
           {
            double receiverAvailableFunds = balance;
            volume = volume * (receiverAvailableFunds / prAccountBalance);
           }
         else
            if(PROPORTIONAL_TO_FREE_MARGIN == LOT_SIZE)
              {
               double receiverAvailableFunds = freeMargin;
               volume = volume * (receiverAvailableFunds / prAccountBalance);
              }
         //Check leverage
         if(USE_LEVERAGE_FOR_LOT_CALCULATION)
           {
            double marginInit;
            double marginMaint;
            SymbolInfoMarginRate(positionSymbol,(prRecord.positionType == 0 ? ORDER_TYPE_BUY : ORDER_TYPE_SELL),marginInit,marginMaint);
            int positionLeverage = 1 / (NormalizeDouble(marginInit,3));
            double receiverLeverage = AccountInfoInteger(ACCOUNT_LEVERAGE);
            //Default position leverage to 1 to avoid dividing by 0
            double prPositionLeverage = prRecord.positionLeverage;
            if(prPositionLeverage == 0)
              {
               prPositionLeverage = 1;
              }
            if(positionLeverage == 0)
              {
               positionLeverage = 1;
              }
            volume = volume * ((receiverLeverage * positionLeverage) / (prAccountLeverage * prPositionLeverage));
           }
         string comment = "[TKT=" + prRecord.positionTicket + ",VOL=" + DoubleToString(prRecord.positionVolume,2) + "]";
         if(prRecord.positionType == 0 && COPY_BUY)
           {
            placeBuyOrder(m_trade, prRecord.positionSL, prRecord.positionTP, volume, positionSymbol, comment);
           }
         else
            if(prRecord.positionType == 1 && COPY_SELL)
              {
               placeSellOrder(m_trade, prRecord.positionSL, prRecord.positionTP, volume, positionSymbol, comment);
              }
        }
     }
   return true;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool closePositions()
  {
   m_trade.SetExpertMagicNumber(prAccountNumber);
   m_trade.SetMarginMode();
   m_trade.SetDeviationInPoints(PRICE_DEVIATION);
   PositionData losersToClose[];
   int loserMatches = 0;
   int recPositionsSize = ArraySize(recPositions);
   for(int i = 0; i < recPositionsSize; i++)
     {
      PositionData recPosition = recPositions[i];
      m_trade.SetTypeFillingBySymbol(recPosition.positionSymbol);
      //Close position no longer on provider side
      bool existsOnProvider = false;
      int prRecordsSize = ArraySize(prRecords);
      for(int i = 0; i < prRecordsSize; i++)
        {
         if(StringFind(recPosition.positionComment,"TKT=" + prRecords[i].positionTicket) != -1) //-1 means no match
           {
            existsOnProvider = true;
            break;
           }
         else
            if(GlobalVariableCheck("VOL-" + recPosition.positionTicket + "-" + prRecords[i].positionTicket))
              {
               existsOnProvider = true;
               break;
              }
        }
      if(!existsOnProvider)
        {
         if(recPosition.positionProfit < 0.00)
           {
            loserMatches++;
            ArrayResize(losersToClose,loserMatches);
            losersToClose[loserMatches - 1] = recPosition;
            continue;
           }
         printHelper(LOG_INFO, StringFormat("Closing position %d as it no longer exists on provider side", recPosition.positionTicket));
         m_trade.PositionClose(recPosition.positionTicket);
        }
     }
   if(loserMatches > 1 && ALERT_MULTIPLE_LOSERS_CLOSE)   //Alert and don't close positions
     {
      string tickets = "";
      for(int i = 0; i < loserMatches; i++)
        {
         tickets = tickets + "[" + losersToClose[i].positionTicket + "]";
        }
      string subject = "Closing of Multiple losers on receiver account " + AccountInfoInteger(ACCOUNT_LOGIN);
      string body = StringFormat("Closing of multiple losing tickets %s looks suspicious. Please check and close them manually if still applicable", tickets);
      SendMail(subject,body);
     }
   else
      if(loserMatches > 0)
        {
         for(int i = 0; i < loserMatches; i++)
           {
            printHelper(LOG_INFO, StringFormat("Closing position %d as it no longer exists on provider side", losersToClose[i].positionTicket));
            m_trade.PositionClose(losersToClose[i].positionTicket);
           }
        }
   return true;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool readPositions()
  {
   ulong startTime = GetTickCount64();
   int positionsFileHandle = INVALID_HANDLE;
   int timeWasted = 0;
   while(positionsFileHandle == INVALID_HANDLE)
     {
      positionsFileHandle = FileOpen(positionsFileName,FILE_READ | FILE_SHARE_READ | FILE_COMMON | FILE_TXT,',');
      if(positionsFileHandle == INVALID_HANDLE)
        {
         if(timeWasted >= FILE_MAXWAIT_MS)
           {
            printHelper(LOG_INFO, StringFormat("Failed to open file %s but will retry in %dms, error code %d", positionsFileName, PROCESSING_INTERVAL_MS, GetLastError()));
            return false;
           }
         timeWasted = timeWasted + FILE_RETRY_MS;
         Sleep(FILE_RETRY_MS);
        }
     }
   FileReadString(positionsFileHandle);//Discard the header line as we don't use it
   string accountDataLine = FileReadString(positionsFileHandle);
   string accountDataArray[10];
   StringSplit(accountDataLine,',',accountDataArray);
   prRecordCount = accountDataArray[0];
   prTimeLocal = accountDataArray[1];
   prTimeGMT = accountDataArray[2];
   prAccountNumber = accountDataArray[3];
   prAccountBalance = accountDataArray[4];
   prAccountEquity = accountDataArray[5];
   prAccountCurrency = accountDataArray[6];
   prAccountLeverage = accountDataArray[7];
   prMarginMode = accountDataArray[8];
   prTradeServerGMTOffset = accountDataArray[9];
   FileReadString(positionsFileHandle);//Discard the header line as we don't use it
   ArrayResize(prRecords,prRecordCount);
   int i = 0;
   while(!FileIsEnding(positionsFileHandle))
     {
      string line = FileReadString(positionsFileHandle);
      //TODO: split string and add struct into array
      string tmpArray[12];
      StringSplit(line, ',', tmpArray);
      //---position data
      PositionData prData;
      prData.seq = tmpArray[0];
      prData.positionMagic = 0;
      prData.positionTicket = tmpArray[1];
      prData.positionOpenTime = tmpArray[2];
      prData.positionType = tmpArray[3];
      prData.positionVolume = tmpArray[4];
      prData.positionPriceOpen = tmpArray[5];
      prData.positionSL = tmpArray[6];
      prData.positionTP = tmpArray[7];
      prData.positionProfit = tmpArray[8];
      prData.positionSymbol = tmpArray[9];
      prData.positionComment = tmpArray[10];
      prData.positionLeverage = tmpArray[11];
      prRecords[i] = prData;
      i++;
     }
   FileClose(positionsFileHandle);
   ulong endTime = GetTickCount64();
   printHelper(LOG_INFO, StringFormat("Reading from file took %d milliseconds", endTime - startTime));
   return true;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool writePositions()
  {
   ulong startTime = GetTickCount64();
   uint posTotal = PositionsTotal();
   uint orderTotal = OrdersTotal();
   ulong positionTicket;
   ulong orderTicket;
   
   ulong accountNumber = AccountInfoInteger(ACCOUNT_LOGIN);
   string accountCurrency = AccountInfoString(ACCOUNT_CURRENCY);
   double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   double accountEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   int accountLeverage = AccountInfoInteger(ACCOUNT_LEVERAGE);
   int margingMode = AccountInfoInteger(ACCOUNT_MARGIN_MODE);
   string nTimeLocal = TimeToString(TimeLocal(),TIME_DATE | TIME_SECONDS);
   string nTimeGMT = TimeToString(TimeGMT(),TIME_DATE | TIME_SECONDS);
   long tradeServerGMTOffset = TimeGMT() - TimeTradeServer();
   int positionsFileHandle = INVALID_HANDLE;
   int timeWasted = 0;
   while(positionsFileHandle == INVALID_HANDLE)
     {
      if(REMOTE_FTP_PUBLISH)   //sendFTP expects file in current termial folder so can't put it in common folder'
        {
         positionsFileHandle = FileOpen(positionsFileName,FILE_WRITE | FILE_TXT,',');
        }
      else
        {
         positionsFileHandle = FileOpen(positionsFileName,FILE_WRITE | FILE_COMMON | FILE_TXT,',');
        }
      if(positionsFileHandle == INVALID_HANDLE)
        {
         if(timeWasted >= FILE_MAXWAIT_MS)
           {
            printHelper(LOG_INFO, StringFormat("Failed to open file %s but will retry in %dms, error code %d", positionsFileName, PROCESSING_INTERVAL_MS, GetLastError()));
            return false;
           }
         timeWasted = timeWasted + FILE_RETRY_MS;
         Sleep(FILE_RETRY_MS);
        }
     }
   FileWrite(positionsFileHandle,
             "RecordCount",
             "TimeLocal",
             "TimeGMT",
             "AccountNumber",
             "Balance",
             "Equity",
             "Currency",
             "Leverage",
             "MarginMode",
             "TradeServer GMT Offset");
   FileWrite(positionsFileHandle,
             posTotal,
             nTimeLocal,
             nTimeGMT,
             accountNumber,
             accountBalance,
             accountEquity,
             accountCurrency,
             accountLeverage,
             margingMode,
             tradeServerGMTOffset);
   FileWrite(positionsFileHandle,
             "Seq",
             "PositionTicket",
             "PositionOpenTime",
             "PositionType",
             "PositionVolume",
             "PositionPriceOpen",
             "PositionSL",
             "PositionTP",
             "PositionProfit",
             "PositionSymbol",
             "PositionComment",
             "PositionLeverage");
   /*



   */
   for(uint i = 0; i < posTotal; i++)
     {
      positionTicket = PositionGetTicket(i);
      if(positionTicket > 0) //Meaning the position exists,,Loading Position Information
        {
         ulong positionOpenTime = PositionGetInteger(POSITION_TIME_MSC);
         int positionType = PositionGetInteger(POSITION_TYPE);  // type of the position
         double positionVolume = PositionGetDouble(POSITION_VOLUME);
         double positionPriceOpen = PositionGetDouble(POSITION_PRICE_OPEN);
         double positionSL = PositionGetDouble(POSITION_SL);
         double positionTP = PositionGetDouble(POSITION_TP);
         double positionProfit = PositionGetDouble(POSITION_PROFIT);
         string positionSymbol = PositionGetString(POSITION_SYMBOL);
         string positionComment = PositionGetString(POSITION_COMMENT);
         double marginInit;
         double marginMaint;
         SymbolInfoMarginRate(positionSymbol,(positionType == 0 ? ORDER_TYPE_BUY : ORDER_TYPE_SELL),marginInit,marginMaint);
         int positionLeverage = 1 / (NormalizeDouble(marginInit,3));
         FileWrite(positionsFileHandle,
                   i,
                   positionTicket,
                   positionOpenTime,
                   positionType,
                   positionVolume,
                   positionPriceOpen,
                   positionSL,
                   positionTP,
                   positionProfit,
                   positionSymbol,
                   positionComment,
                   positionLeverage);
        }//end if
     }//end for
 
   FileClose(positionsFileHandle);
   printHelper(LOG_INFO, "File " + positionsFileName + " updated, there were " + IntegerToString(posTotal) + " positions in the system.");
   ulong endTime = GetTickCount64();
   printHelper(LOG_INFO, StringFormat("Writing to file took %d milliseconds", endTime - startTime));
   return true;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void downloadFile()
  {
   string credentials = REMOTE_USERNAME + ":" + REMOTE_PASSWORD;
   string key = "";
   uchar srcArray[],dstArray[],keyArray[];
   StringToCharArray(key,keyArray);
   StringToCharArray(credentials,srcArray);
   CryptEncode(CRYPT_BASE64,srcArray,keyArray,dstArray);
   string cookie = NULL;
   string headers = "Authorization: Basic " + CharArrayToString(dstArray);
   char   data[],result[];
   ResetLastError();
   printHelper(LOG_DEBUG, StringFormat("HTTP Headers before: %s",headers));
   int res = WebRequest("GET",REMOTE_FILE_URL,headers,500,data,result,headers);
   if(res == -1)
     {
      printHelper(LOG_WARN, StringFormat("Error in download WebRequest. Error code %s",GetLastError()));
      //--- Perhaps the URL is not listed, display a message about the necessity to add the address
      printHelper(LOG_WARN, StringFormat("Add the address %s to the list of allowed URLs on tab 'Expert Advisors'",REMOTE_FILE_URL));
     }
   else
     {
      if(res == 200)
        {
         //--- Successful download
         printHelper(LOG_INFO, StringFormat("Remote file downloaded, File size is %d bytes",ArraySize(result)));
         if(ArraySize(result) > 0)
           {
            int fileHandle = FileOpen(positionsFileName,FILE_WRITE | FILE_COMMON | FILE_BIN);
            if(fileHandle != INVALID_HANDLE)
              {
               //--- Saving the contents of the result[] array to a file
               FileWriteArray(fileHandle,result,0,ArraySize(result));
               FileClose(fileHandle);
              }
           }
         else
           {
            printHelper(LOG_WARN, StringFormat("Not processing file as size is %d",ArraySize(result)));
           }
        }
      else
        {
         printHelper(LOG_WARN, StringFormat("Remote file '%s' download failed, error code %d",REMOTE_FILE_URL,res));
         printHelper(LOG_DEBUG, StringFormat("HTTP Headers after: %s",headers));
        }
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void processHeartbeat()
  {
   ulong now = GetTickCount64();
   if((now - lastHeartbeatTime) < (HEARTBEAT_INTERVAL_MINUTES * 60 * 1000))
     {
      return;
     }
   string cookie = NULL,headers;
   char   data[],result[];
   ResetLastError();
   int res = WebRequest("POST",HEARTBEAT_URL,cookie,NULL,500,data,0,result,headers);
   if(res == -1)
     {
      printHelper(LOG_WARN, StringFormat("Error in heartbeat WebRequest. Error code %s",GetLastError()));
      //--- Perhaps the URL is not listed, display a message about the necessity to add the address
      printHelper(LOG_WARN, StringFormat("Add the address %s to the list of allowed URLs on tab 'Expert Advisors'",HEARTBEAT_URL));
     }
   else
     {
      if(res == 200)
        {
         //--- Successful transmission
         printHelper(LOG_INFO, StringFormat("Heartbeat sent, Server Result: %s", CharArrayToString(result)));
        }
      else
        {
         printHelper(LOG_WARN, StringFormat("Heartbeat transmission '%s' failed, error code %d",HEARTBEAT_URL,res));
        }
     }
   lastHeartbeatTime = GetTickCount64();
  }



/*


more info





About
This is a MetaTrader 5 EA.
The tool is designed for simplicity and speed and I use it daily in my trading.
In my use-case the copier helps with the psychology of trading large accounts and keeping emotions under control. I have a small account which I use for trading. Then I have other accounts which are comparatively large, about 10x but can even be 100x.
These accounts simply copy the trades from the small account using the copier and sizing trades proportionally.
This way I can just keep my trading account small like $5k but have the other accounts at like $100k and trade without panic as the large accounts are out of sight and I just focus on the small one which does not induce as much stress.

Notes:
Account types need to match i.e hedging providers to be used with hedging receivers and vice versa. Ideally, Provider and Receiver accounts should use same currency denomination for accurate lot calculation using balances. Try using the same broker to avoid slippage and issues with unmatching speed.


*/

/*
settings


Settings:
The program allows for the following configurations to be set.
Defaults are indicated in brackets. Where applicable, options are in brackets at the end of the description.

Item [defaults in brackets] Description [valid values in brackets]

Operating mode [RECEIVER] Set the terminal as either a provider or receiver of trades. [PROVIDER , RECEIVER]

Processing interval (ms) [500] Milliseconds indicating how often to check and distribute trades to receivers.


"Monitoring"
Heart beat URL [""] URL to ping to indicate that the terminal is operational. If blank then no heartbeat is sent.

Heart beat interval (minutes) [5] Minutes indicating how often to send out the ping signal.


"Provider"
Publish to remote FTP [false]
Whether to publish trades to a remote server if there are remote receivers. If true, then FTP server details should be configured in the 'FTP' tab under options. [true , false]


"Receiver"
Provider account number [0] Trading account number whose trades are copied.

Price deviation [50] Number of points by which price can deviate from the provider price.

Copy trades in profit [false] Whether to copy trades that are already in profit. [true , false]

Exclude trades older than X minutes [5] Trades older than this number of minutes won’t be copied.

Copy buy trades [true] Whether to copy Buy positions. [true , false]

Copy sell trades [true] Whether to copy Sell positions. [true , false]

Trade volume mode [PROPORTIONAL_TO_BALANCE] Position sizing strategy. Can either be exactly the same as provider or be proportional to receiver account balance or be proportional to receiver free margin. [SAME_AS_PROVIDER , PROPORTIONAL_TO_BALANCE , PROPORTIONAL_TO_FREE_MARGIN]

Use leverage for volume calculation [true] Whether to consider account and position leverage when calculating lot size. Set this to false if you are getting unexpected sizes. [true , false]

Provider balance for lot calculation [0.00] Fixed provider balance to be used when calculating lot. If set to 0.00 then the value received from provider will be used.

Minimum available funds percentage [0.20] Percentage of receiver account funds to keep aside, so no copying once available balance reaches this level.


Exclude tickets [""] List of ticket numbers that should be excluded when copying. Each item must be enclosed within square brackets e.g [878221][879545][549102]


Match instruments [""] If the instrument names differ between provider and receiver brokers then the pair matching can be specified here. Each pair match must be enclosed in square brackets e.g [EURUSD=eurusd.micro][NAS100=Nasdaq 100]

Alert email on multiple losing trades [true] Whether to send an alert email when there are more than 1 losing positions to be closed. If true then the positions are not closed and the email is sent to the address configured in the terminal settings.


"Remote Copy"
Remote HTTP download [false]
Whether to download trades from a remote server. [true , false]

Remote file URL [""] URL of the remote file to be used if http download is true. This points to the full path including the csv filename.

Remote user name [""] Http username to be used if http download is true.

Remote password [""] Http password to be used if http download is true.
*/
