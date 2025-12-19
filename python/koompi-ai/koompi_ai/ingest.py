#!/usr/bin/env python3
"""Ingest ArchWiki articles into the local knowledge base.

This script can:
1. Use pre-defined essential articles (built-in)
2. Parse MediaWiki XML dumps from ArchWiki
3. Fetch articles directly from wiki (requires internet)

Usage:
    # Use built-in articles only (default, no internet needed)
    python -m koompi_ai.ingest --builtin
    
    # Parse from MediaWiki XML dump
    python -m koompi_ai.ingest --xml /path/to/archwiki-dump.xml
    
    # Fetch specific articles from wiki (requires internet)
    python -m koompi_ai.ingest --fetch "Pacman" "Systemd" "Btrfs"
    
    # Show current knowledge base stats
    python -m koompi_ai.ingest --stats
"""

import argparse
import logging
import sys
import re
import xml.etree.ElementTree as ET
from pathlib import Path
from typing import List, Optional
import html

try:
    import requests
    REQUESTS_AVAILABLE = True
except ImportError:
    REQUESTS_AVAILABLE = False

from .knowledge import KnowledgeBase, seed_knowledge_base, get_knowledge_base

logging.basicConfig(level=logging.INFO, format='%(levelname)s: %(message)s')
logger = logging.getLogger(__name__)


# Essential ArchWiki articles to fetch
ESSENTIAL_ARTICLES = [
    "Pacman",
    "Pacman/Tips_and_tricks",
    "Arch_User_Repository",
    "Systemd",
    "Btrfs",
    "Snapper",
    "Network_configuration",
    "NetworkManager",
    "Users_and_groups",
    "Sudo",
    "SSH",
    "Desktop_environment",
    "KDE",
    "GNOME",
    "Xfce",
    "Sway",
    "Hyprland",
    "i3",
    "Flatpak",
    "Installation_guide",
    "General_recommendations",
    "System_maintenance",
    "Kernel",
    "Mkinitcpio",
    "GRUB",
    "Systemd-boot",
    "Fstab",
    "File_systems",
    "Partitioning",
    "USB_flash_installation_medium",
    "Archiso",
]


def clean_mediawiki_text(text: str) -> str:
    """Convert MediaWiki markup to readable text with code blocks."""
    # Remove HTML comments
    text = re.sub(r'<!--.*?-->', '', text, flags=re.DOTALL)
    
    # Convert code templates
    text = re.sub(r'\{\{ic\|([^}]+)\}\}', r'`\1`', text)
    text = re.sub(r'\{\{bc\|([^}]+)\}\}', r'```\n\1\n```', text)
    
    # Convert code blocks
    text = re.sub(r'<code>([^<]+)</code>', r'`\1`', text)
    text = re.sub(r'<pre>([^<]+)</pre>', r'```\n\1\n```', text, flags=re.DOTALL)
    text = re.sub(r'<syntaxhighlight[^>]*>([^<]+)</syntaxhighlight>', r'```\n\1\n```', text, flags=re.DOTALL)
    
    # Convert headers
    text = re.sub(r'^======\s*([^=]+)\s*======', r'###### \1', text, flags=re.MULTILINE)
    text = re.sub(r'^=====\s*([^=]+)\s*=====', r'##### \1', text, flags=re.MULTILINE)
    text = re.sub(r'^====\s*([^=]+)\s*====', r'#### \1', text, flags=re.MULTILINE)
    text = re.sub(r'^===\s*([^=]+)\s*===', r'### \1', text, flags=re.MULTILINE)
    text = re.sub(r'^==\s*([^=]+)\s*==', r'## \1', text, flags=re.MULTILINE)
    text = re.sub(r'^=\s*([^=]+)\s*=', r'# \1', text, flags=re.MULTILINE)
    
    # Convert lists
    text = re.sub(r'^\*\*\*\*', '        -', text, flags=re.MULTILINE)
    text = re.sub(r'^\*\*\*', '      -', text, flags=re.MULTILINE)
    text = re.sub(r'^\*\*', '    -', text, flags=re.MULTILINE)
    text = re.sub(r'^\*', '-', text, flags=re.MULTILINE)
    text = re.sub(r'^####', '        1.', text, flags=re.MULTILINE)
    text = re.sub(r'^###', '      1.', text, flags=re.MULTILINE)
    text = re.sub(r'^##', '    1.', text, flags=re.MULTILINE)
    text = re.sub(r'^#([^#])', r'1.\1', text, flags=re.MULTILINE)
    
    # Convert links
    text = re.sub(r'\[\[([^\]|]+)\|([^\]]+)\]\]', r'\2', text)  # [[Link|Text]] -> Text
    text = re.sub(r'\[\[([^\]]+)\]\]', r'\1', text)  # [[Link]] -> Link
    text = re.sub(r'\[https?://[^\s\]]+\s+([^\]]+)\]', r'\1', text)  # External links
    
    # Convert bold/italic
    text = re.sub(r"'''([^']+)'''", r'**\1**', text)
    text = re.sub(r"''([^']+)''", r'*\1*', text)
    
    # Remove templates we don't handle
    text = re.sub(r'\{\{[^}]+\}\}', '', text)
    
    # Remove categories and other metadata
    text = re.sub(r'\[\[Category:[^\]]+\]\]', '', text)
    text = re.sub(r'\[\[File:[^\]]+\]\]', '', text)
    text = re.sub(r'\[\[Image:[^\]]+\]\]', '', text)
    
    # Clean up whitespace
    text = re.sub(r'\n{3,}', '\n\n', text)
    text = text.strip()
    
    # Decode HTML entities
    text = html.unescape(text)
    
    return text


