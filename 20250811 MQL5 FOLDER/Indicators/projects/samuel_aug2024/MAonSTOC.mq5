////+------------------------------------------------------------------+
////|                                                     MAonSTOC.mq5 |
////|                                  Copyright 2024, MetaQuotes Ltd. |
////|                                             https://www.mql5.com |
////+------------------------------------------------------------------+
//#property copyright "Copyright 2024, MetaQuotes Ltd."
//#property link      "https://www.mql5.com"
//#property version   "1.00"
////+------------------------------------------------------------------+
////| Expert initialization function                                   |
////+------------------------------------------------------------------+
//int OnInit()
//  {
////---
//
////---
//   return(INIT_SUCCEEDED);
//  }
////+------------------------------------------------------------------+
////| Expert deinitialization function                                 |
////+------------------------------------------------------------------+
//void OnDeinit(const int reason)
//  {
////---
//
//  }
////+------------------------------------------------------------------+
////| Expert tick function                                             |
////+------------------------------------------------------------------+
//void OnTick()
//  {
////---
//
//  }
////+------------------------------------------------------------------+


//+------------------------------------------------------------------+
//|                                                     MAonSTOC.mq5 |
//|                                  Copyright 2024, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict
int handle_iStochastic;
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- create handle of the indicator iStochastic
//handle_iStochastic15=iStochastic(Symbol(),PERIOD_M15,
//                                 Sto_Kperiod,Sto_Dperiod,Sto_slowing,
//                                 Sto_ma_method,Sto_price_field);
   handle_iStochastic=iStochastic(Symbol(),PERIOD_CURRENT,
                                  75,5,5,
                                  MODE_SMA,STO_CLOSECLOSE);
//--- if the handle is not created
   if(handle_iStochastic==INVALID_HANDLE)
     {
      //--- tell about the failure and output the error code
      PrintFormat("Failed to create handle of the iStochastic indicator for the symbol %s/%s, error code %d",
                  Symbol(),
                  GetLastError());
      //--- the indicator is stopped early
      return(INIT_FAILED);
     }
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
  }

int time_offset=0;

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool NewBar()
  {
   static datetime LastTime=0;
   if(iTime(Symbol(),Period(),0)+time_offset!=LastTime)
     {
      LastTime=iTime(Symbol(),Period(),0)+time_offset;
      return (true);
     }
   else
      return (false);
  }

//+------------------------------------------------------------------+
//| Get value of buffers for the iStochastic                         |
//|  the buffer numbers are the following:                           |
//|   0 - MAIN_LINE, 1 - SIGNAL_LINE                                 |
//+------------------------------------------------------------------+
bool iStochasticGetArray(int handle,const int buffer,const int start_pos,const int count,double &arr_buffer[])
  {
   if(!ArrayIsDynamic(arr_buffer))
     {
      Print("This a no dynamic array!");
      return(false);
     }
   ArrayFree(arr_buffer);
//--- reset error code
   ResetLastError();
//--- fill a part of the iStochastic array with values from the indicator buffer that has 0 index
   int copy_buffer=CopyBuffer(handle,buffer,start_pos,count,arr_buffer);
   if(copy_buffer!=count)
     {
      //--- if the copying fails, tell the error code
      PrintFormat("Failed to copy data from the iStochastic indicator, error code %d",GetLastError());
      //--- quit with false result - it means that the indicator is considered as not calculated
      return(false);
     }
//---
   return(true);
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   if(!NewBar())
      return;


   int array_size = Bars(Symbol(), Period());



   double         sto_one[];
   ArrayResize(sto_one, array_size);
   ArraySetAsSeries(sto_one,true);

   //double Signal_Stochastic[];
   //ArrayResize(Signal_Stochastic, array_size);
   //ArraySetAsSeries(Signal_Stochastic, true);

//for(int i=0; i<array_size; i++)
//   Signal_Stochastic[i] = iStochastic(NULL, Period(), 75, 5, 5, MODE_SMA, 0, MODE_SIGNAL, i);


   iStochasticGetArray(handle_iStochastic,MAIN_LINE,0,3,sto_one);


   double Signal_StochasticDbl = sto_one[1];//iStochastic(NULL, Period(), 75, 5, 5, MODE_SMA, 0, MODE_SIGNAL, 1);
   double MA_Signal_Sto = iMAOnArray(sto_one,  20, 0, MODE_EMA, 1);

   Print("Signal_Stochastic[0]:", NormalizeDouble(Signal_StochasticDbl, _Digits));
   Print("MA_Signal_Sto:", NormalizeDouble(MA_Signal_Sto, _Digits));

   //if(Signal_StochasticDbl > MA_Signal_Sto && Signal_StochasticDbl < 20)
   //  {
   //   Print("Buy");
   //   Print("Signal_Stochastic[0]:", NormalizeDouble(Signal_Stochastic[0], _Digits));
   //   Print("MA_Signal_Sto:", NormalizeDouble(MA_Signal_Sto, _Digits));
   //  }
   //if(Signal_StochasticDbl < MA_Signal_Sto && Signal_StochasticDbl > 80)
   //  {
   //   Print("Sell");
   //   Print("Signal_Stochastic[0]:", NormalizeDouble(Signal_Stochastic[0], _Digits));
   //   Print("MA_Signal_Sto:", NormalizeDouble(MA_Signal_Sto, _Digits));
   //  }

   return;
  }
