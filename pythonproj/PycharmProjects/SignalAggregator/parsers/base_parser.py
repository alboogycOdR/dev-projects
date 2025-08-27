# parsers/base_parser.py
from abc import ABC, abstractmethod
import logging


class BaseParser(ABC):
    """Abstract base class for all signal format parsers."""

    def __init__(self, parser_id, config):
        self.parser_id = parser_id
        self.config = config  # Specific config section for this parser
        self.logger = logging.getLogger(f"Parser.{self.parser_id}")

    @abstractmethod
    def parse(self, raw_message):
        """
        Parses a raw message object.
        Returns a dictionary with extracted signal data (non-normalized)
        or None if parsing fails or message doesn't match format.
        """
        pass
