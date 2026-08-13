#!/usr/bin/env bash
set -euo pipefail

# ── mise-style logging ────────────────────────────────────────────────────────
BOLD='\033[1m'
DIM='\033[2m'
RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
BLUE='\033[34m'
CYAN='\033[36m'
RESET='\033[0m'

# respect NO_COLOR and non-TTY
if [[ -n "${NO_COLOR:-}" ]] || [[ ! -t 1 ]]; then
    BOLD=''; DIM=''; RED=''; GREEN=''; YELLOW=''; BLUE=''; CYAN=''; RESET=''
fi

_log() {
    local color="$1" label="$2"; shift 2
    printf "${color}${BOLD}%-9s${RESET}${DIM}|${RESET} %s\n" "$label" "$*"
}

info()    { _log "$BLUE"   "info"    "$@"; }
success() { _log "$GREEN"  "success" "$@"; }
warn()    { _log "$YELLOW" "warn"    "$@"; }
error()   { _log "$RED"    "error"   "$@" >&2; exit 1; }
step()    { printf "\n${CYAN}${BOLD}[%s/%s] %s${RESET}\n" "$1" "$TOTAL_STEPS" "$2"; }

TOTAL_STEPS=6

# ── banner ────────────────────────────────────────────────────────────────────
printf "${BOLD}"
cat <<'BANNER'

      .  .  .
    __|__|__|__
   |            |    linux machine setup
   |  (o)   (o) |    github.com/khanhnguyendev
   |     __     |
   |____________|

BANNER
printf "${RESET}"
printf "${DIM}  Ubuntu / Debian  •  x86_64 / arm64${RESET}\n\n"

# ── root check ────────────────────────────────────────────────────────────────
[[ $EUID -eq 0 ]] || exec sudo bash "$0" "$@"

TARGET_USER="ryan"
TARGET_HOME="/home/$TARGET_USER"
NODE_VERSION="lts/*"
JAVA_PKG="openjdk-21-jdk"

# ── distro check ──────────────────────────────────────────────────────────────
if ! command -v apt-get &>/dev/null; then
    error "apt-get not found — only Debian/Ubuntu supported"
fi

# ─────────────────────────────────────────────────────────────────────────────
# 1. system prerequisites
# ─────────────────────────────────────────────────────────────────────────────
step 1 "System prerequisites"

info "running apt-get update"
apt-get update -qq

PKGS=(
    curl wget git gnupg unzip zip
    build-essential make gcc g++
    zsh
    python3 python3-pip python3-venv python3-dev
    "$JAVA_PKG"
    net-tools dnsutils iputils-ping
    htop tree jq tmux vim nano
    software-properties-common apt-transport-https ca-certificates lsb-release xdg-utils
)

info "installing ${#PKGS[@]} packages"
if DEBIAN_FRONTEND=noninteractive apt-get install -y "${PKGS[@]}" > /tmp/apt-setup.log 2>&1; then
    success "all packages installed"
else
    warn "apt-get reported errors — see /tmp/apt-setup.log"
fi

for cmd in git python3 java curl zsh; do
    if command -v "$cmd" &>/dev/null; then
        ver="$($cmd --version 2>&1 | head -1)"
        success "$cmd — $ver"
    else
        warn "$cmd not found after install"
    fi
done

# ─────────────────────────────────────────────────────────────────────────────
# 2. claude desktop
# ─────────────────────────────────────────────────────────────────────────────
step 2 "Claude Desktop"

info "downloading Anthropic apt signing key"
if curl -fsSLo /usr/share/keyrings/claude-desktop-archive-keyring.asc \
    https://downloads.claude.ai/claude-desktop/key.asc; then
    success "signing key saved"
else
    error "failed to download Claude signing key"
fi

info "registering apt repository"
echo "deb [arch=amd64,arm64 signed-by=/usr/share/keyrings/claude-desktop-archive-keyring.asc] \
https://downloads.claude.ai/claude-desktop/apt/stable stable main" \
    | tee /etc/apt/sources.list.d/claude-desktop.list > /dev/null
apt-get update -qq

info "installing claude-desktop"
if DEBIAN_FRONTEND=noninteractive apt-get install -y claude-desktop > /tmp/claude-install.log 2>&1; then
    success "claude-desktop installed"
