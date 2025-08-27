# connectors/telegram_connector.py
import logging
import asyncio
from asyncio import Queue # Assuming async queue based on main.py change
from datetime import timezone

from telethon import TelegramClient, events, errors

# Assuming these are in the correct relative paths
from .base_connector import BaseConnector
try:
    from utils.message_models import RawMessage
except ImportError:
    from ..utils.message_models import RawMessage


class TelegramUserConnector(BaseConnector):
    """Connects to Telegram as a user account using Telethon."""

    # --- __init__ method remains the same as provided before ---
    def __init__(self, source_id: str, config: dict, message_queue: Queue):
        super().__init__(source_id, config, message_queue)
        self.client = None
        self.session_name = config.get('session_name', source_id)
        self.credentials = config.get('credentials', {})
        self.targets = config.get('targets', [])
        if not self.credentials or not all(k in self.credentials for k in ['api_id', 'api_hash', 'phone']):
             raise ValueError(f"Missing Telegram credentials for source {source_id}")

    # --- connect() method remains the same as provided before ---
    async def connect(self) -> bool:
        if self.client and self.client.is_connected():
            return True
        # ... (rest of the connection and authorization logic) ...
        try:
            self.logger.info(f"Initializing Telethon client with session '{self.session_name}'...")
            self.client = TelegramClient(
                self.session_name,
                int(self.credentials['api_id']),
                self.credentials['api_hash']
            )
            self.logger.info("Connecting to Telegram...")
            await asyncio.wait_for(self.client.connect(), timeout=30.0)
            self.logger.info("Connection attempt finished.")

            if not await self.client.is_user_authorized():
                 self.logger.warning("Authorization required. Raising error.")
                 # Handle authorization error - simpler to require pre-authorization
                 raise RuntimeError(f"Telegram authorization required for {self.credentials['phone']}.")
            else:
                 self.logger.info("Already authorized.")
            return True
        except Exception as e:
             self.logger.error(f"Failed to connect or authorize: {e}", exc_info=True)
             if self.client and self.client.is_connected():
                 await self.client.disconnect()
             self.client = None
             return False


    # --- _create_message_handler() method remains the same as provided before ---
    def _create_message_handler(self):
        # ... (logic to define the async handler function) ...
        async def handle_new_message(event):
            self.logger.critical(f"!!! handle_new_message TRIGGERED for connector {self.source_id} !!! Msg ID: {event.message.id}")
            try:
                # ... (extract message, create RawMessage) ...
                message = event.message # etc.
                if not message or not message.text: return
                # ... get channel info ...
                ts = message.date.replace(tzinfo=timezone.utc)
                raw_msg = RawMessage(
                    source_id=self.source_id,
                    connector_type='telegram_user',
                    original_id=str(message.id),
                    timestamp=ts,
                    text=message.text,
                    channel_info= "some_channel_info", # Placeholder - fetch properly
                    metadata={'is_reply': message.is_reply, 'reply_to_msg_id': str(message.reply_to_msg_id) if message.reply_to_msg_id else None}
                )
                loop = asyncio.get_running_loop()
                loop.call_soon_threadsafe(self.message_queue.put_nowait, raw_msg)
            except Exception as e:
                self.logger.error(f"Error processing message event: {e}", exc_info=True)
        return handle_new_message # Return the handler function

    # --- start_listening() method remains the same as provided before ---
    async def start_listening(self):
        # Registers handler and starts the Telethon client's event loop
        if not self.client or not self.client.is_connected():
             self.logger.error("Client not connected, cannot start listening.")
             return

        try:
            handler = self._create_message_handler()
            self.client.add_event_handler(handler, events.NewMessage(chats=self.targets))
            self.logger.info(f"Registered message handler for targets: {self.targets}")
            self.logger.info("Starting Telethon event loop (run_until_disconnected)...")
            self._is_running = True # Set flag when starting listener loop
            await self.client.run_until_disconnected()
        except Exception as e:
             self.logger.error(f"Telethon client run_until_disconnected error: {e}", exc_info=True)
        finally:
             self._is_running = False # Clear flag when loop ends
             self.logger.info("Telethon client listener loop ended.")


    # --- stop() method remains the same as provided before ---
    async def stop(self):
        # Disconnects the Telethon client
        self.logger.info(f"Stopping connector {self.source_id}...")
        # Stop listening loop (Telethon does this via disconnect)
        if self.client and self.client.is_connected():
             self.logger.info("Disconnecting Telethon client...")
             try:
                 await self.client.disconnect()
                 self.logger.info("Telethon client disconnected.")
             except Exception as e:
                 self.logger.error(f"Error during disconnect: {e}")
        self.client = None
        self._is_running = False # Ensure flag is cleared

    # ====> ADD THE MISSING run() METHOD <====
    async def run(self):
        """Main run loop coordinating connect and listen."""
        self._is_running = True
        self.logger.info(f"Connector {self.source_id} run method started.")
        try:
            if await self.connect(): # Attempt to connect first
                 await self.start_listening() # If connect successful, start listening loop
            else:
                 self.logger.error("Connection failed in run method. Connector will not listen.")
        except Exception as e:
            # Catch errors that might occur in connect() or during start_listening setup
            self.logger.error(f"Connector {self.source_id} encountered error during run setup: {e}", exc_info=True)
        finally:
            # Ensure stop logic runs if run exits prematurely
            # Although start_listening should block, this is safety for connect failure
            if self._is_running: # If stop wasn't called explicitly
                await self.stop()
            self.logger.info(f"Connector {self.source_id} run method finished.")