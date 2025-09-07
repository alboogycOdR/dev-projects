//+------------------------------------------------------------------+
//|                                                      common2.mqh |
//|                                      Copyright 2009, A. Williams |
//|                                              http://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "2009, A. Williams"
#property link      "http://www.mql5.com"

//You must include the mt4timeseries.mqh in addition to this for a some of the functions below to work. 

#define EMPTY -1

enum ENUM_OBJECT_PROPERTY_INTEGER_CUSTOM
{
   OBJPROP_TIME1 =777777,
   OBJPROP_TIME2 =888888,
   OBJPROP_TIME3 =999999,
   OBJPROP_RAY =666666
};

enum ENUM_OBJECT_PROPERTY_DOUBLE_CUSTOM
{
   OBJPROP_PRICE1 =111111,
   OBJPROP_PRICE2 =222222,
   OBJPROP_PRICE3 =333333
};

bool ObjectCreate( string name, ENUM_OBJECT type, int window, datetime time1, double price1, datetime time2=0, double price2=0, datetime time3=0, double price3=0) 
{
   return(ObjectCreate(0, name, type, window, time1, price1, time2, price2,time3, price3));   
}

bool ObjectDelete( string name)
{
   return(ObjectDelete(0,name));
}

string ObjectDescription( string name)
{
   return(ObjectGetString(0,name,OBJPROP_TEXT));
}

int ObjectFind( string name)
{
   return(ObjectFind(0,name));
}

double ObjectGet( string name, ENUM_OBJECT_PROPERTY_DOUBLE_CUSTOM index, int modifier=0)
{
   if(index==OBJPROP_PRICE1) return(ObjectGetDouble(0,name,OBJPROP_PRICE,0));
   else if(index==OBJPROP_PRICE2) return(ObjectGetDouble(0,name,OBJPROP_PRICE,1));
   else if(index==OBJPROP_PRICE3) return(ObjectGetDouble(0,name,OBJPROP_PRICE,2)) ; 
   return(0);
}

double ObjectGet( string name, ENUM_OBJECT_PROPERTY_DOUBLE index, int modifier=0)
{
   return(ObjectGetDouble(0,name,index,modifier));
}

double ObjectGet(long chart_id, string name, ENUM_OBJECT_PROPERTY_DOUBLE index, int modifier=0)
{
   return(ObjectGetDouble(chart_id,name,index,modifier));
}

int ObjectGet( string name, ENUM_OBJECT_PROPERTY_INTEGER_CUSTOM index, int modifier=0)
{
   if(index==OBJPROP_TIME1) return(ObjectGetInteger(0,name,OBJPROP_TIME,0));
   else if(index==OBJPROP_TIME2) return(ObjectGetInteger(0,name,OBJPROP_TIME,1));
   else if(index==OBJPROP_TIME3) return(ObjectGetInteger(0,name,OBJPROP_TIME,2)); 
   else if(index==OBJPROP_RAY) return(ObjectGetInteger(0,name,OBJPROP_RAY_RIGHT));
   return(0);
}

int ObjectGet( string name, ENUM_OBJECT_PROPERTY_INTEGER index, int modifier=0)
{
   return(ObjectGetInteger(0,name,index,modifier));
}

int ObjectGet(long chart_id, string name, ENUM_OBJECT_PROPERTY_INTEGER index, int modifier=0)
{
   return(ObjectGetInteger(chart_id,name,index,modifier));
}

string ObjectGet( string name, ENUM_OBJECT_PROPERTY_STRING index, int modifier=0)
{
   return(ObjectGetString(0,name, index,modifier));
}

string ObjectGet(long chart_id, string name, ENUM_OBJECT_PROPERTY_STRING index, int modifier=0)
{
   return(ObjectGetString(chart_id,name, index,modifier));
}

bool ObjectSet( string name, ENUM_OBJECT_PROPERTY_DOUBLE_CUSTOM index, double value) 
{
   if(index==OBJPROP_PRICE1) return(ObjectSetDouble(0,name,OBJPROP_PRICE,0,value));
   else if(index==OBJPROP_PRICE2) return(ObjectSetDouble(0,name,OBJPROP_PRICE,1,value));
   else if(index==OBJPROP_PRICE3) return(ObjectSetDouble(0,name,OBJPROP_PRICE,2,value));    
   return(false);
}

