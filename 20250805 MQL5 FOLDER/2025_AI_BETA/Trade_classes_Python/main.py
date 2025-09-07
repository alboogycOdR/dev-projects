import MetaTrader5 as mt5
from Trade.Trade import CTrade
from Trade.SymbolInfo import CSymbolInfo
from datetime import datetime, timedelta

if not mt5.initialize(r"c:\Users\Omega Joctan\AppData\Roaming\Pepperstone MetaTrader 5\terminal64.exe"):
    print("Failed to initialize Metatrader5 Error = ",mt5.last_error())
    quit()
      
    
symbol = "EURUSD"

m_symbol = CSymbolInfo(symbol=symbol)
m_trade = CTrade(magic_number=1001,
                 deviation_points=100,
                 filling_type_symbol=symbol)


m_symbol.refresh_rates()

ask = m_symbol.ask()
bid = m_symbol.bid()

lotsize = m_symbol.lots_min()

# === Market Orders ===

m_trade.buy(volume=lotsize, symbol=symbol, price=ask, sl=0.0, tp=0.0, comment="Market Buy Pos")
m_trade.sell(volume=lotsize, symbol=symbol, price=bid, sl=0.0, tp=0.0, comment="Market Sell Pos")


# expiration time for pending orders
expiration_time = datetime.now() + timedelta(minutes=1)

# === Pending Orders ===

# Buy Limit - price below current ask
m_trade.buy_limit(volume=lotsize, symbol=symbol, price=ask - 0.0020, sl=0.0, tp=0.0, type_time=mt5.ORDER_TIME_SPECIFIED, expiration=expiration_time,
                comment="Buy Limit Order")


# Sell Limit - price above current bid
m_trade.sell_limit(volume=lotsize, symbol=symbol, price=bid + 0.0020, sl=0.0, tp=0.0, type_time=mt5.ORDER_TIME_SPECIFIED, expiration=expiration_time,
                   comment="Sell Limit Order")

# Buy Stop - price above current ask
m_trade.buy_stop(volume=lotsize, symbol=symbol, price=ask + 0.0020, sl=0.0, tp=0.0, type_time=mt5.ORDER_TIME_SPECIFIED, expiration=expiration_time,
                 comment="Buy Stop Order")

# Sell Stop - price below current bid
m_trade.sell_stop(volume=lotsize, symbol=symbol, price=bid - 0.0020, sl=0.0, tp=0.0, type_time=mt5.ORDER_TIME_SPECIFIED, expiration=expiration_time,
                  comment="Sell Stop Order")

# Buy Stop Limit - stop price above ask, limit price slightly lower (near it)
m_trade.buy_stop_limit(volume=lotsize, symbol=symbol, price=ask + 0.0020, sl=0.0, tp=0.0, type_time=mt5.ORDER_TIME_SPECIFIED, expiration=expiration_time,
                       comment="Buy Stop Limit Order")

# Sell Stop Limit - stop price below bid, limit price slightly higher (near it)
m_trade.sell_stop_limit(volume=lotsize, symbol=symbol, price=bid - 0.0020, sl=0.0, tp=0.0, type_time=mt5.ORDER_TIME_SPECIFIED, expiration=expiration_time,
                        comment="Sell Stop Limit Order")


mt5.shutdown()