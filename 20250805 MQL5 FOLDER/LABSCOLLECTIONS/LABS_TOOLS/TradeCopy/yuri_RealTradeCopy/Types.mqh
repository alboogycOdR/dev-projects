//+------------------------------------------------------------------+
//|                                                        Types.mq5 |
//|                                      Copyright 2022, Yuriy Bykov |
//|                     https://www.mql5.com/ru/market/product/73910 |
//|                     https://www.mql5.com/ru/market/product/73913 |
//+------------------------------------------------------------------+

enum ENUM_RTC_MODE {
   RTC_MODE_SENDER,    // SENDER ->
   RTC_MODE_RECEIVER,  // -> RECEIVER
   RTC_MODE_SELFCOPY   // SELF<->COPY
};

enum ENUM_RTC_UPDATE_MODE {
   RTC_UPDATE_MODE_TIMER_200,    // Very Fast Timer (every 200 ms)
   RTC_UPDATE_MODE_TIMER_500,    // Fast Timer (every 500 ms)
   RTC_UPDATE_MODE_TIMER_1000,   // Medium Timer (every 1000 ms)
   RTC_UPDATE_MODE_TICK,         // Every Tick
};

enum ENUM_RTC_STATUS {
   RTC_STATUS_OK,
   RTC_STATUS_CORRECTING,
   RTC_STATUS_WAIT_FILE,
   RTC_STATUS_WAIT_FILE_ERROR,
   RTC_STATUS_WAIT_FILE_VERSION,
   RTC_STATUS_WAIT_TRADING,
   RTC_STATUS_WAIT_MARKET,
   RTC_STATUS_PARAMETERS_INCORRECT,
};

enum ENUM_RTC_VOLUME_CONVERSION_TYPE {
   RTC_VOLUME_CONVERSION_TYPE_CALC_BLR,   // Use balances, leverage and ratio: R_vol = S_vol * Ratio * (R_bal / S_bal) * (R_lev / S_lev)
   RTC_VOLUME_CONVERSION_TYPE_CALC_BR,    // Use balances and ratio: R_vol = S_vol * Ratio * (R_bal / S_bal)
   RTC_VOLUME_CONVERSION_TYPE_FIXED,      // Use fixed ratio:              R_vol = S_vol * Ratio
};

enum ENUM_RTC_COPY_TYPE {
   RTC_COPY_TYPE_VOLUMES,    // Total VOLUME of positions for each symbol
   RTC_COPY_TYPE_POSITIONS,  // Each POSITION
};
