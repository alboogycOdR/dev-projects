exactly[start - built in telegramtrades]
Okay, let's start laying the foundation for the V3 Python Aggregator. We'll begin by setting up the core structure, including the configuration loading, the base classes for connectors and parsers, and the main orchestration logic. We'll initially integrate our existing Telethon logic as the first connector/parser example.

**Phase 1: Project Structure and Core Classes**

1.  **Create Project Directory:**
    *   Create a new main directory for V3, e.g., `SignalAggregatorV3`.
    *   Inside it, create subdirectories: `connectors`, `parsers`, `utils`.

2.  **Configuration File (`config.yaml`):**
    *   We'll switch to YAML for configuration as it's generally more readable for nested structures than INI.
    *   Install the library: `pip install PyYAML`
    *   Create `config.yaml` in the main `SignalAggregatorV3` directory:

    ```yaml
    # config.yaml
    logging:
      level: INFO # DEBUG, INFO, WARNING, ERROR
      format: '%(asctime)s - %(name)s - %(levelname)s - %(message)s'

    api_endpoint:
      host: "127.0.0.1"
      port: 5000

    sources:
      # --- Source Example 1: Telegram User Account ---
      telegram_fxscalping: # Unique ID for this source
        enabled: true
        type: telegram_user
        session_name: "mt5_signal_session" # Keep existing session file if desired
        credentials:
          api_id: YOUR_API_ID_HERE      # Replace with actual value
          api_hash: YOUR_API_HASH_HERE # Replace with actual value
          phone: YOUR_PHONE_NUMBER_HERE # Replace with actual value
        targets: # Channels/Users to monitor
          - "fx_scalping"
          # - "another_telegram_channel_username"
        parser: telegram_format_1 # Name matching a parser config below

      # --- Source Example 2: Another Potential Source (Future) ---
      # discord_coolsignals:
      #   enabled: false
      #   type: discord_bot
      #   credentials:
      #     token: YOUR_DISCORD_BOT_TOKEN
      #   targets:
      #     - server_id: 1234567890
      #       channel_id: 9876543210
      #   parser: discord_format_x

    parsers:
      telegram_format_1: # Matches the parser name used in sources
        type: TelegramFormat1Parser # Python class name to use
        # Add any specific settings needed for this parser later if needed
        # e.g., specific regex patterns could be stored here

    # --- Add other top-level sections if needed (e.g., symbol_mapping) ---
    # symbol_mapping:
    #   GOLD: XAUUSD
    #   USDCADm: USDCAD
    ```
    *   **Remember to replace placeholders** with your actual Telegram API credentials.

3.  **Utilities (`utils/config_loader.py`):**
    ```python
    # utils/config_loader.py
    import yaml
    import logging
    import os

    def load_config(config_path='config.yaml'):
        """Loads configuration from a YAML file."""
        try:
            # Ensure path is absolute or relative to current script
            if not os.path.isabs(config_path):
                script_dir = os.path.dirname(os.path.dirname(__file__)) # Get parent dir (SignalAggregatorV3)
                config_path = os.path.join(script_dir, config_path)

            with open(config_path, 'r') as f:
                config = yaml.safe_load(f)
                logging.info(f"Configuration loaded successfully from {config_path}")
                return config
        except FileNotFoundError:
            logging.error(f"Configuration file not found at {config_path}")
            return None
        except yaml.YAMLError as e:
            logging.error(f"Error parsing configuration file {config_path}: {e}")
            return None
        except Exception as e:
            logging.error(f"An unexpected error occurred loading config: {e}")
            return None

    def setup_logging(config):
        """Configures logging based on the loaded config."""
        log_config = config.get('logging', {})
        level = getattr(logging, log_config.get('level', 'INFO').upper(), logging.INFO)
        log_format = log_config.get('format', '%(asctime)s - %(name)s - %(levelname)s - %(message)s')
        logging.basicConfig(level=level, format=log_format)
        # Optionally configure file logging here too
    ```

4.  **Base Classes (`connectors/base_connector.py`, `parsers/base_parser.py`):**
    ```python
    # connectors/base_connector.py
    from abc import ABC, abstractmethod
    import asyncio

    class BaseConnector(ABC):
        """Abstract base class for all signal source connectors."""
        def __init__(self, source_id, config, message_queue):
            self.source_id = source_id
            self.config = config # Specific config section for this source
            self.message_queue = message_queue # Async queue to pass raw messages
            self.logger = logging.getLogger(f"Connector.{self.source_id}")

        @abstractmethod
        async def connect(self):
            """Establishes connection to the source."""
            pass

        @abstractmethod
        async def start_listening(self):
            """Starts listening for or fetching new messages."""
            pass

        @abstractmethod
        async def stop(self):
            """Stops listening and disconnects."""
            pass

    # --- Add later: Define a standard RawMessage format ---
    # from dataclasses import dataclass, field
    # from datetime import datetime
    # @dataclass
    # class RawMessage:
    #    source_id: str
    #    original_id: str # Platform-specific message ID
    #    timestamp: datetime
    #    text: str
    #    metadata: dict = field(default_factory=dict) # e.g., channel name, author
    ```

    ```python
    # parsers/base_parser.py
    from abc import ABC, abstractmethod
    import logging

    class BaseParser(ABC):
        """Abstract base class for all signal format parsers."""
        def __init__(self, parser_id, config):
            self.parser_id = parser_id
            self.config = config # Specific config section for this parser
            self.logger = logging.getLogger(f"Parser.{self.parser_id}")

        @abstractmethod
        def parse(self, raw_message):
            """
            Parses a raw message object.
            Returns a dictionary with extracted signal data (non-normalized)
            or None if parsing fails or message doesn't match format.
            """
            pass
    ```

