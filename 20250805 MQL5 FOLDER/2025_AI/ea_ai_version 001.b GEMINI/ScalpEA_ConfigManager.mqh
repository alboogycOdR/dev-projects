
// **3. Configuration Manager Module**

// *   **Path:** `...\MQL5\Include\ScalpEA\ScalpEA_ConfigManager.mqh`
// *   **Filename:** `ScalpEA_ConfigManager.mqh`

// ```mql5
//+------------------------------------------------------------------+
//| ScalpEA_ConfigManager.mqh                                        |
//| Configuration Manager Module for Scalp EA                        |
//| Note: Used by BacktestManager & potentially external tools.      |
//| Main EA uses 'input' parameters primarily.                       |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025"
#property link      "https://www.example.com"
#property strict

// Include required libraries
#include <Arrays\ArrayString.mqh>
#include <Files\File.mqh> // Use CFile for easier file handling
#include <Object.mqh>   // For CString used in profile list retrieval potentially

//--- Configuration Manager Class
class CConfigManager {
private:
   // File paths
   string   m_configFile;        // Path to the main configuration file
   string   m_profilesPath;      // Path to the directory storing configuration profiles
   string   m_currentProfile;    // Name of the current active profile

   // Configuration parameters - AI Configuration
   string   m_aiModel;           // AI Model (GPT-4o-Plus, GPT-4o-Mini, GPT-4o-Free, o1-Mini / claude-3-haiku)
   string   m_apiKey;            // API Key (encrypted)
   int      m_maxTokens;         // Max response tokens
   double   m_temperature;       // Temperature (0.0-1.0 for Anthropic, 0.0-2.0 for OpenAI)
   int      m_retryCount;        // API retry count
   int      m_apiTimeoutMS;      // API timeout in milliseconds

   // Configuration parameters - Trading Configuration
   double   m_riskPercent;       // Risk per trade (%)
   int      m_maxTrades;         // Max concurrent trades
   string   m_mode;              // Operation Mode (Full AI, Hybrid, Manual)
   bool     m_useMarketOrders;   // Use market orders (false = pending orders)
   int      m_pendingOrderDistance; // Distance for pending orders (points)
   int      m_maxSpread;         // Maximum allowed spread (points)
   bool     m_fridayExit;        // Close all positions on Friday
   int      m_fridayExitHour;    // Hour to exit on Friday (server time)

   // Configuration parameters - Risk Management
   double   m_maxDailyLoss;      // Maximum daily loss (%)
   double   m_minProfitToRisk;   // Minimum profit-to-risk ratio
   double   m_initialSLPips;     // Initial stop-loss (pips)
   double   m_trailingSLPips;    // Trailing stop-loss (pips)
   bool     m_useEmergencyShutdown; // Emergency shutdown on error threshold
   int      m_errorThreshold;    // Error threshold for emergency shutdown

   // Configuration parameters - Data Collection
   int      m_dataBars;          // Number of bars for analysis
   ENUM_TIMEFRAMES m_dataTimeframe; // Using ENUM_TIMEFRAMES for type safety
   bool     m_includeIndicators; // Include indicators in data
   bool     m_includeOrderBook;  // Include order book in data (if available)

   // Encryption helpers (simple XOR - **NOT SECURE FOR PRODUCTION**)
   string EncryptString(string value) {
      uchar src[], dst[]; int len = StringToCharArray(value, src); if(len == 0) return ""; ArrayResize(dst, len);
      uchar key = 0x55; for (int i=0; i<len; i++) dst[i] = src[i] ^ key;
      string result = ""; for (int i=0; i<len; i++) result += StringFormat("%02X", dst[i]); return result;
   }
   string DecryptString(string encryptedValue) {
      int sLen=StringLen(encryptedValue); if(sLen % 2 != 0 || sLen == 0) return ""; int len=sLen/2;
      uchar src[]; uchar dst[]; ArrayResize(src,len); ArrayResize(dst,len);
      for (int i=0; i<len; i++) { string bs=StringSubstr(encryptedValue,i*2,2); ushort bv=StringToInteger(bs,16); if(bv>255) return ""; src[i]=(uchar)bv; }
      uchar key=0x55; for(int i=0;i<len;i++) dst[i]=src[i]^key; return CharArrayToString(dst,0,len);
   }

