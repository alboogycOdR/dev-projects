//+------------------------------------------------------------------+
//|                                                      logging.mqh |
//|                                     Copyright 2023, Omega Joctan |
//|                        https://www.mql5.com/en/users/omegajoctan |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Omegafx"
#property link      "https://www.mql5.com/en/users/omegajoctan/seller"

// Cache max size (number of files)
#define MAX_CACHE_SIZE  10000
// Max file size in megabytes
#define MAX_FILE_SIZEMB 10

//+------------------------------------------------------------------+
//|   Logger                                                         |
//+------------------------------------------------------------------+

class CLogging
  {
private:
   string            m_folder;             // Name of project and log file
   string            logCache[MAX_CACHE_SIZE];  // Cache max size
   int               sizeCache;                 // Cache counter
   int               cacheTimeLimit;            // Caching time
   datetime          cacheTime;                 // Time of cache last flush into file
   int               handleFile;                // Handle of log file
   void              writeLog(string log_msg);  // Writing message into log or file, and flushing cache

//--- Generating message

   void              write(string msg, string category, color colorOfMsg, string file = "", int line = 0); // Generating message
   
public:

   void              CLogging(void) {cacheTimeLimit = 0; cacheTime = 0; sizeCache = 0;}; // Constructor
   void             ~CLogging(void) { this.deinit(); };          // Destructor

   void              Config(string file_name, int cache_time_limit = 0);         
   
   bool              init();                    // Initialization, open file for writing
   void              deinit();                  // Deinitialization, closing file
   
   void              info(const string info, const string file, const uint line=0) { this.write(info, "INFO", clrBlue, file, (int)line); }
   void              error(string error, const string file, const uint line=0) { this.write(error, "ERROR", clrRed, file, (int)line); }
   void              warning(string warning, const string file, const uint line=0) { this.write(warning, "WARNING", clrYellow, file, (int)line); }
   
   void              flush(void);               // Flushing cache into file
  };
//+------------------------------------------------------------------+
//|  Settings                                                        |
//+------------------------------------------------------------------+
void CLogging::Config(string folder, int cache_time_limit = 0)
  {
   m_folder = folder;                // File name
   cacheTimeLimit = cache_time_limit; // Caching time
  }
//+------------------------------------------------------------------+
//|  Initialization                                                  |
//+------------------------------------------------------------------+
bool CLogging::init(void)
  {
   if (m_folder=="")
      {
         printf("func=%s line=%d, failed to initialize the logger. call the 'Config()' function first and give it a non-empty folder name",__FUNCTION__,__LINE__);
         return false;
      }
      
//---

   string path;
   MqlDateTime date;
   int i = 0;
   TimeToStruct(TimeCurrent(), date);                          // Get current time
   StringConcatenate(path, m_folder, "\\log\\log__",
                     date.year, date.mon, date.day);           // Generate path and file name
   
   handleFile = FileOpen(path + ".txt", FILE_WRITE| FILE_SHARE_WRITE | FILE_READ |
                         FILE_UNICODE | FILE_TXT | FILE_SHARE_READ); // Open or create file
                            
   if (handleFile==INVALID_HANDLE)
     {
       printf("func=%s line=%d, failed to open a file={%s} for logging. Error = %d",__FUNCTION__,__LINE__,(path+".txt"),GetLastError());
       return false;
     }
   
   while(FileSize(handleFile) > (MAX_FILE_SIZEMB * 1000000))   // Check file size
     {
      // Open or create new log file
      i++;
      FileClose(handleFile);
      handleFile = FileOpen(path + "_" + (string)i + ".txt", FILE_WRITE | FILE_READ | FILE_UNICODE | FILE_TXT | FILE_SHARE_READ);
     }

   FileSeek(handleFile, 0, SEEK_END);                          // Set pointer to the end of file
   return true;
  }
//+------------------------------------------------------------------+
//|   Deinitialization                                               |
//+------------------------------------------------------------------+
void CLogging::deinit(void)
  {
   FileClose(handleFile); // Close file
  }
//+------------------------------------------------------------------+
//|   Write message into file of cache                               |
//+------------------------------------------------------------------+
void CLogging::writeLog(string log_msg)
  {
   if(cacheTimeLimit != 0) // Check if cache is enabled
     {
      if((sizeCache < MAX_CACHE_SIZE - 1 && TimeCurrent() - cacheTime < cacheTimeLimit)
         || sizeCache == 0) // Check if cache time is out or if cache limit is reached
        {
         // Write message into cache
         logCache[sizeCache++] = log_msg;
        }
      else
        {
         // Write message into cache and flush cache into file
         logCache[sizeCache++] = log_msg;
         flush();
        }

     }
   else
     {
      // Cache is disabled, immediately write into file
      FileWrite(handleFile, log_msg);
     }
   if(FileTell(handleFile) > (MAX_FILE_SIZEMB * 1000000)) // Check current file size
     {
      // File size exceeds allowed limit, close current file and open new one
      deinit();
      init();
     }
  }
//+------------------------------------------------------------------+
//|    Generate message and write into log                           |
//+------------------------------------------------------------------+
void CLogging::write(string msg, string category, color colorOfMsg, string file = "", int line = 0)
  {
   string msg_log;
   int red, green, blue;
   red = (colorOfMsg  & Red);          // Select red color from constant
   green = (colorOfMsg  & 0x00FF00) >> 8; // Select green color from constant
   blue = (colorOfMsg  & Blue) >> 16;  // Select blue color from constant
// Check if file or line are passed, generate line and call method of writing message
   if(file != "" && line != 0)
     {
      StringConcatenate(msg_log, category, ":|:", red, ",", green, ",", blue,
                        ":|:", TimeToString(TimeCurrent(), TIME_SECONDS), "    ",
                        "file: ", file, "   line: ", line, "   ", msg);
     }
   else
     {
      StringConcatenate(msg_log, category, ":|:", red, ",", green, ",", blue,
                        ":|:", TimeToString(TimeCurrent(), TIME_SECONDS), "    ", msg);
     }
   writeLog(msg_log);
  }
//+------------------------------------------------------------------+
//|    Flush cache into file                                         |
//+------------------------------------------------------------------+
void CLogging::flush(void)
  {
   for(int i = 0; i < sizeCache; i++) // In loop write all messages into file
     {
      FileWrite(handleFile, logCache[i]);
     }
   sizeCache = 0;                // Reset cache counter
   cacheTime = TimeCurrent();    // Set time of reseting cache
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
