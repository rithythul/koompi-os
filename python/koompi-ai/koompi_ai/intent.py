"""Intent classification for KOOMPI assistant."""

from dataclasses import dataclass
from enum import Enum
from typing import Optional, Dict, Any
import re
import logging

logger = logging.getLogger(__name__)


class Intent(Enum):
    """Known intents for the KOOMPI assistant."""
    
    # Package management
    INSTALL_PACKAGE = "install_package"
    REMOVE_PACKAGE = "remove_package"
    UPDATE_SYSTEM = "update_system"
    SEARCH_PACKAGE = "search_package"

    # Snapshot management
    CREATE_SNAPSHOT = "create_snapshot"
    LIST_SNAPSHOTS = "list_snapshots"
    ROLLBACK = "rollback"

    # System info
    SYSTEM_INFO = "system_info"
    DISK_SPACE = "disk_space"
    MEMORY_INFO = "memory_info"

    # File operations
    FIND_FILES = "find_files"
    OPEN_FILE = "open_file"
    COMPRESS_FILES = "compress_files"

    # Classroom
    SHARE_FILES = "share_files"
    COLLECT_ASSIGNMENTS = "collect_assignments"
    LIST_DEVICES = "list_devices"

    # Help
    HELP = "help"
    TUTORIAL = "tutorial"

    # General
    GREETING = "greeting"
    UNKNOWN = "unknown"


@dataclass
class ClassifiedIntent:
    """Result of intent classification."""
    intent: Intent
    confidence: float
    entities: Dict[str, Any]
    raw_text: str


class IntentClassifier:
    """Rule-based intent classifier with AI fallback."""

    # Pattern definitions
    PATTERNS = {
        Intent.INSTALL_PACKAGE: [
            r"install\s+(.+)",
            r"add\s+(.+)",
            r"get\s+(.+)",
            r"ដំឡើង\s+(.+)",  # Khmer: install
        ],
        Intent.REMOVE_PACKAGE: [
            r"remove\s+(.+)",
            r"uninstall\s+(.+)",
            r"delete\s+(.+)",
            r"លុប\s+(.+)",  # Khmer: delete
        ],
        Intent.UPDATE_SYSTEM: [
            r"update(\s+system)?",
            r"upgrade(\s+system)?",
            r"ធ្វើបច្ចុប្បន្នភាព",  # Khmer: update
        ],
        Intent.SEARCH_PACKAGE: [
            r"search\s+(.+)",
            r"find\s+package\s+(.+)",
            r"look\s+for\s+(.+)",
        ],
        Intent.CREATE_SNAPSHOT: [
            r"create\s+snapshot",
            r"make\s+snapshot",
            r"backup\s+system",
        ],
        Intent.LIST_SNAPSHOTS: [
            r"list\s+snapshots",
            r"show\s+snapshots",
            r"snapshots",
        ],
        Intent.ROLLBACK: [
            r"rollback(\s+to\s+(.+))?",
            r"restore(\s+to\s+(.+))?",
            r"revert(\s+to\s+(.+))?",
        ],
        Intent.SYSTEM_INFO: [
            r"system\s+info",
            r"about\s+(this\s+)?computer",
            r"specs",
        ],
        Intent.DISK_SPACE: [
            r"disk\s+space",
            r"storage",
            r"how\s+much\s+space",
        ],
        Intent.MEMORY_INFO: [
            r"memory",
            r"ram",
            r"how\s+much\s+ram",
        ],
        Intent.SHARE_FILES: [
            r"share\s+(.+)",
            r"send\s+(.+)\s+to\s+(.+)",
        ],
        Intent.LIST_DEVICES: [
            r"who\s+is\s+online",
            r"list\s+devices",
            r"show\s+students",
        ],
        Intent.GREETING: [
            r"^(hi|hello|hey|សួស្តី)$",
            r"good\s+(morning|afternoon|evening)",
        ],
        Intent.HELP: [
            r"help(\s+me)?",
            r"what\s+can\s+you\s+do",
            r"ជួយ",  # Khmer: help
        ],
    }

    def __init__(self):
        self._compiled_patterns = self._compile_patterns()

    def _compile_patterns(self) -> Dict[Intent, list]:
        """Compile regex patterns."""
        compiled = {}
        for intent, patterns in self.PATTERNS.items():
            compiled[intent] = [re.compile(p, re.IGNORECASE) for p in patterns]
        return compiled

    def classify(self, text: str) -> ClassifiedIntent:
        """Classify the intent of the given text."""
        text = text.strip()
        
        for intent, patterns in self._compiled_patterns.items():
            for pattern in patterns:
                match = pattern.search(text)
                if match:
                    entities = self._extract_entities(intent, match)
                    return ClassifiedIntent(
                        intent=intent,
                        confidence=0.9,
                        entities=entities,
                        raw_text=text,
                    )

        return ClassifiedIntent(
            intent=Intent.UNKNOWN,
            confidence=0.5,
            entities={},
            raw_text=text,
        )

    def _extract_entities(self, intent: Intent, match: re.Match) -> Dict[str, Any]:
        """Extract entities from regex match."""
        entities = {}
        groups = match.groups()

        if intent in (Intent.INSTALL_PACKAGE, Intent.REMOVE_PACKAGE, Intent.SEARCH_PACKAGE):
            if groups:
                entities["package_name"] = groups[0].strip()

        elif intent == Intent.ROLLBACK:
            if len(groups) >= 2 and groups[1]:
                entities["snapshot_id"] = groups[1].strip()

        elif intent == Intent.SHARE_FILES:
            if groups:
                entities["files"] = groups[0].strip()

        return entities


# Global instance
_classifier: Optional[IntentClassifier] = None


def classify_intent(text: str) -> ClassifiedIntent:
    """Classify the intent of text.

    Args:
        text: User input text

    Returns:
        ClassifiedIntent with intent and entities
    """
    global _classifier

    if _classifier is None:
        _classifier = IntentClassifier()

    return _classifier.classify(text)
