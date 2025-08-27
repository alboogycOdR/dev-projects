# normalizer.py (SignalAggregatorV3 directory)
import logging
import re
from datetime import datetime
logger = logging.getLogger("Normalizer")

def normalize_signal(parsed_data: dict, symbol_map: dict = None) -> dict | None:
    if not isinstance(parsed_data, dict):
        logger.warning("Input not dict.")
        return None

    logger.debug(f"NORMALIZE START: Input Parsed Dict = {parsed_data}") # <-- DEBUG 1

    try:
        normalized = {}
        # --- IDs ---
        normalized['original_message_id'] = str(parsed_data.get('message_id', '0'))
        
        # --- Timestamp ---
        timestamp_dt = parsed_data.get('timestamp')
        if not isinstance(timestamp_dt, datetime):
            logger.warning(f"Norm: TS is not datetime obj for {normalized['original_message_id']}")
            return None
        normalized['timestamp_dt'] = timestamp_dt
        normalized['timestamp_unix'] = int(timestamp_dt.timestamp())

        # --- Action Normalization ---
        action = str(parsed_data.get('action', '')).upper() # Local var for processing
        logger.debug(f"NORMALIZE ACTION: 1. Initial 'action' var = '{action}'") # <-- DEBUG 2a

        # Handle OPEN case
        if action == "OPEN" and 'direction' in parsed_data:
            direction = str(parsed_data.get('direction','')).upper()
            logger.debug(f"NORMALIZE ACTION: 2. Found OPEN, direction = '{direction}'") # <-- DEBUG 2b
            if direction in ["BUY", "SELL"]:
                action = direction # Promote direction to be the primary action
                logger.debug(f"NORMALIZE ACTION: 3. Promoted local 'action' var to '{action}'") # <-- DEBUG 2c
            else:
                logger.warning(f"Norm: Invalid direction '{direction}' for OPEN {normalized['original_message_id']}. Discarding.")
                return None

        # Validate the *final value* of the local 'action' variable
        if action not in ["BUY", "SELL", "CLOSE"]:
             logger.warning(f"Norm: Unsupported final 'action' var '{action}' for {normalized['original_message_id']}. Discarding.")
             return None

        # ===> ASSIGN the final validated action to the dictionary <===
        logger.debug(f"NORMALIZE ACTION: 4. Assigning final '{action}' to normalized['action']") # <-- DEBUG 3
        normalized['action'] = action

        # --- Symbol Normalization ---
        symbol = str(parsed_data.get('symbol', '')).upper()
        # ... (mapping/cleaning) ...
        symbol = re.sub(r'[^A-Z0-9._-]', '', symbol)
        if not symbol: return None # Guard
        normalized['symbol'] = symbol

        # --- Price/Volume ---
        # ... (Existing code for open_price, sl, tp, vol, original_open_msg_id seems okay) ...
        # ... ensure all required try/except blocks are present ...
        open_price_str = parsed_data.get('open_price')
        if open_price_str is None: return None
        try:
            normalized['open_price'] = float(open_price_str)
            if normalized['open_price'] <= 0: raise ValueError("Price <= 0")
        except (ValueError, TypeError): return None # Simplified exit

        # Reset fields that depend on action
        normalized['stop_loss'] = 0.0
        normalized['take_profit'] = 0.0
        normalized['volume'] = 0.0
        normalized['original_open_msg_id'] = 0

        if normalized['action'] == "CLOSE":
             original_id_str = parsed_data.get('original_open_msg_id')
             if original_id_str:
                  try: normalized['original_open_msg_id'] = int(original_id_str)
                  except: pass # Ignore if invalid format, stays 0
        else: # BUY or SELL
            try:
                normalized['stop_loss'] = float(parsed_data.get('stop_loss', 0.0))
                normalized['take_profit'] = float(parsed_data.get('take_profit', 0.0))
                normalized['volume'] = float(parsed_data.get('volume', 0.0))
                 # Add validation if needed that SL/TP are > 0
            except (ValueError, TypeError, AttributeError):
                 logger.warning(f"Invalid price/vol found during normalization for {normalized['original_message_id']}", exc_info=True)
                 return None # Require valid numbers for OPEN


        # --- Other Fields ---
        normalized['internal_id'] = f"{parsed_data.get('source_id', 'unknown')}-{normalized['original_message_id']}"
        normalized['source_info'] = f"Source:{parsed_data.get('source_id','N/A')}|Chan:{parsed_data.get('channel_info','N/A')}"

        # --- FINAL DEBUG ---
        # Use logger.debug for less noise, set logging level to DEBUG in config to see these
        logger.debug(f"NORMALIZER RETURNING: { {k:v for k,v in normalized.items() if k != 'timestamp_dt'} }") # <-- DEBUG 4
        return normalized

    except Exception as e:
        logger.error(f"Unexpected error during normalization for msg {parsed_data.get('message_id', 'N/A')}: {e}", exc_info=True)
        return None