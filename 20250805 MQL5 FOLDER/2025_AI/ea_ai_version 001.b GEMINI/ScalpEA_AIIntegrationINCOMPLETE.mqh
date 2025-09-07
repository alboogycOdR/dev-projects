// **2. AI Integration Module**

// *   **Path:** `...\MQL5\Include\ScalpEA\ScalpEA_AIIntegration.mqh`
// *   **Filename:** `ScalpEA_AIIntegration.mqh`

// ```mql5
//+------------------------------------------------------------------+
//| ScalpEA_AIIntegration.mqh                                        |
//| AI Integration Module for Scalp EA (v1.1 - Improved API/JSON)   |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025"
#property link      "https://www.example.com"
#property strict

// Include required libraries
#include <Arrays\ArrayString.mqh>
#include <Arrays\ArrayObj.mqh>
#include <Object.mqh> // Include for CObject, CString

// --- Constants ---
#define JSON_PARSER_SIMPLIFIED // Define to indicate the simple parser is used

// Abstract base AI Model interface
class IAIModel : public CObject {
public:
   virtual bool   Initialize(string apiKey, int maxTokens, double temperature, int retryCount, int timeoutMS) = 0;
   virtual string GetTradingSignal(string marketData) = 0;
   virtual string GetMarketAnalysis(string marketData) = 0;
   virtual string ValidateStopLoss(string tradeData) = 0;
   virtual bool   ParseSignal(string signal, string &direction, double &entryPrice, double &stopLoss, double &takeProfit, double initialSLPips, double minProfitToRisk) = 0;
   virtual string GetName() = 0;
   virtual string GetModelProvider() = 0;
   virtual ~IAIModel() {};
};


// --- Helper: Simple JSON String Unescaper ---
// Handles common escapes found in API responses. Add more if needed.
string UnescapeJsonString(string escaped)
{
    string result = escaped;
    StringReplace(result, "\\\"", "\"");  // Unescape quotes
    StringReplace(result, "\\n", "\n");   // Unescape newlines
    StringReplace(result, "\\r", "\r");   // Unescape carriage returns
    StringReplace(result, "\\t", "\t");   // Unescape tabs
    StringReplace(result, "\\/", "/");    // Unescape slashes (optional)
    StringReplace(result, "\\\\", "\\");  // Unescape backslashes (must be last)
    return result;
}


//--- OpenAI GPT-4o Model ---
class CGPT4o : public IAIModel {
private:
   string m_apiKey;
   string m_baseUrl;
   string m_modelName;
   int    m_maxTokens;
   double m_temperature;
   int    m_retryCount;
   int    m_timeoutMS;
   bool   m_isInitialized;
   string m_tradingSignalPrompt;
   string m_marketAnalysisPrompt;
   string m_stopLossValidationPrompt;


