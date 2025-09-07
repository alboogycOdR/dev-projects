//+------------------------------------------------------------------+
//|                                                     MyCHLine.mqh |
//|                                     Copyright 2014, A. Emelyanov |
//|                                        A.Emelyanov2010@yandex.ru |
//+------------------------------------------------------------------+
//| Базовый класс для отображения и хранения объектов горизонт. линия|
//| Создан для упрощенной работы с графическими объектами и реали-   |
//| зации др. класса MyCListHLine   -   список объектов гориз/линий. |
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
class MyCHLine : public CObject
  {
private:
   string            HLineName;                            //1  имя    объекта 
   double            HLinePrice;                           //2  цена   объекта 
   ENUM_LINE_STYLE   HLineStyle;                           //3  стиль  объекта
   //--- "Описатели" объекта /дополнительные/
   color             HLineColor;                           //4  цвет         
   int               HLineWidth;                           //5  толщина
   bool              HLineBack;                            //6  задний план(позиция объекта на графике)
   bool              HLineHidden;                          //7  "скрыть в списке объектов" 
   string            HLineText;                            //8  текст описания
   string            HLineTip;                             //9  текст подсказки
public:
                     MyCHLine();
                    ~MyCHLine();
   //--- Конструктора с параметрами 
                     MyCHLine(double price);
                     MyCHLine(double price,ENUM_LINE_STYLE style);
                     MyCHLine(string name,double price,ENUM_LINE_STYLE style);
   //--- Методы Set-параметры объекта
   bool              SetName(string name);                 // установить  имя   объекта 
   bool              SetPrice(double price);               // установить  цена  объекта 
   bool              SetColor(color col);                  // установить  цвет         
   bool              SetStyle(ENUM_LINE_STYLE style);      // установить  стиль
   bool              SetWidth(int width);                  // установить  толщина
   bool              SetBack(bool back);                   // установить  "задний план"
   bool              SetHidden(bool hidden);               // установить  "скрыть в списке объектов"
   bool              SetText(string text);                 // установить  текст
   bool              SetTip(string tip);                   // установить  "подсказку"
   //--- Mетоды Get-параметры объекта
   string            GetName(void){return(HLineName);};    // получить  имя     объекта 
   double            GetPrice(void){return(HLinePrice);};  // получить  цену    объекта 
   color             GetColor(void){return(HLineColor);};  // получить  цвет         
   ENUM_LINE_STYLE   GetStyle(void){return(HLineStyle);};  // получить  стиль
   int               GetWidth(void){return(HLineWidth);};  // получить  толщина
   bool              GetBack(void){return(HLineBack);};    // получить  "задний план"
   bool              GetHidden(void){return(HLineHidden);};// получить "скрыть в списке объектов"
   string            GetText(void){return(HLineText);};    // получить текст описания
   string            GetTip(void){return(HLineTip);};      // получить подсказку(текст)
private:
   string            GenerateRandName(void);               // генерировать случайное имя               
   void              CreateHLine(void);                    // вывод на экран объекта
   void              DeletHLine(void);                     // удаление объекта
  };
//+------------------------------------------------------------------+
//| Конструктор без параметров                                       |
//+------------------------------------------------------------------+
MyCHLine::MyCHLine()
  {
   //--- "переменные"
   MqlTick last_tick;
   //--- 1.
   this.HLineName   = this.GenerateRandName();
   //--- 2. 
   if(SymbolInfoTick(_Symbol,last_tick))
     {//--- получаем текущее значение цены и времени
      this.HLinePrice = last_tick.ask;
     }
     else
       {//--- не получилось, устанавливаем "крэш"
        this.HLinePrice = 0;
       }
   //--- 3. 
   this.HLineStyle  = STYLE_SOLID;
   //--- 4.
   this.HLineColor  = clrRed;
   //--- 5.
   this.HLineWidth  = 1;
   //--- 6.
   this.HLineBack   = false;
   //--- 7.
   this.HLineHidden = true;
   //--- 8.
   this.HLineText   = NULL;
   //--- 9. 
   this.HLineTip    = NULL;   
   //--- А теперь можно создать объект
   this.CreateHLine();   
  }
