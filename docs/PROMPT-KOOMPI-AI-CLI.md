# KOOMPI AI CLI - AI Agent Build Prompt

## Mission

Build a standalone, cross-distribution AI-powered command-line assistant. Users bring their own Google Gemini API key. The CLI works offline with a comprehensive knowledge base and enhances with cloud AI when API key is provided.

> **Note:** This is a **standalone Python package** that can be installed on any Linux distribution. It is pre-installed in KOOMPI OS but works independently.

---

## Project Overview

**Package Name:** `koompi-cli`
**Repository:** `github.com/koompi/koompi-ai-cli` (new repo)
**Language:** Python 3.10+
**Distribution:** PyPI, AUR

**Install Methods:**
```bash
pip install koompi-cli              # PyPI (any distro)
yay -S koompi-cli                   # AUR (Arch-based)
```

---

## Repository Structure

```
koompi-ai-cli/
├── koompi_ai/                    # AI Engine
│   ├── __init__.py
│   ├── llm.py                    # Gemini API + offline fallback
│   ├── intent.py                 # Natural language intent classification
│   ├── knowledge.py              # Offline knowledge base
│   └── voice.py                  # Voice input (optional)
├── koompi_cli/                   # CLI Interface
│   ├── __init__.py
│   ├── main.py                   # Click CLI entry point
│   ├── commands/                 # Command modules
│   │   ├── __init__.py
│   │   ├── package.py            # Package management
│   │   ├── system.py             # System info
│   │   ├── ai.py                 # AI chat/ask
│   │   └── setup.py              # API key setup
│   └── ui.py                     # Rich terminal UI helpers
├── tests/
│   ├── test_llm.py
│   ├── test_intent.py
│   └── test_cli.py
├── pyproject.toml                # Package config
├── README.md
└── LICENSE
```

---

## Requirements

### 1. Core Features

**Natural Language Understanding:**
```bash
koompi install firefox              # Structured command
koompi help me install firefox      # Natural language
koompi how do I check disk space    # Question
koompi "what's the arch equivalent of apt update"
```

**Offline-First Design:**
- Works completely offline with built-in knowledge base
- No API key required for basic functionality
- Cloud AI enhances responses when available

**Cross-Distribution Support:**
- Detect current distro (Arch, Ubuntu, Fedora, etc.)
- Provide distro-appropriate commands
- Focus on Arch/KOOMPI but support others

---

### 2. CLI Commands

```bash
# Package Management (distro-aware)
koompi install <package>          # Install package
koompi remove <package>           # Remove package
koompi search <query>             # Search packages
koompi update                     # Update system

# AI Assistant
koompi ask <question>             # One-shot question
koompi chat                       # Interactive chat mode
koompi explain <command>          # Explain a command

# System Information
koompi info                       # System overview
koompi disk                       # Disk usage
koompi memory                     # Memory usage
koompi processes                  # Top processes

# Setup
koompi setup                      # Configure API key
koompi setup --check              # Check API status
koompi setup --remove             # Remove API key

# Help
koompi help                       # Show help
koompi --version                  # Show version
```

---

### 3. AI Engine (`koompi_ai/`)

#### `llm.py` - LLM Interface

