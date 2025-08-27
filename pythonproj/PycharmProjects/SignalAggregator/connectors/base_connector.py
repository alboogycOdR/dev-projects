# connectors/base_connector.py
from abc import ABC, abstractmethod
import asyncio

import logging


class BaseConnector(ABC):
    """Abstract base class for all signal source connectors."""

    def __init__(self, source_id, config, message_queue):
        self.source_id = source_id
        self.config = config  # Specific config section for this source
        self.message_queue = message_queue  # Async queue to pass raw messages
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
