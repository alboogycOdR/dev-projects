//+------------------------------------------------------------------+
//|                                                 MyCTrendLine.mqh |
//|                                     Copyright 2014, A. Emelyanov |
//|                                        A.Emelyanov2010@yandex.ru |
//+------------------------------------------------------------------+
//| Базовый класс для отображения и хранения объектов трендовая линия|
//| Создан для упрощенной работы с графическими объектами и реали-   |
//| зации др. класса MyCListTrendLine - список объектов тренд линий. |
//+------------------------------------------------------------------+
#property copyright "Copyright 2014, A. Emelyanov"
#property link      "A.Emelyanov2010@yandex.ru"
#property version   "1.00"
//+------------------------------------------------------------------+
//| Подключаемые библиотеки                                          |
//+------------------------------------------------------------------+
#include <Object.mqh>
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class MyCTrendLine : public CObject
  {
private:
   //--- "Описатели" объекта /ОСНОВНЫЕ/
   string            TrendLineName;                        //1  имя          объекта 
   double            TrendLinePrice1;                      //2  цена  1      объекта 
   datetime          TrendLineTime1;                       //3  время 1      объекта 
   double            TrendLinePrice2;                      //4  цена  2      объекта 
   datetime          TrendLineTime2;                       //5  время 2      объекта 
   ENUM_LINE_STYLE   TrendLineStyle;                       //6  стиль
   //--- "Описатели" объекта /дополнительные/
   color             TrendLineColor;                       //7  цвет         
   int               TrendLineWidth;                       //8  толщина
   bool              TrendLineBack;                        //9  задний план(позиция объекта на графике)
   bool              TrendLineRayLeft;                     //10 продолжать линию влево
   bool              TrendLineRayRight;                    //11 продолжать линию вправо
   bool              TrendLineHidden;                      //12 "скрыть в списке объектов" 
public:
   //--- Публичные методы
                     MyCTrendLine();
                    ~MyCTrendLine();
   //--- Конструктора с параметрами 
                     MyCTrendLine(double price1, datetime time1, 
                                  double price2, datetime time2);
                     MyCTrendLine(double price1, datetime time1, double price2, 
                                  datetime time2, ENUM_LINE_STYLE style);
                     MyCTrendLine(string name, double price1, datetime time1, 
                                  double price2, datetime time2, ENUM_LINE_STYLE style);
   //--- Методы Set-параметры объекта
   bool              SetName(string name);                       // установить  имя          объекта 
   bool              SetPrice1(double price1);                   // установить  цена  1      объекта 
   bool              SetTime1(datetime time1);                   // установить  время 1      объекта 
   bool              SetPrice2(double price2);                   // установить  цена  2      объекта 
   bool              SetTime2(datetime time2);                   // установить  время 2      объекта 
   bool              SetColor(color col);                        // установить  цвет         
   bool              SetStyle(ENUM_LINE_STYLE style);            // установить  стиль
   bool              SetWidth(int width);                        // установить  толщина
   bool              SetBack(bool back);                         // установить  "задний план"
   bool              SetRayLeft(bool left);                      // установить продолжать линию влево
   bool              SetRayRight(bool right);                    // установить продолжать линию вправо
   bool              SetHidden(bool hidden);                     // установить "скрыть в списке объектов"
   
   //--- Mетоды Get-параметры объекта
   string            GetName(void){return(TrendLineName);};      // получить  имя          объекта 
   double            GetPrice1(void){return(TrendLinePrice1);};  // получить  цена  1      объекта 
   datetime          GetTime1(void){return(TrendLineTime1);};    // получить  время 1      объекта 
   double            GetPrice2(void){return(TrendLinePrice2);};  // получить  цена  2      объекта 
   datetime          GetTime2(void){return(TrendLineTime2);};    // получить  время 2      объекта 
   color             GetColor(void){return(TrendLineColor);};    // получить  цвет         
   ENUM_LINE_STYLE   GetStyle(void){return(TrendLineStyle);};    // получить  стиль
   int               GetWidth(void){return(TrendLineWidth);};    // получить  толщина
   bool              GetBack(void){return(TrendLineBack);};      // получить  "задний план"
   bool              GetRayLeft(void){return(TrendLineRayLeft);};// получить продолжать линию влево
   bool              GetRayRight(void){return(TrendLineRayRight);};// получить продолжать линию вправо
   bool              GetHidden(void){return(TrendLineHidden);};  // получить "скрыть в списке объектов"
private:
   //--- Приватные методы
   void              CreateTrend(void);                    // вывод на экран объекта
   void              DeletTrend(void);                     // удаление на экране
   string            GenerateRandName();                   // генерировать случайное имя               
  };