   // Function to make an API call to OpenAI
   string MakeAPIRequest(string prompt, string marketData) {
      if (!m_isInitialized) {
         Print("Error: CGPT4o not initialized for API request.");
         return "";
      }

      // Toggle simulation if API Key is invalid or running in tester
      if (StringLen(m_apiKey) < 10 || MQLInfoInteger(MQL_TESTER)) {
         if(!MQLInfoInteger(MQL_TESTER) && m_apiKey != "") Print("CGPT4o: API Key missing/short or in Tester. Running in Simulation Mode.");
         return SimulateResponse(prompt, marketData);
      }

      // --- Prepare REAL API Request ---
      // ** WARNING: WebRequest is SYNCHRONOUS and blocks execution. Consider a DLL for production EAs. **
      // ** WARNING: Requires URL permission in MT5 options (Tools->Options->Expert Advisors->Allow WebRequest). **

      // Escape prompt and market data minimally for JSON (more robust escaping needed for complex data)
      string escapedPrompt = prompt; StringReplace(escapedPrompt, "\\", "\\\\"); StringReplace(escapedPrompt, "\"", "\\\"");
      string escapedMarketData = marketData; StringReplace(escapedMarketData, "\\", "\\\\"); StringReplace(escapedMarketData, "\"", "\\\""); StringReplace(escapedMarketData, "\n", "\\n");

      string jsonPayload = "{";
      jsonPayload += "\"model\":\"" + m_modelName + "\",";
      jsonPayload += "\"messages\":[";
      jsonPayload += "{\"role\":\"system\",\"content\":\"" + escapedPrompt + "\"},";
      jsonPayload += "{\"role\":\"user\",\"content\":\"" + escapedMarketData + "\"}";
      jsonPayload += "],";
      jsonPayload += "\"temperature\":" + DoubleToString(m_temperature, 1) + ",";
      jsonPayload += "\"max_tokens\":" + IntegerToString(m_maxTokens);
      jsonPayload += "}";

      char responseData[];
      uchar requestPayloadU[]; // Use uchar for UTF8 conversion
      string headers = "Content-Type: application/json\r\nAuthorization: Bearer " + m_apiKey + "\r\n";
      int timeout = m_timeoutMS;
      string url = m_baseUrl;

      // Convert payload to UTF8 uchar array for WebRequest
      int payloadLen = StringToUtf8(jsonPayload, requestPayloadU);

      if(payloadLen <= 0){
         Print("CGPT4o Error: Failed to convert JSON payload to UTF8 char array.");
         return "";
      }

      // --- API Call with Retry Logic ---
      string responseText = "";
      int attempt = 0;
      int httpResultCode = 0;

      while (attempt < m_retryCount && responseText == "") {
         if (attempt > 0) {
             Print("CGPT4o: Retrying API request (Attempt ", attempt + 1, "/", m_retryCount, ")...");
             Sleep(1500); // Wait longer before retry
         }
         attempt++;

         // Clear previous error and make the request
         ResetLastError();
         // Ensure enough buffer size for responseData - can be large! Start with generous buffer.
         ArrayResize(responseData, 32768); // 32KB buffer, adjust if needed

         httpResultCode = WebRequest("POST", url, headers, timeout, requestPayloadU, responseData, headers);
         int lastError = GetLastError();

         if (httpResultCode == 200) {
             // Success - Convert response to string
             responseText = CharArrayToString(responseData); // Assuming server sends compatible encoding, try direct first
             // Optional: Fallback or specific decoding if issues arise
             // string responseTextUtf8 = CharArrayToString(responseData, 0, -1, CP_UTF8);
             // string responseTextAnsi = CharArrayToString(responseData, 0, -1, CP_ACP);

             // Parse the JSON response
             string generatedText = ExtractContentFromJsonResponse_OpenAI(responseText);
             if(generatedText == ""){
                 Print("CGPT4o API Error: Response received (HTTP 200), but failed to parse content. Attempt ", attempt);
                 Print("CGPT4o Raw Response: ", StringSubstr(responseText, 0, 500)); // Log beginning of raw response
                 responseText = ""; // Clear response to force retry or indicate failure
                 httpResultCode = -1; // Treat parsing failure as an error
                 Sleep(500); // Small delay
             } else {
                 // SUCCESS! Return the extracted content
                 // Print("CGPT4o API Request Successful (Attempt ", attempt, ")"); // Optional success log
                 return generatedText;
             }
         } else {
             // Handle HTTP Errors
             string errorMsg = "CGPT4o API Request Failed! HTTP Code: " + (string)httpResultCode;
             if(lastError != 0) errorMsg += ", MQL Error: " + (string)lastError;
              errorMsg += ", Attempt: " + (string)attempt;
              Print(errorMsg);

             // Log response body if available (might contain error details)
              string errorBody = CharArrayToString(responseData);
              if(StringLen(errorBody) > 0 && StringLen(errorBody) < 500) { // Avoid printing huge non-error bodies
                    Print("CGPT4o Error Response Body: ", errorBody);
              }

              // Specific Error Handling & Retry Logic
              if (lastError == 4003 || lastError == 4004) { Print("CGPT4o WebRequest Error: URL '", url, "' not allowed. Check Terminal Settings -> Expert Advisors -> Allow WebRequest."); break; }
              if (httpResultCode == 401) { Print("CGPT4o API Error: Unauthorized (401). Check API Key."); break; }
              if (httpResultCode == 400) { Print("CGPT4o API Error: Bad Request (400). Check JSON payload/params."); break; }
              if (httpResultCode == 404) { Print("CGPT4o API Error: Not Found (404). Check URL."); break; }
              if (httpResultCode >= 400 && httpResultCode < 500 && httpResultCode != 429) { Print("CGPT4o API Client Error (Code ", httpResultCode,")"); break; }
              if (httpResultCode == 429) { Print("CGPT4o API Rate Limit (429). Waiting..."); Sleep(5000 + MathRand()%5000); }
              responseText = "";
         }
      } // End Retry Loop

      Print("CGPT4o API request failed definitively after ", attempt, " attempts. HTTP Code: ", httpResultCode);
      return ""; // Indicates failure
   }

