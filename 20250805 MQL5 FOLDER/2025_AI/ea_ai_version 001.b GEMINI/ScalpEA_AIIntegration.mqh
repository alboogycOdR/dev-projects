//+------------------------------------------------------------------+
//| ScalpEA_AIIntegration.mqh                                        |
//| AI Integration Module for Scalp EA (v1.2 - Using MQL5-Json Lib) |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025"
#property link      "https://www.example.com"
#property strict

// Include required libraries
#include <Arrays\ArrayString.mqh>
#include <Arrays\ArrayObj.mqh>
#include <Object.mqh> // Include for CObject, CString

// --- Include the MQL5 JSON Library ---
// *** ASSUMPTION: All library files (JSON.mqh, JAson.mqh, etc.) ***
// *** are placed inside the MQL5\Include\JSON\ folder.          ***
#include "JAson.mqh" // Include the main library header

// Abstract base AI Model interface
class IAIModel : public CObject
  {
public:
   virtual bool      Initialize(string apiKey, int maxTokens, double temperature, int retryCount, int timeoutMS) = 0;
   virtual string    GetTradingSignal(string marketData) = 0;
   virtual string    GetMarketAnalysis(string marketData) = 0;
   virtual string    ValidateStopLoss(string tradeData) = 0;
   virtual bool      ParseSignal(string signal, string &direction, double &entryPrice, double &stopLoss, double &takeProfit, double initialSLPips, double minProfitToRisk) = 0;
   virtual string    GetName() = 0;
   virtual string    GetModelProvider() = 0;
   virtual          ~IAIModel() {};
  };

// --- Remove the old custom helper ---
// string UnescapeJsonString(string escaped){ ... } // REMOVED - Library handles this