//+------------------------------------------------------------------+
//| Конструктор без параметров                                       |
//+------------------------------------------------------------------+
MyCTrendLine::MyCTrendLine()
  {
   //--- "переменные"
   MqlTick last_tick;
   //--- 1.
   this.TrendLineName = this.GenerateRandName();
   //--- 2-5. 
   if(SymbolInfoTick(_Symbol,last_tick))
     {//--- получаем текущее значение цены и времени
      this.TrendLinePrice1 = last_tick.ask;
      this.TrendLineTime1  = last_tick.time;
      this.TrendLinePrice2 = last_tick.bid;
      this.TrendLineTime2  = last_tick.time-_Period;
     }
     else
       {//--- не получилось, устанавливаем "крэш"
        this.TrendLinePrice1 = 0;
        this.TrendLineTime1  = D'1970.01.01 12:00:00';
        this.TrendLinePrice2 = 0.01;
        this.TrendLineTime2  = D'1970.01.01 12:00:00'+_Period;
       }
   //--- 6. 
   this.TrendLineStyle = STYLE_SOLID;
   //--- 7.
   this.TrendLineColor = clrRed;
   //--- 8.
   this.TrendLineWidth = 1;
   //--- 9.
   this.TrendLineBack = false;
   //--- 10-11.
   this.TrendLineRayLeft  = false;
   this.TrendLineRayRight = false;
   //--- 12.
   this.TrendLineHidden = true;
   //--- А теперь можно создать объект
   this.CreateTrend();
  }
//+------------------------------------------------------------------+
//| деконструктор                                                    |
//+------------------------------------------------------------------+
MyCTrendLine::~MyCTrendLine()
  {
   //---
   if(ObjectFind(0, this.TrendLineName) >= 0)
     {
      this.DeletTrend();
     }
  }
//+------------------------------------------------------------------+
//| Конструктора с параметрами                                       |
//+------------------------------------------------------------------+
//| Конструктор с координатами                                       |
//+------------------------------------------------------------------+
MyCTrendLine::MyCTrendLine(double price1,datetime time1,double price2,datetime time2)
  {
   //--- 1.
   this.TrendLineName = this.GenerateRandName();
   //--- 2-5. 
   this.TrendLinePrice1 = price1;
   this.TrendLineTime1  = time1;
   this.TrendLinePrice2 = price2;
   this.TrendLineTime2  = time2;
   //--- 6. 
   this.TrendLineStyle = STYLE_SOLID;
   //--- 7.
   this.TrendLineColor = clrRed;
   //--- 8.
   this.TrendLineWidth = 1;
   //--- 9.
   this.TrendLineBack = false;
   //--- 10-11.
   this.TrendLineRayLeft  = false;
   this.TrendLineRayRight = false;
   //--- 12.
   this.TrendLineHidden = true;
   //--- А теперь можно создать объект
   this.CreateTrend();
  }
//+------------------------------------------------------------------+
//| Конструктор с координатами + тип                                 |
//+------------------------------------------------------------------+
MyCTrendLine::MyCTrendLine(double price1,datetime time1,double price2,datetime time2,ENUM_LINE_STYLE style)
  {
   //--- 1.
   this.TrendLineName = this.GenerateRandName();
   //--- 2-5. 
   this.TrendLinePrice1 = price1;
   this.TrendLineTime1  = time1;
   this.TrendLinePrice2 = price2;
   this.TrendLineTime2  = time2;
   //--- 6. 
   this.TrendLineStyle = style;
   //--- 7.
   this.TrendLineColor = clrRed;
   //--- 8.
   this.TrendLineWidth = 1;
   //--- 9.
   this.TrendLineBack = false;
   //--- 10-11.
   this.TrendLineRayLeft  = false;
   this.TrendLineRayRight = false;
   //--- 12.
   this.TrendLineHidden = true;
   //--- А теперь можно создать объект
   this.CreateTrend();
  }
//+------------------------------------------------------------------+
//| Конструктор с координатами + тип + имя                           |
//| ПРИМЕЧАНИЕ(ВАЖНО):                                               |
//| МЕТОД ВСЕГДА СОЗДАЕТ ОБЪЕКТ, НО ИМЯ ОБЪЕКТА МОЖЕТ БЫТЬ ДРУГИМ!   |
//+------------------------------------------------------------------+
MyCTrendLine::MyCTrendLine(string name,double price1,datetime time1,double price2,datetime time2,ENUM_LINE_STYLE style)
  {
   //--- 1.
   if(ObjectFind(0,name) < 0)
     {
      this.TrendLineName = name;
     }else this.TrendLineName = this.GenerateRandName();        
   //--- 2-5. 
   this.TrendLinePrice1 = price1;
   this.TrendLineTime1  = time1;
   this.TrendLinePrice2 = price2;
   this.TrendLineTime2  = time2;
   //--- 6. 
   this.TrendLineStyle = style;
   //--- 7.
   this.TrendLineColor = clrRed;
   //--- 8.
   this.TrendLineWidth = 1;
   //--- 9.
   this.TrendLineBack = false;
   //--- 10-11.
   this.TrendLineRayLeft  = false;
   this.TrendLineRayRight = false;
   //--- 12.
   this.TrendLineHidden = true;
   //--- А теперь можно создать объект
   this.CreateTrend();
  }
