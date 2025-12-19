# KOOMPI OS Local LLM Integration Plan

## Overview

This document outlines the strategy for integrating a local Large Language Model (LLM) into KOOMPI OS to provide offline AI assistance for Linux, Arch Linux, and KOOMPI-specific help.

## Architecture

```
User Query
    │
    ▼
┌─────────────────────┐
│ 1. Intent Rules     │ ← "install firefox" → direct action (instant)
│    (regex-based)    │
└──────────┬──────────┘
           │ unknown intent
           ▼
┌─────────────────────┐
│ 2. Local LLM        │ ← "how do I mount USB?" → Linux knowledge
│    (1-3B params)    │    Offline, private, free
└──────────┬──────────┘
           │ complex/creative tasks
           ▼
┌─────────────────────┐
│ 3. Cloud API        │ ← "write a backup script" → best quality
│    (Gemini)         │    Requires API key + internet
└─────────────────────┘
```

## Benefits for Education

| Benefit | Impact |
|---------|--------|
| **Offline** | Classrooms often have poor/no internet |
| **No API Key** | Students don't need Google accounts |
| **Privacy** | Queries stay on device |
| **Low Latency** | Instant help while typing commands |
| **Free** | No ongoing API costs |
| **Khmer Support** | Potential for local language |

## Model Selection

### Recommended Models

| Model | Size | RAM Required | Speed | Quality | Notes |
|-------|------|--------------|-------|---------|-------|
| **Qwen2.5-1.5B** | ~1GB | 2-3GB | Fast | Good | Multilingual, recommended |
| **Phi-3-mini-4k** | ~2GB | 4GB | Medium | Very Good | Microsoft, instruction-tuned |
| **TinyLlama-1.1B** | ~600MB | 2GB | Very Fast | Basic | Best for low-end devices |
| **SmolLM-1.7B** | ~1GB | 2-3GB | Fast | Good | HuggingFace optimized |
| **Gemma-2B** | ~1.5GB | 3GB | Medium | Good | Google, well-documented |

### Primary Recommendation: **Qwen2.5-1.5B**

- Best balance of size, speed, and capability
- Good multilingual support (potential Khmer fine-tuning)
- Efficient on consumer hardware
- MIT license for commercial use

## Runtime Options

### Option 1: Ollama (Recommended)

```bash
# Installation
curl -fsSL https://ollama.ai/install.sh | sh

# Pull model
ollama pull qwen2.5:1.5b

# Run inference
ollama run qwen2.5:1.5b "How do I install packages in Arch Linux?"
```

**Pros:**
- Simple API (REST + CLI)
- Auto model management
- GPU acceleration support
- Easy integration

### Option 2: llama.cpp

```bash
# Build
git clone https://github.com/ggerganov/llama.cpp
cd llama.cpp && make

# Run
./main -m models/qwen2.5-1.5b.gguf -p "How do I..."
```

**Pros:**
- Maximum performance
- No dependencies
- Fine-grained control

### Option 3: Hugging Face Transformers

```python
from transformers import AutoModelForCausalLM, AutoTokenizer

model = AutoModelForCausalLM.from_pretrained("Qwen/Qwen2.5-1.5B-Instruct")
tokenizer = AutoTokenizer.from_pretrained("Qwen/Qwen2.5-1.5B-Instruct")
```

**Pros:**
- Python native
- Easy fine-tuning
- Large ecosystem

## Fine-Tuning Strategy

### Training Data Sources

1. **Arch Wiki** (~10,000 articles)
   - Comprehensive Linux documentation
   - Arch-specific configurations
   - Troubleshooting guides

2. **Man Pages** (~5,000 pages)
   - Command reference
   - Options and flags
   - Usage examples

3. **KOOMPI Documentation**
   - OS-specific features
   - Btrfs snapshots
   - Mesh networking
   - Classroom mode

4. **Stack Overflow / Unix StackExchange**
   - Q&A format (ideal for instruction tuning)
   - Real user problems
   - Community-validated solutions

5. **Pacman/Systemd Documentation**
   - Package management
   - Service configuration
   - System administration

### Data Preparation Pipeline

