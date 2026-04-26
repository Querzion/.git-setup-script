#!/usr/bin/env bash

# =========================================================
#   git-setup-script.version.03
# =========================================================

set -e

# ==============================
# Flags
# ==============================
FORCE=false

if [[ "$1" == "--force" ]]; then
  FORCE=true
fi

# ==============================
# Colors
# ==============================
BLUE="\e[34m"
YELLOW="\e[33m"
RED="\e[31m"
GREEN="\e[32m"
RESET="\e[0m"

info() { echo -e "${BLUE}[INFO]${RESET} $1"; }
warn() { echo -e "${YELLOW}[WARN]${RESET} $1"; }
ok() { echo -e "${GREEN}[OK]${RESET} $1"; }
error() { echo -e "${RED}[ERROR]${RESET} $1"; }

# ==============================
# OS / Family detection
# ==============================
if [[ -f /etc/os-release ]]; then
  . /etc/os-release

  OS_ID="${ID,,}"
  OS_LIKE="${ID_LIKE,,}"
else
  error "Cannot detect OS"
  exit 1
fi

detect_family() {
  case "$OS_ID" in
    ubuntu|debian|linuxmint|pop|zorin|elementary)
      echo "debian"
      ;;
    fedora|rhel|centos|rocky|almalinux)
      echo "fedora"
      ;;
    arch|manjaro|endeavouros|garuda)
      echo "arch"
      ;;
    opensuse*|sles|suse)
      echo "suse"
      ;;
    *)
      # fallback to ID_LIKE parsing
      case "$OS_LIKE" in
        *debian*) echo "debian" ;;
        *ubuntu*) echo "debian" ;;
        *fedora*|*rhel*) echo "fedora" ;;
        *arch*) echo "arch" ;;
        *suse*) echo "suse" ;;
        *)
          echo "unknown"
          ;;
      esac
      ;;
  esac
}

FAMILY=$(detect_family)

info "Detected OS: $OS_ID"
info "Detected family: $FAMILY"

install_packages() {
  case "$FAMILY" in
    debian)
      sudo apt update
      sudo apt install -y git gnupg openssh-client
      ;;
    fedora)
      sudo dnf install -y git gnupg2 openssh-clients
      ;;
    arch)
      sudo pacman -Sy --noconfirm git gnupg openssh
      ;;
    suse)
      sudo zypper install -y git gpg2 openssh
      ;;
    *)
      error "Unsupported OS family: $FAMILY (ID: $OS_ID, LIKE: $OS_LIKE)"
      exit 1
      ;;
  esac
}

# ==============================
# Ensure dependencies
# ==============================
command -v git >/dev/null || install_packages
command -v gpg >/dev/null || install_packages
command -v ssh >/dev/null || install_packages

# ==============================
# Identity setup
# ==============================
CURRENT_NAME=$(git config --global user.name || true)
CURRENT_EMAIL=$(git config --global user.email || true)

if [[ -n "$CURRENT_NAME" && "$FORCE" == false ]]; then
  ok "Git identity already set: $CURRENT_NAME <$CURRENT_EMAIL>"
  read -rp "Override identity? (y/N): " override
  [[ "$override" != "y" ]] && SKIP_IDENTITY=true
fi

if [[ "$SKIP_IDENTITY" != true ]]; then
  read -rp "First Name: " FIRST
  read -rp "Last Name: " LAST
  read -rp "Email: " EMAIL

  capitalize() {
    echo "$1" | awk '{for (i=1;i<=NF;i++) {$i=toupper(substr($i,1,1)) substr($i,2)}}1'
  }

  FIRST=$(capitalize "$FIRST")
  LAST=$(capitalize "$LAST")
  FULLNAME="$FIRST $LAST"

  git config --global user.name "$FULLNAME"
  git config --global user.email "$EMAIL"

  ok "Git identity set: $FULLNAME <$EMAIL>"
fi

# ==============================
# GPG setup (non-destructive)
# ==============================
info "Checking existing GPG keys..."

if [[ -n "$EMAIL" ]]; then
  EXISTING_KEY=$(gpg --list-secret-keys --keyid-format=long "$EMAIL" 2>/dev/null | awk '/sec/ {print $2}' | cut -d'/' -f2 || true)
fi

if [[ -n "$EXISTING_KEY" && "$FORCE" == false ]]; then
  ok "Existing GPG key found: $EXISTING_KEY"
  KEY_ID="$EXISTING_KEY"
else
  warn "Generating new GPG key..."

  cat > gpg-batch <<EOF
%no-protection
Key-Type: default
Subkey-Type: default
Name-Real: ${FULLNAME:-"Git User"}
Name-Email: ${EMAIL:-"user@example.com"}
Expire-Date: 0
%commit
EOF

  gpg --batch --generate-key gpg-batch
  rm gpg-batch

  KEY_ID=$(gpg --list-secret-keys --keyid-format=long "$EMAIL" | awk '/sec/ {print $2}' | cut -d'/' -f2)

  ok "GPG key ready: $KEY_ID"
