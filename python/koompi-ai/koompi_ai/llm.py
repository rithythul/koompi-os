"""AI integration using Google Gemini API with comprehensive OS knowledge.

KOOMPI AI is designed to be a complete computer education platform,
helping users learn about:
- Arch Linux and archlinux documentation (KOOMPI OS base)
- Linux in general (Ubuntu, Fedora, Debian, etc.)
- Windows (for cross-platform work)
- macOS (for cross-platform understanding)
- General computing concepts

Architecture:
┌─────────────────────────────────────────────────────────────┐
│                      User Query                              │
└──────────────────────────┬──────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│              Local Knowledge Search (FTS5)                   │
│       Search ArchWiki + KOOMPI docs (always runs)           │
└──────────────────────────┬──────────────────────────────────┘
                           │
           ┌───────────────┴───────────────┐
           ▼                               ▼
┌─────────────────────────────┐   ┌─────────────────────────────┐
│        ONLINE MODE          │   │       OFFLINE MODE          │
│                             │   │                             │
│  Knowledge Context          │   │  Knowledge + Templates      │
│       +                     │   │       =                     │
│  Gemini API                 │   │  Good answers from local DB │
│       =                     │   │                             │
│  Best quality answers       │   │  (No internet needed!)      │
└─────────────────────────────┘   └─────────────────────────────┘
"""

from dataclasses import dataclass
from typing import Optional, Dict, List, Tuple
import logging
import os

try:
    import google.generativeai as genai
    GENAI_AVAILABLE = True
except ImportError:
    GENAI_AVAILABLE = False

# Import local knowledge base
from .knowledge import get_knowledge_base, SearchResult, KnowledgeBase

logger = logging.getLogger(__name__)


# ═══════════════════════════════════════════════════════════════════════
# System Prompt - Comprehensive Computer Knowledge
# ═══════════════════════════════════════════════════════════════════════

SYSTEM_PROMPT = """You are KOOMPI Assistant, an expert AI built into KOOMPI OS (an Arch Linux-based immutable operating system designed for education).

## Your Expertise

You are a comprehensive computer expert with deep knowledge of:

### Linux (Primary Focus)
- **Arch Linux**: pacman, AUR, yay, PKGBUILD, mkinitcpio, systemd-boot, GRUB
- **KOOMPI OS specifics**: Btrfs snapshots, immutable system, koompi CLI, snapper
- **Package management**: pacman, yay, flatpak, snap, AppImage
- **System administration**: systemd, journalctl, networking, users/permissions
- **Shell**: bash, zsh, fish, scripting, pipelines, environment variables
- **Desktop environments**: KDE, GNOME, XFCE, Sway, Hyprland, i3
- **Other distros**: Ubuntu/Debian (apt), Fedora (dnf), openSUSE (zypper)

### Windows
- PowerShell and CMD commands
- Windows equivalents to Linux commands
- WSL (Windows Subsystem for Linux)
- File system differences (NTFS vs ext4/Btrfs)
- Registry, services, Task Manager equivalents
- Helping Linux users work with Windows when needed

### macOS
- Terminal and zsh (default shell)
- Homebrew package manager
- macOS equivalents to Linux commands
- File system (APFS)
- Helping users transition from macOS to Linux

### General Computing
- Programming (Python, Rust, JavaScript, C/C++, etc.)
- Networking (TCP/IP, DNS, SSH, firewalls)
- Security (encryption, permissions, best practices)
- Hardware (CPU, RAM, storage, drivers)
- Virtualization (VMs, containers, Docker)

## Response Guidelines

1. **Prioritize KOOMPI/Arch commands** but mention alternatives when helpful
2. **Explain the "why"** - help users understand, not just copy commands
3. **Safety first** - warn about dangerous commands (rm -rf, dd, etc.)
4. **Cross-platform awareness** - when asked about Windows/macOS, provide helpful answers
5. **Educational tone** - KOOMPI OS is for learning, explain concepts clearly
6. **Khmer support** - respond in Khmer if the user writes in Khmer

## KOOMPI-Specific Commands

- `koompi install <pkg>` - Install packages (uses pacman + yay)
- `koompi remove <pkg>` - Remove packages
- `koompi update` - Update system with automatic snapshot
- `koompi desktop <name>` - Install desktop environment (kde, gnome, xfce, etc.)
- `koompi snapshot create` - Create system snapshot
- `koompi snapshot list` - List snapshots
- `koompi rollback <id>` - Rollback to snapshot
- `koompi setup-yay` - Install AUR helper

## Immutability Notes

KOOMPI OS uses Btrfs with subvolumes for immutability:
- `@` - Root filesystem (snapshotted)
- `@home` - User data (preserved during rollback)
- `@snapshots` - Snapshot storage
- Rollback is instant and safe - just reboot after `koompi rollback`

Remember: You're helping users learn computers through KOOMPI OS. Be patient, thorough, and educational."""


