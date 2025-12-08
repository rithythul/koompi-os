"""Local LLM integration using llama.cpp."""

from dataclasses import dataclass
from pathlib import Path
from typing import Optional
import logging

logger = logging.getLogger(__name__)


@dataclass
class AIResponse:
    """Response from AI model."""
    text: str
    confidence: float
    source: str  # "local" or "cloud"


class LocalLLM:
    """Local LLM using llama.cpp."""

    def __init__(
        self,
        model_path: str = "/usr/share/koompi/models/llama-3.3-8b-q4.gguf",
        context_length: int = 8192,
        n_gpu_layers: int = 0,
    ):
        self.model_path = Path(model_path)
        self.context_length = context_length
        self.n_gpu_layers = n_gpu_layers
        self._llm = None

    def load(self) -> bool:
        """Load the model into memory."""
        try:
            from llama_cpp import Llama

            if not self.model_path.exists():
                logger.error(f"Model not found: {self.model_path}")
                return False

            self._llm = Llama(
                model_path=str(self.model_path),
                n_ctx=self.context_length,
                n_gpu_layers=self.n_gpu_layers,
                verbose=False,
            )
            logger.info(f"Loaded model: {self.model_path}")
            return True
        except Exception as e:
            logger.error(f"Failed to load model: {e}")
            return False

    async def generate(
        self,
        prompt: str,
        max_tokens: int = 512,
        temperature: float = 0.7,
    ) -> Optional[str]:
        """Generate text from prompt."""
        if self._llm is None:
            if not self.load():
                return None

        try:
            response = self._llm(
                prompt,
                max_tokens=max_tokens,
                temperature=temperature,
                stop=["</s>", "Human:", "User:"],
            )
            return response["choices"][0]["text"].strip()
        except Exception as e:
            logger.error(f"Generation failed: {e}")
            return None

    def unload(self) -> None:
        """Unload model from memory."""
        self._llm = None


class CloudLLM:
    """Cloud LLM fallback using Claude API."""

    def __init__(self, api_key: Optional[str] = None):
        self.api_key = api_key or self._get_api_key()

    def _get_api_key(self) -> Optional[str]:
        """Get API key from environment or config."""
        import os
        return os.environ.get("ANTHROPIC_API_KEY")

    async def generate(
        self,
        prompt: str,
        max_tokens: int = 512,
    ) -> Optional[str]:
        """Generate text using Claude API."""
        if not self.api_key:
            logger.warning("No API key for cloud LLM")
            return None

        try:
            import anthropic

            client = anthropic.Anthropic(api_key=self.api_key)
            message = client.messages.create(
                model="claude-sonnet-4-20250514",
                max_tokens=max_tokens,
                messages=[{"role": "user", "content": prompt}],
            )
            return message.content[0].text
        except Exception as e:
            logger.error(f"Cloud generation failed: {e}")
            return None


# Global instances
_local_llm: Optional[LocalLLM] = None
_cloud_llm: Optional[CloudLLM] = None


async def query(
    prompt: str,
    use_cloud_fallback: bool = True,
    max_tokens: int = 512,
) -> AIResponse:
    """Query AI with automatic fallback.

    Args:
        prompt: The user's prompt
        use_cloud_fallback: Whether to fall back to cloud if local fails
        max_tokens: Maximum tokens to generate

    Returns:
        AIResponse with text and metadata
    """
    global _local_llm, _cloud_llm

    # Try local first
    if _local_llm is None:
        _local_llm = LocalLLM()

    response = await _local_llm.generate(prompt, max_tokens=max_tokens)
    if response:
        return AIResponse(text=response, confidence=0.9, source="local")

    # Fall back to cloud
    if use_cloud_fallback:
        if _cloud_llm is None:
            _cloud_llm = CloudLLM()

        response = await _cloud_llm.generate(prompt, max_tokens=max_tokens)
        if response:
            return AIResponse(text=response, confidence=0.95, source="cloud")

    return AIResponse(
        text="I'm sorry, I couldn't process that request.",
        confidence=0.0,
        source="none",
    )