def categorize_article(title: str, content: str) -> str:
    """Determine article category based on title and content."""
    title_lower = title.lower()
    content_lower = content.lower()[:1000]  # Check first 1000 chars
    
    # Package management
    if any(k in title_lower for k in ['pacman', 'aur', 'package', 'flatpak', 'snap']):
        return "package_management"
    
    # System
    if any(k in title_lower for k in ['systemd', 'kernel', 'mkinitcpio', 'boot', 'grub', 'fstab']):
        return "system"
    
    # Filesystem
    if any(k in title_lower for k in ['btrfs', 'ext4', 'filesystem', 'partition', 'disk', 'snapper']):
        return "filesystem"
    
    # Networking
    if any(k in title_lower for k in ['network', 'ssh', 'firewall', 'wifi', 'wireless']):
        return "networking"
    
    # Desktop
    if any(k in title_lower for k in ['kde', 'gnome', 'xfce', 'desktop', 'sway', 'hyprland', 'i3', 'wayland', 'xorg']):
        return "desktop"
    
    # Installation
    if any(k in title_lower for k in ['install', 'setup', 'guide', 'archiso']):
        return "installation"
    
    # Security
    if any(k in title_lower for k in ['security', 'encrypt', 'permission', 'user', 'sudo']):
        return "security"
    
    return "general"


def parse_mediawiki_xml(xml_path: Path, kb: KnowledgeBase, limit: Optional[int] = None) -> int:
    """Parse MediaWiki XML dump and add articles to knowledge base.
    
    Args:
        xml_path: Path to XML dump file
        kb: Knowledge base instance
        limit: Maximum articles to import (None for all)
        
    Returns:
        Number of articles imported
    """
    logger.info(f"Parsing MediaWiki XML from {xml_path}")
    
    count = 0
    
    # Parse XML iteratively to handle large files
    context = ET.iterparse(xml_path, events=('end',))
    
    ns = '{http://www.mediawiki.org/xml/export-0.10/}'  # MediaWiki namespace
    
    for event, elem in context:
        if elem.tag == f'{ns}page' or elem.tag == 'page':
            # Extract page data
            title_elem = elem.find(f'{ns}title') or elem.find('title')
            text_elem = elem.find(f'.//{ns}text') or elem.find('.//text')
            
            if title_elem is not None and text_elem is not None:
                title = title_elem.text
                text = text_elem.text or ""
                
                # Skip non-article pages
                if title and not title.startswith(('User:', 'Talk:', 'Template:', 'Category:', 'File:')):
                    # Clean and process
                    content = clean_mediawiki_text(text)
                    
                    if len(content) > 100:  # Skip very short articles
                        category = categorize_article(title, content)
                        
                        kb.add_article(
                            title=title,
                            content=content,
                            category=category,
                            source="archwiki",
                            url=f"https://wiki.archlinux.org/title/{title.replace(' ', '_')}"
                        )
                        count += 1
                        
                        if count % 100 == 0:
                            logger.info(f"Imported {count} articles...")
                        
                        if limit and count >= limit:
                            break
            
            # Clear element to save memory
            elem.clear()
    
    logger.info(f"Imported {count} articles from XML")
    return count


