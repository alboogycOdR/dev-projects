//+------------------------------------------------------------------+
//|                                                      ProjectName |
//|                                      Copyright 2012, CompanyName |
//|                                       http://www.companyname.net |
//+------------------------------------------------------------------+
#property strict
#property script_show_inputs

#include <R.mqh>

input string InpCommand="d:\\R\\R-3.3.2\\bin\\x64\\Rterm.exe";//Path to Rterm.exe
input int InpDebugLevel=2;//Debug Level

const bool dll_allowed=MQLInfoInteger(MQL_DLLS_ALLOWED);
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnStart()
  {

//---   
   if(!dll_allowed)
     {
      Print("DLL calls are not allowed. Please switch on this option.");
      return;
     }

//---
   long R=RInit(InpCommand+" --no-restore --no-save",InpDebugLevel);
   if(R==0)
     {
      PrintFormat("Invalid path: %s",InpCommand);
      return;
     }
//---
   int i;
   int k;
   double vecfoo[5];
   double vecbaz[5];

   for(i=0; i<5; i++)
      vecfoo[i]=i*1.25;

   RAssignVector(R,"foo",vecfoo,ArraySize(vecfoo));
   RExecute(R,"baz <- foo * 42");
   k=RGetVector(R,"baz",vecbaz,ArraySize(vecbaz));

   for(i=0; i<k; i++)
      Print(vecbaz[i]);

   RDeinit(R);
  }
//+------------------------------------------------------------------+