    // --- Simplified JSON Parser for OpenAI Response ---
    string ExtractContentFromJsonResponse_OpenAI(string jsonResponse) {
        #ifdef JSON_PARSER_SIMPLIFIED
            int choicesPos = StringFind(jsonResponse, "\"choices\""); if(choicesPos < 0) { /* Print("ParseError(OAI): 'choices' not found."); */ return ""; }
            int messagePos = StringFind(jsonResponse, "\"message\"", choicesPos); if(messagePos < 0) { /* Print("ParseError(OAI): 'message' not found."); */ return ""; }
            int contentPos = StringFind(jsonResponse, "\"content\"", messagePos); if(contentPos < 0) { /* Print("ParseError(OAI): 'content' not found."); */ return ""; }
            int colonPos = StringFind(jsonResponse, ":", contentPos); if(colonPos < 0) { /* Print("ParseError(OAI): ':' not found."); */ return ""; }
            int quoteOpenPos = StringFind(jsonResponse, "\"", colonPos); if(quoteOpenPos < 0) { /* Print("ParseError(OAI): Opening quote not found."); */ return ""; }
            int valueStartPos = quoteOpenPos + 1; int currentPos = valueStartPos; int valueEndPos = -1;
            while(currentPos < StringLen(jsonResponse)) {
                if(StringGetCharacter(jsonResponse, currentPos) == (uchar)'"') {
                    if(currentPos > 0 && StringGetCharacter(jsonResponse, currentPos - 1) == (uchar)'\\') { currentPos++; continue; }
                    else { valueEndPos = currentPos; break; }
                } currentPos++;
            }
            if(valueEndPos < 0) { /* Print("ParseError(OAI): Closing quote not found."); */ return ""; }
            string extractedValue = StringSubstr(jsonResponse, valueStartPos, valueEndPos - valueStartPos);
            return UnescapeJsonString(extractedValue);
        #else
             Print("Error: JSON_PARSER_SIMPLIFIED not defined but no library implementation provided."); return "";
        #endif
    }

