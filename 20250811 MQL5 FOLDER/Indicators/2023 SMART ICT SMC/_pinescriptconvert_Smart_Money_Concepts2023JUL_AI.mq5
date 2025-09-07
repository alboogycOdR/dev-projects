#property indicator_chart_window
#property indicator_buffers 10

enum Modes
{
    Historical,
    Present
};

enum Styles
{
    Colored,
    Monochrome
};

// Constants
color TRANSP_CSS = clrNONE;

// Tooltips
string MODE_TOOLTIP = "Allows to display historical Structure or only the recent ones";
string STYLE_TOOLTIP = "Indicator color theme";
string COLOR_CANDLES_TOOLTIP = "Display additional candles with a color reflecting the current trend detected by structure";
string SHOW_INTERNAL = "Display internal market structure";
string CONFLUENCE_FILTER = "Filter non significant internal structure breakouts";
string SHOW_SWING = "Display swing market Structure";
string SHOW_SWING_POINTS = "Display swing point as labels on the chart";
string SHOW_SWHL_POINTS = "Highlight most recent strong and weak high/low points on the chart";
string INTERNAL_OB = "Display internal order blocks on the chart\n\nNumber of internal order blocks to display on the chart";
string SWING_OB = "Display swing order blocks on the chart\n\nNumber of internal swing blocks to display on the chart";
string FILTER_OB = "Method used to filter out volatile order blocks \n\nIt is recommended to use the cumulative mean range method when a low amount of data is available";
string SHOW_EQHL = "Display equal highs and equal lows on the chart";
string EQHL_BARS = "Number of bars used to confirm equal highs and equal lows";
string EQHL_THRESHOLD = "Sensitivity threshold in a range (0, 1) used for the detection of equal highs & lows\n\nLower values will return fewer but more pertinent results";
string SHOW_FVG = "Display fair values gaps on the chart";
string AUTO_FVG = "Filter out non significant fair value gaps";
string FVG_TF = "Fair value gaps timeframe";
string EXTEND_FVG = "Determine how many bars to extend the Fair Value Gap boxes on chart";
string PED_ZONES = "Display premium, discount, and equilibrium zones on chart";

// Settings
// General
input Modes mode = Historical;
input Styles style = Colored;
input bool show_trend = false;

// Internal Structure
input bool show_internals = true;
input string show_ibull = "All";
input color swing_ibull_css = clrDarkBlue;//RGB(8, 153, 129);
input string show_ibear = "All";
input color swing_ibear_css = clrDarkRed;//RGB(242, 54, 69);
input bool ifilter_confluence = false;
input string internal_structure_size = "Tiny";

// Swing Structure
input bool show_Structure = true;
input string show_bull = "All";
input color swing_bull_css = clrDarkBlue;//clrRGB(8, 153, 129);
input string show_bear = "All";
input color swing_bear_css = clrDarkRed;//clrRGB(242, 54, 69);
input string swing_structure_size = "Small";
input bool show_swings = false;
input int length = 50;
input bool show_hl_swings = true;

// Order Blocks
input bool show_iob = true;
input int iob_showlast = 5;
input bool show_ob = false;
input int ob_showlast = 5;
input string ob_filter = "Atr";
input color ibull_ob_css = clrDarkBlue;//clrRGBA(49, 121, 245, 80);
input color ibear_ob_css = clrDarkRed;//clrRGBA(247, 124, 128, 80);
input color bull_ob_css = clrDarkBlue;//clrRGBA(24, 72, 204, 80);
input color bear_ob_css = clrDarkRed;//clrRGBA(178, 40, 51, 80);

// EQH/EQL
input bool show_eq = true;
input int eq_len = 3;
input double eq_threshold = 0.1;
input string eq_size = "Tiny";

// Fair Value Gaps
input bool show_fvg = false;
input bool fvg_auto = true;
input ENUM_TIMEFRAMES fvg_tf = PERIOD_CURRENT;
input color bull_fvg_css = clrDarkBlue;//clrRGBA(0, 255, 104, 70);
input color bear_fvg_css = clrDarkRed;//clrRGBA(255, 0, 8, 70);
input int fvg_extend = 1;

// Previous day/week high/low
input bool show_pdhl = false;
input string pdhl_style = "⎯⎯⎯";
input color pdhl_css = clrDodgerBlue;//clrRGB(33, 87, 243);


input bool show_pwhl = false;
input string pwhl_style = "⎯⎯⎯";
input color pwhl_css = clrDodgerBlue;//clrRGB(33, 87, 243);


input bool show_pmhl = false;
input string pmhl_style = "⎯⎯⎯";
input color pmhl_css = clrDodgerBlue;//clrRGB(33, 87, 243);

// Premium/Discount zones
input bool show_sd = false;
input color premium_css = clrIndianRed;//clrRGB(242, 54, 69);
input color eq_css = 0xB2B5BE;//clrRGB(178, 181, 190);
input color discount_css = 0x089981;//clrRGB(8, 153, 129);

