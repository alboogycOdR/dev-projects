//+------------------------------------------------------------------+
//|                                           CurrencyStrengthEA.mq5 |
//|                                                                  |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024"
#property link      ""
#property version   "1.00"
#property strict

// Input parameters
input int      UpdateInterval = 60;    // Update interval in seconds
input bool     ShowOnChart = true;     // Show results on chart
input bool     ShowInConsole = true;   // Show results in console
input string   SymbolSuffix = ".iux"; // Broker's symbol suffix

// Global variables
string MajorCurrencies[] = {"USD", "EUR", "GBP", "JPY", "AUD", "NZD", "CHF", "CAD"};
string ForexPairs[];
double CurrencyStrength[];
datetime LastUpdateTime = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    // Initialize arrays
    ArrayResize(CurrencyStrength, ArraySize(MajorCurrencies));
    ArrayInitialize(CurrencyStrength, 0.0);
    
    // Initialize forex pairs
    InitializeForexPairs();
    
    // Create display objects if needed
    if(ShowOnChart)
        CreateDisplayObjects();
        
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    // Clean up display objects
    if(ShowOnChart)
        DeleteDisplayObjects();
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    // Check if it's time to update
    if(TimeCurrent() - LastUpdateTime < UpdateInterval)
        return;
        
    // Calculate currency strengths
    CalculateCurrencyStrengths();
    
    // Display results
    DisplayResults();
    
    LastUpdateTime = TimeCurrent();
}

//+------------------------------------------------------------------+
//| Initialize forex pairs array                                     |
//+------------------------------------------------------------------+
void InitializeForexPairs()
{
    string basePairs[] = {
        "EURUSD","GBPUSD","USDJPY","USDCHF","AUDUSD","USDCAD","NZDUSD",
        "EURGBP","EURJPY","EURCHF","EURAUD","EURCAD","EURNZD",
        "GBPJPY","GBPCHF","GBPAUD","GBPCAD","GBPNZD",
        "AUDJPY","CADJPY","NZDJPY",
        "AUDCAD","AUDNZD","CADNZD"
    };
    int count = 0;
    ArrayResize(ForexPairs, ArraySize(basePairs));
    for(int i = 0; i < ArraySize(basePairs); i++)
    {
        string symbol = basePairs[i] + SymbolSuffix;
        if(SymbolSelect(symbol, true))
        {
            ForexPairs[count] = symbol;
            count++;
        }
    }
    ArrayResize(ForexPairs, count); // Only keep found pairs
}

//+------------------------------------------------------------------+
//| Calculate currency strengths                                     |
//+------------------------------------------------------------------+
void CalculateCurrencyStrengths()
{
    ArrayInitialize(CurrencyStrength, 0.0);
    
    for(int i = 0; i < ArraySize(ForexPairs); i++)
    {
        string pair = ForexPairs[i];
        if(!SymbolSelect(pair, true)) continue;
        double rate = iClose(pair, PERIOD_H1, 0);
        
        if(rate == 0) continue;
        
        // Extract base and quote currencies
        string base = StringSubstr(pair, 0, 3);
        string quote = StringSubstr(pair, 3, 3);
        
        // Find currency indices
        int baseIdx = ArraySearch(MajorCurrencies, base);
        int quoteIdx = ArraySearch(MajorCurrencies, quote);
        
        if(baseIdx >= 0 && quoteIdx >= 0)
        {
            // Calculate strength contribution
            double strength = MathLog(rate);
            CurrencyStrength[baseIdx] += strength;
            CurrencyStrength[quoteIdx] -= strength;
        }
    }
    
    // Normalize strengths
    double maxStrength = 0;
    for(int i = 0; i < ArraySize(CurrencyStrength); i++)
    {
        maxStrength = MathMax(maxStrength, MathAbs(CurrencyStrength[i]));
    }
    
    if(maxStrength > 0)
    {
        for(int i = 0; i < ArraySize(CurrencyStrength); i++)
        {
            CurrencyStrength[i] /= maxStrength;
        }
    }
}

//+------------------------------------------------------------------+
//| Display results                                                  |
//+------------------------------------------------------------------+
void DisplayResults()
{
    // Sort currencies by strength
    int indices[];
    ArrayResize(indices, ArraySize(MajorCurrencies));
    for(int i = 0; i < ArraySize(indices); i++)
        indices[i] = i;
        
    // Custom sort indices based on CurrencyStrength values
    for(int i = 0; i < ArraySize(indices) - 1; i++)
    {
        for(int j = i + 1; j < ArraySize(indices); j++)
        {
            if(CurrencyStrength[indices[i]] > CurrencyStrength[indices[j]])
            {
                int temp = indices[i];
                indices[i] = indices[j];
                indices[j] = temp;
            }
        }
    }
    
    // Prepare display string
    string display = "Currency Strength Analysis\n";
    display += "------------------------\n";
    
    // Display sorted currencies
    for(int i = ArraySize(indices) - 1; i >= 0; i--)
    {
        int idx = indices[i];
        display += StringFormat("%s: %.2f\n", MajorCurrencies[idx], CurrencyStrength[idx]);
    }
    
    // Table header for all 28 pairs
    display += "\nPair      | Strength Diff | Suggestion\n";
    display += "--------------------------------------\n";
    
    double threshold = 0.10; // Minimum strength difference for a trade
    for(int i = 0; i < ArraySize(ForexPairs); i++)
    {
        string pair = ForexPairs[i];
        string base = StringSubstr(pair, 0, 3);
        string quote = StringSubstr(pair, 3, 3);
        int baseIdx = ArraySearch(MajorCurrencies, base);
        int quoteIdx = ArraySearch(MajorCurrencies, quote);
        if(baseIdx < 0 || quoteIdx < 0) continue;
        double diff = CurrencyStrength[baseIdx] - CurrencyStrength[quoteIdx];
        string suggestion = "NO TRADE";
        if(diff > threshold)
            suggestion = "BUY";
        else if(diff < -threshold)
            suggestion = "SELL";
        display += StringFormat("%-10s| % 6.2f      | %s\n", pair, diff, suggestion);
    }
    
    // Display results
    if(ShowInConsole)
        Print(display);
        
    if(ShowOnChart)
        UpdateChartDisplay(display);
}

//+------------------------------------------------------------------+
//| Create display objects                                           |
//+------------------------------------------------------------------+
void CreateDisplayObjects()
{
    string name = "CurrencyStrengthDisplay";
    ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
    ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetInteger(0, name, OBJPROP_XDISTANCE, 10);
    ObjectSetInteger(0, name, OBJPROP_YDISTANCE, 10);
    ObjectSetInteger(0, name, OBJPROP_COLOR, clrWhite);
    ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 10);
    ObjectSetString(0, name, OBJPROP_FONT, "Arial");
}

//+------------------------------------------------------------------+
//| Update chart display                                             |
//+------------------------------------------------------------------+
void UpdateChartDisplay(string text)
{
    string name = "CurrencyStrengthDisplay";
    ObjectSetString(0, name, OBJPROP_TEXT, text);
    ChartRedraw();
}

//+------------------------------------------------------------------+
//| Delete display objects                                           |
//+------------------------------------------------------------------+
void DeleteDisplayObjects()
{
    ObjectDelete(0, "CurrencyStrengthDisplay");
}

//+------------------------------------------------------------------+
//| Search for string in array                                       |
//+------------------------------------------------------------------+
int ArraySearch(const string &array[], string value)
{
    for(int i = 0; i < ArraySize(array); i++)
    {
        if(array[i] == value)
            return i;
    }
    return -1;
}