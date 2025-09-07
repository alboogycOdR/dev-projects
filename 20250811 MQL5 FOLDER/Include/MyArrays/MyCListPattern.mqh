//+------------------------------------------------------------------+
//|                                               MyCListPattern.mqh |
//|                                     Copyright 2014, A. Emelyanov |
//|                                        A.Emelyanov2010@yandex.ru |
//+------------------------------------------------------------------+
//| Класс-контейнер для хранения графических-объектов паттерной моде-|
//| ли(класса MyCPatternZigzag).                                     |
//| Входит в состав пяти паттерной ТС. Обеспечивает вывод информации |
//| на график пользователя.                                          |
//|                                                                  |
//| Версия: молчун - без обработки ошибок!                           |
//+------------------------------------------------------------------+
#property copyright "Copyright 2014, A. Emelyanov"
#property link      "A.Emelyanov2010@yandex.ru"
#property version   "1.02"
//+------------------------------------------------------------------+
//| Подключаемые библиотеки                                          |
//+------------------------------------------------------------------+
#include <MyArrays\MyCListArrow.mqh>
#include <MyArrays\MyCListTrendLine.mqh>
#include <MyArrays\MyCListHLine.mqh>
//+------------------------------------------------------------------+
//| класс MyCListPattern                                             |
//+------------------------------------------------------------------+
class MyCListPattern
  {
private:
   //--- Параметры для Arrow
   color             ColorArrow;
   //--- Параметры для Trend
   color             ColorTrend;
   ENUM_LINE_STYLE   StyleTrend;
   int               WidthTrend;
   bool              BackTrend;
   //--- Параметры для HLine
   ENUM_LINE_STYLE   StyleHLine;                           // стиль  объекта
   color             ColorUpHLine;                         // цвет "сопротивления"        
   color             ColorDownHLine;                       // цвет "поддерки"        
   int               WidthHLine;                           // толщина
   bool              BackHLine;                            // задний план(позиция объекта на графике)
   //--- указатели на списки и т.п.
   MyCListArrow*     ListArrow;
   MyCListTrendLine* ListTrend;
   MyCListHLine*     ListHLine;
public:
                     MyCListPattern();
                    ~MyCListPattern();
   //--- 
   void              Insert(double A, datetime tA, double B, datetime tB, 
                            double C, datetime tC, double D, datetime tD,
                            double E, datetime tE, double Ev,datetime tEv,
                            double M, datetime tM);                // Вставляем данные для отображения на графике
   //--- Методы Get
   color             GetColorArrow(void){return(ColorArrow);};     //
   color             GetColorTrend(void){return(ColorTrend);};     //
   ENUM_LINE_STYLE   GetStyleTrend(void){return(StyleTrend);};     //
   int               GetWidthTrend(void){return(WidthTrend);};     //
   bool              GetBackTrend(void){return(BackTrend);};       //
   ENUM_LINE_STYLE   GetStyleHLine(void){return(StyleHLine);};     // стиль  объекта
   color             GetColorUpHLine(void){return(ColorUpHLine);}; // цвет "сопротивления"        
   color             GetColorDownHLine(void){return(ColorDownHLine);};// цвет "поддерки"        
   int               GetWidthHLine(void){return(WidthHLine);};     // толщина
   bool              GetBackHLine(void){return(BackHLine);};       // задний план(позиция объекта на графике)
   //--- Методы Set
   void              SetColorArrow(color New){ColorArrow = New;};  //
   void              SetColorTrend(color New){ColorTrend = New;};  //
   void              SetStyleTrend(ENUM_LINE_STYLE New){StyleTrend=New;};//
   void              SetWidthTrend(int New){WidthTrend = New;};    //
   void              SetBackTrend(bool New){BackTrend = New;};     //
   void              SetStyleHLine(ENUM_LINE_STYLE New){StyleHLine=New;};// стиль  объекта
   void              SetColorUpHLine(color New){ColorUpHLine=New;};// цвет "сопротивления"        
   void              SetColorDownHLine(color New){ColorDownHLine=New;};// цвет "поддерки"        
   void              SetWidthHLine(int New){WidthHLine=New;};      // толщина
   void              SetBackHLine(bool New){BackHLine=New;};       // задний план(позиция объекта на графике)
private:
   double            CorrectArrowChart(int nCorrectY, datetime time, 
                                       double price);              // корректировка положения Arrow на графике цены
  };
