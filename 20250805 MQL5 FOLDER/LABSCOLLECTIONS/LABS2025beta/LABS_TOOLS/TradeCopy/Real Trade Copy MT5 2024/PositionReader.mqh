//+------------------------------------------------------------------+
//|                                               PositionReader.mqh |
//|                                      Copyright 2022, Yuriy Bykov |
//|                     https://www.mql5.com/ru/market/product/73913 |
//+------------------------------------------------------------------+
#property copyright "Copyright 2022, Yuriy Bykov"
#property link      "https://www.mql5.com/ru/market/product/73913"
#property version   "1.00"

#include <Arrays\Functions.mqh>
#include <Trade\Position.mqh>
#include <Trade\Order.mqh>

struct SenderInfo {
   string            command;
   string            suffix;
   double            balance;
   string            currency;
   ulong             login;
   long              leverage;
   bool              isNetting;
};

class CPositionReader {
protected:
   string            m_fileName;
   double            m_volumes;
   SenderInfo        m_senderInfo;
   datetime          m_lastTime;
   ulong             m_lastTickCount;
   double            m_fixedBalance;
   double            m_depoPart;
   double            m_ratio;

   bool              m_isChanged;

   Position          m_positions[];

   ulong             m_magicNumbers[];
   int               m_magicNumbersCount;
   int               m_symbolsCount;

   string            m_senderSymbols[];
   string            m_receiverSymbols[];
   string            m_receiverSuffix;

   bool              PositionsNotEqual(Position &p_positions[]);
   ulong             GetTick();

public:
                     CPositionReader();
                    ~CPositionReader();

   virtual bool      Init(string p_fileName, string p_allowedSymbols = "", string p_allowedMagics = "");
   virtual void      Deinit();
   virtual bool      Read() = 0;
   void              FillSymbols(string &symbols[]);
   void              FillVolumes(double &volumes[], double ratio = 1);
   bool              IsChanged();
   SenderInfo        Info();
};
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CPositionReader::CPositionReader() {
   m_fileName = "";
   m_receiverSuffix = "MT4";
#ifdef __MQL5__
   m_receiverSuffix = "MT5";
#endif
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CPositionReader::~CPositionReader() {
}
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CPositionReader::Init(string p_fileName, string p_allowedSymbols = "", string p_allowedMagics = "") {
   m_fileName = p_fileName;
   m_magicNumbersCount = 0;
   m_fixedBalance = 0;
   m_depoPart = 1;
   m_lastTime = TimeCurrent();
   m_lastTickCount = GetTick();

   if(p_allowedSymbols != "") {
      string symbols[];
      StringSplit(p_allowedSymbols, ';', symbols);
      for(int i = 0; i < ArraySize(symbols); i++) {
         if(StringFind(symbols[i], "=") != -1) {
            string diffSymbols[];
            StringSplit(symbols[i], '=', diffSymbols);
            if(diffSymbols[0] != "" && diffSymbols[1] != "") {
               ArrayAppend(m_senderSymbols, diffSymbols[0]);
               ArrayAppend(m_receiverSymbols, diffSymbols[1]);
            }

         } else {
            if(symbols[i] != "") {
               ArrayAppend(m_senderSymbols, symbols[i]);
               ArrayAppend(m_receiverSymbols, symbols[i]);
            }
         }
      }
   } else {
      for(int i = 0; i < SymbolsTotal(true); i++) {
         string symbol = SymbolName(i, true);
         ArrayAppend(m_senderSymbols, symbol);
         ArrayAppend(m_receiverSymbols, symbol);
      }
   }

   m_symbolsCount = ArraySize(m_receiverSymbols);

   if(p_allowedMagics != "") {
      string magics[];
      StringSplit(p_allowedMagics, ';', magics);
      for(int i = 0; i < ArraySize(magics); i++) {
         ulong magic = StringToInteger(magics[i]);
         ArrayAppend(m_magicNumbers, magic);
      }
   }

   m_magicNumbersCount = ArraySize(m_magicNumbers);
   ArrayResize(m_positions, 0);

   return true;
}
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CPositionReader::Deinit() {
   ArrayResize(m_senderSymbols, 0);
   ArrayResize(m_receiverSymbols, 0);
   m_symbolsCount = 0;

   ArrayResize(m_magicNumbers, 0);
   m_magicNumbersCount = 0;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CPositionReader::FillSymbols(string &symbols[]) {
   ArrayCopy(symbols, m_receiverSymbols);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CPositionReader::FillVolumes(double &volumes[], double ratio = 1) {
   ArrayResize(volumes, m_symbolsCount);
   ArrayInitialize(volumes, 0);

   for(int i = 0; i < ArraySize(m_positions); i++) {
      int index = ArrayFind(m_senderSymbols, m_positions[i].symbol);

      if (index != -1) {
         volumes[index] += m_positions[i].volume * (-((int) m_positions[i].positionType) * 2 + 1);
      }
   }

   for(int i = 0; i < ArraySize(volumes); i++) {
      volumes[i] *= ratio;
   }
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CPositionReader::PositionsNotEqual(Position &p_positions[]) {
   return ArrayNotEqual(m_positions, p_positions);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CPositionReader::IsChanged(void) {
   return m_isChanged;
}
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
SenderInfo CPositionReader::Info() {
   return m_senderInfo;
}
//+------------------------------------------------------------------+


#ifdef __MQL4__
ulong CPositionReader::GetTick(void) {
   return GetMicrosecondCount();
}
#endif

#ifdef __MQL5__
ulong CPositionReader::GetTick(void) {
   return GetTickCount64();
}
#endif
//+------------------------------------------------------------------+
