# parsers/telegram_parser_format4.py
import re
import logging
from decimal import Decimal, InvalidOperation
from .base_parser import BaseParser
try:
    from utils.message_models import RawMessage
except ImportError:
    RawMessage = dict

logger = logging.getLogger(__name__)

class TelegramFormat4Parser(BaseParser):
    """
    Parses signals from a private club format (Handles Format 4 Examples).
    Handles various asset name formats and numbers with spaces.
    """
    # Asset Name: Take the first non-empty line, attempt basic cleaning later.
    # Direction: Capture Buy/Sell within parentheses, case-insensitive.
    DIRECTION_PATTERN = re.compile(r"^\s*Direction:.*?\((Buy|Sell)\)\s*$", re.IGNORECASE | re.M)
    # Numbers: Capture digits, decimals, spaces, commas after keyword. Cleaning needed later.
    ENTRY_PATTERN = re.compile(r"^\s*Entry:\s*([\d\s,.]+)\s*$", re.IGNORECASE | re.M)
    TP_PATTERN = re.compile(r"^\s*TP\d*:\s*([\d\s,.]+)\s*$", re.IGNORECASE | re.M) # Use findall for multiple
    SL_PATTERN = re.compile(r"^\s*SL:\s*([\d\s,.]+)\s*$", re.IGNORECASE | re.M)
    LOT_SIZE_PATTERN = re.compile(r"^\s*Lot size:\s*([\d\.]+)\s*$", re.IGNORECASE | re.M) # Assuming no spaces in lots

    def _clean_number(self, num_str: str | None) -> str | None:
        """ Helper to remove spaces, commas and return valid number string or None """
        if num_str is None: return None
        try:
            # Remove spaces AND commas (useful for inputs like 1,234.56 or 5 513)
            cleaned = re.sub(r"[\s,]", "", num_str.strip())
            # Validate using regex: one or more digits, optional decimal part
            if re.fullmatch(r"\d+(\.\d+)?", cleaned):
                return cleaned
            else:
                self.logger.warning(f"_clean_number: Invalid number format after cleaning '{cleaned}' from '{num_str}'")
                return None
        except Exception as e:
            self.logger.error(f"_clean_number: Error processing '{num_str}': {e}")
            return None

    def _parse_asset(self, first_line: str) -> str | None:
         """ Extracts and potentially cleans the asset name from the first line """
         if not first_line: return None
         asset_name = first_line.strip()
         # Optional: Attempt to remove common leading non-alphanumeric chars (emojis etc.)
         # Be careful not to remove valid symbols like '/'
         # This regex removes common flag emojis or leading symbols safely
         # Assumes asset starts after first space if emoji present, otherwise uses whole line
         match = re.match(r"^[^\w\s]*\s*(.*)", asset_name) # Match leading non-word/space chars + space, capture rest
         if match and match.group(1):
              asset_name = match.group(1).strip()
         else: # Fallback if no clear leading symbol/space, use stripped original
              asset_name = asset_name.strip()

         # Convert multiple spaces to single space
         asset_name = re.sub(r'\s+', ' ', asset_name).upper() # Normalize to UPPERCASE for mapping
         return asset_name if asset_name else None


    def parse(self, raw_message: RawMessage) -> dict | None:
        """Parses the raw message text using Regex and line-by-line processing."""
        text = raw_message.text
        parsed_data = {}
        lines = [line.strip() for line in text.split("\n") if line.strip()]

        if not lines:
            self.logger.debug(f"Parser {self.parser_id}: Message empty {raw_message.original_id}")
            return None

        self.logger.debug(f"Parser {self.parser_id}: Processing message {raw_message.original_id}, {len(lines)} lines.")

        try:
            # --- Asset Name (First Line) ---
            parsed_data['symbol'] = self._parse_asset(lines[0])
            if not parsed_data['symbol']:
                self.logger.warning(f"Parser {self.parser_id}: Failed to extract Asset/Symbol from first line: '{lines[0]}'")
                return None # Require Asset/Symbol

            # --- Process Other Lines based on Keywords ---
            extracted_tp_values = []
            found_action = False
            found_entry = False
            found_sl = False
            found_tp = False # Track if at least one TP found

            for line in lines[1:]:
                if not parsed_data.get('action'): # Only find action once
                    match = self.DIRECTION_PATTERN.search(line)
                    if match:
                         parsed_data['action'] = match.group(1).upper()
                         found_action = True
                         continue # Move to next line

                if not parsed_data.get('open_price'): # Only find entry once
                    match = self.ENTRY_PATTERN.search(line)
                    if match:
                         num_str = self._clean_number(match.group(1))
                         if num_str:
                              parsed_data['open_price'] = num_str
                              found_entry = True
                         else: logger.warning(f"Failed to clean Entry number: {match.group(1)}")
                         continue

                # Find all TP lines
                match = self.TP_PATTERN.search(line)
                if match:
                    num_str = self._clean_number(match.group(1))
                    if num_str:
                         extracted_tp_values.append(num_str)
                         found_tp = True
                    else: logger.warning(f"Failed to clean TP number: {match.group(1)}")
                    continue # Assume TP line doesn't contain other keywords

                if not parsed_data.get('stop_loss'): # Only find SL once
                     match = self.SL_PATTERN.search(line)
                     if match:
                          num_str = self._clean_number(match.group(1))
                          if num_str:
                               parsed_data['stop_loss'] = num_str
                               found_sl = True
                          else: logger.warning(f"Failed to clean SL number: {match.group(1)}")
                          continue

                if 'volume' not in parsed_data: # Find optional Lot Size once
                     match = self.LOT_SIZE_PATTERN.search(line)
                     if match:
                          num_str = self._clean_number(match.group(1))
                          if num_str: parsed_data['volume'] = num_str
                          # Ignore secondary lot size for now
                          continue

            # --- Validation: Check required fields were found ---
            if not found_action:
                self.logger.warning(f"Parser {self.parser_id}: Direction pattern not found in msg {raw_message.original_id}")
                return None
            if not found_entry:
                 self.logger.warning(f"Parser {self.parser_id}: Entry pattern not found/invalid in msg {raw_message.original_id}")
                 return None
            if not found_sl:
                  self.logger.warning(f"Parser {self.parser_id}: SL pattern not found/invalid in msg {raw_message.original_id}")
                  return None
            if not found_tp:
                  self.logger.warning(f"Parser {self.parser_id}: TP pattern not found/invalid in msg {raw_message.original_id}")
                  return None

            # Process extracted TPs
            parsed_data['take_profit'] = extracted_tp_values[0] # First valid TP found
            if len(extracted_tp_values) > 1:
                parsed_data['metadata'] = {'additional_tps': extracted_tp_values[1:]}


            # Default volume if not parsed
            if 'volume' not in parsed_data: parsed_data['volume'] = '0.0'


            # --- Add Common Info ---
            parsed_data['message_id'] = raw_message.original_id
            parsed_data['timestamp'] = raw_message.timestamp
            parsed_data['source_id'] = raw_message.source_id
            parsed_data['channel_info'] = raw_message.channel_info

            self.logger.info(f"Parser {self.parser_id}: Successfully parsed msg {raw_message.original_id} from source {raw_message.source_id} (Asset: {parsed_data['symbol']}, Action: {parsed_data['action']})")
            self.logger.debug(f"Parsed data dict: {parsed_data}")
            return parsed_data

        except Exception as e:
            self.logger.error(f"Parser {self.parser_id}: Error parsing msg {raw_message.original_id}: {e}\nRaw Text:\n{text}", exc_info=True)
            return None