//+------------------------------------------------------------------+
//|                                                SA_Server_600.mq4 |
//|                                            Copyright © 2013, VGC |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright © 2013, VGC"
#property link      "http://forexforum.bg/viewtopic.php?f=50&t=1352"



extern string PipeName       = "SA_600";
extern int    SuspendSeconds = 10;     
extern int    SleepMS        = 20;



#define PIPE_BASE_NAME     "\\\\.\\pipe\\mt4-"     // MUST tally with client code

#define GENERIC_READ                   0x80000000
#define GENERIC_WRITE                  0x40000000
#define PIPE_ACCESS_DUPLEX             3
#define PIPE_UNLIMITED_INSTANCES       255
#define PIPE_NOWAIT                    1
#define PIPE_TYPE_MESSAGE              4
#define PIPE_READMODE_MESSAGE          2   
#define PIPE_TYPE_BYTE                 0
#define PIPE_READMODE_BYTE             0   
#define PIPE_WAIT                      0

#import "kernel32.dll"
   int CreateNamedPipeW(string pipeName,int openMode,int pipeMode,int maxInstances,int outBufferSize,int inBufferSize,int defaultTimeOut,int security);
   int PeekNamedPipe(int PipeHandle, int PassAsZero, int PassAsZero2, int PassAsZero3, int & BytesAvailable[], int PassAsZero4);
   int CloseHandle(int fileHandle);
	int ReadFile (int FileHandle, uchar& inBuffer[],int BufferLength, int& BytesRead[], int lpOverlapped);
   int WriteFile(int FileHandle, uchar& Buffer[], int BufferLength, int & BytesWritten[], int PassAsZero);
#import

// Number of pipe instances to create by default. This value can overridden by the optional parameter to
// CreatePipeServer(). The number of instances is in effect the maximum number of messages which 
// can be sent to the server between each call which the server makes to CheckForPipeMessages().
// If more messages than this are sent, the extra messages will fail and the sender(s) will need to retry.
#define DEFAULT_MAX_PIPES  200

// Number of pipe instances to allocate. Defaults to DEFAULT_MAX_PIPES unless it is overridden
int glbPipeCount = DEFAULT_MAX_PIPES;
// Array of pipe handles allocated by CreatePipeServer()
int glbPipe[DEFAULT_MAX_PIPES];
// Persistent storage of the pipe name passed as a parameter to CreatePipeServer()
string glbPipeName;

// Starts the pipe server by creating n instances of the pipe
void CreatePipeServer(string pipeName, int UsePipeInstances = DEFAULT_MAX_PIPES)
  {
   // Store the number of pipe instances to use and resize the array accordinging
   glbPipeCount = UsePipeInstances;
   ArrayResize(glbPipe, glbPipeCount);
   // Store the name to use for the pipe instances 
   glbPipeName = pipeName;
   // Create the pipe instances
   for (int i = 0; i < glbPipeCount; i++)
      glbPipe[i] = CreatePipeInstance();
   return;
  }

// Closes all the resources used by the pipe server: i.e. closes all the pipe instances
void DestroyPipeServer()
  {
   for (int i = 0; i < glbPipeCount; i++)
      CloseHandle(glbPipe[i]);
   return;
  }

// Service function which creates a pipe instance
int CreatePipeInstance()
  {
   string strPipeName = StringConcatenate(PIPE_BASE_NAME , glbPipeName);
   return (CreateNamedPipeW(strPipeName, (int)(GENERIC_READ | PIPE_ACCESS_DUPLEX), PIPE_TYPE_MESSAGE | PIPE_READMODE_MESSAGE | PIPE_NOWAIT, PIPE_UNLIMITED_INSTANCES, 1000, 1000, 0, NULL));
  }
  
  
datetime StartTime=0;
int      brCall=0;

int      aPairCount=0;
string   aPair[1000];
int      aDigit[1000];
datetime aLastSinhTime[1000];
double   aBid[1000];
double   aAsk[1000];

  
int init()
  {
   StartTime=TimeLocal();
   brCall=0;
   aPairCount=0;

   // Create the server
   CreatePipeServer(PipeName);
   return(0);
  }

int deinit()
  {
   // Destroy the pipe server 
   DestroyPipeServer();
   
   Comment("");
   return(0);
  }

