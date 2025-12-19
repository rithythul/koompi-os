"""Local Knowledge Base using ArchWiki and custom documentation.

This module provides offline-capable knowledge retrieval using:
- SQLite with FTS5 (Full-Text Search) for fast queries
- Pre-embedded ArchWiki articles (most useful ones)
- Custom KOOMPI documentation
- RAG (Retrieval-Augmented Generation) context building

Architecture:
┌─────────────────────────────────────────────────────────────┐
│                      User Query                             │
└──────────────────────────┬──────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                  Knowledge Search (FTS5)                    │
│           Search local wiki + KOOMPI docs                   │
└──────────────────────────┬──────────────────────────────────┘
                           │
           ┌───────────────┴───────────────┐
           ▼                               ▼
┌─────────────────────┐         ┌─────────────────────┐
│   ONLINE MODE       │         │   OFFLINE MODE      │
│                     │         │                     │
│ Context + Gemini    │         │ Knowledge + Template│
│ = Best answers      │         │ = Good answers      │
└─────────────────────┘         └─────────────────────┘
"""

import sqlite3
import os
import logging
import json
import re
from pathlib import Path
from dataclasses import dataclass
from typing import List, Optional, Dict, Tuple
from datetime import datetime

logger = logging.getLogger(__name__)

# Default location for knowledge database
DEFAULT_DB_PATH = Path.home() / ".local" / "share" / "koompi" / "knowledge.db"


@dataclass
class Article:
    """A knowledge base article."""
    id: int
    title: str
    content: str
    category: str
    source: str  # "archwiki", "koompi", "custom"
    url: Optional[str] = None
    last_updated: Optional[str] = None


@dataclass
class SearchResult:
    """Search result with relevance score."""
    article: Article
    score: float
    snippet: str  # Highlighted excerpt


