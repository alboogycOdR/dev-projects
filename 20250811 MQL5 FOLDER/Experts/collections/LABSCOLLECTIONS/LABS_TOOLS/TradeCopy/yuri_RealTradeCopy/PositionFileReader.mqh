//+------------------------------------------------------------------+
//|                                           PositionFileReader.mqh |
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

class CPositionFileReader : public CPositionReader {

public:
   CPositionFileReader();
   ~CPositionFileReader();

   bool Read();
};
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CPositionFileReader::CPositionFileReader() : CPositionReader() {
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CPositionFileReader::~CPositionFileReader() {
}
//+------------------------------------------------------------------+


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CPositionFileReader::Read() {
   if(m_fileName == "") {
      return false;
   }

   bool res = true;

   string filename = m_fileName + ".positions.csv";
   int f;

   f = FileOpen(filename, FILE_READ | FILE_CSV | FILE_UNICODE, '\t', CP_UTF8);

   if(f) {
      string command = FileReadString(f);
      string p_senderSuffix = FileReadString(f);

      m_senderInfo.command = command;
      m_senderInfo.suffix = p_senderSuffix;
      
      if(res && command == "OK") {

         datetime lastTime = (datetime) StringToInteger(FileReadString(f));
         ulong lastTickCount = (ulong) StringToInteger(FileReadString(f));

         if (lastTime == m_lastTime && lastTickCount == m_lastTickCount) {
            m_isChanged = false;
            return res;
         } else {
            m_isChanged = true;
         }

         m_senderInfo.balance = FileReadNumber(f);
         m_senderInfo.currency = FileReadString(f); // AccountInfoString(ACCOUNT_CURRENCY)
         m_senderInfo.login = StringToInteger(FileReadString(f)); // AccountInfoInteger(ACCOUNT_LOGIN),
         m_senderInfo.leverage = StringToInteger(FileReadString(f)); // AccountInfoInteger(ACCOUNT_LEVERAGE),
         m_senderInfo.isNetting = FileReadBool(f); // AccountInfoInteger(ACCOUNT_MARGIN_MODE) == ACCOUNT_MARGIN_MODE_RETAIL_NETTING);

         Position positions[];

         while(!FileIsEnding(f)) {
            Position position;
            position.ReadFromFile(f);

            if(m_magicNumbersCount > 0 && ArrayFind(m_magicNumbers, position.magic) != -1) {
               continue;
            } else if(ArrayFind(m_senderSymbols, position.symbol) == -1) {
               continue;
            }

            ArrayAppend(positions, position);
         }

         m_isChanged = PositionsNotEqual(positions);

         if(m_isChanged) {
            ArrayResize(m_positions, ArraySize(positions));
            for(int i = 0; i < ArraySize(m_positions); i++) {
               m_positions[i] = positions[i];
            }
            
            PrintLog("Readed positions from SENDER:\n" + Position::ToString(m_positions));
         }
      } else {
         res = false;
      }
      FileClose(f);
   } else {
      res = false;
   }
   return res;
}
//+------------------------------------------------------------------+
