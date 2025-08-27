# parsers/telegram_parser.py
import re
import logging
from datetime import datetime

from .base_parser import BaseParser
from utils.message_models import RawMessage  # Type hinting


class TelegramFormat1Parser(BaseParser):
    """
    Parses Telegram messages based on the specific format found in fx_scalping.
    Example Format:
    📣Signal:  #OPEN #BUY
    💱Symbol: #AUDUSD
    💼Volume: 0.10
    🔓Open Price: 0.61903
    ↕️Stop-Loss: 0.61804
    ↕️Take-Profit: 0.62793
    --- or ---
    📣Signal:  #CLOSE #SELL
    💱Symbol: #USDCHF
    💼Volume: 0.10
    🔓Open Price: 0.85457
    ↕️Stop-Loss: 0.86737
    ↕️Take-Profit: 0.80452
    """

    # Define Regex patterns for robust extraction
    # Using re.VERBOSE for readability
    # Match Action (OPEN/CLOSE) and Direction (BUY/SELL)
    ACTION_PATTERN = re.compile(r"Signal:\s*#(?P<action>OPEN|CLOSE)\s*#(?P<direction>BUY|SELL)", re.IGNORECASE)
    # Match other fields, allowing for extra spaces, using key identifier words
    SYMBOL_PATTERN = re.compile(r"Symbol:\s*#?(?P<symbol>[A-Z]+)",
                                re.IGNORECASE)  # Assumes symbol is letters only after #
    VOLUME_PATTERN = re.compile(r"Volume:\s*(?P<volume>\d+\.?\d*)", re.IGNORECASE)
    OPEN_PRICE_PATTERN = re.compile(r"Open Price:\s*(?P<open_price>\d+\.?\d*)", re.IGNORECASE)
    STOP_LOSS_PATTERN = re.compile(r"Stop-Loss:\s*(?P<stop_loss>\d+\.?\d*)", re.IGNORECASE)
    TAKE_PROFIT_PATTERN = re.compile(r"Take-Profit:\s*(?P<take_profit>\d+\.?\d*)", re.IGNORECASE)

    def parse(self, raw_message: RawMessage):
        """Parses the raw message text using Regex."""
        text = raw_message.text
        parsed_data = {}
        signal_action = None  # To differentiate between OPEN and CLOSE action types

        try:
            # 1. Find Action and Direction
            action_match = self.ACTION_PATTERN.search(text)
            if action_match:
                action = action_match.group('action').upper()
                direction = action_match.group('direction').upper()  # Original direction BUY/SELL
                parsed_data['action'] = action  # Store primary action (OPEN/CLOSE)
                parsed_data['direction'] = direction  # Store direction for reference if needed
                signal_action = action  # Keep track of OPEN vs CLOSE
                self.logger.debug(f"Parser {self.parser_id}: Found Action={action}, Direction={direction}")
            else:
                self.logger.debug(
                    f"Parser {self.parser_id}: Action pattern not found in message ID {raw_message.original_id}.")
                return None  # Not a signal if action is missing

            # 2. Find Symbol
            symbol_match = self.SYMBOL_PATTERN.search(text)
            if symbol_match:
                parsed_data['symbol'] = symbol_match.group('symbol').upper()
            else:
                self.logger.warning(f"Parser {self.parser_id}: Symbol not found for signal {raw_message.original_id}.")
                return None  # Require symbol

            # 3. Find Open Price (Required for OPEN and CLOSE)
            open_price_match = self.OPEN_PRICE_PATTERN.search(text)
            if open_price_match:
                parsed_data['open_price'] = float(open_price_match.group('open_price'))
            else:
                self.logger.warning(
                    f"Parser {self.parser_id}: Open Price not found for signal {raw_message.original_id}.")
                return None  # Require open price

            # --- Fields primarily for OPEN signals ---
            if signal_action == "OPEN":
                volume_match = self.VOLUME_PATTERN.search(text)
                if volume_match:
                    parsed_data['volume'] = float(volume_match.group('volume'))
                else:  # Volume might be optional? Set default or return None if required
                    parsed_data['volume'] = 0.0  # Default to 0 if missing
                    self.logger.debug(
                        f"Parser {self.parser_id}: Volume not found for OPEN signal {raw_message.original_id}, using 0.")

                sl_match = self.STOP_LOSS_PATTERN.search(text)
                if sl_match:
                    parsed_data['stop_loss'] = float(sl_match.group('stop_loss'))
                else:
                    self.logger.warning(
                        f"Parser {self.parser_id}: Stop Loss not found for OPEN signal {raw_message.original_id}.")
                    return None  # Usually require SL for OPEN

                tp_match = self.TAKE_PROFIT_PATTERN.search(text)
                if tp_match:
                    parsed_data['take_profit'] = float(tp_match.group('take_profit'))
                else:
                    self.logger.warning(
                        f"Parser {self.parser_id}: Take Profit not found for OPEN signal {raw_message.original_id}.")
                    return None  # Usually require TP for OPEN

            elif signal_action == "CLOSE":
                # For CLOSE, we mainly needed action, symbol, open_price.
                # We *could* try to parse original SL/TP/Vol from CLOSE msg if they exist
                # But based on previous info, they might not be reliable or needed for the 'match by comment' logic
                pass  # No other essential fields needed *from parsing* for basic CLOSE

            # Add message ID and timestamp from the raw message object
            parsed_data['message_id'] = raw_message.original_id
            parsed_data['timestamp'] = raw_message.timestamp

            self.logger.info(f"Parser {self.parser_id}: Successfully parsed signal: {parsed_data}")
            return parsed_data  # Return the dictionary of extracted (but not normalized) data

        except Exception as e:
            self.logger.error(
                f"Parser {self.parser_id}: Error parsing message ID {raw_message.original_id}: {e}\nRaw Text:\n{text}",
                exc_info=True)
            return None  # Return None on any parsing error