5.  **Core Application Structure (`main.py`):**
    ```python
    # main.py (SignalAggregatorV3 directory)
    import asyncio
    import logging
    import signal # For graceful shutdown
    import threading
    from queue import Queue # Use standard Queue for thread communication initially
                           # Or use asyncio.Queue if all components are async

    from utils.config_loader import load_config, setup_logging
    from connectors.telegram_connector import TelegramUserConnector # We'll create this next
    # Import other connectors later: from connectors.discord_connector import DiscordConnector
    from parsers.telegram_parser import TelegramFormat1Parser # We'll create this next
    # Import other parsers later: from parsers.discord_parser import DiscordFormatXParser
    from normalizer import normalize_signal # We'll create this
    from signal_processor import SignalProcessor # Handles storing latest signal & formatting for API
    from api_server import run_api_server # We'll create this

    # --- Global Queue & Lock ---
    # Using standard Queue for now, simpler if some connectors aren't pure asyncio
    raw_message_queue = Queue()
    # If everything becomes pure async: raw_message_queue = asyncio.Queue()

    # Keep the simple global variable + lock for the latest processed signal for the API
    latest_signal_for_api = {}
    api_data_lock = threading.Lock() # Flask runs in a thread

    async def main():
        # 1. Load Configuration
        config = load_config()
        if not config:
            return # Stop if config failed to load
        setup_logging(config)
        logger = logging.getLogger("MainApp")

        # 2. Initialize Components based on Config
        connectors = []
        source_configs = config.get('sources', {})
        parser_configs = config.get('parsers', {})
        active_parsers = {} # Dictionary to hold instantiated parsers {parser_id: parser_instance}

        # Instantiate parsers first
        for parser_id, p_config in parser_configs.items():
            parser_type_str = p_config.get('type')
            try:
                 # TODO: Add logic to dynamically import/get parser class based on string
                 if parser_type_str == "TelegramFormat1Parser":
                     active_parsers[parser_id] = TelegramFormat1Parser(parser_id, p_config)
                     logger.info(f"Instantiated Parser: {parser_id} ({parser_type_str})")
                 # Add elif for other parser types later...
                 else:
                     logger.warning(f"Unknown or unimplemented parser type '{parser_type_str}' for id '{parser_id}'")
            except Exception as e:
                logger.error(f"Failed to instantiate parser '{parser_id}': {e}", exc_info=True)

        # Instantiate and start connectors
        connector_tasks = []
        for source_id, s_config in source_configs.items():
            if not s_config.get('enabled', False):
                logger.info(f"Source '{source_id}' is disabled in config. Skipping.")
                continue

            source_type = s_config.get('type')
            parser_id = s_config.get('parser')

            if not parser_id or parser_id not in active_parsers:
                logger.error(f"Parser '{parser_id}' not found or configured for source '{source_id}'. Skipping source.")
                continue

            try:
                 connector = None
                 # TODO: Dynamic connector instantiation based on source_type
                 if source_type == "telegram_user":
                     # Pass the standard Queue for now
                     connector = TelegramUserConnector(source_id, s_config, raw_message_queue)
                     logger.info(f"Instantiated Connector: {source_id} ({source_type})")
                     connectors.append(connector)
                     # Start the connector's listening task
                     # Need to adjust this depending on how connectors run (async/thread)
                     # await connector.connect() # Moved connect inside start_listening usually
                     connector_tasks.append(asyncio.create_task(connector.start_listening(), name=f"Connector_{source_id}"))

                 # Add elif for other connector types later...
                 else:
                     logger.warning(f"Unknown or unimplemented connector type '{source_type}' for source '{source_id}'.")

            except Exception as e:
                 logger.error(f"Failed to instantiate or start connector '{source_id}': {e}", exc_info=True)


        # 3. Initialize Signal Processor (Processes queue -> Normalizer -> Updates latest_signal_for_api)
        # Runs in its own thread as it processes from a blocking queue
        signal_processor = SignalProcessor(
            message_queue=raw_message_queue,
            parsers=active_parsers, # Give it access to all parser instances
            latest_signal_store=latest_signal_for_api,
            api_lock=api_data_lock,
            # Pass normalization maps if defined in config
            symbol_map=config.get('symbol_mapping', {})
        )
        processor_thread = threading.Thread(target=signal_processor.run, daemon=True, name="SignalProcessor")
        processor_thread.start()
        logger.info("Started Signal Processor Thread")

        # 4. Start Flask API Server (in its own thread)
        api_config = config.get('api_endpoint', {})
        api_thread = threading.Thread(
            target=run_api_server,
            args=(latest_signal_for_api, api_data_lock, api_config.get('host'), api_config.get('port')),
            daemon=True,
            name="APIServer"
        )
        api_thread.start()
        logger.info(f"Started API Server Thread on http://{api_config.get('host')}:{api_config.get('port')}")

        # 5. Run connector tasks until stopped
        if connector_tasks:
            logger.info(f"Running {len(connector_tasks)} connector task(s)...")
            # Keep main async loop running, handle shutdown signals
            stop_event = asyncio.Event()
            setup_signal_handlers(stop_event, asyncio.get_running_loop())

            # Wait for shutdown signal OR for tasks to finish (error?)
            finished, pending = await asyncio.wait(
                 connector_tasks + [stop_event.wait()], # Wait for stop or any connector task to finish
                 return_when=asyncio.FIRST_COMPLETED
            )

            if stop_event.is_set():
                 logger.info("Shutdown signal received.")
            else:
                 logger.warning("A connector task finished unexpectedly. Checking results...")
                 for task in finished:
                      if task not in connector_tasks: continue # Skip the stop_event task result check
                      try:
                          task.result() # Check for exceptions if task finished early
                      except Exception as e:
                           logger.error(f"Connector task {task.get_name()} exited with error: {e}", exc_info=True)

        else:
             logger.warning("No active connector tasks were started. Waiting for shutdown signal.")
             stop_event = asyncio.Event()
             setup_signal_handlers(stop_event, asyncio.get_running_loop())
             await stop_event.wait()


        # 6. Initiate Graceful Shutdown
        logger.info("Initiating shutdown...")
        # Stop processor thread (via setting a flag - implement in SignalProcessor.run)
        signal_processor.stop()
        # Stop connectors
        for connector in connectors:
             try:
                 await connector.stop()
             except Exception as e:
                 logger.error(f"Error stopping connector {connector.source_id}: {e}", exc_info=True)
        # Cancel any remaining pending asyncio tasks
        for task in pending:
            task.cancel()
        if pending:
            await asyncio.wait(pending) # Allow cancellations to process

        processor_thread.join(timeout=5) # Wait for processor thread
        # API server thread is daemon, should exit automatically

        logger.info("Shutdown complete.")


    def setup_signal_handlers(stop_event, loop):
        """Sets up signal handlers for graceful shutdown."""
        for sig in (signal.SIGINT, signal.SIGTERM):
            loop.add_signal_handler(sig, stop_event.set)

    if __name__ == "__main__":
        try:
            asyncio.run(main())
        except KeyboardInterrupt:
            logging.info("Main loop interrupted by Ctrl+C.")
        except Exception as e:
            logging.critical(f"Critical unhandled exception in main: {e}", exc_info=True)

    ```

