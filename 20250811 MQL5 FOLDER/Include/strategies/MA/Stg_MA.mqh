/**
 * @file
 * Implements MA strategy based the Moving Average indicator.
 */

// User params.
INPUT_GROUP("MA strategy: strategy params");
INPUT float MA_LotSize = 0;                // Lot size
INPUT int MA_SignalOpenMethod = 0;         // Signal open method (-127-127)
INPUT float MA_SignalOpenLevel = 0.04f;    // Signal open level
INPUT int MA_SignalOpenFilterMethod = 32;  // Signal open filter method
INPUT int MA_SignalOpenFilterTime = 3;     // Signal open filter time
INPUT int MA_SignalOpenBoostMethod = 0;    // Signal open boost method
INPUT int MA_SignalCloseMethod = 0;        // Signal close method (-127-127)
INPUT int MA_SignalCloseFilter = 0;        // Signal close filter (-127-127)
INPUT float MA_SignalCloseLevel = 0.04f;   // Signal close level
INPUT int MA_PriceStopMethod = 1;          // Price stop method (0-127)
INPUT float MA_PriceStopLevel = 2;         // Price stop level
INPUT int MA_TickFilterMethod = 32;        // Tick filter method
INPUT float MA_MaxSpread = 4.0;            // Max spread to trade (pips)
INPUT short MA_Shift = 0;                  // Shift
INPUT float MA_OrderCloseLoss = 80;        // Order close loss
INPUT float MA_OrderCloseProfit = 80;      // Order close profit
INPUT int MA_OrderCloseTime = -30;         // Order close time in mins (>0) or bars (<0)
INPUT_GROUP("MA strategy: MA indicator params");
INPUT int MA_Indi_MA_Period = 40;                                // Period
INPUT int MA_Indi_MA_MA_Shift = 0;                               // MA Shift
INPUT ENUM_MA_METHOD MA_Indi_MA_Method = (ENUM_MA_METHOD)3;      // MA Method
INPUT ENUM_APPLIED_PRICE MA_Indi_MA_Applied_Price = PRICE_OPEN;  // Applied Price
INPUT int MA_Indi_MA_Shift = 0;                                  // Shift

// Structs.

// Defines struct with default user strategy values.
struct Stg_MA_Params_Defaults : StgParams {
  Stg_MA_Params_Defaults()
      : StgParams(::MA_SignalOpenMethod, ::MA_SignalOpenFilterMethod, ::MA_SignalOpenLevel, ::MA_SignalOpenBoostMethod,
                  ::MA_SignalCloseMethod, ::MA_SignalCloseFilter, ::MA_SignalCloseLevel, ::MA_PriceStopMethod,
                  ::MA_PriceStopLevel, ::MA_TickFilterMethod, ::MA_MaxSpread, ::MA_Shift) {
    Set(STRAT_PARAM_LS, MA_LotSize);
    Set(STRAT_PARAM_OCL, MA_OrderCloseLoss);
    Set(STRAT_PARAM_OCP, MA_OrderCloseProfit);
    Set(STRAT_PARAM_OCT, MA_OrderCloseTime);
    Set(STRAT_PARAM_SOFT, MA_SignalOpenFilterTime);
  }
};

#ifdef __config__
// Loads pair specific param values.
#include "config/H1.h"
#include "config/H4.h"
#include "config/H8.h"
#include "config/M1.h"
#include "config/M15.h"
#include "config/M30.h"
#include "config/M5.h"
#endif

class Stg_MA : public Strategy {
 public:
  Stg_MA(StgParams &_sparams, TradeParams &_tparams, ChartParams &_cparams, string _name = "")
      : Strategy(_sparams, _tparams, _cparams, _name) {}

  static Stg_MA *Init(ENUM_TIMEFRAMES _tf = NULL) {
    // Initialize strategy initial values.
    Stg_MA_Params_Defaults stg_ma_defaults;
    StgParams _stg_params(stg_ma_defaults);
#ifdef __config__
    SetParamsByTf<StgParams>(_stg_params, _tf, stg_ma_m1, stg_ma_m5, stg_ma_m15, stg_ma_m30, stg_ma_h1, stg_ma_h4,
                             stg_ma_h8);
#endif
    // Initialize indicator.
    // Initialize Strategy instance.
    ChartParams _cparams(_tf, _Symbol);
    TradeParams _tparams;
    Strategy *_strat = new Stg_MA(_stg_params, _tparams, _cparams, "MA");
    return _strat;
  }

  /**
   * Event on strategy's init.
   */
  void OnInit() {
    IndiMAParams _indi_params(::MA_Indi_MA_Period, ::MA_Indi_MA_MA_Shift, ::MA_Indi_MA_Method,
                              ::MA_Indi_MA_Applied_Price, ::MA_Indi_MA_Shift);
    _indi_params.SetTf(Get<ENUM_TIMEFRAMES>(STRAT_PARAM_TF));
    SetIndicator(new Indi_MA(_indi_params));
  }

  /**
   * Check strategy's opening signal.
   */
  bool SignalOpen(ENUM_ORDER_TYPE _cmd, int _method = 0, float _level = 0.0f, int _shift = 0) {
    Indi_MA *_indi = GetIndicator();
    bool _result =
        _indi.GetFlag(INDI_ENTRY_FLAG_IS_VALID, _shift) && _indi.GetFlag(INDI_ENTRY_FLAG_IS_VALID, _shift + 1);
    if (!_result) {
      // Returns false when indicator data is not valid.
      return false;
    }
    IndicatorSignal _signals = _indi.GetSignals(4, _shift);
    switch (_cmd) {
      case ORDER_TYPE_BUY:
        _result &= _indi.IsIncreasing(2, 0, _shift);
        _result &= _indi.IsIncByPct(_level, 0, _shift, 3);
        _result &= _method > 0 ? _signals.CheckSignals(_method) : _signals.CheckSignalsAll(-_method);
        break;
      case ORDER_TYPE_SELL:
        _result &= _indi.IsDecreasing(2, 0, _shift);
        _result &= _indi.IsDecByPct(-_level, 0, _shift, 3);
        _result &= _method > 0 ? _signals.CheckSignals(_method) : _signals.CheckSignalsAll(-_method);
        break;
    }
    return _result;
  }
};
