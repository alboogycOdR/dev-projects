//+------------------------------------------------------------------+
//|                                                  MyCExtremum.mqh |
//|                                     Copyright 2014, A. Emelyanov |
//|                                        A.Emelyanov2010@yandex.ru |
//+------------------------------------------------------------------+
//| Моя вариация расчета индикатора ZigZag - включающая:             |
//| 1. ZigZag базовый расчет как от MetaQuotes;                      |
//+------------------------------------------------------------------+
//| ДОБАВИТЬ:                                                        |
//| 2. ZigZag Случайно полученный мной - обратный расчет;            |
//| 3. Математически правильный поиск экстремумов функций.           |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2014, A. Emelyanov"
#property link      "A.Emelyanov2010@yandex.ru"
#property version   "1.00"
//+------------------------------------------------------------------+
//| ГЛОБАЛЬНЫЕ КОНСТАНТЫ БИБЛИОТЕКИ                                  |
//+------------------------------------------------------------------+
#define EXTREMUM_RESERVE 1000
//--- auxiliary enumeration
enum looling_for
  {
   Pike=1,                                         // searching for next high
   Sill=-1                                         // searching for next low
  };
//+------------------------------------------------------------------+
//| Подключаемые библиотеки                                          |
//+------------------------------------------------------------------+
#include <Object.mqh>
//+------------------------------------------------------------------+
//| Описание класса                                                  |
//+------------------------------------------------------------------+
class MyCExtremum : public CObject
  {
public:
   //--- ПЕРЕМЕННЫЕ, БУФЕРА ДЛЯ ОБЩЕГО ПОЛЬЗОВАНИЯ
   double            HighMapBuffer[];                             // Массив всех "экстремумов макс." 
   double            LowMapBuffer[];                              // Массив всех "экстремумов мин."
   double            ZigzagBuffer[];                              // Массив под  "ЗигЗаг"

public:
                     MyCExtremum();
                    ~MyCExtremum();
   
   //--- КЛАСИЧЕСКИЙ ZIGZAG
   int               GetHighMapZigzag(double &in[], int ExtDepth, int ExtDeviation, 
                                      int ExtBackstep);           // получение массива экстремумов макси   
   int               GetLowMapZigzag(double &in[], int ExtDepth, int ExtDeviation, 
                                      int ExtBackstep);           // получение массива экстремумов мини
   int               GetClassicZigzag(double &high[],double &low[], int ExtDepth, 
                                      int ExtDeviation, int ExtBackstep);// получить классичекий ЗигЗаг

   //--- МОДИФИЦИРОВАННЫЙ ZIGZAG
   int               _GetHighMapZigzag(double &in[], int ExtDepth, int ExtDeviation, 
                                      int ExtBackstep);           // получение массива экстремумов макси   
   int               _GetLowMapZigzag(double &in[], int ExtDepth, int ExtDeviation, 
                                      int ExtBackstep);           // получение массива экстремумов мини
   int               GetModZigzag(double &high[],double &low[], int ExtDepth, 
                                      int ExtDeviation, int ExtBackstep);// получить классичекий ЗигЗаг
   
private:
   //--- Внутренние функции
   int               iHighest(double &array[], int depth, 
                                       int startPos);             // поиск максимума
   int               iLowest(double &array[], int depth, 
                                       int startPos);             // поиск минимума
   void              CorrectMapHigh(double &in[]);                // корректирующая функция high(МОД. ZIGZAG)
   void              CorrectMapLow(double &in[]);                 // корректирующая функция low(МОД. ZIGZAG)
   void              CorrectMapZigzag();                          // убийца двойственности сигнала(МОД. ZIGZAG)
   void              CorrectMapClassicZigzag();                   // добавление посл. точки классического Zigzag
  };
//+------------------------------------------------------------------+
//| конструктор класса                                               |
//+------------------------------------------------------------------+
MyCExtremum::MyCExtremum()
  {
  }
//+------------------------------------------------------------------+
//| деструктор  класса                                               |
//+------------------------------------------------------------------+
MyCExtremum::~MyCExtremum()
  {
  }
