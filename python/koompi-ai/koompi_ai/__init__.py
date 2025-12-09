"""KOOMPI AI - AI integration for KOOMPI OS.

This module provides:
- Cloud AI integration (Gemini)
- Voice recognition (Whisper)
- Intent classification
"""

from .llm import GeminiLLM, query
from .voice import VoiceRecognizer, transcribe
from .intent import IntentClassifier, classify_intent

__version__ = "0.1.0"
__all__ = [
    "GeminiLLM",
    "query",
    "VoiceRecognizer", 
    "transcribe",
    "IntentClassifier",
    "classify_intent",
]