   // Simulated response generator
   string SimulateResponse(string prompt, string marketData) {
      MqlDateTime dt; TimeCurrent(dt);
      double randValue = MathMod(dt.sec * dt.min + dt.hour + GetTickCount(), 100) / 100.0;
      double currentBid = SymbolInfoDouble(Symbol(), SYMBOL_BID); double currentAsk = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
      if(currentBid == 0 || currentAsk == 0) { currentBid = 1900.0; currentAsk = 1900.5; }
      int digits = (int)SymbolInfoInteger(Symbol(), SYMBOL_DIGITS); if(digits < 0) digits=2;
      double point = SymbolInfoDouble(Symbol(), SYMBOL_POINT); if(point <= 0) point = 0.01;
      double pipVal = point * ((digits==2 || digits==4) ? 1.0 : 10.0); if(Symbol()=="XAUUSD") pipVal = point*10.0;

      if (StringFind(prompt, "trading signal") >= 0) {
         if (randValue < 0.4) {
            double entryPrice = currentAsk; double slPips = 30 + randValue * 40;
            double sl = NormalizeDouble(entryPrice - slPips * pipVal, digits);
            double tp = NormalizeDouble(entryPrice + slPips * pipVal * 2.0, digits);
            return "BUY at " + DoubleToString(entryPrice, digits) + " SL=" + DoubleToString(sl, digits) + " TP=" + DoubleToString(tp, digits) + " Reason: Sim bullish.";
         } else if (randValue < 0.8) {
            double entryPrice = currentBid; double slPips = 30 + randValue * 40;
            double sl = NormalizeDouble(entryPrice + slPips * pipVal, digits);
            double tp = NormalizeDouble(entryPrice - slPips * pipVal * 2.0, digits);
            return "SELL at " + DoubleToString(entryPrice, digits) + " SL=" + DoubleToString(sl, digits) + " TP=" + DoubleToString(tp, digits) + " Reason: Sim bearish.";
         } else return "NO_TRADE Reason: Sim neutral.";
      } else if (StringFind(prompt, "stop-loss validation") >= 0) {
         if (randValue < 0.6) return "VALID"; else if (randValue < 0.8) return "ADJUST_UP"; else if (randValue < 0.9) return "ADJUST_DOWN"; else return "CLOSE";
      } else if (StringFind(prompt, "market analysis") >= 0) {
         string analysis = "Simulated Analysis ("+Symbol()+"):\n";
         if (randValue < 0.5) analysis += "Looks bullish. Support " + DoubleToString(currentBid * 0.99, digits) + ".\nRec: BUY near " + DoubleToString(currentAsk * 0.995, digits) + " SL " + DoubleToString(currentBid * 0.99, digits) + ".";
         else analysis += "Looks bearish. Resistance " + DoubleToString(currentAsk * 1.01, digits) + ".\nRec: SELL near " + DoubleToString(currentBid * 1.005, digits) + " SL " + DoubleToString(currentAsk * 1.01, digits) + ".";
         return analysis;
      } return "SIM_ERROR: Prompt type unrecognized.";
   }

public:
   CGPT4o() {
      m_isInitialized = false; m_baseUrl = "https://api.openai.com/v1/chat/completions"; m_modelName = "gpt-4o";
      m_maxTokens = 256; m_temperature = 0.2; m_retryCount = 3; m_timeoutMS = 5000;
      m_tradingSignalPrompt = "You are an expert XAU/USD trading assistant. Analyze market data. Respond EXACTLY format:\nBUY at PRICE SL=X TP=Y Reason: Z\nOR\nSELL at PRICE SL=X TP=Y Reason: Z\nOR\nNO_TRADE Reason: Z\nUse current price if unclear. Be concise.";
      m_marketAnalysisPrompt = "Expert XAU/USD analyst. Analyze data. Provide: 1. Conditions & Levels. 2. Indicator Summary. 3. Potential BUY/SELL Setup (Entry, SL, TP). 4. Sentiment. Max 150 words.";
      m_stopLossValidationPrompt = "Expert risk manager. Evaluate trade position & SL vs market data. Respond EXACTLY one word: VALID, ADJUST_UP, ADJUST_DOWN, or CLOSE. Base on risk principles.";
   }
   ~CGPT4o() override {}
   bool Initialize(string apiKey, int maxTokens, double temperature, int retryCount, int timeoutMS) override {
      m_apiKey = apiKey; m_maxTokens = maxTokens > 0 ? maxTokens : 256;
      m_temperature = MathMax(0.0, MathMin(2.0, temperature)); m_retryCount = MathMax(1, MathMin(10, retryCount));
      m_timeoutMS = MathMax(1000, MathMin(60000, timeoutMS));
      if (m_apiKey == "" && !MQLInfoInteger(MQL_TESTER)) Print("Warning: CGPT4o Sim Mode (No API Key).");
      m_isInitialized = true; Print("CGPT4o Initialized: ",m_modelName); return true;
   }
   string GetTradingSignal(string marketData) override { return MakeAPIRequest(m_tradingSignalPrompt, marketData); }
   string GetMarketAnalysis(string marketData) override { return MakeAPIRequest(m_marketAnalysisPrompt, marketData); }
   string ValidateStopLoss(string tradeData) override {
       string r = MakeAPIRequest(m_stopLossValidationPrompt, tradeData); string u = StringToUpper(StringTrim(r));
       if(u=="VALID"||u=="ADJUST_UP"||u=="ADJUST_DOWN"||u=="CLOSE") return u;
       if(r!="") Print("Warn(OAI): Bad SL validation response '",r,"'. Default VALID."); return "VALID";
   }
   bool ParseSignal(string signal, string &d, double &e, double &sl, double &tp, double iSLp, double mRR) override {
       d = ""; e = 0; sl = 0; tp = 0; if(signal=="" || StringFind(signal,"NO_TRADE")>=0) return false;
       if(StringFind(signal,"BUY")>=0) d="BUY"; else if(StringFind(signal,"SELL")>=0) d="SELL"; else return false;
       double cb=SymbolInfoDouble(Symbol(),SYMBOL_BID), ca=SymbolInfoDouble(Symbol(),SYMBOL_ASK); int dig=(int)SymbolInfoInteger(Symbol(),SYMBOL_DIGITS); if(dig<0)dig=2;
       double pnt=SymbolInfoDouble(Symbol(),SYMBOL_POINT); if(pnt<=0) pnt=0.00001; double pipV=pnt*((dig==2||dig==4)?1.0:10.0); if(Symbol()=="XAUUSD") pipV=pnt*10.0;
       e=(d=="BUY")?ca:cb; int atP=StringFind(signal," at "); if(atP>0){string pS;int sP=atP+4,spP=StringFind(signal," ",sP);if(spP>sP)pS=StringSubstr(signal,sP,spP-sP);double pV=StringToDouble(pS);if(pV>0)e=pV;}
       int slP=StringFind(signal,"SL="); if(slP>0){string pS;int sP=slP+3,spP=StringFind(signal," ",sP);if(spP>sP)pS=StringSubstr(signal,sP,spP-sP);else pS=StringSubstr(signal,sP);sl=StringToDouble(pS);}
       int tpP=StringFind(signal,"TP="); if(tpP>0){string pS;int sP=tpP+3,spP=StringFind(signal," ",sP);if(spP>sP)pS=StringSubstr(signal,sP,spP-sP);else pS=StringSubstr(signal,sP);tp=StringToDouble(pS);}
       if(sl<=0||(d=="BUY"&&sl>=e)||(d=="SELL"&&sl<=e)){sl=(d=="BUY")?Norm(e-iSLp*pipV,dig):Norm(e+iSLp*pipV,dig);/*Print("Warn: Bad SL. Using default: ",DoubleToString(sl,dig));*/}
       if(tp<=0||(d=="BUY"&&tp<=e)||(d=="SELL"&&tp>=e)){if(mRR>0){double rD=MathAbs(e-sl);if(rD>pnt){tp=(d=="BUY")?Norm(e+rD*mRR,dig):Norm(e-rD*mRR,dig);/*Print("Warn: Bad TP. Calc using R:R ",mRR,": ",DoubleToString(tp,dig));*/}else tp=0;}else tp=0;}
       if((d=="BUY"&&(sl>=e||(tp>0&&tp<=e)))||(d=="SELL"&&(sl<=e||(tp>0&&tp>=e)))){Print("Err: Parsed signal invalid SL/TP vs Entry. Discard."); return false;}
       return true;
   }
   string GetName() override { return m_modelName; } string GetModelProvider() override { return "OpenAI"; }
   double Norm(double val, int dg){ return NormalizeDouble(val, dg);} // Helper
};