bool ObjectSet( string name, ENUM_OBJECT_PROPERTY_DOUBLE index, double value, int modifier=0) 
{
   return(ObjectSetDouble(0, name, index, modifier, value));
}

bool ObjectSet(long chart_id, string name, ENUM_OBJECT_PROPERTY_DOUBLE index, double value, int modifier=0) 
{
   return(ObjectSetDouble(chart_id, name, index, modifier, value));
}

bool ObjectSet( string name, ENUM_OBJECT_PROPERTY_INTEGER_CUSTOM index, int value, int modifier=0) 
{
   if(index==OBJPROP_TIME1) return(ObjectSetInteger(0,name,OBJPROP_TIME,0,value));
   else if(index==OBJPROP_TIME2) return(ObjectSetInteger(0,name,OBJPROP_TIME,1,value));
   else if(index==OBJPROP_TIME3) return(ObjectSetInteger(0,name,OBJPROP_TIME,2,value)); 
   else if(index==OBJPROP_RAY) return(ObjectSetInteger(0,name,OBJPROP_RAY_RIGHT,value));
   return(false);
}

bool ObjectSet( string name, ENUM_OBJECT_PROPERTY_INTEGER index, int value, int modifier=0) 
{  
   return(ObjectSetInteger(0, name, index, modifier, value));
}

bool ObjectSet(long chart_id, string name, ENUM_OBJECT_PROPERTY_INTEGER index, int value, int modifier=0) 
{  
   return(ObjectSetInteger(chart_id, name, index, modifier, value));
}

bool ObjectSet( string name, ENUM_OBJECT_PROPERTY_STRING index, string value, int modifier=0) 
{
   return(ObjectSetString(0, name, index, modifier, value));
}

bool ObjectSet(long chart_id, string name, ENUM_OBJECT_PROPERTY_STRING index, string value, int modifier=0) 
{
   return(ObjectSetString(chart_id, name, index, modifier, value));
}

string ObjectGetFiboDescription( string name, int index)
{
   return(ObjectGetString(0,name,OBJPROP_LEVELTEXT,index));
}

int ObjectGetShiftByValue( string name, double value)
{
   return(iBarShift(NULL,PERIOD_CURRENT,ObjectGetTimeByValue(0, name, value)));
}

double ObjectGetValueByShift( string name, int shift)
{
   return(ObjectGetValueByTime(0,name,iTime(NULL,PERIOD_CURRENT,shift),0));
}

bool ObjectMove( string name, int point, datetime time1, double price1)
{
   return(ObjectMove(0, name, point, time1, price1));
}

string ObjectName( int index)
{
   return(ObjectName(0,index));
}

int ObjectsDeleteAll(int window=EMPTY, int type=EMPTY)
{
   return(ObjectsDeleteAll(0, window, type));
}

bool ObjectSetFiboDescription(string name, int index, string text) 
{
   return(ObjectSetString(0,name,OBJPROP_LEVELTEXT,index,text));
}

bool ObjectSetText( string name, string text, int font_size, string font="", color text_color=CLR_NONE) 
{
   int tmpObjType=ObjectType(name);
   if(tmpObjType != OBJ_LABEL && tmpObjType != OBJ_TEXT) return(false);
   if(StringLen(text) > 0 && font_size > 0)
   {
      if(ObjectSetString(0,name,OBJPROP_TEXT,text)==true && ObjectSetInteger(0,name,(ENUM_OBJECT_PROPERTY_INTEGER)OBJPROP_FONTSIZE,font_size)==true)
      {
         if((StringLen(font)>0) && ObjectSetString(0,name,OBJPROP_FONT,font)==false) return(false);
         if(text_color > -1 && ObjectSetInteger(0,name,(ENUM_OBJECT_PROPERTY_INTEGER)OBJPROP_COLOR,text_color)==false) return(false);
         return(true);
      }
      return(false);
   }
   return(false);
}

int ObjectsTotal(int type=EMPTY, int window=-1) 
{
   return(ObjectsTotal(0,window,type));
}

int ObjectType( string name) 
{
   return(ObjectGetInteger(0,name,(ENUM_OBJECT_PROPERTY_INTEGER)OBJPROP_TYPE));
}
