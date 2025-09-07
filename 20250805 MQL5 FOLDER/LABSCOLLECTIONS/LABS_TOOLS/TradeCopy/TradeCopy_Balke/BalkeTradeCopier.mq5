//+------------------------------------------------------------------+
//|                                             BalkeTradeCopier.mq5 |
//|                                  Copyright 2023, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
/*

ref: https://www.youtube.com/watch?v=6txbB5eMvTs&t=1831s
Simple Trade Copier for MT5 - Copy Trades From One Account To Another (Full MQL5 Programming)

*/


#define FILE_NAME MQLInfoString(MQL_PROGRAM_NAME)+".bin"

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\SymbolInfo.mqh>

#property copyright "Copyright 2023, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

#include <Trade\AccountInfo.mqh>
#include <Trade\DealInfo.mqh>
#include <Trade\OrderInfo.mqh>

CTrade trade;
CPositionInfo  m_position;                   // object of CPositionInfo class
CSymbolInfo    m_symbol;                     // object of CSymbolInfo class
CAccountInfo   m_account;                    // object of CAccountInfo class
CDealInfo      m_deal;                       // object of CDealInfo class
COrderInfo     m_order;


#include <arrays/arraylong.mqh>

enum ENUM_MODE {MODE_MASTER, MODE_SLAVE};
input ENUM_MODE Mode = MODE_SLAVE;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
   EventSetTimer(1);
//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   EventKillTimer();
  }


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTimer()
  {
   if(Mode == MODE_MASTER)
     {
      int file = FileOpen(FILE_NAME, FILE_WRITE | FILE_BIN | FILE_COMMON);
      if(file != INVALID_HANDLE)
        {
         if(PositionsTotal() == 0)
           {
           // FileDelete(FILE_NAME);
           //do nothing
           }
         else
           {
            for(int i = PositionsTotal() - 1; i >= 0; i --)
              {
               CPositionInfo pos;
               if(pos.SelectByIndex(i))
                 {
                  FileWriteLong(file,pos. Ticket());
                  int length = StringLen(pos.Symbol());
                  FileWriteInteger(file, length);
                  FileWriteString(file,pos. Symbol());
                  FileWriteDouble(file,pos.Volume());
                  FileWriteInteger(file, pos.PositionType());
                  FileWriteDouble(file,pos.PriceOpen());
                  FileWriteDouble(file,pos.StopLoss());
                  FileWriteDouble(file,pos.TakeProfit());
                 }//if
              }//for
           }//else
         FileClose(file);
        }//if file not invalid
     }//if mode is master
   else
      if(Mode == MODE_SLAVE)
        {
         CArrayLong arr;
         arr.Sort();
         int file = FileOpen(FILE_NAME, FILE_READ | FILE_BIN | FILE_COMMON);
         if(file != INVALID_HANDLE)
           {
            while(!FileIsEnding(file))
              {
               ulong posTicket = FileReadLong(file);
               int length = FileReadInteger(file);
               string posSymbol = FileReadString(file, length);
               double posVolume = FileReadDouble(file);
               ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)FileReadInteger(file);
               double posPriceOpen = FileReadDouble(file);
               double posSL = FileReadDouble(file);
               double posTP = FileReadDouble(file);
               //loop thorugh all current positions currently running on the slave
               //do comparisons
               for(int i = PositionsTotal() - 1; i >= 0; i --)
                 {
                  CPositionInfo pos;
                  if(pos.SelectByIndex(i))
                    {
                     if(StringToInteger(pos.Comment()) == posTicket)
                       {
                        if(arr.SearchFirst(posTicket) < 0)
                          {
                           arr.InsertSort(posTicket);
                          }
                        if(pos.StopLoss() != posSL || pos.TakeProfit() != posTP)
                          {
                           trade.PositionModify(pos.Ticket(), posSL, posTP);
                          }
                        break;
                       }//if
                    }//if pos select
                 }//for loop
               //==
               //----------------------
               //if no existing positions on the slave
               //then
               //execute on the slave as either buy or sell
               if(arr.SearchFirst(posTicket) < 0)
                 {
                  if(posType == POSITION_TYPE_BUY)
                    {
                     trade.Buy(posVolume, posSymbol, 0, posSL, posTP, IntegerToString(posTicket));
                    }
                  else
                     if(posType == POSITION_TYPE_SELL)
                       {
                        trade.Sell(posVolume,posSymbol, 0, posSL, posTP,IntegerToString(posTicket));
                       }
                  if(trade.ResultRetcode() == TRADE_RETCODE_DONE)
                     arr.InsertSort(posTicket);
                 }//if arr.SearchFirst
              }//if
              
              //-------------------------close the file
              FileClose(file);
              
            //==
            //if we cannot find the position on slave anymore, then we close
            //becuase it has been closed on the master
            for(int i = PositionsTotal() - 1; i >= 0; i --)
              {
               CPositionInfo pos;
               if(pos.SelectByIndex(i))
                 {
                  if(arr.SearchFirst(StringToInteger(pos.Comment())) < 0)
                    {
                     trade.PositionClose(pos.Ticket());
                    }
                 }
              }
           }//else if
        }
  }//function
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