// Functions
int n;
double atr, cmean_range;

// HL Output function
double hl[]()
{
    return {high[0], low[0]};
    //return ArrayCreate(high[0], low[0]);
}

// Get ohlc values function
double[] get_ohlc()
{
    double close1 = Close[1];
    double open1 = Open[1];
    double high0 = High[0];
    double low0 = Low[0];
    double high2 = High[2];
    double low2 = Low[2];

    return ArrayCreate(close1, open1, high0, low0, high2, low2);
}

// Display Structure function
void display_Structure(int x, double y, string txt, color css, bool dashed, bool down, int lbl_size)
{
    int structure_line = ObjectCreate(0, "", OBJ_TREND);
    ObjectSetInteger(0, "", OBJPROP_STYLE, dashed ? STYLE_DASH : STYLE_SOLID);
    ObjectSetInteger(0, "", OBJPROP_COLOR, css);
    ObjectSetDouble(0, "", OBJPROP_PRICE1, y);
    ObjectSetDouble(0, "", OBJPROP_PRICE2, y);
    
    int structure_lbl = ObjectCreate(0, "", OBJ_LABEL);
    ObjectSetInteger(0, "", OBJPROP_XDISTANCE, 0);
    ObjectSetInteger(0, "", OBJPROP_YDISTANCE, 0);
    ObjectSetInteger(0, "", OBJPROP_CORNER, down ? CORNER_LEFT_LOWER : CORNER_LEFT_UPPER);
    ObjectSetString(0, "", OBJPROP_TEXT, txt);
    ObjectSetInteger(0, "", OBJPROP_COLOR, css);
    ObjectSetInteger(0, "", OBJPROP_FONTSIZE, lbl_size);
    ObjectSetDouble(0, "", OBJPROP_PRICE, y);

    if (mode == Present)
    {
        ObjectDelete(structure_line);
        ObjectDelete(structure_lbl);
    }
}

// Swings detection/measurements
void swings(int len, out double top, out double btm)
{
    int os = 0;
    
    double upper = HighArrayMaximum(len);
    double lower = LowArrayMinimum(len);

    if (High[0] > upper)
        os = 0;
    else if (Low[0] < lower)
        os = 1;
    else
        os = os;

    double topVal = 0.0;
    double bottomVal = 0.0;

    if (os == 0 && os[1] != 0)
        topVal = High[0];
    if (os == 1 && os[1] != 1)
        bottomVal = Low[0];

    top = topVal;
    btm = bottomVal;
}

// Order block coordinates function
void ob_coord(bool use_max, int loc, double target_top[], double target_btm[], long target_left[], int target_type[])
{
    double min = 99999999.0;
    double max = 0.0;
    int idx = 1;
    
    double ob_threshold[];
    ArrayResize(ob_threshold, Bars);

    if (ob_filter == "Atr")
    {
        for (int i = 0; i < Bars - loc - 1; i++)
        {
            if ((High[i] - Low[i]) < ob_threshold[i] * 2)
            {
                if (use_max)
                {
                    if (High[i] > max)
                    {
                        max = High[i];
                        min = Low[i];
                        idx = i;
                    }
                }
                else
                {
                    if (Low[i] < min)
                    {
                        min = Low[i];
                        max = High[i];
                        idx = i;
                    }
                }
            }
        }
    }
    else
    {
        for (int i = 0; i < Bars - loc - 1; i++)
        {
            if ((High[i] - Low[i]) < ob_threshold[i] * 2)
            {
                if (use_max)
                {
                    if (High[i] > max)
                    {
                        max = High[i];
                        min = Low[i];
                        idx = i;
                    }
                }
                else
                {
                    if (Low[i] < min)
                    {
                        min = Low[i];
                        max = High[i];
                        idx = i;
                    }
                }
            }
        }
    }
    
    ArrayInsert(target_top, 0, max);
    ArrayInsert(target_btm, 0, min);
    ArrayInsert(target_left, 0, Time[idx]);
    ArrayInsert(target_type, 0, use_max ? -1 : 1);
}

