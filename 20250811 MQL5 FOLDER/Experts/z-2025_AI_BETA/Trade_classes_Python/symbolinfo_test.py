import MetaTrader5 as mt5
from Trade.SymbolInfo import CSymbolInfo


if not mt5.initialize(r"c:\Users\Omega Joctan\AppData\Roaming\Pepperstone MetaTrader 5\terminal64.exe"):
    print("Failed to initialize Metatrader5 Error = ",mt5.last_error())
    quit()
      
m_symbol = CSymbolInfo("EURUSD")

print(f"""
Symbol Information
---------------------
Name: {m_symbol.name()}
Selected: {m_symbol.select()}
Synchronized: {m_symbol.is_synchronized()}

--- Volumes ---
Volume: {m_symbol.volume()}
Volume High: {m_symbol.volume_high()}
Volume Low: {m_symbol.volume_low()}

--- Time & Spread ---
Time: {m_symbol.time()}
Spread: {m_symbol.spread()}
Spread Float: {m_symbol.spread_float()}
Ticks Book Depth: {m_symbol.ticks_book_depth()}

--- Trade Levels ---
Stops Level: {m_symbol.stops_level()}
Freeze Level: {m_symbol.freeze_level()}

--- Bid Parameters ---
Bid: {m_symbol.bid()}
Bid High: {m_symbol.bid_high()}
Bid Low: {m_symbol.bid_low()}

--- Ask Parameters ---
Ask: {m_symbol.ask()}
Ask High: {m_symbol.ask_high()}
Ask Low: {m_symbol.ask_low()}

--- Last Parameters ---
Last: {m_symbol.last()}
Last High: {m_symbol.last_high()}
Last Low: {m_symbol.last_low()}

--- Order & Trade Modes ---
Trade Calc Mode: {m_symbol.trade_calc_mode()} ({m_symbol.trade_calc_mode_description()})
Trade Mode: {m_symbol.trade_mode()} ({m_symbol.trade_mode_description()})
Trade Execution Mode: {m_symbol.trade_execution()}  ({m_symbol.trade_execution_description()})

--- Swap Terms ---
Swap Mode: {m_symbol.swap_mode()} ({m_symbol.swap_mode_description()})
Swap Rollover 3 Days: {m_symbol.swap_rollover_3days()} ({m_symbol.swap_rollover_3days_description()})

--- Futures Dates ---
Start Time: {m_symbol.start_time()}
Expiration Time: {m_symbol.expiration_time()}

--- Margin Parameters ---
Initial Margin: {m_symbol.margin_initial()}
Maintenance Margin: {m_symbol.margin_maintenance()}
Hedged Margin: {m_symbol.margin_hedged()}
Hedged Margin Use Leg: {m_symbol.margin_hedged_use_leg()}

--- Tick Info ---

Digits: {m_symbol.digits()}
Point: {m_symbol.point()}
Tick Value: {m_symbol.tick_value()}
Tick Value Profit: {m_symbol.tick_value_profit()}
Tick Value Loss: {m_symbol.tick_value_loss()}
Tick Size: {m_symbol.tick_size()}

--- Contracts sizes---
Contract Size: {m_symbol.contract_size()}
Lots Min: {m_symbol.lots_min()}
Lots Max: {m_symbol.lots_max()}
Lots Step: {m_symbol.lots_step()}
Lots Limit: {m_symbol.lots_limit()}

--- Swap sizes 

Swap Long: {m_symbol.swap_long()}
Swap Short: {m_symbol.swap_short()}

--- Currency Info ---
Currency Base: {m_symbol.currency_base()}
Currency Profit: {m_symbol.currency_profit()}
Currency Margin: {m_symbol.currency_margin()}
Bank: {m_symbol.bank()}
Description: {m_symbol.description()}
Path: {m_symbol.path()}
Page: {m_symbol.page()}

--- Session Info ---
Session Deals: {m_symbol.session_deals()}
Session Buy Orders: {m_symbol.session_buy_orders()}
Session Sell Orders: {m_symbol.session_sell_orders()}
Session Turnover: {m_symbol.session_turnover()}
Session Interest: {m_symbol.session_interest()}
Session Buy Volume: {m_symbol.session_buy_orders_volume()}
Session Sell Volume: {m_symbol.session_sell_orders_volume()}
Session Open: {m_symbol.session_open()}
Session Close: {m_symbol.session_close()}
Session AW: {m_symbol.session_aw()}
Session Price Settlement: {m_symbol.session_price_settlement()}
Session Price Limit Min: {m_symbol.session_price_limit_min()}
Session Price Limit Max: {m_symbol.session_price_limit_max()}
---------------------
""")

mt5.shutdown()
