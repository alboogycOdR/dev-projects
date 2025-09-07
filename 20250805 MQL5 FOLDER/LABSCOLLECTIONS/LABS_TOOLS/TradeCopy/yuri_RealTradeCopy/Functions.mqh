//+------------------------------------------------------------------+
//|                                                    Functions.mqh |
//|                        Copyright 2022, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2022, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property strict

template<typename T>
void ArrayAppend(T& array[], T& value) {
   int i = ArraySize(array);
   ArrayResize(array, i + 1);
   array[i] = value;
}

template<typename T>
int ArrayFind(T& array[], const T& value) {
   for(int i = 0; i < ArraySize(array); i++) {
      if(array[i] == value) {
         return i;
      }
   }
   return -1;
}

template<typename T>
bool ArrayNotEqual(const T& a[], const T& b[]) {
   if(ArraySize(a) != ArraySize(b)) {
      return true;
   }

   for(int i = 0; i < ArraySize(a); i++) {
      if(a[i] != b[i]) {
         return true;
      }
   }

   return false;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string DefaultFormat(string& type) {
   if(type == "double" || type == "float") {
      return "%+8.2f";
   }

   if(type == "string") {
      return "%8s";
   }

   return "% 8d";
}

template<typename T>
string ArrayToString(const T& array[], string format = "", string sep = " ") {
   string s = "";
   string t = typename(T);
   int size  = ArraySize(array);

   if(t == "Position" || t == "Order") {

   } else {
      if(size == 0) {
         s = "[]";
      } else {
         if(format == "") {
            format = DefaultFormat(t);
         }
         s = "[";
         for(int i = 0; i < size - 1; i++) {
            s += StringFormat(format + sep, array[i]);
         }
         s += StringFormat(format, array[size - 1]);
         s += "]";
      }
   }
   return s;
}

template<typename T1, typename T2>
string ArrayToString(const T1& array1[], const T2& array2[], string format = "", string sep = ", ") {
   string s = "";
   string t1 = typename(T1);
   string t2 = typename(T2);
   int size  = MathMin(ArraySize(array1), ArraySize(array2));

   if(size == 0) {
      s = "{}";
   } else {
      if(format == "") {
         format = DefaultFormat(t1) + ": " + DefaultFormat(t2);
      }
      s = "{";
      for(int i = 0; i < size - 1; i++) {
         s += StringFormat(format, array1[i], array2[i]) + sep;
      }
      s += StringFormat(format, array1[size - 1], array2[size - 1]);
      s += "}";
   }

   return s;
}


#ifdef __MQL4__

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void PrintLog(const string logMessage) {
   string lines[];
   StringSplit(logMessage, '\n', lines);

   for(int i = ArraySize(lines) - 1; i >= 0; i--) {
      Print(lines[i]);
   }
}

#endif
//+------------------------------------------------------------------+

#ifdef __MQL5__
void PrintLog(const string logMessage) {
   string lines[];
   StringSplit(logMessage, '\n', lines);

   for(int i = 0; i < ArraySize(lines); i++) {
      Print(lines[i]);
   }
}
#endif


//+------------------------------------------------------------------+
