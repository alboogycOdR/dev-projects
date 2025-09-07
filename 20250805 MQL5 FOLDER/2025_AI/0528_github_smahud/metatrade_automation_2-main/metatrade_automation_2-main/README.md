# MetaTrader5 LLM Trading Bot

This project integrates MetaTrader5 with Large Language Models (LLMs) to automate trading decisions in the futures market. The application utilizes OpenAI's GPT models through Langchain to analyze market data and make informed trading decisions.

## Project Overview

The LLM Trading Bot receives data from the financial market through MetaTrader5's API, performs analysis to reduce risks and maximize profits, and manages contracts based on market conditions and user inputs.

### Key Features

- **Real-time market data** extraction from MetaTrader5
- **Technical indicators** calculation (ATR, Directional Entropy, EMA9)
- **LLM-powered analysis** for trading decisions
- **Contract management** based on confidence levels
- **Interactive dashboard** for monitoring and control

## Installation

1. Clone this repository to your local machine:
   ```
   git clone https://github.com/yourusername/metatradebot2.git
   cd metatradebot2
   ```

2. Install the required Python packages:
   ```
   pip install -r requirements.txt
   ```

3. Set up your OpenAI API key as an environment variable:
   ```
   export OPENAI_API_KEY=your_api_key_here
   ```

4. Ensure MetaTrader5 is installed and running on your system.

## Project Structure

- `app.py`: Main application file with Dash frontend and trading logic
- `indicators.py`: Technical indicators calculation functions
- `prompts.py`: Prompt templates for LLM interactions
- `requirements.txt`: Python dependencies
- `README.md`: Project documentation

## Usage

1. Start the application:
   ```
   python app.py
   ```

2. Access the web interface at http://localhost:8050

3. Configure your trading parameters:
   - Asset Symbol (e.g., EURUSD)
   - Timeframe (M1, M5, M15, M30, H1, H4, D1)
   - Support and Resistance levels
   - Maximum contracts

4. Click "Start" to begin market analysis
   
5. Click "Trigger Analysis" to manually trigger a market analysis and potential trade execution

## How It Works

1. **Data Extraction**: The application connects to MetaTrader5 and extracts OHLC and volume data for the specified asset and timeframe.

2. **Technical Analysis**: The data is processed to calculate ATR, Directional Entropy, and EMA9 indicators.

3. **LLM Analysis**: The processed data is sent to the LLM through Langchain, which analyzes market conditions and generates trading recommendations.

4. **Contract Management**: Based on the LLM's confidence level, the application adds or removes contracts, respecting the maximum contract limit.

5. **User Interface**: The dashboard displays current positions, P&L, market direction, confidence level, and LLM reasoning.

## Configuration

You can modify the following parameters in the user interface:

- **Asset Symbol**: The financial instrument to trade
- **Timeframe**: The candle timeframe for analysis
- **Support/Resistance Levels**: Key price levels entered manually
- **Max Contracts**: Maximum number of contracts allowed per trade
- **Use Initial Market Context**: Option to analyze historical data for context

## Requirements

- Python 3.7+
- MetaTrader5
- OpenAI API Key
- Required Python packages (see requirements.txt)

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Disclaimer

This software is for educational purposes only. Trading financial instruments carries risk, and past performance is not indicative of future results. Use at your own risk.