**Next Steps (Implementation):**

1.  **Implement `connectors/telegram_connector.py`:** Adapt our previous Telethon code into the `TelegramUserConnector` class structure, making it use the passed `config` and putting received messages onto the `message_queue`.
2.  **Implement `parsers/telegram_parser.py`:** Create the `TelegramFormat1Parser` class. Move the Regex/logic needed to parse *your specific Telegram signal format* into its `parse` method. It should take a `RawMessage` object (we need to define that properly, perhaps using `dataclasses`) and return the extracted dictionary.
3.  **Implement `normalizer.py`:** Create the `normalize_signal` function or class. Implement symbol mapping (based on config) and other standardizations.
4.  **Implement `signal_processor.py`:** Create the `SignalProcessor` class. Its `run` loop continuously gets messages from `raw_message_queue`, calls the appropriate parser, then the normalizer, handles deduplication/validation, and finally updates the `latest_signal_for_api` dictionary using the `api_data_lock`. Include a `stop()` method.
5.  **Implement `api_server.py`:** Create the `run_api_server` function. Move the Flask app definition and the `/get_signal` endpoint logic (which now reads from `latest_signal_for_api` and formats the delimited string) into this file.

This is a significant structural setup. Let's tackle implementing `TelegramUserConnector` and `TelegramFormat1Parser` first, reusing our previous code within this new framework. Would you like to proceed with that?

[end - built in telegramtrades already]


Okay, let's implement the first concrete parts of the V3 system: `TelegramUserConnector` and the definition of the `RawMessage` it will produce.

**1. Define `RawMessage` Data Structure**

It's useful to have a standard way to represent raw messages coming from any connector. We can use Python's `dataclasses`. Create a new file `utils/message_models.py`:

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
    timestamp: datetime     # Timestamp of the message (preferably UTC)
    text: str               # The raw text content of the message
    channel_info: str       # Info about the channel/chat it came from (e.g., username, ID)
    author_info: str = ""   # Info about the author (if available/relevant)
    metadata: dict = field(default_factory=dict) # Any other source-specific details
```

**2. Implement `TelegramUserConnector`**

Create the file `connectors/telegram_connector.py`. This adapts our previous Telethon code into the class structure.

```python
# connectors/telegram_connector.py
import logging
import asyncio
from queue import Queue # Import standard Queue
from datetime import timezone

from telethon import TelegramClient, events, errors

from .base_connector import BaseConnector
from utils.message_models import RawMessage # Import our standard message format

class TelegramUserConnector(BaseConnector):
    """Connects to Telegram as a user account using Telethon."""

    def __init__(self, source_id, config, message_queue: Queue):
        super().__init__(source_id, config, message_queue)
        self.client = None
        self.session_name = config.get('session_name', source_id) # Use source_id as default session name
        self.credentials = config.get('credentials', {})
        self.targets = config.get('targets', []) # List of channel usernames/IDs

        if not all(k in self.credentials for k in ['api_id', 'api_hash', 'phone']):
            raise ValueError(f"Missing 'api_id', 'api_hash', or 'phone' in credentials for source {source_id}")

    async def connect(self):
        """Initializes and connects the Telethon client."""
        try:
            self.logger.info(f"Initializing Telethon client with session '{self.session_name}'...")
            self.client = TelegramClient(
                self.session_name,
                int(self.credentials['api_id']),
                self.credentials['api_hash']
            )
            self.logger.info("Connecting to Telegram...")
            await self.client.connect()
            self.logger.info("Connection attempt finished.")

            if not await self.client.is_user_authorized():
                self.logger.info("Authorization required.")
                await self.client.send_code_request(self.credentials['phone'])
                # Note: Getting code input needs main thread interaction or a different approach
                # In a real app, might need a separate mechanism or prompt during initial setup
                try:
                    code = input(f"Enter the Telegram code sent to {self.credentials['phone']}: ")
                    await self.client.sign_in(self.credentials['phone'], code)
                    self.logger.info("Signed in successfully!")
                except errors.SessionPasswordNeededError:
                     # Handle 2FA - requires password input
                     # Similar input challenge as the code
                     try:
                        pwd = input("Two-factor authentication password needed: ")
                        await self.client.sign_in(password=pwd)
                        self.logger.info("Signed in successfully with 2FA!")
                     except Exception as e:
                        self.logger.error(f"Failed 2FA sign in: {e}")
                        await self.client.disconnect()
                        self.client = None # Ensure client is None on failure
                        return False
                except Exception as e:
                    self.logger.error(f"Failed to sign in: {e}")
                    await self.client.disconnect()
                    self.client = None
                    return False
            else:
                self.logger.info("Already authorized.")
            return True # Return connection status

        except Exception as e:
            self.logger.error(f"Failed to connect or authorize: {e}", exc_info=True)
            if self.client and self.client.is_connected():
                 await self.client.disconnect()
            self.client = None
            return False

    def _register_message_handler(self):
        """Internal method to register the event handler."""
        if not self.client:
            self.logger.error("Cannot register handler, client not initialized.")
            return

        # Get entity objects for targets to handle different types (username vs ID)
        # Note: Getting entities might be better done once after connection setup
        # For simplicity now, we let Telethon handle resolution within the decorator if possible
        resolved_targets = []
        for target in self.targets:
             # Could potentially pre-resolve IDs here if needed
             resolved_targets.append(target) # Use raw targets initially

        @self.client.on(events.NewMessage(chats=resolved_targets))
        async def handle_new_message(event):
            try:
                message = event.message
                chat = await event.get_chat() # Get chat entity to extract info

                # Prefer chat username if available, else use ID
                channel_info = getattr(chat, 'username', None)
                if not channel_info:
                     channel_info = str(getattr(chat, 'id', 'UnknownChannel'))
                else: # Prepend @ for usernames for clarity
                     channel_info = f"@{channel_info}"

                author_info = "" # TODO: Get author info if needed (might require more permissions/config)

                self.logger.info(f"Received message ID {message.id} from {channel_info} (Source: {self.source_id})")
                self.logger.debug(f"Raw Text: {message.text}")

                # Create the standardized RawMessage object
                raw_msg = RawMessage(
                    source_id=self.source_id,
                    connector_type='telegram_user',
                    original_id=str(message.id), # Ensure ID is string
                    timestamp=message.date.replace(tzinfo=timezone.utc), # Ensure timezone-aware (UTC)
                    text=message.text if message.text else "", # Handle potential None text
                    channel_info=channel_info,
                    author_info=author_info
                    # Add other metadata if needed, e.g., message.is_reply etc.
                    # metadata = {'is_reply': message.is_reply, 'reply_to_msg_id': message.reply_to_msg_id}
                )

                # Put the raw message onto the central queue
                # Use put_nowait as queue size is currently unbounded in this basic setup
                # If using asyncio.Queue, use await self.message_queue.put(raw_msg)
                self.message_queue.put(raw_msg)

            except Exception as e:
                self.logger.error(f"Error processing incoming message event: {e}", exc_info=True)

        self.logger.info(f"Registered message handler for targets: {resolved_targets}")


    async def start_listening(self):
        """Connects (if needed) and starts the Telethon client's event loop."""
        if not self.client or not self.client.is_connected():
             self.logger.info("Client not connected, attempting connection...")
             if not await self.connect():
                 self.logger.error("Connection failed, cannot start listening.")
                 return # Stop if connection failed

        if not self.client:
             self.logger.error("Client is None, cannot start listening.")
             return

        self._register_message_handler()

        self.logger.info("Starting Telethon client's event loop (run_until_disconnected)...")
        # This call blocks until the client disconnects or is stopped
        try:
             await self.client.run_until_disconnected()
        except Exception as e:
             self.logger.error(f"Telethon client run_until_disconnected error: {e}", exc_info=True)
        finally:
             self.logger.info("Telethon client has stopped.")


    async def stop(self):
        """Disconnects the Telethon client."""
        self.logger.info("Stopping connector...")
        if self.client and self.client.is_connected():
            self.logger.info("Disconnecting Telethon client...")
            await self.client.disconnect()
            self.logger.info("Telethon client disconnected.")
        self.client = None # Clear client reference

