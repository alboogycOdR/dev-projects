import MetaTrader5 as mt5
from Trade.PositionInfo import CPositionInfo

if not mt5.initialize(r"c:\Users\Omega Joctan\AppData\Roaming\Pepperstone MetaTrader 5\terminal64.exe"):
    print("Failed to initialize Metatrader5 Error = ",mt5.last_error())
    quit()
      
    
positions = mt5.positions_get()
m_position = CPositionInfo()

# Loop and print each position
for i, position in enumerate(positions):
    if m_position.select_position(position):
        print(f"""
Position #{i}

--- Integer type properties ---

Time Open: {m_position.time()}
Time Open (ms): {m_position.time_msc()}
Time Update: {m_position.time_update()}
Time Update (ms): {m_position.time_update_msc()}
Magic Number: {m_position.magic()}
Ticket: {m_position.ticket()}
Position Type: {m_position.position_type()} ({m_position.position_type_description()})

--- Double type properties ---

Volume: {m_position.volume()}
Price Open: {m_position.price_open()}
Price Current: {m_position.price_current()}
Stop Loss: {m_position.stop_loss()}
Take Profit: {m_position.take_profit()}
Profit: {m_position.profit()}
Swap: {m_position.swap()}

--- Access to text properties ---

Symbol: {m_position.symbol()}
Comment: {m_position.comment()}

""")

mt5.shutdown()