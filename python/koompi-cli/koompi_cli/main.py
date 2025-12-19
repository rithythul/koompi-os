"""KOOMPI CLI - Command-line interface for KOOMPI OS.

Supports both structured commands and natural language:
  koompi pkg install firefox     (structured)
  koompi help me install firefox (natural language)
"""

import click
import subprocess
import sys
from rich.console import Console
from rich.table import Table

console = Console()


# ═══════════════════════════════════════════════════════════════════════
# Natural Language Handler
# ═══════════════════════════════════════════════════════════════════════

def handle_natural_language(text: str) -> bool:
    """Handle natural language input. Returns True if handled."""
    from koompi_ai import classify_intent
    from koompi_ai.intent import Intent
    
    result = classify_intent(text)
    
    if result.intent == Intent.UNKNOWN:
        return False
    
    # Route to appropriate handler
    if result.intent == Intent.INSTALL_PACKAGE:
        pkg = result.entities.get("package_name", "")
        if pkg:
            console.print(f"[cyan]→ Installing:[/cyan] {pkg}")
            _do_install(pkg)
            return True
    
    elif result.intent == Intent.REMOVE_PACKAGE:
        pkg = result.entities.get("package_name", "")
        if pkg:
            console.print(f"[cyan]→ Removing:[/cyan] {pkg}")
            _do_remove(pkg)
            return True
    
    elif result.intent == Intent.UPDATE_SYSTEM:
        console.print("[cyan]→ Updating system[/cyan]")
        _do_update()
        return True
    
    elif result.intent == Intent.SEARCH_PACKAGE:
        query = result.entities.get("package_name", "")
        if query:
            console.print(f"[cyan]→ Searching:[/cyan] {query}")
            _do_search(query)
            return True
    
    elif result.intent == Intent.INSTALL_DESKTOP:
        de = result.entities.get("desktop", "")
        if de:
            console.print(f"[cyan]→ Installing desktop:[/cyan] {de}")
            _do_install_desktop(de)
            return True
    
    elif result.intent == Intent.CREATE_SNAPSHOT:
        console.print("[cyan]→ Creating snapshot[/cyan]")
        _do_snapshot_create("manual")
        return True
    
    elif result.intent == Intent.LIST_SNAPSHOTS:
        console.print("[cyan]→ Listing snapshots[/cyan]")
        _do_snapshot_list()
        return True
    
    elif result.intent == Intent.ROLLBACK:
        sid = result.entities.get("snapshot_id", "")
        if sid:
            console.print(f"[cyan]→ Rolling back to:[/cyan] {sid}")
            _do_rollback(sid)
        else:
            console.print("[yellow]Please specify a snapshot ID: koompi rollback <id>[/yellow]")
        return True
    
    elif result.intent == Intent.SYSTEM_INFO:
        _do_system_info()
        return True
    
    elif result.intent == Intent.DISK_SPACE:
        subprocess.run(["df", "-h"])
        return True
    
    elif result.intent == Intent.MEMORY_INFO:
        subprocess.run(["free", "-h"])
        return True
    
    elif result.intent == Intent.GREETING:
        console.print("[green]សួស្តី! Hello! How can I help you?[/green]")
        console.print("Try: [cyan]koompi help[/cyan] to see what I can do.")
        return True
    
    elif result.intent == Intent.HELP:
        _show_natural_help()
        return True
    
    return False


def _show_natural_help():
    """Show help with natural language examples."""
    console.print("""
[bold cyan]KOOMPI CLI[/bold cyan] - I understand natural language!

[yellow]Package Management:[/yellow]
  koompi install firefox
  koompi help me install vlc
  koompi remove chromium
  koompi search terminal
  koompi update

[yellow]Desktop Environment:[/yellow]
  koompi desktop kde
  koompi install gnome
  koompi i want to use xfce

[yellow]Snapshots:[/yellow]
  koompi snapshot create backup
  koompi list snapshots
  koompi rollback to <id>

[yellow]System:[/yellow]
  koompi info
  koompi disk space
  koompi memory

[yellow]AI Assistant:[/yellow]
  koompi ask how do I edit fstab
  koompi chat

[dim]Tip: Just type naturally - "koompi help me install firefox" works![/dim]
""")


# ═══════════════════════════════════════════════════════════════════════
# Helper Functions
# ═══════════════════════════════════════════════════════════════════════