class KnowledgeBase:
    """Local knowledge base with SQLite FTS5."""

    def __init__(self, db_path: Optional[Path] = None):
        """Initialize knowledge base.
        
        Args:
            db_path: Path to SQLite database. Uses default if None.
        """
        self.db_path = db_path or DEFAULT_DB_PATH
        self.db_path.parent.mkdir(parents=True, exist_ok=True)
        self._init_db()

    def _init_db(self):
        """Initialize database schema."""
        with sqlite3.connect(self.db_path) as conn:
            # Main articles table
            conn.execute("""
                CREATE TABLE IF NOT EXISTS articles (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    title TEXT NOT NULL,
                    content TEXT NOT NULL,
                    category TEXT DEFAULT 'general',
                    source TEXT DEFAULT 'custom',
                    url TEXT,
                    last_updated TEXT,
                    UNIQUE(title, source)
                )
            """)
            
            # FTS5 virtual table for full-text search
            conn.execute("""
                CREATE VIRTUAL TABLE IF NOT EXISTS articles_fts USING fts5(
                    title,
                    content,
                    category,
                    content='articles',
                    content_rowid='id',
                    tokenize='porter unicode61'
                )
            """)
            
            # Triggers to keep FTS in sync
            conn.execute("""
                CREATE TRIGGER IF NOT EXISTS articles_ai AFTER INSERT ON articles BEGIN
                    INSERT INTO articles_fts(rowid, title, content, category)
                    VALUES (new.id, new.title, new.content, new.category);
                END
            """)
            
            conn.execute("""
                CREATE TRIGGER IF NOT EXISTS articles_ad AFTER DELETE ON articles BEGIN
                    INSERT INTO articles_fts(articles_fts, rowid, title, content, category)
                    VALUES('delete', old.id, old.title, old.content, old.category);
                END
            """)
            
            conn.execute("""
                CREATE TRIGGER IF NOT EXISTS articles_au AFTER UPDATE ON articles BEGIN
                    INSERT INTO articles_fts(articles_fts, rowid, title, content, category)
                    VALUES('delete', old.id, old.title, old.content, old.category);
                    INSERT INTO articles_fts(rowid, title, content, category)
                    VALUES (new.id, new.title, new.content, new.category);
                END
            """)
            
            # Metadata table
            conn.execute("""
                CREATE TABLE IF NOT EXISTS metadata (
                    key TEXT PRIMARY KEY,
                    value TEXT
                )
            """)
            
            conn.commit()

    def add_article(self, title: str, content: str, category: str = "general",
                    source: str = "custom", url: Optional[str] = None) -> int:
        """Add or update an article.
        
        Args:
            title: Article title
            content: Full text content
            category: Category (e.g., "package_management", "system")
            source: Source ("archwiki", "koompi", "custom")
            url: Optional URL reference
            
        Returns:
            Article ID
        """
        with sqlite3.connect(self.db_path) as conn:
            cursor = conn.execute("""
                INSERT INTO articles (title, content, category, source, url, last_updated)
                VALUES (?, ?, ?, ?, ?, ?)
                ON CONFLICT(title, source) DO UPDATE SET
                    content = excluded.content,
                    category = excluded.category,
                    url = excluded.url,
                    last_updated = excluded.last_updated
                RETURNING id
            """, (title, content, category, source, url, datetime.now().isoformat()))
            result = cursor.fetchone()
            conn.commit()
            return result[0] if result else -1

    def search(self, query: str, limit: int = 5, category: Optional[str] = None) -> List[SearchResult]:
        """Search knowledge base using FTS5.
        
        Args:
            query: Search query (supports FTS5 syntax)
            limit: Maximum results
            category: Optional category filter
            
        Returns:
            List of SearchResult ordered by relevance
        """
        # Clean and prepare query for FTS5
        # Convert natural language to FTS-friendly format
        fts_query = self._prepare_query(query)
        
        with sqlite3.connect(self.db_path) as conn:
            conn.row_factory = sqlite3.Row
            
            if category:
                sql = """
                    SELECT 
                        a.id, a.title, a.content, a.category, a.source, a.url, a.last_updated,
                        bm25(articles_fts) as score,
                        snippet(articles_fts, 1, '<mark>', '</mark>', '...', 64) as snippet
                    FROM articles_fts
                    JOIN articles a ON articles_fts.rowid = a.id
                    WHERE articles_fts MATCH ? AND a.category = ?
                    ORDER BY score
                    LIMIT ?
                """
                params = (fts_query, category, limit)
            else:
                sql = """
                    SELECT 
                        a.id, a.title, a.content, a.category, a.source, a.url, a.last_updated,
                        bm25(articles_fts) as score,
                        snippet(articles_fts, 1, '<mark>', '</mark>', '...', 64) as snippet
                    FROM articles_fts
                    JOIN articles a ON articles_fts.rowid = a.id
                    WHERE articles_fts MATCH ?
                    ORDER BY score
                    LIMIT ?
                """
                params = (fts_query, limit)
            
            try:
                rows = conn.execute(sql, params).fetchall()
            except sqlite3.OperationalError as e:
                logger.warning(f"FTS search failed, falling back to LIKE: {e}")
                # Fallback to simple LIKE search
                return self._fallback_search(query, limit, category)
            
            results = []
            for row in rows:
                article = Article(
                    id=row['id'],
                    title=row['title'],
                    content=row['content'],
                    category=row['category'],
                    source=row['source'],
                    url=row['url'],
                    last_updated=row['last_updated']
                )
                results.append(SearchResult(
                    article=article,
                    score=abs(row['score']),  # bm25 returns negative scores
                    snippet=row['snippet']
                ))
            
            return results

    def _prepare_query(self, query: str) -> str:
        """Convert natural language query to FTS5 query."""
        # Remove special characters that confuse FTS5
        query = re.sub(r'[^\w\s]', ' ', query)
        
        # Split into words
        words = query.lower().split()
        
        # Remove very common words (stop words)
        stop_words = {'the', 'a', 'an', 'is', 'are', 'was', 'were', 'how', 'do', 'i', 'to', 'what', 'can', 'you'}
        words = [w for w in words if w not in stop_words and len(w) > 1]
        
        if not words:
            return query.lower()
        
        # Use OR for broader matching, with prefix matching
        return ' OR '.join(f'"{w}"*' for w in words[:10])  # Limit to 10 terms

    def _fallback_search(self, query: str, limit: int, category: Optional[str]) -> List[SearchResult]:
        """Fallback search using LIKE when FTS fails."""
        with sqlite3.connect(self.db_path) as conn:
            conn.row_factory = sqlite3.Row
            
            words = query.lower().split()[:5]  # Top 5 words
            like_conditions = ' OR '.join(['(title LIKE ? OR content LIKE ?)'] * len(words))
            params = []
            for word in words:
                params.extend([f'%{word}%', f'%{word}%'])
            
            sql = f"""
                SELECT id, title, content, category, source, url, last_updated
                FROM articles
                WHERE {like_conditions}
            """
            if category:
                sql += " AND category = ?"
                params.append(category)
            sql += f" LIMIT {limit}"
            
            rows = conn.execute(sql, params).fetchall()
            
            results = []
            for row in rows:
                article = Article(
                    id=row['id'],
                    title=row['title'],
                    content=row['content'][:500] + "...",
                    category=row['category'],
                    source=row['source'],
                    url=row['url'],
                    last_updated=row['last_updated']
                )
                # Create simple snippet
                content_lower = row['content'].lower()
                for word in words:
                    idx = content_lower.find(word)
                    if idx > 0:
                        start = max(0, idx - 50)
                        end = min(len(row['content']), idx + 100)
                        snippet = "..." + row['content'][start:end] + "..."
                        break
                else:
                    snippet = row['content'][:150] + "..."
                
                results.append(SearchResult(
                    article=article,
                    score=1.0,
                    snippet=snippet
                ))
            
            return results

    def get_article(self, article_id: int) -> Optional[Article]:
        """Get article by ID."""
        with sqlite3.connect(self.db_path) as conn:
            conn.row_factory = sqlite3.Row
            row = conn.execute(
                "SELECT * FROM articles WHERE id = ?",
                (article_id,)
            ).fetchone()
            
            if row:
                return Article(**dict(row))
            return None

    def get_stats(self) -> Dict:
        """Get knowledge base statistics."""
        with sqlite3.connect(self.db_path) as conn:
            total = conn.execute("SELECT COUNT(*) FROM articles").fetchone()[0]
            by_source = dict(conn.execute(
                "SELECT source, COUNT(*) FROM articles GROUP BY source"
            ).fetchall())
            by_category = dict(conn.execute(
                "SELECT category, COUNT(*) FROM articles GROUP BY category"
            ).fetchall())
            
            return {
                "total_articles": total,
                "by_source": by_source,
                "by_category": by_category,
                "db_path": str(self.db_path),
                "db_size_mb": self.db_path.stat().st_size / (1024 * 1024) if self.db_path.exists() else 0
            }

    def build_context(self, query: str, max_tokens: int = 2000) -> Tuple[str, List[SearchResult]]:
        """Build RAG context from search results.
        
        Args:
            query: User query
            max_tokens: Approximate max tokens for context
            
        Returns:
            Tuple of (context_string, search_results)
        """
        results = self.search(query, limit=5)
        
        if not results:
            return "", []
        
        # Build context string
        context_parts = ["## Relevant Documentation\n"]
        char_count = 0
        max_chars = max_tokens * 4  # Rough estimate: 1 token ≈ 4 chars
        
        for result in results:
            # Add title and source
            entry = f"\n### {result.article.title}"
            if result.article.source == "archwiki":
                entry += f" (ArchWiki)"
            entry += "\n"
            
            # Add content (truncated if needed)
            remaining = max_chars - char_count - len(entry)
            if remaining <= 0:
                break
            
            content = result.article.content
            if len(content) > remaining:
                content = content[:remaining] + "..."
            
            entry += content + "\n"
            context_parts.append(entry)
            char_count += len(entry)
            
            if char_count >= max_chars:
                break
        
        return "\n".join(context_parts), results