//--- Anthropic Claude Haiku Model ---
class CClaudeHaiku : public IAIModel {
private:
   string m_apiKey; string m_baseUrl; string m_modelName; int m_maxTokens;
   double m_temperature; int m_retryCount; int m_timeoutMS; bool m_isInitialized;
   string m_tradingSignalPrompt; string m_marketAnalysisPrompt; string m_stopLossValidationPrompt;

   // Function to make an API call to Anthropic
   string MakeAPIRequest(string prompt, string marketData) {
       if (!m_isInitialized) { Print("Error: CClaudeHaiku not initialized."); return ""; }
       if (StringLen(m_apiKey) < 10 || MQLInfoInteger(MQL_TESTER)) {
          if(!MQLInfoInteger(MQL_TESTER) && m_apiKey != "") Print("CClaudeHaiku: Sim Mode (No API Key or Tester).");
          return SimulateResponse(prompt, marketData);
       }
       string escapedSysP = prompt; StringReplace(escapedSysP,"\\","\\\\"); StringReplace(escapedSysP,"\"","\\\"");
       string escapedMktD = marketData; StringReplace(escapedMktD,"\\","\\\\"); StringReplace(escapedMktD,"\"","\\\""); StringReplace(escapedMktD,"\n","\\n");
       string jsonPayload="{"; jsonPayload+="\"model\":\""+m_modelName+"\","; jsonPayload+="\"system\":\""+escapedSysP+"\",";
       jsonPayload+="\"messages\":[{\"role\":\"user\",\"content\":\""+escapedMktD+"\"}],";
       jsonPayload+="\"temperature\":"+DoubleToString(m_temperature,1)+","; jsonPayload+="\"max_tokens\":"+IntegerToString(m_maxTokens)+"}";
       char responseData[]; uchar requestPayloadU[];
       string headers="Content-Type: application/json\r\nx-api-key: "+m_apiKey+"\r\nanthropic-version: 2023-06-01\r\n";
       int timeout = m_timeoutMS; string url = m_baseUrl;
       int payloadLen = StringToUtf8(jsonPayload, requestPayloadU); if(payloadLen<=0){Print("Claude Error: UTF8 conversion failed."); return "";}
       string responseText = ""; int attempt = 0; int httpResultCode = 0;
       while(attempt < m_retryCount && responseText == ""){
           if(attempt>0){ Print("Claude: Retrying API (",attempt+1,"/",m_retryCount,")..."); Sleep(1500); } attempt++;
           ResetLastError(); ArrayResize(responseData, 32768);
           httpResultCode=WebRequest("POST",url,headers,timeout,requestPayloadU,responseData,headers); int lastError=GetLastError();
           if(httpResultCode == 200){
               responseText = CharArrayToString(responseData);
               string generatedText = ExtractContentFromJsonResponse_Anthropic(responseText);
               if(generatedText==""){ Print("Claude API Err: Parse failed (HTTP 200). Attempt ",attempt); Print("Claude Raw: ", StringSubstr(responseText,0,500)); responseText=""; httpResultCode=-1; Sleep(500);}
               else{ /* Print("Claude API OK (Attempt ",attempt,")"); */ return generatedText; }
           }else{
               string eMsg="Claude API Fail! HTTP:"+ (string)httpResultCode; if(lastError!=0) eMsg+=", MQL:"+ (string)lastError; eMsg+=", Att:"+ (string)attempt; Print(eMsg);
               string eBody=CharArrayToString(responseData); if(StringLen(eBody)>0 && StringLen(eBody)<500) Print("Claude Err Body: ",eBody);
               if(lastError==4003||lastError==4004){Print("Claude WebReq Err: URL '",url,"' not allowed."); break;}
               if(httpResultCode==401||httpResultCode==403){Print("Claude API Err: Auth/Forbidden (401/403). Check Key/Perms."); break;}
               if(httpResultCode==400){Print("Claude API Err: Bad Req (400). Check Payload/Model/Version."); break;}
               if(httpResultCode==404){Print("Claude API Err: Not Found (404). Check URL."); break;}
               if(httpResultCode>=400&&httpResultCode<500&&httpResultCode!=429){Print("Claude Client Err ",httpResultCode); break;}
               if(httpResultCode==429){Print("Claude Rate Limit (429). Waiting..."); Sleep(5000+MathRand()%5000);}
               responseText="";
           }
       } Print("Claude API req failed after ",attempt," attempts. HTTP:",httpResultCode); return "";
   }