def _do_install(package: str):
    """Install a package."""
    # Create snapshot first
    _create_pre_snapshot(f"Install {package}")
    
    # Try pacman first, then yay for AUR
    result = subprocess.run(["sudo", "pacman", "-S", "--needed", "--noconfirm", package])
    if result.returncode != 0:
        console.print("[yellow]Not in official repos, trying AUR...[/yellow]")
        subprocess.run(["yay", "-S", "--needed", package])


def _do_remove(package: str):
    """Remove a package."""
    _create_pre_snapshot(f"Remove {package}")
    subprocess.run(["sudo", "pacman", "-Rns", package])


def _do_update():
    """Update system."""
    _create_pre_snapshot("System update")
    # Check if yay is available
    if subprocess.run(["which", "yay"], capture_output=True).returncode == 0:
        subprocess.run(["yay", "-Syu"])
    else:
        subprocess.run(["sudo", "pacman", "-Syu"])


def _do_search(query: str):
    """Search packages."""
    console.print("[cyan]=== Official Repositories ===[/cyan]")
    subprocess.run(["pacman", "-Ss", query])
    
    if subprocess.run(["which", "yay"], capture_output=True).returncode == 0:
        console.print("\n[cyan]=== AUR ===[/cyan]")
        subprocess.run(["yay", "-Ss", query])


def _do_install_desktop(de: str):
    """Install a desktop environment."""
    _create_pre_snapshot(f"Install {de} desktop")
    
    de_packages = {
        "kde": ["plasma-desktop", "plasma-workspace", "plasma-pa", "plasma-nm", 
                "sddm", "konsole", "dolphin", "kate"],
        "gnome": ["gnome", "gnome-tweaks", "gdm"],
        "xfce": ["xfce4", "xfce4-goodies", "lightdm", "lightdm-gtk-greeter"],
        "cinnamon": ["cinnamon", "nemo", "lightdm", "lightdm-gtk-greeter"],
        "mate": ["mate", "mate-extra", "lightdm", "lightdm-gtk-greeter"],
        "i3": ["i3-wm", "i3status", "i3lock", "dmenu", "alacritty", "lightdm"],
        "sway": ["sway", "swaylock", "waybar", "wofi", "foot", "greetd"],
        "hyprland": ["hyprland", "waybar", "wofi", "foot", "greetd"],
    }
    
    dm_enable = {
        "kde": "sddm", "gnome": "gdm", "xfce": "lightdm",
        "cinnamon": "lightdm", "mate": "lightdm", "i3": "lightdm",
        "sway": "greetd", "hyprland": "greetd",
    }
    
    if de not in de_packages:
        console.print(f"[red]Unknown desktop: {de}[/red]")
        console.print(f"Available: {', '.join(de_packages.keys())}")
        return
    
    packages = de_packages[de]
    console.print(f"Installing: {' '.join(packages)}")
    
    subprocess.run(["sudo", "pacman", "-S", "--needed"] + packages)
    
    dm = dm_enable.get(de)
    if dm:
        subprocess.run(["sudo", "systemctl", "enable", dm])
        console.print(f"[green]✓ {de.upper()} installed. Reboot to start.[/green]")


def _do_snapshot_create(name: str):
    """Create a snapshot."""
    try:
        import koompi_core
        snapshot_id = koompi_core.create_snapshot(name, f"Created by koompi CLI")
        console.print(f"[green]✓ Created snapshot: {snapshot_id}[/green]")
    except ImportError:
        # Fallback to snapper
        subprocess.run(["sudo", "snapper", "create", "--description", name])
        console.print(f"[green]✓ Created snapshot: {name}[/green]")
    except Exception as e:
        console.print(f"[red]Failed to create snapshot: {e}[/red]")


def _do_snapshot_list():
    """List snapshots."""
    try:
        import koompi_core
        import json
        snapshots = json.loads(koompi_core.list_snapshots())
        
        if not snapshots:
            console.print("No snapshots found.")
            return
        
        table = Table(title="System Snapshots")
        table.add_column("ID", style="cyan")
        table.add_column("Name", style="green")
        table.add_column("Created", style="yellow")
        table.add_column("Type", style="magenta")
        
        for s in snapshots:
            table.add_row(s["id"], s["name"], s["created_at"][:19], s["snapshot_type"])
        
        console.print(table)
    except ImportError:
        subprocess.run(["sudo", "snapper", "list"])
    except Exception as e:
        console.print(f"[red]Failed to list snapshots: {e}[/red]")


