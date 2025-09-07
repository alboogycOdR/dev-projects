//+------------------------------------------------------------------+
//|                                        PositionAccountReader.mqh |
//|                                      Copyright 2022, Yuriy Bykov |
//|                     https://www.mql5.com/ru/market/product/73913 |
//+------------------------------------------------------------------+
#property copyright "Copyright 2022, Yuriy Bykov"
#property link      "https://www.mql5.com/ru/market/product/73913"
#property version   "1.00"

#include "PositionReader.mqh"
#include <Arrays\Functions.mqh>
#include <Trade\Position.mqh>
#include <Trade\Order.mqh>

class CPositionAccountReader : public CPositionReader {
protected:
   ulong             m_magicN;
   void              FillMarketPositions(Position &p_positions[]);

public:
                     CPositionAccountReader();
                    ~CPositionAccountReader();
   bool              Init(string p_magicN, string p_allowedSymbols = "", string p_allowedMagics = "");
   bool              Read();
};
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CPositionAccountReader::CPositionAccountReader() : CPositionReader() {
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CPositionAccountReader::~CPositionAccountReader() {
}
//+------------------------------------------------------------------+


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CPositionAccountReader::Init(string p_magicN, string p_allowedSymbols = "", string p_allowedMagics = "") {
   m_magicN = StringToInteger(p_magicN);
   return CPositionReader::Init(p_magicN, p_allowedSymbols, p_allowedMagics);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CPositionAccountReader::Read() {
   bool res = true;

   m_senderInfo.command = "OK";
   m_senderInfo.suffix = "MT4";
   m_senderInfo.balance = AccountInfoDouble(ACCOUNT_BALANCE);
   m_senderInfo.currency = AccountInfoString(ACCOUNT_CURRENCY);
   m_senderInfo.login = AccountInfoInteger(ACCOUNT_LOGIN);
   m_senderInfo.leverage = AccountInfoInteger(ACCOUNT_LEVERAGE);
   m_senderInfo.isNetting = false;

#ifdef __MQL5__
   m_senderInfo.suffix = "MT5";
   m_senderInfo.isNetting = AccountInfoInteger(ACCOUNT_MARGIN_MODE) == ACCOUNT_MARGIN_MODE_RETAIL_NETTING;

#endif

   Position positions[];

   FillMarketPositions(positions);

   m_isChanged = PositionsNotEqual(positions);

   if(m_isChanged) {
      ArrayResize(m_positions, ArraySize(positions));
      for(int i = 0; i < ArraySize(m_positions); i++) {
         m_positions[i] = positions[i];
      }

      PrintLog("Readed positions from SENDER:\n" + Position::ToString(m_positions));
   }

   return res;
}
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CPositionAccountReader::FillMarketPositions(Position &p_positions[]) {
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