//+------------------------------------------------------------------+
//| Функция ищет максимум в буфере array                             |
//+------------------------------------------------------------------+
int MyCExtremum::iHighest(double &array[],int depth,int startPos)
  {
   int index=startPos;
   //--- start index validation
   if(startPos<0)
     {
      Print(__FUNCTION__," ERROR: Invalid parameter in the function iHighest(...)");
      return 0;
     }
   //--- depth correction if need
   if(startPos-depth<0) depth=startPos;
   double max=array[startPos];
   //--- start searching
   for(int i=startPos;i>startPos-depth;i--)
     {
      if(array[i]>max)
        {
         index=i;
         max=array[i];
        }
     }
   //--- return index of the highest bar
   return(index);
  }
//+------------------------------------------------------------------+
//| Функция ищет минимум  в буфере array                             |
//+------------------------------------------------------------------+
int MyCExtremum::iLowest(double &array[],int depth,int startPos)
  {
   int index=startPos;
   //--- start index validation
   if(startPos<0)
     {
      Print(__FUNCTION__," ERROR: Invalid parameter in the function iLowest(...)");
      return 0;
     }
   //--- depth correction if need
   if(startPos-depth<0) depth=startPos;
   double min=array[startPos];
   //--- start searching
   for(int i=startPos;i>startPos-depth;i--)
     {
      if(array[i]<min)
        {
         index=i;
         min=array[i];
        }
     }
   //--- return index of the lowest bar
   return(index);
  }
//+------------------------------------------------------------------+
//| КЛАССИЧЕСКИЙ ZIGZAG                                              |
//+------------------------------------------------------------------+
//| получение массива экстремумов макси                              |
//+------------------------------------------------------------------+
int MyCExtremum::GetHighMapZigzag(double &in[],int ExtDepth,int ExtDeviation,int ExtBackstep)
  {
   //--- Переменные функции
   int    shift    = 0, back = 0; 
   double lasthigh = 0, res  = 0, val = 0;
   
   //--- "Переменные" обеспечивающие обратную совместимость кода(необходимо убрать их...)
   int    rates_total     = ArrayRange(in,0);         // размер входных таймсерий
   double deviation       = ExtDeviation * _Point;    // отклонение цены в пунктах
   
   //--- перевичная проверка входных данных на корректность
   if(rates_total<100)
     { 
      Print(__FUNCTION__," ERROR: the small size of the buffer!");
      return(-1);                                     //Ошибка, маленький размер буфера!
     }
   
   //--- первичная инициализация вектора нулевыми значениями
   ArrayResize(HighMapBuffer,  rates_total, EXTREMUM_RESERVE);
   ArrayFill(HighMapBuffer, 0, rates_total, 0.0);     // было значение NULL, но думаю, что корректней будет 0.0

   //--- А вот и сам код... Searching High
   for(shift=ExtDepth;shift<rates_total;shift++)
     {//--- high
      val=in[iHighest(in,ExtDepth,shift)];
      if(val==lasthigh) val=0.0;
      else
        {
         lasthigh=val;
         if((val-in[shift])>deviation) val=0.0;
         else
           {
            for(back=1;back<=ExtBackstep;back++)
              {
               res=HighMapBuffer[shift-back];
               if((res!=0) && (res<val)) HighMapBuffer[shift-back]=0.0;
              }
           }
        }
      if(in[shift]==val) HighMapBuffer[shift]=val; else HighMapBuffer[shift]=0.0;
     }   
   //--- возрат размера буфера для чтения
   return(rates_total);
  }
//+------------------------------------------------------------------+
//| получение массива экстремумов мини                               |
//+------------------------------------------------------------------+
int MyCExtremum::GetLowMapZigzag(double &in[],int ExtDepth,int ExtDeviation,int ExtBackstep)
  {
   //--- Переменные функции
   int    shift = 0, back    = 0; 
   double val   = 0, lastlow = 0, res = 0;  

   //--- "Переменные" обеспечивающие обратную совместимость кода(необходимо убрать их...)
   int    rates_total     = ArrayRange(in,0);         // размер входных таймсерий
   double deviation       = ExtDeviation * _Point;    // отклонение цены в пунктах

   //--- перевичная проверка входных данных на корректность
   if(rates_total<100)
     { 
      Print(__FUNCTION__," ERROR: the small size of the buffer!");
      return(-1);                                     //Ошибка, маленький размер буфера!
     }

   //--- первичная инициализация вектора нулевыми значениями
   ArrayResize(LowMapBuffer,   rates_total, EXTREMUM_RESERVE);
   ArrayFill(LowMapBuffer,  0, rates_total, 0.0);    // было значение NULL, но думаю, что корректней будет 0.0

   //--- А вот и сам код... Searching Low
   for(shift=ExtDepth;shift<rates_total;shift++)
     {
      val=in[iLowest(in,ExtDepth,shift)];
      if(val==lastlow) val=0.0;
      else
        {
         lastlow=val;
         if((in[shift]-val)>deviation) val=0.0;
         else
           {
            for(back=1;back<=ExtBackstep;back++)
              {
               res=LowMapBuffer[shift-back];
               if((res!=0) && (res>val)) LowMapBuffer[shift-back]=0.0;
              }
           }
        }
      if(in[shift]==val) LowMapBuffer[shift]=val; else LowMapBuffer[shift]=0.0;
     }
   //--- возрат размера буфера для чтения
   return(rates_total);
  }