def _do_rollback(snapshot_id: str):
    """Rollback to a snapshot."""
    try:
        import koompi_core
        if click.confirm(f"Rollback to snapshot {snapshot_id}? This requires a reboot."):
            koompi_core.rollback(snapshot_id)
            console.print("[green]✓ Rollback configured. Please reboot.[/green]")
    except ImportError:
        console.print("[yellow]Using snapper for rollback...[/yellow]")
        subprocess.run(["sudo", "snapper", "rollback", snapshot_id])
    except Exception as e:
        console.print(f"[red]Rollback failed: {e}[/red]")


def _do_system_info():
    """Show system information."""
    import platform
    import os
    
    table = Table(title="KOOMPI OS System Information")
    table.add_column("Property", style="cyan")
    table.add_column("Value", style="green")
    
    table.add_row("OS", "KOOMPI OS")
    table.add_row("Kernel", platform.release())
    table.add_row("Architecture", platform.machine())
    table.add_row("Hostname", platform.node())
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


def _create_pre_snapshot(reason: str):
    """Create a pre-operation snapshot."""
    try:
        import koompi_core
        koompi_core.create_snapshot(f"pre-{reason}", f"Before: {reason}")
    except:
        pass  # Silently skip if not available


def _ask_ai(text: str):
    """Ask AI for help with unknown commands."""
    import asyncio
    try:
        from koompi_ai import query
        
        async def run():
            response = await query(text)
            console.print(f"{response.text}")
            
            # Show knowledge sources if used
            if response.knowledge_used:
                sources = ", ".join(response.knowledge_used)
                console.print(f"\n[dim]📚 Knowledge: {sources}[/dim]")
            
            console.print(f"[dim]Source: {response.source}[/dim]")
        
        asyncio.run(run())
    except ImportError:
        console.print("[yellow]AI module not available. Try: pip install koompi-ai[/yellow]")
    except Exception as e:
        console.print(f"[red]AI error: {e}[/red]")


@click.group(invoke_without_command=True)
@click.pass_context
@click.argument('args', nargs=-1)
@click.version_option(version="0.1.0")
def cli(ctx, args):
    """KOOMPI OS command-line interface.
    
    Supports both structured commands and natural language:
    
    \b
      koompi pkg install firefox     (structured)
      koompi help me install firefox (natural language)
    """
    if ctx.invoked_subcommand is None:
        if args:
            # Try natural language processing
            text = " ".join(args)
            if not handle_natural_language(text):
                # Unknown command - try AI
                console.print(f"[dim]I didn't understand that. Let me ask the AI...[/dim]\n")
                _ask_ai(text)
        else:
            click.echo(ctx.get_help())


# Snapshot commands
@cli.group()
def snapshot():
    """Manage system snapshots."""
    pass


@snapshot.command("create")
@click.argument("name")
@click.option("--description", "-d", help="Snapshot description")
def snapshot_create(name: str, description: str | None):
    """Create a new snapshot."""
    try:
        import koompi_core
        snapshot_id = koompi_core.create_snapshot(name, description)
        console.print(f"✓ Created snapshot: [green]{snapshot_id}[/green]")
    except Exception as e:
        console.print(f"✗ Failed to create snapshot: [red]{e}[/red]")


@snapshot.command("list")
def snapshot_list():
    """List all snapshots."""
    try:
        import koompi_core
        import json
        
        snapshots = json.loads(koompi_core.list_snapshots())
        
        if not snapshots:
            console.print("No snapshots found.")
            return
            
        table = Table(title="System Snapshots")
        table.add_column("ID", style="cyan")
        table.add_column("Name", style="green")
        table.add_column("Created", style="yellow")
        table.add_column("Type", style="magenta")
        
        for s in snapshots:
            table.add_row(
                s["id"],
                s["name"],
                s["created_at"][:19],
                s["snapshot_type"],
            )
        
        console.print(table)
    except Exception as e:
        console.print(f"✗ Failed to list snapshots: [red]{e}[/red]")


@snapshot.command("rollback")
@click.argument("snapshot_id")
def snapshot_rollback(snapshot_id: str):
    """Rollback to a snapshot."""
    try:
        import koompi_core
        
        if click.confirm(f"Rollback to snapshot {snapshot_id}? This requires a reboot."):
            koompi_core.rollback(snapshot_id)
            console.print(f"✓ Rollback configured. [yellow]Please reboot to complete.[/yellow]")
    except Exception as e:
        console.print(f"✗ Rollback failed: [red]{e}[/red]")