//+------------------------------------------------------------------+
//| деконструктор                                                    |
//+------------------------------------------------------------------+
MyCHLine::~MyCHLine()
  {
   //---
   if(ObjectFind(0, this.HLineName) >= 0)
     {
      this.DeletHLine();
     }
  }
//+------------------------------------------------------------------+
//| Конструктора с параметрами                                       |
//+------------------------------------------------------------------+
//| Конструктор с ценой                                              |
//+------------------------------------------------------------------+
MyCHLine::MyCHLine(double price)
  {
   //--- 1.
   this.HLineName   = this.GenerateRandName();
   //--- 2. 
   this.HLinePrice  = price;
   //--- 3. 
   this.HLineStyle  = STYLE_SOLID;
   //--- 4.
   this.HLineColor  = clrRed;
   //--- 5.
   this.HLineWidth  = 1;
   //--- 6.
   this.HLineBack   = false;
   //--- 7.
   this.HLineHidden = true;
   //--- 8.
   this.HLineText   = NULL;
   //--- 9. 
   this.HLineTip    = NULL;   
   //--- А теперь можно создать объект
   this.CreateHLine();   
  }
//+------------------------------------------------------------------+
//| Конструктор с ценой и типом                                      |
//+------------------------------------------------------------------+
MyCHLine::MyCHLine(double price,ENUM_LINE_STYLE style)
  {
   //--- 1.
   this.HLineName   = this.GenerateRandName();
   //--- 2. 
   this.HLinePrice  = price;
   //--- 3. 
   this.HLineStyle  = style;
   //--- 4.
   this.HLineColor  = clrRed;
   //--- 5.
   this.HLineWidth  = 1;
   //--- 6.
   this.HLineBack   = false;
   //--- 7.
   this.HLineHidden = true;
   //--- 8.
   this.HLineText   = NULL;
   //--- 9. 
   this.HLineTip    = NULL;   
   //--- А теперь можно создать объект
   this.CreateHLine();   
  }
//+------------------------------------------------------------------+
//| Конструктор с именем, ценой и типом                              |
//+------------------------------------------------------------------+
MyCHLine::MyCHLine(string name,double price,ENUM_LINE_STYLE style)
  {
   //--- 1.
   this.HLineName   = name;
   //--- 2. 
   this.HLinePrice  = price;
   //--- 3. 
   this.HLineStyle  = style;
   //--- 4.
   this.HLineColor  = clrRed;
   //--- 5.
   this.HLineWidth  = 1;
   //--- 6.
   this.HLineBack   = false;
   //--- 7.
   this.HLineHidden = true;
   //--- 8.
   this.HLineText   = NULL;
   //--- 9. 
   this.HLineTip    = NULL;   
   //--- А теперь можно создать объект
   this.CreateHLine();   
  }
//+------------------------------------------------------------------+
//| ПУБЛИЧНЫЕ МЕТОДЫ КЛАССА                                          |
//+------------------------------------------------------------------+
//| Set ИМЯ объекта                                                  |
//+------------------------------------------------------------------+
bool MyCHLine::SetName(string name)
  {
   if(ObjectSetString(0, this.HLineName,OBJPROP_NAME,name))
     {
      //---
      this.HLineName = name;
      //---
      ChartRedraw(0);   
      //---
      return(true);
     }
   Print(__FUNCTION__," ERROR: ",GetLastError());
   return(false);
  }
