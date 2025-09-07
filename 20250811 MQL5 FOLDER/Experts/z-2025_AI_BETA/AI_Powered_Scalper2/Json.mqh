//+------------------------------------------------------------------+
//|                                                         Json.mqh |
//|                                                     Manus AI       |
//|                 A simple JSON builder and parser for MQL5        |
//+------------------------------------------------------------------+
#property copyright "Manus AI"
#property link      "https"

// Forward declaration for CJson to be used in CJAVal
class CJson;

//+------------------------------------------------------------------+
//| A class to represent an array of JSON objects                    |
//+------------------------------------------------------------------+
class CJAVal
  {
private:
   string            m_elements[];
   int               m_total_elements;

public:
                     CJAVal(void) { m_total_elements = 0; ArrayResize(m_elements, 0); }
                    ~CJAVal(void) {}
   //--- methods
   void              Add(CJson &value);
   string            ToString(void);
  };

//+------------------------------------------------------------------+
//| A class to build a JSON object                                   |
//+------------------------------------------------------------------+
class CJson
  {
private:
   string            m_fields[];
   string            m_values[];
   int               m_total_fields;

public:
                     CJson(void) { m_total_fields = 0; ArrayResize(m_fields, 0); ArrayResize(m_values, 0); }
                    ~CJson(void) {}
   //--- methods
   void              Add(const string key, const string value);
   void              Add(const string key, const double value, const int digits=8);
   void              Add(const string key, const long value);
   void              Add(const string key, CJson &value);
   void              Add(const string key, CJAVal &value);
   string            ToString(void);
   string            GetValue(const string key);
  };

//+------------------------------------------------------------------+
//| Adds a JSON object to the array                                  |
//+------------------------------------------------------------------+
void CJAVal::Add(CJson &value)
  {
   m_total_elements++;
   ArrayResize(m_elements, m_total_elements);
   m_elements[m_total_elements - 1] = value.ToString();
  }

//+------------------------------------------------------------------+
//| Converts the array to its string representation                  |
//+------------------------------------------------------------------+
string CJAVal::ToString(void)
  {
   string result = "[";
   for(int i = 0; i < m_total_elements; i++)
     {
      result += m_elements[i];
      if(i < m_total_elements - 1)
        {
         result += ",";
        }
     }
   result += "]";
   return result;
  }

//+------------------------------------------------------------------+
//| Adds a string value to the JSON object                           |
//+------------------------------------------------------------------+
void CJson::Add(const string key, const string value)
  {
   m_total_fields++;
   ArrayResize(m_fields, m_total_fields);
   ArrayResize(m_values, m_total_fields);
   m_fields[m_total_fields - 1] = "\"" + key + "\"";
   //--- Create a mutable copy and escape special characters for JSON validity
   string escaped_value = value;
   StringReplace(escaped_value, "\\", "\\\\"); // Escape backslashes
   StringReplace(escaped_value, "\"", "\\\""); // Escape double quotes
   m_values[m_total_fields - 1] = "\"" + escaped_value + "\"";
  }

//+------------------------------------------------------------------+
//| Adds a double value to the JSON object                           |
//+------------------------------------------------------------------+
void CJson::Add(const string key, const double value, const int digits=8)
  {
   m_total_fields++;
   ArrayResize(m_fields, m_total_fields);
   ArrayResize(m_values, m_total_fields);
   m_fields[m_total_fields - 1] = "\"" + key + "\"";
   m_values[m_total_fields - 1] = DoubleToString(value, digits);
  }

//+------------------------------------------------------------------+
//| Adds a long value to the JSON object                             |
//+------------------------------------------------------------------+
void CJson::Add(const string key, const long value)
  {
   m_total_fields++;
   ArrayResize(m_fields, m_total_fields);
   ArrayResize(m_values, m_total_fields);
   m_fields[m_total_fields - 1] = "\"" + key + "\"";
   m_values[m_total_fields - 1] = IntegerToString(value);
  }

//+------------------------------------------------------------------+
//| Adds a nested JSON object                                        |
//+------------------------------------------------------------------+
void CJson::Add(const string key, CJson &value)
  {
   m_total_fields++;
   ArrayResize(m_fields, m_total_fields);
   ArrayResize(m_values, m_total_fields);
   m_fields[m_total_fields - 1] = "\"" + key + "\"";
   m_values[m_total_fields - 1] = value.ToString();
  }