```

**Key Points & Changes:**

*   **Inheritance:** Inherits from `BaseConnector`.
*   **Initialization:** Takes `source_id`, the specific `config` section for this source, and the shared `message_queue` (standard `Queue` for now). It extracts necessary credentials.
*   **Connect:** Handles the `TelegramClient` initialization, connection, and the one-time authorization flow (manual code/password input is needed here during setup - a GUI or web interface would be better for production).
*   **Handler (`handle_new_message`):** This internal function (registered via `@client.on`) is triggered by Telethon.
    *   It now creates our standardized `RawMessage` object using data from the `event`.
    *   It puts this `RawMessage` onto the `self.message_queue` which is shared with the central processing logic in `main.py`.
*   **`start_listening`:** Ensures connection, registers the handler, and then calls `client.run_until_disconnected()`. This is the main blocking call that keeps the listener active.
*   **`stop`:** Handles disconnecting the client gracefully.

**Next: Implement the Parser (`TelegramFormat1Parser`)**

Now, let's create `parsers/telegram_parser.py` to handle the specific format you expect from the `fx_scalping` channel.

```python
# parsers/telegram_parser.py
import re
import logging
from datetime import datetime

from .base_parser import BaseParser
from utils.message_models import RawMessage # Type hinting

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
    SYMBOL_PATTERN = re.compile(r"Symbol:\s*#?(?P<symbol>[A-Z]+)", re.IGNORECASE) # Assumes symbol is letters only after #
    VOLUME_PATTERN = re.compile(r"Volume:\s*(?P<volume>\d+\.?\d*)", re.IGNORECASE)
    OPEN_PRICE_PATTERN = re.compile(r"Open Price:\s*(?P<open_price>\d+\.?\d*)", re.IGNORECASE)
    STOP_LOSS_PATTERN = re.compile(r"Stop-Loss:\s*(?P<stop_loss>\d+\.?\d*)", re.IGNORECASE)
    TAKE_PROFIT_PATTERN = re.compile(r"Take-Profit:\s*(?P<take_profit>\d+\.?\d*)", re.IGNORECASE)


    def parse(self, raw_message: RawMessage):
        """Parses the raw message text using Regex."""
        text = raw_message.text
        parsed_data = {}
        signal_action = None # To differentiate between OPEN and CLOSE action types

        try:
            # 1. Find Action and Direction
            action_match = self.ACTION_PATTERN.search(text)
            if action_match:
                action = action_match.group('action').upper()
                direction = action_match.group('direction').upper() # Original direction BUY/SELL
                parsed_data['action'] = action # Store primary action (OPEN/CLOSE)
                parsed_data['direction'] = direction # Store direction for reference if needed
                signal_action = action # Keep track of OPEN vs CLOSE
                self.logger.debug(f"Parser {self.parser_id}: Found Action={action}, Direction={direction}")
            else:
                self.logger.debug(f"Parser {self.parser_id}: Action pattern not found in message ID {raw_message.original_id}.")
                return None # Not a signal if action is missing

            # 2. Find Symbol
            symbol_match = self.SYMBOL_PATTERN.search(text)
            if symbol_match:
                parsed_data['symbol'] = symbol_match.group('symbol').upper()
            else:
                self.logger.warning(f"Parser {self.parser_id}: Symbol not found for signal {raw_message.original_id}.")
                return None # Require symbol

            # 3. Find Open Price (Required for OPEN and CLOSE)
            open_price_match = self.OPEN_PRICE_PATTERN.search(text)
            if open_price_match:
                parsed_data['open_price'] = float(open_price_match.group('open_price'))
            else:
                self.logger.warning(f"Parser {self.parser_id}: Open Price not found for signal {raw_message.original_id}.")
                return None # Require open price

            # --- Fields primarily for OPEN signals ---
            if signal_action == "OPEN":
                volume_match = self.VOLUME_PATTERN.search(text)
                if volume_match:
                    parsed_data['volume'] = float(volume_match.group('volume'))
                else: # Volume might be optional? Set default or return None if required
                    parsed_data['volume'] = 0.0 # Default to 0 if missing
                    self.logger.debug(f"Parser {self.parser_id}: Volume not found for OPEN signal {raw_message.original_id}, using 0.")

                sl_match = self.STOP_LOSS_PATTERN.search(text)
                if sl_match:
                    parsed_data['stop_loss'] = float(sl_match.group('stop_loss'))
                else:
                    self.logger.warning(f"Parser {self.parser_id}: Stop Loss not found for OPEN signal {raw_message.original_id}.")
                    return None # Usually require SL for OPEN

                tp_match = self.TAKE_PROFIT_PATTERN.search(text)
                if tp_match:
                    parsed_data['take_profit'] = float(tp_match.group('take_profit'))
                else:
                    self.logger.warning(f"Parser {self.parser_id}: Take Profit not found for OPEN signal {raw_message.original_id}.")
                    return None # Usually require TP for OPEN

            elif signal_action == "CLOSE":
                 # For CLOSE, we mainly needed action, symbol, open_price.
                 # We *could* try to parse original SL/TP/Vol from CLOSE msg if they exist
                 # But based on previous info, they might not be reliable or needed for the 'match by comment' logic
                 pass # No other essential fields needed *from parsing* for basic CLOSE


            # Add message ID and timestamp from the raw message object
            parsed_data['message_id'] = raw_message.original_id
            parsed_data['timestamp'] = raw_message.timestamp

            self.logger.info(f"Parser {self.parser_id}: Successfully parsed signal: {parsed_data}")
            return parsed_data # Return the dictionary of extracted (but not normalized) data

        except Exception as e:
            self.logger.error(f"Parser {self.parser_id}: Error parsing message ID {raw_message.original_id}: {e}\nRaw Text:\n{text}", exc_info=True)
            return None # Return None on any parsing error

