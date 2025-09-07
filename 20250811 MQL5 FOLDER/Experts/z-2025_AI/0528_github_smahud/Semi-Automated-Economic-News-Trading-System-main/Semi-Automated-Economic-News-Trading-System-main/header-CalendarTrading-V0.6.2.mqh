//+------------------------------------------------------------------+
//|                                       header-CalendarTrading.mqh |
//|                                  Copyright 2024, MetaQuotes Ltd. |
//|                                            https://www.Hedge.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Hedge Ltd."
#property link      "https://www.Hedge.com"
//+------------------------------------------------------------------+
//| Imports                                                          |
//+------------------------------------------------------------------+
#include <Trade/Trade.mqh>
#include <Strings\String.mqh> 
CTrade trade;
CString strg;
//+------------------------------------------------------------------+
//| Parameters                                                       |
//+------------------------------------------------------------------+

//datetime date_from=TimeLocal();
//datetime date_to=getDateInNDays(1);

const string countryCodeList[10] = {"EU","US","CA","AU","NZ","JP","GB","CH","DE","FR"};
const string symbolList[7] = {"EURUSD","USDCAD","AUDUSD","NZDUSD","USDJPY","USDCHF","GBPUSD"};

struct MyMqlCalendarData
  {
   string name;
   datetime time;
   double consensus;
   int impact_type;
   int importance;
   string symbol;
   int side;
   string href;
   int decision;
  };

// Structure pour stocker les informations de chaque position
struct PositionInfo
{
    ulong ticket;    // Ticket de la position
    string symbol;   // Symbole du trade
    long open_time;  // Heure d'ouverture de la position
};

//+------------------------------------------------------------------+
//| Global variables for main                                        |
//+------------------------------------------------------------------+

MqlDateTime date;
string date_formate;

int socket;
double eventValue;
string eventValue_string;
bool eventValue_valid;
bool IsItRealyTheEnd = false;

double prixAchat;
double prixVente;

datetime currentTime;
MqlDateTime tm={};

ulong start_time;
ulong end_time;

double min_SLTP_point;
double SL;
double TP;

double Lot;
double list_lot_size[];

string currentSymbol;
bool symbolAlreadyTrade;
bool enoughMargin;
bool TimeToTrade;

datetime date_from_session;  // session start time
MqlDateTime hour_from;
datetime date_to_session;    // session end time
MqlDateTime hour_to;

int indice;
uint ResultCode;
int correction;


//+------------------------------------------------------------------+
//| Global variables for header                                      |
//+------------------------------------------------------------------+

int countryCodeListLenght = ArraySize(countryCodeList);
MqlCalendarValue valueToTrade[];
MyMqlCalendarData MyCalendarData[];
string symbolToTrade[];
int symbolSide[];

//+------------------------------------------------------------------+
//| Fonctions auxiliaires                                            |
//+------------------------------------------------------------------+

datetime ConvertServerTimeToLocalTime(datetime eventTime){
   datetime offset=TimeTradeServer()-TimeLocal();
   return eventTime-offset;
}

datetime ConvertLocalTimeToServerTime(datetime eventTime){
   datetime offset=TimeTradeServer()-TimeLocal();
   return eventTime+offset;
}

datetime getDateInNDays(int nb_day_forward){
   return TimeLocal()+24*nb_day_forward*3600;
}

bool IsInCountryList(string countryCode){   
   for(int k=countryCodeListLenght-1; k>=0; k--) if(countryCode == countryCodeList[k]) return true;
   return false;
}

void whichSymbolAndSide(string country, string &symbol, int &side){
   
   if(country=="US" ){
      symbol = symbolList[0];
      side = 2;
   } else if(country=="EA" || country=="FR" || country=="DE"){
      symbol = symbolList[0];
      side = 1;
   } else if(country=="CA"){
      symbol = symbolList[1];
      side = 2;
   } else if(country=="AU"){
      symbol = symbolList[2];
      side = 1;
   } else if(country=="NZ"){
      symbol = symbolList[3];
      side = 1;
   } else if(country=="JP"){
      symbol = symbolList[4];
      side = 2;
   } else if(country=="CH"){
      symbol = symbolList[5];
      side = 2;
   } else { 
      symbol = symbolList[6];
      side = 1;
   }
}

