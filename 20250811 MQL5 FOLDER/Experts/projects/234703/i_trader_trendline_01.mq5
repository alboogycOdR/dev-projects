//+------------------------------------------------------------------+
//| Expert: Zigzag with horizontal lines at peaks/troughs            |
//+------------------------------------------------------------------+
#property strict

#include <Trade/Trade.mqh>
CTrade trade;

// Define Zigzag parameters
input int Depth = 12;
input int Deviation = 5;
input int Backstep = 3;

int                InpBandsPeriod            = 20;          // Bands Period
double             InpBandsDeviations        = 2.0;         // Bands Deviations
ENUM_APPLIED_PRICE BBAppliedPrice         = PRICE_CLOSE; // Fast MA Applied Price

int shift_Bar=0;

// Option to draw yellow trendlines
input bool isDrawYellowTrendline = true; // Set to false to disable drawing yellow trendlines

// Declare variables
int ZigZag_Handle;
double ZigZag_Buffer[];
datetime Time_Buffer[]; // Store candle times

int handle_bb;
int handle_stoch;

datetime lastUpdate = 0; // Store the last update time

//+------------------------------------------------------------------+
//| Initialization function                                          |
//+------------------------------------------------------------------+
void OnInit()
  {
   ChartSetInteger(0, CHART_SHIFT, true);  // Distance from candles to the left border

// Disable grid
   ChartSetInteger(0, CHART_SHOW_GRID, false);

// Show ask line
   ChartSetInteger(0, CHART_SHOW_ASK_LINE, true);

// Disable trade history
   ChartSetInteger(0, CHART_SHOW_TRADE_HISTORY, false);

   int chartWidth = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS, 0);

   handle_bb= iBands(Symbol(), PERIOD_CURRENT, InpBandsPeriod, shift_Bar, InpBandsDeviations, BBAppliedPrice);
   if(handle_bb==INVALID_HANDLE)
     {
      return;
     }
   int handle_stoch = iStochastic(_Symbol,_Period,14,3,3,MODE_SMA,STO_LOWHIGH);
   if(handle_stoch == INVALID_HANDLE)
     {
      Print("Failed to initialize Stoch indicator");
      return;
     }
     
   ZigZag_Handle = iCustom(Symbol(), 0, "ZigZag", Depth, Deviation, Backstep);
   if(ZigZag_Handle == INVALID_HANDLE)
     {
      Print("Failed to initialize ZigZag indicator");
      return;
     }

   ChartIndicatorAdd(ChartID(), 0, ZigZag_Handle);
  }

//+------------------------------------------------------------------+
//| Function to delete ZigZag objects                               |
//+------------------------------------------------------------------+
void DeleteZigZagObjects()
  {
   int totalObjects = ObjectsTotal(0, -1, -1);
   for(int i = totalObjects - 1; i >= 0; i--)
     {
      string objName = ObjectName(0, i);
      if(StringFind(objName, "ZigZag_") == 0)
        {
         ObjectDelete(0, objName);
        }
     }
  }

//+------------------------------------------------------------------+
//| Main function                                                   |
//+------------------------------------------------------------------+
void OnTick()
  {
   int bars = Bars(Symbol(), 0);
   if(ZigZag_Handle == INVALID_HANDLE)
      return;

// Check if there is a new candle to update
   datetime currentTime = iTime(Symbol(), 0, 0);
   if(currentTime == lastUpdate)
      return;
   lastUpdate = currentTime;

// Copy ZigZag indicator data
   if(CopyBuffer(ZigZag_Handle, 0, 0, bars, ZigZag_Buffer) <= 0)
     {
      Print("Error copying indicator data");
      return;
     }

// Copy time data
   if(CopyTime(Symbol(), 0, 0, bars, Time_Buffer) <= 0)
     {
      Print("Error copying time data");
      return;
     }
   ArraySetAsSeries(ZigZag_Buffer, true);
   ArraySetAsSeries(Time_Buffer, true);

// Array to store troughs
   datetime troughTimes[];
   double troughValues[];
   int troughCount = 0;

// Find all troughs
   for(int i = 1; i < ArraySize(ZigZag_Buffer) - 1; i++) // Stop before the last element to avoid out-of-range errors
     {
      if(ZigZag_Buffer[i] != 0) // Only process valid ZigZag points
        {
         double zigzagValue = ZigZag_Buffer[i]; // ZigZag value at the current point
         datetime zigzagTime = Time_Buffer[i];  // Time of the current point

         // Get the actual candle value at the ZigZag point
         double candleLow = iLow(Symbol(), 0, i);    // Lowest price of the candle at the ZigZag point

         // Check if the ZigZag point is a trough
         if(zigzagValue == candleLow)
           {
            // Add trough to arrays
            ArrayResize(troughTimes, troughCount + 1);
            ArrayResize(troughValues, troughCount + 1);
            troughTimes[troughCount] = zigzagTime;
            troughValues[troughCount] = zigzagValue;
            troughCount++;
           }
        }
     }

// Draw trendlines between all possible pairs of troughs
   for(int i = 0; i < troughCount; i++)
     {
      for(int j = i + 1; j < troughCount; j++)
        {
         // Ensure x1 is older than x2 (left to right)
         datetime x1 = troughTimes[i];
         datetime x2 = troughTimes[j];
         double y1 = troughValues[i];
         double y2 = troughValues[j];

         // Swap if x1 is newer than x2
         if(x1 > x2)
           {
            datetime tempTime = x1;
            x1 = x2;
            x2 = tempTime;

            double tempValue = y1;
            y1 = y2;
            y2 = tempValue;
           }

         // Calculate the trendline's slope and current value
         double trendlineSlope = (y2 - y1) / (x2 - x1);
         double trendlineValueAtCurrentTime = y1 + trendlineSlope * (TimeCurrent() - x1);

         // Get the current price
         double currentPrice = SymbolInfoDouble(Symbol(), SYMBOL_BID);

         // Check if the price is approaching or moving away from the trendline
         double distanceToTrendline = MathAbs(currentPrice - trendlineValueAtCurrentTime);

         // Determine if the trendline is converging (approaching) or diverging (moving away)
         bool isConverging = (distanceToTrendline < MathAbs(currentPrice - y2)); // So sánh khoảng cách hiện tại với khoảng cách trước đó

         // Set color based on convergence/divergence
         color trendlineColor;
         if(isConverging)
           {
            trendlineColor = clrDarkTurquoise; // Màu xanh cho các đường hội tụ (giá đang tiến gần)
           }
         else
           {
            if(isDrawYellowTrendline) // Chỉ vẽ màu vàng nếu tùy chọn được bật
              {
               trendlineColor = clrYellow; // Màu vàng cho các đường phân kỳ (giá đang đi xa)
              }
            else
              {
               continue; // Bỏ qua không vẽ nếu tùy chọn vẽ màu vàng bị tắt
              }
           }

         string trendlineName = "Trendline_" + (string)x1 + "_" + (string)x2;
         DrawTrendline(x1, y1, x2, y2, trendlineName, trendlineColor);
        }
     }
  }

