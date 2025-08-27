# parsers/telegram_parser_format2.py
import re
import logging
from decimal import Decimal, InvalidOperation # Use Decimal for potentially high precision numbers
from .base_parser import BaseParser
from utils.message_models import RawMessage

logger = logging.getLogger(__name__)

class TelegramFormat2Parser(BaseParser):
    """
    Parses signals from channels like @DeriveVIKnightsPtY.
    Format Example:
    BUY STEPINDEX500
    @ 6352.8
    Sl 6326.6
    Tp 6402.3
    Tp2 6452.6
    Tp3 6502.9
    Lotsize 0.15(0.2)
    """
    # Using MULTILINE mode (re.M) so ^ matches start of line
    # Allow optional leading characters/whitespace before action
    ACTION_INSTRUMENT_PATTERN = re.compile(r"^\*?\s*(BUY|SELL)\s+([A-Z0-9_.-]+)", re.IGNORECASE | re.M)
    ENTRY_PRICE_PATTERN = re.compile(r"^\s*@\s+(\d+\.?\d*)", re.IGNORECASE | re.M)
    STOP_LOSS_PATTERN = re.compile(r"^\s*Sl\s+(\d+\.?\d*)", re.IGNORECASE | re.M)
    # Match Tp, Tp1, Tp2 etc. - find all instances
    TAKE_PROFIT_PATTERN = re.compile(r"^\s*Tp\d*\s+(\d+\.?\d*)", re.IGNORECASE | re.M)
    # Capture primary lot size and optional secondary in brackets
    LOT_SIZE_PATTERN = re.compile(r"^\s*Lotsize\s+(\d+\.?\d*)\s*(?:\(\s*(\d+\.?\d*)\s*\))?", re.IGNORECASE | re.M)

    def parse(self, raw_message: RawMessage) -> dict | None:
        text = raw_message.text
        parsed_data = {}

        try:
            # --- Extract Action & Instrument (Symbol) ---
            action_match = self.ACTION_INSTRUMENT_PATTERN.search(text)
            if action_match:
                # Action is BUY or SELL directly from this format
                parsed_data['action'] = action_match.group(1).upper()
                parsed_data['symbol'] = action_match.group(2).upper()
                # No separate 'direction' key needed
            else:
                self.logger.debug(f"Parser {self.parser_id}: Action/Instrument pattern not found in msg {raw_message.original_id}.")
                return None

            # --- Extract Entry Price ---
            entry_match = self.ENTRY_PRICE_PATTERN.search(text)
            if entry_match:
                # Store as string, normalizer handles conversion
                parsed_data['open_price'] = entry_match.group(1)
            else:
                self.logger.warning(f"Parser {self.parser_id}: Entry Price (@) not found for msg {raw_message.original_id}")
                return None # Essential field

            # --- Extract Stop Loss ---
            sl_match = self.STOP_LOSS_PATTERN.search(text)
            if sl_match:
                 parsed_data['stop_loss'] = sl_match.group(1)
            else:
                self.logger.warning(f"Parser {self.parser_id}: Stop Loss (Sl) not found for msg {raw_message.original_id}")
                return None # Essential field

            # --- Extract Take Profit(s) ---
            # Find ALL TP matches
            tp_matches = self.TAKE_PROFIT_PATTERN.findall(text)
            if tp_matches:
                 # For V3 compatibility, take the FIRST one found as the primary TP
                 parsed_data['take_profit'] = tp_matches[0]
                 if len(tp_matches) > 1:
                      # Store others in metadata if needed later
                      parsed_data['metadata'] = {'additional_tps': tp_matches[1:]}
                      self.logger.debug(f"Parser {self.parser_id}: Found primary TP {tp_matches[0]} and additional TPs {tp_matches[1:]} for msg {raw_message.original_id}")
                 else:
                      self.logger.debug(f"Parser {self.parser_id}: Found primary TP {tp_matches[0]} for msg {raw_message.original_id}")

            else:
                self.logger.warning(f"Parser {self.parser_id}: Take Profit (Tp) not found for msg {raw_message.original_id}")
                return None # Essential field

            # --- Extract Lot Size (Volume) ---
            lot_match = self.LOT_SIZE_PATTERN.search(text)
            if lot_match:
                 # Take the first lot size found
                 parsed_data['volume'] = lot_match.group(1)
                 # Optional: store alternative lot size if needed
                 if lot_match.group(2):
                      if 'metadata' not in parsed_data: parsed_data['metadata'] = {}
                      parsed_data['metadata']['alt_lot_size'] = lot_match.group(2)
                 self.logger.debug(f"Parser {self.parser_id}: Found Volume {parsed_data['volume']} for msg {raw_message.original_id}")
            else:
                self.logger.debug(f"Parser {self.parser_id}: Lot size not found for msg {raw_message.original_id}. Using default (0).")
                parsed_data['volume'] = '0.0' # Default if missing

            # --- Add Common Info ---
            parsed_data['message_id'] = raw_message.original_id
            parsed_data['timestamp'] = raw_message.timestamp # Pass datetime obj
            parsed_data['source_id'] = raw_message.source_id
            parsed_data['channel_info'] = raw_message.channel_info

            self.logger.info(f"Parser {self.parser_id}: Successfully parsed msg {raw_message.original_id} from source {raw_message.source_id}")
            self.logger.debug(f"Parsed data dict: {parsed_data}")
            return parsed_data

        except Exception as e:
            self.logger.error(f"Parser {self.parser_id}: Error parsing msg {raw_message.original_id}: {e}\nRaw Text:\n{text}", exc_info=True)
            return None