int stringSeparator(string ChaineDeCaractere, string separator, string &res[]){
   int start_pos = 0;
   int separator_pos = StringFind(ChaineDeCaractere,separator, start_pos);
   do{
      ArrayResize(res,ArraySize(res)+1);
      res[ArraySize(res)-1] = StringSubstr(ChaineDeCaractere,start_pos,separator_pos-start_pos);
      start_pos = separator_pos+StringLen(separator);
      separator_pos = StringFind(ChaineDeCaractere,separator, start_pos);
   }while(separator_pos != -1);
   
   ArrayResize(res,ArraySize(res)+1);
   res[ArraySize(res)-1] = StringSubstr(ChaineDeCaractere,start_pos);
   
   return ArraySize(res);
}

void ReceivedCalendar_To_MyCalendarData(string received_data, MyMqlCalendarData &parsed_events[]){
    received_data = StringSubstr(received_data,1,StringLen(received_data)-2);

    // Diviser par "], [" pour obtenir chaque événement
    string events[];
    int total_events = stringSeparator(received_data, "], [", events);

    // Créer un tableau pour stocker les événements
    MyMqlCalendarData event;
    ArrayResize(parsed_events, total_events); // Redimensionner le tableau

    // Traiter chaque événement
    for (int i = 0; i < total_events; i++) {
        events[i] = StringSubstr(events[i],1,StringLen(events[i])-2);
        
        string fields[];
        int total_fields = stringSeparator(events[i], "\", \"", fields);
        
        string symbolStr;
        int side;
        whichSymbolAndSide(fields[1], symbolStr,side);
        
        event.time = ConvertLocalTimeToServerTime(StringToTime(fields[0]));
        event.symbol = symbolStr;
        event.side = side;
        event.importance = int(fields[2]);
        event.name = fields[3];
        event.consensus = double(fields[4]);
        event.href = fields[5];
        event.impact_type = int(fields[6]);
        
        parsed_events[i] = event;
    }
}


void PrintCalendar(MyMqlCalendarData &values[]){
   for(int i=0;i<ArraySize(values);i++)
     {
     PrintFormat("%d----  %s  --  time=%s\n        importance=%d\n        consensus=%g\n        symbol=%s\n        impact=%d\n        decision=%d\n        eventName=%s",
                  i,
                  values[i].name, 
                  TimeToString(ConvertServerTimeToLocalTime(values[i].time)),
                  values[i].importance,
                  values[i].consensus,
                  values[i].symbol,
                  values[i].impact_type,
                  values[i].decision,
                  values[i].href);
     }
}



//_____________________________________________________________________________________________________




int initSocket(){
   int socket_id = SocketCreate();
   if(SocketConnect(socket_id, "127.0.0.1", 9090, 1000*60*5)) {
      Print("-- [DEBUG] Connected to ", "127.0.0.1", ":", 9090);
      return socket_id;
   }
   else {
      Print("-- [DEBUG] Error create socket connect : ", GetLastError());
      return NULL;
   }
}


bool socksend(int sock,string request) 
{
   char req[];
   int  len=StringToCharArray(request,req)-1;
   if(len<0) return(false);
   return(SocketSend(sock,req,len)==len);
}

string socketreceive(int sock, int timeout)
{
    char rsp[];
    string result = "";
    uint len;
    uint timeout_check = GetTickCount() + timeout;

    // Attendre jusqu'à ce que des données soient prêtes à être lues ou que le délai d'attente expire
    while ((GetTickCount() < timeout_check) && !IsStopped())
    {
        len = SocketIsReadable(sock);
        if (len > 0)
        {
            int rsp_len;
            rsp_len = SocketRead(sock, rsp, len, timeout);
            if (rsp_len > 0)
            {
                result += CharArrayToString(rsp, 0, rsp_len);
                // Vérifier si le message se termine par '/'
                if (StringSubstr(result, StringLen(result) - 1, 1) == "\\")
                {
                    result = StringSubstr(result, 0, StringLen(result) - 1); // Supprimer le '/'
                    break; // Sortir de la boucle si le message est complet
                }
            }
        }
    }
    return result;
}