   // Validate configuration values
   bool ValidateConfig() {
      bool valid=true;
      if(m_aiModel!="GPT-4o-Plus"&&m_aiModel!="GPT-4o-Mini"&&m_aiModel!="GPT-4o-Free"&&m_aiModel!="gpt-4o"&&m_aiModel!="o1-Mini"&&m_aiModel!="claude-3-haiku-20240307"){Print("Val Err: Bad AI model: ",m_aiModel);valid=false;}
      if(m_maxTokens<=0||m_maxTokens>4096){Print("Val Err: Bad max tokens(1-4096): ",m_maxTokens);valid=false;}
      if(m_temperature<0.0||m_temperature>2.0){Print("Val Err: Bad temperature(0.0-2.0): ",m_temperature);valid=false;}
      if(m_retryCount<=0||m_retryCount>10){Print("Val Err: Bad retry count(1-10): ",m_retryCount);valid=false;}
      if(m_apiTimeoutMS<=500||m_apiTimeoutMS>60000){Print("Val Err: Bad API timeout(500-60000ms): ",m_apiTimeoutMS);valid=false;}
      if(m_riskPercent<=0.0||m_riskPercent>20.0){Print("Val Err: Bad risk percent(0.1-20.0): ",m_riskPercent);valid=false;}
      if(m_maxTrades<=0||m_maxTrades>20){Print("Val Err: Bad max trades(1-20): ",m_maxTrades);valid=false;}
      if(m_mode!="Full AI"&&m_mode!="Hybrid"&&m_mode!="Manual"){Print("Val Err: Bad operation mode: ",m_mode);valid=false;}
      if(m_pendingOrderDistance<=0||m_pendingOrderDistance>1000){Print("Val Err: Bad pending distance(1-1000pts): ",m_pendingOrderDistance);valid=false;}
      if(m_maxSpread<0||m_maxSpread>1000){Print("Val Err: Bad max spread(0=off, 1-1000pts): ",m_maxSpread);valid=false;} // Allow 0
      if(m_fridayExitHour<0||m_fridayExitHour>23){Print("Val Err: Bad Friday exit hour(0-23): ",m_fridayExitHour);valid=false;}
      if(m_maxDailyLoss<0.0||m_maxDailyLoss>50.0){Print("Val Err: Bad max daily loss(0=off, 0.1-50.0%): ",m_maxDailyLoss);valid=false;} // Allow 0
      if(m_minProfitToRisk<=0.0||m_minProfitToRisk>10.0){Print("Val Err: Bad min R:R(0.1-10.0): ",m_minProfitToRisk);valid=false;}
      if(m_initialSLPips<=1.0||m_initialSLPips>1000.0){Print("Val Err: Bad initial SL(1-1000pips): ",m_initialSLPips);valid=false;}
      if(m_trailingSLPips<0.0||m_trailingSLPips>1000.0){Print("Val Err: Bad trailing SL(0=off, 1-1000pips): ",m_trailingSLPips);valid=false;} // Allow 0
      if(m_errorThreshold<=0||m_errorThreshold>100){Print("Val Err: Bad error threshold(1-100): ",m_errorThreshold);valid=false;}
      if(m_dataBars<=5||m_dataBars>2000){Print("Val Err: Bad data bars(5-2000): ",m_dataBars);valid=false;}
      ENUM_TIMEFRAMES vTFs[]={PERIOD_M1,PERIOD_M5,PERIOD_M15,PERIOD_M30,PERIOD_H1,PERIOD_H4,PERIOD_D1,PERIOD_W1,PERIOD_MN1}; bool tfV=false; for(int i=0;i<ArraySize(vTFs);i++){if(m_dataTimeframe==vTFs[i]){tfV=true;break;}} if(!tfV){Print("Val Err: Bad data timeframe: ",EnumToString(m_dataTimeframe));valid=false;}
      return valid;
   }

