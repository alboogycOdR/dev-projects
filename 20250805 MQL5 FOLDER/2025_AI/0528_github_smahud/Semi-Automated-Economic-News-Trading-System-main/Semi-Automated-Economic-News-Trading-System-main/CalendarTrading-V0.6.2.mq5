//+------------------------------------------------------------------+
//|                                              CalendarTrading.mq5 |
//|                                       Copyright 2024, Hedge Ltd. |
//|                                            https://www.Hedge.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Hedge Ltd."
#property link      "https://www.Hedge.com"
#property version   "1.0"

#include "C:\Program Files\MetaTrader 5\MQL5\Include\header-CalendarTrading-V0.6.2.mqh"

//input group " Date "
string date_from_calendar="2024-10-28";
string date_to_calendar="2024-11-01";

input group " Parameters "
input int StopLoss = 0;
input int Takeprofit = 800;
input double RiskPercentage = 0.3;
input int maxTimeOpenPosition = 8;
input int maxTotalMarge = 100;
input int Trailing_Stop_Points = 15;

//input group " Other "
int eventTimer = 42;


//+------------------------------------------------------------------+
//| Main                                                             |
//+------------------------------------------------------------------+

void OnInit(void)
     {
     Print("---- OnInit CalendarTrading ----");
     EventSetMillisecondTimer(1);
     //trade.LogLevel(LOG_LEVEL_ERRORS);
     //trade.LogLevel(LOG_LEVEL_NO);
     
     //--- corrects the time difference caused by DST ---//
     if((TimeCurrent() >= StringToTime("2024.10.27") && TimeCurrent() <= StringToTime("2025.03.30"))) correction = 3600;
     else correction = 0;
     
     Print("-- [DEBUG] Init Socket");
     socket = initSocket();

     string ReceivedCalendar = Socket(socket,date_from_calendar,date_to_calendar,"","calendar");
     ReceivedCalendar_To_MyCalendarData(ReceivedCalendar, MyCalendarData);
     
     Print("-- [DEBUG] MyCalendarData processed : ");
     PrintCalendar(MyCalendarData);
     
     Print("-- [DEBUG] Init Indice");
     indice = ArraySize(MyCalendarData)-1;
     
     return;
}

//--------------------

void OnDeinit(const int reason)
  {
   Print("---- OnDeInit ----");
   Print(__FUNCTION__,"_code de raison de non-initalisation = ",reason);
  }

//--------------------