# ═══════════════════════════════════════════════════════════════════════
# Core ArchWiki Articles (Embedded in Code)
# ═══════════════════════════════════════════════════════════════════════

CORE_ARCHWIKI_ARTICLES = [
    {
        "title": "Pacman",
        "category": "package_management",
        "url": "https://wiki.archlinux.org/title/Pacman",
        "content": """Pacman is the package manager for Arch Linux. It combines a simple binary package format with an easy-to-use build system.

## Common Operations

### Installing packages
```bash
# Install a single package or group
pacman -S package_name

# Install multiple packages
pacman -S package1 package2

# Install with dependencies question
pacman -S --needed package_name
```

### Removing packages
```bash
# Remove a package
pacman -R package_name

# Remove package and its dependencies not required by others
pacman -Rs package_name

# Remove package, dependencies, and config files
pacman -Rns package_name
```

### Upgrading packages
```bash
# Sync and upgrade all packages
pacman -Syu

# Force refresh and upgrade (use after changing mirrors)
pacman -Syyu
```

### Querying packages
```bash
# Search for packages
pacman -Ss keyword

# Show package info
pacman -Si package_name

# List installed packages
pacman -Q

# List explicitly installed packages
pacman -Qe

# Check which package owns a file
pacman -Qo /path/to/file
```

### Cleaning cache
```bash
# Remove old package versions
pacman -Sc

# Remove all cached packages
pacman -Scc

# Use paccache (recommended)
paccache -r
```

## Configuration
The main configuration file is `/etc/pacman.conf`. Key options:
- `Color` - Enable colored output
- `ParallelDownloads` - Number of simultaneous downloads (default 5)
- `ILoveCandy` - Easter egg: changes progress bar

## Mirrors
Mirrors are configured in `/etc/pacman.d/mirrorlist`. Use `reflector` to automatically select fastest mirrors:
```bash
sudo reflector --country 'United States' --latest 10 --sort rate --save /etc/pacman.d/mirrorlist
```"""
    },
    {
        "title": "AUR (Arch User Repository)",
        "category": "package_management",
        "url": "https://wiki.archlinux.org/title/AUR",
        "content": """The Arch User Repository (AUR) is a community-driven repository for Arch Linux users. It contains package descriptions (PKGBUILDs) that allow you to compile packages from source.

## Using AUR Helpers

### yay (Recommended for KOOMPI OS)
```bash
# Install yay first
git clone https://aur.archlinux.org/yay-bin.git
cd yay-bin
makepkg -si

# Then use like pacman
yay -S package_name
yay -Syu  # Update everything including AUR
```

### paru (Alternative)
```bash
# Similar to yay
paru -S package_name
```

## Manual Installation
```bash
# 1. Clone the AUR package
git clone https://aur.archlinux.org/package_name.git
cd package_name

# 2. Review the PKGBUILD (IMPORTANT!)
less PKGBUILD

# 3. Build and install
makepkg -si
```

## Safety
- Always review PKGBUILD before installing
- AUR packages are user-submitted, not officially supported
- Check comments on the AUR page for issues
- Use AUR helpers that show diffs (like yay with `--diffmenu`)

## Updating AUR Packages
```bash
# With yay
yay -Sua  # Only AUR packages
yay -Syu  # All packages including AUR

# Check for orphans
yay -Yc
```"""
    },
    {
        "title": "Systemd",
        "category": "system",
        "url": "https://wiki.archlinux.org/title/Systemd",
        "content": """systemd is the init system and service manager for Arch Linux.

## Basic Service Management

### systemctl commands
```bash
# Start a service
sudo systemctl start service_name

# Stop a service
sudo systemctl stop service_name

# Restart a service
sudo systemctl restart service_name

# Enable at boot
sudo systemctl enable service_name

# Disable at boot
sudo systemctl disable service_name

# Check status
systemctl status service_name

# Enable and start in one command
sudo systemctl enable --now service_name
```

### Listing services
```bash
# List running services
systemctl list-units --type=service

# List all services
systemctl list-units --type=service --all

# List enabled services
systemctl list-unit-files --type=service | grep enabled
```

## Journalctl (Logs)
```bash
# View all logs
journalctl

# Follow logs in real-time
journalctl -f

# Logs for a specific service
journalctl -u service_name

# Logs since boot
journalctl -b

# Logs from previous boot
journalctl -b -1

# Show only errors
journalctl -p err

# Logs with timestamps
journalctl --since "1 hour ago"
```

## Targets (Runlevels)
```bash
# Check current target
systemctl get-default

# Set graphical target (with display manager)
sudo systemctl set-default graphical.target

# Set multi-user (text mode)
sudo systemctl set-default multi-user.target
```

## Timers (Cron replacement)
```bash
# List active timers
systemctl list-timers

# Enable a timer
sudo systemctl enable --now timer_name.timer
```"""
    },
    {
        "title": "Btrfs",
        "category": "filesystem",
        "url": "https://wiki.archlinux.org/title/Btrfs",
        "content": """Btrfs (B-tree file system) is a modern copy-on-write (CoW) filesystem for Linux. KOOMPI OS uses Btrfs for its snapshot and rollback capabilities.

## Key Features
- Snapshots (instant, space-efficient)
- Subvolumes (like partitions but flexible)
- Compression (zstd, lzo, zlib)
- RAID support (built-in)
- Online defragmentation

## Subvolumes

### Creating subvolumes
```bash
# Create a subvolume
sudo btrfs subvolume create /mnt/@new_subvol

# List subvolumes
sudo btrfs subvolume list /

# Delete subvolume
sudo btrfs subvolume delete /mnt/@old_subvol
```

### KOOMPI OS Subvolume Layout
- `@` - Root filesystem
- `@home` - User home directories
- `@snapshots` - Snapshot storage
- `@var_log` - Log files

## Snapshots

### Creating snapshots
```bash
# Read-only snapshot (recommended for backups)
sudo btrfs subvolume snapshot -r /source /dest/snapshot_name

# Writable snapshot
sudo btrfs subvolume snapshot /source /dest/snapshot_name
```

### Using snapper (KOOMPI OS default)
```bash
# Create manual snapshot
sudo snapper create -d "description"

# List snapshots
sudo snapper list

# Compare snapshots
sudo snapper diff 1..2

# Rollback (with grub-btrfs)
sudo snapper rollback
```

## Maintenance

### Check filesystem
```bash
# Check and report errors
sudo btrfs check /dev/sda2

# Scrub (online data integrity check)
sudo btrfs scrub start /
sudo btrfs scrub status /
```

### Balance
```bash
# Rebalance data (may take time)
sudo btrfs balance start /

# Check balance status
sudo btrfs balance status /
```

### Compression
```bash
# Mount with compression
mount -o compress=zstd /dev/sda2 /mnt

# Compress existing files
sudo btrfs filesystem defragment -r -czstd /
```

### Space usage
```bash
# Detailed usage
sudo btrfs filesystem usage /

# Show file system info
sudo btrfs filesystem show /
```"""
    },
    {
        "title": "Network Configuration",
        "category": "networking",
        "url": "https://wiki.archlinux.org/title/Network_configuration",
        "content": """Network configuration in Arch Linux and KOOMPI OS.

## NetworkManager (Default in KOOMPI OS)

### nmcli commands
```bash
# Show connections
nmcli connection show

# Show WiFi networks
nmcli device wifi list

# Connect to WiFi
nmcli device wifi connect "SSID" password "password"

# Disconnect
nmcli connection down "connection_name"

# Delete a connection
nmcli connection delete "connection_name"

# Show device status
nmcli device status
```

### nmtui (Text UI)
```bash
# Launch text-based interface
nmtui
```

## systemd-networkd (Alternative)

### Configuration files
Create `/etc/systemd/network/20-wired.network`:
```ini
[Match]
Name=en*

[Network]
DHCP=yes
```

### Enable
```bash
sudo systemctl enable --now systemd-networkd
sudo systemctl enable --now systemd-resolved
```

## Static IP Configuration

### With NetworkManager
```bash
nmcli connection modify "Wired" ipv4.addresses "192.168.1.100/24"
nmcli connection modify "Wired" ipv4.gateway "192.168.1.1"
nmcli connection modify "Wired" ipv4.dns "8.8.8.8"
nmcli connection modify "Wired" ipv4.method manual
```

## Common Tools
```bash
# Show IP addresses
ip addr
ip a

# Show routing table
ip route

# DNS lookup
nslookup google.com
dig google.com

# Test connectivity
ping google.com
ping -c 4 8.8.8.8

# Check open ports
ss -tulpn
```

## Troubleshooting
```bash
# Restart NetworkManager
sudo systemctl restart NetworkManager

# Check logs
journalctl -u NetworkManager

# Release/renew DHCP
sudo dhclient -r
sudo dhclient
```"""
    },
    {
        "title": "Users and Groups",
        "category": "system",
        "url": "https://wiki.archlinux.org/title/Users_and_groups",
        "content": """User and group management in Arch Linux.

## User Management

### Creating users
```bash
# Create user with home directory
sudo useradd -m username

# Create with specific shell
sudo useradd -m -s /bin/zsh username

# Create and add to groups
sudo useradd -m -G wheel,audio,video username

# Set password
sudo passwd username
```

### Modifying users
```bash
# Add user to group
sudo usermod -aG groupname username

# Change shell
sudo usermod -s /bin/zsh username

# Change home directory
sudo usermod -d /new/home username

# Lock/unlock user
sudo usermod -L username
sudo usermod -U username
```

### Deleting users
```bash
# Remove user
sudo userdel username

# Remove user and home directory
sudo userdel -r username
```

## Group Management

### Creating groups
```bash
sudo groupadd groupname
```

### Important groups
- `wheel` - Administrator access (sudo)
- `audio` - Sound device access
- `video` - Video device access
- `storage` - Access to removable drives
- `network` - NetworkManager control
- `docker` - Docker daemon access

## Sudo Configuration

### Edit sudoers
```bash
# Always use visudo!
sudo EDITOR=nano visudo
```

### Common configurations
```
# Allow wheel group full access
%wheel ALL=(ALL:ALL) ALL

# Allow without password (not recommended)
%wheel ALL=(ALL:ALL) NOPASSWD: ALL

# Allow specific command
username ALL=(ALL) /usr/bin/pacman
```

## Checking Users/Groups
```bash
# Current user
whoami

# User details
id username

# All groups user belongs to
groups username

# List all users
cat /etc/passwd

# List all groups
cat /etc/group
```"""
    },
    {
        "title": "Desktop Environments",
        "category": "desktop",
        "url": "https://wiki.archlinux.org/title/Desktop_environment",
        "content": """Desktop environments available for Arch Linux and KOOMPI OS.

## KDE Plasma (Recommended)
Full-featured, customizable desktop.

```bash
# Install KDE
koompi desktop kde
# Or manually
sudo pacman -S plasma kde-applications sddm
sudo systemctl enable sddm
```

## GNOME
Modern, streamlined desktop.

```bash
koompi desktop gnome
# Or manually
sudo pacman -S gnome gnome-extra gdm
sudo systemctl enable gdm
```

## XFCE
Lightweight and fast.

```bash
koompi desktop xfce
# Or manually
sudo pacman -S xfce4 xfce4-goodies lightdm lightdm-gtk-greeter
sudo systemctl enable lightdm
```

## Window Managers (Minimal)

### Hyprland (Wayland tiling)
```bash
koompi desktop hyprland
# Or manually
sudo pacman -S hyprland waybar kitty
```

### Sway (Wayland i3-like)
```bash
koompi desktop sway
# Or manually
sudo pacman -S sway swaybar swayidle
```

### i3 (X11 tiling)
```bash
koompi desktop i3
# Or manually
sudo pacman -S i3-wm i3status dmenu
```

## Display Managers

### SDDM (KDE default)
```bash
sudo pacman -S sddm
sudo systemctl enable sddm
```

### GDM (GNOME default)
```bash
sudo pacman -S gdm
sudo systemctl enable gdm
```

### LightDM (Lightweight)
```bash
sudo pacman -S lightdm lightdm-gtk-greeter
sudo systemctl enable lightdm
```

## Starting Without Display Manager
```bash
# Add to ~/.xinitrc or ~/.xprofile
exec startplasma-x11  # KDE
exec gnome-session    # GNOME
exec startxfce4       # XFCE
exec i3               # i3
```"""
    },
    {
        "title": "Installation Guide",
        "category": "installation",
        "url": "https://wiki.archlinux.org/title/Installation_guide",
        "content": """Arch Linux installation overview. KOOMPI OS simplifies this with Calamares installer.

## Pre-installation

### Boot the live environment
1. Download ISO from archlinux.org
2. Write to USB: `dd if=archlinux.iso of=/dev/sdX bs=4M`
3. Boot from USB

### Connect to internet
```bash
# WiFi
iwctl
device list
station wlan0 scan
station wlan0 get-networks
station wlan0 connect "SSID"

# Test connection
ping archlinux.org
```

## Disk Partitioning

### Using fdisk
```bash
fdisk /dev/sda

# Create partitions:
# - EFI: 512MB (type: EFI System)
# - Swap: RAM size (type: Linux swap)
# - Root: remainder (type: Linux filesystem)
```

### Format partitions
```bash
mkfs.fat -F32 /dev/sda1      # EFI
mkswap /dev/sda2             # Swap
mkfs.btrfs /dev/sda3         # Root (Btrfs for KOOMPI)
```

## Installation

### Mount and create subvolumes (Btrfs)
```bash
mount /dev/sda3 /mnt
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
umount /mnt

mount -o subvol=@ /dev/sda3 /mnt
mkdir -p /mnt/{boot/efi,home}
mount -o subvol=@home /dev/sda3 /mnt/home
mount /dev/sda1 /mnt/boot/efi
swapon /dev/sda2
```

### Install base system
```bash
pacstrap /mnt base linux linux-firmware btrfs-progs
genfstab -U /mnt >> /mnt/etc/fstab
arch-chroot /mnt
```

### Configure system
```bash
# Timezone
ln -sf /usr/share/zoneinfo/Asia/Phnom_Penh /etc/localtime
hwclock --systohc

# Locale
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

# Hostname
echo "koompi" > /etc/hostname

# Root password
passwd

# Create user
useradd -m -G wheel -s /bin/bash username
passwd username
```

### Bootloader
```bash
pacman -S grub efibootmgr
grub-install --target=x86_64-efi --efi-directory=/boot/efi
grub-mkconfig -o /boot/grub/grub.cfg
```"""
    },
    {
        "title": "SSH",
        "category": "networking",
        "url": "https://wiki.archlinux.org/title/SSH",
        "content": """SSH (Secure Shell) for remote access.

## Installation
```bash
sudo pacman -S openssh
```

## Server Setup

### Enable SSH server
```bash
sudo systemctl enable --now sshd
```

### Configuration (/etc/ssh/sshd_config)
```
# Security recommendations
PermitRootLogin no
PasswordAuthentication no  # After setting up keys
PubkeyAuthentication yes
```

## Client Usage

### Basic connection
```bash
ssh username@hostname
ssh -p 2222 user@host  # Custom port
```

### SSH Keys
```bash
# Generate key pair
ssh-keygen -t ed25519 -C "comment"

# Copy public key to server
ssh-copy-id username@hostname

# Manual copy
cat ~/.ssh/id_ed25519.pub | ssh user@host "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys"
```

### SSH Config (~/.ssh/config)
```
Host myserver
    HostName 192.168.1.100
    User username
    Port 22
    IdentityFile ~/.ssh/id_ed25519

# Then just:
ssh myserver
```

### Port Forwarding
```bash
# Local forwarding (access remote service locally)
ssh -L 8080:localhost:80 user@host

# Remote forwarding (expose local service remotely)
ssh -R 8080:localhost:80 user@host

# Dynamic (SOCKS proxy)
ssh -D 1080 user@host
```

### File Transfer
```bash
# Copy to remote
scp file.txt user@host:/path/

# Copy from remote
scp user@host:/path/file.txt ./

# Copy directory
scp -r directory/ user@host:/path/

# Using rsync (better for large transfers)
rsync -avz directory/ user@host:/path/
```"""
    },
    {
        "title": "Flatpak",
        "category": "package_management",
        "url": "https://wiki.archlinux.org/title/Flatpak",
        "content": """Flatpak is a sandboxed application framework. KOOMPI OS includes Flatpak for easy app installation.

## Setup
```bash
# Install Flatpak (pre-installed on KOOMPI OS)
sudo pacman -S flatpak

# Add Flathub repository
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
```

## Usage

### Installing applications
```bash
# Search
flatpak search firefox

# Install
flatpak install flathub org.mozilla.firefox

# Install from file
flatpak install ./app.flatpakref
```

### Running applications
```bash
# Run
flatpak run org.mozilla.firefox

# List installed
flatpak list

# List with app IDs
flatpak list --app
```

### Updating
```bash
# Update all
flatpak update

# Update specific app
flatpak update org.mozilla.firefox
```

### Removing applications
```bash
# Remove app
flatpak uninstall org.mozilla.firefox

# Remove unused runtimes
flatpak uninstall --unused
```

## Permissions

### Using Flatseal (GUI)
```bash
flatpak install flathub com.github.tchx84.Flatseal
```

### Command line
```bash
# Show permissions
flatpak info --show-permissions org.mozilla.firefox

# Override permissions
flatpak override --user --filesystem=home org.mozilla.firefox
```

## Benefits
- Sandboxed (more secure)
- Distribution-independent
- Latest versions
- Multiple versions can coexist
- User installations (no root needed)

## Drawbacks
- Larger disk usage
- May not integrate perfectly with system theme
- Some system features require permission grants"""
    },
]