   // Set default values
   void SetDefaults() {
      m_aiModel="GPT-4o-Plus"; m_apiKey=""; m_maxTokens=256; m_temperature=0.2; m_retryCount=3; m_apiTimeoutMS=5000;
      m_riskPercent=1.0; m_maxTrades=3; m_mode="Full AI"; m_useMarketOrders=true; m_pendingOrderDistance=10; m_maxSpread=30; m_fridayExit=true; m_fridayExitHour=20;
      m_maxDailyLoss=5.0; m_minProfitToRisk=1.5; m_initialSLPips=50.0; m_trailingSLPips=30.0; m_useEmergencyShutdown=true; m_errorThreshold=10;
      m_dataBars=50; m_dataTimeframe=PERIOD_H1; m_includeIndicators=true; m_includeOrderBook=false;
      m_currentProfile = "Default"; // Ensure profile is reset too
   }

   // Initialize file paths
   void InitializePaths() {
      string dPath=TerminalInfoString(TERMINAL_DATA_PATH); m_configFile=dPath+"\\MQL5\\Files\\ScalpEA_Config.ini"; m_profilesPath=dPath+"\\MQL5\\Files\\ScalpEA_Profiles\\";
      if(!FolderCreate(m_profilesPath,FILE_COMMON)){}// Print("Warn: Profile dir create fail: ",GetLastError());}
   }

   // Helper to write config values
   void WriteConfigValue(CFile &f,string k,string v){f.WriteString(k+"="+v+"\r\n");}
   void WriteConfigValue(CFile &f,string k,int v){WriteConfigValue(f,k,IntegerToString(v));}
   void WriteConfigValue(CFile &f,string k,double v,int d=2){WriteConfigValue(f,k,DoubleToString(v,d));}
   void WriteConfigValue(CFile &f,string k,bool v){WriteConfigValue(f,k,v?"true":"false");}
   void WriteConfigValue(CFile &f,string k,ENUM_TIMEFRAMES v){WriteConfigValue(f,k,(string)v);} // Save enum as int string

public:
   CConfigManager() { InitializePaths(); SetDefaults(); }
   ~CConfigManager() {}

   // Initialize by loading specified profile or default
   bool Initialize(string initialProfile = "Default") {
       m_currentProfile = (initialProfile != "") ? initialProfile : "Default";
       if (!LoadProfile(m_currentProfile)) {
           Print("Config Init: Failed loading '", m_currentProfile, "'. Using defaults & saving.");
           SetDefaults();
           m_currentProfile = "Default"; // Force profile name back to Default
           SaveProfile(m_currentProfile); // Save defaults AS the "Default" profile
           // SaveConfig(); // Redundant if SaveProfile updates main config? Yes.
           return ValidateConfig(); // Validate the defaults
       }
       return true; // Loaded profile passed validation inside LoadProfile
   }

   // Save current settings to main config file
   bool SaveConfig() {
      CFile file; if(!file.Open(m_configFile,FILE_WRITE|FILE_TXT|FILE_ANSI,FILE_COMMON)){Print("Err: SaveConfig open fail: ",GetLastError());return false;}
      file.WriteString("[General]\r\n"); WriteConfigValue(file,"CurrentProfile",m_currentProfile); file.WriteString("\r\n");
      file.WriteString("[AI_Configuration]\r\n"); WriteConfigValue(file,"AIModel",m_aiModel); WriteConfigValue(file,"APIKey",(m_apiKey!=""?EncryptString(m_apiKey):"")); WriteConfigValue(file,"MaxTokens",m_maxTokens); WriteConfigValue(file,"Temperature",m_temperature,2); WriteConfigValue(file,"RetryCount",m_retryCount); WriteConfigValue(file,"APITimeoutMS",m_apiTimeoutMS); file.WriteString("\r\n");
      file.WriteString("[Trading_Configuration]\r\n"); WriteConfigValue(file,"RiskPercent",m_riskPercent,2); WriteConfigValue(file,"MaxTrades",m_maxTrades); WriteConfigValue(file,"Mode",m_mode); WriteConfigValue(file,"UseMarketOrders",m_useMarketOrders); WriteConfigValue(file,"PendingOrderDistance",m_pendingOrderDistance); WriteConfigValue(file,"MaxSpread",m_maxSpread); WriteConfigValue(file,"FridayExit",m_fridayExit); WriteConfigValue(file,"FridayExitHour",m_fridayExitHour); file.WriteString("\r\n");
      file.WriteString("[Risk_Management]\r\n"); WriteConfigValue(file,"MaxDailyLoss",m_maxDailyLoss,2); WriteConfigValue(file,"MinProfitToRisk",m_minProfitToRisk,2); WriteConfigValue(file,"InitialSLPips",m_initialSLPips,1); WriteConfigValue(file,"TrailingSLPips",m_trailingSLPips,1); WriteConfigValue(file,"UseEmergencyShutdown",m_useEmergencyShutdown); WriteConfigValue(file,"ErrorThreshold",m_errorThreshold); file.WriteString("\r\n");
      file.WriteString("[Data_Collection]\r\n"); WriteConfigValue(file,"DataBars",m_dataBars); WriteConfigValue(file,"DataTimeframe",m_dataTimeframe); WriteConfigValue(file,"IncludeIndicators",m_includeIndicators); WriteConfigValue(file,"IncludeOrderBook",m_includeOrderBook); file.WriteString("\r\n");
      file.Close(); /*Print("Main config saved: ",m_configFile);*/ return true;
   }