int start()
  {
   while(!IsStopped() && IsConnected())	
     {
      for(int i = 0; i < glbPipeCount; i++) 
          CheckPipe(i);
      Comment("\nStart Time: "+TimeToStr(StartTime,TIME_DATE|TIME_SECONDS)+
              "\nLocal Time: "+TimeToStr(TimeLocal(),TIME_DATE|TIME_SECONDS)+
              "\nCall Count: "+DoubleToStr(brCall,0)
             );
      Sleep(MathMax(SleepMS,10));
     }
   return(0);
  }

bool CheckPipe(int PipeIndex)
  {
   bool Result=false;
   string sMsg = "";
 
   // See if there's data available on the pipe   
   int BytesAvailable[1] = {0};
   int res = PeekNamedPipe(glbPipe[PipeIndex], 0, 0, 0, BytesAvailable, 0);
   if (res != 0) {
      // PeekNamedPipe() succeeded
      // Is there data?
      if (BytesAvailable[0] != 0) {
          Result=true;

         // Keep reading until either we have all the data, or an error occurs         
         int TotalBytesRead = 0;
         while (TotalBytesRead < BytesAvailable[0]) 
           {
            string ReadBuffer="";
            int BytesRead[1] = {0};
            uchar iBuffer[256];
            ReadFile(glbPipe[PipeIndex],iBuffer,ArraySize(iBuffer),BytesRead,NULL);
            for(int i=0; i<BytesRead[0]; i++)
                ReadBuffer = ReadBuffer + CharToStr(iBuffer[i]);
            // Did we get any data from the read?
            if(BytesRead[0] > 0) 
              {
               // Yes, got some data. Add it to the total message which is passed back
               sMsg = StringConcatenate(sMsg, StringSubstr(ReadBuffer, 0, BytesRead[0]));   
               TotalBytesRead += BytesRead[0];
              } 
            else 
              {
               // No, the read failed. Stop reading, and pass back an empty string 
               sMsg = "";
               TotalBytesRead = 999999;
              }
           }
         if(StringLen(sMsg)>0)
           {
            string outString="n/a";
            RefreshRates();
            brCall=brCall+1;
            double pBid=MarketInfo(sMsg,MODE_BID);
            double pAsk=MarketInfo(sMsg,MODE_ASK);
            if(pBid>0.0001 && pAsk>0.0001)
              {
               int ai=0;
               bool fl=true;
               for(i=1;i<=aPairCount;i++)
                   if(aPair[i]==sMsg)
                     {
                      ai=i;
                      break;
                     }
               if(ai==0)
                 {
                  aPairCount=aPairCount+1;
                  ai=aPairCount;
                  aPair[ai]=sMsg;
                  aDigit[ai]=MarketInfo(sMsg,MODE_DIGITS);
                  aLastSinhTime[ai]=TimeLocal();
                  aBid[ai]=pBid;
                  aAsk[ai]=pAsk;
                 }
               else
               if(MathAbs(aBid[ai]-pBid)>=0.00001 || MathAbs(aAsk[ai]-pAsk)>=0.00001)
                 {
                  aLastSinhTime[ai]=TimeLocal();
                  aBid[ai]=pBid;
                  aAsk[ai]=pAsk;
                 }
               else
               if(TimeLocal()-aLastSinhTime[ai]>SuspendSeconds)
                  fl=false;
               if(fl)
                  outString=DoubleToStr(aBid[ai],aDigit[ai])+"|"+DoubleToStr(aAsk[ai],aDigit[ai]);
               else
                  outString="Suspended";
              }

            int bytesWritten[1];
            uchar aoutString[2048];
            StringToCharArray(outString,aoutString);
            
            bool fSuccess=WriteFile(glbPipe[PipeIndex],aoutString,StringLen(outString)+1,bytesWritten,NULL) != 0;
            if(!fSuccess || bytesWritten[0] != StringLen(outString)+1) 
              {
               Sleep(10);
              }
           }
         // Destroy and recreate the pipe instance
         CloseHandle(glbPipe[PipeIndex]);
         glbPipe[PipeIndex] = CreatePipeInstance();
      
      } else {
         // No data available on pipe 
      }
   } else {
      // PeekNamedPipe() failed
   }
   
   return(Result);
  }

