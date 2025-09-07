//+------------------------------------------------------------------+
//|                                                      MyArrow.mqh |
//|                                     Copyright 2014, A. Emelyanov |
//|                                        A.Emelyanov2010@yandex.ru |
//+------------------------------------------------------------------+
//| Базовый класс для отображения и хранения объекта типа стрелка.   |
//| Создан для упрощенной работы с графическими объектами и реали-   |
//| зации др. класса MyCListArrow - список объектов стрелка.         |
//+------------------------------------------------------------------+
#property copyright "Copyright 2014, A. Emelyanov"
#property link      "A.Emelyanov2010@yandex.ru"
#property version   "1.00"
//+------------------------------------------------------------------+
//| Подключаемые библиотеки                                          |
//+------------------------------------------------------------------+
#include <Object.mqh>
//+------------------------------------------------------------------+
//| Мой тип класса для хранения графического объекта "стрелка".      |
//+------------------------------------------------------------------+
class MyCArrow : public CObject
  {
private:
   //--- "Описатели" объекта MyCArrow /ОСНОВНЫЕ/
   string            ArrowName;          // имя          объекта стрелка
   string            ArrowTip;           // описание     объекта стрелка
   double            ArrowPrice;         // цена         объекта стрелка
   datetime          ArrowTime;          // время        объекта стрелка
   ENUM_OBJECT       ArrowType;          // тип          объекта стрелка
   //--- "Описатели" объекта MyCArrow /ДОПОЛНИТЕЛЬНЫЕ/
   int               ArrowCode;          // доп/описание объекта стралка
   color             ArrowColor;         // цвет         объекта стрелка
   ENUM_ARROW_ANCHOR ArrowAnchor;        // выравнивание объекта стрелка
public:
   //--- Публичные методы
                     MyCArrow(void);
                    ~MyCArrow(void);
   //--- Конструктора с параметрами 
                     MyCArrow(double APrice, datetime ATime);  
                     MyCArrow(double APrice, datetime ATime, ENUM_OBJECT AType);  
                     MyCArrow(string AName, string ATip, double APrice, 
                             datetime ATime, ENUM_OBJECT AType);  
   //--- Методы Set
   bool              SetName(string NewName);      // метод изм. имени
   bool              SetTip(string NewTip);        // метод изм. описания
   bool              SetPrice(double NewPrice);    // метод изм. цены
   bool              SetTime(datetime NewTime);    // метод изм. даты
   bool              SetType(ENUM_OBJECT NewType); // метод изм. типа
   //--- доп. методы Set
   bool              SetCode(int NewCode);         // метод изм. доп/типа
   bool              SetColor(color NewColor);     // метод изм. цвета
   bool              SetAnchor(ENUM_ARROW_ANCHOR Anchor);// метод изм. выравнивания
   //--- Mетоды Get
   string            GetName(void)  {return(ArrowName);};  // метод пол. имени
   string            GetTip(void)   {return(ArrowTip);};   // метод пол. описания
   double            GetPrice(void) {return(ArrowPrice);}; // метод пол. цены
   datetime          GetTime(void)  {return(ArrowTime);};  // метод пол. времени
   ENUM_OBJECT       GetType(void)  {return(ArrowType);};  // метод пол. типа
   //--- доп. методы Get
   int               GetCode(void)  {return(ArrowCode);};  // метод пол. доп/типа
   color             GetColor(void) {return(ArrowColor);}; // метод пол. цвета
   ENUM_ARROW_ANCHOR GetAnchor(void){return(ArrowAnchor);};// метод пол. выравнивания
private:
   //--- Приватные методы
   void              CreateArrow(void);                    // вывод на экран объекта
   void              DeletArrow(void);                     // удаление на экране
   string            GenerateRandName();                   // генерировать случайное имя               
  };
//+------------------------------------------------------------------+
//| Конструктор без параметров                                       |
//+------------------------------------------------------------------+
MyCArrow::MyCArrow(void)
  {
   //--- "переменные"
   MqlTick last_tick;
   //--- по умолчанию...
   if(SymbolInfoTick(_Symbol,last_tick))
     {//--- получаем текущее значение цены и времени
      this.ArrowPrice = last_tick.ask;
      this.ArrowTime  = last_tick.time;
     }
     else
       {//--- не получилось, устанавливаем "крэш"
        this.ArrowPrice = 0.0;
        this.ArrowTime  = D'1970.01.01 12:00:00';
       }
   //--- 
   this.ArrowName  = GenerateRandName();        
   this.ArrowTip   = "No_Tip";
   this.ArrowType  = OBJ_ARROW;
   this.ArrowCode  = 58;
   this.ArrowColor = clrRed;
   this.ArrowAnchor= ANCHOR_TOP;
   //--- 
   this.CreateArrow();
  }