//+------------------------------------------------------------------+
//| добавление посл. точки классического Zigzag                      |
//+------------------------------------------------------------------+
void MyCExtremum::CorrectMapClassicZigzag(void)
  {
   //---
   int rates_total = ArrayRange(ZigzagBuffer,0);      // размер таймсерий
   //---
   for(int i=0;i<rates_total-1;i++)
     {
      if(ZigzagBuffer[i]!=0)
        {
         //--- поиск предыдущего макси
         if(LowMapBuffer[i]!=0)
           {
            for(int a=i;a>0;a--)
              {
               if(HighMapBuffer[a]!=0)
                 {
                  ZigzagBuffer[a]=HighMapBuffer[a];
                  return;
                 }
              }
            return;
           }
         //--- поиск предыдуего  мини
         if(HighMapBuffer[i]!=0)
           {
            for(int a=i;a>0;a--)
              {
               if(LowMapBuffer[a]!=0)
                 {
                  ZigzagBuffer[a] = LowMapBuffer[a];
                  return;
                 }
              }
            return;
           }
        }
     }
  }
//+------------------------------------------------------------------+
//| ПОЛУЧЕНИЕ КЛАССИЧЕСКОГО ЗИГЗАГА                                  |
//+------------------------------------------------------------------+
int MyCExtremum::GetClassicZigzag(double &high[],double &low[],int ExtDepth,int ExtDeviation,int ExtBackstep)
  {
   //+---------------------------------------------------------------+
   //| ОЧЕНЬ ВАЖНАЯ ПРОВЕРКА ВЛИЯЮЩАЯ НА КОРРЕКТНОСТЬ ВЫЧИСЛЕНИЙ!    |
   //| ПРОВЕРКА НАПРАВЛЕНИЯ МАССИВА, ТРЕБУЕТСЯ СЛЕДУЮЩЕЕ НАПРАВЛЕНИЕ:|
   //| ИНД = 0 <- ПРОШЛОЕ, ИНД=MAX <- НАСТОЯЩЕЕ(не таймсерия)        |
   //+---------------------------------------------------------------+
   if(ArrayIsSeries(high)) ArraySetAsSeries(high,false);
   if(ArrayIsSeries(low))  ArraySetAsSeries(low,false);
   //--- Переменные функции
   int    rates_total     = ArrayRange(high,0);       // размер входных таймсерий
   if(rates_total > ArrayRange(low,0))
     {
      rates_total = ArrayRange(low,0);                // если в low меньше данных, получить нов.размер
     }
   int    limit           = rates_total - ExtDepth;   // лимит на расчеты...

   //--- "Переменные" обеспечивающие обратную совместимость кода(необходимо убрать их...)
   int    shift=0, whatlookfor=0, lasthighpos=0, lastlowpos=0;
   double res=0.0, curlow=0.0, curhigh=0.0, lasthigh=0.0, lastlow=0.0;

   //--- Проверка размера буфера
   if(rates_total<100)
     { 
      Print(__FUNCTION__," ERROR: the small size of the buffer!");
      return(-1);                                     //Ошибка, маленький размер буфера!
     }
     
   //--- готовим буфер ZigzagBuffer[]
   ArrayResize(ZigzagBuffer,   rates_total, EXTREMUM_RESERVE);
   ArrayFill(ZigzagBuffer,  0, rates_total, 0.0);    // было значение NULL, но думаю, что корректней будет 0.0
   
   //--- получаем "свежие" минимумы и максимумы
   if(GetHighMapZigzag(high,ExtDepth,ExtDeviation,ExtBackstep) < 0) return(0);
   if(GetLowMapZigzag(low,ExtDepth,ExtDeviation,ExtBackstep)   < 0) return(0);
   
   //--- код: last preparation
   if(whatlookfor==0)// uncertain quantity
     {
      lastlow=0;
      lasthigh=0;
     }else
       {
        lastlow=curlow;
        lasthigh=curhigh;
       }
   //--- final rejection
   for(shift=ExtDepth;shift<rates_total;shift++)
     {
      res=0.0;
      switch(whatlookfor)
        {
         case 0: // search for peak or lawn
            if(lastlow==0 && lasthigh==0)
              {
               if(HighMapBuffer[shift]!=0)
                 {
                  lasthigh=high[shift];
                  lasthighpos=shift;
                  whatlookfor=Sill;
                  ZigzagBuffer[shift]=lasthigh;
                  res=1;
                 }
               if(LowMapBuffer[shift]!=0)
                 {
                  lastlow=low[shift];
                  lastlowpos=shift;
                  whatlookfor=Pike;
                  ZigzagBuffer[shift]=lastlow;
                  res=1;
                 }
              }
            break;
         case Pike: // search for peak
            if(LowMapBuffer[shift]!=0.0 && LowMapBuffer[shift]<lastlow && HighMapBuffer[shift]==0.0)
              {
               ZigzagBuffer[lastlowpos]=0.0;
               lastlowpos=shift;
               lastlow=LowMapBuffer[shift];
               ZigzagBuffer[shift]=lastlow;
               res=1;
              }
            if(HighMapBuffer[shift]!=0.0 && LowMapBuffer[shift]==0.0)
              {
               lasthigh=HighMapBuffer[shift];
               lasthighpos=shift;
               ZigzagBuffer[shift]=lasthigh;
               whatlookfor=Sill;
               res=1;
              }
            break;
         case Sill: // search for lawn
            if(HighMapBuffer[shift]!=0.0 && HighMapBuffer[shift]>lasthigh && LowMapBuffer[shift]==0.0)
              {
               ZigzagBuffer[lasthighpos]=0.0;
               lasthighpos=shift;
               lasthigh=HighMapBuffer[shift];
               ZigzagBuffer[shift]=lasthigh;
              }
            if(LowMapBuffer[shift]!=0.0 && HighMapBuffer[shift]==0.0)
              {
               lastlow=LowMapBuffer[shift];
               lastlowpos=shift;
               ZigzagBuffer[shift]=lastlow;
               whatlookfor=Pike;
              }
            break;
         default: 
            CorrectMapClassicZigzag();
            return(rates_total);
        }
     }
   //--- return value of prev_calculated for next call
   CorrectMapClassicZigzag();
   return(rates_total);   
  }