```python
"""Google Gemini API with offline fallback."""

import os
from dataclasses import dataclass
from typing import Optional

try:
    import google.generativeai as genai
    GENAI_AVAILABLE = True
except ImportError:
    GENAI_AVAILABLE = False


SYSTEM_PROMPT = """You are KOOMPI Assistant, an AI expert for Linux, Windows, and macOS.

## Your Expertise

### Linux (Primary)
- Arch Linux: pacman, AUR, yay, systemd, GRUB
- KOOMPI OS: Btrfs snapshots, immutability, koompi commands
- Ubuntu/Debian: apt, dpkg, snap
- Fedora/RHEL: dnf, rpm
- General: bash, zsh, file systems, networking

### Windows
- PowerShell, CMD, winget
- WSL (Windows Subsystem for Linux)
- Windows equivalents for Linux commands

### macOS
- Terminal, zsh, Homebrew
- macOS equivalents for Linux commands

### Programming
- Python, Rust, JavaScript, Go, C/C++
- Git, Docker, development tools

## Response Guidelines
1. Detect user's distro and provide appropriate commands
2. Explain the "why", not just the "what"
3. Warn about dangerous commands
4. Support Khmer language (respond in Khmer if asked in Khmer)
5. Be educational and patient
"""


@dataclass
class AIResponse:
    text: str
    confidence: float
    source: str  # "gemini", "offline", "error"
    is_offline: bool


class GeminiLLM:
    """Cloud LLM with offline fallback."""

    def __init__(self, api_key: Optional[str] = None):
        self.api_key = api_key or os.environ.get("GEMINI_API_KEY") or os.environ.get("GOOGLE_API_KEY")
        self.model = None
        self._is_offline = not GENAI_AVAILABLE or not self.api_key

        if not self._is_offline:
            try:
                genai.configure(api_key=self.api_key)
                self.model = genai.GenerativeModel(
                    'gemini-1.5-flash',
                    system_instruction=SYSTEM_PROMPT
                )
            except Exception:
                self._is_offline = True

    @property
    def is_offline(self) -> bool:
        return self._is_offline

    async def generate(self, prompt: str) -> AIResponse:
        """Generate response, falling back to offline if needed."""
        from .knowledge import get_offline_response

        # Try offline first for common queries
        offline = get_offline_response(prompt)

        if self.is_offline:
            if offline:
                return AIResponse(offline, 0.7, "offline", True)
            return AIResponse(
                "I'm in offline mode. For enhanced AI, run: koompi setup",
                0.3, "offline", True
            )

        try:
            response = self.model.generate_content(prompt)
            return AIResponse(response.text, 0.95, "gemini", False)
        except Exception as e:
            if offline:
                return AIResponse(
                    f"{offline}\n\n*[Offline - API error: {e}]*",
                    0.6, "offline", True
                )
            return AIResponse(f"API error: {e}", 0.0, "error", True)
```

#### `intent.py` - Intent Classification

```python
"""Natural language intent classification."""

from enum import Enum, auto
from dataclasses import dataclass
from typing import Dict, Any
import re


class Intent(Enum):
    # Package management
    INSTALL_PACKAGE = auto()
    REMOVE_PACKAGE = auto()
    UPDATE_SYSTEM = auto()
    SEARCH_PACKAGE = auto()

    # System
    SYSTEM_INFO = auto()
    DISK_SPACE = auto()
    MEMORY_INFO = auto()
    PROCESS_LIST = auto()

    # Snapshots (KOOMPI-specific)
    CREATE_SNAPSHOT = auto()
    LIST_SNAPSHOTS = auto()
    ROLLBACK = auto()

    # Desktop
    INSTALL_DESKTOP = auto()

    # Conversation
    GREETING = auto()
    HELP = auto()
    QUESTION = auto()  # General question for AI

    UNKNOWN = auto()


@dataclass
class IntentResult:
    intent: Intent
    confidence: float
    entities: Dict[str, Any]


def classify_intent(text: str) -> IntentResult:
    """Classify user intent from natural language."""
    text_lower = text.lower().strip()

    # Greetings
    if any(g in text_lower for g in ["hello", "hi", "hey", "សួស្តី"]):
        return IntentResult(Intent.GREETING, 0.9, {})

    # Help
    if text_lower in ("help", "?", "--help"):
        return IntentResult(Intent.HELP, 0.95, {})

    # Install patterns
    install_patterns = [
        r"install\s+(\S+)",
        r"add\s+(\S+)",
        r"get\s+(\S+)",
        r"i want to install\s+(\S+)",
        r"help me install\s+(\S+)",
    ]
    for pattern in install_patterns:
        match = re.search(pattern, text_lower)
        if match:
            return IntentResult(Intent.INSTALL_PACKAGE, 0.9, {"package_name": match.group(1)})

    # Remove patterns
    remove_patterns = [
        r"remove\s+(\S+)",
        r"uninstall\s+(\S+)",
        r"delete\s+(\S+)",
    ]
    for pattern in remove_patterns:
        match = re.search(pattern, text_lower)
        if match:
            return IntentResult(Intent.REMOVE_PACKAGE, 0.9, {"package_name": match.group(1)})

    # Update
    if any(u in text_lower for u in ["update", "upgrade", "syu"]):
        return IntentResult(Intent.UPDATE_SYSTEM, 0.85, {})

    # Search
    search_match = re.search(r"search\s+(\S+)", text_lower)
    if search_match:
        return IntentResult(Intent.SEARCH_PACKAGE, 0.9, {"query": search_match.group(1)})

    # System info
    if any(s in text_lower for s in ["info", "system info", "about"]):
        return IntentResult(Intent.SYSTEM_INFO, 0.85, {})

    # Disk
    if any(d in text_lower for d in ["disk", "storage", "space", "df"]):
        return IntentResult(Intent.DISK_SPACE, 0.85, {})

    # Memory
    if any(m in text_lower for m in ["memory", "ram", "free"]):
        return IntentResult(Intent.MEMORY_INFO, 0.85, {})

    # Snapshots
    if "snapshot" in text_lower:
        if "create" in text_lower or "make" in text_lower:
            return IntentResult(Intent.CREATE_SNAPSHOT, 0.85, {})
        if "list" in text_lower:
            return IntentResult(Intent.LIST_SNAPSHOTS, 0.85, {})
        return IntentResult(Intent.LIST_SNAPSHOTS, 0.7, {})

    # Rollback
    if "rollback" in text_lower or "restore" in text_lower:
        match = re.search(r"(?:rollback|restore)\s+(?:to\s+)?(\S+)", text_lower)
        sid = match.group(1) if match else None
        return IntentResult(Intent.ROLLBACK, 0.85, {"snapshot_id": sid})

    # Desktop
    desktop_match = re.search(r"(?:desktop|install)\s+(kde|gnome|xfce|tiling|terminal|lite)", text_lower)
    if desktop_match or "desktop" in text_lower:
        de = desktop_match.group(1) if desktop_match else None
        return IntentResult(Intent.INSTALL_DESKTOP, 0.8, {"desktop": de})

    # Default: treat as question for AI
    return IntentResult(Intent.QUESTION, 0.5, {"question": text})
```

