import MetaTrader5 as mt5
from Trade.TerminalInfo import CTerminalInfo


if not mt5.initialize(r"c:\Users\Omega Joctan\AppData\Roaming\Pepperstone MetaTrader 5\terminal64.exe"):
    print("Failed to initialize Metatrader5 Error = ",mt5.last_error())
    quit()
      

terminal = CTerminalInfo()


print(f"""
Terminal Information

--- String type ---

Name: {terminal.name()}
Company: {terminal.company()}
Language: {terminal.language()}
Terminal Path: {terminal.path()}
Data Path: {terminal.data_path()}
Common Data Path: {terminal.common_data_path()}

--- Integers type ---

Build: {terminal.build()}
Connected: {terminal.is_connected()}
DLLs Allowed: {terminal.is_dlls_allowed()}
Trade Allowed: {terminal.is_trade_allowed()}
Email Enabled: {terminal.is_email_enabled()}
FTP Enabled: {terminal.is_ftp_enabled()}
Notifications Enabled: {terminal.are_notifications_enabled()}
Community Account: {terminal.is_community_account()}
Community Connected: {terminal.is_community_connection()}
MQID: {terminal.is_mqid()}
Trade API Disabled: {terminal.is_tradeapi_disabled()}
Max Bars: {terminal.max_bars()}
Code Page: {terminal.code_page()}
Ping Last (μs): {terminal.ping_last()}
Community Balance: {terminal.community_balance()}
Retransmission Rate: {terminal.retransmission()}
""")
    
mt5.shutdown()