// Set order blocks
void display_ob(int boxes[], double target_top[], double target_btm[], long target_left[], int target_type[], int show_last, bool swing, int size)
{
    for (int i = 0; i < MathMin(show_last - 1, size - 1); i++)
    {
        int get_box = boxes[i];

        ObjectSetDouble(0, "", OBJPROP_PRICE1, target_top[i]);
        ObjectSetDouble(0, "", OBJPROP_PRICE2, target_btm[i]);
        ObjectSetInteger(0, "", OBJPROP_TIME1, target_left[i]);
        ObjectSetInteger(0, "", OBJPROP_STYLE, swing ? STYLE_SOLID : STYLE_SOLID);
        
        color css = 0;
        
        if (swing)
        {
            if (style == Monochrome)
            {
                css = target_type[i] == 1 ? clrRGB(178, 181, 190) : clrRGB(93, 96, 107);
                ObjectSetInteger(0, "", OBJPROP_COLOR, target_type[i] == 1 ? clrRGB(178, 181, 190) : clrRGB(93, 96, 107));
            }
            else
            {
                css = target_type[i] == 1 ? bull_ob_css : bear_ob_css;
                ObjectSetInteger(0, "", OBJPROP_COLOR, target_type[i] == 1 ? bull_ob_css : bear_ob_css);
            }
            
            ObjectSetInteger(0, "", OBJPROP_COLOR, css);
            ObjectSetInteger(0, "", OBJPROP_BACK, css);
        }
        else
        {
            if (style == Monochrome)
            {
                css = target_type[i] == 1 ? clrRGB(178, 181, 190) : clrRGB(93, 96, 107);
            }
            else
            {
                css = target_type[i] == 1 ? ibull_ob_css : ibear_ob_css;
            }
            
            ObjectSetInteger(0, "", OBJPROP_COLOR, css);
            ObjectSetInteger(0, "", OBJPROP_BACK, css);
        }
    }
}

// Line Style function
int get_line_style(string style)
{
    int out = STYLE_SOLID;
    
    if (style == "⎯⎯⎯")
        out = STYLE_SOLID;
    else if (style == "----")
        out = STYLE_DASH;
    else if (style == "····")
        out = STYLE_DOT;
    
    return out;
}

