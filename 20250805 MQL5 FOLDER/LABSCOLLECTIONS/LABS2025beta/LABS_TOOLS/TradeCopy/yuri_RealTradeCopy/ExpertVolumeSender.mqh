//+------------------------------------------------------------------+
//|                                           ExpertVolumeSender.mqh |
//|                                      Copyright 2021, Yuriy Bykov |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2021, Yuriy Bykov"
#property link      "https://www.mql5.com"
#property version   "1.00"

#include <Object.mqh>
#include <Arrays\Functions.mqh>
#include <Trade\Order.mqh>
#include <Trade\Position.mqh>

class CExpertVolumeSender : public CObject {
private:
   ulong             m_magicNumbers[];
   int               m_magicNumbersCount;
   string            m_senderSymbols[];
   int               m_symbolsCount;
   string            m_fileName;
   double            m_fixedBalance;
   ulong             m_currentTime;
   ulong             m_startTime;
   ulong             m_startTickCount;
   ulong             m_currentTickCount;
   Position          m_positions[];
   Order             m_orders[];
   int               m_positionsCount;
   int               m_ordersCount;
   ulong             m_magicN;
   bool              m_isNetting;
   string            m_senderSuffix;

   void              FillMarketPositions(Position& p_positions[]);
   void              FillMarketOrders(Order &p_orders[]);
   bool              IsChanged();
   bool              SavePositions(string command);
   bool              SaveOrders(string command);
   ulong             GetTick();

public:
                     CExpertVolumeSender();
                    ~CExpertVolumeSender();
   void              Init(string p_fileName, double p_fixedBalance = 0, string p_allowedSymbols = "", string p_allowedMagics = "", ulong p_magicN = 0);
   void              Deinit();
   bool              Save(string command = "OK", bool force = false);
};
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CExpertVolumeSender::CExpertVolumeSender() {
   m_fileName = "";
   m_magicNumbersCount = 0;
   m_fixedBalance = 0;
   ArrayResize(m_positions, 0);
   ArrayResize(m_orders, 0);
   m_isNetting = false;
   m_senderSuffix = "MT4";
#ifdef __MQL5__
   m_isNetting = AccountInfoInteger(ACCOUNT_MARGIN_MODE) == ACCOUNT_MARGIN_MODE_RETAIL_NETTING;
   m_senderSuffix = "MT5";
#endif
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CExpertVolumeSender::~CExpertVolumeSender() {
}
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CExpertVolumeSender::Init(string p_fileName, double p_fixedBalance = 0, string p_allowedSymbols = "", string p_allowedMagics = "", ulong p_magicN = 0) {
   m_fileName = p_fileName;
   m_magicNumbersCount = 0;
   m_fixedBalance = p_fixedBalance;
   m_magicN = p_magicN;
   m_startTime = TimeCurrent();
   m_startTickCount = GetTick();
   ArrayResize(m_positions, 0);
   ArrayResize(m_orders, 0);
   ArrayResize(m_senderSymbols, 0);

   if(p_allowedSymbols != "") {
      string symbols[];
      StringSplit(p_allowedSymbols, ';', symbols);
      for(int i = 0; i < ArraySize(symbols); i++) {
         if(StringFind(symbols[i], "=")) {
            string diffSymbols[];
            StringSplit(symbols[i], '=', diffSymbols);
            ArrayAppend(m_senderSymbols, diffSymbols[0]);
         } else {
            ArrayAppend(m_senderSymbols, symbols[i]);
         }
      }
      m_symbolsCount = ArraySize(m_senderSymbols);
   }

   if(p_allowedMagics != "") {
      string magics[];
      StringSplit(p_allowedMagics, ';', magics);
      for(int i = 0; i < ArraySize(magics); i++) {
         ulong magic = StringToInteger(magics[i]);
         ArrayAppend(m_magicNumbers, magic);
      }
      m_magicNumbersCount = ArraySize(m_magicNumbers);
   }
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CExpertVolumeSender::Deinit(void) {
   Save("LOST");
   ArrayResize(m_positions, 0);
   ArrayResize(m_orders, 0);
   ArrayResize(m_senderSymbols, 0);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CExpertVolumeSender::IsChanged(void) {
   Position positions[];

   FillMarketPositions(positions);

   return ArrayNotEqual(m_positions, positions);
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CExpertVolumeSender::Save(string command = "OK", bool force = false) {
   if(m_fileName == "") {
      return false;
   }

   if(!force && !IsChanged() && command == "OK") {
      return true;
   }

   m_currentTime = TimeCurrent();
   m_currentTickCount = GetTick();

   bool res = true;
   res &= SavePositions(command);
//res &= SaveOrders(command);

   return res;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CExpertVolumeSender::SavePositions(string command = "OK") {
   bool res = true;

   string filename = m_fileName + ".positions.csv";
   int f;

   double balance = m_fixedBalance > 0 ? m_fixedBalance : AccountInfoDouble(ACCOUNT_BALANCE);

   f = FileOpen(filename, FILE_WRITE | FILE_CSV | FILE_UNICODE, '\t', CP_UTF8);

   if(f) {
      FileWrite(f, command, m_senderSuffix);
      FileWrite(f, (long)m_currentTime, m_currentTickCount);
      FileWrite(f, balance, AccountInfoString(ACCOUNT_CURRENCY), AccountInfoInteger(ACCOUNT_LOGIN), AccountInfoInteger(ACCOUNT_LEVERAGE), m_isNetting);

      FillMarketPositions(m_positions);
      for(int i = 0; i < ArraySize(m_positions); i++) {
         Position p = m_positions[i];
         FileWrite(f, p.ticket, p.openTime, p.positionType, p.volume, p.symbol, p.priceOpen, p.stopLoss, p.takeProfit, p.magic, p.comment);
      }
      FileClose(f);
   } else {
      res = false;
   }

   res &= FileCopy(filename, 0, filename, FILE_COMMON | FILE_REWRITE);
   return (res);
}
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CExpertVolumeSender::SaveOrders(string command = "OK") {
   bool res = true;

   string filename = m_fileName + ".orders.csv";
   int f;

   double balance = m_fixedBalance > 0 ? m_fixedBalance : AccountInfoDouble(ACCOUNT_BALANCE);

   f = FileOpen(filename, FILE_WRITE | FILE_CSV | FILE_UNICODE, '\t', CP_UTF8);

   if(f) {
      FileWrite(f, command, m_senderSuffix);
      FileWrite(f, (long)m_currentTime, m_currentTickCount);
      FileWrite(f, balance, AccountInfoString(ACCOUNT_CURRENCY), AccountInfoInteger(ACCOUNT_LOGIN), AccountInfoInteger(ACCOUNT_LEVERAGE), m_isNetting);

      FillMarketOrders(m_orders);
      for(int i = 0; i < ArraySize(m_orders); i++) {
         Order o = m_orders[i];
         FileWrite(f, o.ticket, o.timeSetup, o.orderType, o.volumeInitial, o.volume, o.symbol, o.priceOpen, o.stopLoss, o.takeProfit, o.expiration, o.magic, o.comment);
      }
      FileClose(f);

   } else {
      res = false;
   }

   res &= FileCopy(filename, 0, filename, FILE_COMMON | FILE_REWRITE);
   return (res);
}
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CExpertVolumeSender::FillMarketPositions(Position &p_positions[]) {
   ArrayResize(p_positions, 0);
   int total = PositionsTotal();

   CPositionInfo p;

   for(int i = total - 1; i >= 0; i--) {
      if(p.SelectByIndex(i)) {
         ulong magic = p.Magic();
         string symbol = p.Symbol();
         if(magic == m_magicN
               || p.Type() > 1
               || (m_magicNumbersCount > 0 && ArrayFind(m_magicNumbers, magic) != -1)
               || (m_symbolsCount > 0 && ArrayFind(m_senderSymbols, symbol) == -1)) {
            continue;
         }

         ArrayAppend(p_positions, Position(p));
      }
   }
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CExpertVolumeSender::FillMarketOrders(Order &p_orders[]) {
   ArrayResize(p_orders, 0);
   int total = OrdersTotal();

   COrderInfo o;

   for(int i = total - 1; i >= 0; i--) {
      if(o.SelectByIndex(i)) {
         ulong magic = o.Magic();
         string symbol = o.Symbol();
         if(magic == m_magicN
               || o.Type() < 2 || o.Type() > 5
               || (m_magicNumbersCount > 0 && ArrayFind(m_magicNumbers, magic) != -1)
               || (m_symbolsCount > 0 && ArrayFind(m_senderSymbols, symbol) == -1)) {
            continue;
         }

         ArrayAppend(p_orders, Order(o));
      }
   }
}

#ifdef __MQL4__
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
ulong CExpertVolumeSender::GetTick(void) {
   return GetMicrosecondCount();
}
#endif

#ifdef __MQL5__
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
ulong CExpertVolumeSender::GetTick(void) {
   return GetTickCount64();
}
#endif
//+------------------------------------------------------------------+