@snapshot.command("delete")
@click.argument("snapshot_id")
def snapshot_delete(snapshot_id: str):
    """Delete a snapshot."""
    try:
        import koompi_core
        
        if click.confirm(f"Delete snapshot {snapshot_id}?"):
            koompi_core.delete_snapshot(snapshot_id)
            console.print(f"✓ Deleted snapshot: [green]{snapshot_id}[/green]")
    except Exception as e:
        console.print(f"✗ Failed to delete snapshot: [red]{e}[/red]")


# Package commands
@cli.group()
def pkg():
    """Manage packages."""
    pass


@pkg.command("search")
@click.argument("query")
def pkg_search(query: str):
    """Search for packages."""
    try:
        import koompi_core
        import json
        
        packages = json.loads(koompi_core.search_packages(query))
        
        if not packages:
            console.print(f"No packages found for '{query}'")
            return
            
        table = Table(title=f"Search Results: {query}")
        table.add_column("Name", style="cyan")
        table.add_column("Version", style="green")
        table.add_column("Backend", style="yellow")
        table.add_column("Description")
        
        for p in packages[:20]:
            table.add_row(
                p["name"],
                p["version"],
                p["backend"],
                p["description"][:50] + "..." if len(p["description"]) > 50 else p["description"],
            )
        
        console.print(table)
    except Exception as e:
        console.print(f"✗ Search failed: [red]{e}[/red]")


@pkg.command("install")
@click.argument("name")
def pkg_install(name: str):
    """Install a package."""
    try:
        import koompi_core
        
        console.print(f"Installing [cyan]{name}[/cyan]...")
        koompi_core.install_package(name)
        console.print(f"✓ Installed: [green]{name}[/green]")
    except Exception as e:
        console.print(f"✗ Installation failed: [red]{e}[/red]")


@pkg.command("remove")
@click.argument("name")
def pkg_remove(name: str):
    """Remove a package."""
    try:
        import koompi_core
        
        if click.confirm(f"Remove {name}?"):
            koompi_core.remove_package(name)
            console.print(f"✓ Removed: [green]{name}[/green]")
    except Exception as e:
        console.print(f"✗ Removal failed: [red]{e}[/red]")


@pkg.command("update")
def pkg_update():
    """Update all packages."""
    console.print("Updating system packages...")
    _do_update()


# Desktop Environment command
@cli.command()
@click.argument("name", required=False)
def desktop(name: str | None):
    """Install a desktop environment.
    
    Available: kde, gnome, xfce, cinnamon, mate, i3, sway, hyprland
    """
    if not name:
        console.print("""
[bold cyan]Available Desktop Environments:[/bold cyan]

[yellow]Full Desktops:[/yellow]
  kde       - KDE Plasma (modern, feature-rich)
  gnome     - GNOME (simple, elegant)
  xfce      - XFCE (lightweight, traditional)
  cinnamon  - Cinnamon (Windows-like)
  mate      - MATE (classic GNOME 2 style)

[yellow]Tiling/Minimal:[/yellow]
  i3        - i3wm (X11 tiling)
  sway      - Sway (Wayland i3-like)
  hyprland  - Hyprland (modern Wayland)

[dim]Usage: koompi desktop <name>[/dim]
""")
        return
    
    _do_install_desktop(name.lower())


# AI Assistant command
@cli.command()
@click.argument("prompt", nargs=-1)
def ask(prompt: tuple):
    """Ask the AI assistant a question."""
    import asyncio
    from koompi_ai import query
    
    text = " ".join(prompt)
    if not text:
        console.print("Please provide a question.")
        return
    
    console.print(f"[dim]Thinking...[/dim]")
    
    async def run():
        response = await query(text)
        console.print(f"\n{response.text}")
        
        # Show knowledge sources if used
        if response.knowledge_used:
            sources = ", ".join(response.knowledge_used)
            console.print(f"\n[bold blue]📚 Knowledge Sources:[/bold blue]")
            for title in response.knowledge_used:
                console.print(f"  • {title}")
        
        console.print(f"\n[dim]Source: {response.source} | Confidence: {response.confidence:.0%}[/dim]")
    
    asyncio.run(run())


