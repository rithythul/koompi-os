"""AI integration using Google Gemini API."""

from dataclasses import dataclass
from typing import Optional
import logging
import os
import google.generativeai as genai

logger = logging.getLogger(__name__)


@dataclass
class AIResponse:
    """Response from AI model."""
    text: str
    confidence: float
    source: str  # "gemini"


class GeminiLLM:
    """Cloud LLM using Google Gemini API."""

    def __init__(self, api_key: Optional[str] = None):
        self.api_key = api_key or os.environ.get("GEMINI_API_KEY")
        self.model = None
        
        if self.api_key:
            try:
                genai.configure(api_key=self.api_key)
                self.model = genai.GenerativeModel('gemini-pro')
            except Exception as e:
                logger.error(f"Failed to configure Gemini: {e}")
        else:
            logger.warning("No GEMINI_API_KEY found")

    async def generate(self, prompt: str) -> Optional[str]:
        """Generate text using Gemini API."""
        if not self.model:
            return None

        try:
            response = await self.model.generate_content_async(prompt)
            return response.text
        except Exception as e:
            logger.error(f"Gemini generation failed: {e}")
            return None


# Global instance
_llm: Optional[GeminiLLM] = None


async def query(prompt: str) -> AIResponse:
    """Query AI.

    Args:
        prompt: The user's prompt

    Returns:
        AIResponse with text and metadata
    """
    global _llm

    if _llm is None:
        _llm = GeminiLLM()

    response = await _llm.generate(prompt)
    if response:
        return AIResponse(text=response, confidence=0.95, source="gemini")

    return AIResponse(
        text="I'm sorry, I couldn't process that request. Please check your internet connection or API key.",
        confidence=0.0,
        source="none",
    )
