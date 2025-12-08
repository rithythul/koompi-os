"""KOOMPI AI - AI integration for KOOMPI OS.

This module provides:
- Local LLM integration (Llama)
- Cloud AI fallback (Claude)
- Voice recognition (Whisper)
- Intent classification
"""

from .llm import LocalLLM, query
from .voice import VoiceRecognizer, transcribe
from .intent import IntentClassifier, classify_intent

__version__ = "0.1.0"
__all__ = [
    "LocalLLM",
    "query",
    "VoiceRecognizer", 
    "transcribe",
    "IntentClassifier",
    "classify_intent",
]