# ═══════════════════════════════════════════════════════════════════════
# Offline Knowledge Base
# ═══════════════════════════════════════════════════════════════════════

OFFLINE_RESPONSES: Dict[str, str] = {
    # Greetings
    "greeting": "សួស្តី! Hello! I'm KOOMPI Assistant. I can help you with Linux, Windows, macOS, and general computing. What would you like to learn?",
    
    # Help
    "help": """I can help you with:

**KOOMPI OS / Arch Linux:**
• Installing packages: `koompi install firefox`
• System updates: `koompi update`
• Snapshots: `koompi snapshot create/list/rollback`
• Desktop setup: `koompi desktop kde`

**Linux Commands:**
• File operations, permissions, users
• System administration, services
• Shell scripting, automation

**Other Operating Systems:**
• Windows commands and equivalents
• macOS terminal and Homebrew
• Cross-platform workflows

**Programming & More:**
• Python, Rust, JavaScript, etc.
• Networking, security, hardware

Just ask naturally! For example:
• "How do I install KDE?"
• "What's the Windows equivalent of grep?"
• "How do I create a Python virtual environment?"
""",

    # Package management
    "install": """To install packages on KOOMPI OS:

```bash
# Using koompi CLI (recommended)
koompi install firefox

# Or directly with pacman (official repos)
sudo pacman -S firefox

# For AUR packages
yay -S spotify
```

The `koompi` command automatically creates a snapshot before installing.""",

    "remove": """To remove packages:

```bash
# Using koompi CLI
koompi remove firefox

# Or with pacman (removes package + unused dependencies)
sudo pacman -Rns firefox
```

A snapshot is created before removal for safety.""",

    "update": """To update KOOMPI OS:

```bash
# Using koompi CLI (creates snapshot first)
koompi update

# Or manually
sudo pacman -Syu

# If you have AUR packages
yay -Syu
```

If something breaks, rollback with: `koompi rollback <snapshot-id>`""",

    # Snapshots
    "snapshot": """KOOMPI OS uses Btrfs snapshots for system protection:

```bash
# Create a snapshot
koompi snapshot create "before experiment"

# List all snapshots
koompi snapshot list

# Rollback to a snapshot (requires reboot)
koompi rollback <snapshot-id>
```

Snapshots are instant and space-efficient (copy-on-write).""",

    "rollback": """To rollback your system:

```bash
# List available snapshots
koompi snapshot list

# Rollback to a specific snapshot
koompi rollback <snapshot-id>

# Reboot to complete
sudo reboot
```

Your `/home` data is preserved during rollback.""",

    # System info
    "disk": """Check disk space:

```bash
# Human-readable disk usage
df -h

# Directory sizes
du -sh /var/cache/pacman/*

# Btrfs-specific
sudo btrfs filesystem usage /
```""",

    "memory": """Check memory usage:

```bash
# Simple overview
free -h

# Detailed with processes
htop

# Or
top
```""",

    # Cross-platform
    "windows": """**Windows equivalents for Linux users:**

| Linux | Windows | Description |
|-------|---------|-------------|
| `ls` | `dir` | List files |
| `cat` | `type` | Show file contents |
| `grep` | `findstr` | Search text |
| `rm` | `del` | Delete file |
| `cp` | `copy` | Copy file |
| `mv` | `move` | Move file |
| `man` | `help` or `/?` | Help |
| `sudo` | Run as Admin | Elevated privileges |
| `apt/pacman` | `winget` | Package manager |
| `systemctl` | `sc` or Services | Service management |

PowerShell is more similar to Linux shells than CMD.""",

    "macos": """**macOS for Linux users:**

macOS uses zsh by default and has many Unix commands:

```bash
# Package manager (install Homebrew first)
brew install firefox

# Most Linux commands work
ls, cat, grep, find, etc.

# Key differences
- No apt/pacman, use Homebrew
- No systemd, use launchctl
- File system is APFS (not ext4)
- Root is /System (protected)
```

Many Linux users feel at home on macOS terminal!""",

    # Programming
    "python": """**Python on KOOMPI OS:**

```bash
# Install Python (usually pre-installed)
koompi install python python-pip

# Create virtual environment
python -m venv myproject
source myproject/bin/activate

# Install packages
pip install requests numpy

# Run script
python script.py
```""",

    "git": """**Git basics:**

```bash
# Clone a repository
git clone https://github.com/user/repo.git

# Basic workflow
git add .
git commit -m "message"
git push

# Check status
git status
git log --oneline
```""",

    # Offline message
    "offline": "I'm currently in offline mode with limited knowledge. For detailed help, please check your internet connection and API key. Basic commands still work!",
}


