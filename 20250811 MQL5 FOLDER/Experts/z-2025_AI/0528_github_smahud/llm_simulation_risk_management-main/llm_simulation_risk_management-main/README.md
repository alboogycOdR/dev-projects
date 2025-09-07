# Natural Gas Trading Dashboard with LLM Integration

A sophisticated natural gas futures trading simulation dashboard powered by Large Language Model (LLM) analytics. The system visualizes price movements, provides real-time trading decisions, and displays LLM reasoning for each trade.

## Features

- **Real-time Price Visualization**: Interactive candlestick chart with support/resistance levels
- **LLM-based Trading Decisions**: Uses OpenAI's GPT model to analyze market patterns and make trading decisions
- **Position Management**: Tracks contracts, entry prices, and calculates real-time P&L
- **Dynamic Trading Strategy**: Responsive to breakouts, candlestick patterns, and volume confirmations
- **Historical Analysis**: Maintains a log of all trading decisions with reasoning

## Requirements

- Python 3.8+
- OpenAI API key
- Required packages listed in `requirements.txt`

## Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/natural-gas-trading-dashboard.git
   cd natural-gas-trading-dashboard
   ```

2. Create and activate a virtual environment:
   ```bash
   python -m venv venv
   source venv/bin/activate  # On Windows: venv\Scripts\activate
   ```

3. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```

4. Create a `.env` file in the project root with your OpenAI API key:
   ```
   OPENAI_API_KEY=your_api_key_here
   ```

## Usage

1. Start the dashboard:
   ```bash
   python llm_analize_De_entradaV3.py
   ```

2. Open your browser and navigate to:
   ```
   http://127.0.0.1:8050/
   ```

3. Use the dashboard controls:
   - Click "Start Simulation" to begin the trading simulation
   - Adjust the speed slider to control the pace of the simulation
   - Click "Pause" to temporarily halt the simulation
   - Click "Restart" to reset the simulation to the beginning

## Configuration

You can modify various parameters in the `Config` class at the beginning of the main script:

- `SUPPORT_RESISTANCE_LEVELS`: Key price levels for technical analysis
- `CONTRACT_MULTIPLIER`: Value of each price point per contract
- `INITIAL_CONTRACTS`: Starting position size
- `LLM_EVERY`: How often to request LLM analysis (every n candles)
- `OPENAI_MODEL`: Which OpenAI model to use
- Additional UI and simulation parameters

## Data Sources

The dashboard can use either:
1. Real historical price data in CSV format
2. Simulated price data (automatically generated if no CSV is found)

To use your own data, place a CSV file at the location specified in `Config.CSV_PATH` with columns:
- Date
- Open
- High
- Low
- Close
- Volume

## Trading Strategy Logic

The LLM analyzes market conditions based on:

1. **Breakout Detection**: Identifies when price breaks through support/resistance levels
2. **Candlestick Patterns**: Recognizes continuation or reversal patterns
3. **Volume Confirmation**: Uses volume data to validate price movements
4. **Position Management**: Makes decisions based on current position size and P&L

Each decision comes with a confidence level that affects position sizing.

## Project Structure

- `llm_analize_De_entradaV3.py`: Main application file
- `requirements.txt`: Dependencies
- `.env`: Environment variables (API keys)
- `.env.example`: Template for creating your own .env file
- `docs/`: Additional documentation
- `LICENSE`: MIT License

## License

This project is licensed under the MIT License - see the LICENSE file for details.