```

**Key Points:**

*   Uses `re.compile` for efficiency (compiles regex once).
*   Uses named capture groups (`?P<name>`) for easy access to extracted data.
*   Handles `OPEN` and `CLOSE` slightly differently regarding required fields (SL/TP/Volume only strictly required for OPEN).
*   Returns a dictionary containing the extracted raw data. Symbol normalization happens later.
*   Includes logging for debugging.

**Next Steps:**

1.  Review and save these files: `utils/message_models.py`, `connectors/telegram_connector.py`, `parsers/telegram_parser.py`.
2.  Update `config.yaml` with your actual credentials.
3.  We then need to implement:
    *   `normalizer.py` (for symbol mapping etc.)
    *   `signal_processor.py` (to manage the queue and orchestrate parsing/normalization)
    *   `api_server.py` (to house the Flask endpoint)
    *   Refine `main.py` to correctly instantiate and wire these components together.

Shall we proceed with `normalizer.py` and `signal_processor.py`?

Okay, let's implement the remaining core components for the V3 Python Aggregator: the Normalizer, the Signal Processor, and the API Server, along with necessary updates to `main.py`.

**1. Implement `normalizer.py`**

This module will contain functions or a class to standardize the data received from any parser.

```python
# normalizer.py (SignalAggregatorV3 directory)
import logging
import re

logger = logging.getLogger("Normalizer")