   // --- Simplified JSON Parser for Anthropic Response ---
   string ExtractContentFromJsonResponse_Anthropic(string jsonResponse) {
       #ifdef JSON_PARSER_SIMPLIFIED
            int contentArrPos=StringFind(jsonResponse,"\"content\""); if(contentArrPos<0){/*Print("ParseErr(Anth): 'content' not found.");*/ return "";}
            int bracketOpenPos=StringFind(jsonResponse,"[",contentArrPos); if(bracketOpenPos<0){/*Print("ParseErr(Anth): '[' not found.");*/ return "";}
            int textKeyPos=StringFind(jsonResponse,"\"text\"",bracketOpenPos); if(textKeyPos<0){/*Print("ParseErr(Anth): 'text' key not found.");*/ return "";}
            int colonPos=StringFind(jsonResponse,":",textKeyPos); if(colonPos<0){/*Print("ParseErr(Anth): ':' not found.");*/ return "";}
            int quoteOpenPos=StringFind(jsonResponse,"\"",colonPos); if(quoteOpenPos<0){/*Print("ParseErr(Anth): Opening quote not found.");*/ return "";}
            int valueStartPos=quoteOpenPos+1; int currentPos=valueStartPos; int valueEndPos=-1;
            while(currentPos<StringLen(jsonResponse)){ if(StringGetCharacter(jsonResponse,currentPos)==(uchar)'"'){if(currentPos>0&&StringGetCharacter(jsonResponse,currentPos-1)==(uchar)'\\'){currentPos++;continue;}else{valueEndPos=currentPos;break;}}currentPos++; }
            if(valueEndPos<0){/*Print("ParseErr(Anth): Closing quote not found.");*/ return "";}
            string extractedValue=StringSubstr(jsonResponse,valueStartPos,valueEndPos-valueStartPos);
            return UnescapeJsonString(extractedValue);
       #else
            Print("Error: JSON_PARSER_SIMPLIFIED not defined but no library implementation provided."); return "";
       #endif
   }