//--- OpenAI GPT-4o Model ---
class CGPT4o : public IAIModel
  {
private:
   string            m_apiKey;
   string            m_baseUrl;
   string            m_modelName;
   int               m_maxTokens;
   double            m_temperature;
   int               m_retryCount;
   int               m_timeoutMS;
   bool              m_isInitialized;
   string            m_tradingSignalPrompt;
   string            m_marketAnalysisPrompt;
   string            m_stopLossValidationPrompt;

   // Function to make an API call to OpenAI
   string            MakeAPIRequest(string prompt, string marketData)
     {
      if(!m_isInitialized)
        {
         Print("Error: CGPT4o not initialized.");
         return "";
        }
      if(StringLen(m_apiKey) < 10 || MQLInfoInteger(MQL_TESTER))
        {
         if(!MQLInfoInteger(MQL_TESTER) && m_apiKey != "")
            Print("CGPT4o: Sim Mode (No API Key or Tester).");
         return SimulateResponse(prompt, marketData);
        }
      // Prepare JSON payload (Escaping handled more robustly by encoder if used, basic manual escaping here)
      string jsonPayload;
      CJAVal payloadRoot(jtOBJ, ""); // Use library to build payload (safer escaping)
      payloadRoot["model"] = m_modelName;
      payloadRoot["temperature"] = m_temperature;
      payloadRoot["max_tokens"] = m_maxTokens;
      payloadRoot["messages"].New()[0]["role"] = "system";
      payloadRoot["messages"][0]["content"] = prompt;
      payloadRoot["messages"].Add(CJAVal(jtOBJ, ""))["role"] = "user";
      payloadRoot["messages"][1]["content"] = marketData;
      jsonPayload = payloadRoot.Serialize(); // Serialize payload using library
      uchar requestPayloadU[];
      string headers = "Content-Type: application/json\r\nAuthorization: Bearer " + m_apiKey + "\r\n";
      int timeout = m_timeoutMS;
      string url = m_baseUrl;
      int payloadLen = StringToCharArray(jsonPayload, requestPayloadU, 0, -1, CP_UTF8);
      if(payloadLen <= 0)
        {
         Print("CGPT4o Error: UTF8 conversion failed.");
         return "";
        }
      string responseText = "";
      int attempt = 0;
      int httpResultCode = 0;
      while(attempt < m_retryCount && responseText == "")
        {
         if(attempt>0)
           {
            Print("CGPT4o: Retrying API(",attempt+1,"/",m_retryCount,")...");
            Sleep(1500);
           }
         attempt++;
         ResetLastError();
         char responseData[];
         ArrayResize(responseData, 65536); // 64KB buffer
         httpResultCode=WebRequest("POST",url,headers,timeout,requestPayloadU,responseData,headers);
         int lastError=GetLastError();
         if(httpResultCode == 200)
           {
            responseText = CharArrayToString(responseData); // Assume compatible encoding
            string generatedText = "";
            // --- Use MQL5-Json Library to Parse ---
            CJAVal jsonResponse;
            if(jsonResponse.Deserialize(responseText))
              {
               // Navigate: choices[0].message.content
               if(jsonResponse.HasKey("choices"))
                 {
                  CJAVal choicesArray = jsonResponse["choices"];
                  if(choicesArray.m_type == jtARRAY)
                    {
                     if(choicesArray.Size() > 0)
                       {
                        CJAVal messageObj = choicesArray[0]["message"]; // Get message object
                        if(messageObj.m_type == jtOBJ)
                          {
                           if(messageObj.HasKey("content"))
                             {
                              CJAVal contentVal = messageObj["content"];
                              if(contentVal.m_type == jtSTR)
                                {
                                 generatedText = contentVal.ToStr(); // Extract content string
                                }
                              else
                                {
                                 Print("CGPT4o JSON Parse Err: 'content' key not string in message.");
                                }
                             }
                           else
                             {
                              Print("CGPT4o JSON Parse Err: 'content' key missing in message.");
                             }
                          }
                        else
                          {
                           Print("CGPT4o JSON Parse Err: 'message' not object type.");
                          }
                       }
                     else
                       {
                        Print("CGPT4o JSON Parse Err: 'choices' array empty.");
                       }
                    }
                  else
                    {
                     Print("CGPT4o JSON Parse Err: 'choices' not array type.");
                    }
                 }
               else
                 {
                  Print("CGPT4o JSON Parse Err: 'choices' key missing.");
                 }
              }
            else
              {
               Print("CGPT4o JSON Parse Err: Deserialize failed. Invalid JSON?");
               Print("Raw Response Start: ", StringSubstr(responseText, 0, 200));
              }
            // --- End MQL5-Json Parsing ---
            if(generatedText == "")
              {
               Print("CGPT4o API Err: Parse failed (HTTP 200). Attempt ",attempt);
               responseText="";
               httpResultCode=-1;
               Sleep(500);
              }
            else { /* Print("CGPT4o API OK (Att ",attempt,")"); */ return generatedText; } // SUCCESS
           }
         else     // Handle HTTP errors (same logic as before)
           {
            string eMsg="CGPT4o API Fail! HTTP:"+ (string)httpResultCode;
            if(lastError!=0)
               eMsg+=", MQL:"+ (string)lastError;
            eMsg+=", Att:"+ (string)attempt;
            Print(eMsg);
            string eBody=CharArrayToString(responseData);
            if(StringLen(eBody)>0 && StringLen(eBody)<500)
               Print("CGPT4o Err Body: ",eBody);
            if(lastError==4003||lastError==4004)
              {
               Print("CGPT4o WebReq Err: URL '",url,"' not allowed.");
               break;
              }
            if(httpResultCode==401)
              {
               Print("CGPT4o API Err: Auth(401). Check Key.");
               break;
              }
            if(httpResultCode==400)
              {
               Print("CGPT4o API Err: Bad Req(400).");
               break;
              }
            if(httpResultCode==404)
              {
               Print("CGPT4o API Err: Not Found(404).");
               break;
              }
            if(httpResultCode>=400&&httpResultCode<500&&httpResultCode!=429)
              {
               Print("CGPT4o Client Err ",httpResultCode);
               break;
              }
            if(httpResultCode==429)
              {
               Print("CGPT4o Rate Limit(429). Waiting...");
               Sleep(5000+MathRand()%5000);
              }
            responseText="";
           }
        }
      Print("CGPT4o API req failed after ",attempt," attempts. HTTP:",httpResultCode);
      return "";
     }

   // --- REMOVE THE OLD CUSTOM PARSER ---
   // string ExtractContentFromJsonResponse_OpenAI(string jsonResponse) { ... } // REMOVED

   // Simulated response generator (remains the same)
   string            SimulateResponse(string prompt, string marketData) { /* ... keep simulation logic ... */ MqlDateTime dt; TimeCurrent(dt); double rV = MathMod(dt.sec*dt.min+dt.hour+GetTickCount(),100)/100.0; double cb=SymbolInfoDouble(Symbol(),SYMBOL_BID), ca=SymbolInfoDouble(Symbol(),SYMBOL_ASK); if(cb==0||ca==0) {cb=1900.0;ca=1900.5;} int dg=(int)SymbolInfoInteger(Symbol(),SYMBOL_DIGITS); if(dg<0)dg=2; double pnt=SymbolInfoDouble(Symbol(),SYMBOL_POINT); if(pnt<=0)pnt=0.01; double pipV=pnt*((dg==2||dg==4)?1.0:10.0); if(Symbol()=="XAUUSD") pipV=pnt*10.0; if(StringFind(prompt,"trading signal")>=0) {if(rV<0.4) {double eP=ca,slP=30+rV*40;double sl=Norm(eP-slP*pipV,dg);double tp=Norm(eP+slP*pipV*2.0,dg);return "BUY at "+DTS(eP,dg)+" SL="+DTS(sl,dg)+" TP="+DTS(tp,dg)+" Reason: Sim bullish.";} else if(rV<0.8) {double eP=cb,slP=30+rV*40;double sl=Norm(eP+slP*pipV,dg);double tp=Norm(eP-slP*pipV*2.0,dg);return "SELL at "+DTS(eP,dg)+" SL="+DTS(sl,dg)+" TP="+DTS(tp,dg)+" Reason: Sim bearish.";} else return "NO_TRADE Reason: Sim neutral.";} else if(StringFind(prompt,"stop-loss validation")>=0) {if(rV<0.6)return"VALID";else if(rV<0.8)return"ADJUST_UP";else if(rV<0.9)return"ADJUST_DOWN";else return"CLOSE";} else if(StringFind(prompt,"market analysis")>=0) {string a="Sim Analysis("+Symbol()+"):\n";if(rV<0.5)a+="Bullish. Sup "+DTS(cb*0.99,dg)+".\nRec: BUY near "+DTS(ca*0.995,dg)+" SL "+DTS(cb*0.99,dg)+".";else a+="Bearish. Res "+DTS(ca*1.01,dg)+".\nRec: SELL near "+DTS(cb*1.005,dg)+" SL "+DTS(ca*1.01,dg)+".";return a;} return "SIM_ERR: Prompt type unrecognized.";}
   // Helpers for simulation code
   string            DTS(double v, int dg) { return DoubleToString(v,dg);} double Norm(double v, int dg) {return NormalizeDouble(v,dg);}

public:
                     CGPT4o() { /* ... constructor defaults ... */ m_isInitialized = false; m_baseUrl = "https://api.openai.com/v1/chat/completions"; m_modelName = "gpt-4o"; m_maxTokens = 256; m_temperature = 0.2; m_retryCount = 3; m_timeoutMS = 5000; m_tradingSignalPrompt = "..."; m_marketAnalysisPrompt = "..."; m_stopLossValidationPrompt = "..."; /* Keep prompts */}
                    ~CGPT4o() override {}
   bool              Initialize(string apiKey, int maxTokens, double temperature, int retryCount, int timeoutMS) override { /* ... keep init logic ... */ m_apiKey = apiKey; m_maxTokens = maxTokens > 0 ? maxTokens : 256; m_temperature = MathMax(0.0, MathMin(2.0, temperature)); m_retryCount = MathMax(1, MathMin(10, retryCount)); m_timeoutMS = MathMax(1000, MathMin(60000, timeoutMS)); if(m_apiKey == "" && !MQLInfoInteger(MQL_TESTER)) Print("Warning: CGPT4o Sim Mode (No API Key)."); m_isInitialized = true; Print("CGPT4o Initialized: ",m_modelName); return true;}
   string            GetTradingSignal(string md) override { return MakeAPIRequest(m_tradingSignalPrompt, md); }
   string            GetMarketAnalysis(string md) override { return MakeAPIRequest(m_marketAnalysisPrompt, md); }
   string            ValidateStopLoss(string td) override
     {
      string r=MakeAPIRequest(m_stopLossValidationPrompt, td);
      StringTrimLeft(r);
      StringTrimRight(r);
      StringToUpper(r);
      string u=r;//StringToUpper(StringTrimRight(StringTrim(r)));
      if(u=="VALID"||u=="ADJUST_UP"||u=="ADJUST_DOWN"||u=="CLOSE")
         return u;
      if(r!="")
         Print("Warn(OAI): Bad SL valid '",r,"'. Default VALID.");
      return "VALID";
     }
   bool              ParseSignal(string signal, string &d, double &e, double &sl, double &tp, double iSLp, double mRR) override { /* ... keep parsing logic ... */ d = ""; e = 0; sl = 0; tp = 0; if(signal=="" || StringFind(signal,"NO_TRADE")>=0) return false; if(StringFind(signal,"BUY")>=0) d="BUY"; else if(StringFind(signal,"SELL")>=0) d="SELL"; else return false; double cb=SymbolInfoDouble(Symbol(),SYMBOL_BID), ca=SymbolInfoDouble(Symbol(),SYMBOL_ASK); int dig=(int)SymbolInfoInteger(Symbol(),SYMBOL_DIGITS); if(dig<0)dig=2; double pnt=SymbolInfoDouble(Symbol(),SYMBOL_POINT); if(pnt<=0) pnt=0.00001; double pipV=pnt*((dig==2 || dig==4)?1.0:10.0); if(Symbol()=="XAUUSD") pipV=pnt*10.0; e=(d=="BUY")?ca:cb; int atP=StringFind(signal," at "); if(atP>0) {string pS;int sP=atP+4,spP=StringFind(signal," ",sP);if(spP>sP)pS=StringSubstr(signal,sP,spP-sP);double pV=StringToDouble(pS);if(pV>0)e=pV;} int slP=StringFind(signal,"SL="); if(slP>0) {string pS;int sP=slP+3,spP=StringFind(signal," ",sP);if(spP>sP)pS=StringSubstr(signal,sP,spP-sP);else pS=StringSubstr(signal,sP);sl=StringToDouble(pS);} int tpP=StringFind(signal,"TP="); if(tpP>0) {string pS;int sP=tpP+3,spP=StringFind(signal," ",sP);if(spP>sP)pS=StringSubstr(signal,sP,spP-sP);else pS=StringSubstr(signal,sP);tp=StringToDouble(pS);} if(sl<=0||(d=="BUY"&&sl>=e)||(d=="SELL"&&sl<=e)) {sl=(d=="BUY")?Norm(e-iSLp*pipV,dig):Norm(e+iSLp*pipV,dig);} if(tp<=0||(d=="BUY"&&tp<=e)||(d=="SELL"&&tp>=e)) {if(mRR>0) {double rD=MathAbs(e-sl);if(rD>pnt)tp=(d=="BUY")?Norm(e+rD*mRR,dig):Norm(e-rD*mRR,dig);else tp=0;} else tp=0;} if((d=="BUY"&&(sl>=e||(tp>0&&tp<=e)))||(d=="SELL"&&(sl<=e||(tp>0&&tp>=e)))) {Print("Err: Parsed signal invalid SL/TP vs Entry. Discard."); return false;} return true;}
string GetName() override { return m_modelName; } string GetModelProvider() override { return "OpenAI"; }
  };