//+------------------------------------------------------------------+
double iMAOnArray(double& array[], int period, int ma_shift, ENUM_MA_METHOD ma_method, int shift)
  {

   double buf[], arr[];
   int total = ArraySize(array);

   if(total <= period)
      return 0;

   if(shift > total - period - ma_shift)
      return 0;

   switch(ma_method)
     {

      case MODE_SMA:
        {

         total = ArrayCopy(arr, array, 0, shift + ma_shift, period);
         if(ArrayResize(buf, total) < 0)
            return 0;

         double sum = 0;
         int i, pos = total-1;

         for(i = 1; i < period; i++, pos--)

            sum += arr[pos];

         while(pos >= 0)
           {

            sum += arr[pos];

            buf[pos] = sum / period;

            sum -= arr[pos + period - 1];

            pos--;

           }

         return buf[0];

        }



      case MODE_EMA:
        {

         if(ArrayResize(buf, total) < 0)

            return 0;

         double pr = 2.0 / (period + 1);

         int pos = total - 2;



         while(pos >= 0)
           {

            if(pos == total - 2)

               buf[pos+1] = array[pos+1];

            buf[pos] = array[pos] * pr + buf[pos+1] * (1-pr);

            pos--;

           }

         return buf[shift+ma_shift];

        }



      case MODE_SMMA:
        {

         if(ArrayResize(buf, total) < 0)

            return(0);

         double sum = 0;

         int i, k, pos;



         pos = total - period;

         while(pos >= 0)
           {

            if(pos == total - period)
              {

               for(i = 0, k = pos; i < period; i++, k++)
                 {

                  sum += array[k];

                  buf[k] = 0;

                 }

              }

            else

               sum = buf[pos+1] * (period-1) + array[pos];

            buf[pos]=sum/period;

            pos--;

           }

         return buf[shift+ma_shift];

        }



      case MODE_LWMA:
        {

         if(ArrayResize(buf, total) < 0)

            return 0;

         double sum = 0.0, lsum = 0.0;

         double price;

         int i, weight = 0, pos = total-1;



         for(i = 1; i <= period; i++, pos--)
           {

            price = array[pos];

            sum += price * i;

            lsum += price;

            weight += i;

           }

         pos++;

         i = pos + period;

         while(pos >= 0)
           {

            buf[pos] = sum / weight;

            if(pos == 0)

               break;

            pos--;

            i--;

            price = array[pos];

            sum = sum - lsum + price * period;

            lsum -= array[i];

            lsum += price;

           }

         return buf[shift+ma_shift];

        }

     }

   return 0;

  }
//+------------------------------------------------------------------+
//| Based on http://www.mql5.com/en/articles/81                      |
//| Simplified SMA calculation.                                 |
//+------------------------------------------------------------------+
double iMAOnArrayOLD(double &Array[], int total, int iMAPeriod, int ma_shift, ENUM_MA_METHOD ma_method, int Shift)
  {
   double buf[];
   if((total > 0) && (total <= iMAPeriod))
      return(0);
   if(total == 0)
      total = ArraySize(Array);
   if(ArrayResize(buf, total) < 0)
      return(0);

   switch(ma_method)
     {
      // Simplified SMA. No longer works with ma_shift parameter.
      case MODE_SMA:
        {
         double sum = 0;
         for(int i = Shift; i < Shift + iMAPeriod; i++)
            sum += Array[i] / iMAPeriod;
         return(sum);
        }
      case MODE_EMA:
        {
         double pr = 2.0 / (iMAPeriod + 1);
         int pos = total - 2;
         while(pos >= 0)
           {
            if(pos == total - 2)
               buf[pos + 1] = Array[pos + 1];
            buf[pos] = Array[pos] * pr + buf[pos + 1] * (1 - pr);
            pos--;
           }
         return(buf[Shift + ma_shift]);
        }
      case MODE_SMMA:
        {
         double sum = 0;
         int i, k, pos;
         pos = total - iMAPeriod;
         while(pos >= 0)
           {
            if(pos == total - iMAPeriod)
              {
               for(i = 0, k = pos; i < iMAPeriod; i++, k++)
                 {
                  sum += Array[k];
                  buf[k] = 0;
                 }
              }
            else
               sum = buf[pos + 1] * (iMAPeriod - 1) + Array[pos];
            buf[pos] = sum / iMAPeriod;
            pos--;
           }
         return(buf[Shift + ma_shift]);
        }
      case MODE_LWMA:
        {
         double sum = 0.0, lsum = 0.0;
         double price;
         int i, weight = 0, pos = total - 1;
         for(i = 1; i <= iMAPeriod; i++, pos--)
           {
            price = Array[pos];
            sum += price * i;
            lsum += price;
            weight += i;
           }
         pos++;
         i = pos + iMAPeriod;
         while(pos >= 0)
           {
            buf[pos] = sum / weight;
            if(pos == 0)
               break;
            pos--;
            i--;
            price = Array[pos];
            sum = sum - lsum + price * iMAPeriod;
            lsum -= Array[i];
            lsum += price;
           }
         return(buf[Shift + ma_shift]);
        }
      default:
         return(0);
     }
   return(0);
  }
//+--------------------------------------
//+------------------------------------------------------------------+
