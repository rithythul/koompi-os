"""Voice recognition using Whisper."""

from dataclasses import dataclass
from pathlib import Path
from typing import Optional
import logging
import tempfile

logger = logging.getLogger(__name__)


@dataclass
class TranscriptionResult:
    """Result of voice transcription."""
    text: str
    language: str
    confidence: float


class VoiceRecognizer:
    """Voice recognition using OpenAI Whisper."""

    def __init__(
        self,
        model_size: str = "base",
        language: str = "km",  # Khmer
    ):
        self.model_size = model_size
        self.language = language
        self._model = None

    def load(self) -> bool:
        """Load the Whisper model."""
        try:
            import whisper

            self._model = whisper.load_model(self.model_size)
            logger.info(f"Loaded Whisper model: {self.model_size}")
            return True
        except Exception as e:
            logger.error(f"Failed to load Whisper: {e}")
            return False

    async def transcribe_file(self, audio_path: str) -> Optional[TranscriptionResult]:
        """Transcribe an audio file."""
        if self._model is None:
            if not self.load():
                return None

        try:
            result = self._model.transcribe(
                audio_path,
                language=self.language if self.language != "auto" else None,
            )
            return TranscriptionResult(
                text=result["text"].strip(),
                language=result.get("language", self.language),
                confidence=0.9,  # Whisper doesn't provide confidence
            )
        except Exception as e:
            logger.error(f"Transcription failed: {e}")
            return None

    async def transcribe_bytes(self, audio_data: bytes) -> Optional[TranscriptionResult]:
        """Transcribe audio from bytes."""
        with tempfile.NamedTemporaryFile(suffix=".wav", delete=True) as f:
            f.write(audio_data)
            f.flush()
            return await self.transcribe_file(f.name)


class AudioRecorder:
    """Record audio from microphone."""

    def __init__(self, sample_rate: int = 16000):
        self.sample_rate = sample_rate
        self._recording = False

    async def record(self, duration: float = 5.0) -> bytes:
        """Record audio for specified duration."""
        try:
            import sounddevice as sd
            import numpy as np
            import io
            import wave

            logger.info(f"Recording for {duration} seconds...")

            audio = sd.rec(
                int(duration * self.sample_rate),
                samplerate=self.sample_rate,
                channels=1,
                dtype=np.int16,
            )
            sd.wait()

            # Convert to WAV bytes
            buffer = io.BytesIO()
            with wave.open(buffer, "wb") as wf:
                wf.setnchannels(1)
                wf.setsampwidth(2)
                wf.setframerate(self.sample_rate)
                wf.writeframes(audio.tobytes())

            return buffer.getvalue()
        except Exception as e:
            logger.error(f"Recording failed: {e}")
            return b""


# Global instance
_recognizer: Optional[VoiceRecognizer] = None
_recorder: Optional[AudioRecorder] = None


async def transcribe(
    audio: Optional[bytes] = None,
    file_path: Optional[str] = None,
    record_duration: float = 5.0,
) -> TranscriptionResult:
    """Transcribe audio from various sources.

    Args:
        audio: Raw audio bytes
        file_path: Path to audio file
        record_duration: Duration to record if no audio provided

    Returns:
        TranscriptionResult with text and metadata
    """
    global _recognizer, _recorder

    if _recognizer is None:
        _recognizer = VoiceRecognizer()

    # Transcribe from file
    if file_path:
        result = await _recognizer.transcribe_file(file_path)
        if result:
            return result

    # Transcribe from bytes
    if audio:
        result = await _recognizer.transcribe_bytes(audio)
        if result:
            return result

    # Record and transcribe
    if _recorder is None:
        _recorder = AudioRecorder()

    audio = await _recorder.record(record_duration)
    if audio:
        result = await _recognizer.transcribe_bytes(audio)
        if result:
            return result

    return TranscriptionResult(text="", language="unknown", confidence=0.0)