//+------------------------------------------------------------------+
//| конструктор                                                      |
//+------------------------------------------------------------------+
MyCListPattern::MyCListPattern()
  {
   //--- создание классов-объектов
   ListArrow = new MyCListArrow;
   ListTrend = new MyCListTrendLine;
   ListHLine = new MyCListHLine;
   //--- переменные по умолчанию
   this.ColorArrow = clrBlue;
   this.ColorTrend = clrGold;
   this.StyleTrend = STYLE_SOLID;
   this.WidthTrend = 1;
   this.BackTrend  = true;
   this.StyleHLine = STYLE_SOLID;             // стиль  объекта
   this.ColorUpHLine   = clrBlue;             // цвет "сопротивления"        
   this.ColorDownHLine = clrRed;              // цвет "поддерки"        
   this.WidthHLine = 1;                       // толщина
   this.BackHLine  = true;                    // задний план(позиция объекта на графике)
  }
//+------------------------------------------------------------------+
//| деконструктор                                                    |
//+------------------------------------------------------------------+
MyCListPattern::~MyCListPattern()
  {
   //---
   delete ListArrow;
   delete ListTrend;
   delete ListHLine;
  }
//+------------------------------------------------------------------+
//| Вставка данных на график                                         |
//+------------------------------------------------------------------+
void MyCListPattern::Insert(double A, datetime tA, double B, datetime tB, 
                            double C, datetime tC, double D, datetime tD,
                            double E, datetime tE, double Ev,datetime tEv,
                            double M, datetime tM)
  {
   //--- проверка входных данных(проверку )
   if(A < 0 || B < 0 || C < 0 || D < 0 || E < 0) return;
   //--- очистка "стрелок"
   if(ListArrow.GetSize() > 0)
     {
      ListArrow.ClearAll();
     }
   //--- очистка "T-линий"
   if(ListTrend.GetSize() > 0)
     {
      ListTrend.ClearAll();
     }
   //--- очистка "H-линий"
   if(ListHLine.GetSize() > 0)
     {
      ListHLine.ClearAll();
     }
   //+---------------------------------------------------------------+
   //| Вставка данных на график, отрисовка Arrow. Получаем масштаб   |
   //+---------------------------------------------------------------+
   //---
   ListArrow.Insert(CorrectArrowChart(-6, tA, A), tA);
   //ListArrow.Insert(A, tA);
   ListArrow.SetAtNameOfCode(ListArrow.GetLastArrowName(),  140);
   ListArrow.SetAtNameOfColor(ListArrow.GetLastArrowName(), ColorArrow);
   ListArrow.SetAtNameOfTip(ListArrow.GetLastArrowName(),"point A");
   //---
   ListArrow.Insert(CorrectArrowChart(-6, tB, B), tB);
   //ListArrow.Insert(B, tB);
   ListArrow.SetAtNameOfCode(ListArrow.GetLastArrowName(),  141);
   ListArrow.SetAtNameOfColor(ListArrow.GetLastArrowName(), ColorArrow);
   ListArrow.SetAtNameOfTip(ListArrow.GetLastArrowName(),"point B");
   //---
   ListArrow.Insert(CorrectArrowChart(-6, tC, C), tC);
   //ListArrow.Insert(C, tC);
   ListArrow.SetAtNameOfCode(ListArrow.GetLastArrowName(),  142);
   ListArrow.SetAtNameOfColor(ListArrow.GetLastArrowName(), ColorArrow);
   ListArrow.SetAtNameOfTip(ListArrow.GetLastArrowName(),"point C");
   //---
   ListArrow.Insert(CorrectArrowChart(-6, tD, D), tD);
   //ListArrow.Insert(D, tD);
   ListArrow.SetAtNameOfCode(ListArrow.GetLastArrowName(),  143);
   ListArrow.SetAtNameOfColor(ListArrow.GetLastArrowName(), ColorArrow);
   ListArrow.SetAtNameOfTip(ListArrow.GetLastArrowName(),"point D");
   //---
   ListArrow.Insert(CorrectArrowChart(-6, tE, E), tE);
   //ListArrow.Insert(E, tE);
   ListArrow.SetAtNameOfCode(ListArrow.GetLastArrowName(),  144);
   ListArrow.SetAtNameOfColor(ListArrow.GetLastArrowName(), ColorArrow);
   ListArrow.SetAtNameOfTip(ListArrow.GetLastArrowName(),"point E");
   //---
   if(Ev > 0)
     {
      ListArrow.Insert(CorrectArrowChart(-6, tEv, Ev), tEv);
      //ListArrow.Insert(Ev, tEv);
      ListArrow.SetAtNameOfCode(ListArrow.GetLastArrowName(),  108);
      ListArrow.SetAtNameOfColor(ListArrow.GetLastArrowName(), ColorArrow);
      ListArrow.SetAtNameOfTip(ListArrow.GetLastArrowName(),"Evolution");
     }
   //---
   if(M > 0)
     {
      ListArrow.Insert(CorrectArrowChart(-6, tM, M), tM);
      //ListArrow.Insert(M, tM);
      ListArrow.SetAtNameOfCode(ListArrow.GetLastArrowName(),  109);
      ListArrow.SetAtNameOfColor(ListArrow.GetLastArrowName(), ColorArrow);
      ListArrow.SetAtNameOfTip(ListArrow.GetLastArrowName(),"Mutation");
     }
   //--- отрисовка Trend
   ListTrend.Insert("Line_A-B",A,tA,B,tB,StyleTrend);
   ListTrend.SetAtNameOfColor(ListTrend.GetLastTrendName(),ColorTrend);
   ListTrend.SetAtNameOfWidth(ListTrend.GetLastTrendName(),WidthTrend);
   ListTrend.SetAtNameOfBack(ListTrend.GetLastTrendName(), BackTrend);   
   //---
   ListTrend.Insert("Line_B-C",B,tB,C,tC,StyleTrend);
   ListTrend.SetAtNameOfColor(ListTrend.GetLastTrendName(),ColorTrend);
   ListTrend.SetAtNameOfWidth(ListTrend.GetLastTrendName(),WidthTrend);
   ListTrend.SetAtNameOfBack(ListTrend.GetLastTrendName(), BackTrend);   
   //---
   ListTrend.Insert("Line_C-D",C,tC,D,tD,StyleTrend);
   ListTrend.SetAtNameOfColor(ListTrend.GetLastTrendName(),ColorTrend);
   ListTrend.SetAtNameOfWidth(ListTrend.GetLastTrendName(),WidthTrend);
   ListTrend.SetAtNameOfBack(ListTrend.GetLastTrendName(), BackTrend);   
   //---
   ListTrend.Insert("Line_D-E",D,tD,E,tE,StyleTrend);
   ListTrend.SetAtNameOfColor(ListTrend.GetLastTrendName(),ColorTrend);
   ListTrend.SetAtNameOfWidth(ListTrend.GetLastTrendName(),WidthTrend);
   ListTrend.SetAtNameOfBack(ListTrend.GetLastTrendName(), BackTrend);
   //---
   if(Ev > 0)
     {
      ListTrend.Insert("Line_Evolution",E,tE,Ev,tEv,STYLE_DOT);
      ListTrend.SetAtNameOfColor(ListTrend.GetLastTrendName(),ColorTrend);
      ListTrend.SetAtNameOfWidth(ListTrend.GetLastTrendName(),1);
      ListTrend.SetAtNameOfBack(ListTrend.GetLastTrendName(), BackTrend);
     }
   //---
   if(M > 0) 
     {
      ListTrend.Insert("Line_Mutation",E,tE,M,tM,STYLE_DOT);
      ListTrend.SetAtNameOfColor(ListTrend.GetLastTrendName(),ColorTrend);
      ListTrend.SetAtNameOfWidth(ListTrend.GetLastTrendName(),1);
      ListTrend.SetAtNameOfBack(ListTrend.GetLastTrendName(), BackTrend);
     }
   //--- отрисовка HLine
   if(A>B)
     {
      ListHLine.Insert(A, StyleHLine);
      ListHLine.SetAtNameOfColor(ListHLine.GetLastHLineName(),ColorUpHLine);
      ListHLine.SetAtNameOfWidth(ListHLine.GetLastHLineName(),WidthHLine);
      ListHLine.SetAtNameOfBack(ListHLine.GetLastHLineName(), BackHLine);
     }else
        {
         ListHLine.Insert(A, StyleHLine);
         ListHLine.SetAtNameOfColor(ListHLine.GetLastHLineName(),ColorDownHLine);
         ListHLine.SetAtNameOfWidth(ListHLine.GetLastHLineName(),WidthHLine);
         ListHLine.SetAtNameOfBack(ListHLine.GetLastHLineName(), BackHLine);
        }    
   //---
   if(B>C)
     {
      ListHLine.Insert(B, StyleHLine);
      ListHLine.SetAtNameOfColor(ListHLine.GetLastHLineName(),ColorUpHLine);
      ListHLine.SetAtNameOfWidth(ListHLine.GetLastHLineName(),WidthHLine);
      ListHLine.SetAtNameOfBack(ListHLine.GetLastHLineName(), BackHLine);
     }else
        {
         ListHLine.Insert(B, StyleHLine);
         ListHLine.SetAtNameOfColor(ListHLine.GetLastHLineName(),ColorDownHLine);
         ListHLine.SetAtNameOfWidth(ListHLine.GetLastHLineName(),WidthHLine);
         ListHLine.SetAtNameOfBack(ListHLine.GetLastHLineName(), BackHLine);
        }    
   //---
   if(C>D)
     {
      ListHLine.Insert(C, StyleHLine);
      ListHLine.SetAtNameOfColor(ListHLine.GetLastHLineName(),ColorUpHLine);
      ListHLine.SetAtNameOfWidth(ListHLine.GetLastHLineName(),WidthHLine);
      ListHLine.SetAtNameOfBack(ListHLine.GetLastHLineName(), BackHLine);
     }else
        {
         ListHLine.Insert(C, StyleHLine);
         ListHLine.SetAtNameOfColor(ListHLine.GetLastHLineName(),ColorDownHLine);
         ListHLine.SetAtNameOfWidth(ListHLine.GetLastHLineName(),WidthHLine);
         ListHLine.SetAtNameOfBack(ListHLine.GetLastHLineName(), BackHLine);
        }    
   //---
   if(D>E)
     {
      ListHLine.Insert(D, StyleHLine);
      ListHLine.SetAtNameOfColor(ListHLine.GetLastHLineName(),ColorUpHLine);
      ListHLine.SetAtNameOfWidth(ListHLine.GetLastHLineName(),WidthHLine);
      ListHLine.SetAtNameOfBack(ListHLine.GetLastHLineName(), BackHLine);
     }else
        {
         ListHLine.Insert(D, StyleHLine);
         ListHLine.SetAtNameOfColor(ListHLine.GetLastHLineName(),ColorDownHLine);
         ListHLine.SetAtNameOfWidth(ListHLine.GetLastHLineName(),WidthHLine);
         ListHLine.SetAtNameOfBack(ListHLine.GetLastHLineName(), BackHLine);
        }      
  }
//+------------------------------------------------------------------+
//| Корректировка положения значков Arrow на графике цены            |
//| in : nCorrectY - кол-во пикселей корректировки, time - время кор-|
//|      ректироки, price - цена корректировки                       |
//| out: новая цена для отображения на графике                       |
//+------------------------------------------------------------------+
double MyCListPattern::CorrectArrowChart(int nCorrectY, datetime time, double price)
  {
   //--- Временные переменные
   int      x=0, y=0, sub_window=0;
   double   m_price = price;
   datetime m_time  = time;
   //--- Возрат значения "новой цены"
   if(ChartTimePriceToXY(0,sub_window,m_time,m_price,x,y))
     {
      if(ChartXYToTimePrice(0,x,(y+nCorrectY),sub_window,m_time,m_price)) return(m_price);
     }
   //--- Ошибка, вернем что взяли... :-)
   return(price);
  }
//+------------------------------------------------------------------+
