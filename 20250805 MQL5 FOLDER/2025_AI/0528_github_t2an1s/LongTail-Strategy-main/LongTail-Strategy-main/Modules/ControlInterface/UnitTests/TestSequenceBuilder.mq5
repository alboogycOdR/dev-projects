//+------------------------------------------------------------------+
//|                                              SequenceBuilder.mq5 |
//|                                      Copyright 2025, Anyim Ossi. |
//|                                          anyimossi.dev@gmail.com |
//+------------------------------------------------------------------+

// Modules
#include  <Ossi\LongTails\SequenceBuilder.mqh> || "SequenceBuilder.mqh"

// Accept Input
#property  script_show_inputs
input int  multiplier = 3;


void OnStart()
  {
   TestSequenceBuilder();
   
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void TestSequenceBuilder()
   {
   double sequence[];
   build_sequence(multiplier, sequence);
   
   Print(StringFormat("\nLongTail %dX Sequence",multiplier));
   ArrayPrint(sequence);
   }