fi

git config --global commit.gpgsign true
git config --global user.signingkey "$KEY_ID"

# GPG agent caching (prevents constant prompts)
mkdir -p ~/.gnupg
chmod 700 ~/.gnupg

grep -q "default-cache-ttl" ~/.gnupg/gpg-agent.conf 2>/dev/null || cat >> ~/.gnupg/gpg-agent.conf <<EOF
default-cache-ttl 86400
max-cache-ttl 604800
EOF

gpgconf --kill gpg-agent
gpgconf --launch gpg-agent

ok "GPG configured"

# ==============================
# SSH setup (non-destructive)
# ==============================
info "Checking SSH key..."

SSH_KEY="$HOME/.ssh/id_ed25519"

mkdir -p ~/.ssh
chmod 700 ~/.ssh

if [[ -f "$SSH_KEY" && "$FORCE" == false ]]; then
  ok "Existing SSH key found"
else
  warn "Generating SSH key..."
  ssh-keygen -t ed25519 -C "${EMAIL:-"user@example.com"}" -f "$SSH_KEY" -N ""
  ok "SSH key created"
fi

eval "$(ssh-agent -s)" > /dev/null
ssh-add "$SSH_KEY"

ok "SSH key loaded"

# ==============================
# Git workflow enforcement
# ==============================
info "Configuring Git workflow standards..."

git config --global alias.merge-no-ff "merge --no-ff"

git config --global alias.dev-merge "!f() { git merge --no-ff \"$1\"; }; f"

ok "Merge strategy enforced (--no-ff required)"

# ==============================
# Output keys
# ==============================
echo ""
info "SSH PUBLIC KEY"
echo "------------------------------------"
cat "${SSH_KEY}.pub"
echo "------------------------------------"

echo ""
info "GPG PUBLIC KEY"
echo "------------------------------------"
gpg --armor --export "$KEY_ID"
echo "------------------------------------"

# ==============================
# Optional Git Aliases Prompt
# ==============================
echo ""
info "Optional Git Aliases"

echo "The following aliases can be added to your shell (.bashrc):"
echo ""
echo "  gc   → git commit -S -m"
echo "  gco  → git checkout"
echo "  gcb  → git checkout -b"
echo "  gs   → git status -sb"
echo "  gl   → git log --oneline --graph --decorate --all"
echo "  sl   → git shortlog -s -n"
echo "  gp   → git push"
echo "  gpl  → git pull"
echo "  gmnf → git merge --no-ff"
echo ""

read -rp "Do you want to add these aliases to ~/.bashrc? [Y/n]: " ADD_ALIASES

# Default = YES if empty input
if [[ -z "$ADD_ALIASES" || "$ADD_ALIASES" =~ ^[Yy]$ ]]; then

  BASHRC="$HOME/.bashrc"
  MARKER="# >>> git-bootstrap-aliases"

  if ! grep -q "$MARKER" "$BASHRC" 2>/dev/null; then
    cat >> "$BASHRC" <<'EOF'

# >>> git-bootstrap-aliases

# Git commit (signed)
alias gc='git commit -S -m'

# Navigation
alias gco='git checkout'
alias gcb='git checkout -b'

# Status & logs
alias gs='git status -sb'
alias gl='git log --oneline --graph --decorate --all'
alias sl='git shortlog -s -n'

# Push / Pull
alias gp='git push'
alias gpl='git pull'

# Merge (no fast-forward enforcement)
alias gmnf='git merge --no-ff'
alias gm='git merge --no-ff'

# <<< git-bootstrap-aliases
EOF

    ok "Aliases added to ~/.bashrc"
    warn "Run: source ~/.bashrc to activate them"
  else
    warn "Aliases already exist in ~/.bashrc — skipping"
  fi

else
  warn "Skipping alias installation"
fi

# ==============================
# Summary
# ==============================
echo ""
ok "SETUP COMPLETE"
echo "------------------------------------"
echo "OS        : $OS"
echo "Git User  : $(git config --global user.name)"
echo "Email     : $(git config --global user.email)"
echo "GPG Key   : $KEY_ID"
echo "SSH Key   : $SSH_KEY"
echo "Mode      : $( [[ "$FORCE" == true ]] && echo "FORCE" || echo "SAFE" )"
echo "------------------------------------"

echo ""
info "Enforced Workflow:"
echo "  main → production"
echo "  main-dev → integration"
echo "  dev/* → feature branches"
echo ""
echo "Merges MUST use:"
echo "  git merge --no-ff <branch>"
echo "  or git merge-no-ff <branch>"
echo ""
echo "Workflow example:"
echo "  git checkout -b dev/feature main-dev"
echo "  git commit -S -m \"feat: add feature\""
echo "  git merge --no-ff dev/feature"
echo "  git push"
