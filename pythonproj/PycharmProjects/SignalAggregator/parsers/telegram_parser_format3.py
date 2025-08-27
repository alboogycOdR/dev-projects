# parsers/telegram_parser_format3.py
import re
import logging
from decimal import Decimal, InvalidOperation # Using decimal in case needed for prices later
from .base_parser import BaseParser
# Import RawMessage assuming correct relative path setup
try:
    from utils.message_models import RawMessage
except ImportError:
    RawMessage = dict # Basic fallback

logger = logging.getLogger(__name__)

class TelegramFormat3Parser(BaseParser):
    """
    Parses signals from channels like @redfox_daily_forex_signals.
    Format Example:
    💹 BUY XAUUSD
    👉 Entry: 3316.917
    🚀 Lot size: 0.03
    💎 TP: 3321.000 (12.0$ - 40.8 pip)
    💎 TP2: 3324.800 (24.0$ - 78.8 pip)
    💎 TP3: 3329.000 (36.0$ - 120.8 pip)
    🔶 S/L: 3311.000 (18.0$ - 59.2 pip)
    💰 Risk 2% - 1000$
    """
    # Regex Patterns using MULTILINE and IGNORECASE. Allowing optional leading emojis/chars
    # Allow optional emoji/whitespace before keyword, match keyword, whitespace, capture value.
    # Using non-greedy match '.*?' after keyword before number if needed.

    ACTION_INSTRUMENT_PATTERN = re.compile(r"^\s*.*?\s*(BUY|SELL)\s+([A-Z]+)\s*$", re.IGNORECASE | re.M)
    ENTRY_PRICE_PATTERN = re.compile(r"^\s*.*?Entry:\s+(\d+\.?\d*)\s*$", re.IGNORECASE | re.M)
    LOT_SIZE_PATTERN = re.compile(r"^\s*.*?Lot size:\s+(\d+\.?\d*)\s*$", re.IGNORECASE | re.M)
    STOP_LOSS_PATTERN = re.compile(r"^\s*.*?S/L:\s+(\d+\.?\d*)\s*\(.*?\)\s*$", re.IGNORECASE | re.M) # Match SL num before (...)
    # Find all TP lines, extract only the primary TP value (the number after TPX:)
    TAKE_PROFIT_PATTERN = re.compile(r"^\s*.*?TP\d*:\s+(\d+\.?\d*)\s*\(.*?\)\s*$", re.IGNORECASE | re.M)
    # Optional patterns for details within parentheses if ever needed
    # TP_DETAIL_PATTERN = re.compile(r"\((\d+\.?\d*)\$\s+-\s+(\d+\.?\d*)\s+pip\)")
    # SL_DETAIL_PATTERN = re.compile(r"\((\d+\.?\d*)\$\s+-\s+(\d+\.?\d*)\s+pip\)")
    # RISK_PATTERN = re.compile(r"^\s*.*?Risk\s+(\d+)%\s*-\s*(\d+)\$", re.IGNORECASE | re.M)

    def parse(self, raw_message: RawMessage) -> dict | None:
        """Parses the raw message text using Regex."""
        text = raw_message.text
        parsed_data = {}

        # Helper function to search and log failure
        def find_pattern(pattern, name, required=True):
            match = pattern.search(text)
            if match:
                self.logger.debug(f"Parser {self.parser_id}: Found {name} = {match.group(1)}")
                return match.group(1) # Return first capture group
            else:
                if required:
                     self.logger.warning(f"Parser {self.parser_id}: Required pattern '{name}' not found in msg {raw_message.original_id}")
                else:
                     self.logger.debug(f"Parser {self.parser_id}: Optional pattern '{name}' not found in msg {raw_message.original_id}")
                return None

        try:
            # --- Extract required fields ---
            action_instrument_match = self.ACTION_INSTRUMENT_PATTERN.search(text)
            if action_instrument_match:
                 parsed_data['action'] = action_instrument_match.group(1).upper()
                 parsed_data['symbol'] = action_instrument_match.group(2).upper()
                 # Action is BUY/SELL directly
            else:
                self.logger.debug(f"Parser {self.parser_id}: Action/Instrument not found in msg {raw_message.original_id}")
                return None # Essential line

            parsed_data['open_price'] = find_pattern(self.ENTRY_PRICE_PATTERN, "Entry Price")
            parsed_data['stop_loss'] = find_pattern(self.STOP_LOSS_PATTERN, "Stop Loss")

            # --- Extract Take Profits ---
            # Find *all* matches first
            tp_matches = self.TAKE_PROFIT_PATTERN.findall(text)
            if tp_matches:
                 parsed_data['take_profit'] = tp_matches[0] # Take the first one found
                 if len(tp_matches) > 1:
                     parsed_data['metadata'] = {'additional_tps': tp_matches[1:]}
                     self.logger.debug(f"Extracted TP1={tp_matches[0]}, additional={tp_matches[1:]}")
                 else:
                      self.logger.debug(f"Extracted TP={tp_matches[0]}")
            else:
                 parsed_data['take_profit'] = None # Mark as not found

            # --- Extract optional Lot Size ---
            parsed_data['volume'] = find_pattern(self.LOT_SIZE_PATTERN, "Lot Size", required=False)

            # --- Validation: Check required fields were found ---
            # Normalizer will handle type conversions and detailed validation
            required_fields = ['action', 'symbol', 'open_price', 'stop_loss', 'take_profit']
            missing_fields = [f for f in required_fields if not parsed_data.get(f)]
            if missing_fields:
                 self.logger.warning(f"Parser {self.parser_id}: Missing required fields {missing_fields} in msg {raw_message.original_id}")
                 return None

             # Default volume if not found
            if parsed_data['volume'] is None: parsed_data['volume'] = '0.0'


            # --- Add Common Info ---
            parsed_data['message_id'] = raw_message.original_id
            parsed_data['timestamp'] = raw_message.timestamp
            parsed_data['source_id'] = raw_message.source_id
            parsed_data['channel_info'] = raw_message.channel_info

            self.logger.info(f"Parser {self.parser_id}: Successfully parsed msg {raw_message.original_id} from source {raw_message.source_id}")
            self.logger.debug(f"Parsed data dict: {parsed_data}")
            return parsed_data

        except Exception as e:
            self.logger.error(f"Parser {self.parser_id}: Error parsing msg {raw_message.original_id}: {e}\nRaw Text:\n{text}", exc_info=True)
            return None