//+------------------------------------------------------------------+
//| Adds a JSON array object                                         |
//+------------------------------------------------------------------+
void CJson::Add(const string key, CJAVal &value)
  {
   m_total_fields++;
   ArrayResize(m_fields, m_total_fields);
   ArrayResize(m_values, m_total_fields);
   m_fields[m_total_fields - 1] = "\"" + key + "\"";
   m_values[m_total_fields - 1] = value.ToString();
  }

//+------------------------------------------------------------------+
//| Converts the object to its string representation                 |
//+------------------------------------------------------------------+
string CJson::ToString(void)
  {
   string result = "{";
   for(int i = 0; i < m_total_fields; i++)
     {
      result += m_fields[i] + ":" + m_values[i];
      if(i < m_total_fields - 1)
        {
         result += ",";
        }
     }
   result += "}";
   return result;
  }

//+------------------------------------------------------------------+
//| Simple parser to get a value for a key.                          |
//| This is not a full parser but is more robust than StringFind.    |
//| It does not handle nested objects for value extraction.          |
//+------------------------------------------------------------------+
string CJson::GetValue(const string key)
  {
   string json_string = ToString(); // In a real scenario, this would parse a string passed to it
   string key_to_find = "\"" + key + "\":";
   int key_pos = StringFind(json_string, key_to_find);

   if(key_pos == -1)
      return "";

   int value_start_pos = key_pos + StringLen(key_to_find);
   string value = "";

   // Trim leading spaces
   while(StringGetCharacter(json_string, value_start_pos) == ' ' || StringGetCharacter(json_string, value_start_pos) == '\n')
     {
      value_start_pos++;
     }

   ushort first_char = StringGetCharacter(json_string, value_start_pos);

   if(first_char == '"') // It's a string
     {
      int end_quote_pos = StringFind(json_string, "\"", value_start_pos + 1);
      // Basic handling for escaped quotes
      while(StringGetCharacter(json_string, end_quote_pos - 1) == '\\')
      {
         end_quote_pos = StringFind(json_string, "\"", end_quote_pos + 1);
      }
      if(end_quote_pos != -1)
        {
         value = StringSubstr(json_string, value_start_pos + 1, end_quote_pos - (value_start_pos + 1));
        }
     }
   else // It's a number, boolean or null
     {
      int end_pos = StringFind(json_string, ",", value_start_pos);
      if(end_pos == -1)
        {
         end_pos = StringFind(json_string, "}", value_start_pos);
        }
      if(end_pos != -1)
        {
         value = StringSubstr(json_string, value_start_pos, end_pos - value_start_pos);
        }
     }

   return value;
  }

//+------------------------------------------------------------------+
//| Standalone function to parse a value from a raw JSON string.     |
//+------------------------------------------------------------------+
string JsonGetValue(const string json, const string key)
  {
   string key_to_find = "\"" + key + "\":";
   int key_pos = StringFind(json, key_to_find, 0);

   if(key_pos == -1)
      return "";

   int value_start_pos = key_pos + StringLen(key_to_find);
   string value = "";

   // Trim leading spaces
   while(StringGetCharacter(json, value_start_pos) == ' ' || StringGetCharacter(json, value_start_pos) == '\n' || StringGetCharacter(json, value_start_pos) == '\r' || StringGetCharacter(json, value_start_pos) == '\t')
     {
      value_start_pos++;
     }

   ushort first_char = StringGetCharacter(json, value_start_pos);

   if(first_char == '"') // It's a string
     {
      int end_quote_pos = StringFind(json, "\"", value_start_pos + 1);
      // This simple parser doesn't handle escaped quotes inside the string value well.
      // For this project's needs (BUY/SELL/HOLD), it's sufficient.
      if(end_quote_pos != -1)
        {
         value = StringSubstr(json, value_start_pos + 1, end_quote_pos - (value_start_pos + 1));
        }
     }
   else // It's a number, boolean, or null
     {
      int end_pos = StringFind(json, ",", value_start_pos);
      if(end_pos == -1)
        {
         end_pos = StringFind(json, "}", value_start_pos);
        }
      if(end_pos != -1)
        {
         value = StringSubstr(json, value_start_pos, end_pos - value_start_pos);
         // trim trailing spaces
         while(StringLen(value) > 0 && (StringGetCharacter(value, StringLen(value)-1) == ' ' || StringGetCharacter(value, StringLen(value)-1) == '\n' || StringGetCharacter(value, StringLen(value)-1) == '\r' || StringGetCharacter(value, StringLen(value)-1) == '\t'))
           {
            value = StringSubstr(value, 0, StringLen(value)-1);
           }
        }
     }

   return value;
  }
//+------------------------------------------------------------------+ 