///////////////////////////////////////////////////////////////////////
//|                                                   XAUUSD_EA.mq5  |
//|     Exemplo de EA MQL5 que busca 100 candles via dukascopy-node  |
//|     e envia OHLCV ao modelo ONNX para obter sinal              |
///////////////////////////////////////////////////////////////////////

#import "kernel32.dll"
int WinExec(string lpCmdLine, int uCmdShow);
#import

#define SW_HIDE 0

//=== Protótipos ===
bool FetchDukascopyCSV(const string timeframe, const string outPath);
bool LoadCSVtoInputs(const string path, double &inputs[]);
int  PredictSignal(const double &inputs[], double &tp, double &sl);

//+------------------------------------------------------------------+
//| Função de inicialização                                          |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("EA XAUUSD iniciado. Timeframe: ", EnumToString(Period()));
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Evento de tick                                                   |
//+------------------------------------------------------------------+
void OnTick()
{
   static bool first = true;
   if(!first) return;            // executa apenas uma vez
   first = false;

   // Converte ENUM_TIMEFRAMES em string para o timeframe atual
   string tf;
   switch(Period())
   {
      case PERIOD_M1:  tf = "m1";  break;
      case PERIOD_M5:  tf = "m5";  break;
      case PERIOD_M15: tf = "m15"; break;
      case PERIOD_M30: tf = "m30"; break;
      case PERIOD_H1:  tf = "h1";  break;
      case PERIOD_H4:  tf = "h4";  break;
      case PERIOD_D1:  tf = "d1";  break;
      case PERIOD_W1:  tf = "w1";  break;
      case PERIOD_MN1: tf = "mn1"; break;
      default:
         Print("Timeframe não suportado: ", EnumToString(Period()));
         return;
   }

   // Define o caminho para salvar o arquivo CSV
   string symbol = Symbol(); // Obtém o símbolo do gráfico atual
   string csvPath = TerminalInfoString(TERMINAL_DATA_PATH) + "\\MQL5\\Files\\" + symbol + "_" + tf + ".csv";

   // 1) Buscar CSV via dukascopy-node
   if(!FetchDukascopyCSV(tf, csvPath))
   {
      Print("Falha ao obter dados Dukascopy para tf=", tf);
      return;
   }

   // 2) Carregar dados no array inputs
   double inputs[];
   if(!LoadCSVtoInputs(csvPath, inputs))
   {
      Print("Falha ao ler CSV Dukascopy: ", csvPath);
      return;
   }

   // 3) Enviar ao modelo ONNX e obter sinal
   double tp, sl;
   int signal = PredictSignal(inputs, tp, sl);
   PrintFormat("Sinal previsto: %d, TP=%.5f, SL=%.5f", signal, tp, sl);

   // Aqui você pode executar ordens com base no sinal
}

//+------------------------------------------------------------------+
//| Chama dukascopy-node e aguarda arquivo CSV                      |
//+------------------------------------------------------------------+
bool FetchDukascopyCSV(const string timeframe, const string outPath)
{
   datetime toTime   = TimeCurrent();
   datetime fromTime = toTime - 100 * PeriodSeconds(Period()); // Últimos 100 candles

   string fromStr = TimeToString(fromTime, TIME_DATE|TIME_SECONDS) + "Z";
   string toStr   = TimeToString(toTime,   TIME_DATE|TIME_SECONDS) + "Z";

   // Usa o caminho completo para o executável
   string cmd = StringFormat(
      "\"C:\\Users\\sheyl\\AppData\\Roaming\\npm\\dukascopy-node.cmd\" -i %s -from \"%s\" -to \"%s\" -t %s -f csv > \"%s\"",
      Symbol(), fromStr, toStr, timeframe, outPath
   );

   Print("Comando gerado: ", cmd);  // Para depuração

   // Usa WinExec para executar o comando
   int result = WinExec("cmd.exe /C " + cmd, SW_HIDE);

   // Verifica se o comando foi executado
   if(result <= 31)
   {
      Print("Erro ao executar WinExec. Código: ", result);
      return(false);
   }

   // Espera arquivo aparecer (timeout ~5s)
   for(int i=0; i<50; i++)
   {
      if(FileIsExist(outPath)) return(true);
      Sleep(100);
   }
   Print("Arquivo CSV não encontrado: ", outPath);
   return(false);
}

//+------------------------------------------------------------------+
//| Lê CSV Dukascopy e preenche array inputs [100 x 5]              |
//+------------------------------------------------------------------+
bool LoadCSVtoInputs(const string path, double &inputs[])
{
   int fh = FileOpen(path, FILE_READ|FILE_CSV, ',');
   if(fh == INVALID_HANDLE)
      return(false);

   ArrayResize(inputs, 100*5);
   // pula header se houver
   FileReadString(fh);

   for(int i=0; i<100 && !FileIsEnding(fh); i++)
   {
      FileReadString(fh); // timestamp
      inputs[i*5+0] = FileReadNumber(fh); // open
      inputs[i*5+1] = FileReadNumber(fh); // high
      inputs[i*5+2] = FileReadNumber(fh); // low
      inputs[i*5+3] = FileReadNumber(fh); // close
      inputs[i*5+4] = FileReadNumber(fh); // volume
      FileSeek(fh, 0, 1);  // 1 equivale a FILE_CURRENT
   }
   FileClose(fh);
   return(true);
}

//+------------------------------------------------------------------+
//| Stub para função que envia dados ao modelo ONNX                  |
//+------------------------------------------------------------------+
int PredictSignal(const double &inputs[], double &tp, double &sl)
{
   // TODO: Implemente a chamada ao ONNXRuntime, passando inputs[] e obtendo signal, tp, sl
   tp = 0.0;
   sl = 0.0;
   return(0);
}

//+------------------------------------------------------------------+