```python
# data_preparation.py

import json
from pathlib import Path

def prepare_arch_wiki():
    """Convert Arch Wiki to instruction format."""
    data = []
    
    for article in load_arch_wiki_dump():
        # Create Q&A pairs from sections
        for section in article.sections:
            data.append({
                "instruction": f"How do I {section.title.lower()} in Arch Linux?",
                "input": "",
                "output": section.content
            })
    
    return data

def prepare_man_pages():
    """Convert man pages to instruction format."""
    data = []
    
    for cmd in ["pacman", "systemctl", "btrfs", "nmcli", ...]:
        man_content = get_man_page(cmd)
        
        # Command overview
        data.append({
            "instruction": f"What is the {cmd} command?",
            "input": "",
            "output": man_content.description
        })
        
        # Common options
        for option in man_content.options[:10]:
            data.append({
                "instruction": f"What does {cmd} {option.flag} do?",
                "input": "",
                "output": option.description
            })
    
    return data

def prepare_koompi_docs():
    """KOOMPI-specific documentation."""
    return [
        {
            "instruction": "How do I create a system snapshot in KOOMPI OS?",
            "input": "",
            "output": "Use `koompi snapshot create <name>` to create a Btrfs snapshot..."
        },
        {
            "instruction": "How do I start a classroom session?",
            "input": "",
            "output": "Run `koompi classroom start` to begin a classroom session..."
        },
        # ... more KOOMPI-specific Q&A
    ]
```

### Fine-Tuning Process

```python
# finetune.py

from transformers import (
    AutoModelForCausalLM,
    AutoTokenizer,
    TrainingArguments,
    Trainer
)
from peft import LoraConfig, get_peft_model
from datasets import load_dataset

# 1. Load base model
model_name = "Qwen/Qwen2.5-1.5B-Instruct"
model = AutoModelForCausalLM.from_pretrained(model_name)
tokenizer = AutoTokenizer.from_pretrained(model_name)

# 2. Configure LoRA (efficient fine-tuning)
lora_config = LoraConfig(
    r=16,                    # Rank
    lora_alpha=32,           # Scaling
    target_modules=["q_proj", "v_proj"],
    lora_dropout=0.05,
    bias="none",
    task_type="CAUSAL_LM"
)

model = get_peft_model(model, lora_config)

# 3. Load training data
dataset = load_dataset("json", data_files="koompi_training_data.json")

# 4. Training configuration
training_args = TrainingArguments(
    output_dir="./koompi-llm",
    num_train_epochs=3,
    per_device_train_batch_size=4,
    gradient_accumulation_steps=4,
    learning_rate=2e-4,
    fp16=True,
    save_steps=100,
    logging_steps=10,
)

# 5. Train
trainer = Trainer(
    model=model,
    args=training_args,
    train_dataset=dataset["train"],
    tokenizer=tokenizer,
)

trainer.train()

# 6. Save model
model.save_pretrained("./koompi-assistant-1.5b")
```

### Hardware Requirements for Fine-Tuning

| Component | Minimum | Recommended |
|-----------|---------|-------------|
| GPU | GTX 1080 (8GB) | RTX 3090 (24GB) |
| RAM | 16GB | 32GB |
| Storage | 50GB SSD | 100GB NVMe |
| Time | ~4-8 hours | ~1-2 hours |

**Cloud Alternative:** Google Colab Pro ($10/month) or Lambda Labs

## Integration with KOOMPI CLI

### Python Module: `koompi_ai/local_llm.py`

```python
"""Local LLM integration for KOOMPI OS."""

import os
import httpx
from typing import Optional
import logging

logger = logging.getLogger(__name__)

OLLAMA_HOST = os.environ.get("OLLAMA_HOST", "http://localhost:11434")
DEFAULT_MODEL = "koompi-assistant:latest"  # Or "qwen2.5:1.5b"


class LocalLLM:
    """Interface to local LLM via Ollama."""
    
    def __init__(self, model: str = DEFAULT_MODEL):
        self.model = model
        self.client = httpx.AsyncClient(timeout=60.0)
    
    async def is_available(self) -> bool:
        """Check if Ollama is running."""
        try:
            response = await self.client.get(f"{OLLAMA_HOST}/api/tags")
            return response.status_code == 200
        except Exception:
            return False
    
    async def query(self, prompt: str, system: str = None) -> Optional[str]:
        """Query the local LLM."""
        if not await self.is_available():
            return None
        
        system_prompt = system or """You are KOOMPI Assistant, a helpful AI 
        specialized in Linux, Arch Linux, and KOOMPI OS. Provide concise, 
        accurate answers about system administration, package management, 
        and troubleshooting. When suggesting commands, use KOOMPI CLI 
        (koompi) when available."""
        
        try:
            response = await self.client.post(
                f"{OLLAMA_HOST}/api/generate",
                json={
                    "model": self.model,
                    "prompt": prompt,
                    "system": system_prompt,
                    "stream": False,
                }
            )
            
            if response.status_code == 200:
                return response.json().get("response")
        except Exception as e:
            logger.warning(f"Local LLM query failed: {e}")
        
        return None
    
    async def query_stream(self, prompt: str):
        """Stream response from local LLM."""
        # ... streaming implementation
```