   // Load main config file (primarily gets CurrentProfile then loads it)
   bool LoadConfig() {
      CFile file; if(!file.Open(m_configFile,FILE_READ|FILE_TXT|FILE_ANSI,FILE_COMMON)){/*Print("Main cfg missing: ",m_configFile);*/ return LoadProfile("Default");} // Load Default if main is missing
      string loadedProfile = ""; string currentSection = "";
      while(!file.IsEnding()){ string line = StringTrim(file.ReadString()); if(line==""||StringGetChar(line,0)=='#'||StringGetChar(line,0)==';')continue; if(StringGetChar(line,0)=='['&&StringGetChar(line,StringLen(line)-1)==']'){currentSection=StringSubstr(line,1,StringLen(line)-2);continue;} int eqPos=StringFind(line,"="); if(eqPos>0){string k=StringSubstr(line,0,eqPos);string v=StringSubstr(line,eqPos+1); if(currentSection=="General"&&k=="CurrentProfile"){loadedProfile=v;break;}}} file.Close(); // Stop after finding profile
      return LoadProfile(loadedProfile != "" ? loadedProfile : "Default"); // Load profile found or Default
   }

   // Parse single config value line
   void ParseConfigValue(string section, string key, string value) {
       value=StringTrim(value); // Trim whitespace
       if(section=="General"){if(key=="CurrentProfile")m_currentProfile=value;}
       else if(section=="AI_Configuration"){ if(key=="AIModel")m_aiModel=value; else if(key=="APIKey")m_apiKey=(value!=""?DecryptString(value):""); else if(key=="MaxTokens")m_maxTokens=(int)StringToInteger(value); else if(key=="Temperature")m_temperature=StringToDouble(value); else if(key=="RetryCount")m_retryCount=(int)StringToInteger(value); else if(key=="APITimeoutMS")m_apiTimeoutMS=(int)StringToInteger(value); }
       else if(section=="Trading_Configuration"){ if(key=="RiskPercent")m_riskPercent=StringToDouble(value); else if(key=="MaxTrades")m_maxTrades=(int)StringToInteger(value); else if(key=="Mode")m_mode=value; else if(key=="UseMarketOrders")m_useMarketOrders=(StringCompare(value,"true",false)==0); else if(key=="PendingOrderDistance")m_pendingOrderDistance=(int)StringToInteger(value); else if(key=="MaxSpread")m_maxSpread=(int)StringToInteger(value); else if(key=="FridayExit")m_fridayExit=(StringCompare(value,"true",false)==0); else if(key=="FridayExitHour")m_fridayExitHour=(int)StringToInteger(value); }
       else if(section=="Risk_Management"){ if(key=="MaxDailyLoss")m_maxDailyLoss=StringToDouble(value); else if(key=="MinProfitToRisk")m_minProfitToRisk=StringToDouble(value); else if(key=="InitialSLPips")m_initialSLPips=StringToDouble(value); else if(key=="TrailingSLPips")m_trailingSLPips=StringToDouble(value); else if(key=="UseEmergencyShutdown")m_useEmergencyShutdown=(StringCompare(value,"true",false)==0); else if(key=="ErrorThreshold")m_errorThreshold=(int)StringToInteger(value); }
       else if(section=="Data_Collection"){ if(key=="DataBars")m_dataBars=(int)StringToInteger(value); else if(key=="DataTimeframe")m_dataTimeframe=(ENUM_TIMEFRAMES)StringToInteger(value); else if(key=="IncludeIndicators")m_includeIndicators=(StringCompare(value,"true",false)==0); else if(key=="IncludeOrderBook")m_includeOrderBook=(StringCompare(value,"true",false)==0); }
   }