def normalize_signal(parsed_data: dict, symbol_map: dict = None):
    """
    Normalizes parsed signal data into a standard internal format.

    Args:
        parsed_data: Dictionary output from a parser module.
                     Expected keys might vary slightly but should include:
                     'message_id', 'timestamp', 'action', 'symbol',
                     and potentially 'open_price', 'stop_loss', 'take_profit', 'volume'.
        symbol_map: Optional dictionary for mapping source symbols to standard symbols.
                    Example: {'GOLD': 'XAUUSD', 'USDCADm': 'USDCAD'}

    Returns:
        A dictionary containing the normalized signal data, or None if validation fails.
        Guaranteed keys on success:
        'internal_id', 'original_message_id', 'timestamp', 'action',
        'symbol', 'open_price', 'stop_loss', 'take_profit', 'volume',
        'source_info' (optional, can be added based on parsed_data metadata)
    """
    if not isinstance(parsed_data, dict):
        logger.warning("Invalid input to normalize_signal: not a dictionary.")
        return None

    try:
        normalized = {}

        # --- Core Fields (Expected from most parsers) ---
        normalized['original_message_id'] = str(parsed_data.get('message_id', '0'))
        normalized['timestamp'] = parsed_data.get('timestamp') # Should be datetime object

        # --- Action Normalization ---
        action = str(parsed_data.get('action', '')).upper()
        if action not in ["BUY", "SELL", "CLOSE", "OPEN"]: # OPEN may need resolving direction
            logger.warning(f"Invalid or unsupported action '{action}' in parsed data {normalized['original_message_id']}.")
            # Handle OPEN case - if parser includes 'direction' separately
            if action == "OPEN" and 'direction' in parsed_data:
                 direction = str(parsed_data.get('direction','')).upper()
                 if direction in ["BUY", "SELL"]:
                      action = direction # Promote direction to main action
                      logger.debug(f"Promoted 'OPEN' + direction '{direction}' to action '{action}'.")
                 else:
                     logger.warning(f"Action 'OPEN' found but invalid direction '{direction}'. Discarding.")
                     return None
            else: # Unresolvable or unsupported action
                return None
        normalized['action'] = action

        # --- Symbol Normalization ---
        symbol = str(parsed_data.get('symbol', '')).upper()
        if not symbol:
            logger.warning(f"Missing symbol in parsed data {normalized['original_message_id']}.")
            return None

        # Apply custom mapping if provided
        if symbol_map and symbol in symbol_map:
            original_symbol = symbol
            symbol = symbol_map[symbol]
            logger.debug(f"Mapped symbol '{original_symbol}' to '{symbol}'.")

        # Apply generic cleaning (e.g., remove non-alphanumeric, unless needed for specific broker symbols like '.m')
        # This regex might be too aggressive, adjust as needed based on target MQL5 symbol requirements
        # Example: keep A-Z, 0-9, allow '.' or '_' if brokers use them
        symbol = re.sub(r'[^A-Z0-9._-]', '', symbol) # Allow dot, underscore, dash

        if not symbol: # Check again after cleaning
            logger.warning(f"Symbol became empty after cleaning for {normalized['original_message_id']}.")
            return None
        normalized['symbol'] = symbol

        # --- Price/Volume Normalization (Convert to float, handle defaults) ---
        # Required: Open Price (needed for CLOSE matching based on original plan)
        open_price = parsed_data.get('open_price')
        if open_price is None:
            logger.warning(f"Missing 'open_price' for {normalized['original_message_id']}.")
            return None
        try:
            normalized['open_price'] = float(open_price)
            if normalized['open_price'] <= 0: raise ValueError("Price must be positive")
        except (ValueError, TypeError) as e:
            logger.warning(f"Invalid 'open_price' value '{open_price}' for {normalized['original_message_id']}: {e}")
            return None

        # Optional: SL, TP, Volume (Default to 0.0 if missing or if CLOSE action)
        if normalized['action'] == "CLOSE":
            normalized['stop_loss'] = 0.0
            normalized['take_profit'] = 0.0
            normalized['volume'] = 0.0
            # >>> Handling CLOSE message ID linking <<<
            # If using comment matching (Option 3): Need original OPEN message ID.
            # This ID must be provided by the *parser* (from parsing replies/quotes/specific text)
            # Add it to parsed_data['original_open_msg_id'] by the parser.
            original_open_msg_id = str(parsed_data.get('original_open_msg_id', '0'))
            if original_open_msg_id == '0':
                logger.warning(f"CLOSE signal {normalized['original_message_id']} did not have 'original_open_msg_id' from parser. Cannot use comment matching.")
                # Fallback? For now, fail if comment matching is the goal.
                # OR, we could pass signal's own open_price if fallback logic is used in MQL5
                # Sticking to passing '0' if no explicit ID is parsed
                normalized['original_open_msg_id'] = 0
            else:
                 normalized['original_open_msg_id'] = int(original_open_msg_id) # Convert to int for struct
                 logger.info(f"CLOSE signal refers to original OPEN message ID: {normalized['original_open_msg_id']}")


        else: # Action is BUY or SELL
            # Default original_open_msg_id to 0 for BUY/SELL
            normalized['original_open_msg_id'] = 0

            try:
                normalized['stop_loss'] = float(parsed_data.get('stop_loss', 0.0))
                if normalized['stop_loss'] <= 0:
                    logger.warning(f"Invalid 'stop_loss' (<=0) for BUY/SELL {normalized['original_message_id']}, but proceeding (check required).")
                    # Depending on strategy, maybe return None here if SL is always required
            except (ValueError, TypeError) as e:
                logger.warning(f"Invalid 'stop_loss' value '{parsed_data.get('stop_loss')}' for {normalized['original_message_id']}: {e}")
                return None # Consider SL mandatory?

            try:
                normalized['take_profit'] = float(parsed_data.get('take_profit', 0.0))
                if normalized['take_profit'] <= 0:
                     logger.warning(f"Invalid 'take_profit' (<=0) for BUY/SELL {normalized['original_message_id']}, but proceeding (check required).")
                     # Maybe return None here?
            except (ValueError, TypeError) as e:
                logger.warning(f"Invalid 'take_profit' value '{parsed_data.get('take_profit')}' for {normalized['original_message_id']}: {e}")
                return None # Consider TP mandatory?

            try:
                normalized['volume'] = float(parsed_data.get('volume', 0.0))
            except (ValueError, TypeError) as e:
                logger.warning(f"Invalid 'volume' value '{parsed_data.get('volume')}' for {normalized['original_message_id']}: {e}")
                # Default volume to 0 if parsing fails, calculation happens in MQL5 anyway
                normalized['volume'] = 0.0

        # --- Timestamps ---
        if not isinstance(normalized['timestamp'], datetime):
            logger.warning(f"Invalid timestamp type ({type(normalized['timestamp'])}) for {normalized['original_message_id']}. Attempting conversion.")
            # Add conversion logic if parsers might return strings or Unix timestamps
            return None # Require parsers to provide datetime objects for now

        # Convert timestamp to Unix timestamp (integer seconds UTC) for delimited string
        normalized['timestamp_unix'] = int(normalized['timestamp'].timestamp())


        # --- Generate Internal ID (Can be simple combination for now) ---
        # More robust unique ID generation might be needed if rates are very high
        normalized['internal_id'] = f"{parsed_data.get('source_id', 'unknown')}-{normalized['original_message_id']}"

        # Add any extra source info if available/needed
        normalized['source_info'] = f"Source:{parsed_data.get('source_id', 'N/A')}|Chan:{parsed_data.get('channel_info', 'N/A')}"


        logger.debug(f"Normalized data for {normalized['internal_id']}: {normalized}")
        return normalized

    except Exception as e:
        logger.error(f"Unexpected error during normalization: {e}", exc_info=True)
        return None

```

**2. Implement `signal_processor.py`**

This class runs in its own thread, consuming from the `raw_message_queue`.

```python
# signal_processor.py (SignalAggregatorV3 directory)
import logging
import time
import threading
from queue import Queue, Empty # Import Empty exception

from normalizer import normalize_signal

logger = logging.getLogger("SignalProcessor")