#### `knowledge.py` - Offline Knowledge Base

```python
"""Comprehensive offline knowledge base."""

from typing import Optional, Dict

KNOWLEDGE_BASE: Dict[str, str] = {
    # ═══════════════════════════════════════════════════════════════
    # Greetings & Help
    # ═══════════════════════════════════════════════════════════════

    "greeting": """សួស្តី! Hello! I'm KOOMPI Assistant.

I can help you with:
• Linux commands and system administration
• Package management (Arch, Ubuntu, Fedora)
• Windows and macOS equivalents
• Programming and development

Try: koompi help""",

    "help": """KOOMPI CLI - AI-Powered Assistant

**Package Management:**
  koompi install <pkg>    Install packages
  koompi remove <pkg>     Remove packages
  koompi search <query>   Search packages
  koompi update           Update system

**AI Assistant:**
  koompi ask <question>   Ask a question
  koompi chat             Interactive chat
  koompi explain <cmd>    Explain a command

**System:**
  koompi info             System information
  koompi disk             Disk usage
  koompi memory           Memory usage

**Setup:**
  koompi setup            Configure AI (optional)

Just type naturally: "koompi how do I check disk space" """,

    # ═══════════════════════════════════════════════════════════════
    # Package Management
    # ═══════════════════════════════════════════════════════════════

    "install": """**Installing packages:**

**Arch Linux / KOOMPI OS:**
```bash
sudo pacman -S firefox          # Official repos
yay -S spotify                  # AUR packages
```

**Ubuntu/Debian:**
```bash
sudo apt install firefox
```

**Fedora:**
```bash
sudo dnf install firefox
```

**Universal:**
```bash
flatpak install flathub org.mozilla.firefox
```""",

    "remove": """**Removing packages:**

**Arch Linux / KOOMPI OS:**
```bash
sudo pacman -Rns firefox        # Remove with dependencies
```

**Ubuntu/Debian:**
```bash
sudo apt remove firefox
sudo apt autoremove             # Clean unused deps
```

**Fedora:**
```bash
sudo dnf remove firefox
```""",

    "update": """**Updating system:**

**Arch Linux / KOOMPI OS:**
```bash
sudo pacman -Syu                # Official packages
yay -Syu                        # Include AUR
```

**Ubuntu/Debian:**
```bash
sudo apt update && sudo apt upgrade
```

**Fedora:**
```bash
sudo dnf upgrade
```""",

    "search": """**Searching packages:**

**Arch Linux:**
```bash
pacman -Ss firefox              # Search official
yay -Ss firefox                 # Search AUR too
```

**Ubuntu/Debian:**
```bash
apt search firefox
```

**Fedora:**
```bash
dnf search firefox
```""",

    # ═══════════════════════════════════════════════════════════════
    # System Information
    # ═══════════════════════════════════════════════════════════════

    "disk": """**Check disk space:**

```bash
df -h                           # Disk usage (human readable)
du -sh /path/to/dir             # Directory size
ncdu /                          # Interactive disk usage
lsblk                           # List block devices
```

**Btrfs-specific:**
```bash
sudo btrfs filesystem usage /
sudo btrfs filesystem df /
```""",

    "memory": """**Check memory usage:**

```bash
free -h                         # Memory overview
htop                            # Interactive process viewer
btop                            # Modern system monitor
cat /proc/meminfo               # Detailed memory info
```""",

    "processes": """**View processes:**

```bash
htop                            # Interactive (recommended)
btop                            # Modern alternative
top                             # Classic
ps aux                          # List all processes
ps aux | grep firefox           # Find specific process
kill <PID>                      # Kill by PID
pkill firefox                   # Kill by name
```""",

    # ═══════════════════════════════════════════════════════════════
    # KOOMPI-Specific
    # ═══════════════════════════════════════════════════════════════

    "snapshot": """**KOOMPI OS Snapshots:**

```bash
koompi-snapshot create "my backup"    # Create snapshot
koompi-snapshot list                  # List all snapshots
koompi-snapshot info <id>             # Snapshot details
koompi-snapshot delete <id>           # Delete snapshot
koompi-snapshot rollback <id>         # Rollback (needs reboot)
```

Snapshots use Btrfs copy-on-write - instant and space-efficient!""",

    "rollback": """**Rollback system:**

```bash
# List available snapshots
koompi-snapshot list