//+------------------------------------------------------------------+
//| Function to check if trendline crosses price on the right side   |
//| (from the start point to the current time)                       |
//+------------------------------------------------------------------+
bool IsTrendlineCrossingPriceOnRight(datetime x1, double y1, datetime x2, double y2)
  {
// Tính toán độ dốc của đường trendline
   double trendlineSlope = (y2 - y1) / (x2 - x1);

// Lấy thời gian hiện tại
   datetime currentTime = TimeCurrent();

// Kiểm tra từ điểm x1 (điểm bắt đầu của trendline) đến thời gian hiện tại
   int startBar = iBarShift(Symbol(), 0, x1);
   int endBar = iBarShift(Symbol(), 0, currentTime);

   for(int i = startBar; i >= endBar; i--)
     {
      datetime candleTime = iTime(Symbol(), 0, i); // Thời gian của cây nến
      double candleLow = iLow(Symbol(), 0, i);     // Giá thấp nhất của cây nến
      double candleHigh = iHigh(Symbol(), 0, i);   // Giá cao nhất của cây nến

      // Tính giá trị của đường trendline tại thời điểm cây nến
      double trendlineValueAtCandleTime = y1 + trendlineSlope * (candleTime - x1);

      // Kiểm tra xem trendline có cắt qua cây nến hay không
      if((trendlineValueAtCandleTime > candleLow && trendlineValueAtCandleTime < candleHigh) ||
         (trendlineValueAtCandleTime < candleLow && trendlineValueAtCandleTime > candleHigh))
        {
         return true; // Trendline cắt qua giá ở phía bên phải
        }
     }

   return false; // Trendline không cắt qua giá ở phía bên phải
  }

//+------------------------------------------------------------------+
//| Function to check if a trendline already exists                 |
//+------------------------------------------------------------------+
bool IsTrendlineExist(string name)
  {
   return ObjectFind(0, name) >= 0; // Kiểm tra xem trendline có tồn tại không
  }

//+------------------------------------------------------------------+
//| Hàm vẽ trendline giữa hai điểm                                   |
//+------------------------------------------------------------------+
void DrawTrendline(datetime x1, double y1, datetime x2, double y2, string name = "Trendline", color clr = clrDarkTurquoise, int width = 1)
  {
// Kiểm tra xem trendline đã tồn tại chưa
   if(IsTrendlineExist(name))
     {
      Print("Trendline already exists: ", name);
      return; // Không vẽ lại trendline nếu nó đã tồn tại
     }

// Kiểm tra xem trendline có cắt qua giá ở phía bên phải hay không
   if(IsTrendlineCrossingPriceOnRight(x1, y1, x2, y2))
     {
      Print("Trendline crosses price on the right side, not drawing: ", name);
      return; // Không vẽ trendline nếu nó cắt qua giá ở phía bên phải
     }

// Tạo một đối tượng trendline
   if(!ObjectCreate(0, name, OBJ_TREND, 0, x1, y1, x2, y2))
     {
      Print("Failed to create trendline: ", name, " | Error: ", GetLastError());
      return;
     }

// Thiết lập màu sắc và độ dày của đường trendline
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, width);

// Thiết lập kiểu nét gạch
   ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_DASH);

// Kéo dài đường trendline về phía bên phải
   ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, true);

   Print("Trendline drawn: ", name, " | Color: ", clr);
  }
//+------------------------------------------------------------------+
