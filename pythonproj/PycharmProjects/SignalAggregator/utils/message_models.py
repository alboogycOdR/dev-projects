# utils/message_models.py
from dataclasses import dataclass, field
from datetime import datetime


@dataclass
class RawMessage:
    """Standardized representation of a raw message from a source."""
    source_id: str  # Unique ID of the source defined in config.yaml (e.g., 'telegram_fxscalping')
    connector_type: str  # Type of connector (e.g., 'telegram_user', 'discord_bot')
    original_id: str  # Platform-specific message ID (e.g., Telegram message ID)
    timestamp: datetime  # Timestamp of the message (preferably UTC)
    text: str  # The raw text content of the message
    channel_info: str  # Info about the channel/chat it came from (e.g., username, ID)
    author_info: str = ""  # Info about the author (if available/relevant)
    metadata: dict = field(default_factory=dict)  # Any other source-specific details