//+------------------------------------------------------------------+
//| Set цена                                                         |
//+------------------------------------------------------------------+
bool MyCHLine::SetPrice(double price)
  {
   if(ObjectSetDouble(0,this.HLineName,OBJPROP_PRICE,0,price))
     {
      //---
      this.HLinePrice = price;
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
bool MyCHLine::SetStyle(ENUM_LINE_STYLE style)
  {
   if(ObjectSetInteger(0,this.HLineName,OBJPROP_STYLE,style))
     {
      //---
      this.HLineStyle = style;
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
bool MyCHLine::SetColor(color col)
  {
   if(ObjectSetInteger(0,this.HLineName,OBJPROP_COLOR,col))
     {
      //---
      this.HLineColor = col;
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
bool MyCHLine::SetWidth(int width)
  {
   if(ObjectSetInteger(0,this.HLineName,OBJPROP_WIDTH,width))
     {
      //---
      this.HLineWidth = width;
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
bool MyCHLine::SetBack(bool back)
  {
   if(ObjectSetInteger(0,this.HLineName,OBJPROP_BACK,back))
     {
      //---
      this.HLineBack = back;
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
bool MyCHLine::SetHidden(bool hidden)
  {
   if(ObjectSetInteger(0,this.HLineName,OBJPROP_HIDDEN,hidden))
     {
      //---
      this.HLineHidden = hidden;
      //---
      ChartRedraw(0);   
      //---
      return(true);
     }
   Print(__FUNCTION__," ERROR: ",GetLastError());
   return(false);
  }
//+------------------------------------------------------------------+
//| Установка текста описания                                        |
//+------------------------------------------------------------------+
bool MyCHLine::SetText(string text)
  {
   if(text != NULL)
     {
      ObjectSetString(0,this.HLineName,OBJPROP_TEXT,this.HLineText);
      ChartSetInteger(0,CHART_SHOW_OBJECT_DESCR,true);
      this.HLineText = text;
      //---
      ChartRedraw(0);   
      //---
      return(true);
     }
   return(false);
  }
//+------------------------------------------------------------------+
//| Установка текста подсказки                                       |
//+------------------------------------------------------------------+
bool MyCHLine::SetTip(string tip)
  {
   if(tip != NULL)
     {
      ObjectSetString(0,this.HLineName,OBJPROP_TOOLTIP,this.HLineTip);
      ChartSetInteger(0,CHART_SHOW_OBJECT_DESCR,true);      
      this.HLineTip = tip;
      //---
      ChartRedraw(0);   
      //---
      return(true);
     }
   return(false);
  }
//+------------------------------------------------------------------+
//| ЗАЩИЩЕННЫЕ МЕТОДЫ КЛАССА                                         |
//+------------------------------------------------------------------+
//| Генерирование случайного имени                                   |
//+------------------------------------------------------------------+
string MyCHLine::GenerateRandName(void)
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
	  RandName = "No_Name_HLine_"+IntegerToString(MathRand());
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
//| Создание объекта "горизонтальная линия"                          |
//+------------------------------------------------------------------+
void MyCHLine::CreateHLine(void)
  {
   //--- Создание объекта... параметры: 1, 2
   ObjectCreate(0, this.HLineName, OBJ_HLINE, 0, 0, this.HLinePrice);
   //--- установка параметра 3
   ObjectSetInteger(0,this.HLineName,OBJPROP_STYLE,this.HLineStyle);
   //--- установка параметра 4
   ObjectSetInteger(0,this.HLineName,OBJPROP_COLOR,this.HLineColor);
   //--- установка параметра 5
   ObjectSetInteger(0,this.HLineName,OBJPROP_WIDTH,this.HLineWidth);
   //+---------------------------------------------------------------+
   //| Отключим режим перемещения линии мышью, данного параметра нет |
   //| в переменных данного класса!                                  |
   //+---------------------------------------------------------------+
   ObjectSetInteger(0,this.HLineName,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,this.HLineName,OBJPROP_SELECTED,false);
   //--- установка параметра 6 
   ObjectSetInteger(0,this.HLineName,OBJPROP_BACK,this.HLineBack);
   //--- установка параметра 7
   ObjectSetInteger(0,this.HLineName,OBJPROP_HIDDEN,this.HLineHidden);
   //--- 8.
   if(this.HLineText != NULL)
     {
      ObjectSetString(0,this.HLineName,OBJPROP_TEXT,this.HLineText);
      ChartSetInteger(0,CHART_SHOW_OBJECT_DESCR,true);
     }
   //--- 9. 
   if(this.HLineTip != NULL)
     {
      ObjectSetString(0,this.HLineName,OBJPROP_TOOLTIP,this.HLineTip);
      ChartSetInteger(0,CHART_SHOW_OBJECT_DESCR,true);
     }
   //---
   ChartRedraw(0);   
  }
//+------------------------------------------------------------------+
//| удаление на экране                                               |
//+------------------------------------------------------------------+
void MyCHLine::DeletHLine(void)
  {
   ObjectDelete(0, this.HLineName);
   ChartRedraw(0);   
  }
//+------------------------------------------------------------------+