# Rollback to specific snapshot
koompi-snapshot rollback <snapshot-id>

# Reboot to complete
sudo reboot
```

Your /home data is preserved during rollback.""",

    "desktop": """**Install desktop environment:**

**KOOMPI Editions (Recommended):**
```bash
koompi-desktop tiling           # Hyprland + waybar + configs
koompi-desktop terminal         # Pure CLI (zellij, neovim)
koompi-desktop lite             # Openbox (lightweight)
```

**Community Desktops:**
```bash
koompi-desktop kde              # KDE Plasma
koompi-desktop gnome            # GNOME
koompi-desktop xfce             # XFCE
```

Or run `koompi-desktop` for interactive menu.""",

    # ═══════════════════════════════════════════════════════════════
    # Cross-Platform
    # ═══════════════════════════════════════════════════════════════

    "windows": """**Windows equivalents:**

| Linux | Windows | Description |
|-------|---------|-------------|
| `ls` | `dir` | List files |
| `cat` | `type` | Show file content |
| `grep` | `findstr` | Search text |
| `rm` | `del` | Delete file |
| `cp` | `copy` | Copy file |
| `mv` | `move` | Move/rename |
| `sudo` | Run as Admin | Elevated |
| `pacman` | `winget` | Package manager |
| `systemctl` | `sc` | Services |

PowerShell is more Linux-like than CMD!""",

    "macos": """**macOS equivalents:**

macOS uses zsh and has many Unix commands built-in.

**Package management:**
```bash
brew install firefox            # Homebrew (install first)
```

**Key differences:**
- No apt/pacman → use Homebrew
- No systemd → use launchctl
- File system: APFS (not ext4)
- /System is read-only

Most Linux commands work: ls, cat, grep, find, etc.""",

    # ═══════════════════════════════════════════════════════════════
    # Programming
    # ═══════════════════════════════════════════════════════════════

    "python": """**Python development:**

```bash
# Install Python
sudo pacman -S python python-pip    # Arch
sudo apt install python3 python3-pip # Ubuntu

# Virtual environment (recommended)
python -m venv myproject
source myproject/bin/activate
pip install requests flask

# Run script
python script.py

# Deactivate venv
deactivate
```""",

    "git": """**Git basics:**

```bash
# Clone repository
git clone https://github.com/user/repo.git
cd repo

# Basic workflow
git status                      # Check changes
git add .                       # Stage all
git commit -m "message"         # Commit
git push                        # Push to remote

# Branches
git branch feature              # Create branch
git checkout feature            # Switch branch
git merge feature               # Merge into current

