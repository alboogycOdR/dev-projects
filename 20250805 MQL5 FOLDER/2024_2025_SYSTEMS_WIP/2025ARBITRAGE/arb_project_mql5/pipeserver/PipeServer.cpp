//+------------------------------------------------------------------+
//|                                                 MQL5 Pipe Server |
//|                        Copyright 2012, MetaQuotes Software Corp. |
//|                                              http://www.mql5.com |
//+------------------------------------------------------------------+
#include "stdafx.h"
#include "Pipes\PipeManager.h"

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int PipeServer(void)
  {
   wprintf(L"MQL5 Pipe Server\n");
   wprintf(L"Copyright 2012, MetaQuotes Software Corp.\n");
//--- create named pipe
   CPipeManager manager;

   if(!manager.Create(L"\\\\.\\pipe\\MQL5.Pipe.Server"))
      return(-1);
//--- wait for client
   char          answer[256];
   int           value=1234567890;

   wprintf(L"Client: waiting for connection...\n");
   while(!manager.IsConnected())
     {
      if(!manager.ReadString(answer,_countof(answer)-1))
        {
         Sleep(250);
         continue;
        }
      wprintf(L"Client: connected as '%S'\n",answer);
     }
//--- send data to client
   wprintf(L"Server: send string\n");
   if(!manager.SendString("Hello from pipe server"))
     {
      wprintf(L"Server: sending string failed\n");
      return(-1);
     }

   wprintf(L"Server: sending integer\n");
   if(!manager.Send(&value,sizeof(value)))
     {
      wprintf(L"Server: sending integer failed\n");
      return(-1);
     }
//--- read data from client
   wprintf(L"Server: reading string\n");
   if(!manager.ReadString(answer,_countof(answer)-1))
     {
      wprintf(L"Server: reading string failed\n");
      return(-1);
     }
   wprintf(L"Server: '%S' received\n",answer);

   wprintf(L"Server: reading integer\n");
   if(!manager.Read(&value,sizeof(value)))
     {
      wprintf(L"Server: reading integer failed\n");
      return(-1);
     }
   wprintf(L"Server: %d received\n",value);
//--- benchmark
   double  volume=0.0;
   double *buffer=new double[1024*1024];   // 8 Mb

   wprintf(L"Server: start benchmark\n");
   if(buffer)
     {
      //--- fill the buffer
      for(size_t j=0;j<1024*1024;j++)
         buffer[j]=j;
      //--- send 8 Mb * 128 = 1024 Mb to client
      DWORD   ticks=GetTickCount();

      for(size_t i=0;i<128;i++)
        {
         //--- setup guard signatures
         buffer[0]=i;
         buffer[1024*1024-1]=i+1024*1024-1;
         //--- 
         if(!manager.Send(buffer,sizeof(double)*1024*1024))
           {
            wprintf(L"Server: benchmark failed, %d\n",GetLastError());
            break;
           }
         volume+=sizeof(double)*1024*1024;
         wprintf(L".");
        }
      wprintf(L"\n");
      //--- read confirmation
      if(!manager.Read(&value,sizeof(value)) || value!=12345)
         wprintf(L"Server: benchmark confirmation failed\n");
      //--- show statistics
      ticks=GetTickCount()-ticks;
      if(ticks>0)
         wprintf(L"Server: %.0lf Mb sent at %.0lf Mb per second\n",volume/1024/1024,volume/1024/ticks);
      //---
      delete[] buffer;
     }
//---
   return(0);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int _tmain(int argc, _TCHAR* argv[])
  {
   wprintf(L"MQL5 Pipe Server\n");
   wprintf(L"Copyright 2012, MetaQuotes Software Corp.\n");
//--- create named pipe
   while(true)
     {
      PipeServer();
     }
//---
   return(0);
  }
//+------------------------------------------------------------------+