   // Simulated response generator
   string SimulateResponse(string prompt, string marketData) {
       MqlDateTime dt; TimeCurrent(dt); double rV = MathMod(dt.sec*dt.min+dt.hour+GetTickCount()+10,100)/100.0;
       double cb=SymbolInfoDouble(Symbol(),SYMBOL_BID), ca=SymbolInfoDouble(Symbol(),SYMBOL_ASK); if(cb==0||ca==0){cb=1900.0;ca=1900.5;}
       int dg=(int)SymbolInfoInteger(Symbol(),SYMBOL_DIGITS); if(dg<0)dg=2; double pnt=SymbolInfoDouble(Symbol(),SYMBOL_POINT); if(pnt<=0) pnt=0.01;
       double pipV=pnt*((dg==2||dg==4)?1.0:10.0); if(Symbol()=="XAUUSD") pipV=pnt*10.0;
       if (StringFind(prompt,"trading signal")>=0) {
           if (rV < 0.35) { double eP=ca, slP=25+rV*35; double sl=Norm(eP-slP*pipV,dg); double tp=Norm(eP+slP*pipV*2.5,dg); return "BUY at "+DTS(eP,dg)+" SL="+DTS(sl,dg)+" TP="+DTS(tp,dg)+" Reason: Sim Claude bullish.";}
           else if (rV < 0.75) { double eP=cb, slP=25+rV*35; double sl=Norm(eP+slP*pipV,dg); double tp=Norm(eP-slP*pipV*2.5,dg); return "SELL at "+DTS(eP,dg)+" SL="+DTS(sl,dg)+" TP="+DTS(tp,dg)+" Reason: Sim Claude bearish.";}
           else return "NO_TRADE Reason: Sim Claude neutral.";
       } else if (StringFind(prompt,"stop-loss validation")>=0) { if (rV<0.5)return "VALID"; else if(rV<0.75)return "ADJUST_UP"; else if(rV<0.9)return "ADJUST_DOWN"; else return "CLOSE";}
       else if (StringFind(prompt,"market analysis")>=0) { string a="Sim Claude Analysis("+Symbol()+"):\n"; if(rV<0.6){a+="Uptrend. Sup "+DTS(cb*0.985,dg)+". Rec: BUY near "+DTS(ca*0.998,dg)+", SL "+DTS(cb*0.985,dg)+".";} else{a+="Reversal. Res "+DTS(ca*1.015,dg)+". Rec: SELL near "+DTS(cb*1.01,dg)+", SL "+DTS(ca*1.015,dg)+".";} return a;}
       return "SIM_ERROR: Claude simulation failed.";
   }

public:
   CClaudeHaiku() {
       m_isInitialized=false; m_baseUrl="https://api.anthropic.com/v1/messages"; m_modelName="claude-3-haiku-20240307";
       m_maxTokens=256; m_temperature=0.2; m_retryCount=3; m_timeoutMS=5000;
       m_tradingSignalPrompt="Expert XAU/USD trader. Analyze data. Respond ONLY signal line:\nBUY at PRICE SL=X TP=Y Reason: Z\nOR\nSELL at PRICE SL=X TP=Y Reason: Z\nOR\nNO_TRADE Reason: Z\nUse current price. Focus price action/levels.";
       m_marketAnalysisPrompt="Expert XAU/USD analyst. Analyze data. Provide: 1. Conditions & Levels. 2. Price Action/Vol implications. 3. Recommended Strategy (BUY/SELL/Wait) + Entry/SL/TP. 4. Sentiment. Under 150 words.";
       m_stopLossValidationPrompt="Risk Manager. Evaluate trade/SL vs market. Respond EXACTLY: VALID, ADJUST_UP, ADJUST_DOWN, or CLOSE. Base on risk principles.";
   }
   ~CClaudeHaiku() override {}
   bool Initialize(string apiKey, int maxTokens, double temperature, int retryCount, int timeoutMS) override {
       m_apiKey=apiKey; m_maxTokens=maxTokens>0?maxTokens:256; m_temperature=MathMax(0.0,MathMin(1.0,temperature)); // Anthropic Temp 0-1
       m_retryCount=MathMax(1,MathMin(10,retryCount)); m_timeoutMS=MathMax(1000,MathMin(60000,timeoutMS));
       if(m_apiKey=="" && !MQLInfoInteger(MQL_TESTER)) Print("Warn: Claude Sim Mode (No API Key).");
       m_isInitialized=true; Print("CClaudeHaiku Initialized: ",m_modelName); return true;
   }
   string GetTradingSignal(string md) override { return MakeAPIRequest(m_tradingSignalPrompt, md); }
   string GetMarketAnalysis(string md) override { return MakeAPIRequest(m_marketAnalysisPrompt, md); }
   string ValidateStopLoss(string td) override {
       string r=MakeAPIRequest(m_stopLossValidationPrompt, td); string u=StringToUpper(StringTrim(r));
       if(u=="VALID"||u=="ADJUST_UP"||u=="ADJUST_DOWN"||u=="CLOSE") return u;
       if(r!="") Print("Warn(Anth): Bad SL valid response '",r,"'. Default VALID."); return "VALID";
   }
   // Use shared parser via helper instance, assuming format consistency prompted correctly
   bool ParseSignal(string s, string &d, double &e, double &sl, double &tp, double iSLp, double mRR) override {
      CGPT4o helper; return helper.ParseSignal(s,d,e,sl,tp,iSLp,mRR);
   }
   string GetName() override { return m_modelName; } string GetModelProvider() override { return "Anthropic"; }
   // Helpers for simulation code
   string DTS(double v, int dg){ return DoubleToString(v,dg);} double Norm(double v, int dg){return NormalizeDouble(v,dg);}
};