string Socket(int socket_id, string dateFrom, string dateTo, string eventName, string dataType)
{
   if(socket_id != INVALID_HANDLE)
   {
      if(dataType == "actual" || dataType == "previous"){
         // Concaténation des éléments de la liste en une seule chaîne séparée par des virgules
         string tosend = dateFrom + "," + "" + "," + eventName + "," + dataType;

         // Mesurer l'heure d'envoi du message
         ulong strt_time = GetMicrosecondCount();
         
         // Envoi du message
         if(socksend(socket_id, tosend))
         {
            Print("-- [DEBUG] Envoie du message à Python réussi");
            Print("-- [DEBUG] Attente de la réponse de Python");
            // Attente de la réponse du programme Python
            string received = socketreceive(socket_id, 60*10*1000); // Attendre jusqu'à 10 minutes
            
            // Mesurer l'heure de réception de la réponse
            double duration_seconds = (GetMicrosecondCount() - strt_time)/ 1000.0;
            
            if (StringLen(received) > 0) {               
               printf("-- [DEBUG] Message reçu de la part de Python : %s", received);
               printf("-- [DEBUG] Durée écoulée entre l'envoi et la réception : %f milliseconde", duration_seconds);
               return received;
            }
            else printf("-- [DEBUG] Aucune réponse reçue du serveur Python dans le délai imparti.");
         }
         else printf("-- [DEBUG] Erreur lors de l'envoi du message au serveur Python.");
      }
      else if(dataType == "calendar"){
         // Concaténation des éléments de la liste en une seule chaîne séparée par des virgules
         string tosend = dateFrom + "," + dateTo + "," + "" + "," + dataType;
         
         // Envoi du message
         if(socksend(socket_id, tosend))
         {
            Print("-- [DEBUG] Envoie de la requete de calendrier à Python réussi");
            Print("-- [DEBUG] Attente de la réponse de Python");
            // Attente de la réponse du programme Python
            string received = socketreceive(socket_id, 60*80*1000); // Attendre jusqu'à 1h20
            
            if (StringLen(received) > 0) {
               printf("-- [DEBUG] Réponse reçu de la part de Python : %s", received);
               return received;
            }
            else printf("-- [DEBUG] Aucune réponse reçue du serveur Python dans le délai imparti.");
         }
         else printf("-- [DEBUG] Erreur lors de l'envoi du message au serveur Python.");
      }
      else {
         string tosend = "close";
         if (socksend(socket_id, tosend))
         {
            Print("-- [DEBUG] Envoie du message de cloture à python ...");
            // Attendre la confirmation de la fermeture
            string received = socketreceive(socket_id, 60*10*1); // Attendre jusqu'à 1 minutes
            PrintFormat("-- [DEBUG] Message reçu de la part de Python : %s", received);
         }
         else printf("-- [DEBUG] Erreur lors de l'envoi du message de fermeture.");
      }
      
   }
   else Print("-- [DEBUG] Connection à ", "127.0.0.1", ":", 9090, " échouée, erreur ", GetLastError());
   SocketClose(socket_id);
   
   return "---------- End of connection & programme ----------";
}



//_____________________________________________________________________________________________________




double CalculateLotSize(double stop_loss_tick, double risk_percentage, string symbol, double price, int order_type, double &Lots_size_list[], int max_total_marge){
   
   // 1. Récupérer les informations nécessaires
   double tick_value = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);  // Valeur d'un tick
   double tick_size = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);    // Taille d'un tick
   double account_balance = AccountInfoDouble(ACCOUNT_BALANCE);            // Solde du compte
   double min_lot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);           // Lot minimum
   double max_lot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);           // Lot maximum
   double step_lot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);         // Incrément de lot
   
   // 2. Calculer le montant du risque en argent
   double risk = account_balance * (risk_percentage / 100);
   
   // 3. Calculer la valeur du SL
   double stop_loss_value = (stop_loss_tick / tick_size) * tick_value;
   
   // 4. Calculer la taille du lot (sans encore ajuster pour volume_step)
   double lot_size = risk / stop_loss_value;
   
   // 5. Ajuster la taille du lot
   lot_size = MathFloor(lot_size / step_lot) * step_lot;
   lot_size = MathMax(lot_size, min_lot);      // S'assurer qu'il est supérieur ou égal au lot minimum
   if(lot_size > max_lot){
      int nb_max_lot = int(lot_size/max_lot);
      ArrayResize(Lots_size_list, nb_max_lot);
      for(int n=0; n<nb_max_lot;n++) Lots_size_list[n] = max_lot;
      
      double remainder =MathMod(lot_size,max_lot);
      
      if(remainder > 0) {
         ArrayResize(Lots_size_list, ArraySize(Lots_size_list)+1);
         Lots_size_list[ArraySize(Lots_size_list)-1] = remainder;
      }
   }
   else {
      ArrayResize(Lots_size_list, ArraySize(Lots_size_list)+1);
      Lots_size_list[0] = lot_size;
   }
   
   PrintFormat("-- [DEBUG] {%s} lot size : %f",symbol, lot_size);
   
   double margin;
   if(!OrderCalcMargin((ENUM_ORDER_TYPE)order_type,symbol,lot_size,price,margin)) PrintFormat("-- [DEBUG] OrderCalcMargin() a échoué, erreur=%d",GetLastError());;
   if(AccountInfoDouble(ACCOUNT_MARGIN_FREE) - margin < 0) return 0;
   else return lot_size;
}