// Set line/labels function for previous high/lows
void phl(double h, double l, ENUM_TIMEFRAMES tf, color css)
{
    ObjectCreate(0, "", OBJ_TREND);
    ObjectSetInteger(0, "", OBJPROP_STYLE, get_line_style(pdhl_style));
    ObjectSetInteger(0, "", OBJPROP_COLOR, css);
    ObjectSetDouble(0, "", OBJPROP_PRICE1, h);
    ObjectSetTime(0, "", OBJPROP_TIME1, Time[0]);
    ObjectSetDouble(0, "", OBJPROP_PRICE2, Time[0] + (Time[0] - Time[1]) * 20);
    
    ObjectCreate(0, "", OBJ_LABEL);
    ObjectSetInteger(0, "", OBJPROP_XDISTANCE, 0);
    ObjectSetInteger(0, "", OBJPROP_YDISTANCE, 0);
    ObjectSetInteger(0, "", OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetString(0, "", OBJPROP_TEXT, "P" + ENUM_TIMEFRAMES_NAME[tf] + "H");
    ObjectSetInteger(0, "", OBJPROP_COLOR, css);
    ObjectSetInteger(0, "", OBJPROP_FONTSIZE, SIZE_SMALL);
    ObjectSetDouble(0, "", OBJPROP_PRICE, h);

    ObjectCreate(0, "", OBJ_TREND);
    ObjectSetInteger(0, "", OBJPROP_STYLE, get_line_style(pdhl_style));
    ObjectSetInteger(0, "", OBJPROP_COLOR, css);
    ObjectSetDouble(0, "", OBJPROP_PRICE1, l);
    ObjectSetTime(0, "", OBJPROP_TIME1, Time[0]);
    ObjectSetDouble(0, "", OBJPROP_PRICE2, Time[0] + (Time[0] - Time[1]) * 20);
    
    ObjectCreate(0, "", OBJ_LABEL);
    ObjectSetInteger(0, "", OBJPROP_XDISTANCE, 0);
    ObjectSetInteger(0, "", OBJPROP_YDISTANCE, 0);
    ObjectSetInteger(0, "", OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetString(0, "", OBJPROP_TEXT, "P" + ENUM_TIMEFRAMES_NAME[tf] + "L");
    ObjectSetInteger(0, "", OBJPROP_COLOR, css);
    ObjectSetInteger(0, "", OBJPROP_FONTSIZE, SIZE_SMALL);
    ObjectSetDouble(0, "", OBJPROP_PRICE, l);
}

int trend = 0;
int itrend = 0;

double top_y = 0.0;
int top_x = 0;
double btm_y = 0.0;
int btm_x = 0;

double itop_y = 0.0;
int itop_x = 0;
double ibtm_y = 0.0;
int ibtm_x = 0;

double trail_up = High;
int trail_up_x = 0;
double trail_dn = Low;
int trail_dn_x = 0;

bool top_cross = true;
bool btm_cross = true;
bool itop_cross = true;
bool ibtm_cross = true;

string txt_top = "";
string txt_btm = "";

// Alerts
bool bull_choch_alert = false;
bool bull_bos_alert = false;
bool bear_choch_alert = false;
bool bear_bos_alert = false;
bool bull_ichoch_alert = false;
bool bull_ibos_alert = false;
bool bear_ichoch_alert = false;
bool bear_ibos_alert = false;
bool bull_iob_break = false;
bool bear_iob_break = false;
bool bull_ob_break = false;
bool bear_ob_break = false;
bool eqh_alert = false;
bool eql_alert = false;

// Structure colors
color bull_css = style == "Monochrome" ? clrRGB(178, 181, 190) : swing_bull_css;
color bear_css = style == "Monochrome" ? clrRGB(178, 181, 190) : swing_bear_css;
color ibull_css = style == "Monochrome" ? clrRGB(178, 181, 190) : swing_ibull_css;
color ibear_css = style == "Monochrome" ? clrRGB(178, 181, 190) : swing_ibear_css;

// Labels size
int internal_structure_lbl_size = internal_structure_size == "Tiny" ? SIZE_TINY :
    internal_structure_size == "Small" ? SIZE_SMALL : SIZE_NORMAL;
int swing_structure_lbl_size = swing_structure_size == "Tiny" ? SIZE_TINY :
    swing_structure_size == "Small" ? SIZE_SMALL : SIZE_NORMAL;
int eqhl_lbl_size = eq_size == "Tiny" ? SIZE_TINY :
    eq_size == "Small" ? SIZE_SMALL : SIZE_NORMAL;


//Swings
double top, btm;
swings(length, top, btm);

double itop, ibtm;
swings(5, itop, ibtm);

//-----------------------------------------------------------------------------}
//Pivot High
//-----------------------------------------------------------------------------{
int extend_top = -1;
int extend_top_lbl = -1;

if (top)
{
    top_cross = true;
    txt_top = top > top_y ? "HH" : "LH";

    if (show_swings)
    {
        extend_top_lbl = label.new(0, 0,
            txt_top,
            TRANSP_CSS,
            bear_css,
            label.style_label_down,
            swing_structure_lbl_size
        );

        if (mode == "Present")
            label.delete(extend_top_lbl[1]);
    }

    extend_top = line.new(n - length, top, n, top,
        bear_css
    );

    top_y = top;
    top_x = n - length;

    trail_up = top;
    trail_up_x = n - length;
}

if (itop)
{
    itop_cross = true;

    itop_y = itop;
    itop_x = n - 5;
}

//Trailing maximum
trail_up = MathMax(high, trail_up);
trail_up_x = trail_up == high ? n : trail_up_x;

//Set top extension label/line
if (barstate.islast && show_hl_swings)
{
    line.set_xy1(extend_top, trail_up_x, trail_up);
    line.set_xy2(extend_top, n + 20, trail_up);

    label.set_x(extend_top_lbl, n + 20);
    label.set_y(extend_top_lbl, trail_up);
    label.set_text(extend_top_lbl, trend < 0 ? "Strong High" : "Weak High");
}

//-----------------------------------------------------------------------------}
//Pivot Low
//-----------------------------------------------------------------------------{
int extend_btm = -1;
int extend_btm_lbl = -1;

if (btm)
{
    btm_cross = true;
    txt_btm = btm < btm_y ? "LL" : "HL";

    if (show_swings)
    {
        extend_btm_lbl = label.new(0, 0,
            txt_btm,
            TRANSP_CSS,
            bull_css,
            label.style_label_up,
            swing_structure_lbl_size
        );

        if (mode == "Present")
            label.delete(extend_btm_lbl[1]);
    }

    extend_btm = line.new(n - length, btm, n, btm,
        bull_css
    );

    btm_y = btm;
    btm_x = n - length;

    trail_dn = btm;
    trail_dn_x = n - length;
}

if (ibtm)
{
    ibtm_cross = true;

    ibtm_y = ibtm;
    ibtm_x = n - 5;
}

//Trailing minimum
trail_dn = MathMin(low, trail_dn);
trail_dn_x = trail_dn == low ? n : trail_dn_x;

//Set btm extension label/line
if (barstate.islast && show_hl_swings)
{
    line.set_xy1(extend_btm, trail_dn_x, trail_dn);
    line.set_xy2(extend_btm, n + 20, trail_dn);

    label.set_x(extend_btm_lbl, n + 20);
    label.set_y(extend_btm_lbl, trail_dn);
    label.set_text(extend_btm_lbl, trend > 0 ? "Strong Low" : "Weak Low");
}

//-----------------------------------------------------------------------------}
//Order Blocks Arrays
//-----------------------------------------------------------------------------{
double iob_top[];
double iob_btm[];
long iob_left[];
int iob_type[];

double ob_top[];
double ob_btm[];
long ob_left[];
int ob_type[];

//-----------------------------------------------------------------------------}
//Pivot High BOS/CHoCH
//-----------------------------------------------------------------------------{
bool bull_concordant = true;

if (ifilter_confluence)
    bull_concordant = high - MathMax(close, open) > MathMin(close, open - low);

//Detect internal bullish Structure
if (close > itop_y && itop_cross && top_y != itop_y && bull_concordant)
{
    bool choch = false;

    if (itrend < 0)
    {
        choch = true;
        bull_ichoch_alert = true;
    }
    else
    {
        bull_ibos_alert = true;
    }

    string txt = choch ? "CHoCH" : "BOS";

    if (show_internals)
    {
        if (show_ibull == "All" || (show_ibull == "BOS" && !choch) || (show_ibull == "CHoCH" && choch))
        {
            display_Structure(itop_x, itop_y, txt, ibull_css, true, true, internal_structure_lbl_size);
        }
    }

    itop_cross = false;
    itrend = 1;

    //Internal Order Block
    if (show_iob)
    {
        ob_coord(false, itop_x, iob_top, iob_btm, iob_left, iob_type);
    }
}

//Detect bullish Structure
if (close > top_y && top_cross)
{
    bool choch = false;

    if (trend < 0)
    {
        choch = true;
        bull_choch_alert = true;
    }
    else
    {
        bull_bos_alert = true;
    }

    string txt = choch ? "CHoCH" : "BOS";

    if (show_Structure)
    {
        if (show_bull == "All" || (show_bull == "BOS" && !choch) || (show_bull == "CHoCH" && choch))
        {
            display_Structure(top_x, top_y, txt, bull_css, false, true, swing_structure_lbl_size);
        }
    }

    //Order Block
    if (show_ob)
    {
        ob_coord(false, top_x, ob_top, ob_btm, ob_left, ob_type);
    }

    top_cross = false;
    trend = 1;
}

//-----------------------------------------------------------------------------}
//Pivot Low BOS/CHoCH
//-----------------------------------------------------------------------------{
bool bear_concordant = true;

if (ifilter_confluence)
    bear_concordant = high - MathMax(close, open) < MathMin(close, open - low);

//Detect internal bearish Structure
if (close < ibtm_y && ibtm_cross && btm_y != ibtm_y && bear_concordant)
{
    bool choch = false;

    if (itrend > 0)
    {
        choch = true;
        bear_ichoch_alert = true;
    }
    else
    {
        bear_ibos_alert = true;
    }

    string txt = choch ? "CHoCH" : "BOS";

    if (show_internals)
    {
        if (show_ibear == "All" || (show_ibear == "BOS" && !choch) || (show_ibear == "CHoCH" && choch))
        {
            display_Structure(ibtm_x, ibtm_y, txt, ibear_css, true, false, internal_structure_lbl_size);
        }
    }

    ibtm_cross = false;
    itrend = -1;

    //Internal Order Block
    if (show_iob)
    {
        ob_coord(true, ibtm_x, iob_top, iob_btm, iob_left, iob_type);
    }
}

//Detect bearish Structure
if (close < btm_y && btm_cross)
{
    bool choch = false;

    if (trend > 0)
    {
        choch = true;
        bear_choch_alert = true;
    }
    else
    {
        bear_bos_alert = true;
    }

    string txt = choch ? "CHoCH" : "BOS";

    if (show_Structure)
    {
        if (show_bear == "All" || (show_bear == "BOS" && !choch) || (show_bear == "CHoCH" && choch))
        {
            display_Structure(btm_x, btm_y, txt, bear_css, false, false, swing_structure_lbl_size);
        }
    }

    //Order Block
    if (show_ob)
    {
        ob_coord(true, btm_x, ob_top, ob_btm, ob_left, ob_type);
    }

    btm_cross = false;
    trend = -1;
}

//-----------------------------------------------------------------------------}
//Order Blocks
//-----------------------------------------------------------------------------{
//Set order blocks
int iob_boxes[];
int ob_boxes[];

//Delete internal order blocks box coordinates if top/bottom is broken
for (int i = 0; i < ArraySize(iob_type); i++)
{
    if (close < iob_btm[i] && iob_type[i] == 1)
    {
        ArrayResize(iob_top, ArraySize(iob_top) - 1);
        ArrayResize(iob_btm, ArraySize(iob_btm) - 1);
        ArrayResize(iob_left, ArraySize(iob_left) - 1);
        ArrayResize(iob_type, ArraySize(iob_type) - 1);
        bull_iob_break = true;
    }
    else if (close > iob_top[i] && iob_type[i] == -1)
    {
        ArrayResize(iob_top, ArraySize(iob_top) - 1);
        ArrayResize(iob_btm, ArraySize(iob_btm) - 1);
        ArrayResize(iob_left, ArraySize(iob_left) - 1);
        ArrayResize(iob_type, ArraySize(iob_type) - 1);
        bear_iob_break = true;
    }
}

//Delete internal order blocks box coordinates if top/bottom is broken
for (int i = 0; i < ArraySize(ob_type); i++)
{
    if (close < ob_btm[i] && ob_type[i] == 1)
    {
        ArrayResize(ob_top, ArraySize(ob_top) - 1);
        ArrayResize(ob_btm, ArraySize(ob_btm) - 1);
        ArrayResize(ob_left, ArraySize(ob_left) - 1);
        ArrayResize(ob_type, ArraySize(ob_type) - 1);
        bull_ob_break = true;
    }
    else if (close > ob_top[i] && ob_type[i] == -1)
    {
        ArrayResize(ob_top, ArraySize(ob_top) - 1);
        ArrayResize(ob_btm, ArraySize(ob_btm) - 1);
        ArrayResize(ob_left, ArraySize(ob_left) - 1);
        ArrayResize(ob_type, ArraySize(ob_type) - 1);
        bear_ob_break = true;
    }
}

int iob_size = ArraySize(iob_type);
int ob_size = ArraySize(ob_type);

if (barstate.isfirst)
{
    if (show_iob)
    {
        for (int i = 0; i < iob_showlast; i++)
        {
            ArrayResize(iob_boxes, ArraySize(iob_boxes) + 1);
        }
    }

    if (show_ob)
    {
        for (int i = 0; i < ob_showlast; i++)
        {
            ArrayResize(ob_boxes, ArraySize(ob_boxes) + 1);
        }
    }
}

if (iob_size > 0)
{
    if (barstate.islast)
    {
        display_ob(iob_boxes, iob_top, iob_btm, iob_left, iob_type, iob_showlast, false, iob_size);
    }
}

if (ob_size > 0)
{
    if (barstate.islast)
    {
        display_ob(ob_boxes, ob_top, ob_btm, ob_left, ob_type, ob_showlast, true, ob_size);
    }
}

//-----------------------------------------------------------------------------}
//EQH/EQL
//-----------------------------------------------------------------------------{
double eq_prev_top = 0.0;
int eq_top_x = 0;

double eq_prev_btm = 0.0;
int eq_btm_x = 0;

if (show_eq)
{
    double eq_top = ta.pivothigh(eq_len, eq_len);
    double eq_btm = ta.pivotlow(eq_len, eq_len);

    if (eq_top)
    {
        double max = MathMax(eq_top, eq_prev_top);
        double min = MathMin(eq_top, eq_prev_top);

        if (max < min + atr * eq_threshold)
        {
            int eqh_line = line.new(eq_top_x, eq_prev_top, n - eq_len, eq_top,
                bear_css,
                line.style_dotted
            );

            int eqh_lbl = label.new((n - eq_len + eq_top_x) / 2, eq_top, "EQH",
                TRANSP_CSS,
                bear_css,
                label.style_label_down,
                eqhl_lbl_size
            );

            if (mode == "Present")
            {
                line.delete(eqh_line);
                label.delete(eqh_lbl);
            }

            eqh_alert = true;
        }

        eq_prev_top = eq_top;
        eq_top_x = n - eq_len;
    }

    if (eq_btm)
    {
        double max = MathMax(eq_btm, eq_prev_btm);
        double min = MathMin(eq_btm, eq_prev_btm);

        if (min > max - atr * eq_threshold)
        {
            int eql_line = line.new(eq_btm_x, eq_prev_btm, n - eq_len, eq_btm,
                bull_css,
                line.style_dotted
            );

            int eql_lbl = label.new((n - eq_len + eq_btm_x) / 2, eq_btm, "EQL",
                TRANSP_CSS,
                bull_css,
                label.style_label_up,
                eqhl_lbl_size
            );

            eql_alert = true;

            if (mode == "Present")
            {
                line.delete(eql_line);
                label.delete(eql_lbl);
            }
        }

        eq_prev_btm = eq_btm;
        eq_btm_x = n - eq_len;
    }
}

//-----------------------------------------------------------------------------}
//Fair Value Gaps
//-----------------------------------------------------------------------------{
int bullish_fvg_max[];
int bullish_fvg_min[];

int bearish_fvg_max[];
int bearish_fvg_min[];

double bullish_fvg_avg = 0.0;
double bearish_fvg_avg = 0.0;

bool bullish_fvg_cnd = false;
bool bearish_fvg_cnd = false;

double[] src_c1, src_o1, src_h, src_l, src_h2, src_l2;
request.security(syminfo.tickerid, fvg_tf, get_ohlc(), out src_c1, out src_o1, out src_h, out src_l, out src_h2, out src_l2);

if (show_fvg)
{
    double delta_per = (src_c1 - src_o1) / src_o1 * 100.0;

    int change_tf = timeframe.change(fvg_tf);

    double threshold = fvg_auto ? ta.cum(change_tf != 0 ? MathAbs(delta_per) : 0.0) / n * 2 : 0.0;

    //FVG conditions
    bullish_fvg_cnd = src_l > src_h2
        && src_c1 > src_h2
        && delta_per > threshold
        && change_tf != 0;

    bearish_fvg_cnd = src_h < src_l2
        && src_c1 < src_l2
        && -delta_per > threshold
        && change_tf != 0;

    //FVG Areas
    if (bullish_fvg_cnd)
    {
        ArrayUnshift(bullish_fvg_max, box.new(n - 1, src_l, n + fvg_extend, MathAvg(src_l, src_h2),
            bull_fvg_css,
            bull_fvg_css
        ));

        ArrayUnshift(bullish_fvg_min, box.new(n - 1, MathAvg(src_l, src_h2), n + fvg_extend, src_h2,
            bull_fvg_css,
            bull_fvg_css
        ));
    }

    if (bearish_fvg_cnd)
    {
        ArrayUnshift(bearish_fvg_max, box.new(n - 1, src_h, n + fvg_extend, MathAvg(src_h, src_l2),
            bear_fvg_css,
            bear_fvg_css
        ));

        ArrayUnshift(bearish_fvg_min, box.new(n - 1, MathAvg(src_h, src_l2), n + fvg_extend, src_l2,
            bear_fvg_css,
            bear_fvg_css
        ));
    }

    for (int i = ArraySize(bullish_fvg_min) - 1; i >= 0; i--)
    {
        if (low < box.get_bottom(bullish_fvg_min[i]))
        {
            box.delete(bullish_fvg_min[i]);
            box.delete(bullish_fvg_max[i]);
        }
    }

    for (int i = ArraySize(bearish_fvg_max) - 1; i >= 0; i--)
    {
        if (high > box.get_top(bearish_fvg_max[i]))
        {
            box.delete(bearish_fvg_max[i]);
            box.delete(bearish_fvg_min[i]);
        }
    }
}

//-----------------------------------------------------------------------------}
//Previous day/week high/lows
//-----------------------------------------------------------------------------{
//Daily high/low
var pdh = na;
var pdl = na;
request.security(syminfo.tickerid, "D", hl(), lookahead = barmerge.lookahead_on, out pdh, out pdl);

//Weekly high/low
var pwh = na;
var pwl = na;
request.security(syminfo.tickerid, "W", hl(), lookahead = barmerge.lookahead_on, out pwh, out pwl);

//Monthly high/low
var pmh = na;
var pml = na;
request.security(syminfo.tickerid, "M", hl(), lookahead = barmerge.lookahead_on, out pmh, out pml);

//Display Daily
if (show_pdhl)
{
    phl(pdh, pdl, "D", pdhl_css);
}

//Display Weekly
if (show_pwhl)
{
    phl(pwh, pwl, "W", pwhl_css);
}

//Display Monthly
if (show_pmhl)
{
    phl(pmh, pml, "M", pmhl_css);
}

//-----------------------------------------------------------------------------}
//Premium/Discount/Equilibrium zones
//-----------------------------------------------------------------------------{
var premium = box.new(na, na, na, na,
    color.new(premium_css, 80),
    na
);

var premium_lbl = label.new(na, na,
    "Premium",
    TRANSP_CSS,
    premium_css,
    label.style_label_down,
    size.small
);

var eq = box.new(na, na, na, na,
    color.rgb(120, 123, 134, 80),
    na
);

var eq_lbl = label.new(na, na,
    "Equilibrium",
    TRANSP_CSS,
    eq_css,
    label.style_label_left,
    size.small
);

var discount = box.new(na, na, na, na,
    color.new(discount_css, 80),
    na
);

var discount_lbl = label.new(na, na,
    "Discount",
    TRANSP_CSS,
    discount_css,
    label.style_label_up,
    size.small
);

//Show Premium/Discount Areas
if (barstate.islast && show_sd)
{
    double avg = math.avg(trail_up, trail_dn);

    box.set(premium, MathMax(top_x, btm_x), trail_up, n, .95 * trail_up + .05 * trail_dn);
    label.set_xy(premium_lbl, int(math.avg(MathMax(top_x, btm_x), n)), trail_up);

    box.set(eq, MathMax(top_x, btm_x), .525 * trail_up + .475 * trail_dn, n, .525 * trail_dn + .475 * trail_up);
    label.set_xy(eq_lbl, n, avg);

    box.set(discount, MathMax(top_x, btm_x), .95 * trail_dn + .05 * trail_up, n, trail_dn);
    label.set_xy(discount_lbl, int(math.avg(MathMax(top_x, btm_x), n)), trail_dn);
}

//-----------------------------------------------------------------------------}
//Plotting
//-----------------------------------------------------------------------------{
if (show_swings && barstate.islast)
{
    label.set_xy(extend_top_lbl, n + 20, trail_up);
    label.set_xy(extend_btm_lbl, n + 20, trail_dn);

    line.set_xy1(extend_top, trail_up_x, trail_up);
    line.set_xy2(extend_top, n + 20, trail_up);

    line.set_xy1(extend_btm, trail_dn_x, trail_dn);
    line.set_xy2(extend_btm, n + 20, trail_dn);
}

//Alerts
if (bull_ichoch_alert || bull_ibos_alert || bull_choch_alert || bull_bos_alert)
{
    alert("Bullish Structure Alert", alert.freq_once_per_bar);
}

if (bear_ichoch_alert || bear_ibos_alert || bear_choch_alert || bear_bos_alert)
{
    alert("Bearish Structure Alert", alert.freq_once_per_bar);
}

if (eqh_alert)
{
    alert("EQH Alert", alert.freq_once_per_bar);
}

if (eql_alert)
{
    alert("EQL Alert", alert.freq_once_per_bar);
}

if (bull_iob_break)
{
    alert("Bullish Internal Order Block Break", alert.freq_once_per_bar);
}

if (bear_iob_break)
{
    alert("Bearish Internal Order Block Break", alert.freq_once_per_bar);
}

if (bull_ob_break)
{
    alert("Bullish Order Block Break", alert.freq_once_per_bar);
}

if (bear_ob_break)
{
    alert("Bearish Order Block Break", alert.freq_once_per_bar);
}

//-----------------------------------------------------------------------------}
//Functions
//-----------------------------------------------------------------------------{
double atr(int period)
{
    double tr = MathMax(high - low, MathMax(MathAbs(high - close[1]), MathAbs(low - close[1])));
    return ta.sma(tr, period);
}

void swings(int period, out double top, out double btm)
{
    double ath = ta.highest(high, period);
    double atl = ta.lowest(low, period);

    top = ath > high[period] ? ath : na;
    btm = atl < low[period] ? atl : na;
}

void display_Structure(int x, double y, string txt, color cl, bool internal, bool bullish, int size)
{
    if (internal)
    {
        if (bullish)
        {
            label.new(x, y, txt, TRANSP_CSS, cl, label.style_label_up, size);
        }
        else
        {
            label.new(x, y, txt, TRANSP_CSS, cl, label.style_label_down, size);
        }
    }
    else
    {
        label.new(x, y, txt, TRANSP_CSS, cl, size = size);
    }
}

void ob_coord(bool bear, int x, double[] top, double[] btm, long[] left, int[] type)
{
    double p;

    if (bear)
    {
        p = btm_y;
    }
    else
    {
        p = top_y;
    }

    ArrayPush(top, p);
    ArrayPush(btm, bear ? btm_y : top_y);
    ArrayPush(left, x);
    ArrayPush(type, bear ? 1 : -1);
}

void display_ob(int[] boxes, double[] top, double[] btm, long[] left, int[] type, int showlast, bool bear, int size)
{
    for (int i = 0; i < ArraySize(boxes); i++)
    {
        int j = ArraySize(boxes) - 1 - i;

        if (j < size)
        {
            double h = bear ? btm[j] : top[j];
            double l = bear ? top[j] : btm[j];

            int cl = bear ? bear_ob_css : bull_ob_css;
            int bg = bear ? bear_ob_css : bull_ob_css;

            box.set(boxes[i], left[j], l, n, h, cl, bg);
        }
    }

    for (int i = 0; i < ArraySize(boxes); i++)
    {
        if (i < ArraySize(boxes) - showlast)
        {
            box.delete(boxes[i]);
        }
    }
}

void phl(var high_low, var low_high, string type, color cl)
{
    if (high_low != na)
    {
        if (type == "D")
        {
            int cl_d = color.rgb(color.rgb(cl), 120);
            line.set_xy1(pdh_l, n - 1, high_low);
            line.set_xy2(pdh_l, n + 1, high_low);
            label.set_xy(pdh_l_lbl, n + 1, high_low);
            label.set_text(pdh_l_lbl, "PDH");
            label.set_color(pdh_l_lbl, cl_d);

            line.set_xy1(pdl_l, n - 1, low_high);
            line.set_xy2(pdl_l, n + 1, low_high);
            label.set_xy(pdl_l_lbl, n + 1, low_high);
            label.set_text(pdl_l_lbl, "PDL");
            label.set_color(pdl_l_lbl, cl_d);
        }

        if (type == "W")
        {
            int cl_w = color.rgb(color.rgb(cl), 140);
            line.set_xy1(pwh_l, n - 1, high_low);
            line.set_xy2(pwh_l, n + 1, high_low);
            label.set_xy(pwh_l_lbl, n + 1, high_low);
            label.set_text(pwh_l_lbl, "PWH");
            label.set_color(pwh_l_lbl, cl_w);

            line.set_xy1(pwl_l, n - 1, low_high);
            line.set_xy2(pwl_l, n + 1, low_high);
            label.set_xy(pwl_l_lbl, n + 1, low_high);
            label.set_text(pwl_l_lbl, "PWL");
            label.set_color(pwl_l_lbl, cl_w);
        }

        if (type == "M")
        {
            int cl_m = color.rgb(color.rgb(cl), 160);
            line.set_xy1(pmh_l, n - 1, high_low);
            line.set_xy2(pmh_l, n + 1, high_low);
            label.set_xy(pmh_l_lbl, n + 1, high_low);
            label.set_text(pmh_l_lbl, "PMH");
            label.set_color(pmh_l_lbl, cl_m);

            line.set_xy1(pml_l, n - 1, low_high);
            line.set_xy2(pml_l, n + 1, low_high);
            label.set_xy(pml_l_lbl, n + 1, low_high);
            label.set_text(pml_l_lbl, "PML");
            label.set_color(pml_l_lbl, cl_m);
        }
    }
}
