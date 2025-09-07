//+------------------------------------------------------------------+
//|                                             SOB_FVG_BoS V1.0.mq5 |
//|                                                   shikhar shivam |
//|                                     @artificialintelligencefacts |
//+------------------------------------------------------------------+
#property copyright "shikhar shivam"
#property link      "@artificialintelligencefacts"
#property version   "1.00"
#property indicator_chart_window
#property indicator_label1  "Super OrderBlock / FVG / BoS Tools"

// Input Parameters
// Order Blocks
input bool plotOB = true;                     // Plot OB
input color obBullColor = clrGreen;           // Bullish OB Color
input color obBearColor = clrRed;             // Bearish OB Color
input ENUM_LINE_STYLE obBoxBorder = STYLE_SOLID; // OB Box Border Style
input int obMaxBoxSet = 10;                   // Maximum OB Box Displayed
input bool filterMitOB = false;               // Custom Color Mitigated OB
input color mitOBColor = clrGray;             // Mitigated OB Color
input bool plotLabelOB = true;                // Plot OB Label
input color obLabelColor = clrGray;           // OB Label Color
input int obLabelSize = 6;                    // OB Label Size (tiny=6)

// Fair Value Gaps
input bool plotFVG = true;                    // Plot FVG
input bool plotStructureBreakingFVG = true;   // Plot Structure Breaking FVG
input color fvgBullColor = clrBlack;          // Bullish FVG Color
input color fvgBearColor = clrBlack;          // Bearish FVG Color
input color fvgStructBreakingColor = clrBlue; // Structure Breaking FVG Color
input ENUM_LINE_STYLE fvgBoxBorder = STYLE_SOLID; // FVG Box Border Style
input int fvgMaxBoxSet = 10;                  // Maximum FVG Box Displayed
input bool filterMitFVG = false;              // Custom Color Mitigated FVG
input color mitFVGColor = clrGray;            // Mitigated FVG Color
input bool plotLabelFVG = true;               // Plot FVG Label
input color fvgLabelColor = clrGray;          // FVG Label Color
input int fvgLabelSize = 6;                   // FVG Label Size

// Rejection Blocks
input bool plotRJB = false;                   // Plot RJB
input color rjbBullColor = clrGreen;          // Bullish RJB Color
input color rjbBearColor = clrRed;            // Bearish RJB Color
input ENUM_LINE_STYLE rjbBoxBorder = STYLE_SOLID; // RJB Box Border Style
input int rjbMaxBoxSet = 10;                  // Maximum RJB Box Displayed
input bool filterMitRJB = false;              // Custom Color Mitigated RJB
input color mitRJBColor = clrGray;            // Mitigated RJB Color
input bool plotLabelRJB = true;               // Plot RJB Label
input color rjbLabelColor = clrGray;          // RJB Label Color
input int rjbLabelSize = 6;                   // RJB Label Size

// Pivots
input bool plotPVT = true;                    // Plot Pivots
input int pivotLookup = 1;                    // Pivot Lookup (1 to 5)
input color pvtTopColor = clrSilver;          // Pivot Top Color
input color pvtBottomColor = clrSilver;       // Pivot Bottom Color

// Break of Structures
input bool plotBOS = false;                   // Plot BoS
input bool useHighLowForBullishBoS = false;   // Use High/Low for Bullish BoS
input bool useHighLowForBearishBoS = false;   // Use High/Low for Bearish BoS
input bool bosBoxFlag = false;                // BoS Box Length Manually
input int bosBoxLength = 3;                   // BoS Box Length Manually (1 to 5)
input color bosBullColor = clrGreen;          // Bullish BoS Color
input color bosBearColor = clrRed;            // Bearish BoS Color
input ENUM_LINE_STYLE bosBoxBorder = STYLE_SOLID; // BoS Box Border Style
input int bosMaxBoxSet = 10;                  // Maximum BoS Box Displayed
input bool plotLabelBOS = true;               // Plot BoS Label
input color bosLabelColor = clrGray;          // BoS Label Color
input int bosLabelSize = 6;                   // BoS Label Size

