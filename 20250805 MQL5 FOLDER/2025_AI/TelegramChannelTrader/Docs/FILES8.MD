Okay, absolutely. Here are the complete contents for those 6 Python files, consolidating the versions we developed for the V3 structure.

Make sure to place these files in the correct directories within your `SignalAggregatorV3` project folder (`utils/`, `connectors/`, `parsers/`, and the rest in the main directory).

---

**1. `utils/message_models.py`**

```python
# utils/message_models.py
from dataclasses import dataclass, field
from datetime import datetime

@dataclass
class RawMessage:
    """Standardized representation of a raw message from a source."""
    source_id: str          # Unique ID of the source defined in config.yaml (e.g., 'telegram_fxscalping')
    connector_type: str     # Type of connector (e.g., 'telegram_user', 'discord_bot')
    original_id: str        # Platform-specific message ID (e.g., Telegram message ID)
    timestamp: datetime     # Timestamp of the message (preferably UTC and timezone-aware)
    text: str               # The raw text content of the message
    channel_info: str       # Info about the channel/chat it came from (e.g., username, ID)
    author_info: str = ""   # Info about the author (if available/relevant)
    metadata: dict = field(default_factory=dict) # Any other source-specific details (e.g., reply info)

```

---

**2. `connectors/base_connector.py`** (Base class - important to have)

```python
# connectors/base_connector.py
from abc import ABC, abstractmethod
import logging
import asyncio
# Choose Queue type based on whether processor runs in thread or async task
# from queue import Queue # For thread-based processor
from asyncio import Queue # For async-based processor

class BaseConnector(ABC):
    """Abstract base class for all signal source connectors."""
    def __init__(self, source_id: str, config: dict, message_queue: Queue):
        self.source_id = source_id
        self.config = config # Specific config section for this source
        self.message_queue = message_queue # Async or standard queue to pass raw messages
        self.logger = logging.getLogger(f"Connector.{self.source_id}")
        self._is_running = False # Flag to control running state

    @abstractmethod
    async def connect(self) -> bool:
        """Establishes connection to the source. Returns True on success."""
        pass

    @abstractmethod
    async def start_listening(self):
        """Starts listening for or fetching new messages."""
        pass

    @abstractmethod
    async def stop(self):
        """Stops listening and disconnects."""
        pass

    async def run(self):
        """Main run loop for the connector."""
        self._is_running = True
        self.logger.info("Starting...")
        if await self.connect():
             await self.start_listening()
        else:
            self.logger.error("Connection failed. Connector will not listen.")
        self.logger.info("Run loop finished.")
        self._is_running = False

```

---

**3. `connectors/telegram_connector.py`**