//+------------------------------------------------------------------+
//| ПУБЛИЧНЫЕ МЕТОДЫ КЛАССА                                          |
//+------------------------------------------------------------------+
//| Set ИМЯ объекта                                                  |
//+------------------------------------------------------------------+
bool MyCTrendLine::SetName(string name)
  {
   if(ObjectSetString(0, this.TrendLineName,OBJPROP_NAME,name))
     {
      //---
      this.TrendLineName = name;
      //---
      ChartRedraw(0);   
      //---
      return(true);
     }
   Print(__FUNCTION__," ERROR: ",GetLastError());
   return(false);
  }
//+------------------------------------------------------------------+
//| Set цена 1                                                       |
//+------------------------------------------------------------------+
bool MyCTrendLine::SetPrice1(double price1)
  {
   if(ObjectSetDouble(0,this.TrendLineName,OBJPROP_PRICE,0,price1))
     {
      //---
      this.TrendLinePrice1 = price1;
      //---
      ChartRedraw(0);   
      //---
      return(true);
     }
   Print(__FUNCTION__," ERROR: ",GetLastError());
   return(false);
  }
//+------------------------------------------------------------------+
//| Set time 1                                                       |
//+------------------------------------------------------------------+
bool MyCTrendLine::SetTime1(datetime time1)
  {
   if(ObjectSetInteger(0,this.TrendLineName,OBJPROP_TIME,0,time1))
     {
      //---
      this.TrendLineTime1 = time1;
      //---
      ChartRedraw(0);   
      //---
      return(true);
     }
   Print(__FUNCTION__," ERROR: ",GetLastError());
   return(false);
  }
//+------------------------------------------------------------------+
//| Set price 2                                                      |
//+------------------------------------------------------------------+
bool MyCTrendLine::SetPrice2(double price2)
  {
   if(ObjectSetDouble(0,this.TrendLineName,OBJPROP_PRICE,1,price2))
     {
      //---
      this.TrendLinePrice2 = price2;
      //---
      ChartRedraw(0);   
      //---
      return(true);
     }
   Print(__FUNCTION__," ERROR: ",GetLastError());
   return(false);
  }
//+------------------------------------------------------------------+
//| Set time 2                                                       |
//+------------------------------------------------------------------+
bool MyCTrendLine::SetTime2(datetime time2)
  {
   if(ObjectSetInteger(0,this.TrendLineName,OBJPROP_TIME,1,time2))
     {
      //---
      this.TrendLineTime2 = time2;
      //---
      ChartRedraw(0);   
      //---
      return(true);
     }
   Print(__FUNCTION__," ERROR: ",GetLastError());
   return(false);
  }
//+------------------------------------------------------------------+
//| Set style                                                        |
//+------------------------------------------------------------------+
bool MyCTrendLine::SetStyle(ENUM_LINE_STYLE style)
  {
   if(ObjectSetInteger(0,this.TrendLineName,OBJPROP_STYLE,style))
     {
      //---
      this.TrendLineStyle = style;
      //---
      ChartRedraw(0);   
      //---
      return(true);
     }
   Print(__FUNCTION__," ERROR: ",GetLastError());
   return(false);
  }
//+------------------------------------------------------------------+
//| Set color                                                        |
//+------------------------------------------------------------------+
bool MyCTrendLine::SetColor(color col)
  {
   if(ObjectSetInteger(0,this.TrendLineName,OBJPROP_COLOR,col))
     {
      //---
      this.TrendLineColor = col;
      //---
      ChartRedraw(0);   
      //---
      return(true);
     }
   Print(__FUNCTION__," ERROR: ",GetLastError());
   return(false);
  }
//+------------------------------------------------------------------+
//| Set толщина объекта                                              |
//+------------------------------------------------------------------+
bool MyCTrendLine::SetWidth(int width)
  {
   if(ObjectSetInteger(0,this.TrendLineName,OBJPROP_WIDTH,width))
     {
      //---
      this.TrendLineWidth = width;
      //---
      ChartRedraw(0);   
      //---
      return(true);
     }
   Print(__FUNCTION__," ERROR: ",GetLastError());
   return(false);
  }