// High Volume Bars
input bool plotHVB = true;                    // Plot HVB
input color hvbBullColor = clrGreen;          // Bullish HVB Color
input color hvbBearColor = clrRed;            // Bearish HVB Color
input int hvbEMAPeriod = 12;                  // Volume EMA Period
input double hvbMultiplier = 1.5;             // Volume Multiplier

// Qualitative Indicators
input bool plotPPDD = true;                   // Plot PPDD OB's
input color ppddBullColor = clrGreen;         // Bullish PPDD OB's Color
input color ppddBearColor = clrRed;           // Bearish PPDD OB's Color
input bool plotOBFVG = true;                  // Plot Stacked OB+FVG
input color obfvgBullColor = clrGreen;        // Bullish Stacked OB+FVG Color
input color obfvgBearColor = clrRed;          // Bearish Stacked OB+FVG Color

// Box Types
#define TYPE_OB  1
#define TYPE_FVG 2
#define TYPE_RJB 3
#define TYPE_BOS 4

// Struct for Box Information
struct BoxInfo {
    string name;
    int type;
    bool mitigated;
    datetime leftTime;
    datetime rightTime;
    double topPrice;
    double bottomPrice;
    color bgColor;
    color borderColor;
};

// Global Arrays for Boxes
BoxInfo bullBoxesOB[], bearBoxesOB[];
BoxInfo bullBoxesFVG[], bearBoxesFVG[];
BoxInfo bullBoxesRJB[], bearBoxesRJB[];
BoxInfo bullBoxesBOS[], bearBoxesBOS[];

// Helper Functions
bool IsUp(int index) {
    return iClose(NULL, 0, index) > iOpen(NULL, 0, index);
}

bool IsDown(int index) {
    return iClose(NULL, 0, index) < iOpen(NULL, 0, index);
}

bool IsObUp(int index) {
    return IsDown(index + 1) && IsUp(index) && iClose(NULL, 0, index) > iHigh(NULL, 0, index + 1);
}

bool IsObDown(int index) {
    return IsUp(index + 1) && IsDown(index) && iClose(NULL, 0, index) < iLow(NULL, 0, index + 1);
}

bool IsFvgUp(int index) {
    return iLow(NULL, 0, index) > iHigh(NULL, 0, index + 2);
}

bool IsFvgDown(int index) {
    return iHigh(NULL, 0, index) < iLow(NULL, 0, index + 2);
}

bool IsPivotHigh(int index, int lookup) {
    double high = iHigh(NULL, 0, index);
    for(int j = 1; j <= lookup; j++) {
        if(high <= iHigh(NULL, 0, index - j) || high <= iHigh(NULL, 0, index + j)) return false;
    }
    return true;
}

bool IsPivotLow(int index, int lookup) {
    double low = iLow(NULL, 0, index);
    for(int j = 1; j <= lookup; j++) {
        if(low >= iLow(NULL, 0, index - j) || low >= iLow(NULL, 0, index + j)) return false;
    }
    return true;
}

double CalculateEMA(int period, int index, const long &volume[]) {
    double alpha = 2.0 / (period + 1);
    double ema = (double)volume[index];  // Explicit cast from long to double
    for(int j = index + 1; j < index + period && j < iBars(NULL, 0); j++) {
        ema = alpha * (double)volume[j] + (1 - alpha) * ema;  // Explicit cast
    }
    return ema;
}

// Function to Draw Box
void DrawBox(string name, datetime leftTime, double topPrice, datetime rightTime, double bottomPrice, color bgColor, color borderColor, ENUM_LINE_STYLE borderStyle, string labelText, color labelColor, int labelSize) {
    string boxName = "Box_" + name;
    ObjectCreate(0, boxName, OBJ_RECTANGLE, 0, leftTime, topPrice, rightTime, bottomPrice);
    ObjectSetInteger(0, boxName, OBJPROP_COLOR, borderColor);
    ObjectSetInteger(0, boxName, OBJPROP_STYLE, borderStyle);
    ObjectSetInteger(0, boxName, OBJPROP_WIDTH, 1);
    ObjectSetInteger(0, boxName, OBJPROP_BACK, true);
    ObjectSetInteger(0, boxName, OBJPROP_FILL, true);
    ObjectSetInteger(0, boxName, OBJPROP_BGCOLOR, bgColor);

    if(labelText != "") {
        string labelName = "Label_" + name;
        ObjectCreate(0, labelName, OBJ_TEXT, 0, rightTime, bottomPrice);
        ObjectSetString(0, labelName, OBJPROP_TEXT, labelText);
        ObjectSetInteger(0, labelName, OBJPROP_COLOR, labelColor);
        ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, labelSize);
        ObjectSetInteger(0, labelName, OBJPROP_ANCHOR, ANCHOR_RIGHT_UPPER);
    }
}

