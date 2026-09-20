#!/usr/bin/env bash
set -euo pipefail

DEV_USER="sudhz"
DEVBOX_REPO="sudhz/devbox"
DEVBOX_DIR="/home/$DEV_USER/devbox"

if [ "$(id -u)" -ne 0 ]; then
  echo "Run this bootstrap as root."
  exit 1
fi

echo "==> Checking Ubuntu"
if ! grep -q 'Ubuntu 24.04' /etc/os-release; then
  echo "Warning: this setup was built for Ubuntu 24.04."
fi

echo "==> Installing bootstrap dependencies"
apt update
apt install -y \
  curl \
  git \
  gh \
  sudo \
  xz-utils \
  ca-certificates

echo "==> Configuring 2 GB swap"
if [ ! -f /swapfile ]; then
  fallocate -l 2G /swapfile
  chmod 600 /swapfile
  mkswap /swapfile
fi

if ! swapon --show | grep -q '/swapfile'; then
  swapon /swapfile
fi

grep -q '^/swapfile ' /etc/fstab \
  || echo '/swapfile none swap sw 0 0' >> /etc/fstab

echo "==> Creating $DEV_USER"
if ! id "$DEV_USER" >/dev/null 2>&1; then
  adduser "$DEV_USER"
fi

usermod -aG sudo "$DEV_USER"

echo "==> Installing GitHub SSH keys"
install \
  -d \
  -m 700 \
  -o "$DEV_USER" \
  -g "$DEV_USER" \
  "/home/$DEV_USER/.ssh"

curl -fsSL "https://github.com/$DEV_USER.keys" \
  > "/home/$DEV_USER/.ssh/authorized_keys"

chown \
  "$DEV_USER:$DEV_USER" \
  "/home/$DEV_USER/.ssh/authorized_keys"

chmod 600 "/home/$DEV_USER/.ssh/authorized_keys"

echo "==> Installing multi-user Nix"
if [ ! -x /nix/var/nix/profiles/default/bin/nix ]; then
  curl -L https://nixos.org/nix/install \
    | sh -s -- --daemon
fi

echo "==> Configuring Nix"

mkdir -p /etc/nix

set_nix_option() {
  local key="$1"
  local value="$2"

  if grep -q "^${key} =" /etc/nix/nix.conf 2>/dev/null; then
    sed -i \
      "s|^${key} =.*|${key} = ${value}|" \
      /etc/nix/nix.conf
  else
    echo "${key} = ${value}" >> /etc/nix/nix.conf
  fi
}

set_nix_option \
  "experimental-features" \
  "nix-command flakes"

set_nix_option \
  "auto-optimise-store" \
  "true"

# Herdr publishes a Nix binary cache, so trust it system-wide.
# OMP does NOT need a Nix cache because Home Manager installs its
# official prebuilt release binary instead of compiling it.
set_nix_option \
  "extra-substituters" \
  "https://herdr.cachix.org"

set_nix_option \
  "extra-trusted-public-keys" \
  "herdr.cachix.org-1:3nH7IStRsS0ASfdonA0DCRR2ZrSCeWitZ7Kwew0cR4I="

systemctl restart nix-daemon

echo
echo "==> GitHub login is required for this devbox"

sudo -iu "$DEV_USER" \
  gh auth status >/dev/null 2>&1 \
  || sudo -iu "$DEV_USER" gh auth login

echo "==> Configuring Git identity from GitHub"

sudo -iu "$DEV_USER" bash <<'EOS'
git config --global user.name \
  "$(gh api user --jq '.name // .login')"

git config --global user.email "$(
  gh api user \
    --jq '(.id|tostring) + "+" + .login + "@users.noreply.github.com"'
)"
EOS

echo "==> Cloning devbox configuration"

if [ ! -d "$DEVBOX_DIR/.git" ]; then
  sudo -iu "$DEV_USER" \
    gh repo clone "$DEVBOX_REPO" "$DEVBOX_DIR"
else
  sudo -iu "$DEV_USER" \
    git -C "$DEVBOX_DIR" pull --ff-only
fi

echo "==> Applying Home Manager configuration"

sudo -iu "$DEV_USER" bash -lc "
  nix run github:nix-community/home-manager/release-26.05 -- \
    switch --flake '$DEVBOX_DIR#sudhz'
"

echo
echo "==> Devbox bootstrap complete"
echo
echo "Next login:"
echo "  ssh $DEV_USER@<server-ip>"