```python
# connectors/telegram_connector.py
import logging
import asyncio
# from queue import Queue # Use standard Queue if processor is threaded
from asyncio import Queue # Use asyncio Queue if processor is async
from datetime import timezone

from telethon import TelegramClient, events, errors

from .base_connector import BaseConnector
from utils.message_models import RawMessage # Import our standard message format

class TelegramUserConnector(BaseConnector):
    """Connects to Telegram as a user account using Telethon."""

    def __init__(self, source_id: str, config: dict, message_queue: Queue):
        super().__init__(source_id, config, message_queue)
        self.client = None
        self.session_name = config.get('session_name', source_id) # Use source_id as default session name
        self.credentials = config.get('credentials', {})
        self.targets = config.get('targets', []) # List of channel usernames/IDs to monitor

        if not self.credentials or not all(k in self.credentials for k in ['api_id', 'api_hash', 'phone']):
            raise ValueError(f"Missing 'api_id', 'api_hash', or 'phone' in credentials for Telegram source {source_id}")

    async def connect(self) -> bool:
        """Initializes and connects the Telethon client."""
        if self.client and self.client.is_connected():
            self.logger.info("Already connected.")
            return True
        try:
            self.logger.info(f"Initializing Telethon client with session '{self.session_name}'...")
            self.client = TelegramClient(
                self.session_name,
                int(self.credentials['api_id']),
                self.credentials['api_hash']
            )
            self.logger.info("Connecting to Telegram...")
            # Increased timeout for connection potentially
            await asyncio.wait_for(self.client.connect(), timeout=30.0)
            self.logger.info("Connection attempt finished.")

            if not await self.client.is_user_authorized():
                self.logger.warning("Authorization required. Manual intervention needed.")
                await self.client.send_code_request(self.credentials['phone'])
                # NOTE: Production systems need a better way to handle this
                # Maybe signal main app, or require pre-authorization.
                # Raising exception for now to halt setup if code needed.
                raise RuntimeError(f"Telegram authorization required for {self.credentials['phone']}. Enter code via separate run or pre-authorize session.")
                # Code below for interactive sign-in:
                # try:
                #     code = input(f"Enter Telegram code for {self.credentials['phone']}: ")
                #     await self.client.sign_in(self.credentials['phone'], code)
                # except errors.SessionPasswordNeededError:
                #     pwd = input("Enter 2FA password: ")
                #     await self.client.sign_in(password=pwd)
                # self.logger.info("Signed in successfully!")
            else:
                self.logger.info("Already authorized.")
            return True # Return connection status

        except asyncio.TimeoutError:
            self.logger.error("Connection to Telegram timed out.")
            self.client = None
            return False
        except RuntimeError as e: # Catch our manual authorization error
             self.logger.error(str(e))
             if self.client and self.client.is_connected(): await self.client.disconnect()
             self.client = None
             return False
        except Exception as e:
            self.logger.error(f"Failed to connect or authorize: {e}", exc_info=True)
            if self.client and self.client.is_connected(): await self.client.disconnect()
            self.client = None
            return False

    def _create_message_handler(self):
        """Creates the handler function for Telethon."""

        async def handle_new_message(event):
            try:
                message = event.message
                if not message or not message.text: # Ignore empty messages or media captions for now
                    return

                chat = await event.get_chat() # Get chat entity to extract info
                channel_info = getattr(chat, 'username', None)
                if channel_info: channel_info = f"@{channel_info}"
                else: channel_info = str(getattr(chat, 'id', 'UnknownChannel'))

                # Make sure timestamp is timezone-aware (UTC)
                ts = message.date.replace(tzinfo=timezone.utc) if message.date else datetime.now(timezone.utc)


                self.logger.info(f"Received MsgID:{message.id} from {channel_info} via {self.source_id}")
                self.logger.debug(f"Raw Text: {message.text[:100]}...") # Log truncated text

                # Create the standardized RawMessage object
                raw_msg = RawMessage(
                    source_id=self.source_id,
                    connector_type='telegram_user',
                    original_id=str(message.id),
                    timestamp=ts,
                    text=message.text,
                    channel_info=channel_info,
                    metadata={'is_reply': message.is_reply, 'reply_to_msg_id': str(message.reply_to_msg_id) if message.reply_to_msg_id else None}
                    # Added reply info to metadata - parser might use this later
                )

                # Put the raw message onto the central async queue
                try:
                    # If queue gets full, this might block or raise error depending on setup
                    # Consider timeout or nowait variant if needed
                    await self.message_queue.put(raw_msg)
                except asyncio.QueueFull:
                    self.logger.warning(f"Message queue is full! Discarding message {raw_msg.original_id}")
                except Exception as qe:
                     self.logger.error(f"Error putting message on queue: {qe}")

            except Exception as e:
                # Avoid crashing the handler loop
                self.logger.error(f"Error processing incoming message event: {e}", exc_info=True)

        return handle_new_message


    async def start_listening(self):
        """Registers handler and starts the Telethon client's event loop."""
        if not self.client or not self.client.is_connected():
             self.logger.error("Client not connected, cannot start listening.")
             return

        try:
            # Resolve targets if possible (helps with dynamic joining etc.)
            # target_entities = []
            # for target in self.targets:
            #    try:
            #        entity = await self.client.get_entity(target)
            #        target_entities.append(entity)
            #    except Exception as e:
            #        self.logger.error(f"Could not resolve target '{target}': {e}")
            # if not target_entities:
            #    self.logger.error("No valid targets resolved. Stopping.")
            #    return

            # Register the handler function directly
            handler = self._create_message_handler()
            # Register for the specified targets in config
            self.client.add_event_handler(handler, events.NewMessage(chats=self.targets))
            self.logger.info(f"Registered message handler for targets: {self.targets}")

            self.logger.info("Starting Telethon client's event loop (run_until_disconnected)...")
            self._is_running = True
            await self.client.run_until_disconnected()

        except Exception as e:
             # Catch errors during listening phase
             self.logger.error(f"Telethon client run_until_disconnected error: {e}", exc_info=True)
        finally:
             self._is_running = False
             self.logger.info("Telethon client listener loop has ended.")


    async def stop(self):
        """Disconnects the Telethon client."""
        self.logger.info("Stopping connector...")
        if self.client and self.client.is_connected():
            self.logger.info("Disconnecting Telethon client...")
            # Telethon >= 1.20: Use await client.disconnect()
            # Telethon < 1.20: Use client.disconnect()
            try:
                await self.client.disconnect()
                self.logger.info("Telethon client disconnected.")
            except Exception as e:
                 self.logger.error(f"Error during disconnect: {e}")
        self.client = None

```