// Function to Update Boxes
void UpdateBoxes(BoxInfo &boxes[], int type, double high, double low, datetime currentTime, bool filterMit, color mitColor) {
    for(int j = 0; j < ArraySize(boxes); j++) {
        BoxInfo box = boxes[j];
        if(!box.mitigated) {
            if(high > box.bottomPrice && low < box.topPrice) {
                box.mitigated = true;
                if(filterMit) {
                    ObjectSetInteger(0, "Box_" + box.name, OBJPROP_BGCOLOR, mitColor);
                    ObjectSetInteger(0, "Box_" + box.name, OBJPROP_COLOR, mitColor);
                }
            } else {
                ObjectSetInteger(0, "Box_" + box.name, OBJPROP_TIME, 1, currentTime);
                box.rightTime = currentTime;
            }
        }
    }
}

// OnInit
int OnInit() {
    return(INIT_SUCCEEDED);
}

// OnDeinit
void OnDeinit(const int reason) {
    ObjectsDeleteAll(0, -1, -1);
}

// OnCalculate
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
    int start = prev_calculated == 0 ? 2 : prev_calculated - 1;

    for(int i = start; i < rates_total && i >= 2; i++) {
        // Order Blocks (Bullish)
        if(plotOB && IsObUp(i-1)) {
            string name = "BullOB_" + TimeToString(time[i-2]);
            DrawBox(name, time[i-2], high[i-2], time[i], MathMin(low[i-2], low[i-1]), obBullColor, obBullColor, obBoxBorder, plotLabelOB ? "OB+" : "", obLabelColor, obLabelSize);
            BoxInfo box = {name, TYPE_OB, false, time[i-2], time[i], high[i-2], MathMin(low[i-2], low[i-1]), obBullColor, obBullColor};
            ArrayResize(bullBoxesOB, ArraySize(bullBoxesOB) + 1);
            bullBoxesOB[ArraySize(bullBoxesOB) - 1] = box;
            if(ArraySize(bullBoxesOB) > obMaxBoxSet) {
                ObjectDelete(0, "Box_" + bullBoxesOB[0].name);
                ObjectDelete(0, "Label_" + bullBoxesOB[0].name);
                ArrayRemove(bullBoxesOB, 0, 1);
            }
        }

        // Order Blocks (Bearish)
        if(plotOB && IsObDown(i-1)) {
            string name = "BearOB_" + TimeToString(time[i-2]);
            DrawBox(name, time[i-2], MathMax(high[i-2], high[i-1]), time[i], low[i-2], obBearColor, obBearColor, obBoxBorder, plotLabelOB ? "OB-" : "", obLabelColor, obLabelSize);
            BoxInfo box = {name, TYPE_OB, false, time[i-2], time[i], MathMax(high[i-2], high[i-1]), low[i-2], obBearColor, obBearColor};
            ArrayResize(bearBoxesOB, ArraySize(bearBoxesOB) + 1);
            bearBoxesOB[ArraySize(bearBoxesOB) - 1] = box;
            if(ArraySize(bearBoxesOB) > obMaxBoxSet) {
                ObjectDelete(0, "Box_" + bearBoxesOB[0].name);
                ObjectDelete(0, "Label_" + bearBoxesOB[0].name);
                ArrayRemove(bearBoxesOB, 0, 1);
            }
        }

        // Fair Value Gaps (Bullish)
        if(plotFVG && IsFvgUp(i)) {
            string name = "BullFVG_" + TimeToString(time[i]);
            DrawBox(name, time[i], low[i], time[i+1], high[i+2], fvgBullColor, fvgBullColor, fvgBoxBorder, plotLabelFVG ? "FVG+" : "", fvgLabelColor, fvgLabelSize);
            BoxInfo box = {name, TYPE_FVG, false, time[i], time[i+1], low[i], high[i+2], fvgBullColor, fvgBullColor};
            ArrayResize(bullBoxesFVG, ArraySize(bullBoxesFVG) + 1);
            bullBoxesFVG[ArraySize(bullBoxesFVG) - 1] = box;
            if(ArraySize(bullBoxesFVG) > fvgMaxBoxSet) {
                ObjectDelete(0, "Box_" + bullBoxesFVG[0].name);
                ObjectDelete(0, "Label_" + bullBoxesFVG[0].name);
                ArrayRemove(bullBoxesFVG, 0, 1);
            }
        }

        // Fair Value Gaps (Bearish)
        if(plotFVG && IsFvgDown(i)) {
            string name = "BearFVG_" + TimeToString(time[i]);
            DrawBox(name, time[i], high[i], time[i+1], low[i+2], fvgBearColor, fvgBearColor, fvgBoxBorder, plotLabelFVG ? "FVG-" : "", fvgLabelColor, fvgLabelSize);
            BoxInfo box = {name, TYPE_FVG, false, time[i], time[i+1], high[i], low[i+2], fvgBearColor, fvgBearColor};
            ArrayResize(bearBoxesFVG, ArraySize(bearBoxesFVG) + 1);
            bearBoxesFVG[ArraySize(bearBoxesFVG) - 1] = box;
            if(ArraySize(bearBoxesFVG) > fvgMaxBoxSet) {
                ObjectDelete(0, "Box_" + bearBoxesFVG[0].name);
                ObjectDelete(0, "Label_" + bearBoxesFVG[0].name);
                ArrayRemove(bearBoxesFVG, 0, 1);
            }
        }

        // Pivots
        if(plotPVT && i >= pivotLookup && i < rates_total - pivotLookup) {
            if(IsPivotHigh(i, pivotLookup)) {
                ObjectCreate(0, "PivotH_" + TimeToString(time[i]), OBJ_ARROW, 0, time[i], high[i]);
                ObjectSetInteger(0, "PivotH_" + TimeToString(time[i]), OBJPROP_COLOR, pvtTopColor);
                ObjectSetInteger(0, "PivotH_" + TimeToString(time[i]), OBJPROP_ARROWCODE, 159); // Dot
            }
            if(IsPivotLow(i, pivotLookup)) {
                ObjectCreate(0, "PivotL_" + TimeToString(time[i]), OBJ_ARROW, 0, time[i], low[i]);
                ObjectSetInteger(0, "PivotL_" + TimeToString(time[i]), OBJPROP_COLOR, pvtBottomColor);
                ObjectSetInteger(0, "PivotL_" + TimeToString(time[i]), OBJPROP_ARROWCODE, 159); // Dot
            }
        }

        // High Volume Bars
        if(plotHVB && i >= hvbEMAPeriod) {
            double ema = CalculateEMA(hvbEMAPeriod, i, volume);
            if(volume[i] > ema * hvbMultiplier) {
                string name = "HVB_" + TimeToString(time[i]);
                color hvbColor = IsUp(i) ? hvbBullColor : hvbBearColor;
                ObjectCreate(0, name, OBJ_RECTANGLE, 0, time[i], high[i], time[i+1], low[i]);
                ObjectSetInteger(0, name, OBJPROP_COLOR, hvbColor);
                ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_DOT);
                ObjectSetInteger(0, name, OBJPROP_BACK, true);
                ObjectSetInteger(0, name, OBJPROP_FILL, false);
            }
        }
    }

    // Update Boxes
    if(rates_total > 0) {
        UpdateBoxes(bullBoxesOB, TYPE_OB, high[rates_total-1], low[rates_total-1], time[rates_total-1], filterMitOB, mitOBColor);
        UpdateBoxes(bearBoxesOB, TYPE_OB, high[rates_total-1], low[rates_total-1], time[rates_total-1], filterMitOB, mitOBColor);
        UpdateBoxes(bullBoxesFVG, TYPE_FVG, high[rates_total-1], low[rates_total-1], time[rates_total-1], filterMitFVG, mitFVGColor);
        UpdateBoxes(bearBoxesFVG, TYPE_FVG, high[rates_total-1], low[rates_total-1], time[rates_total-1], filterMitFVG, mitFVGColor);
    }

    return(rates_total);
}