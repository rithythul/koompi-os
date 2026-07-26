#!/usr/bin/env bash
# One-line installer for the KOOMPI desktop.
#
#   curl -fsSL https://raw.githubusercontent.com/rithythul/koompi-os/main/install.sh | bash
#
# All this does is get the repository onto the machine and hand over to
# ./setup, which is the real installer. Keeping the bootstrap this thin means
# the piped-from-the-internet part stays small enough to read in one screen,
# and everything of consequence lives in a file you can review after cloning.
#
# Overridable, mostly for testing against a branch or a local mirror:
#   KOOMPI_REPO   git URL to clone from
#   KOOMPI_REF    branch or tag                  (default: main)
#   KOOMPI_DEST   where to keep the checkout     (default: ~/.local/share/koompi-os)
#
# Arguments are passed straight through to ./setup install, so this works:
#   curl -fsSL .../install.sh | bash -s -- --dry-run

set -euo pipefail

REPO_URL="${KOOMPI_REPO:-https://github.com/rithythul/koompi-os.git}"
REPO_REF="${KOOMPI_REF:-main}"
DEST="${KOOMPI_DEST:-$HOME/.local/share/koompi-os}"

if [[ -t 1 ]] && [[ -z "${NO_COLOR:-}" ]]; then
    C_BOLD=$'\e[1m'; C_RED=$'\e[31m'; C_CYAN=$'\e[36m'; C_RST=$'\e[0m'
else
    C_BOLD=''; C_RED=''; C_CYAN=''; C_RST=''
fi

say()  { printf '%s==>%s %s\n' "${C_BOLD}${C_CYAN}" "${C_RST}" "$*"; }
die()  { printf '%serror:%s %s\n' "${C_RED}" "${C_RST}" "$*" >&2; exit 1; }

[[ "$(id -u)" -ne 0 ]] || die "run this as your normal user, not root; it installs into \$HOME and calls sudo only where needed"

# git is the one thing needed before the repo exists. Everything else is the
# per-distro recipe's problem, not this script's.
bootstrap_git() {
    command -v git >/dev/null 2>&1 && return 0
    say "installing git"
    if   command -v pacman >/dev/null 2>&1; then sudo pacman  -S --needed --noconfirm git
    elif command -v dnf    >/dev/null 2>&1; then sudo dnf     install -y git
    elif command -v apt-get>/dev/null 2>&1; then sudo apt-get update && sudo apt-get install -y git
    else die "no git, and no supported package manager to install it with"
    fi
}

bootstrap_git

if [[ -d "$DEST/.git" ]]; then
    say "updating $DEST"
    git -C "$DEST" remote set-url origin "$REPO_URL"
    git -C "$DEST" fetch --depth 1 origin "$REPO_REF"
    # Hard reset rather than pull: this checkout is ours, and a merge conflict
    # here would strand the user inside a bootstrap script with no good way out.
    # Anything the user edits belongs in ~/.config, which ./setup never clobbers.
    git -C "$DEST" reset --hard FETCH_HEAD
    git -C "$DEST" submodule update --init --recursive --depth 1
else
    say "cloning $REPO_URL ($REPO_REF)"
    mkdir -p "$(dirname "$DEST")"
    git clone --depth 1 --branch "$REPO_REF" --recurse-submodules --shallow-submodules \
        "$REPO_URL" "$DEST"
fi

[[ -x "$DEST/setup" ]] || die "no executable setup script in $DEST - wrong branch, or an incomplete clone"

say "handing over to ./setup install"
cd "$DEST"

# stdin is the pipe carrying this script when run as `curl | bash`, so ./setup
# would read its prompts from a closed stream and take the default for
# everything. Reconnect to the terminal so the confirmations actually work.
if [[ ! -t 0 ]] && [[ -r /dev/tty ]]; then
    exec ./setup install "$@" < /dev/tty
fi
exec ./setup install "$@"
