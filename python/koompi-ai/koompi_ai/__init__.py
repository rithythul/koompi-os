"""KOOMPI AI - AI integration for KOOMPI OS.

This module provides:
- Cloud AI integration (Gemini) with offline fallback
- Local knowledge base (ArchWiki + KOOMPI docs)
- Voice recognition (Whisper)
- Intent classification

Architecture:
    User Query → Knowledge Search (FTS5) → Gemini + Context (online)
                                        → Knowledge Response (offline)
"""

from .llm import GeminiLLM, query, AIResponse, search_knowledge, get_knowledge_stats
from .knowledge import KnowledgeBase, get_knowledge_base, SearchResult, Article
from .voice import VoiceRecognizer, transcribe
from .intent import IntentClassifier, classify_intent

__version__ = "0.2.0"
__all__ = [
    # LLM
    "GeminiLLM",
    "query",
    "AIResponse",
    # Knowledge Base
    "KnowledgeBase",
    "get_knowledge_base",
    "search_knowledge",
    "get_knowledge_stats",
    "SearchResult",
    "Article",
    # Voice
    "VoiceRecognizer", 
    "transcribe",
    # Intent
    "IntentClassifier",
    "classify_intent",
]