# System info command
@cli.command()
def info():
    """Show system information."""
    import platform
    import os
    
    table = Table(title="KOOMPI OS System Information")
    table.add_column("Property", style="cyan")
    table.add_column("Value", style="green")
    
    table.add_row("OS", "KOOMPI OS")
    table.add_row("Kernel", platform.release())
    table.add_row("Architecture", platform.machine())
    table.add_row("Python", platform.python_version())
    table.add_row("Hostname", platform.node())
    table.add_row("CPU Cores", str(os.cpu_count()))
    
    try:
        with open("/proc/meminfo") as f:
            for line in f:
                if line.startswith("MemTotal"):
                    mem_kb = int(line.split()[1])
                    mem_gb = mem_kb / 1024 / 1024
                    table.add_row("Memory", f"{mem_gb:.1f} GB")
                    break
    except:
        pass
    
    console.print(table)


# Interactive chat mode
@cli.command()
def chat():
    """Start interactive chat with AI assistant."""
    import asyncio
    from koompi_ai import query, classify_intent
    from koompi_ai.intent import Intent
    
    console.print("[bold]KOOMPI Assistant[/bold]")
    console.print("Type 'exit' to quit, 'help' for commands.\n")
    
    async def handle_input(text: str) -> str:
        classified = classify_intent(text)
        
        if classified.intent == Intent.GREETING:
            return "សួស្តី! Hello! How can I help you today?"
        
        if classified.intent == Intent.HELP:
            return """I can help you with:
• Installing/removing packages: "install firefox"
• System snapshots: "create snapshot", "list snapshots"
• System info: "disk space", "memory info"
• And much more! Just ask naturally."""
        
        if classified.intent == Intent.INSTALL_PACKAGE:
            pkg = classified.entities.get("package_name", "")
            return f"To install {pkg}, run: koompi pkg install {pkg}"
        
        response = await query(text)
        return response.text
    
    while True:
        try:
            user_input = console.input("[bold cyan]You:[/bold cyan] ")
            
            if user_input.lower() in ("exit", "quit", "bye"):
                console.print("Goodbye! 👋")
                break
            
            if not user_input.strip():
                continue
            
            response = asyncio.run(handle_input(user_input))
            console.print(f"[bold green]KOOMPI:[/bold green] {response}\n")
            
        except KeyboardInterrupt:
            console.print("\nGoodbye! 👋")
            break
        except EOFError:
            break


if __name__ == "__main__":
    cli()


# ═══════════════════════════════════════════════════════════════════════
# Additional Top-Level Commands
# ═══════════════════════════════════════════════════════════════════════

@cli.command()
def update():
    """Update system (shortcut for pkg update)."""
    _do_update()


@cli.command("install")
@click.argument("packages", nargs=-1, required=True)
def install_shortcut(packages: tuple):
    """Install packages (shortcut for pkg install)."""
    for pkg in packages:
        _do_install(pkg)


@cli.command("remove")
@click.argument("packages", nargs=-1, required=True)
def remove_shortcut(packages: tuple):
    """Remove packages (shortcut for pkg remove)."""
    for pkg in packages:
        _do_remove(pkg)


@cli.command("search")
@click.argument("query")
def search_shortcut(query: str):
    """Search packages (shortcut for pkg search)."""
    _do_search(query)


@cli.command("setup-yay")
def setup_yay():
    """Install yay (AUR helper)."""
    import shutil
    
    if shutil.which("yay"):
        console.print("[green]yay is already installed[/green]")
        return
    
    console.print("[cyan]Installing yay (AUR helper)...[/cyan]")
    
    import tempfile
    import os
    
    with tempfile.TemporaryDirectory() as tmpdir:
        os.chdir(tmpdir)
        result = subprocess.run(["git", "clone", "https://aur.archlinux.org/yay.git"])
        if result.returncode != 0:
            console.print("[red]Failed to clone yay[/red]")
            return
        
        os.chdir("yay")
        result = subprocess.run(["makepkg", "-si", "--noconfirm"])
        if result.returncode != 0:
            console.print("[red]Failed to build yay[/red]")
            return
    
    console.print("[green]✓ yay installed successfully[/green]")


@cli.command("rollback")
@click.argument("snapshot_id", required=False)
def rollback_shortcut(snapshot_id: str | None):
    """Rollback to a snapshot (shortcut)."""
    if not snapshot_id:
        console.print("[yellow]Please specify a snapshot ID[/yellow]")
        console.print("List snapshots with: koompi snapshot list")
        return
    _do_rollback(snapshot_id)