# Undo
git checkout -- file            # Discard changes
git reset HEAD~1                # Undo last commit
```""",

    "docker": """**Docker basics:**

```bash
# Install (Arch)
sudo pacman -S docker docker-compose
sudo systemctl enable --now docker
sudo usermod -aG docker $USER   # Run without sudo

# Common commands
docker pull nginx               # Download image
docker run -d -p 80:80 nginx    # Run container
docker ps                       # List running
docker stop <id>                # Stop container
docker rm <id>                  # Remove container

# Docker Compose
docker-compose up -d            # Start services
docker-compose down             # Stop services
```""",
}


def get_offline_response(prompt: str) -> Optional[str]:
    """Get response from offline knowledge base."""
    prompt_lower = prompt.lower()

    # Greeting detection
    if any(g in prompt_lower for g in ["hello", "hi", "hey", "សួស្តី", "good morning"]):
        return KNOWLEDGE_BASE["greeting"]

    # Help
    if prompt_lower.strip() in ("help", "?", "--help", "what can you do"):
        return KNOWLEDGE_BASE["help"]

    # Topic matching
    topic_keywords = {
        "install": ["install", "add", "get", "setup"],
        "remove": ["remove", "uninstall", "delete"],
        "update": ["update", "upgrade", "syu"],
        "search": ["search", "find package"],
        "disk": ["disk", "storage", "space", "df", "du"],
        "memory": ["memory", "ram", "free -h"],
        "processes": ["process", "htop", "top", "kill", "ps"],
        "snapshot": ["snapshot", "btrfs snapshot"],
        "rollback": ["rollback", "restore", "revert"],
        "desktop": ["desktop", "kde", "gnome", "xfce", "hyprland"],
        "windows": ["windows", "cmd", "powershell", "winget"],
        "macos": ["macos", "mac os", "homebrew", "brew"],
        "python": ["python", "pip", "venv", "virtualenv"],
        "git": ["git", "clone", "commit", "push", "pull"],
        "docker": ["docker", "container", "compose"],
    }

    for topic, keywords in topic_keywords.items():
        if any(kw in prompt_lower for kw in keywords):
            return KNOWLEDGE_BASE.get(topic)

    return None
```

---

### 4. CLI Interface (`koompi_cli/`)

#### `main.py` - Entry Point

