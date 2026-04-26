# 📦 Git Security Bootstrapper (GPG + SSH)

A system-agnostic setup script that configures **Git identity, GPG commit signing, and SSH authentication** in a clean, safe, and repeatable way across major Linux distributions.

It is designed to eliminate repetitive authentication prompts while maintaining strong cryptographic security for commits and repository access.

---

## ⚙️ Features

- ✔ Automatically detects Linux distribution
- ✔ Installs required dependencies (Git, GPG, SSH tools)
- ✔ Configures Git identity (name + email with proper capitalization)
- ✔ Sets up **GPG commit signing**
- ✔ Reuses existing GPG keys (non-destructive by default)
- ✔ Sets up **SSH key authentication for push/pull**
- ✔ Starts and configures `ssh-agent`
- ✔ Configures `gpg-agent` caching to reduce passphrase prompts
- ✔ Safe re-runs (idempotent behavior)
- ✔ Optional `--force` mode for full reset

---

## 🧠 Security Model

| Layer | Purpose |
|------|--------|
| Git  | Version control |
| GPG  | Commit authenticity (identity/signature) |
| SSH  | Repository authentication (push/pull access) |

---

## 🖥️ Supported Systems

- Debian / Ubuntu (`apt`)
- Fedora (`dnf`)
- Arch Linux (`pacman`)
- openSUSE (`zypper`)
- Other `/etc/os-release` compatible Linux systems

---

## 🚀 Usage

### Standard (safe mode)

```bash
chmod +x setup-git.sh
./setup-git.sh
```

### Force mode (full reset)

⚠️ This will regenerate keys and overwrite configuration.

```bash
./setup-git.sh --force
```

---

## 🔐 What gets configured

### Git
- `user.name`
- `user.email`

### GPG
- New or existing key reused
- Commit signing enabled:

```bash
git config --global commit.gpgsign true
```

- Signing key linked to Git

### SSH
- Generates Ed25519 key (if missing)
- Starts `ssh-agent`
- Adds key automatically

---

## 📂 Output artifacts

### SSH Key
```
~/.ssh/id_ed25519
~/.ssh/id_ed25519.pub
```

### GPG Key
```
gpg --list-secret-keys
```

---

## 🧪 Mock Output

Example run on a fresh Fedora system:

```
[INFO] Detected OS: fedora

[INFO] Git not found. Installing...
[OK] Git installed successfully

First Name: john
Last Name: doe
Email: john.doe@example.com

[OK] Git identity set: John Doe <john.doe@example.com>

[INFO] Checking existing GPG keys...
[WARN] No existing GPG key found. Generating new key...

gpg: key generation started
gpg: key ABCD1234EF567890 marked as ultimately trusted

[OK] New GPG key created: ABCD1234EF567890
[OK] GPG configured

[INFO] Checking SSH key...
[WARN] Generating SSH key...

Generating public/private ed25519 key pair.
Your identification has been saved in /home/user/.ssh/id_ed25519

[OK] SSH key created
[OK] SSH key loaded into agent

==============================
SSH PUBLIC KEY (ADD TO GIT PROVIDER)
==============================
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHk... john.doe@example.com
==============================

==============================
GPG PUBLIC KEY (ADD TO GIT PROVIDER)
==============================
-----BEGIN PGP PUBLIC KEY BLOCK-----
...
-----END PGP PUBLIC KEY BLOCK-----
==============================

[OK] SETUP COMPLETE
------------------------------------
OS        : fedora
Git User  : John Doe
Email     : john.doe@example.com
GPG Key   : ABCD1234EF567890
SSH Key   : /home/user/.ssh/id_ed25519
Mode      : SAFE
------------------------------------

Workflow:
  git add .
  git commit -S -m "Initial Commit: Project setup"
  git push origin main
```

---

## 🔁 Safe Re-run Behavior

- Existing Git identity is preserved (unless overridden)
- Existing SSH key is reused
- Existing GPG key is reused
- Only missing components are configured

---

## ⚠️ Force Mode Behavior

Using `--force`:

- Generates a new GPG key
- Generates a new SSH key
- Overwrites Git global identity
- Rebinds signing configuration

---

## 🧩 Design Philosophy

- **Idempotency** → safe to run multiple times
- **Minimal disruption** → never overwrites silently
- **Explicit control** → user decides overrides
- **Cross-distro compatibility**
- **Separation of concerns (SSH ≠ GPG ≠ Git)**

---

## 🧠 Common Pitfalls Avoided

- ❌ Repeated GPG passphrase prompts
- ❌ Git push password confusion
- ❌ Duplicate key generation
- ❌ OS-specific assumptions

---

## 📌 Recommendation

After setup, ensure your Git remote uses SSH:

```bash
git remote set-url origin git@github.com:USER/REPO.git
```

---

## 🔮 Future upgrades (optional)

- dotfiles-style security module
- persistent agent systemd services
- multi-profile (work/personal) switching
- CI/CD hardened version

## License

MIT — do whatever you want with it.
