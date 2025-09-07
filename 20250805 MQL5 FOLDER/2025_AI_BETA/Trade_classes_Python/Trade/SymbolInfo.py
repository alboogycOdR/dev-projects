import MetaTrader5 as mt5
from datetime import datetime

class CSymbolInfo:
    def __init__(self, symbol):
        
        """This class provides access to the symbol properties.
        
           read more: https://www.mql5.com/en/docs/standardlibrary/tradeclasses/csymbolinfo
        """ 
        
        self.symbol = symbol
        self.refresh()

    
    # --- controlling
    
    def refresh(self):
        info = mt5.symbol_info(self.symbol)
        if not info:
            raise Exception(f"Failed to get symbol info for {self.symbol}")
        self.info = info
        return True

    def refresh_rates(self):
        return mt5.symbol_info_tick(self.symbol)

    # --- properties
    
    def name(self):
        return self.info.name
    
    def select(self, select=True):
        return mt5.symbol_select(self.symbol, select)

    # --- volumes
    
    def volume(self):
        return self.info.volume
    
    def volume_high(self):
        return self.info.volumehigh
    
    def volume_low(self):
        return self.info.volumelow
    
    # --- Miscillaneous
    
    def time(self):
        return datetime.fromtimestamp(self.info.time)

    def spread(self):
        return self.info.spread

    def spread_float(self):
        return self.info.spread_float
    
    def ticks_book_depth(self):
        return self.info.ticks_bookdepth
    
    # --- Trade levels
    
    def stops_level(self):
        return self.info.trade_stops_level

    def freeze_level(self):
        return self.info.trade_freeze_level
    
    # --- bid parameters
    
    def bid(self):
        return self.info.bid
        
    def bid_high(self):
        return self.info.bidhigh

    def bid_low(self):
        return self.info.bidlow
    
    # --- ask parameters
    
    def ask(self):
        return self.info.ask
    
    def ask_high(self):
        return self.info.askhigh

    def ask_low(self):
        return self.info.asklow
    
    # --- Last parameters
    
    def is_synchronized(self):
        return self.info.select

    def last(self):
        return self.info.last

    def last_high(self):
        return self.info.lasthigh

    def last_low(self):
        return self.info.lastlow

    # --- terms and calculation of trades 
    
    def trade_calc_mode(self):
        return self.info.trade_calc_mode
    
    def trade_calc_mode_description(self) -> str:
        
        calc_mode_map = {
            mt5.SYMBOL_CALC_MODE_FOREX: "Calculation of profit and margin for Forex",
            mt5.SYMBOL_CALC_MODE_FUTURES: "Calculation of margin and profit for futures",
            mt5.SYMBOL_CALC_MODE_CFD: "Calculation of margin and profit for CFD",
            mt5.SYMBOL_CALC_MODE_CFDINDEX: "Calculation of margin and profit for CFD by indexes",
            mt5.SYMBOL_CALC_MODE_CFDLEVERAGE: "Calculation of margin and profit for CFD at leverage trading",
            mt5.SYMBOL_CALC_MODE_FOREX_NO_LEVERAGE: "Calculation of profit and margin for Forex symbols without taking into account the leverage",
            mt5.SYMBOL_CALC_MODE_EXCH_STOCKS: "Calculation of margin and profit for trading securities on a stock exchange",
            mt5.SYMBOL_CALC_MODE_EXCH_FUTURES: "Calculation of margin and profit for trading futures contracts on a stock exchange",
            mt5.SYMBOL_CALC_MODE_EXCH_BONDS: "Calculation of margin and profit for trading bonds on a stock exchange",
            mt5.SYMBOL_CALC_MODE_EXCH_STOCKS_MOEX: "Calculation of margin and profit for trading securities on MOEX",
            mt5.SYMBOL_CALC_MODE_EXCH_BONDS_MOEX: "Calculation of margin and profit for trading bonds on MOEX",
            mt5.SYMBOL_CALC_MODE_SERV_COLLATERAL: "Collateral mode - a symbol is used as a non-tradable asset on a trading account"
        }

        return calc_mode_map.get(self.trade_calc_mode(), "Unknown trade calculation mode")
    
    def trade_mode(self):
        return self.info.trade_mode

    def trade_mode_description(self) -> str:
        
        trade_mode_map = {
            mt5.SYMBOL_TRADE_MODE_DISABLED: "Trade is disabled for the symbol",
            mt5.SYMBOL_TRADE_MODE_LONGONLY: "Allowed only long positions",
            mt5.SYMBOL_TRADE_MODE_SHORTONLY: "Allowed only short positions",
            mt5.SYMBOL_TRADE_MODE_CLOSEONLY: "Allowed only position close operations",
            mt5.SYMBOL_TRADE_MODE_FULL: "No trade restrictions"
        }

        return trade_mode_map.get(self.trade_mode(), "Unknown trade mode")
    
    
    def trade_execution(self):
        return self.info.trade_exemode

    def trade_execution_description(self) -> str:
        
        exec_mode_map = {
            
            mt5.SYMBOL_TRADE_EXECUTION_REQUEST: "Execution by request",
            mt5.SYMBOL_TRADE_EXECUTION_INSTANT: "Instant execution",
            mt5.SYMBOL_TRADE_EXECUTION_MARKET: "Market execution",
            mt5.SYMBOL_TRADE_EXECUTION_EXCHANGE: "Exchange execution"
        }

        return exec_mode_map.get(self.trade_execution(), "Unkown trade execution mode")
        
    def order_mode(self):
        return self.info.order_mode

    # --- swaps
    
    def swap_mode(self):
        return self.info.swap_mode

    def swap_mode_description(self) -> str:
        
        swap_mode_map = {
            mt5.SYMBOL_SWAP_MODE_DISABLED: "No swaps",
            mt5.SYMBOL_SWAP_MODE_POINTS: "Swaps are calculated in points",
            mt5.SYMBOL_SWAP_MODE_CURRENCY_SYMBOL: "Swaps are calculated in base currency",
            mt5.SYMBOL_SWAP_MODE_CURRENCY_MARGIN: "Swaps are calculated in margin currency",
            mt5.SYMBOL_SWAP_MODE_CURRENCY_DEPOSIT: "Swaps are calculated in deposit currency",
            mt5.SYMBOL_SWAP_MODE_INTEREST_CURRENT: "Swaps are calculated as annual interest using the current price",
            mt5.SYMBOL_SWAP_MODE_INTEREST_OPEN: "Swaps are calculated as annual interest using the open price",
            mt5.SYMBOL_SWAP_MODE_REOPEN_CURRENT: "Swaps are charged by reopening positions at the close price",
            mt5.SYMBOL_SWAP_MODE_REOPEN_BID: "Swaps are charged by reopening positions at the Bid price"
        }
    
        return swap_mode_map.get(self.swap_mode(), "Unkown swap mode")

    def swap_rollover_3days(self):
        return self.info.swap_rollover3days

    def swap_rollover_3days_description(self):
        
        swap_rollover_map = {
            0: "Sunday",
            1: "Monday",
            2: "Tuesday",
            3: "Wednesday",
            4: "Thursday",
            5: "Friday",
            6: "Saturday",
        }

        return swap_rollover_map.get(self.swap_rollover_3days(), "Unkown swap rollover 3 days")
        
    def filling_mode(self):
        return self.info.filling_mode
    
    # --- dates for futures

    def expiration_time(self):
        return self.info.expiration_time

    def start_time(self):
        return self.info.start_time
    
    # --- margin parameters
    
    def margin_initial(self):
        return self.info.margin_initial

    def margin_maintenance(self):
        return self.info.margin_maintenance

    def margin_hedged(self):
        return self.info.margin_hedged

    def margin_hedged_use_leg(self):
        return self.info.margin_hedged_use_leg
    
    # --- tick parameters

    def digits(self):
        return self.info.digits

    def point(self):
        return self.info.point
    
    def tick_value(self):
        return self.info.trade_tick_value

    def tick_value_profit(self):
        return self.info.trade_tick_value_profit

    def tick_value_loss(self):
        return self.info.trade_tick_value_loss

    def tick_size(self):
        return self.info.trade_tick_size

    def swap_long(self):
        return self.info.swap_long

    def swap_short(self):
        return self.info.swap_short
    
    # --- Lots parameters
    
    def contract_size(self):
        return self.info.trade_contract_size
    
    def lots_min(self):
        return self.info.volume_min

    def lots_max(self):
        return self.info.volume_max

    def lots_step(self):
        return self.info.volume_step

    def lots_limit(self):
        return self.info.volume_limit

    # --- Currency 
    
    def currency_base(self):
        return self.info.currency_base

    def currency_profit(self):
        return self.info.currency_profit

    def currency_margin(self):
        return self.info.currency_margin

    def bank(self):
        return self.info.bank
    
    def description(self):
        return self.info.description    
    
    def path(self):
        return self.info.path
    
    def page(self):
        return self.info.page
    
    # --- Sessions

    def session_deals(self):
        return self.info.session_deals

    def session_buy_orders(self):
        return self.info.session_buy_orders

    def session_sell_orders(self):
        return self.info.session_sell_orders

    def session_turnover(self):
        return self.info.session_turnover

    def session_interest(self):
        return self.info.session_interest

    def session_buy_orders_volume(self):
        return self.info.session_buy_orders_volume

    def session_sell_orders_volume(self):
        return self.info.session_sell_orders_volume

    def session_open(self):
        return self.info.session_open

    def session_close(self):
        return self.info.session_close

    def session_aw(self):
        return self.info.session_aw

    def session_price_settlement(self):
        return self.info.session_price_settlement

    def session_price_limit_min(self):
        return self.info.session_price_limit_min

    def session_price_limit_max(self):
        return self.info.session_price_limit_max
    