//+------------------------------------------------------------------+
//| КЛАССИЧЕСКИЙ модифицированный ZIGZAG                             |
//+------------------------------------------------------------------+
//| получение массива экстремумов макси                              |
//+------------------------------------------------------------------+
int MyCExtremum::_GetHighMapZigzag(double &in[],int ExtDepth,int ExtDeviation,int ExtBackstep)
  {
   //--- Переменные функции
   int    shift    = 0, back = 0; 
   double lasthigh = 0, res  = 0, val = 0;
   
   //--- "Переменные" обеспечивающие обратную совместимость кода(необходимо убрать их...)
   int    rates_total     = ArrayRange(in,0);         // размер входных таймсерий
   int    limit           = rates_total - ExtDepth;   // лимит на расчеты...
   double deviation       = ExtDeviation * _Point;    // отклонение цены в пунктах
   
   //--- перевичная проверка входных данных на корректность
   if(rates_total<100)
     { 
      Print(__FUNCTION__," ERROR: the small size of the buffer!");
      return(-1);                                     //Ошибка, маленький размер буфера!
     }
   
   //--- первичная инициализация вектора нулевыми значениями
   ArrayResize(HighMapBuffer,  rates_total, EXTREMUM_RESERVE);
   ArrayFill(HighMapBuffer, 0, rates_total, 0.0);     // было значение NULL, но думаю, что корректней будет 0.0

   //--- А вот и сам код... Searching High
   //for(shift=ExtDepth;shift<rates_total;shift++)
   for(shift=limit; shift>=0; shift--)
     {//--- high
      val=in[iHighest(in,ExtDepth,shift)];
      if(val==lasthigh) val=0.0;
      else
        {
         lasthigh=val;
         if((val-in[shift])>deviation) val=0.0;
         else
           {
            for(back=1;back<=ExtBackstep;back++)
              {
               res=HighMapBuffer[shift+back];//res=HighMapBuffer[shift-back];
               if((res!=0) && (res<val)) HighMapBuffer[shift+back]=0.0;//if((res!=0) && (res<val)) HighMapBuffer[shift-back]=0.0;
              }
           }
        }
      if(in[shift]==val) HighMapBuffer[shift+1]=val; else HighMapBuffer[shift+1]=0.0;
     }   
   //--- Вызов корректирующей функции
   CorrectMapHigh(in);
   //--- возрат размера буфера для чтения
   return(rates_total);
  }