void ClosePosition(int MaxTimeOpenPosition){
   //---------- Close open positions if <maxTimeOpenPosition> is exceeded ----------//
   PositionInfo positionToClosed;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      positionToClosed.ticket = PositionGetTicket(i);  // Récupérer le ticket de la position
      if(PositionSelectByTicket(positionToClosed.ticket))  // Sélectionner la position
      {
         positionToClosed.open_time = (datetime)PositionGetInteger(POSITION_TIME);
         //Print("positionToClosed.open_time : ", TimeToString(PositionGetInteger(POSITION_TIME)));
         positionToClosed.symbol = PositionGetString(POSITION_SYMBOL);
         
         if(TimeCurrent() - positionToClosed.open_time > MaxTimeOpenPosition*60){
            if(trade.PositionClose(positionToClosed.symbol)) PrintFormat("-- [DEBUG] Position closed : %s - %s - %lu", positionToClosed.symbol, TimeToString(positionToClosed.open_time), positionToClosed.ticket);
            else {
               PrintFormat("-- [DEBUG] Error trade.PositionClose [%s ; %s ; %lu], erreur=%d", positionToClosed.symbol, TimeToString(positionToClosed.open_time), positionToClosed.ticket, GetLastError());
               ResultCode = trade.ResultRetcode();
               if(ResultCode != 10009) PrintFormat("-- [DEBUG] PositionClose doesn't work [%s ; %s ; %lu], code : %d : %s", positionToClosed.symbol, TimeToString(positionToClosed.open_time), positionToClosed.ticket, ResultCode, trade.ResultRetcodeDescription());
            }
         }
      }
      else Print("Error Position Select By Ticket");
   } 
   Sleep(1000);
} 