//+------------------------------------------------------------------+
//| Set "задний план"                                                |
//+------------------------------------------------------------------+
bool MyCTrendLine::SetBack(bool back)
  {
   if(ObjectSetInteger(0,this.TrendLineName,OBJPROP_BACK,back))
     {
      //---
      this.TrendLineBack = back;
      //---
      ChartRedraw(0);   
      //---
      return(true);
     }
   Print(__FUNCTION__," ERROR: ",GetLastError());
   return(false);
  }
//+------------------------------------------------------------------+
//| Установить "продолжать линию влево"                              |
//+------------------------------------------------------------------+
bool MyCTrendLine::SetRayLeft(bool left)
  {
   if(ObjectSetInteger(0,this.TrendLineName,OBJPROP_RAY_LEFT,left))
     {
      //---
      this.TrendLineRayLeft = left;
      //---
      ChartRedraw(0);   
      //---
      return(true);
     }
   Print(__FUNCTION__," ERROR: ",GetLastError());
   return(false);
  }
//+------------------------------------------------------------------+
//| Установить продолжать линию вправо                               |
//+------------------------------------------------------------------+
bool MyCTrendLine::SetRayRight(bool right)
  {
   if(ObjectSetInteger(0,this.TrendLineName,OBJPROP_RAY_RIGHT,right))
     {
      //---
      this.TrendLineRayRight = right;
      //---
      ChartRedraw(0);   
      //---
      return(true);
     }
   Print(__FUNCTION__," ERROR: ",GetLastError());
   return(false);
  }
//+------------------------------------------------------------------+
//| Установить "скрыть в списке объектов"                            |
//+------------------------------------------------------------------+
bool MyCTrendLine::SetHidden(bool hidden)
  {
   if(ObjectSetInteger(0,this.TrendLineName,OBJPROP_HIDDEN,hidden))
     {
      //---
      this.TrendLineHidden = hidden;
      //---
      ChartRedraw(0);   
      //---
      return(true);
     }
   Print(__FUNCTION__," ERROR: ",GetLastError());
   return(false);
  }
//+------------------------------------------------------------------+
//| ЗАЩИЩЕННЫЕ МЕТОДЫ КЛАССА                                         |
//+------------------------------------------------------------------+
//| Генерирование случайного имени                                   |
//+------------------------------------------------------------------+
string MyCTrendLine::GenerateRandName(void)
  {
   //---
   int ind = 0;
   string RandName;
   //---
   MathSrand(GetTickCount());
   //--- цикл поиска нового свободного имени
   while(ind < 32767)
     {
	  //---
	  RandName = "No_Name_Trend_"+IntegerToString(MathRand());
	  //---
	  if(ObjectFind(0, RandName) < 0)
	    {
		  //---
		  return(RandName);
		 }
	  //---
	  ind++;
	 }
   //---
   return("Error");
  }
//+------------------------------------------------------------------+
//| CreateArrow                                                      |
//+------------------------------------------------------------------+
void MyCTrendLine::CreateTrend(void)
  {
   //--- Создание объекта... параметры: 1, 2, 3, 4, 5 
   ObjectCreate(0, this.TrendLineName, OBJ_TREND, 0, this.TrendLineTime1, 
                this.TrendLinePrice1, this.TrendLineTime2, this.TrendLinePrice2);
   //--- установка параметра 6
   ObjectSetInteger(0,this.TrendLineName,OBJPROP_STYLE,this.TrendLineStyle);
   //--- установка параметра 7
   ObjectSetInteger(0,this.TrendLineName,OBJPROP_COLOR,this.TrendLineColor);
   //--- установка параметра 8
   ObjectSetInteger(0,this.TrendLineName,OBJPROP_WIDTH,this.TrendLineWidth);
   //+---------------------------------------------------------------+
   //| Отключим режим перемещения линии мышью, данного параметра нет |
   //| в переменных данного класса!                                  |
   //+---------------------------------------------------------------+
   ObjectSetInteger(0,this.TrendLineName,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,this.TrendLineName,OBJPROP_SELECTED,false);
   //--- установка параметра 9 
   ObjectSetInteger(0,this.TrendLineName,OBJPROP_BACK,this.TrendLineBack);
   //--- установка параметра 10 
   ObjectSetInteger(0,this.TrendLineName,OBJPROP_RAY_LEFT,this.TrendLineRayLeft);
   //--- установка параметра 11 
   ObjectSetInteger(0,this.TrendLineName,OBJPROP_RAY_RIGHT,this.TrendLineRayRight);
   //--- установка параметра 12
   ObjectSetInteger(0,this.TrendLineName,OBJPROP_HIDDEN,this.TrendLineHidden);
   //---
   ChartRedraw(0);   
  }
//+------------------------------------------------------------------+
//| удаление на экране                                               |
//+------------------------------------------------------------------+
void MyCTrendLine::DeletTrend(void)
  {
   ObjectDelete(0, this.TrendLineName);
   ChartRedraw(0);   
  }
//+------------------------------------------------------------------+