---

**4. `parsers/base_parser.py`** (Base class - important to have)

```python
# parsers/base_parser.py
from abc import ABC, abstractmethod
import logging
from utils.message_models import RawMessage # Use for type hinting

class BaseParser(ABC):
    """Abstract base class for all signal format parsers."""
    def __init__(self, parser_id: str, config: dict):
        self.parser_id = parser_id
        self.config = config # Specific config section for this parser
        self.logger = logging.getLogger(f"Parser.{self.parser_id}")

    @abstractmethod
    def parse(self, raw_message: RawMessage) -> dict | None:
        """
        Parses a raw message object.

        Args:
            raw_message: The RawMessage object from a connector.

        Returns:
            A dictionary with extracted signal data fields (non-normalized,
            using common keys like 'action', 'symbol', 'open_price', 'stop_loss',
            'take_profit', 'volume', 'message_id', 'timestamp').
            It can include additional fields like 'direction' or 'original_open_msg_id'.
            Returns None if parsing fails or message doesn't match format.
        """
        pass
```

---

**5. `parsers/telegram_parser.py`**

```python
# parsers/telegram_parser.py
import re
import logging
from datetime import datetime, timezone

from .base_parser import BaseParser
from utils.message_models import RawMessage # For type hinting

class TelegramFormat1Parser(BaseParser):
    """
    Parses Telegram messages based on the specific 'fx_scalping' format.
    Handles OPEN and CLOSE signals.
    Attempts to find original_open_msg_id for CLOSE signals if available in metadata.
    """
    # Regex patterns compiled for efficiency
    ACTION_PATTERN = re.compile(r"Signal:.*#(?P<action>OPEN|CLOSE)\s*#(?P<direction>BUY|SELL)", re.IGNORECASE | re.DOTALL)
    SYMBOL_PATTERN = re.compile(r"Symbol:.*#(?P<symbol>[A-Z0-9_.-]+)", re.IGNORECASE | re.DOTALL) # Allow more chars in symbol
    VOLUME_PATTERN = re.compile(r"Volume:.*?(?P<volume>\d+\.?\d*)", re.IGNORECASE | re.DOTALL)
    OPEN_PRICE_PATTERN = re.compile(r"Open Price:.*?(?P<open_price>\d+\.?\d*)", re.IGNORECASE | re.DOTALL)
    STOP_LOSS_PATTERN = re.compile(r"Stop-Loss:.*?(?P<stop_loss>\d+\.?\d*)", re.IGNORECASE | re.DOTALL)
    TAKE_PROFIT_PATTERN = re.compile(r"Take-Profit:.*?(?P<take_profit>\d+\.?\d*)", re.IGNORECASE | re.DOTALL)

    def parse(self, raw_message: RawMessage) -> dict | None:
        """Parses the raw message text using Regex."""
        text = raw_message.text
        parsed_data = {}
        signal_action = None # Store OPEN or CLOSE

        try:
            # Add common message info first
            parsed_data['message_id'] = raw_message.original_id
            parsed_data['timestamp'] = raw_message.timestamp # Keep as datetime object

            # 1. Find Action and Direction
            action_match = self.ACTION_PATTERN.search(text)
            if action_match:
                action = action_match.group('action').upper()
                direction = action_match.group('direction').upper()
                parsed_data['action'] = action # Store primary action (OPEN/CLOSE)
                # Store original BUY/SELL direction - might be useful for context/validation
                parsed_data['direction'] = direction
                signal_action = action
                self.logger.debug(f"Parser {self.parser_id}: Found Action={action}, Direction={direction}")
            else:
                self.logger.debug(f"Parser {self.parser_id}: Action pattern not found in msg {raw_message.original_id}.")
                return None # Not a signal if essential action is missing

            # 2. Find Symbol
            symbol_match = self.SYMBOL_PATTERN.search(text)
            if symbol_match:
                # Symbol is critical, extract and make uppercase
                parsed_data['symbol'] = symbol_match.group('symbol').upper()
            else:
                self.logger.warning(f"Parser {self.parser_id}: Symbol not found for signal msg {raw_message.original_id}.")
                return None # Require symbol

            # 3. Find Open Price (Required for both OPEN and CLOSE variants)
            open_price_match = self.OPEN_PRICE_PATTERN.search(text)
            if open_price_match:
                # Extract as string, normalization will handle conversion/validation
                 parsed_data['open_price'] = open_price_match.group('open_price')
            else:
                self.logger.warning(f"Parser {self.parser_id}: Open Price not found for signal msg {raw_message.original_id}.")
                return None # Require open price

            # 4. Parse optional fields, mainly for OPEN
            if signal_action == "OPEN":
                volume_match = self.VOLUME_PATTERN.search(text)
                parsed_data['volume'] = volume_match.group('volume') if volume_match else None

                sl_match = self.STOP_LOSS_PATTERN.search(text)
                parsed_data['stop_loss'] = sl_match.group('stop_loss') if sl_match else None
                # Could add validation: return None if sl_match is None for OPEN

                tp_match = self.TAKE_PROFIT_PATTERN.search(text)
                parsed_data['take_profit'] = tp_match.group('take_profit') if tp_match else None
                # Could add validation: return None if tp_match is None for OPEN

            elif signal_action == "CLOSE":
                 # For CLOSE signals meant for comment matching, we need the original OPEN signal ID.
                 # Attempt to get it if the CLOSE message was a reply
                 if raw_message.metadata and raw_message.metadata.get('is_reply'):
                      original_id = raw_message.metadata.get('reply_to_msg_id')
                      if original_id:
                           parsed_data['original_open_msg_id'] = original_id # Pass the replied-to ID
                           self.logger.info(f"Parser {self.parser_id}: Found CLOSE signal replying to original msg {original_id}")
                      else:
                          self.logger.warning(f"Parser {self.parser_id}: CLOSE signal {raw_message.original_id} is a reply, but original ID is missing in metadata.")
                 else:
                      # If not a reply, comment matching isn't possible unless the ID is in the text itself
                      # (Need a different regex/logic if the CLOSE text contains the OPEN ID)
                      self.logger.debug(f"Parser {self.parser_id}: CLOSE signal {raw_message.original_id} is not a reply. Cannot determine original_open_msg_id for comment matching.")


            # Add extra info that might be needed by Normalizer or later stages
            parsed_data['source_id'] = raw_message.source_id
            parsed_data['channel_info'] = raw_message.channel_info

            self.logger.info(f"Parser {self.parser_id}: Successfully parsed msg {raw_message.original_id}")
            self.logger.debug(f"Parsed data dict: {parsed_data}")
            return parsed_data

        except Exception as e:
            self.logger.error(f"Parser {self.parser_id}: Error parsing msg {raw_message.original_id}: {e}\nRaw Text:\n{text}", exc_info=True)
            return None
```

