import MetaTrader5 as mt5
from Trade.AccountInfo import CAccountInfo

if not mt5.initialize(r"c:\Users\Omega Joctan\AppData\Roaming\Pepperstone MetaTrader 5\terminal64.exe"):
    print("Failed to initialize Metatrader5 Error = ",mt5.last_error())
    quit()
      

acc = CAccountInfo()

print(f"""
Account Information
-------------------
Login: {acc.login()}
-------------------
Name: {acc.name()}
Server: {acc.server()}
Company: {acc.company()}
Currency: {acc.currency()}
-------------------
Trade Mode: {acc.trade_mode()} ({acc.trade_mode_description()})
Leverage: {acc.leverage()}
Stopout Mode: {acc.stopout_mode()} ({acc.stopout_mode_description()})
Margin Mode: {acc.margin_mode()} ({acc.margin_mode_description()})
Trade Allowed: {acc.trade_allowed()}
Trade Expert: {acc.trade_expert()}
Limit Orders: {acc.limit_orders()}
-------------------
Balance: {acc.balance()}
Credit: {acc.credit()}
Profit: {acc.profit()}
Equity: {acc.equity()}
Margin: {acc.margin()}
Free Margin: {acc.free_margin()}
Margin Level: {acc.margin_level()}
Margin Call: {acc.margin_call()}
Margin StopOut: {acc.margin_stopout()}
-------------------
""")


mt5.shutdown()