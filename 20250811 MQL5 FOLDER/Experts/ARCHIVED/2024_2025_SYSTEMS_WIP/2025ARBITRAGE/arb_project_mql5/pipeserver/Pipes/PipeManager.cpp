//+------------------------------------------------------------------+
//|                                                 MQL5 Pipe Server |
//|                        Copyright 2012, MetaQuotes Software Corp. |
//|                                              http://www.mql5.com |
//+------------------------------------------------------------------+
#include "StdAfx.h"
#include "PipeManager.h"

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CPipeManager::CPipeManager(void):m_handle(INVALID_HANDLE_VALUE),m_connected(false)
  {
  }
//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CPipeManager::~CPipeManager(void)
  {
   Close();
  }
//+------------------------------------------------------------------+
//| Create named pipe                                                |
//+------------------------------------------------------------------+
bool CPipeManager::Create(LPCWSTR pipename)
  {
//--- check parameters
   if(!pipename || *pipename==0) return(false);
//--- close old
   Close();
//--- create named pipe
   m_handle=CreateNamedPipe(pipename,PIPE_ACCESS_DUPLEX,
                            PIPE_TYPE_BYTE | PIPE_READMODE_BYTE | PIPE_WAIT,
                            PIPE_UNLIMITED_INSTANCES,256*1024,256*1024,5000,NULL);

   if(m_handle==INVALID_HANDLE_VALUE)
     {
      wprintf(L"Creating pipe '%s' failed\n",pipename);
      return(false);
     }
//--- ok
   wprintf(L"Pipe '%s' created\n",pipename);
   return(true);
  }
//+------------------------------------------------------------------+
//| Close pipe                                                       |
//+------------------------------------------------------------------+
void CPipeManager::Close(void)
  {
//--- pipe exists?
   if(m_handle!=INVALID_HANDLE_VALUE)
     {
      DisconnectNamedPipe(m_handle);     // disconnect
      CloseHandle(m_handle);             // close
      m_handle=INVALID_HANDLE_VALUE;
     }
//---
  }
//+------------------------------------------------------------------+
//| Client connected?                                                |
//+------------------------------------------------------------------+
bool CPipeManager::IsConnected(void)
  {
   return(m_connected);
  }
//+------------------------------------------------------------------+
//| Connect client                                                   |
//+------------------------------------------------------------------+
bool CPipeManager::ConnectClient(void)
  {
//--- pipe exists?
   if(m_handle==INVALID_HANDLE_VALUE) return(false);
//--- connected?
   if(!m_connected)
     {
      //--- connect
      if(ConnectNamedPipe(m_handle,NULL)==0)
        {
         //--- client already connected before ConnectNamedPipe?
         if(GetLastError()!=ERROR_PIPE_CONNECTED)
            return(false);
         //--- ok
        }
      m_connected=true;
     }
//---
   return(true);
  }
//+------------------------------------------------------------------+
//| Disconnect                                                       |
//+------------------------------------------------------------------+
void CPipeManager::DisconnectClient(void)
  {
//--- pipe exists?
   if(m_handle!=INVALID_HANDLE_VALUE)
     {
      FlushFileBuffers(m_handle);
      DisconnectNamedPipe(m_handle);
     }
//--- drop flag
   m_connected=false;
  }
//+------------------------------------------------------------------+
//| Send any data                                                    |
//+------------------------------------------------------------------+
bool CPipeManager::Send(void *data,size_t data_size)
  {
//--- check parameters
   if(!data || data_size<1) return(false);
//--- connected?
   if(!m_connected)
      if(!ConnectClient())
         return(false);
//--- send data
   DWORD written=0;
   if(!WriteFile(m_handle,data,data_size,&written,NULL) || written!=data_size)
      return(false);
//--- ok
   return(true);
  }
//+------------------------------------------------------------------+
//| Read any data                                                    |
//+------------------------------------------------------------------+
bool CPipeManager::Read(void *data,size_t data_size)
  {
//--- check parameters
   if(!data || data_size<1) return(false);
//--- connected?
   if(!m_connected)
      if(!ConnectClient())
         return(false);
//--- read data
   DWORD received=0;

   if(!ReadFile(m_handle,data,data_size,&received,NULL) || received!=data_size)
      return(false);
//--- ok
   return(true);
  }
//+------------------------------------------------------------------+
//| Send string                                                      |
//+------------------------------------------------------------------+
bool CPipeManager::SendString(LPCSTR command)
  {
//--- check parameters
   if(!command || *command==0) return(false);
//--- connected?
   if(!m_connected)
      if(!ConnectClient())
         return(false);
//--- send string (size+data)
   DWORD size=strlen(command);
   DWORD written=0;

   if(!WriteFile(m_handle,&size,sizeof(size),&written,NULL) || written!=sizeof(size))
      return(false);

   if(!WriteFile(m_handle,command,size,&written,NULL) || written!=size)
      return(false);
//--- ok
   return(true);
  }
//+------------------------------------------------------------------+
//| Read string from client                                          |
//+------------------------------------------------------------------+
bool CPipeManager::ReadString(LPSTR answer,size_t answer_maxlen)
  {
//--- check parameters
   if(!answer || answer_maxlen<2) return(false);
   *answer=0;
//--- connected?
   if(!m_connected)
      if(!ConnectClient())
         return(false);
//--- read ANSI string (size+data)
   DWORD size=0;
   DWORD received=0;

   if(!ReadFile(m_handle,&size,sizeof(size),&received,NULL) || received!=sizeof(size))
      return(false);

   if(size<2 || size>answer_maxlen)
      return(false);

   if(!ReadFile(m_handle,answer,size,&received,NULL) || received!=size)
      return(false);
   answer[size]=0;
//--- ok
   return(true);
  }
//+------------------------------------------------------------------+