   // Save current settings as named profile
   bool SaveProfile(string profileName) {
       if(profileName==""){Print("Err: SaveProfile needs name."); return false;} profileName=StringTrim(profileName);
       string profileFile = m_profilesPath + profileName + ".ini";
       CFile file; if(!file.Open(profileFile, FILE_WRITE|FILE_TXT|FILE_ANSI, FILE_COMMON)){Print("Err: SaveProfile open fail '",profileFile,"': ",GetLastError()); return false;}
       // Write all sections similar to SaveConfig
       file.WriteString("[AI_Configuration]\r\n"); WriteConfigValue(file,"AIModel",m_aiModel); WriteConfigValue(file,"APIKey",(m_apiKey!=""?EncryptString(m_apiKey):"")); WriteConfigValue(file,"MaxTokens",m_maxTokens); WriteConfigValue(file,"Temperature",m_temperature,2); WriteConfigValue(file,"RetryCount",m_retryCount); WriteConfigValue(file,"APITimeoutMS",m_apiTimeoutMS); file.WriteString("\r\n");
       file.WriteString("[Trading_Configuration]\r\n"); WriteConfigValue(file,"RiskPercent",m_riskPercent,2); WriteConfigValue(file,"MaxTrades",m_maxTrades); WriteConfigValue(file,"Mode",m_mode); WriteConfigValue(file,"UseMarketOrders",m_useMarketOrders); WriteConfigValue(file,"PendingOrderDistance",m_pendingOrderDistance); WriteConfigValue(file,"MaxSpread",m_maxSpread); WriteConfigValue(file,"FridayExit",m_fridayExit); WriteConfigValue(file,"FridayExitHour",m_fridayExitHour); file.WriteString("\r\n");
       file.WriteString("[Risk_Management]\r\n"); WriteConfigValue(file,"MaxDailyLoss",m_maxDailyLoss,2); WriteConfigValue(file,"MinProfitToRisk",m_minProfitToRisk,2); WriteConfigValue(file,"InitialSLPips",m_initialSLPips,1); WriteConfigValue(file,"TrailingSLPips",m_trailingSLPips,1); WriteConfigValue(file,"UseEmergencyShutdown",m_useEmergencyShutdown); WriteConfigValue(file,"ErrorThreshold",m_errorThreshold); file.WriteString("\r\n");
       file.WriteString("[Data_Collection]\r\n"); WriteConfigValue(file,"DataBars",m_dataBars); WriteConfigValue(file,"DataTimeframe",m_dataTimeframe); WriteConfigValue(file,"IncludeIndicators",m_includeIndicators); WriteConfigValue(file,"IncludeOrderBook",m_includeOrderBook); file.WriteString("\r\n");
       file.Close();
       // If saving the currently active profile, also update main config file pointer
       if (profileName == m_currentProfile) SaveConfig();
       Print("Profile '",profileName,"' saved."); return true;
   }

   // Load settings from a named profile
   bool LoadProfile(string profileName) {
       if(profileName==""){Print("Err: LoadProfile needs name.");return false;} profileName=StringTrim(profileName);
       string profileFile = m_profilesPath + profileName + ".ini";
       CFile file; if(!file.Open(profileFile,FILE_READ|FILE_TXT|FILE_ANSI,FILE_COMMON)){Print("Warn: LoadProfile '",profileName,"' not found (Err:",GetLastError(),"). Loading Defaults."); SetDefaults(); m_currentProfile="Default"; SaveConfig(); return true;} // Load defaults if profile missing
       SetDefaults(); // Apply defaults first, then override from file
       string currentSection=""; while(!file.IsEnding()){string line=StringTrim(file.ReadString()); if(line==""||StringGetChar(line,0)=='#'||StringGetChar(line,0)==';')continue; if(StringGetChar(line,0)=='['&&StringGetChar(line,StringLen(line)-1)==']'){currentSection=StringSubstr(line,1,StringLen(line)-2);continue;} int eqPos=StringFind(line,"="); if(eqPos>0){string k=StringSubstr(line,0,eqPos); string v=StringSubstr(line,eqPos+1); ParseConfigValue(currentSection,k,v);}} file.Close();
       if(!ValidateConfig()){ Print("Error: Profile '",profileName,"' failed validation after loading."); SetDefaults(); m_currentProfile="Default"; SaveConfig(); return false;} // Revert to defaults on validation failure
       m_currentProfile = profileName; SaveConfig(); // Set as current profile and save main config
       Print("Profile '",profileName,"' loaded."); return true;
   }

