#!/usr/bin/env bash

# =========================================================
#   git-setup-script.version.02
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
# OS detection
# ==============================
if [[ -f /etc/os-release ]]; then
  . /etc/os-release
  OS=$ID
else
  error "Cannot detect OS"
  exit 1
fi

info "Detected OS: $OS"

install_packages() {
  case "$OS" in
    ubuntu|debian)
      sudo apt update
      sudo apt install -y git gnupg openssh-client
      ;;
    fedora)
      sudo dnf install -y git gnupg2 openssh-clients
      ;;
    arch|manjaro)
      sudo pacman -Sy --noconfirm git gnupg openssh
      ;;
    opensuse*|sles)
      sudo zypper install -y git gpg2 openssh
      ;;
    *)
      error "Unsupported OS: $OS"
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
# Identity (safe)
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
  warn "No usable GPG key found or force enabled. Generating new key..."

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

  ok "New GPG key created: $KEY_ID"
fi

git config --global commit.gpgsign true
git config --global user.signingkey "$KEY_ID"

# GPG agent tuning (safe append)
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
  ok "Existing SSH key found: $SSH_KEY"
else
  warn "Generating SSH key..."

  ssh-keygen -t ed25519 -C "${EMAIL:-"user@example.com"}" -f "$SSH_KEY" -N ""

  ok "SSH key created"
fi

# Start ssh-agent safely
eval "$(ssh-agent -s)" > /dev/null
ssh-add "$SSH_KEY"

ok "SSH key loaded into agent"

# ==============================
# Output keys
# ==============================
echo ""
info "SSH PUBLIC KEY (ADD TO GIT PROVIDER)"
echo "------------------------------------"
cat "${SSH_KEY}.pub"
echo "------------------------------------"

echo ""
info "GPG PUBLIC KEY (ADD TO GIT PROVIDER)"
echo "------------------------------------"
gpg --armor --export "$KEY_ID"
echo "------------------------------------"

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
info "Workflow:"
echo "  git add ."
echo "  git commit -S -m \"Initial Commit: Project setup\""
echo "  git push origin main"