```python
"""KOOMPI CLI - AI-powered command-line assistant."""

import click
import asyncio
from rich.console import Console
from rich.table import Table
from rich.panel import Panel

from koompi_ai import classify_intent, query
from koompi_ai.intent import Intent

console = Console()


@click.group(invoke_without_command=True)
@click.pass_context
@click.argument('args', nargs=-1)
@click.version_option(version="1.0.0")
def cli(ctx, args):
    """KOOMPI CLI - AI-powered assistant.

    Supports natural language:
      koompi install firefox
      koompi help me install firefox
      koompi how do I check disk space
    """
    if ctx.invoked_subcommand is None:
        if args:
            text = " ".join(args)
            handle_natural_language(text)
        else:
            click.echo(ctx.get_help())


def handle_natural_language(text: str):
    """Process natural language input."""
    result = classify_intent(text)

    if result.intent == Intent.GREETING:
        console.print("[green]សួស្តី! Hello! How can I help you?[/green]")
        console.print("Try: [cyan]koompi help[/cyan]")
        return

    if result.intent == Intent.HELP:
        show_help()
        return

    if result.intent == Intent.INSTALL_PACKAGE:
        pkg = result.entities.get("package_name")
        if pkg:
            install_package(pkg)
        return

    if result.intent == Intent.REMOVE_PACKAGE:
        pkg = result.entities.get("package_name")
        if pkg:
            remove_package(pkg)
        return

    if result.intent == Intent.UPDATE_SYSTEM:
        update_system()
        return

    if result.intent == Intent.SEARCH_PACKAGE:
        query = result.entities.get("query")
        if query:
            search_package(query)
        return

    if result.intent == Intent.DISK_SPACE:
        import subprocess
        subprocess.run(["df", "-h"])
        return

    if result.intent == Intent.MEMORY_INFO:
        import subprocess
        subprocess.run(["free", "-h"])
        return

    if result.intent == Intent.SYSTEM_INFO:
        show_system_info()
        return

    # Default: ask AI
    ask_ai(text)


def ask_ai(question: str):
    """Ask AI a question."""
    console.print("[dim]Thinking...[/dim]")

    async def run():
        response = await query(question)
        console.print(f"\n{response.text}")
        if response.is_offline:
            console.print("\n[dim]📴 Offline mode. Run 'koompi setup' for enhanced AI.[/dim]")

    asyncio.run(run())


# ═══════════════════════════════════════════════════════════════
# Commands
# ═══════════════════════════════════════════════════════════════

@cli.command()
@click.argument('packages', nargs=-1, required=True)
def install(packages):
    """Install packages."""
    for pkg in packages:
        install_package(pkg)


@cli.command()
@click.argument('packages', nargs=-1, required=True)
def remove(packages):
    """Remove packages."""
    for pkg in packages:
        remove_package(pkg)


@cli.command()
@click.argument('query')
def search(query):
    """Search for packages."""
    search_package(query)


@cli.command()
def update():
    """Update system."""
    update_system()


@cli.command()
@click.argument('question', nargs=-1, required=True)
def ask(question):
    """Ask AI a question."""
    ask_ai(" ".join(question))


@cli.command()
def chat():
    """Interactive chat with AI."""
    console.print(Panel("KOOMPI AI Chat", subtitle="Type 'exit' to quit"))

    while True:
        try:
            user_input = console.input("[bold cyan]You:[/bold cyan] ")
            if user_input.lower() in ("exit", "quit", "bye"):
                console.print("Goodbye! 👋")
                break
            if not user_input.strip():
                continue
            ask_ai(user_input)
            console.print()
        except (KeyboardInterrupt, EOFError):
            console.print("\nGoodbye! 👋")
            break


@cli.command()
def info():
    """Show system information."""
    show_system_info()


@cli.command()
def disk():
    """Show disk usage."""
    import subprocess
    subprocess.run(["df", "-h"])


@cli.command()
def memory():
    """Show memory usage."""
    import subprocess
    subprocess.run(["free", "-h"])


@cli.command()
@click.option('--check', is_flag=True, help='Check API status')
@click.option('--remove', is_flag=True, help='Remove API key')
def setup(check, remove):
    """Configure AI API key."""
    import os

    if check:
        key = os.environ.get("GEMINI_API_KEY") or os.environ.get("GOOGLE_API_KEY")
        if key:
            console.print(f"[green]✓ API key configured[/green] ({key[:8]}...)")
        else:
            console.print("[yellow]✗ No API key configured[/yellow]")
            console.print("Run: koompi setup")
        return

    if remove:
        # Remove from shell configs
        console.print("[yellow]Remove GEMINI_API_KEY from ~/.bashrc and ~/.zshrc[/yellow]")
        return

    console.print(Panel("KOOMPI AI Setup", subtitle="Configure Gemini API"))
    console.print()
    console.print("Get your free API key at:")
    console.print("[cyan]https://aistudio.google.com/app/apikey[/cyan]")
    console.print()

    api_key = console.input("Enter your Gemini API key: ")

    if api_key.strip():
        # Save to shell configs
        home = os.path.expanduser("~")
        export_line = f'\nexport GEMINI_API_KEY="{api_key.strip()}"\n'

        for rc in [".bashrc", ".zshrc"]:
            rc_path = os.path.join(home, rc)
            if os.path.exists(rc_path):
                with open(rc_path, "a") as f:
                    f.write(export_line)

        os.environ["GEMINI_API_KEY"] = api_key.strip()

        console.print()
        console.print("[green]✓ API key saved![/green]")
        console.print("Restart your shell or run: source ~/.zshrc")
        console.print()
        console.print("Testing connection...")
        ask_ai("Hello, are you working?")
    else:
        console.print("[yellow]No key provided. AI will work in offline mode.[/yellow]")


# ═══════════════════════════════════════════════════════════════
# Helper Functions
# ═══════════════════════════════════════════════════════════════

def detect_distro() -> str:
    """Detect Linux distribution."""
    import os
    if os.path.exists("/etc/os-release"):
        with open("/etc/os-release") as f:
            for line in f:
                if line.startswith("ID="):
                    return line.split("=")[1].strip().strip('"')
    return "unknown"


def install_package(pkg: str):
    """Install package using distro's package manager."""
    import subprocess
    distro = detect_distro()

    console.print(f"[cyan]Installing {pkg}...[/cyan]")

    if distro in ("arch", "koompi", "manjaro", "endeavouros"):
        result = subprocess.run(["sudo", "pacman", "-S", "--needed", "--noconfirm", pkg])
        if result.returncode != 0:
            console.print("[yellow]Not in official repos, trying AUR...[/yellow]")
            subprocess.run(["yay", "-S", "--needed", pkg])
    elif distro in ("ubuntu", "debian", "linuxmint", "pop"):
        subprocess.run(["sudo", "apt", "install", "-y", pkg])
    elif distro in ("fedora", "rhel", "centos", "rocky"):
        subprocess.run(["sudo", "dnf", "install", "-y", pkg])
    else:
        console.print(f"[yellow]Unknown distro: {distro}[/yellow]")
        console.print(f"Try manually: sudo pacman -S {pkg}")


def remove_package(pkg: str):
    """Remove package using distro's package manager."""
    import subprocess
    distro = detect_distro()

    console.print(f"[cyan]Removing {pkg}...[/cyan]")

    if distro in ("arch", "koompi", "manjaro", "endeavouros"):
        subprocess.run(["sudo", "pacman", "-Rns", pkg])
    elif distro in ("ubuntu", "debian", "linuxmint", "pop"):
        subprocess.run(["sudo", "apt", "remove", "-y", pkg])
    elif distro in ("fedora", "rhel", "centos", "rocky"):
        subprocess.run(["sudo", "dnf", "remove", "-y", pkg])


def search_package(query: str):
    """Search for packages."""
    import subprocess
    distro = detect_distro()

    if distro in ("arch", "koompi", "manjaro", "endeavouros"):
        console.print("[cyan]=== Official Repositories ===[/cyan]")
        subprocess.run(["pacman", "-Ss", query])
        import shutil
        if shutil.which("yay"):
            console.print("\n[cyan]=== AUR ===[/cyan]")
            subprocess.run(["yay", "-Ss", query])
    elif distro in ("ubuntu", "debian", "linuxmint", "pop"):
        subprocess.run(["apt", "search", query])
    elif distro in ("fedora", "rhel", "centos", "rocky"):
        subprocess.run(["dnf", "search", query])


def update_system():
    """Update system packages."""
    import subprocess
    import shutil
    distro = detect_distro()

    console.print("[cyan]Updating system...[/cyan]")

    if distro in ("arch", "koompi", "manjaro", "endeavouros"):
        if shutil.which("yay"):
            subprocess.run(["yay", "-Syu"])
        else:
            subprocess.run(["sudo", "pacman", "-Syu"])
    elif distro in ("ubuntu", "debian", "linuxmint", "pop"):
        subprocess.run(["sudo", "apt", "update"])
        subprocess.run(["sudo", "apt", "upgrade", "-y"])
    elif distro in ("fedora", "rhel", "centos", "rocky"):
        subprocess.run(["sudo", "dnf", "upgrade", "-y"])


def show_system_info():
    """Display system information."""
    import platform
    import os

    table = Table(title="System Information")
    table.add_column("Property", style="cyan")
    table.add_column("Value", style="green")

    table.add_row("OS", detect_distro().title())
    table.add_row("Kernel", platform.release())
    table.add_row("Architecture", platform.machine())
    table.add_row("Hostname", platform.node())
    table.add_row("Python", platform.python_version())
    table.add_row("CPU Cores", str(os.cpu_count()))

    try:
        with open("/proc/meminfo") as f:
            for line in f:
                if line.startswith("MemTotal"):
                    mem_kb = int(line.split()[1])
                    table.add_row("Memory", f"{mem_kb / 1024 / 1024:.1f} GB")
                    break
    except:
        pass

    console.print(table)


def show_help():
    """Show help information."""
    help_text = """
[bold cyan]KOOMPI CLI[/bold cyan] - AI-Powered Assistant

[yellow]Package Management:[/yellow]
  koompi install <pkg>      Install packages
  koompi remove <pkg>       Remove packages
  koompi search <query>     Search packages
  koompi update             Update system

[yellow]AI Assistant:[/yellow]
  koompi ask <question>     Ask a question
  koompi chat               Interactive chat
  koompi explain <cmd>      Explain a command

[yellow]System:[/yellow]
  koompi info               System information
  koompi disk               Disk usage
  koompi memory             Memory usage

[yellow]Setup:[/yellow]
  koompi setup              Configure API key
  koompi setup --check      Check API status

[dim]Natural language works too:[/dim]
  koompi help me install firefox
  koompi how do I check disk space
  koompi what's the Windows equivalent of grep
"""
    console.print(help_text)


if __name__ == "__main__":
    cli()
```