//+------------------------------------------------------------------+
//| получение массива экстремумов мини                               |
//+------------------------------------------------------------------+
int MyCExtremum::_GetLowMapZigzag(double &in[],int ExtDepth,int ExtDeviation,int ExtBackstep)
  {
   //--- Переменные функции
   int    shift = 0, back    = 0; 
   double val   = 0, lastlow = 0, res = 0;  

   //--- "Переменные" обеспечивающие обратную совместимость кода(необходимо убрать их...)
   int    rates_total     = ArrayRange(in,0);         // размер входных таймсерий
   int    limit           = rates_total - ExtDepth;   // лимит на расчеты...
   double deviation       = ExtDeviation * _Point;    // отклонение цены в пунктах

   //--- перевичная проверка входных данных на корректность
   if(rates_total<100)
     { 
      Print(__FUNCTION__," ERROR: the small size of the buffer!");
      return(-1);                                     //Ошибка, маленький размер буфера!
     }

   //--- первичная инициализация вектора нулевыми значениями
   ArrayResize(LowMapBuffer,   rates_total, EXTREMUM_RESERVE);
   ArrayFill(LowMapBuffer,  0, rates_total, 0.0);    // было значение NULL, но думаю, что корректней будет 0.0

   //--- А вот и сам код... Searching Low
   for(shift=limit; shift>=0; shift--)//for(shift=ExtDepth;shift<rates_total;shift++)
     {
      val=in[iLowest(in,ExtDepth,shift)];
      if(val==lastlow) val=0.0;
      else
        {
         lastlow=val;
         if((in[shift]-val)>deviation) val=0.0;
         else
           {
            for(back=1;back<=ExtBackstep;back++)
              {
               
               res=LowMapBuffer[shift+back];//res=LowMapBuffer[shift-back];
               if((res!=0) && (res>val)) LowMapBuffer[shift+back]=0.0;//if((res!=0) && (res>val)) LowMapBuffer[shift-back]=0.0;
              }
           }
        }
      if(in[shift]==val) LowMapBuffer[shift+1]=val; else LowMapBuffer[shift+1]=0.0;
     }
   //--- Вызов корректирующей функции
   CorrectMapLow(in);
   //--- возрат размера буфера для чтения
   return(rates_total);
  }
//+------------------------------------------------------------------+
//| корректирующая функция high                                      |
//+------------------------------------------------------------------+
void MyCExtremum::CorrectMapHigh(double &in[])
  {
   //---
   int rates_total = ArrayRange(HighMapBuffer,0);     // размер входных таймсерий
   //---
   for(int i=0;i<rates_total;i++)
     {
      if(HighMapBuffer[i]!=0)
        {
         HighMapBuffer[i] = in[i];
        }
     }
  }
//+------------------------------------------------------------------+
//| корректирующая функция low                                       |
//+------------------------------------------------------------------+
void MyCExtremum::CorrectMapLow(double &in[])
  {
   //---
   int rates_total = ArrayRange(LowMapBuffer,0);      // размер входных таймсерий
   //---
   for(int i=0;i<rates_total;i++)
     {
      if(LowMapBuffer[i]!=0)
        {
         LowMapBuffer[i] = in[i];
        }
     }
  }
//+------------------------------------------------------------------+
//| убийца двойственности сигнала                                    |
//+------------------------------------------------------------------+
void MyCExtremum::CorrectMapZigzag(void)
  {
   //---
   int rates_total = ArrayRange(HighMapBuffer,0);     // размер входных таймсерий
   //---
   for(int i=0;i<rates_total;i++)
     {
      if(HighMapBuffer[i]!=0&&LowMapBuffer[i]!=0)
        {
         HighMapBuffer[i] = 0.0;
         LowMapBuffer[i]  = 0.0;
        }
     }
  }
