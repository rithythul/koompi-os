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

    # Desktop environment
    INSTALL_DESKTOP = "install_desktop"

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

    # Pattern definitions - supports natural language like "help me install xyz"
    PATTERNS = {
        Intent.INSTALL_PACKAGE: [
            r"(?:help\s+me\s+)?install\s+(.+)",
            r"(?:can\s+you\s+)?(?:please\s+)?install\s+(.+)",
            r"(?:i\s+want\s+to\s+)?install\s+(.+)",
            r"(?:i\s+need\s+)?(.+)\s+installed",
            r"add\s+(.+)",
            r"get\s+(?:me\s+)?(.+)",
            r"setup\s+(.+)",
            r"ដំឡើង\s+(.+)",  # Khmer: install
            r"ជួយ\s*ដំឡើង\s+(.+)",  # Khmer: help install
        ],
        Intent.REMOVE_PACKAGE: [
            r"(?:help\s+me\s+)?remove\s+(.+)",
            r"(?:can\s+you\s+)?(?:please\s+)?(?:remove|uninstall|delete)\s+(.+)",
            r"(?:i\s+want\s+to\s+)?(?:remove|uninstall|delete)\s+(.+)",
            r"get\s+rid\s+of\s+(.+)",
            r"លុប\s+(.+)",  # Khmer: delete
        ],
        Intent.UPDATE_SYSTEM: [
            r"(?:help\s+me\s+)?update(?:\s+(?:my\s+)?system)?",
            r"(?:can\s+you\s+)?(?:please\s+)?update(?:\s+everything)?",
            r"upgrade(?:\s+(?:my\s+)?system)?",
            r"(?:keep|make)\s+(?:my\s+)?system\s+up\s+to\s+date",
            r"ធ្វើបច្ចុប្បន្នភាព",  # Khmer: update
        ],
        Intent.SEARCH_PACKAGE: [
            r"(?:help\s+me\s+)?search(?:\s+for)?\s+(.+)",
            r"find\s+(?:a\s+)?package\s+(?:called\s+)?(.+)",
            r"(?:is\s+there\s+a\s+)?package\s+(?:for\s+)?(.+)",
            r"look\s+(?:up|for)\s+(.+)",
            r"what\s+package\s+(?:provides|has)\s+(.+)",
        ],
        Intent.CREATE_SNAPSHOT: [
            r"(?:help\s+me\s+)?create\s+(?:a\s+)?snapshot",
            r"(?:can\s+you\s+)?make\s+(?:a\s+)?snapshot",
            r"(?:please\s+)?backup\s+(?:my\s+)?system",
            r"save\s+(?:the\s+)?(?:current\s+)?system\s+state",
            r"take\s+(?:a\s+)?snapshot",
        ],
        Intent.LIST_SNAPSHOTS: [
            r"(?:help\s+me\s+)?list\s+(?:all\s+)?snapshots",
            r"show\s+(?:me\s+)?(?:all\s+)?snapshots",
            r"what\s+snapshots\s+(?:do\s+i\s+have|exist)",
            r"^snapshots$",
        ],
        Intent.ROLLBACK: [
            r"(?:help\s+me\s+)?rollback(?:\s+to\s+(.+))?",
            r"(?:can\s+you\s+)?restore(?:\s+to\s+(.+))?",
            r"(?:please\s+)?revert(?:\s+to\s+(.+))?",
            r"go\s+back\s+to\s+(?:snapshot\s+)?(.+)",
            r"undo\s+(?:recent\s+)?changes",
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
            r"^help$",
            r"what\s+can\s+you\s+do",
            r"how\s+do\s+i\s+use\s+(?:this|koompi)",
            r"ជួយ",  # Khmer: help
        ],
        Intent.INSTALL_DESKTOP: [
            r"(?:help\s+me\s+)?install\s+(kde|plasma|gnome|xfce|cinnamon|mate|i3|sway|hyprland)",
            r"(?:i\s+want\s+)?(?:to\s+use\s+)?(kde|plasma|gnome|xfce|cinnamon|mate|i3|sway|hyprland)",
            r"setup\s+(kde|plasma|gnome|xfce|cinnamon|mate|i3|sway|hyprland)",
            r"switch\s+to\s+(kde|plasma|gnome|xfce|cinnamon|mate|i3|sway|hyprland)",
            r"(?:give\s+me\s+)?(?:a\s+)?(kde|plasma|gnome|xfce|cinnamon|mate|i3|sway|hyprland)\s+desktop",
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
                # Clean up the package name
                pkg = groups[0].strip()
                # Remove common filler words
                pkg = re.sub(r'^(the|a|an|package|app|application|program)\s+', '', pkg, flags=re.IGNORECASE)
                pkg = re.sub(r'\s+(package|app|application|program)$', '', pkg, flags=re.IGNORECASE)
                entities["package_name"] = pkg.strip()

        elif intent == Intent.ROLLBACK:
            if len(groups) >= 1 and groups[0]:
                entities["snapshot_id"] = groups[0].strip()

        elif intent == Intent.SHARE_FILES:
            if groups:
                entities["files"] = groups[0].strip()

        elif intent == Intent.INSTALL_DESKTOP:
            if groups:
                de = groups[0].lower().strip()
                # Normalize desktop names
                if de == "plasma":
                    de = "kde"
                entities["desktop"] = de

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