---

### 5. Package Configuration (`pyproject.toml`)

```toml
[build-system]
requires = ["hatchling"]
build-backend = "hatchling.build"

[project]
name = "koompi-cli"
version = "1.0.0"
description = "AI-powered command-line assistant for Linux"
readme = "README.md"
license = "MIT"
requires-python = ">=3.10"
authors = [
    { name = "KOOMPI", email = "dev@koompi.com" }
]
keywords = ["cli", "ai", "linux", "assistant", "gemini"]
classifiers = [
    "Development Status :: 4 - Beta",
    "Environment :: Console",
    "Intended Audience :: Developers",
    "Intended Audience :: System Administrators",
    "License :: OSI Approved :: MIT License",
    "Operating System :: POSIX :: Linux",
    "Programming Language :: Python :: 3",
    "Programming Language :: Python :: 3.10",
    "Programming Language :: Python :: 3.11",
    "Programming Language :: Python :: 3.12",
    "Topic :: System :: Systems Administration",
    "Topic :: Utilities",
]
dependencies = [
    "click>=8.0",
    "rich>=13.0",
]

[project.optional-dependencies]
ai = [
    "google-generativeai>=0.3.0",
]
voice = [
    "openai-whisper>=20231117",
    "sounddevice",
    "numpy",
]
dev = [
    "pytest",
    "pytest-asyncio",
    "black",
    "ruff",
]

[project.scripts]
koompi = "koompi_cli.main:cli"
koompi-cli = "koompi_cli.main:cli"

[project.urls]
Homepage = "https://koompi.com"
Repository = "https://github.com/koompi/koompi-ai-cli"
Documentation = "https://docs.koompi.com/cli"

[tool.hatch.build.targets.wheel]
packages = ["koompi_ai", "koompi_cli"]
```