//+------------------------------------------------------------------+
//| МОДИФИЦИРОВАННЫЙ АЛГОРИТМ РАСЧЕТА ЗИГЗАГА                        |
//+------------------------------------------------------------------+
int MyCExtremum::GetModZigzag(double &high[],double &low[],int ExtDepth,int ExtDeviation,int ExtBackstep)
  {
   /*//--- auxiliary enumeration
   enum looling_for
     {
      Pike=1,                                         // searching for next high
      Sill=-1                                         // searching for next low
     };
   */
   //--- Переменные функции
   int    rates_total     = ArrayRange(high,0);       // размер входных таймсерий
   if(rates_total > ArrayRange(low,0))
     {
      rates_total = ArrayRange(low,0);                // если в low меньше данных, получить нов.размер
     }
   int    limit           = rates_total - ExtDepth;   // лимит на расчеты...

   //--- "Переменные" обеспечивающие обратную совместимость кода(необходимо убрать их...)
   int    shift=0, whatlookfor=0, lasthighpos=0, lastlowpos=0;
   double res=0.0, curlow=0.0, curhigh=0.0, lasthigh=0.0, lastlow=0.0;

   //--- Проверка размера буфера
   if(rates_total<100)
     { 
      Print(__FUNCTION__," ERROR: the small size of the buffer!");
      return(-1);                                     //Ошибка, маленький размер буфера!
     }
     
   //--- готовим буфер ZigzagBuffer[]
   ArrayResize(ZigzagBuffer,   rates_total, EXTREMUM_RESERVE);
   ArrayFill(ZigzagBuffer,  0, rates_total, 0.0);    // было значение NULL, но думаю, что корректней будет 0.0
   
   //--- получаем "свежие" минимумы и максимумы
   if(_GetHighMapZigzag(high,ExtDepth,ExtDeviation,ExtBackstep) < 0) return(0);
   if(_GetLowMapZigzag(low,ExtDepth,ExtDeviation,ExtBackstep)   < 0) return(0);
   CorrectMapZigzag();
   
   //--- код: last preparation
   if(whatlookfor==0)// uncertain quantity
     {
      lastlow=0;
      lasthigh=0;
     }else
       {
        lastlow=curlow;
        lasthigh=curhigh;
       }
   //--- final rejection
   for(shift=limit;shift>=0;shift--)//for(shift=ExtDepth;shift<rates_total;shift++)
     {
      res=0.0;
      switch(whatlookfor)
        {
         case 0: // search for peak or lawn
            if(lastlow==0 && lasthigh==0)
              {
               if(HighMapBuffer[shift]!=0)
                 {
                  lasthigh=high[shift];
                  lasthighpos=shift;
                  whatlookfor=Sill;
                  ZigzagBuffer[shift]=lasthigh;
                  res=1;
                 }
               if(LowMapBuffer[shift]!=0)
                 {
                  lastlow=low[shift];
                  lastlowpos=shift;
                  whatlookfor=Pike;
                  ZigzagBuffer[shift]=lastlow;
                  res=1;
                 }
              }
            break;
         case Pike: // search for peak
            if(LowMapBuffer[shift]!=0.0 && LowMapBuffer[shift]<lastlow && HighMapBuffer[shift]==0.0)
              {
               ZigzagBuffer[lastlowpos]=0.0;
               lastlowpos=shift;
               lastlow=LowMapBuffer[shift];
               ZigzagBuffer[shift]=lastlow;
               res=1;
              }
            if(HighMapBuffer[shift]!=0.0 && LowMapBuffer[shift]==0.0)
              {
               lasthigh=HighMapBuffer[shift];
               lasthighpos=shift;
               ZigzagBuffer[shift]=lasthigh;
               whatlookfor=Sill;
               res=1;
              }
            break;
         case Sill: // search for lawn
            if(HighMapBuffer[shift]!=0.0 && HighMapBuffer[shift]>lasthigh && LowMapBuffer[shift]==0.0)
              {
               ZigzagBuffer[lasthighpos]=0.0;
               lasthighpos=shift;
               lasthigh=HighMapBuffer[shift];
               ZigzagBuffer[shift]=lasthigh;
              }
            if(LowMapBuffer[shift]!=0.0 && HighMapBuffer[shift]==0.0)
              {
               lastlow=LowMapBuffer[shift];
               lastlowpos=shift;
               ZigzagBuffer[shift]=lastlow;
               whatlookfor=Pike;
              }
            break;
         default: return(rates_total);
        }
     }
   //--- return value of prev_calculated for next call
   return(rates_total);   
  }
//+------------------------------------------------------------------+