class SignalProcessor:
    def __init__(self, message_queue: Queue, parsers: dict, latest_signal_store: dict, api_lock: threading.Lock, symbol_map: dict = None):
        self.message_queue = message_queue
        self.parsers = parsers # Dict of {parser_id: parser_instance}
        self.latest_signal_store = latest_signal_store # Reference to the shared dict
        self.api_lock = api_lock # Lock for accessing the shared dict
        self.symbol_map = symbol_map if symbol_map else {}
        self._stop_event = threading.Event()
        # Track processed message IDs per source to avoid reprocessing during restarts if needed
        # self.processed_ids = {} # Example: { "source_id": {message_id1, message_id2} }

    def run(self):
        """The main loop executed in a separate thread."""
        logger.info("Signal Processor thread started.")
        while not self._stop_event.is_set():
            try:
                # Get raw message from queue, block for a short time
                raw_message = self.message_queue.get(block=True, timeout=1.0)

                # --- Find the Correct Parser ---
                # Assumes RawMessage has a source_id which maps to a parser_id via config logic in main.py
                # For now, let's assume raw_message has 'source_id' and we get parser_id from there
                # Need config access or pass parser_id mapping
                # Simplified: Get parser config name linked to source during setup?
                # TODO: Need a way to get the parser_id for the raw_message.source_id
                # For now, ASSUME our telegram source 'telegram_fxscalping' uses 'telegram_format_1' parser
                # This needs proper mapping via config passed down/looked up here.
                parser_id_for_source = None
                if raw_message.source_id == 'telegram_fxscalping':
                    parser_id_for_source = 'telegram_format_1' # Hardcoded lookup - FIX THIS

                if not parser_id_for_source or parser_id_for_source not in self.parsers:
                    logger.warning(f"No valid parser configured/found for source '{raw_message.source_id}'. Skipping msg {raw_message.original_id}.")
                    self.message_queue.task_done() # Mark task as done even if skipped
                    continue

                parser = self.parsers[parser_id_for_source]

                # --- Parse ---
                logger.debug(f"Processing msg {raw_message.original_id} from {raw_message.source_id} using parser {parser_id_for_source}")
                parsed_data = parser.parse(raw_message)
                if not parsed_data:
                    # Parsing failed or msg didn't match format
                    logger.debug(f"Msg {raw_message.original_id} not parsed by {parser_id_for_source}.")
                    self.message_queue.task_done()
                    continue

                # --- Normalize ---
                # Pass source_id into parsed_data if parser doesn't add it
                parsed_data['source_id'] = raw_message.source_id
                parsed_data['channel_info'] = raw_message.channel_info
                # Pass timestamp explicitly if parser didn't return datetime
                if 'timestamp' not in parsed_data: parsed_data['timestamp'] = raw_message.timestamp

                normalized_data = normalize_signal(parsed_data, self.symbol_map)
                if not normalized_data:
                    logger.warning(f"Normalization failed for msg {raw_message.original_id}.")
                    self.message_queue.task_done()
                    continue

                # --- Store Latest Signal (Thread Safe) ---
                # Store based on unique ID (e.g., source-original_id) or use timestamp?
                # For now, simply overwrite the single 'latest' entry
                with self.api_lock:
                    self.latest_signal_store.clear() # Remove old signal
                    self.latest_signal_store.update(normalized_data) # Add new signal
                    logger.info(f"Updated latest signal store with signal from {normalized_data['internal_id']}")
                    logger.debug(f"Stored data: {self.latest_signal_store}")

                # Mark task as complete for the queue
                self.message_queue.task_done()

            except Empty:
                # Queue was empty, loop continues waiting
                continue
            except Exception as e:
                logger.error(f"Error in signal processor loop: {e}", exc_info=True)
                # Avoid tight loop on unexpected errors
                time.sleep(0.5)

        logger.info("Signal Processor thread finished.")

    def stop(self):
        """Signals the processor loop to stop."""
        logger.info("Stopping Signal Processor thread...")
        self._stop_event.set()

```

**3. Implement `api_server.py`**

This houses the Flask logic, now simplified.

```python
# api_server.py (SignalAggregatorV3 directory)
import logging
import threading
from flask import Flask

logger = logging.getLogger("APIServer")

# Define Flask app globally or pass it if needed
flask_app = Flask(__name__)

# Global references needed inside the endpoint function
# These will be set by the run_api_server function
shared_latest_signal = {}
shared_api_lock = None

@flask_app.route('/get_signal', methods=['GET'])
def get_signal_endpoint():
    """Endpoint for MQL5 EA to fetch the latest signal as a delimited string."""
    global shared_latest_signal, shared_api_lock

    signal_to_format = None
    if shared_api_lock is None:
        logger.error("API Lock not initialized!")
        return "ERROR: Server configuration invalid", 500 # Internal Server Error

    # --- Access Shared Data Safely ---
    with shared_api_lock:
        if shared_latest_signal and shared_latest_signal.get('internal_id'): # Check basic validity
             signal_to_format = shared_latest_signal.copy()

    # --- Format Data ---
    if signal_to_format:
        try:
            # Format the pipe-delimited string using NORMALIZED data
            # Field order: message_id|timestamp_unix|action|symbol|open_price|stop_loss|take_profit|volume|original_open_msg_id
            # Note: original_open_msg_id is non-zero ONLY for CLOSE signals meant for comment matching.
            # IMPORTANT: The message_id sent here should be the one MQL5 uses to check for duplicates.
            #            Using the original message ID from the source platform is probably best here.

            signal_string = (
                f"{signal_to_format.get('original_message_id', 0)}|" # Original Msg ID for MQL5 duplicate check
                f"{signal_to_format.get('timestamp_unix', 0)}|"
                f"{signal_to_format.get('action', '')}|"
                f"{signal_to_format.get('symbol', '')}|"
                f"{signal_to_format.get('open_price', 0.0):.5f}|"
                f"{signal_to_format.get('stop_loss', 0.0):.5f}|"
                f"{signal_to_format.get('take_profit', 0.0):.5f}|"
                f"{signal_to_format.get('volume', 0.0):.2f}|"
                f"{signal_to_format.get('original_open_msg_id', 0)}" # Added 9th field for CLOSE logic V3
            )

            logger.info(f"API Serving Signal String: {signal_string}")
            return signal_string

        except Exception as e:
             logger.error(f"Error formatting signal string for API: {signal_to_format} - Error: {e}", exc_info=True)
             return "ERROR: Failed to format signal", 500
    else:
        logger.info("API Serving: No valid signal data available.")
        return "" # Return empty string if no valid signal is stored


def run_api_server(latest_signal_ref: dict, lock_ref: threading.Lock, host: str, port: int):
    """Runs the Flask server, passing references to shared data."""
    global shared_latest_signal, shared_api_lock
    shared_latest_signal = latest_signal_ref
    shared_api_lock = lock_ref

    logger.info(f"Starting Flask API server on http://{host}:{port}")
    try:
        # Use waitress or another production-ready WSGI server in a real deployment
        # For development:
        flask_app.run(host=host, port=port, threaded=True, use_reloader=False, debug=False)
    except Exception as e:
         logger.critical(f"Flask API server failed to start or crashed: {e}", exc_info=True)