---

## Build Tasks

### Phase 1: Project Setup
- [ ] Create new repository `koompi-ai-cli`
- [ ] Set up project structure
- [ ] Create `pyproject.toml`
- [ ] Set up basic CI/CD (GitHub Actions)

### Phase 2: AI Engine
- [ ] Implement `llm.py` with Gemini integration
- [ ] Implement `intent.py` for intent classification
- [ ] Build comprehensive `knowledge.py` offline database
- [ ] Add unit tests for AI components

### Phase 3: CLI Interface
- [ ] Implement `main.py` with Click
- [ ] Add all commands (install, remove, search, etc.)
- [ ] Implement natural language handler
- [ ] Add distro detection and multi-distro support
- [ ] Create Rich-based UI helpers

### Phase 4: Testing & Polish
- [ ] Test on Arch Linux
- [ ] Test on Ubuntu
- [ ] Test on Fedora
- [ ] Test offline mode
- [ ] Test with Gemini API
- [ ] Write documentation

### Phase 5: Release
- [ ] Publish to PyPI
- [ ] Create AUR package
- [ ] Write README.md
- [ ] Create release notes

---

## Success Criteria

1. **Install via pip:** `pip install koompi-cli` works
2. **Offline mode:** Works without API key
3. **Online mode:** Gemini enhances responses
4. **Multi-distro:** Works on Arch, Ubuntu, Fedora
5. **Natural language:** Understands conversational input
6. **Fast:** Responds quickly for common queries
7. **Helpful:** Provides accurate Linux guidance

---

## Test Commands

```bash
# Install locally for development
pip install -e ".[ai,dev]"

# Run tests
pytest

# Test CLI
koompi --version
koompi help
koompi install firefox
koompi ask "how do I check disk space"
koompi chat

# Test offline
unset GEMINI_API_KEY
koompi ask "how do I install packages on arch"

# Test online
export GEMINI_API_KEY="your-key"
koompi ask "explain the difference between ext4 and btrfs"
```

---

## Notes for Agent

1. **Standalone package** - No dependency on KOOMPI OS
2. **Offline-first** - Must work without internet
3. **Multi-distro** - Detect and support Arch, Ubuntu, Fedora
4. **Simple install** - `pip install koompi-cli` should just work
5. **Good UX** - Use Rich for beautiful terminal output
6. **Comprehensive knowledge** - Offline base should cover common tasks