//--- Anthropic Claude Haiku Model ---
class CClaudeHaiku : public IAIModel
  {
private:
   string            m_apiKey;
   string            m_baseUrl;
   string            m_modelName;
   int               m_maxTokens;
   double            m_temperature;
   int               m_retryCount;
   int               m_timeoutMS;
   bool              m_isInitialized;
   string            m_tradingSignalPrompt;
   string            m_marketAnalysisPrompt;
   string            m_stopLossValidationPrompt;

   // Function to make an API call to Anthropic
   string            MakeAPIRequest(string prompt, string marketData)
     {
      if(!m_isInitialized)
        {
         Print("Error: CClaudeHaiku not initialized.");
         return "";
        }
      if(StringLen(m_apiKey) < 10 || MQLInfoInteger(MQL_TESTER))
        {
         if(!MQLInfoInteger(MQL_TESTER) && m_apiKey != "")
            Print("CClaudeHaiku: Sim Mode (No API Key or Tester).");
         return SimulateResponse(prompt, marketData);
        }
      // Build Payload using JSON lib helper (example)
      //CJAVal payloadRoot(jtOBJ);
      //payloadRoot["model"] = m_modelName;
      //payloadRoot["system"] = prompt; // System prompt
      //payloadRoot["temperature"] = m_temperature;
      //payloadRoot["max_tokens"] = m_maxTokens;
      
      string jsonPayload;
      CJAVal payloadRoot;     // Use default constructor
      payloadRoot.m_type = jtOBJ; // Explicitly set the type to Object
      payloadRoot["model"] = m_modelName;
      payloadRoot["system"] = prompt; // System prompt
      payloadRoot["temperature"] = m_temperature;
      payloadRoot["max_tokens"] = m_maxTokens;
      
      //NOT SURE ABOUT THE NEXT 3 LINES
      payloadRoot["messages"].Clear(jtARRAY); // Clear ensures type is set if needed
      payloadRoot["messages"].New()[0]["role"] = "user";      
      payloadRoot["messages"][0]["content"] = marketData;
      
      
      
      
      jsonPayload = payloadRoot.Serialize();
      
      
      uchar requestPayloadU[];
      
      string headers="Content-Type: application/json\r\nx-api-key: "+m_apiKey+"\r\nanthropic-version: 2023-06-01\r\n";
      int timeout = m_timeoutMS;
      string url = m_baseUrl;
      
      int payloadLen = StringToCharArray(jsonPayload, requestPayloadU, 0, -1, CP_UTF8);
      
      if(payloadLen<=0)
        {
         Print("Claude Error: UTF8 conversion fail.");
         return "";
        }
        
      string responseText = "";
      
      int attempt = 0;
      int httpResultCode = 0;
      
      while(attempt < m_retryCount && responseText == "")
        {
         if(attempt>0)
           {
            Print("Claude: Retrying API(",attempt+1,"/",m_retryCount,")...");
            Sleep(1500);
           }
         attempt++;
         ResetLastError();
         char responseData[];
         ArrayResize(responseData, 65536); // 64KB buffer
         httpResultCode=WebRequest("POST",url,headers,timeout,requestPayloadU,responseData,headers);
         int lastError=GetLastError();
         if(httpResultCode == 200)
           {
            responseText = CharArrayToString(responseData);
            string generatedText = "";
            // --- Use MQL5-Json Library to Parse ---
            CJAVal jsonResponse;
            if(jsonResponse.Deserialize(responseText))
              {
               // Navigate: content[0].text
               if(jsonResponse.HasKey("content"))
                 {
                  CJAVal contentArray = jsonResponse["content"];
                  if(contentArray.m_type == jtARRAY)
                    {
                     if(contentArray.Size() > 0)
                       {
                        CJAVal textBlock = contentArray[0]; // Get first element in content array
                        if(textBlock.m_type == jtOBJ)
                          {
                           if(textBlock.HasKey("text"))
                             {
                              CJAVal textVal = textBlock["text"];
                              if(textVal.m_type == jtSTR)
                                {
                                 generatedText = textVal.ToStr(); // Extract text
                                }
                              else
                                {
                                 Print("Claude JSON Parse Err: 'text' value not string type.");
                                }
                             }
                           else
                             {
                              Print("Claude JSON Parse Err: 'text' key missing in content item.");
                             }
                          }
                        else
                          {
                           Print("Claude JSON Parse Err: First content item not object type.");
                          }
                       }
                     else
                       {
                        Print("Claude JSON Parse Err: 'content' array is empty.");
                       }
                    }
                  else
                    {
                     Print("Claude JSON Parse Err: 'content' not array or empty.");
                    }
                 }
               else
                 {
                  Print("Claude JSON Parse Err: 'content' array missing.");
                 }
              }
            else
              {
               Print("Claude JSON Parse Err: Deserialize failed.");
               Print("Raw Response Start: ", StringSubstr(responseText, 0, 200));
              }
            // --- End MQL5-Json Parsing ---
            if(generatedText=="")
              {
               Print("Claude API Err: Parse failed (HTTP 200). Att ",attempt);
               responseText="";
               httpResultCode=-1;
               Sleep(500);
              }
            else { /* Print("Claude API OK (Att ",attempt,")"); */ return generatedText; } // SUCCESS
           }
         else   // Handle HTTP errors (same logic as before)
           {
            string eMsg="Claude API Fail! HTTP:"+ (string)httpResultCode;
            if(lastError!=0)
               eMsg+=", MQL:"+ (string)lastError;
            eMsg+=", Att:"+ (string)attempt;
            Print(eMsg);
            string eBody=CharArrayToString(responseData);
            if(StringLen(eBody)>0 && StringLen(eBody)<500)
               Print("Claude Err Body: ",eBody);
            if(lastError==4003||lastError==4004)
              {
               Print("Claude WebReq Err: URL '",url,"' not allowed.");
               break;
              }
            if(httpResultCode==401||httpResultCode==403)
              {
               Print("Claude API Err: Auth/Forbidden(401/403).");
               break;
              }
            if(httpResultCode==400)
              {
               Print("Claude API Err: Bad Req(400).");
               break;
              }
            if(httpResultCode==404)
              {
               Print("Claude API Err: Not Found(404).");
               break;
              }
            if(httpResultCode>=400&&httpResultCode<500&&httpResultCode!=429)
              {
               Print("Claude Client Err ",httpResultCode);
               break;
              }
            if(httpResultCode==429)
              {
               Print("Claude Rate Limit(429). Waiting...");
               Sleep(5000+MathRand()%5000);
              }
            responseText="";
           }
        }
      Print("Claude API req failed after ",attempt," attempts. HTTP:",httpResultCode);
      return "";
     }

   // --- REMOVE THE OLD CUSTOM PARSER ---
   // string ExtractContentFromJsonResponse_Anthropic(string jsonResponse) { ... } // REMOVED

   // Simulated response generator (remains the same)
   string            SimulateResponse(string prompt, string marketData) { /* ... keep simulation logic ... */ MqlDateTime dt; TimeCurrent(dt); double rV=MathMod(dt.sec*dt.min+dt.hour+GetTickCount()+10,100)/100.0; double cb=SymbolInfoDouble(Symbol(),SYMBOL_BID),ca=SymbolInfoDouble(Symbol(),SYMBOL_ASK); if(cb==0||ca==0) {cb=1900.0;ca=1900.5;} int dg=(int)SymbolInfoInteger(Symbol(),SYMBOL_DIGITS); if(dg<0)dg=2; double pnt=SymbolInfoDouble(Symbol(),SYMBOL_POINT); if(pnt<=0) pnt=0.01; double pipV=pnt*((dg==2||dg==4)?1.0:10.0); if(Symbol()=="XAUUSD") pipV=pnt*10.0; if(StringFind(prompt,"trading signal")>=0) {if(rV<0.35) {double eP=ca,slP=25+rV*35;double sl=Norm(eP-slP*pipV,dg);double tp=Norm(eP+slP*pipV*2.5,dg);return"BUY at "+DTS(eP,dg)+" SL="+DTS(sl,dg)+" TP="+DTS(tp,dg)+" Reason: Sim Claude bullish.";} else if(rV<0.75) {double eP=cb,slP=25+rV*35;double sl=Norm(eP+slP*pipV,dg);double tp=Norm(eP-slP*pipV*2.5,dg);return"SELL at "+DTS(eP,dg)+" SL="+DTS(sl,dg)+" TP="+DTS(tp,dg)+" Reason: Sim Claude bearish.";} else return"NO_TRADE Reason: Sim Claude neutral.";} else if(StringFind(prompt,"stop-loss validation")>=0) {if(rV<0.5)return"VALID";else if(rV<0.75)return"ADJUST_UP";else if(rV<0.9)return"ADJUST_DOWN";else return"CLOSE";} else if(StringFind(prompt,"market analysis")>=0) {string a="Sim Claude Analysis("+Symbol()+"):\n";if(rV<0.6) {a+="Uptrend. Sup "+DTS(cb*0.985,dg)+". Rec: BUY near "+DTS(ca*0.998,dg)+", SL "+DTS(cb*0.985,dg)+".";} else {a+="Reversal. Res "+DTS(ca*1.015,dg)+". Rec: SELL near "+DTS(cb*1.01,dg)+", SL "+DTS(ca*1.015,dg)+".";} return a;} return"SIM_ERROR: Claude simulation failed.";}
   // Helpers for simulation code
   string            DTS(double v, int dg) { return DoubleToString(v,dg);} double Norm(double v, int dg) {return NormalizeDouble(v,dg);}

public:
                     CClaudeHaiku() { /* ... constructor defaults ... */ m_isInitialized=false; m_baseUrl="https://api.anthropic.com/v1/messages"; m_modelName="claude-3-haiku-20240307"; m_maxTokens=256; m_temperature=0.2; m_retryCount=3; m_timeoutMS=5000; m_tradingSignalPrompt="..."; m_marketAnalysisPrompt="..."; m_stopLossValidationPrompt="..."; /* Keep prompts */}
                    ~CClaudeHaiku() override {}
   bool              Initialize(string apiKey, int maxTokens, double temperature, int retryCount, int timeoutMS) override { /* ... keep init logic ... */ m_apiKey=apiKey; m_maxTokens=maxTokens>0?maxTokens:256; m_temperature=MathMax(0.0,MathMin(1.0,temperature)); m_retryCount=MathMax(1,MathMin(10,retryCount)); m_timeoutMS=MathMax(1000,MathMin(60000,timeoutMS)); if(m_apiKey==""&&!MQLInfoInteger(MQL_TESTER))Print("Warn: Claude Sim Mode(No API Key)."); m_isInitialized=true; Print("CClaudeHaiku Initialized: ",m_modelName); return true; }
   string            GetTradingSignal(string md) override { return MakeAPIRequest(m_tradingSignalPrompt, md); }
   string            GetMarketAnalysis(string md) override { return MakeAPIRequest(m_marketAnalysisPrompt, md); }
   string            ValidateStopLoss(string td) override
     {
      string r=MakeAPIRequest(m_stopLossValidationPrompt, td);
      StringTrimLeft(r);
      StringTrimRight(r);
      StringToUpper(r);
      string u=r;//StringToUpper(StringTrimRight(StringTrimLeft(r)));
      
      if(u=="VALID"||u=="ADJUST_UP"||u=="ADJUST_DOWN"||u=="CLOSE")
         return u;
      if(r!="")
         Print("Warn(Anth): Bad SL valid '",r,"'. Default VALID.");
      return "VALID";
     }
   bool              ParseSignal(string s, string &d, double &e, double &sl, double &tp, double iSLp, double mRR) override { CGPT4o h; return h.ParseSignal(s,d,e,sl,tp,iSLp,mRR); } // Reuse parser
   string            GetName() override { return m_modelName; } string GetModelProvider() override { return "Anthropic"; }
  };