//+------------------------------------------------------------------+
//| Конструктор с параметрами                                        |
//+------------------------------------------------------------------+
MyCArrow::MyCArrow(double APrice,datetime ATime,ENUM_OBJECT AType)
  {
   //--- 
   this.ArrowName    = GenerateRandName();        
   this.ArrowTip     = "No_Tip";
   this.ArrowPrice   = APrice;
   this.ArrowTime    = ATime;
   this.ArrowCode    = 58;
   this.ArrowColor   = clrRed;
   this.ArrowAnchor  = ANCHOR_TOP;
   switch(AType)
     {
      case  OBJ_ARROW_BUY:
      case  OBJ_ARROW_SELL:
      case  OBJ_ARROW_STOP:
      case  OBJ_ARROW_CHECK:
      case  OBJ_ARROW_UP:
      case  OBJ_ARROW_DOWN:
      case  OBJ_ARROW_LEFT_PRICE:
      case  OBJ_ARROW_RIGHT_PRICE:
      case  OBJ_ARROW_THUMB_UP:
      case  OBJ_ARROW_THUMB_DOWN:
        this.ArrowType = AType; 
        break;
      default:
        this.ArrowType = OBJ_ARROW;
        break;
     }
   //---
   this.CreateArrow();
  }
//+------------------------------------------------------------------+
//| Конструктор с параметрами                                        |
//+------------------------------------------------------------------+
MyCArrow::MyCArrow(double APrice,datetime ATime)
  {
   //--- 
   this.ArrowName    = GenerateRandName();        
   this.ArrowTip     = "No_Tip";
   this.ArrowPrice   = APrice;
   this.ArrowTime    = ATime;
   this.ArrowType    = OBJ_ARROW;
   this.ArrowCode    = 58;
   this.ArrowColor   = clrRed;
   this.ArrowAnchor  = ANCHOR_TOP;
   //---
   this.CreateArrow();
  }
//+------------------------------------------------------------------+
//| Конструктор с параметрами                                        |
//| ПРИМЕЧАНИЕ(ВАЖНО):                                               |
//| МЕТОД ВСЕГДА СОЗДАЕТ ОБЪЕКТ, НО ИМЯ ОБЪЕКТА МОЖЕТ БЫТЬ ДРУГИМ!   |
//+------------------------------------------------------------------+
MyCArrow::MyCArrow(string AName, string ATip, double APrice,datetime ATime,ENUM_OBJECT AType)
  {
   //---
   if(ObjectFind(0,AName) < 0)
     {
      this.ArrowName = AName;   
     }else this.ArrowName = GenerateRandName();        
   //---
   this.ArrowTip     = ATip;
   this.ArrowPrice   = APrice;
   this.ArrowTime    = ATime;
   this.ArrowCode    = 58;
   this.ArrowColor   = clrRed;
   this.ArrowAnchor  = ANCHOR_TOP;
   //---
   switch(AType)
     {
      case  OBJ_ARROW_BUY:
      case  OBJ_ARROW_SELL:
      case  OBJ_ARROW_STOP:
      case  OBJ_ARROW_CHECK:
      case  OBJ_ARROW_UP:
      case  OBJ_ARROW_DOWN:
      case  OBJ_ARROW_LEFT_PRICE:
      case  OBJ_ARROW_RIGHT_PRICE:
      case  OBJ_ARROW_THUMB_UP:
      case  OBJ_ARROW_THUMB_DOWN:
        this.ArrowType = AType; 
        break;
      default:
        this.ArrowType = OBJ_ARROW;
        break;
     }
   //---
    this.CreateArrow();
  }
//+------------------------------------------------------------------+
//| деконструктор                                                    |
//+------------------------------------------------------------------+
MyCArrow::~MyCArrow(void)
  {
   //---
   if(ObjectFind(0, this.ArrowName) >= 0)
     {
      DeletArrow();
     }
  }
//+------------------------------------------------------------------+
//| CreateArrow                                                      |
//+------------------------------------------------------------------+
void MyCArrow::CreateArrow(void)
  {
   //---
   ObjectCreate(0, this.ArrowName, this.ArrowType, 0,
                this.ArrowTime, this.ArrowPrice);
   //---
   if(this.ArrowType == OBJ_ARROW)
     {
      ObjectSetInteger(0, this.ArrowName, OBJPROP_ARROWCODE, this.ArrowCode);
     }
   //---
   ObjectSetInteger(0,this.ArrowName,OBJPROP_COLOR,this.ArrowColor);
   //---
   ObjectSetString(0,this.ArrowName,OBJPROP_TOOLTIP,this.ArrowTip);
   //---
   ObjectSetInteger(0,this.ArrowName,OBJPROP_ANCHOR,this.ArrowAnchor);
   //---
   ChartRedraw(0);   
  }