void CheckTrailingStop(int TrailingStopPoints)
{
   // Boucle sur toutes les positions ouvertes
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);  // Récupérer le ticket de la position
      if(PositionSelectByTicket(ticket))  // Sélectionner la position
      {
         double current_price = 0;
         double stop_loss = PositionGetDouble(POSITION_SL);  // Récupérer le SL actuel
         long direction = PositionGetInteger(POSITION_TYPE);  // Type de la position : Achat ou Vente
         double PointSize = SymbolInfoDouble(PositionGetSymbol(i), SYMBOL_POINT);
         
         int min_SL_point = int(SymbolInfoInteger(PositionGetSymbol(i),SYMBOL_TRADE_STOPS_LEVEL));
         TrailingStopPoints = min_SL_point > TrailingStopPoints ? min_SL_point : TrailingStopPoints;
         
         if(direction == POSITION_TYPE_BUY)  // Trailing Stop pour une position Achat
         {
            current_price = SymbolInfoDouble(PositionGetSymbol(i), SYMBOL_BID);  // Prix Bid
            int StopLevel = int((current_price - TrailingStopPoints * PointSize)/PointSize);  // Calculer le niveau de SL

            // Si le stop_loss est inférieur au nouveau niveau calculé, on ajuste
            if(StopLevel > int(MathRound(stop_loss/PointSize)))
            {
               //PrintFormat("-- [DEBUG] (Avant if SELL) SL Origine (stop_loss) : %d - SL modifié (StopLevel) : %d", int(stop_loss/PointSize), StopLevel);
               //PrintFormat("-- [DEBUG] (Avant if SELL) SL Origine (stop_loss) : %f - SL modifié (StopLevel) : %f", stop_loss, double(StopLevel*PointSize));
               //PrintFormat("-- [DEBUG] (Avant if SELL) SL Origine (stop_loss) : %d - SL modifié (StopLevel) : %d", int(MathRound(stop_loss/PointSize)), StopLevel);
               //PrintFormat("-- [DEBUG] (Avant if SELL) SL Origine (stop_loss) : %f - SL modifié (StopLevel) : %f", MathRound(stop_loss), double(StopLevel*PointSize));
               //Print("-- [DEBUG] (Avant if SELL) StopLevel < stop_loss = ", StopLevel > stop_loss);
               
               if(!trade.PositionModify(ticket, double(StopLevel*PointSize), PositionGetDouble(POSITION_TP)))
               {
                  PrintFormat("-- [DEBUG] BUY : Erreur de modification du Stop Loss pour la position %d, code erreur : %d", ticket, GetLastError());
                  PrintFormat("-- [DEBUG] SL Origine : %f - SL modifié : %f", stop_loss, StopLevel);
                  ResultCode = trade.ResultRetcode();
                  if(ResultCode != 10009) PrintFormat("-- [DEBUG] PositionModify doesn't work [%s ; %s ; %lu], code : %d : %s", PositionGetSymbol(i), TimeToString(PositionGetInteger(POSITION_TIME)), ticket, ResultCode, trade.ResultRetcodeDescription());
               }
               else {
                  PrintFormat("-- [DEBUG] {%s} {BUY} Position modify success : + %d Points",PositionGetSymbol(i), StopLevel - int(MathRound(stop_loss/PointSize)));
                  //PrintFormat("SL recalculé : %f ; nouveau SL : %f", StopLevel, PositionGetDouble(POSITION_SL));
               }
            }
         }
         else if(direction == POSITION_TYPE_SELL)  // Trailing Stop pour une position Vente
         {
            current_price = SymbolInfoDouble(PositionGetSymbol(i), SYMBOL_ASK);  // Prix Ask
            int StopLevel = int((current_price + TrailingStopPoints * PointSize)/PointSize);  // Calculer le niveau de SL
            
            // Si le stop_loss est supérieur au nouveau niveau calculé, on ajuste
            if(StopLevel < int(MathFloor(stop_loss/PointSize)))
            {
               //PrintFormat("-- [DEBUG] (Avant if SELL) SL Origine (stop_loss) : %d - SL modifié (StopLevel) : %d", int(stop_loss/PointSize), StopLevel);
               //PrintFormat("-- [DEBUG] (Avant if SELL) SL Origine (stop_loss) : %f - SL modifié (StopLevel) : %f", stop_loss, double(StopLevel*PointSize));
               //PrintFormat("-- [DEBUG] (Avant if SELL) SL Origine (stop_loss) : %d - SL modifié (StopLevel) : %d", int(MathRound(stop_loss/PointSize)), StopLevel);
               //PrintFormat("-- [DEBUG] (Avant if SELL) SL Origine (stop_loss) : %f - SL modifié (StopLevel) : %f", MathRound(stop_loss), double(StopLevel*PointSize));
               //Print("-- [DEBUG] (Avant if SELL) StopLevel < stop_loss = ", StopLevel < stop_loss);
               
               if(!trade.PositionModify(ticket, double(StopLevel*PointSize), PositionGetDouble(POSITION_TP)))
               {
                  PrintFormat("-- [DEBUG] SELL : Erreur de modification du Stop Loss pour la position %d, code erreur : %d", ticket, GetLastError());
                  PrintFormat("-- [DEBUG] SL Origine : %f - SL modifié : %f", stop_loss, StopLevel);
                  ResultCode = trade.ResultRetcode();
                  if(ResultCode != 10009) PrintFormat("-- [DEBUG] PositionModify doesn't work [%s ; %s ; %lu], code : %d : %s", PositionGetSymbol(i), TimeToString(PositionGetInteger(POSITION_TIME)), ticket, ResultCode, trade.ResultRetcodeDescription());

               }
               else {
                  PrintFormat("-- [DEBUG] {%s} {SELL} Position modify success : - %d Points",PositionGetSymbol(i), int(MathRound(stop_loss/PointSize)) - StopLevel);
                  //PrintFormat("SL recalculé : %f ; nouveau SL : %f", StopLevel, PositionGetDouble(POSITION_SL));
               }
            }
         }
      }
   }
}