### Updated Query Flow

```python
# koompi_ai/assistant.py

from .intent import classify_intent, Intent
from .local_llm import LocalLLM
from .gemini import GeminiClient

local_llm = LocalLLM()
gemini = GeminiClient()

async def query(text: str) -> Response:
    """Process user query through the 3-tier system."""
    
    # Tier 1: Intent classification (instant)
    classified = classify_intent(text)
    if classified.confidence > 0.85:
        result = execute_intent(classified)
        if result:
            return Response(text=result, source="rules", confidence=0.95)
    
    # Tier 2: Local LLM (offline, fast)
    if await local_llm.is_available():
        response = await local_llm.query(text)
        if response:
            return Response(text=response, source="local", confidence=0.8)
    
    # Tier 3: Cloud API (best quality, requires internet)
    if gemini.has_api_key():
        response = await gemini.query(text)
        return Response(text=response, source="gemini", confidence=0.9)
    
    # Fallback
    return Response(
        text="I couldn't process that query. Please check your internet connection or try 'koompi config set-key gemini <your-api-key>'",
        source="fallback",
        confidence=0.0
    )
```

## Deployment

### Pre-installed on KOOMPI OS

```bash
# In ISO build script
pacman -S ollama

# Pull KOOMPI model
ollama pull koompi-assistant:latest
# Or fallback to base model
ollama pull qwen2.5:1.5b

# Enable service
systemctl enable --user ollama
```

### User Installation

```bash
# Install Ollama
koompi pkg install ollama

# Download KOOMPI Assistant model
ollama pull koompi-assistant

# Test
koompi ask "How do I create a snapshot?"
```

## System Prompt Template

```
You are KOOMPI Assistant, an AI specialized in:
- Linux system administration
- Arch Linux and pacman package management
- KOOMPI OS features (Btrfs snapshots, mesh networking, classroom mode)
- Troubleshooting and debugging

Guidelines:
1. Provide concise, accurate answers
2. Use KOOMPI CLI commands (koompi ...) when available
3. Suggest pacman/systemctl for standard Linux tasks
4. Warn about destructive operations
5. Support both English and Khmer queries

Current system: KOOMPI OS (Arch Linux-based, KDE Plasma, Btrfs)
```

## Evaluation Metrics

| Metric | Target | How to Measure |
|--------|--------|----------------|
| Response Time | <2 seconds | Benchmark 100 queries |
| Accuracy (Linux) | >85% | Test against Arch Wiki |
| Accuracy (KOOMPI) | >90% | Test against our docs |
| Memory Usage | <3GB | Monitor during inference |
| Offline Capability | 100% | Test without network |

## Roadmap

### Phase 1: Ollama Integration (Week 1-2)
- [ ] Add Ollama client to koompi-ai
- [ ] Update query flow to use 3-tier system
- [ ] Add CLI commands for model management
- [ ] Test with base Qwen2.5-1.5B

### Phase 2: Data Collection (Week 3-4)
- [ ] Scrape Arch Wiki (respectfully, with caching)
- [ ] Process man pages
- [ ] Write KOOMPI-specific Q&A pairs
- [ ] Create validation dataset

### Phase 3: Fine-Tuning (Week 5-6)
- [ ] Set up training environment
- [ ] Fine-tune with LoRA
- [ ] Evaluate on validation set
- [ ] Iterate on training data

### Phase 4: Deployment (Week 7-8)
- [ ] Package fine-tuned model
- [ ] Add to KOOMPI OS ISO
- [ ] Create update mechanism
- [ ] Document for users

## References

- [Ollama Documentation](https://ollama.ai/docs)
- [Qwen2.5 Model Card](https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct)
- [LoRA Paper](https://arxiv.org/abs/2106.09685)
- [Arch Wiki](https://wiki.archlinux.org/)
- [PEFT Library](https://github.com/huggingface/peft)