//+------------------------------------------------------------------+
//| удаление на экране                                               |
//+------------------------------------------------------------------+
void MyCArrow::DeletArrow(void)
  {
   ObjectDelete(0, this.ArrowName);
   ChartRedraw(0);   
  }
//+------------------------------------------------------------------+
//| метод изм. выравнивания                                          |
//+------------------------------------------------------------------+
bool MyCArrow::SetAnchor(ENUM_ARROW_ANCHOR Anchor)
  {
   if(ObjectSetInteger(0,this.ArrowName,OBJPROP_ANCHOR,Anchor))
     {
      //---
      this.ArrowAnchor = Anchor;
      //---
      ChartRedraw(0);   
      //---
      return(true);
     }
   Print(__FUNCTION__," ERROR: ",GetLastError());
   return(false);
  }
//+------------------------------------------------------------------+
//| Переименование объекта стрелка                                   |
//+------------------------------------------------------------------+
bool MyCArrow::SetName(string NewName)
  {
   if(ObjectSetString(0, this.ArrowName,OBJPROP_NAME,NewName))
     {
      //---
      this.ArrowName = NewName;
      //---
      ChartRedraw(0);   
      //---
      return(true);
     }
   Print(__FUNCTION__," ERROR: ",GetLastError());
   return(false);
  }
//+------------------------------------------------------------------+
//| Новый коментарий для стрелки                                     |
//+------------------------------------------------------------------+
bool MyCArrow::SetTip(string NewTip)
  {
   if(ObjectSetString(0, this.ArrowName,OBJPROP_TOOLTIP,NewTip))
     {
      //---
      this.ArrowTip = NewTip;
      //---
      ChartRedraw(0);   
      //---
      return(true);
     }
   Print(__FUNCTION__," ERROR: ",GetLastError());
   return(false);
  }
//+------------------------------------------------------------------+
//| Установка новой цены                                             |
//+------------------------------------------------------------------+
bool MyCArrow::SetPrice(double NewPrice)
  {
   if(ObjectSetDouble(0, this.ArrowName,OBJPROP_PRICE,NewPrice))
     {
      //---
      this.ArrowPrice = NewPrice;
      //---
      ChartRedraw(0);   
      //---
      return(true);
     }
   Print(__FUNCTION__," ERROR: ",GetLastError());
   return(false);
  }
//+------------------------------------------------------------------+
//| Установка нового времени                                         |
//+------------------------------------------------------------------+
bool MyCArrow::SetTime(datetime NewTime)
  {
   if(ObjectSetInteger(0, this.ArrowName,OBJPROP_TIME,NewTime))
     {
      //---
      this.ArrowTime = NewTime;
      //---
      ChartRedraw(0);   
      //---
      return(true);
     }
   Print(__FUNCTION__," ERROR: ",GetLastError());
   return(false);
  }
//+------------------------------------------------------------------+
//| Установка нового типа стрелки                                    |
//+------------------------------------------------------------------+
bool MyCArrow::SetType(ENUM_OBJECT NewType)
  {
   //--- уничтожить объект
   this.DeletArrow();
   //---
   this.ArrowType = NewType;
   //--- создать новый
   this.CreateArrow();
   //---
   return(true);
  }
//+------------------------------------------------------------------+
//| Установка нового доп/типа стрелки                                |
//+------------------------------------------------------------------+
bool MyCArrow::SetCode(int NewCode)
  {
   //---
   if(this.ArrowType == OBJ_ARROW)
     {
      //---
      if(NewCode>=32&&NewCode<=255)
        {
         this.ArrowCode = NewCode;
        }else return(false);      
      //---
      bool ret = ObjectSetInteger(0, this.ArrowName, OBJPROP_ARROWCODE, this.ArrowCode);
      //---
      ChartRedraw(0);
      //---
      return(ret);
     }
   //---
   return(false);
  }
//+------------------------------------------------------------------+
//| Установка нового цвета стрелки                                   |
//+------------------------------------------------------------------+
bool MyCArrow::SetColor(color NewColor)
  {
   //---
   this.ArrowColor = NewColor;
   //---
   bool ret = ObjectSetInteger(0, this.ArrowName, OBJPROP_COLOR, this.ArrowColor);
   //---
   ChartRedraw(0);
   //---
   return(ret);
  }
//+------------------------------------------------------------------+
//| Генерирование случайного имени                                   |
//+------------------------------------------------------------------+
string MyCArrow::GenerateRandName(void)
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
	  RandName = "No_Name_Arrow_"+IntegerToString(MathRand());
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
