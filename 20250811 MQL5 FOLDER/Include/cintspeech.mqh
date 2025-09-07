#property copyright     "Integer"
#property link          "https://login.mql5.com/ru/users/Integer"
#property description   "http://dmffx.com"
#property description   "mailto:for-good-letters@yandex.ru"

#import "kernel32.dll"
int CopyFileA(uchar  &FromFileName[],uchar  &ToFileName[],int FailIfExists);
int DeleteFileA(uchar  &FromFileName[]);
#import
#import "kernel32.dll"
int WinExec(uchar  &x[],int);
#import
//+------------------------------------------------------------------+
//| cIntSpeech class                                                 |
//+------------------------------------------------------------------+
class cIntSpeech
  {
protected:
   bool Copy(string aFromFileName,string aToFileName="")
     {
      aFromFileName=TerminalInfoString(TERMINAL_PATH)+"\\MQL5\\Files\\"+aFromFileName;
      aToFileName=TerminalInfoString(TERMINAL_PATH)+"\\MQL5\\Files\\"+aToFileName;
      uchar m_from[];
      uchar m_to[];
      StringToCharArray(aFromFileName,m_from);
      StringToCharArray(aToFileName,m_to);
      return(CopyFileA(m_from,m_to,0)==1);
     }
   int Run(string aCommand)
     {
      uchar ucArr[];
      StringToCharArray(aCommand,ucArr);
      return(WinExec(ucArr,3));
     }
   void Delete(string aFileName)
     {
      uchar m_fn[];
      StringToCharArray(aFileName,m_fn);
      DeleteFileA(m_fn);
     }
public:
   void Say(string aText,bool aPrint=true)
     {
      if(aPrint)
        {
         Print(aText);
        }
      if(!MQL5InfoInteger(MQL5_DLLS_ALLOWED))
        {
         Alert(__FUNCTION__+": Allow dll");
         return;
        }
      string m_fntxt="Speak\\"+MQL5InfoString(MQL5_PROGRAM_NAME)+".txt";
      string m_fnvbs="Speak\\"+MQL5InfoString(MQL5_PROGRAM_NAME)+".vbs";
      int h=FileOpen(m_fntxt,FILE_ANSI|FILE_WRITE);
      FileWrite(h,"CreateObject(\"SAPI.SpVoice\").Speak\""+aText+"\"");
      FileClose(h);
      Copy(m_fntxt,m_fnvbs);
      FileDelete(m_fntxt);
      int x=Run("explorer "+TerminalInfoString(TERMINAL_PATH)+"\\MQL5\\Files\\"+m_fnvbs);
     }
  };

cIntSpeech Speech;
//+------------------------------------------------------------------+
