//+------------------------------------------------------------------+
//|                  EA31337 - multi-strategy advanced trading robot |
//|                                 Copyright 2016-2022, EA31337 Ltd |
//|                                       https://github.com/EA31337 |
//+------------------------------------------------------------------+

// Sets EA mode (Lite, Advanced or Rider).
#include "common/mode.h"

// Includes common files.
#include "common/code-conf.h"
#include "common/define.h"
#include "common/enum.h"

// Includes class files.
#include "EA31337-classes/Action.struct.h"
#include "EA31337-classes/Chart.mqh"
#include "EA31337-classes/Condition.mqh"
#include "EA31337-classes/Condition.struct.h"
#include "EA31337-classes/EA.mqh"
#include "EA31337-classes/Msg.mqh"
#include "EA31337-classes/Terminal.mqh"
#include "EA31337-classes/Trade.mqh"

// Includes common EA's functions.
#ifdef __advanced__
// Includes common EA actions.
#include "common/funcs-adv.h"
#endif

// Includes indicator classes.
#include "EA31337-classes/Indicators/Bitwise/indicators.h"
#include "EA31337-classes/Indicators/Price/indicators.h"
#include "EA31337-classes/Indicators/Special/indicators.h"
#include "EA31337-classes/Indicators/indicators.h"

// EA structs.
#include "common/struct.h"

// Strategy enums.
#include "strategies/enum.h"

// Main user inputs.
#include "inputs.h"

// Strategy includes.
INPUT_GROUP("Strategy parameters");  // >>> STRATEGIES <<<
#include "strategies/strategies.h"