else
    error "claude-desktop install failed — see /tmp/claude-install.log"
fi

# ─────────────────────────────────────────────────────────────────────────────
# 3. nvm + node
# ─────────────────────────────────────────────────────────────────────────────
step 3 "nvm + Node.js ($NODE_VERSION)"

info "installing nvm for $TARGET_USER"
if sudo -u "$TARGET_USER" bash -c \
    'curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash > /tmp/nvm-install.log 2>&1'; then
    success "nvm installed"
else
    error "nvm install failed — see /tmp/nvm-install.log"
fi

info "installing Node.js $NODE_VERSION"
if sudo -u "$TARGET_USER" bash -c "
    export NVM_DIR=\"$TARGET_HOME/.nvm\"
    source \"\$NVM_DIR/nvm.sh\"
    nvm install '$NODE_VERSION' > /tmp/node-install.log 2>&1
    nvm alias default '$NODE_VERSION'
    nvm use default >> /tmp/node-install.log 2>&1
"; then
    success "Node.js installed"
else
    error "Node.js install failed — see /tmp/node-install.log"
fi

NODE_VER=$(sudo -u "$TARGET_USER" bash -c "
    export NVM_DIR=\"$TARGET_HOME/.nvm\"
    source \"\$NVM_DIR/nvm.sh\"
    node --version 2>/dev/null || echo 'unknown'
")
success "node $NODE_VER active"

# ─────────────────────────────────────────────────────────────────────────────
# 4. herdr
# ─────────────────────────────────────────────────────────────────────────────
step 4 "herdr"

info "running herdr installer"
if sudo -u "$TARGET_USER" bash -c 'curl -fsSL https://herdr.dev/install.sh | sh'; then
    success "herdr installed"
else
    error "herdr install failed"
fi

# ─────────────────────────────────────────────────────────────────────────────
# 5. oh-my-zsh
# ─────────────────────────────────────────────────────────────────────────────
step 5 "oh-my-zsh"

info "setting zsh as default shell for $TARGET_USER"
if chsh -s "$(which zsh)" "$TARGET_USER"; then
    success "default shell set to zsh"
else
    warn "chsh failed — run manually: chsh -s $(which zsh) $TARGET_USER"
fi

if [[ -d "$TARGET_HOME/.oh-my-zsh" ]]; then
    warn "oh-my-zsh already present — skipping"
else
    info "installing oh-my-zsh"
    if sudo -u "$TARGET_USER" bash -c \
        'RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"'; then
        success "oh-my-zsh installed"
    else
        error "oh-my-zsh install failed"
    fi
fi

_rc_block() {
    local file="$1"
    if ! grep -q 'NVM_DIR' "$file" 2>/dev/null; then
        sudo -u "$TARGET_USER" tee -a "$file" > /dev/null <<'EOF'

# PATH
export PATH="$HOME/.local/bin:/usr/local/bin:$PATH"

# nvm
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && source "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && source "$NVM_DIR/bash_completion"
EOF
        success "PATH + nvm init added to $(basename "$file")"
    else
        warn "$(basename "$file") already has nvm block — skipping"
    fi
}

info "writing PATH exports to shell rc files"
_rc_block "$TARGET_HOME/.zshrc"
_rc_block "$TARGET_HOME/.bashrc"

# ─────────────────────────────────────────────────────────────────────────────
# 6. summary
# ─────────────────────────────────────────────────────────────────────────────
step 6 "Summary"

printf "\n"
_log "$BLUE" "shell"    "zsh + oh-my-zsh"
_log "$BLUE" "git"      "$(git --version | cut -d' ' -f3)"
_log "$BLUE" "python"   "$(python3 --version | cut -d' ' -f2)"
_log "$BLUE" "java"     "$(java -version 2>&1 | awk -F'"' 'NR==1{print $2}')"
_log "$BLUE" "node"     "$NODE_VER (via nvm)"
_log "$BLUE" "claude"   "claude-desktop (apt)"
_log "$BLUE" "herdr"    "latest"

printf "\n${GREEN}${BOLD}success  ${RESET}${DIM}|${RESET} machine ready — run: ${BOLD}su - $TARGET_USER${RESET}\n\n"