```

**4. Updates to `main.py` (Ensure linkages are correct):**

Review the `main.py` code from the previous step. Ensure:
*   It imports `normalize_signal` (though `SignalProcessor` uses it internally).
*   It imports and correctly instantiates `SignalProcessor`, passing `raw_message_queue`, the `active_parsers` dict, `latest_signal_for_api` dict, `api_data_lock`, and `symbol_map` from config.
*   It imports and correctly calls `run_api_server` in its thread, passing `latest_signal_for_api`, `api_data_lock`, and host/port from config.
*   The `SignalProcessor` needs the mapping logic from source ID to parser ID (currently hardcoded placeholder - FIX THIS by passing a map created during setup).

```python
# --- Snippet inside main() in main.py ---

        # Create mapping from source_id to parser_id
        source_parser_map = {
             source_id: s_config.get('parser')
             for source_id, s_config in source_configs.items()
             if s_config.get('enabled', False) and s_config.get('parser') in active_parsers
        }


        # 3. Initialize Signal Processor
        signal_processor = SignalProcessor(
            message_queue=raw_message_queue,
            parsers=active_parsers,
            latest_signal_store=latest_signal_for_api,
            api_lock=api_data_lock,
            symbol_map=config.get('symbol_mapping', {}),
            # Pass the source -> parser map (or integrate lookup logic into Processor)
            source_parser_map=source_parser_map # Need to add this argument to SignalProcessor.__init__
        )
        processor_thread = threading.Thread(target=signal_processor.run, daemon=True, name="SignalProcessor")
        # ... rest of main ...
```
*   **You need to add `source_parser_map`** as an argument to `SignalProcessor.__init__` and use it inside 
its `run` loop to find the correct parser for the
 incoming `raw_message.source_id`.




**5. MQL5 EA Update (Required due to new CLOSE format):**

    *   Modify `FetchAndProcessSignal` to expect **9** parts from `StringSplit`.
    *   Store the 9th part (`original_open_msg_id`) in the `SignalData` struct when `action == "CLOSE"`.
    *   **Crucially: Implement the `HandleCloseSignal` function to use comment matching** based on `signal.original_open_msg_id`. This replaces the previous logic relying on open price or "latest".

    ```mql5
    // --- Inside MQL5 EA ---

    // Add field to SignalData struct
    struct SignalData {
    // ... other fields ...
    long original_open_msg_id; // Holds the OPEN signal's ID for comment matching
    bool is_valid;
    };

    // Update parsing in FetchAndProcessSignal
    void FetchAndProcessSignal() {
        // ... WebRequest code ...
        string signalString = CharArrayToString(result);
        string parts[];
        int expected_parts = 9; // <<< EXPECT 9 PARTS NOW
        int num_parts = StringSplit(signalString, '|', parts);
        if (num_parts != expected_parts) { /* ... error handling ... */ return; }

        SignalData signal;
        // ... initialize ...
        signal.original_open_msg_id = 0; // Initialize

        // ... parse common fields parts[0] to [3] ...
        signal.message_id = (long)StringToInteger(parts[0]); // ID of this signal msg
        signal.timestamp  = (long)StringToInteger(parts[1]);
        signal.action     = StringTrimLeft(StringTrimRight(parts[2]));
        signal.symbol     = StringTrimLeft(StringTrimRight(parts[3]));
        string upperAction = StringToUpper(signal.action);
        signal.action     = upperAction; // Store uppercase

        // --- Parse action-specific fields ---
        if (upperAction == "BUY" || upperAction == "SELL") {
        signal.open_price  = StringToDouble(parts[4]);
        signal.stop_loss   = StringToDouble(parts[5]);
        signal.take_profit = StringToDouble(parts[6]);
        signal.volume      = StringToDouble(parts[7]);
        // 9th field (parts[8]) is ignored for BUY/SELL
        } else if (upperAction == "CLOSE") {
        // Field 9 (index 8) now contains the ORIGINAL OPEN message ID
        signal.original_open_msg_id = (long)StringToInteger(parts[8]);
        // Other fields (prices, vol) are ignored for close
        } else { /* ... handle invalid action ... */ return; }

        // --- Validation ---
        // ... validate essentials, INCLUDING signal.original_open_msg_id for CLOSE action ...
        if (signal.action == "CLOSE" && signal.original_open_msg_id <= 0) {
            PrintFormat("Error parsing CLOSE signal: Missing or invalid original_open_msg_id (%d).", signal.original_open_msg_id);
            return;
        }
    // ... other validation ...

    signal.is_valid = true;
    if (signal.is_valid) { ProcessSignal(signal); }
    }


    // --- Implement comment matching in HandleCloseSignal ---
    bool HandleCloseSignal(const SignalData &signal, const string brokerSymbol) {
        if (signal.original_open_msg_id <= 0) {
            Print("Error in HandleCloseSignal: Invalid original_open_msg_id (0) received for CLOSE.");
            return false;
        }

        string expectedComment = "TG_SigID_" + (string)signal.original_open_msg_id + "_Mkt"; // MATCHES OPEN COMMENT
        PrintFormat("Attempting CLOSE for %s based on Expected Comment: '%s' (Orig. Open ID: %d)",
                    brokerSymbol, expectedComment, signal.original_open_msg_id);

        bool close_attempted = false;
        bool position_found_matching_comment = false;

        for (int i = PositionsTotal() - 1; i >= 0; i--) {
            ulong ticket = PositionGetTicket(i);
            if (ticket == 0) continue;

            // Check Magic Number and Symbol
            if (PositionGetInteger(POSITION_MAGIC) == InpMagicNumber && PositionGetString(POSITION_SYMBOL) == brokerSymbol)
            {
                string positionComment = PositionGetString(POSITION_COMMENT);

                // --- Compare Comments ---
                if (positionComment == expectedComment) {
                    position_found_matching_comment = true;
                    PrintFormat("Found matching position by Comment! Ticket: %d, Comment: '%s'. Attempting to close.", ticket, positionComment);
                    // Close the position by ticket
                    bool close_result = trade.PositionClose(ticket, InpSlippage);
                    close_attempted = true;
                    if (close_result) {
                        PrintFormat("PositionClose successful for ticket %d. Deal: %d", ticket, (int)trade.ResultDeal());
                    } else {
                        PrintFormat("PositionClose FAILED for ticket %d. Code: %d. Reason: %s", ticket, (int)trade.ResultRetcode(), trade.ResultComment());
                    }
                    // Assume one CLOSE matches one OPEN -> break after finding/attempting
                    break;
                }
            }
        }

        if (!position_found_matching_comment) {
            PrintFormat("No open position found for %s with matching comment '%s'.", brokerSymbol, expectedComment);
            // It's possible the position was already closed manually or hit SL/TP.
            // We still processed the signal.
        }

        return true; // Return true indicating signal was processed (action attempted or no match found)
    }

    ```

    This completes the core implementation loop for V3 with the specified changes. Remember to address the TODOs (like dynamic parser loading and source->parser mapping lookup in `signal_processor.py`) and add thorough error handling. This provides a much more robust and scalable structure. Test this incrementally.