---

**6. `normalizer.py`** (Includes logic for CLOSE using `original_open_msg_id`)

```python
# normalizer.py (SignalAggregatorV3 directory)
import logging
import re
from datetime import datetime

logger = logging.getLogger("Normalizer")

def normalize_signal(parsed_data: dict, symbol_map: dict = None) -> dict | None:
    """
    Normalizes parsed signal data into a standard internal format.
    Now expects parsers to provide datetime object for timestamp.
    Expects 'original_open_msg_id' from parser for CLOSE signals if available.
    """
    if not isinstance(parsed_data, dict):
        logger.warning("Invalid input to normalize_signal: not a dictionary.")
        return None

    try:
        normalized = {}

        # --- IDs and Timestamps ---
        normalized['original_message_id'] = str(parsed_data.get('message_id', '0'))
        timestamp_dt = parsed_data.get('timestamp')
        if not isinstance(timestamp_dt, datetime):
            logger.warning(f"Timestamp is not a datetime object for msg {normalized['original_message_id']}. Type: {type(timestamp_dt)}")
            return None # Enforce datetime from parser
        normalized['timestamp_unix'] = int(timestamp_dt.timestamp()) # Keep Unix version
        normalized['timestamp_dt'] = timestamp_dt # Keep datetime object too

        # --- Action Normalization (Handles 'OPEN' + 'direction' if needed) ---
        action = str(parsed_data.get('action', '')).upper()
        if action == "OPEN" and 'direction' in parsed_data:
            direction = str(parsed_data.get('direction','')).upper()
            if direction in ["BUY", "SELL"]:
                action = direction
                logger.debug(f"Promoted OPEN + {direction} to action {action} for {normalized['original_message_id']}")
            else:
                 logger.warning(f"Invalid direction '{direction}' for OPEN action in msg {normalized['original_message_id']}.")
                 return None
        if action not in ["BUY", "SELL", "CLOSE"]:
             logger.warning(f"Unsupported final action '{action}' for msg {normalized['original_message_id']}.")
             return None
        normalized['action'] = action

        # --- Symbol Normalization ---
        symbol = str(parsed_data.get('symbol', '')).upper()
        if not symbol:
            logger.warning(f"Missing symbol for msg {normalized['original_message_id']}.")
            return None
        # Apply mapping
        if symbol_map and symbol in symbol_map:
            original_symbol = symbol
            symbol = symbol_map[symbol].upper()
            logger.debug(f"Mapped symbol '{original_symbol}' to '{symbol}' for msg {normalized['original_message_id']}")
        # Apply final cleaning (adjust regex based on target symbols)
        symbol = re.sub(r'[^A-Z0-9]', '', symbol) # Basic Alphanumeric
        if not symbol:
            logger.warning(f"Symbol empty after cleaning for msg {normalized['original_message_id']}")
            return None
        normalized['symbol'] = symbol

        # --- Price/Volume ---
        # Open Price (must exist, validated as float)
        open_price_str = parsed_data.get('open_price')
        if open_price_str is None: return None # Already checked by parser maybe, but check again
        try:
            normalized['open_price'] = float(open_price_str)
            if normalized['open_price'] <= 0: raise ValueError("Price <= 0")
        except (ValueError, TypeError):
             logger.warning(f"Invalid 'open_price' ('{open_price_str}') for msg {normalized['original_message_id']}")
             return None

        # Initialize SL/TP/Vol/OriginalID
        normalized['stop_loss'] = 0.0
        normalized['take_profit'] = 0.0
        normalized['volume'] = 0.0
        normalized['original_open_msg_id'] = 0 # Important: Reset for each signal

        # Process based on final action
        if normalized['action'] == "CLOSE":
            original_id_str = parsed_data.get('original_open_msg_id')
            if original_id_str:
                try:
                    # Ensure it's parsed as int/long for MQL5 struct compatibility
                    original_id_int = int(original_id_str)
                    if original_id_int > 0:
                        normalized['original_open_msg_id'] = original_id_int
                        logger.info(f"Normalized CLOSE for msg {normalized['original_message_id']} linking to original open msg {original_id_int}")
                    else:
                         logger.warning(f"Parsed 'original_open_msg_id' is not positive ('{original_id_str}') for CLOSE msg {normalized['original_message_id']}")
                         # If not found/invalid, MQL5 comment matching won't work unless alternative exists
                         # Fail normalization if this ID is mandatory for CLOSE? Or let MQL handle failure?
                         # For now, allow it pass normalization, MQL5 will fail to find matching comment.
                except (ValueError, TypeError):
                     logger.warning(f"Invalid 'original_open_msg_id' format ('{original_id_str}') for CLOSE msg {normalized['original_message_id']}")
            else:
                logger.warning(f"CLOSE signal {normalized['original_message_id']} lacks 'original_open_msg_id' needed for reliable MQL5 comment matching.")

        else: # BUY or SELL
            try: # Stop Loss
                sl_str = parsed_data.get('stop_loss')
                if sl_str is None: raise ValueError("Stop Loss missing")
                sl = float(sl_str)
                if sl <= 0: raise ValueError("Stop Loss <= 0")
                normalized['stop_loss'] = sl
            except (ValueError, TypeError) as e:
                logger.warning(f"Invalid Stop Loss ('{parsed_data.get('stop_loss')}') for {normalized['action']} msg {normalized['original_message_id']}: {e}")
                return None # Require valid SL for OPEN actions

            try: # Take Profit
                tp_str = parsed_data.get('take_profit')
                if tp_str is None: raise ValueError("Take Profit missing")
                tp = float(tp_str)
                if tp <= 0: raise ValueError("Take Profit <= 0")
                normalized['take_profit'] = tp
            except (ValueError, TypeError) as e:
                logger.warning(f"Invalid Take Profit ('{parsed_data.get('take_profit')}') for {normalized['action']} msg {normalized['original_message_id']}: {e}")
                return None # Require valid TP for OPEN actions

            try: # Volume (Optional?)
                vol_str = parsed_data.get('volume')
                if vol_str is not None:
                     normalized['volume'] = float(vol_str)
                # else volume stays 0.0, MQL5 calculates if mode allows
            except (ValueError, TypeError) as e:
                 logger.warning(f"Invalid Volume ('{parsed_data.get('volume')}') for {normalized['action']} msg {normalized['original_message_id']}: {e}. Setting volume to 0.")
                 normalized['volume'] = 0.0

        # --- Generate Internal ID ---
        normalized['internal_id'] = f"{parsed_data.get('source_id', 'unknown')}-{normalized['original_message_id']}"
        # Add source/channel info for logging/reference
        normalized['source_info'] = f"Source:{parsed_data.get('source_id','N/A')}|Chan:{parsed_data.get('channel_info','N/A')}"

        logger.info(f"Normalization successful for internal ID {normalized['internal_id']}")
        logger.debug(f"Normalized data dict: {normalized}")
        return normalized

    except Exception as e:
        # Catch any unexpected errors during normalization
        logger.error(f"Unexpected error during normalization for msg {parsed_data.get('message_id', 'N/A')}: {e}", exc_info=True)
        return None

```

