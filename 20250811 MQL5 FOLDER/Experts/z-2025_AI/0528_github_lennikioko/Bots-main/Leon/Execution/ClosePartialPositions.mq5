//+------------------------------------------------------------------+
//|                                           ClosePartialPositions.mq5 |
//|                                  Copyright 2024, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property script_show_inputs

#include <Trade/Trade.mqh>

// Input parameters
input double CloseRatio = 0.5;        // Ratio to close (1.0 = full position)

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
{
    CTrade trade;

    // Check if ratio is valid
    if(CloseRatio <= 0 || CloseRatio > 1) {
        MessageBox("Close ratio must be between 0 and 1", "Invalid Input");
        return;
    }

    // Get symbol volume constraints
    double minVolume = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double maxVolume = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    double volumeStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

    if(minVolume == 0 || maxVolume == 0 || volumeStep == 0) {
        Print("Error getting symbol volume information");
        return;
    }

    // Iterate through all positions
    for(int i = PositionsTotal() - 1; i >= 0; i--) {
        ulong ticket = PositionGetTicket(i);

        if(ticket <= 0) continue;

        // Only process positions for current symbol
        if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;

        // Get position volume
        double positionVolume = PositionGetDouble(POSITION_VOLUME);

        // Calculate volume to close based on ratio and round to nearest volume step
        double rawVolumeToClose = positionVolume * CloseRatio;
        double volumeToClose = MathRound(rawVolumeToClose / volumeStep) * volumeStep;
        volumeToClose = NormalizeDouble(volumeToClose, 2);

        // Calculate remaining volume after close
        double remainingVolume = positionVolume - volumeToClose;

        // If closing would leave less than minimum volume or ratio is 1, close full position
        if(CloseRatio >= 1.0 || remainingVolume < minVolume || MathAbs(remainingVolume - minVolume) < volumeStep/2) {
            if(trade.PositionClose(ticket)) {
                Print("Closed full position ", ticket, " (", positionVolume, " lots)");
            } else {
                Print("Failed to close position ", ticket, ". Error: ", GetLastError());
            }
        }
        // Close partial position if the volume to close is valid
        else if(volumeToClose >= minVolume && volumeToClose <= maxVolume) {
            if(trade.PositionClosePartial(ticket, volumeToClose)) {
                Print("Closed partial position ", ticket, " (", volumeToClose, " of ", positionVolume, " lots)");
            } else {
                Print("Failed to close partial position ", ticket, ". Error: ", GetLastError());
            }
        } else {
            Print("Invalid volume to close for ticket ", ticket, ": ", volumeToClose,
                  " (Min: ", minVolume, ", Max: ", maxVolume, ", Step: ", volumeStep, ")");
        }
    }
}
//+------------------------------------------------------------------+