void OnTimer()
{    
     //--- if there's no more data ---//
     if(ArraySize(MyCalendarData)<1 && PositionsTotal() <= 0) {
         Print("-- [DEBUG] Plus d'évènement dans MyCalendarData : OnDeInit()");
         Print(Socket(socket,"","","",""));
         EventKillTimer();
         ExpertRemove();
         
         return;
     }
     
     if(ArraySize(MyCalendarData)>0 && TimeCurrent() >= MyCalendarData[indice].time - correction + 60*2){
         PrintFormat("-- [DEBUG] Remove an event : %s - %s - %s",MyCalendarData[indice].name, TimeToString(MyCalendarData[indice].time), MyCalendarData[indice].href);
         ArrayRemove(MyCalendarData, indice, 1);
         indice--;
     }
     
     //--- If economic data published, then open position ? ---//
     else if(ArraySize(MyCalendarData)>0 && TimeCurrent() >= MyCalendarData[indice].time - correction - 60*1){
        Print("--------------------------------------------------------------------------------------------------------");
        currentSymbol = MyCalendarData[indice].symbol;
        
        PrintFormat("-------- [DEBUG] {%s} It's Time : %s - %s", currentSymbol, TimeToString(MyCalendarData[indice].time), TimeToString(TimeCurrent()));
        start_time = GetTickCount();
        
        
        if(TimeToStruct(MyCalendarData[indice].time,date)) date_formate = string(date.year)+"-"+string(date.mon)+"-"+string(date.day);
        else PrintFormat("-- [DEBUG] {%s} Error formate date : %d", currentSymbol, GetLastError());
        string eventName = MyCalendarData[indice].href;
        string dataType = "actual";
        
        PrintFormat("-- [DEBUG] {%s} Envoie des données à Python : socket : %d ; date_formate : %s ; eventName : %s ; dataType : %s", currentSymbol,
                     socket,
                     date_formate,
                     eventName,
                     dataType);
        
        eventValue_valid = true;
        eventValue_string = Socket(socket,date_formate, "",eventName,dataType);
        
        PrintFormat("-- [DEBUG] {%s} Event value reçu à %s [socket : %d ; date_formate : %s ; eventName : %s ; dataType : %s] : %s", currentSymbol,
                        TimeToString(TimeLocal(), TIME_MINUTES | TIME_SECONDS) + StringFormat(".%03d", GetTickCount() % 1000),
                        socket,
                        date_formate,
                        eventName,
                        dataType,
                        eventValue_string);
        
        if(eventValue_string == "abort") {
            PrintFormat("-- [DEBUG] {%s} {%s} Impossibilité pour le programme python de récupérer la donnée", currentSymbol, eventName);
            eventValue_valid = false;
        }
        
        if(eventValue_valid){
        
           eventValue = StringToDouble(eventValue_string);
               
           if(eventValue > MyCalendarData[indice].consensus) MyCalendarData[indice].impact_type = MyCalendarData[indice].decision;
           if(eventValue < MyCalendarData[indice].consensus) MyCalendarData[indice].impact_type = -1*MyCalendarData[indice].decision;
           
           //----------------------------------------------------------------------//
           
           symbolAlreadyTrade = false;
           for(int i = PositionsTotal() - 1; i >= 0; i--){
               if(currentSymbol == PositionGetSymbol(i)) {
                  symbolAlreadyTrade = true;
                  PrintFormat("-- [DEBUG] {%s} Symbol Already Trade", currentSymbol);
                  break;
               }
           }
           
           //----------------------------------------------------------------------//
           
           if(AccountInfoDouble(ACCOUNT_MARGIN)*100/AccountInfoDouble(ACCOUNT_BALANCE) >= maxTotalMarge) {
               enoughMargin = false;
               PrintFormat("-- [DEBUG] {%s} Not enough margin", currentSymbol);
           } else enoughMargin = true;
           
           //----------------------------------------------------------------------//
           
           currentTime = TimeTradeServer(tm);
           TimeToTrade = false;
           //--- get data from the quotation session by symbol and day of the week
           if(SymbolInfoSessionQuote(currentSymbol, (ENUM_DAY_OF_WEEK)tm.day_of_week, 0, date_from_session, date_to_session))
           {
              TimeToStruct(date_from_session, hour_from);
              TimeToStruct(date_to_session, hour_to);
              if(tm.hour >= hour_from.hour && tm.hour < hour_to.hour) TimeToTrade = true;
              else PrintFormat("-- [DEBUG] {%s} Time to trade : False", currentSymbol);
           }
           else PrintFormat("-- [DEBUG] {%s} SymbolInfoSessionQuote() failed. Error : %d ", currentSymbol, GetLastError());
           
           //----------------------------------------------------------------------//
           
           //--- Get current symbol price ---//
           prixAchat = SymbolInfoDouble(currentSymbol,SYMBOL_ASK);
           prixVente = SymbolInfoDouble(currentSymbol,SYMBOL_BID);
           
           min_SLTP_point = (double)SymbolInfoInteger(currentSymbol, SYMBOL_TRADE_STOPS_LEVEL); // En point
           SL = StopLoss*SymbolInfoDouble(currentSymbol, SYMBOL_TRADE_TICK_SIZE) + min_SLTP_point*SymbolInfoDouble(currentSymbol, SYMBOL_TRADE_TICK_SIZE);
           TP = Takeprofit*SymbolInfoDouble(currentSymbol, SYMBOL_TRADE_TICK_SIZE) + min_SLTP_point*SymbolInfoDouble(currentSymbol, SYMBOL_TRADE_TICK_SIZE);
           
           double SL_lot_Buy = prixAchat - (prixVente - SL);
           double SL_lot_Sell = (prixAchat + SL) - prixVente;
           
           //----------------------------------------------------------------------//
           
           //--- BUY : If symbol not already trade ; And If Free Margin > 0 ; And conditions ---//
           if(TimeToTrade && !symbolAlreadyTrade && enoughMargin && ((MyCalendarData[indice].impact_type == 1 && MyCalendarData[indice].side==1) || (MyCalendarData[indice].impact_type == -1 && MyCalendarData[indice].side==2))) {
               
               ArrayFree(list_lot_size);
               Lot = CalculateLotSize(SL_lot_Buy, RiskPercentage, currentSymbol, prixAchat, 0, list_lot_size, maxTotalMarge); //Calculation of lot size
                        
               //--- Debugging ---//
               //Print("--------------------------------------------------------------------------------------------------------");
               
               if(Lot > 0){
                  
                  for(int n=0; n<=ArraySize(list_lot_size)-1;n++){
                     
                     prixAchat = SymbolInfoDouble(currentSymbol,SYMBOL_ASK);
                     prixVente = SymbolInfoDouble(currentSymbol,SYMBOL_BID);
                     
                     min_SLTP_point = (double)SymbolInfoInteger(currentSymbol, SYMBOL_TRADE_STOPS_LEVEL); // En point
                     SL = StopLoss*SymbolInfoDouble(currentSymbol, SYMBOL_TRADE_TICK_SIZE) + min_SLTP_point*SymbolInfoDouble(currentSymbol, SYMBOL_TRADE_TICK_SIZE);
                     
                     if(!trade.Buy(list_lot_size[n], currentSymbol, prixAchat, prixVente - SL, prixAchat + TP)) {
                        //--- Debugging ---//
                        PrintFormat("-- [DEBUG] {%s} {BUY} trade.buy error (%d) :  Lot = %f, ASK = %f, BID = %f, SL = %f, TP = %f", currentSymbol, GetLastError(), list_lot_size[n], prixAchat, prixVente, prixVente - SL, prixAchat + TP);
                     }
                     
                     else { // Trade réussi
                       ResultCode = trade.ResultRetcode();
                       if(ResultCode != 10009) PrintFormat("-- [DEBUG] {%s} {BUY} trade.Buy doesn't work, code : %d : %s", currentSymbol, ResultCode, trade.ResultRetcodeDescription());
                       
                       end_time = GetTickCount();
                       PrintFormat("-- [DEBUG] {%s} {BUY} Buy Order Execute :  Lot = %f, ASK = %f, BID = %f, SL = %f, TP = %f", currentSymbol, list_lot_size[n], prixAchat, prixVente, prixVente - SL, prixAchat + TP);
                       PrintFormat("-- [DEBUG] {%s} {BUY} Trade exécuté en : %f millisecondes",currentSymbol, end_time - start_time);
                     }
                   }
               }
               
               else PrintFormat("-- [DEBUG] {%s} {BUY} Risk to high : Margin = %f € - %f %",currentSymbol, AccountInfoDouble(ACCOUNT_MARGIN), AccountInfoDouble(ACCOUNT_MARGIN)*100/AccountInfoDouble(ACCOUNT_BALANCE), "%");
               
               //--- Debugging ---//
               //Print("--------------------------------------------------------------------------------------------------------");
           }
           
           //------------------------------------------------------------------------------------------------------------------------------------------------------------------------------//
           //------------------------------------------------------------------------------------------------------------------------------------------------------------------------------//
           
           //--- Sell : If symbol not already trade ; And If Free Margin > 0 ; And conditions ---//
           else if(TimeToTrade && !symbolAlreadyTrade && enoughMargin && ((MyCalendarData[indice].impact_type==-1 && MyCalendarData[indice].side==1) || (MyCalendarData[indice].impact_type == 1 && MyCalendarData[indice].side==2))) {
               
               ArrayFree(list_lot_size);
               Lot = CalculateLotSize(SL_lot_Sell, RiskPercentage, currentSymbol, prixVente, 1, list_lot_size, maxTotalMarge); //Calculation of lot size
              
               //--- Debugging ---//
               //Print("--------------------------------------------------------------------------------------------------------");
               if(Lot > 0){
                  
                  for(int n=0; n<=ArraySize(list_lot_size)-1;n++){
                  
                     prixAchat = SymbolInfoDouble(currentSymbol,SYMBOL_ASK);
                     prixVente = SymbolInfoDouble(currentSymbol,SYMBOL_BID);
                     
                     min_SLTP_point = (double)SymbolInfoInteger(currentSymbol, SYMBOL_TRADE_STOPS_LEVEL); // En point
                     SL = StopLoss*SymbolInfoDouble(currentSymbol, SYMBOL_TRADE_TICK_SIZE) + min_SLTP_point*SymbolInfoDouble(currentSymbol, SYMBOL_TRADE_TICK_SIZE);
                  
                     if(!trade.Sell(list_lot_size[n], currentSymbol, prixVente, prixAchat + SL, prixVente - TP)) {
                        //--- Debugging ---//
                        PrintFormat("-- [DEBUG] {%s} {SELL} trade.sell error (%d) :  Lot = %f, Bid = %f, Ask = %f, SL = %f, TP = %f", currentSymbol, GetLastError(), list_lot_size[n], prixVente, prixAchat, prixAchat + SL, prixVente - TP);
                     }
                     
                     else { // Trade réussi
                       ResultCode = trade.ResultRetcode();
                       if(ResultCode != 10009) PrintFormat("-- [DEBUG] {%s} {SELL} trade.Sell doesn't work, code : %d : %s", currentSymbol, ResultCode, trade.ResultRetcodeDescription());
                       
                       end_time = GetTickCount();
                       PrintFormat("-- [DEBUG] {%s} {SELL} Order Execute :  Lot = %f, Bid = %f, Ask = %f, SL = %f, TP = %f", currentSymbol, list_lot_size[n], prixVente, prixAchat, prixAchat + SL, prixVente - TP);
                       PrintFormat("-- [DEBUG] {%s} {SELL} Trade exécuté en : %f millisecondes",currentSymbol, end_time - start_time);
                     }
                   }
               }
               
               else PrintFormat("-- [DEBUG] {%s} {SELL} Risk to high : Margin = %f € - %f %",currentSymbol, AccountInfoDouble(ACCOUNT_MARGIN), AccountInfoDouble(ACCOUNT_MARGIN)*100/AccountInfoDouble(ACCOUNT_BALANCE), "%");
               
               //--- Debugging ---//
               //Print("--------------------------------------------------------------------------------------------------------");
               
           } //--- End of "Sell" section ---//
        }
        //---------- Remove Already Trade event ----------//
        PrintFormat("-- [DEBUG] Remove an event : %s - %s - %s",MyCalendarData[indice].name, TimeToString(MyCalendarData[indice].time), MyCalendarData[indice].href);
        ArrayRemove(MyCalendarData, indice, 1);
        indice--;
        //------------------------------------------------//
  }

   // Close position if <maxTimeOpenPosition> is exceeded
   ClosePosition(maxTimeOpenPosition);
   
   // Modify SL if needed
   CheckTrailingStop(Trailing_Stop_Points);
}