---

**7. `signal_processor.py`** (Requires adding `source_parser_map` argument)

```python
# signal_processor.py (SignalAggregatorV3 directory)
import logging
import time
import threading
# Use standard Queue if mixing threads and async or if simpler
from queue import Queue, Empty
# from asyncio import Queue, TimeoutError # Use if fully async with connectors

from normalizer import normalize_signal

logger = logging.getLogger("SignalProcessor")

class SignalProcessor:
    # Added source_parser_map argument
    def __init__(self, message_queue: Queue, parsers: dict, source_parser_map: dict,
                 latest_signal_store: dict, api_lock: threading.Lock, symbol_map: dict = None):
        self.message_queue = message_queue
        self.parsers = parsers # Dict of {parser_id: parser_instance}
        self.source_parser_map = source_parser_map # Dict {source_id: parser_id}
        self.latest_signal_store = latest_signal_store # Shared dict reference
        self.api_lock = api_lock # Shared lock reference
        self.symbol_map = symbol_map if symbol_map else {}
        self._stop_event = threading.Event()
        # Track processed message IDs to potentially avoid reprocessing duplicates if queue refills
        self.processed_ids = set() # Simple set for this run instance

    def run(self):
        """The main loop executed in a separate thread."""
        logger.info("Signal Processor thread starting.")
        while not self._stop_event.is_set():
            try:
                # Get raw message from queue (standard Queue version)
                raw_message = self.message_queue.get(block=True, timeout=1.0) # Wait up to 1s

                # --- Basic Duplicate Check ---
                # Check if this specific message from this source was already processed
                # Simple check based on memory set, does not persist across restarts
                message_unique_key = f"{raw_message.source_id}-{raw_message.original_id}"
                if message_unique_key in self.processed_ids:
                     logger.debug(f"Skipping already processed message: {message_unique_key}")
                     self.message_queue.task_done()
                     continue

                # --- Find the Correct Parser using the map ---
                parser_id = self.source_parser_map.get(raw_message.source_id) # Dynamic lookup

                if not parser_id or parser_id not in self.parsers:
                    logger.warning(f"No valid parser found for source '{raw_message.source_id}'. Configured Map: {self.source_parser_map}. Skipping msg {raw_message.original_id}.")
                    self.processed_ids.add(message_unique_key) # Mark as processed even if skipped
                    self.message_queue.task_done()
                    continue

                parser = self.parsers[parser_id]
                logger.debug(f"Processing msg {raw_message.original_id} from {raw_message.source_id} using parser {parser_id}")

                # --- Parse ---
                parsed_data = parser.parse(raw_message)
                if not parsed_data:
                    logger.debug(f"Msg {raw_message.original_id} not parsed by {parser_id}.")
                    self.processed_ids.add(message_unique_key)
                    self.message_queue.task_done()
                    continue

                # --- Normalize ---
                normalized_data = normalize_signal(parsed_data, self.symbol_map)
                if not normalized_data:
                    logger.warning(f"Normalization failed for msg {raw_message.original_id}.")
                    self.processed_ids.add(message_unique_key)
                    self.message_queue.task_done()
                    continue

                # --- Store Latest Signal (Thread Safe) ---
                with self.api_lock:
                    # Store the complete normalized data dictionary
                    self.latest_signal_store.clear()
                    self.latest_signal_store.update(normalized_data)
                    logger.info(f"Updated latest signal store with ID {normalized_data['internal_id']} (Orig:{normalized_data['original_message_id']})")
                    logger.debug(f"Stored data snapshot: { {k:v for k,v in normalized_data.items() if k != 'timestamp_dt'} }") # Log without datetime obj

                # Mark as processed and complete queue task
                self.processed_ids.add(message_unique_key)
                self.message_queue.task_done()

            except Empty:
                # Queue was empty during timeout, totally normal
                continue
            except Exception as e:
                logger.error(f"Critical Error in signal processor loop: {e}", exc_info=True)
                # Avoid potential tight loop on errors
                time.sleep(1.0)

        logger.info("Signal Processor thread stopped.")

    def stop(self):
        """Signals the processor loop to stop."""
        logger.info("Stopping Signal Processor thread...")
        self._stop_event.set()

```