def fetch_article_from_wiki(title: str) -> Optional[str]:
    """Fetch article content from ArchWiki API.
    
    Args:
        title: Article title
        
    Returns:
        Article content or None if failed
    """
    if not REQUESTS_AVAILABLE:
        logger.error("requests library not available. Install with: pip install requests")
        return None
    
    api_url = "https://wiki.archlinux.org/api.php"
    params = {
        "action": "query",
        "titles": title,
        "prop": "revisions",
        "rvprop": "content",
        "format": "json",
        "rvslots": "main"
    }
    
    try:
        response = requests.get(api_url, params=params, timeout=30)
        response.raise_for_status()
        data = response.json()
        
        pages = data.get("query", {}).get("pages", {})
        for page_id, page_data in pages.items():
            if page_id == "-1":
                return None  # Page not found
            
            revisions = page_data.get("revisions", [])
            if revisions:
                content = revisions[0].get("slots", {}).get("main", {}).get("*", "")
                return clean_mediawiki_text(content)
        
        return None
    except Exception as e:
        logger.error(f"Failed to fetch {title}: {e}")
        return None


def fetch_articles(titles: List[str], kb: KnowledgeBase) -> int:
    """Fetch multiple articles from ArchWiki.
    
    Args:
        titles: List of article titles
        kb: Knowledge base instance
        
    Returns:
        Number of articles fetched
    """
    count = 0
    
    for title in titles:
        logger.info(f"Fetching: {title}")
        content = fetch_article_from_wiki(title)
        
        if content and len(content) > 100:
            category = categorize_article(title, content)
            kb.add_article(
                title=title,
                content=content,
                category=category,
                source="archwiki",
                url=f"https://wiki.archlinux.org/title/{title.replace(' ', '_')}"
            )
            count += 1
            logger.info(f"  ✓ Added ({category})")
        else:
            logger.warning(f"  ✗ Skipped (not found or too short)")
    
    return count


def main():
    parser = argparse.ArgumentParser(
        description="Ingest ArchWiki articles into KOOMPI AI knowledge base",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s --builtin          # Load built-in essential articles
  %(prog)s --stats            # Show knowledge base statistics
  %(prog)s --fetch Pacman     # Fetch specific article from wiki
  %(prog)s --xml dump.xml     # Import from MediaWiki XML dump
  %(prog)s --essential        # Fetch essential articles from wiki
"""
    )
    
    parser.add_argument('--builtin', action='store_true',
                        help='Seed knowledge base with built-in articles (default, offline)')
    parser.add_argument('--stats', action='store_true',
                        help='Show knowledge base statistics')
    parser.add_argument('--xml', type=Path,
                        help='Path to MediaWiki XML dump file')
    parser.add_argument('--fetch', nargs='+', metavar='TITLE',
                        help='Fetch specific articles from ArchWiki (requires internet)')
    parser.add_argument('--essential', action='store_true',
                        help='Fetch essential ArchWiki articles (requires internet)')
    parser.add_argument('--limit', type=int,
                        help='Limit number of articles to import (for XML)')
    parser.add_argument('--reset', action='store_true',
                        help='Reset knowledge base before importing')
    
    args = parser.parse_args()
    
    # Get knowledge base
    kb = get_knowledge_base()
    
    # Reset if requested
    if args.reset:
        logger.warning("Resetting knowledge base...")
        kb.db_path.unlink(missing_ok=True)
        kb = KnowledgeBase()  # Recreate
    
    # Show stats
    if args.stats:
        stats = kb.get_stats()
        print(f"\n📚 Knowledge Base Statistics")
        print(f"   Database: {stats['db_path']}")
        print(f"   Size: {stats['db_size_mb']:.2f} MB")
        print(f"   Total articles: {stats['total_articles']}")
        print(f"\n   By source:")
        for source, count in stats['by_source'].items():
            print(f"     - {source}: {count}")
        print(f"\n   By category:")
        for cat, count in stats['by_category'].items():
            print(f"     - {cat}: {count}")
        return 0
    
    # Import from XML
    if args.xml:
        if not args.xml.exists():
            logger.error(f"File not found: {args.xml}")
            return 1
        count = parse_mediawiki_xml(args.xml, kb, limit=args.limit)
        logger.info(f"Imported {count} articles from XML")
        return 0
    
    # Fetch specific articles
    if args.fetch:
        count = fetch_articles(args.fetch, kb)
        logger.info(f"Fetched {count}/{len(args.fetch)} articles")
        return 0
    
    # Fetch essential articles
    if args.essential:
        logger.info("Fetching essential ArchWiki articles...")
        count = fetch_articles(ESSENTIAL_ARTICLES, kb)
        logger.info(f"Fetched {count}/{len(ESSENTIAL_ARTICLES)} essential articles")
        return 0
    
    # Default: seed with built-in articles
    if args.builtin or not any([args.xml, args.fetch, args.essential, args.stats]):
        logger.info("Seeding knowledge base with built-in articles...")
        seed_knowledge_base(kb)
        stats = kb.get_stats()
        logger.info(f"Knowledge base now has {stats['total_articles']} articles")
        return 0
    
    return 0


if __name__ == "__main__":
    sys.exit(main())
