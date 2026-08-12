# linux-setup

One-command setup script for a fresh Ubuntu / Debian machine.

## What it installs

| Step | Tool | Detail |
|------|------|--------|
| 1 | System packages | `git`, `curl`, `wget`, `unzip`, `zip`, `gnupg` |
| 1 | Build tools | `build-essential`, `make`, `gcc`, `g++` |
| 1 | Shell | `zsh` |
| 1 | Python | `python3`, `pip`, `venv`, `python3-dev` |
| 1 | Java | `openjdk-21-jdk` |
| 1 | Network / debug | `net-tools`, `dnsutils`, `iputils-ping` |
| 1 | CLI tools | `htop`, `tree`, `jq`, `tmux`, `vim`, `nano` |
| 2 | Claude Desktop | via Anthropic apt repository |
| 3 | nvm + Node.js | nvm `v0.40.3`, Node.js LTS, sourced in `.zshrc` |
| 4 | herdr | via `herdr.dev/install.sh` |
| 5 | oh-my-zsh | non-interactive, zsh set as default shell |

## Requirements

- Ubuntu 22.04+ or Debian 12+
- `x86_64` or `arm64`
- Run as root or a user with sudo

## Usage

```bash
curl -fsSL https://raw.githubusercontent.com/khanhnguyendev/linux-setup/master/setup.sh | sudo bash
```

Or download and run manually:

```bash
wget https://raw.githubusercontent.com/khanhnguyendev/linux-setup/master/setup.sh
chmod +x setup.sh
sudo bash setup.sh
```

## Notes

- Script auto-escalates to `sudo` if not run as root
- All install logs written to `/tmp/*.log` — check them on failure
- Respects `NO_COLOR` env var and non-TTY output (CI-safe)
- nvm and oh-my-zsh install runs as the target user (`ryan`), not root
- Re-running is safe — existing installs are detected and skipped

## Log output style

```
info     | running apt-get update
success  | all packages installed
warn     | oh-my-zsh already present — skipping
error    | failed to download Claude signing key
```