def seed_knowledge_base(kb: KnowledgeBase):
    """Seed knowledge base with core articles."""
    logger.info("Seeding knowledge base with core articles...")
    
    for article in CORE_ARCHWIKI_ARTICLES:
        kb.add_article(
            title=article["title"],
            content=article["content"],
            category=article["category"],
            source="archwiki",
            url=article.get("url")
        )
    
    # Add KOOMPI-specific articles
    koompi_articles = [
        {
            "title": "KOOMPI OS Overview",
            "category": "koompi",
            "content": """KOOMPI OS is an immutable, AI-powered Linux distribution built on Arch Linux, designed for education.

## Key Features
- **Immutable System**: Root filesystem is protected with Btrfs snapshots
- **AI Assistant**: Built-in AI help via `koompi` command
- **Easy Recovery**: Instant rollback if something breaks
- **Educational Focus**: Designed for schools and learning

## Quick Commands
```bash
# Get help
koompi help

# Install software
koompi install firefox

# Update system (auto-snapshot)
koompi update

# Install desktop environment
koompi desktop kde

# Create snapshot
koompi snapshot create "description"

# Rollback
koompi rollback <id>
```

## Getting Started
1. Boot KOOMPI OS
2. Run `koompi setup-yay` to enable AUR
3. Install your preferred desktop: `koompi desktop kde`
4. Start learning!"""
        },
        {
            "title": "KOOMPI Snapshots",
            "category": "koompi",
            "content": """KOOMPI OS uses Btrfs snapshots for system protection.

## How It Works
- Every system change creates a snapshot first
- You can rollback to any previous state
- User data (/home) is preserved during rollback
- Snapshots are instant and space-efficient

## Commands

### Create snapshot
```bash
koompi snapshot create "before experiment"
```

### List snapshots
```bash
koompi snapshot list
```

### Rollback
```bash
# List snapshots first
koompi snapshot list

# Rollback to ID
koompi rollback 5

# Reboot to apply
sudo reboot
```

## Automatic Snapshots
KOOMPI creates snapshots automatically before:
- Package installations (`koompi install`)
- System updates (`koompi update`)
- Desktop installations (`koompi desktop`)

## Tips
- Create manual snapshots before experiments
- Keep snapshots lean (old ones auto-deleted)
- Your /home data is safe during rollback"""
        }
    ]
    
    for article in koompi_articles:
        kb.add_article(
            title=article["title"],
            content=article["content"],
            category=article["category"],
            source="koompi"
        )
    
    logger.info(f"Seeded {len(CORE_ARCHWIKI_ARTICLES) + len(koompi_articles)} articles")


# ═══════════════════════════════════════════════════════════════════════
# Singleton Instance
# ═══════════════════════════════════════════════════════════════════════

_kb: Optional[KnowledgeBase] = None


def get_knowledge_base() -> KnowledgeBase:
    """Get or create the knowledge base instance."""
    global _kb
    if _kb is None:
        _kb = KnowledgeBase()
        # Seed if empty
        stats = _kb.get_stats()
        if stats["total_articles"] == 0:
            seed_knowledge_base(_kb)
    return _kb