//--- Main AI Integration Class (Orchestrator) ---
class CAIIntegration {
private: IAIModel* m_aiModel; bool m_isInitialized; int m_errorCount;
   datetime m_lastRequestTime; int m_requestCounter; int m_maxRequestsPerMinute;
   double m_initialSLPips; double m_minProfitToRisk;
public:
   CAIIntegration() { m_aiModel=NULL; m_isInitialized=false; m_errorCount=0; m_lastRequestTime=0; m_requestCounter=0; m_maxRequestsPerMinute=60; m_initialSLPips=50.0; m_minProfitToRisk=1.5; }
   ~CAIIntegration() { if (m_aiModel != NULL) { delete m_aiModel; m_aiModel = NULL; } }
   bool Initialize(string modelName, string apiKey, int maxTokens, double temperature, int retryCount, int timeoutMS, double initialSLPips, double minProfitToRisk) {
       m_initialSLPips=initialSLPips>0?initialSLPips:50.0; m_minProfitToRisk=minProfitToRisk>0?minProfitToRisk:0;
       if (m_aiModel!=NULL){delete m_aiModel;m_aiModel=NULL;}
       if(StringFind(modelName,"GPT",0)>=0||StringFind(modelName,"gpt",0)>=0){m_aiModel=new CGPT4o(); if(modelName=="GPT-4o-Plus")m_maxRequestsPerMinute=100; else if(modelName=="GPT-4o-Mini")m_maxRequestsPerMinute=180; else m_maxRequestsPerMinute=60;}
       else if(StringFind(modelName,"o1-Mini",0)>=0||StringFind(modelName,"claude",0)>=0){m_aiModel=new CClaudeHaiku(); m_maxRequestsPerMinute=90;}
       else{Print("Err: Unsupported AI model '",modelName,"'"); return false;}
       if(m_aiModel==NULL||!m_aiModel.Initialize(apiKey,maxTokens,temperature,retryCount,timeoutMS)){Print("Err: Failed AI model init."); if(m_aiModel!=NULL)delete m_aiModel;m_aiModel=NULL;return false;}
       m_isInitialized=true; m_errorCount=0; m_lastRequestTime=0; m_requestCounter=0; Print("AI Init OK: ",m_aiModel.GetName()," RPM Limit:",m_maxRequestsPerMinute); return true;
   }
   bool CheckRateLimit() { if(!m_isInitialized)return false; datetime ct=TimeCurrent(); if(ct-m_lastRequestTime>=60){m_lastRequestTime=ct;m_requestCounter=0;return true;} if(m_requestCounter>=m_maxRequestsPerMinute){/*Print("Rate limit hit.");*/ return false;} return true;}
   void IncrementRequestCounter() { if(!m_isInitialized)return; if(m_requestCounter==0){m_lastRequestTime=TimeCurrent();} m_requestCounter++;}
   string GetTradingSignal(string md) { if(!m_isInitialized||m_aiModel==NULL){Print("Err: AI !Init (GetSignal)");m_errorCount++;return "";} if(!CheckRateLimit())return ""; IncrementRequestCounter(); string s=m_aiModel.GetTradingSignal(md); if(s==""){} return s;}
   string GetMarketAnalysis(string md) { if(!m_isInitialized||m_aiModel==NULL){Print("Err: AI !Init (GetAnalysis)");m_errorCount++;return "";} if(!CheckRateLimit())return ""; IncrementRequestCounter(); string a=m_aiModel.GetMarketAnalysis(md); if(a==""){} return a;}
   string ValidateStopLoss(string td) { if(!m_isInitialized||m_aiModel==NULL){Print("Err: AI !Init (ValidateSL)");m_errorCount++;return"VALID";} if(!CheckRateLimit()){/*Print("SL valid rate limit.");*/ return"VALID";} IncrementRequestCounter(); string v=m_aiModel.ValidateStopLoss(td); return v;}
   bool ParseSignal(string s, string &d, double &e, double &sl, double &tp){ if(!m_isInitialized||m_aiModel==NULL){Print("Err: AI !Init (ParseSignal)");return false;} return m_aiModel.ParseSignal(s,d,e,sl,tp,m_initialSLPips,m_minProfitToRisk);}
   int GetErrorCount() const { return m_errorCount; } void IncrementErrorCount(){if(m_isInitialized)m_errorCount++;} void ResetErrorCount(){m_errorCount=0;}
   string GetActiveModelName() const { return(m_aiModel!=NULL)?m_aiModel.GetName():"None"; } string GetActiveModelProvider() const { return(m_aiModel!=NULL)?m_aiModel.GetModelProvider():"None"; }
};
//+------------------------------------------------------------------+

// ```

// ---