//--- Main AI Integration Class (Orchestrator) ---
class CAIIntegration
  {
private:
   IAIModel*         m_aiModel;
   bool              m_isInitialized;
   int               m_errorCount;
   datetime          m_lastRequestTime;
   int               m_requestCounter;
   int               m_maxRequestsPerMinute;
   double            m_initialSLPips;
   double            m_minProfitToRisk;
public:
                     CAIIntegration() { m_aiModel=NULL; m_isInitialized=false; m_errorCount=0; m_lastRequestTime=0; m_requestCounter=0; m_maxRequestsPerMinute=60; m_initialSLPips=50.0; m_minProfitToRisk=1.5; }
                    ~CAIIntegration() { if(m_aiModel != NULL) { delete m_aiModel; m_aiModel = NULL; } }
   bool              Initialize(string modelName, string apiKey, int maxTokens, double temperature, int retryCount, int timeoutMS, double initialSLPips, double minProfitToRisk)
     {
      m_initialSLPips=initialSLPips>0?initialSLPips:50.0;
      m_minProfitToRisk=minProfitToRisk>=0?minProfitToRisk:0; // Allow 0 R:R
      if(m_aiModel!=NULL)
        {
         delete m_aiModel;
         m_aiModel=NULL;
        }
      if(StringFind(modelName,"GPT",0)>=0||StringFind(modelName,"gpt",0)>=0)
        {
         m_aiModel=new CGPT4o();
         if(modelName=="GPT-4o-Plus")
            m_maxRequestsPerMinute=100;
         else
            if(modelName=="GPT-4o-Mini")
               m_maxRequestsPerMinute=180;
            else
               m_maxRequestsPerMinute=60;
        }
      else
         if(StringFind(modelName,"o1-Mini",0)>=0||StringFind(modelName,"claude",0)>=0)
           {
            m_aiModel=new CClaudeHaiku();
            m_maxRequestsPerMinute=90;
           }
         else
           {
            Print("Err: Unsupported AI model '",modelName,"'");
            return false;
           }
      if(m_aiModel==NULL||!m_aiModel.Initialize(apiKey,maxTokens,temperature,retryCount,timeoutMS))
        {
         Print("Err: Failed AI model init.");
         if(m_aiModel!=NULL)
            delete m_aiModel;
         m_aiModel=NULL;
         return false;
        }
      m_isInitialized=true;
      m_errorCount=0;
      m_lastRequestTime=0;
      m_requestCounter=0;
      Print("AI Init OK: ",m_aiModel.GetName()," RPM Limit:",m_maxRequestsPerMinute);
      return true;
     }
   bool              CheckRateLimit() { if(!m_isInitialized)return false; datetime ct=TimeCurrent(); if(ct-m_lastRequestTime>=60) {m_lastRequestTime=ct;m_requestCounter=0;return true;} if(m_requestCounter>=m_maxRequestsPerMinute) {/*Print("Rate limit hit.");*/ return false;} return true;}
   void              IncrementRequestCounter() { if(!m_isInitialized)return; if(m_requestCounter==0) {m_lastRequestTime=TimeCurrent();} m_requestCounter++;}
   string            GetTradingSignal(string md) { if(!m_isInitialized||m_aiModel==NULL) {Print("Err: AI !Init (GetSignal)");m_errorCount++;return "";} if(!CheckRateLimit())return ""; IncrementRequestCounter(); string s=m_aiModel.GetTradingSignal(md); return s;}
   string            GetMarketAnalysis(string md) { if(!m_isInitialized||m_aiModel==NULL) {Print("Err: AI !Init (GetAnalysis)");m_errorCount++;return "";} if(!CheckRateLimit())return ""; IncrementRequestCounter(); string a=m_aiModel.GetMarketAnalysis(md); return a;}
   string            ValidateStopLoss(string td) { if(!m_isInitialized||m_aiModel==NULL) {Print("Err: AI !Init (ValidateSL)");m_errorCount++;return"VALID";} if(!CheckRateLimit()) {/*Print("SL valid rate limit.");*/ return"VALID";} IncrementRequestCounter(); string v=m_aiModel.ValidateStopLoss(td); return v;}
   bool              ParseSignal(string s, string &d, double &e, double &sl, double &tp) { if(!m_isInitialized||m_aiModel==NULL) {Print("Err: AI !Init (ParseSignal)");return false;} return m_aiModel.ParseSignal(s,d,e,sl,tp,m_initialSLPips,m_minProfitToRisk);}
   int               GetErrorCount() const { return m_errorCount; } void IncrementErrorCount() {if(m_isInitialized)m_errorCount++;} void ResetErrorCount() {m_errorCount=0;}
   string            GetActiveModelName() const { return(m_aiModel!=NULL)?m_aiModel.GetName():"None"; } string GetActiveModelProvider() const { return(m_aiModel!=NULL)?m_aiModel.GetModelProvider():"None"; }
  };
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
