#include  <Ossi\LongTails\Utils.mqh>

double Sequence[]={0.01, 0.01, 0.02, 0.02, 0.03, 0.04, 0.05, 0.07, 0.09, 0.12, 0.16, 0.22, 0.29, 0.39, 0.52, 0.69, 0.92, 1.23, 1.64, 2.18};
bool use_trading_session = false; // trade 24/7
datetime session_start = StringToTime("08:30");
datetime session_end = StringToTime("18:30");// test server time = real time +1
int session_status;
double grid_unit = 2.0;
double grid_spread = 0.4;
int LTSMultiplier = 3;
CTrade trade;

//+------------------------------------------------------------------+
// Perform Sanity Checks
// Initialize Ctrade, check all tests, must init deviation, etc.

class LTSControl(){
public:// XXX: Dont encapsulate, allow full scope for this project
    //private sequence
    //predefined sequenceLength

    // initialize GridInfo Grid, and GridBase Base

    void start(){
        
        Grid.Init(grid_unit, grid_spread, LTSMultiplier);
        build_sequence(Grid.multiplier, Grid.progression_sequence);
        Base.ticket = 0; // default (rule 7)
        Base.type = POSITION_TYPE_BUY;

        // start Grid
        if (use_trading_session && !IsWithinTradingTime()) return init succesful; // Handles placing EA on chart, outside trading time
        
        /*if (!IsEmptyChart) // Prod
            {
                Print("Failed to start grid, please clear all orders and close all positions on the current chart");
                return init error, error message "unable to start grid";
            }
        */
        if (!PositionSelect(_Symbol)) 
        {
        ulong ticket = OpenShort(Grid.progression_sequence[0], trade);
        if (ticket) 
            {
                Base.UpdateGridBase(ticket);
                Print(__FUNCTION__, ": Started trading session with short at market price");   
            }
        else return init error, error message "unable to start grid short";
        }
    }

    void Manage(){  
        // return irrelevant ticket
        if(use_trading_session && session_status == SESSION_OVER && IsEmptyChart) return;

        // manage mismanagement ☑️
        check_strategy_rules();

        // Track grid motion
        if (IsNewPosition(Base.ticket)) 
            HandleNewPosition(Base, Grid);   
        HandleGridGap(Grid, Base, trade);
        
        // Track Trading Session
        if (use_trading_session)
        {
            UpdateSesionStatus(Grid);
            if (Grid.session_status == SESSION_OVER) 
                HandleSessionEnd(trade, Grid);
            else StartSession(sequence, EA_TAG);
        }
    }

    void Stop(){
        Print("Logging off...");
        // Log stuff
        // profit or loss
    }
};