@dataclass
class AIResponse:
    """Response from AI model."""
    text: str
    confidence: float
    source: str  # "gemini", "gemini+knowledge", "knowledge", "offline", "none"
    is_offline: bool = False
    knowledge_used: List[str] = None  # Titles of articles used for context
    
    def __post_init__(self):
        if self.knowledge_used is None:
            self.knowledge_used = []


class GeminiLLM:
    """Cloud LLM using Google Gemini API with local knowledge enhancement."""

    def __init__(self, api_key: Optional[str] = None):
        self.api_key = api_key or os.environ.get("GEMINI_API_KEY") or os.environ.get("GOOGLE_API_KEY")
        self.model = None
        self._is_offline = False
        self._kb: Optional[KnowledgeBase] = None
        
        if not GENAI_AVAILABLE:
            logger.warning("google-generativeai not installed - offline mode only")
            self._is_offline = True
        elif self.api_key:
            try:
                genai.configure(api_key=self.api_key)
                self.model = genai.GenerativeModel(
                    'gemini-1.5-flash',
                    system_instruction=SYSTEM_PROMPT
                )
            except Exception as e:
                logger.error(f"Failed to configure Gemini: {e}")
                self._is_offline = True
        else:
            logger.warning("No API key found - running in offline mode")
            self._is_offline = True
        
        # Initialize knowledge base
        try:
            self._kb = get_knowledge_base()
            stats = self._kb.get_stats()
            logger.info(f"Knowledge base loaded: {stats['total_articles']} articles")
        except Exception as e:
            logger.error(f"Failed to load knowledge base: {e}")

    @property
    def is_offline(self) -> bool:
        """Check if running in offline mode (no API)."""
        return self._is_offline or self.model is None
    
    @property
    def has_knowledge(self) -> bool:
        """Check if knowledge base is available."""
        return self._kb is not None

    def _get_offline_response(self, prompt: str) -> Optional[str]:
        """Get offline response based on prompt keywords."""
        prompt_lower = prompt.lower()
        
        # Check for greetings
        greetings = ["hello", "hi", "hey", "សួស្តី", "good morning", "good afternoon"]
        if any(g in prompt_lower for g in greetings):
            return OFFLINE_RESPONSES["greeting"]
        
        # Check for help requests
        if prompt_lower.strip() in ("help", "?", "what can you do"):
            return OFFLINE_RESPONSES["help"]
        
        # Match against known topics
        topic_keywords = {
            "install": ["install", "add", "get", "setup", "ដំឡើង"],
            "remove": ["remove", "uninstall", "delete", "លុប"],
            "update": ["update", "upgrade", "ធ្វើបច្ចុប្បន្នភាព"],
            "snapshot": ["snapshot", "backup"],
            "rollback": ["rollback", "restore", "revert"],
            "disk": ["disk", "space", "storage", "df"],
            "memory": ["memory", "ram", "free"],
            "windows": ["windows", "cmd", "powershell", "winget"],
            "macos": ["macos", "mac", "homebrew", "brew"],
            "python": ["python", "pip", "venv"],
            "git": ["git", "clone", "commit", "push"],
        }
        
        for topic, keywords in topic_keywords.items():
            if any(kw in prompt_lower for kw in keywords):
                return OFFLINE_RESPONSES.get(topic)
        
        return None

    def _search_knowledge(self, query: str, limit: int = 3) -> Tuple[str, List[str]]:
        """Search knowledge base and build context.
        
        Returns:
            Tuple of (context_string, list_of_article_titles)
        """
        if not self._kb:
            return "", []
        
        try:
            context, results = self._kb.build_context(query, max_tokens=2000)
            titles = [r.article.title for r in results]
            return context, titles
        except Exception as e:
            logger.error(f"Knowledge search failed: {e}")
            return "", []

    def _generate_offline_from_knowledge(self, query: str, context: str, titles: List[str]) -> AIResponse:
        """Generate response from knowledge base when offline."""
        if not context:
            # No knowledge found, use basic offline response
            offline_resp = self._get_offline_response(query)
            if offline_resp:
                return AIResponse(
                    text=offline_resp,
                    confidence=0.6,
                    source="offline",
                    is_offline=True
                )
            return AIResponse(
                text=OFFLINE_RESPONSES["offline"],
                confidence=0.3,
                source="offline",
                is_offline=True
            )
        
        # Build response from knowledge
        # Extract the most relevant content
        response_parts = [
            f"Based on my knowledge base ({', '.join(titles[:3])}):\n"
        ]
        
        # Add the context (already formatted from build_context)
        response_parts.append(context)
        
        # Add note about offline mode
        response_parts.append("\n---\n*📚 Answer from local knowledge base (offline mode)*")
        
        return AIResponse(
            text="\n".join(response_parts),
            confidence=0.75,
            source="knowledge",
            is_offline=True,
            knowledge_used=titles
        )

    async def generate(self, prompt: str, use_knowledge: bool = True) -> AIResponse:
        """Generate response using Gemini with knowledge enhancement.
        
        Args:
            prompt: User's question
            use_knowledge: Whether to search local knowledge base
            
        Returns:
            AIResponse with text, confidence, and metadata
        """
        knowledge_context = ""
        knowledge_titles = []
        
        # Step 1: Search local knowledge base (always, for context)
        if use_knowledge and self._kb:
            knowledge_context, knowledge_titles = self._search_knowledge(prompt)
            if knowledge_titles:
                logger.info(f"Found relevant articles: {knowledge_titles}")
        
        # Step 2: If offline, generate from knowledge or fallback
        if self.is_offline:
            return self._generate_offline_from_knowledge(prompt, knowledge_context, knowledge_titles)
        
        # Step 3: Online mode - use Gemini with knowledge context
        try:
            # Build enhanced prompt with knowledge context
            if knowledge_context:
                enhanced_prompt = f"""User Question: {prompt}

{knowledge_context}

Please answer the user's question. Use the documentation above as reference if relevant, but also apply your broader knowledge. Be helpful and educational."""
            else:
                enhanced_prompt = prompt
            
            response = self.model.generate_content(enhanced_prompt)
            
            return AIResponse(
                text=response.text,
                confidence=0.95,
                source="gemini+knowledge" if knowledge_titles else "gemini",
                is_offline=False,
                knowledge_used=knowledge_titles
            )
            
        except Exception as e:
            logger.error(f"Gemini generation failed: {e}")
            
            # Fallback to knowledge-based response
            if knowledge_context:
                return self._generate_offline_from_knowledge(prompt, knowledge_context, knowledge_titles)
            
            # Final fallback to basic offline response
            offline_response = self._get_offline_response(prompt)
            if offline_response:
                return AIResponse(
                    text=offline_response + "\n\n*[Offline response - API unavailable]*",
                    confidence=0.5,
                    source="offline",
                    is_offline=True
                )
            
            return AIResponse(
                text=f"I couldn't connect to the AI service. Error: {e}\n\nPlease check your internet connection and API key.",
                confidence=0.0,
                source="none",
                is_offline=True
            )


# Global instance
_llm: Optional[GeminiLLM] = None


async def query(prompt: str, use_knowledge: bool = True) -> AIResponse:
    """Query AI with comprehensive knowledge.

    Args:
        prompt: The user's question
        use_knowledge: Whether to search local knowledge base for context

    Returns:
        AIResponse with text and metadata
    """
    global _llm

    if _llm is None:
        _llm = GeminiLLM()

    return await _llm.generate(prompt, use_knowledge=use_knowledge)


def search_knowledge(query: str, limit: int = 5) -> List[SearchResult]:
    """Search the local knowledge base directly.
    
    Args:
        query: Search query
        limit: Maximum results
        
    Returns:
        List of SearchResult objects
    """
    kb = get_knowledge_base()
    return kb.search(query, limit=limit)


def get_knowledge_stats() -> Dict:
    """Get knowledge base statistics."""
    kb = get_knowledge_base()
    return kb.get_stats()