   // Get list of available profile filenames (without extension)
   void GetProfileList(CArrayString &profileList) {
      profileList.Clear(); string fName; ResetLastError(); long sHandle=FileFindFirst(m_profilesPath+"*.ini",fName,FILE_COMMON);
      if(sHandle!=INVALID_HANDLE){do{if(StringLen(fName)>4)profileList.Add(StringSubstr(fName,0,StringLen(fName)-4));}while(FileFindNext(sHandle,fName)); FileFindClose(sHandle);}
      bool defFound=false; for(int i=0;i<profileList.Total();i++){if(profileList.At(i)=="Default"){defFound=true;break;}} if(!defFound)profileList.Add("Default"); // Ensure Default is present
      profileList.Sort();
   }

   // Delete a profile file
   bool DeleteProfile(string profileName) {
      if(profileName=="Default"){Print("Cannot delete 'Default' profile."); return false;} if(profileName==""){Print("Err: DeleteProfile needs name."); return false;} profileName=StringTrim(profileName);
      string profileFile = m_profilesPath + profileName + ".ini";
      CFile file; if(!file.Open(profileFile,FILE_READ,FILE_COMMON)){Print("Profile '",profileName,"' not found for deletion."); return false;} file.Close(); // Check existence
      if(!FileDelete(profileFile,FILE_COMMON)){Print("Failed deleting '",profileName,"'. Err:",GetLastError()); return false;}
      if(m_currentProfile==profileName){Print("Deleted active profile '",profileName,"'. Switching to Default."); LoadProfile("Default");} // Switch if current deleted
      Print("Profile '",profileName,"' deleted."); return true;
   }

   // --- Getters ---
   string   GetAIModel() const { return m_aiModel; } string   GetAPIKey() const { return m_apiKey; }
   int      GetMaxTokens() const { return m_maxTokens; } double   GetTemperature() const { return m_temperature; }
   int      GetRetryCount() const { return m_retryCount; } int      GetAPITimeoutMS() const { return m_apiTimeoutMS; }
   double   GetRiskPercent() const { return m_riskPercent; } int      GetMaxTrades() const { return m_maxTrades; }
   string   GetMode() const { return m_mode; } bool     GetUseMarketOrders() const { return m_useMarketOrders; }
   int      GetPendingOrderDistance() const { return m_pendingOrderDistance; } int      GetMaxSpread() const { return m_maxSpread; }
   bool     GetFridayExit() const { return m_fridayExit; } int      GetFridayExitHour() const { return m_fridayExitHour; }
   double   GetMaxDailyLoss() const { return m_maxDailyLoss; } double   GetMinProfitToRisk() const { return m_minProfitToRisk; }
   double   GetInitialSLPips() const { return m_initialSLPips; } double   GetTrailingSLPips() const { return m_trailingSLPips; }
   bool     GetUseEmergencyShutdown() const { return m_useEmergencyShutdown; } int      GetErrorThreshold() const { return m_errorThreshold; }
   int      GetDataBars() const { return m_dataBars; } ENUM_TIMEFRAMES GetDataTimeframe() const { return m_dataTimeframe; }
   bool     GetIncludeIndicators() const { return m_includeIndicators; } bool     GetIncludeOrderBook() const { return m_includeOrderBook; }
   string   GetCurrentProfile() const { return m_currentProfile; }

   // --- Setters (Use with caution - modify internal state directly) ---
   // Example: void SetRiskPercent(double r){ if(r>0 && r<=20) m_riskPercent=r; } // Requires re-validation and saving potentially
   void SetCurrentProfile(string name) { LoadProfile(name); } // Loads the profile if valid

};
//+------------------------------------------------------------------+