---

**8. `api_server.py`** (Now expects 9th field for `original_open_msg_id`)

```python
# api_server.py (SignalAggregatorV3 directory)
import logging
import threading
from flask import Flask, Response # Import Response for correct mimetype

logger = logging.getLogger("APIServer")

# Global references needed inside the endpoint function
# Set by the run_api_server function at startup
flask_app = Flask(__name__)
shared_latest_signal = {}
shared_api_lock = None

@flask_app.route('/get_signal', methods=['GET'])
def get_signal_endpoint():
    """Endpoint for MQL5 EA to fetch the latest normalized signal as a delimited string."""
    global shared_latest_signal, shared_api_lock

    signal_to_format = None
    output_string = "" # Default to empty string for "no signal"

    if shared_api_lock is None:
        logger.error("API Lock not initialized!")
        return "ERROR: Server configuration invalid", 500 # Internal Server Error

    # --- Access Shared Data Safely ---
    with shared_api_lock:
        # Check if the dictionary is populated and has essential keys
        if shared_latest_signal and shared_latest_signal.get('original_message_id'):
             signal_to_format = shared_latest_signal.copy()

    # --- Format Data if available ---
    if signal_to_format:
        try:
            # --- Format the 9-part pipe-delimited string ---
            # Uses the NORMALIZED and VALIDATED data from the store
            # Order: msg_id | timestamp | action | symbol | open_price | stop_loss | take_profit | volume | original_open_msg_id

            # Use original message ID for MQL5's duplicate check consistency
            message_id = signal_to_format.get('original_message_id', 0)
            timestamp_unix = signal_to_format.get('timestamp_unix', 0)
            action = signal_to_format.get('action', '')
            symbol = signal_to_format.get('symbol', '')
            open_price = signal_to_format.get('open_price', 0.0)
            stop_loss = signal_to_format.get('stop_loss', 0.0)
            take_profit = signal_to_format.get('take_profit', 0.0)
            volume = signal_to_format.get('volume', 0.0)
            # This field is only > 0 for CLOSE signals processed correctly by parser/normalizer
            original_open_msg_id = signal_to_format.get('original_open_msg_id', 0)

            # Use fixed precision formatting
            output_string = (
                f"{message_id}|{timestamp_unix}|{action}|{symbol}|"
                f"{open_price:.5f}|{stop_loss:.5f}|{take_profit:.5f}|{volume:.2f}|"
                f"{original_open_msg_id}" # This is an integer ID
            )

            logger.info(f"API Serving Formatted String: {output_string}")

        except Exception as e:
             # Log formatting errors, but return empty string to MQL5
             logger.error(f"Error formatting signal string for API: {signal_to_format} - Error: {e}", exc_info=True)
             output_string = "" # Send empty on error formatting

    else:
        logger.info("API Serving: No valid signal data to format.")
        # output_string remains ""

    # Return plain text response
    return Response(output_string, mimetype='text/plain')


def run_api_server(latest_signal_ref: dict, lock_ref: threading.Lock, host: str, port: int):
    """Runs the Flask server, passing references to shared data."""
    global shared_latest_signal, shared_api_lock
    if not isinstance(latest_signal_ref, dict) or not isinstance(lock_ref, threading.Lock):
         logger.critical("Invalid shared data/lock reference passed to API server. Aborting.")
         return

    shared_latest_signal = latest_signal_ref
    shared_api_lock = lock_ref

    logger.info(f"Attempting to start Flask API server on http://{host}:{port}")
    try:
        # For production, use a proper WSGI server like Waitress or Gunicorn
        # from waitress import serve
        # serve(flask_app, host=host, port=port)
        # For development:
        flask_app.run(host=host, port=port, threaded=True, use_reloader=False, debug=False)
        logger.info(f"Flask API server on http://{host}:{port} has stopped.")

    except OSError as e:
         logger.critical(f"Flask API server failed to start. Port {port} likely in use or permission issue: {e}")
    except Exception as e:
         logger.critical(f"Flask API server failed to start or crashed: {e}", exc_info=True)

```

---

Remember you also need the main `main.py` file (updated to pass the `source_parser_map` to `SignalProcessor`) and the `config.yaml` file properly configured. This should give you the complete set of Python files for the V3 aggregator framework.