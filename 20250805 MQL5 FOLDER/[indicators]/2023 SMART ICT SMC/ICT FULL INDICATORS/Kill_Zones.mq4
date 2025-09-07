//+------------------------------------------------------------------+
//|                                                   i-Sessions.mq4 |
//|                                           Ким Игорь В. aka KimIV |
//|                                              http://www.kimiv.ru |
//|                                                                  |
//|  16.11.2005  Индикатор торговых сессий                           |
//+------------------------------------------------------------------+
#property copyright "Ким Игорь В. aka KimIV"
#property link      "http://www.kimiv.ru"

#property indicator_chart_window

//------- Внешние параметры индикатора -------------------------------
extern int    NumberOfDays = 50;  
      
extern string LondonOpenBegin    = "02:00";   
extern string LondonOpenEnd      = "04:00";   
extern color  LondonOpenColor    = C'162,162,162'; 
extern string LondonCloseBegin     = "10:00";   
extern string LondonCloseEnd       = "12:00";   
extern color  LondonCloseColor     = C'162,162,162'; 

extern string NYOpenBegin    = "08:30";   
extern string NYOpenEnd      = "09:30";   
extern color  NYOpenColor    = C'162,162,162'; 
//extern string NYCloseBegin     = "16:00";   
//extern string NYCloseEnd       = "17:00";   
//extern color  NYCloseColor     = C'162,162,162'; 

extern string TKOpenBegin    = "19:00";   
extern string TKOpenEnd      = "21:00";   
extern color  TKOpenColor    = C'162,162,162'; 
//extern string TKCloseBegin     = "15:00";   
//extern string TKCloseEnd       = "16:00";   
//extern color  TKCloseColor     = C'162,162,162'; 




//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
void init() {
  DeleteObjects();
  for (int i=0; i<NumberOfDays; i++) {
    CreateObjects("LO"+i, LondonOpenColor);
    CreateObjects("LC"+i, LondonCloseColor);
    CreateObjects("NYO"+i, NYOpenColor);
    //CreateObjects("NYC"+i, NYCloseColor);
    CreateObjects("TKO"+i, TKOpenColor);
    //CreateObjects("TKC"+i, TKCloseColor);
  }
  Comment("");
}

//+------------------------------------------------------------------+
//| Custor indicator deinitialization function                       |
//+------------------------------------------------------------------+
void deinit() {
  DeleteObjects();
  Comment("");
}

//+------------------------------------------------------------------+
//| Создание объектов индикатора                                     |
//| Параметры:                                                       |
//|   no - наименование объекта                                      |
//|   cl - цвет объекта                                              |
//+------------------------------------------------------------------+
void CreateObjects(string no, color cl) {
  ObjectCreate(no, OBJ_RECTANGLE, 0, 0,0, 0,0);
  ObjectSet(no, OBJPROP_STYLE, STYLE_SOLID);
  ObjectSet(no, OBJPROP_COLOR, cl);
  ObjectSet(no, OBJPROP_BACK, True);
}

//+------------------------------------------------------------------+
//| Удаление объектов индикатора                                     |
//+------------------------------------------------------------------+
void DeleteObjects() {
  for (int i=0; i<NumberOfDays; i++) {
    ObjectDelete("LO"+i);
    ObjectDelete("LC"+i);
    ObjectDelete("NYO"+i);
    //ObjectDelete("NYC"+i);
    ObjectDelete("TKO"+i);
    //ObjectDelete("TKC"+i);
  }
}

//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
void start() {
  datetime dt=CurTime();

  for (int i=0; i<NumberOfDays; i++) {
    DrawObjects(dt, "LO"+i, LondonOpenBegin, LondonOpenEnd);
    DrawObjects(dt, "LC"+i, LondonCloseBegin, LondonCloseEnd);
    DrawObjects(dt, "NYO"+i, NYOpenBegin, NYOpenEnd);
    //DrawObjects(dt, "NYC"+i, NYCloseBegin, NYCloseEnd);
    DrawObjects(dt, "TKO"+i, TKOpenBegin, TKOpenEnd);
    //DrawObjects(dt, "TKC"+i, TKCloseBegin, TKCloseEnd);
    dt=decDateTradeDay(dt);
    while (TimeDayOfWeek(dt)>5) dt=decDateTradeDay(dt);
  }
}

//+------------------------------------------------------------------+
//| Прорисовка объектов на графике                                   |
//| Параметры:                                                       |
//|   dt - дата торгового дня                                        |
//|   no - наименование объекта                                      |
//|   tb - время начала сессии                                       |
//|   te - время окончания сессии                                    |
//+------------------------------------------------------------------+
void DrawObjects(datetime dt, string no, string tb, string te) {
  datetime t1, t2;
  double   p1, p2;
  int      b1, b2;

  t1=StrToTime(TimeToStr(dt, TIME_DATE)+" "+tb);
  t2=StrToTime(TimeToStr(dt, TIME_DATE)+" "+te);
  b1=iBarShift(NULL, 0, t1);
  b2=iBarShift(NULL, 0, t2);
  p1=High[Highest(NULL, 0, MODE_HIGH, b1-b2, b2)];
  p2=Low [Lowest (NULL, 0, MODE_LOW , b1-b2, b2)];
  ObjectSet(no, OBJPROP_TIME1 , t1);
  ObjectSet(no, OBJPROP_PRICE1, p1);
  ObjectSet(no, OBJPROP_TIME2 , t2);
  ObjectSet(no, OBJPROP_PRICE2, p2);
}

//+------------------------------------------------------------------+
//| Уменьшение даты на один торговый день                            |
//| Параметры:                                                       |
//|   dt - дата торгового дня                                        |
//+------------------------------------------------------------------+
datetime decDateTradeDay (datetime dt) {
  int ty=TimeYear(dt);
  int tm=TimeMonth(dt);
  int td=TimeDay(dt);
  int th=TimeHour(dt);
  int ti=TimeMinute(dt);

  td--;
  if (td==0) {
    tm--;
    if (tm==0) {
      ty--;
      tm=12;
    }
    if (tm==1 || tm==3 || tm==5 || tm==7 || tm==8 || tm==10 || tm==12) td=31;
    if (tm==2) if (MathMod(ty, 4)==0) td=29; else td=28;
    if (tm==4 || tm==6 || tm==9 || tm==11) td=30;
  }
  return(StrToTime(ty+"."+tm+"."+td+" "+th+":"+ti));
}
//+------------------------------------------------------------------+

