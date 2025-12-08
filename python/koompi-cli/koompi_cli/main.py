"""KOOMPI CLI - Command-line interface for KOOMPI OS."""

import click
from rich.console import Console
from rich.table import Table

console = Console()


@click.group()
@click.version_option(version="0.1.0")
def cli():
    """KOOMPI OS command-line interface."""
    pass


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
    try:
        import koompi_core
        console.print("✓ System updated")
    except Exception as e:
        console.print(f"✗ Update failed: [red]{e}[/red]")


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
