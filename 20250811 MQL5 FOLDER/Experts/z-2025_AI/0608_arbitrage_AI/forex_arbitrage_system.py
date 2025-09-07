import MetaTrader5 as mt5
import pandas as pd
import numpy as np
import pytz
from datetime import datetime
import time
import logging
import itertools

# Configure logging to be more concise for HFT
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(message)s')
logger = logging.getLogger(__name__)

# --- Data Structure for True Triangular Arbitrage ---
class ArbitrageTriangle:
    def __init__(self, cross_symbol, base_symbol1, base_symbol2, operation):
        self.cross_symbol = cross_symbol
        self.base_symbol1 = base_symbol1
        self.base_symbol2 = base_symbol2
        self.operation = operation # 'DIVIDE' or 'MULTIPLY'

    def __repr__(self):
        op_char = '/' if self.operation == 'DIVIDE' else '*'
        return f"[{self.cross_symbol} = {self.base_symbol1} {op_char} {self.base_symbol2}]"

class ForexArbitrageSystem:
    """
    High-frequency Forex arbitrage trading system using MetaTrader 5
    Refactored to use true triangular arbitrage logic and scalable pair generation.
    """
    def __init__(self, terminal_path, max_open_trades=10, min_spread_pips=8.0):
        self.terminal_path = terminal_path
        self.max_open_trades = max_open_trades
        self.min_spread_pips = min_spread_pips # Use pips for a more universal threshold

        # Core currencies to build triangles from. This is the new, scalable approach.
        self.core_currencies = ["EUR", "USD", "GBP", "JPY", "CHF", "AUD", "NZD", "CAD"]
        
        # All symbols required by the generated triangles
        self.required_symbols = set() 
        self.arbitrage_triangles = []

        # Trading parameters
        self.volume = 0.50
        self.take_profit_pips = 450
        self.stop_loss_pips = 200
        self.magic_number = 123456

    def _generate_triangles(self):
        """Programmatically generate all valid arbitrage triangles."""
        self.arbitrage_triangles = []
        # Generate combinations of 3 different currencies
        for combo in itertools.combinations(self.core_currencies, 3):
            # Create all permutations of pairs from the three currencies
            pair1 = f"{combo[0]}{combo[1]}"
            pair2 = f"{combo[1]}{combo[2]}"
            cross_pair = f"{combo[0]}{combo[2]}"

            # This is a classic triangular arbitrage loop: A/C = A/B * B/C
            self.arbitrage_triangles.append(
                ArbitrageTriangle(cross_pair, pair1, pair2, 'MULTIPLY')
            )
        
        logger.info(f"Generated {len(self.arbitrage_triangles)} potential arbitrage triangles.")
    
    def _subscribe_to_symbols(self):
        """Gathers all unique symbols and subscribes to them in MT5."""
        for triangle in self.arbitrage_triangles:
            self.required_symbols.add(triangle.cross_symbol)
            self.required_symbols.add(triangle.base_symbol1)
            self.required_symbols.add(triangle.base_symbol2)

        for symbol in self.required_symbols:
            try:
                if not mt5.symbol_select(symbol, True):
                    # Attempt inverse symbol if the primary fails (e.g., EURUSD vs USDEUR)
                    if len(symbol) == 6:
                        inverse = symbol[3:] + symbol[:3]
                        if mt5.symbol_select(inverse, True):
                            logger.info(f"Subscribed to inverse symbol: {inverse}")
                        else:
                            logger.warning(f"Could not subscribe to {symbol} or its inverse.")
                    else:
                        logger.warning(f"Could not subscribe to {symbol}")
            except Exception as e:
                logger.error(f"Error subscribing to symbol {symbol}: {e}")

    def initialize_mt5(self):
        """Initialize connection, generate triangles, and subscribe to symbols."""
        if not mt5.initialize(path=self.terminal_path):
            logger.error(f"Failed to connect to MT5 terminal at {self.terminal_path}")
            return False

        logger.info(f"Connected to MetaTrader 5 build {mt5.terminal_info().build}")
        self._generate_triangles()
        self._subscribe_to_symbols()
        return True

    def calculate_synthetic_price(self, triangle):
        """Calculates the synthetic price for a given arbitrage triangle."""
        try:
            tick1 = mt5.symbol_info_tick(triangle.base_symbol1)
            tick2 = mt5.symbol_info_tick(triangle.base_symbol2)
            
            if not tick1 or not tick2:
                return None, None # Not enough data

            if triangle.operation == 'MULTIPLY':
                synthetic_bid = tick1.bid * tick2.bid
                synthetic_ask = tick1.ask * tick2.ask
                return synthetic_bid, synthetic_ask

            elif triangle.operation == 'DIVIDE':
                if tick2.bid == 0 or tick2.ask == 0: return None, None # Avoid division by zero
                synthetic_bid = tick1.bid / tick2.ask
                synthetic_ask = tick1.ask / tick2.bid
                return synthetic_bid, synthetic_ask
                
        except Exception as e:
            logger.debug(f"Could not calculate synthetic for {triangle}: {e}")
            return None, None

    def open_arbitrage_order(self, symbol, order_type):
        """Opens a market order with specified TP/SL."""
        if mt5.positions_total() >= self.max_open_trades:
            logger.warning("Max open trades limit reached.")
            return
            
        if len(mt5.positions_get(symbol=symbol)) > 0:
            logger.info(f"Position for {symbol} already exists, skipping.")
            return

        tick = mt5.symbol_info_tick(symbol)
        if not tick:
            logger.error(f"Could not retrieve tick for {symbol}")
            return

        price = tick.ask if order_type == mt5.ORDER_TYPE_BUY else tick.bid
        point = mt5.symbol_info(symbol).point

        request = {
            "action": mt5.TRADE_ACTION_DEAL,
            "symbol": symbol,
            "volume": self.volume,
            "type": order_type,
            "price": price,
            "deviation": 20,
            "magic": self.magic_number,
            "comment": "Triangular Arbitrage",
            "type_time": mt5.ORDER_TIME_GTC,
            "type_filling": mt5.ORDER_FILLING_IOC, # Immediate Or Cancel
            "tp": price + self.take_profit_pips * point if order_type == mt5.ORDER_TYPE_BUY else price - self.take_profit_pips * point,
            "sl": price - self.stop_loss_pips * point if order_type == mt5.ORDER_TYPE_BUY else price + self.stop_loss_pips * point,
        }
        
        result = mt5.order_send(request)
        if result.retcode == mt5.TRADE_RETCODE_DONE:
            logger.info(f"SUCCESS: Opened {symbol} {order_type} at {price}. Order: {result.order}")
        else:
            logger.error(f"FAILURE: Order for {symbol} failed. Code: {result.retcode} - {result.comment}")

    def run_arbitrage_cycle(self):
        """
        Run one complete arbitrage analysis and trading cycle.
        This is the core logic loop.
        """
        for triangle in self.arbitrage_triangles:
            synthetic_bid, synthetic_ask = self.calculate_synthetic_price(triangle)
            if synthetic_bid is None:
                continue

            real_tick = mt5.symbol_info_tick(triangle.cross_symbol)
            if not real_tick:
                continue

            point = mt5.symbol_info(triangle.cross_symbol).point
            min_spread_value = self.min_spread_pips * point

            # Opportunity to BUY the cross pair (Real Ask price is cheaper than Synthetic Bid)
            if real_tick.ask < synthetic_bid and (synthetic_bid - real_tick.ask) > min_spread_value:
                logger.info(f"BUY opportunity on {triangle.cross_symbol}: Real Ask({real_tick.ask}) < Synthetic Bid({synthetic_bid})")
                self.open_arbitrage_order(triangle.cross_symbol, mt5.ORDER_TYPE_BUY)
                time.sleep(1) # Pause briefly after opening a trade to avoid hammering

            # Opportunity to SELL the cross pair (Real Bid price is higher than Synthetic Ask)
            if real_tick.bid > synthetic_ask and (real_tick.bid - synthetic_ask) > min_spread_value:
                logger.info(f"SELL opportunity on {triangle.cross_symbol}: Real Bid({real_tick.bid}) > Synthetic Ask({synthetic_ask})")
                self.open_arbitrage_order(triangle.cross_symbol, mt5.ORDER_TYPE_SELL)
                time.sleep(1)

    def is_trading_hours(self):
        """Check if current time is within trading hours (avoid 23:30-05:00 UTC)."""
        utc_now = datetime.now(pytz.utc).time()
        if utc_now > datetime.strptime("23:30", "%H:%M").time() or utc_now < datetime.strptime("05:00", "%H:%M").time():
            return False
        return True

    def run_continuous(self, cycle_interval=0.1):
        """Run the arbitrage system continuously in a high-frequency loop."""
        if not self.initialize_mt5():
            return
        
        logger.info("System initialized. Starting high-frequency arbitrage cycle.")
        
        try:
            while True:
                if self.is_trading_hours():
                    self.run_arbitrage_cycle()
                else:
                    logger.info("Outside trading hours, pausing for 1 minute...")
                    time.sleep(60)

                time.sleep(cycle_interval) # High-frequency pause

        except KeyboardInterrupt:
            logger.info("Arbitrage system stopped by user.")
        finally:
            mt5.shutdown()
            logger.info("MT5 connection closed.")

def main():
    """Main function to configure and run the arbitrage system."""
    # NOTE: Update this path to your MetaTrader 5 terminal.exe location
    terminal_path = "C:/Program Files/MetaTrader 5/terminal64.exe" 
    
    arbitrage_system = ForexArbitrageSystem(
        terminal_path=terminal_path,
        max_open_trades=10,
        min_spread_pips=8.0 # An 8-pip difference required to trigger a trade
    )
    
    # Start the main loop
    arbitrage_system.run_continuous(cycle_interval=0.1) # Check for opportunities 10 times per second

if __name__ == "__main__":
    main()