//+------------------------------------------------------------------+
//|                                                 MQL5 Pipe Server |
//|                        Copyright 2012, MetaQuotes Software Corp. |
//|                                              http://www.mql5.com |
//+------------------------------------------------------------------+
#pragma once

//+------------------------------------------------------------------+
//| Pipe manager                                                     |
//+------------------------------------------------------------------+
class CPipeManager
  {
private:
   HANDLE            m_handle;                  // handle
   bool              m_connected;               // flag

public:
                     CPipeManager(void);
                    ~CPipeManager(void);

   bool              Create(LPCWSTR pipename);
   void              Close(void);
   bool              IsConnected(void);

   bool              Send(void *data,size_t data_size);
   bool              Read(void *data,size_t data_size);

   bool              SendString(LPCSTR command);
   bool              ReadString(LPSTR answer,size_t answer_maxlen);

private:
   bool              ConnectClient(void);
   void              DisconnectClient(void);
  };
//+------------------------------------------------------------------+
