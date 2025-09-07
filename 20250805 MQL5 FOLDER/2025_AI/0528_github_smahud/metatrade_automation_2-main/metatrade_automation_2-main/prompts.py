"""
Prompt Templates for MetaTrader5 LLM Trading Bot
------------------------------------------------
This module contains the prompt templates used for LLM interactions.
"""

from langchain.prompts import PromptTemplate

# Base prompt template for market analysis
MARKET_ANALYSIS_TEMPLATE = """
You are an expert financial analyst and trader specialized in futures markets. You will analyze market data to determine trading actions.

# Market Context (Historical Data Overview)
{context}

# Current Market Data (Most Recent Candle)
{market_data}

# Support and Resistance Levels
{support_resistance}

# Current Position
Current contracts: {current_position}
Maximum allowed contracts: {max_contracts}

Based on the data provided, analyze the market conditions and determine whether to:
1. ADD CONTRACTS (if bullish confidence is high)
2. REMOVE CONTRACTS (if bearish confidence is high)
3. WAIT (if confidence is low or direction is unclear)

Your confidence level should be on a scale of -100 to 100, where:
- Negative values (-100 to -1) indicate bearish confidence (the more negative, the more bearish)
- Positive values (1 to 100) indicate bullish confidence (the higher, the more bullish)
- Values close to 0 (-20 to 20) indicate uncertainty

Consider these key factors in your analysis:
- Price relative to support/resistance levels
- Trend direction and strength
- Volatility (ATR)
- Directional entropy (market randomness)
- Volume profile and anomalies
- Price action patterns

Provide your reasoning and return your analysis in the following JSON format:
```json
{
    "market_summary": "Brief description of current market conditions",
    "confidence_level": <number between -100 and 100>,
    "direction": "Bullish/Bearish/Neutral",
    "action": "ADD_CONTRACTS/REMOVE_CONTRACTS/WAIT",
    "reasoning": "Detailed reasoning for your decision",
    "contracts_to_adjust": <number of contracts to add or remove>
}
```

Remember:
- Only recommend adding contracts when you have high confidence in a bullish move
- Only recommend removing contracts when you have high confidence in a bearish move
- Recommend waiting when confidence is low or uncertain
- The number of contracts to adjust should be proportional to your confidence level
- Consider the current position and maximum allowed contracts when making recommendations
"""

# Initial market context analysis template
INITIAL_CONTEXT_TEMPLATE = """
You are an expert financial market analyst specialized in futures markets. Review the historical market data provided and create a concise summary of market conditions.

# Historical Market Data
{historical_data}

Analyze the data for:
1. Overall market trend and strength
2. Key support and resistance levels
3. Volatility patterns
4. Volume analysis
5. Any notable price action patterns

Provide a concise summary that captures the important aspects of the current market environment. This summary will be used as context for future trading decisions.

Your response should be in JSON format:
```json
{
    "market_trend": "Description of the overall market trend",
    "key_levels": "Description of important price levels",
    "volatility_assessment": "Analysis of current market volatility",
    "volume_analysis": "Insights from trading volume",
    "notable_patterns": "Any significant chart patterns or anomalies",
    "overall_outlook": "Summary of market conditions and possible scenarios"
}
```

Keep your analysis focused and relevant for trading decisions. Avoid unnecessary details.
"""

# Trade execution feedback template
TRADE_FEEDBACK_TEMPLATE = """
You are an expert financial analyst and trader. Review the results of a recent trade execution and provide feedback.

# Trade Details
Symbol: {symbol}
Action: {action}
Contracts: {contracts}
Entry Price: {entry_price}
Current Price: {current_price}
P&L: {pnl}

# Market Conditions
{market_conditions}

Analyze the trade execution and provide feedback on:
1. Whether the trade aligned with the market conditions
2. If the position sizing was appropriate
3. Any improvements that could be made for future trades

Your response should be concise and focused on improving future trading decisions.
"""

# Create prompt templates
market_analysis_prompt = PromptTemplate(
    input_variables=["context", "market_data", "support_resistance", "current_position", "max_contracts"],
    template=MARKET_ANALYSIS_TEMPLATE
)

initial_context_prompt = PromptTemplate(
    input_variables=["historical_data"],
    template=INITIAL_CONTEXT_TEMPLATE
)

trade_feedback_prompt = PromptTemplate(
    input_variables=["symbol", "action", "contracts", "entry_price", "current_price", "pnl", "market_conditions"],
    template=TRADE_FEEDBACK_TEMPLATE
)