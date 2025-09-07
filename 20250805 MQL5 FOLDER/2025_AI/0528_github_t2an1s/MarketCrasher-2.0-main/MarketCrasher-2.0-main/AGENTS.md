The project is about porting onto a new Metatrader5 EA, a TradingView Strategy (see TradingView PropStrategy.txt for full script), coded in Pinescript.

EA skeleton comprises of 2 separate EAs, one (acting as Master) will be attached to the Prop MT5 account and will be triggering the trades and the second EA (slave) will be attached to the Hedge MT5 account and will open the opposite direction positions. 

Priority is to ensure absolute parity between TradingView PropStrategy and EA. Note ---> Pineconnector related code can be dropped, we dont need it anymore. 

Dashboard (below) needs to be cloned and code it in an .mqh. <img width="513" alt="Screenshot 2025-05-17 at 10 36 05 AM" src="https://github.com/user-attachments/assets/f9df3bb5-1849-4f24-b89a-5b969fcc9f1a" />

You are granted permission to access all repo contents, to create directories, folders, files, move files, as well as to delete (upon prior OK from me). Any of these actions must be included and reasoned in your summary.

You are granted access to run any actions and workflows set in this repository.

You are granted access to create Pull Request as soon as you complete the task, access Pull Requests on github, resolve conflicts (if any), merge and commit.

IMPORTANT ----> Code that you deliver must be error/warning-free.


## Setup  <!-- Codex runs this block once per container boot -->

```bash
# One-time provisioning of Wine + portable MetaTrader 5
bash ./codex-setup.sh
