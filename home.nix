{ pkgs, inputs, lib, ... }:

{
  home.username = "sudhz";
  home.homeDirectory = "/home/sudhz";
  home.stateVersion = "26.05";

  programs.home-manager.enable = true;

  # ~/.local/bin is where the official OMP release binary is installed.
  home.sessionPath = [
    "/home/sudhz/.local/bin"
  ];

  home.packages = with pkgs; [
    # Core CLI
    git
    gh
    curl
    wget
    jq
    ripgrep
    fd
    fzf
    tree
    htop
    unzip
    zip

    # Development
    nodejs_22
    bun
    python3

    # Terminal / build tools
    tmux
    gcc
    gnumake

    # Herdr
    inputs.herdr-nix.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];

  # This VPS only has ~24 GB of storage, so don't allow old Nix
  # generations and unused store paths to accumulate indefinitely.
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 7d";
  };

  # OMP intentionally uses the official prebuilt Linux x64 release rather
  # than OMP's Nix source build. The source build requires a large Rust/Bun
  # build environment and can exhaust this VPS's disk.
  #
  # Every Home Manager activation:
  #   - checks GitHub's latest stable OMP release
  #   - does nothing if that version is already installed
  #   - otherwise downloads the official binary
  #   - verifies its GitHub-published SHA-256 digest
  #   - installs it to ~/.local/bin/omp
  home.activation.installLatestOmp =
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      echo "Checking latest OMP release..."

      RELEASE_JSON="$(
        ${pkgs.curl}/bin/curl \
          -fsSL \
          --connect-timeout 10 \
          --max-time 60 \
          https://api.github.com/repos/can1357/oh-my-pi/releases/latest
      )"

      LATEST_TAG="$(
        printf '%s' "$RELEASE_JSON" |
          ${pkgs.jq}/bin/jq -r '.tag_name'
      )"

      LATEST_VERSION="''${LATEST_TAG#v}"

      ASSET_URL="$(
        printf '%s' "$RELEASE_JSON" |
          ${pkgs.jq}/bin/jq -r \
            '.assets[] | select(.name == "omp-linux-x64") | .browser_download_url'
      )"

      ASSET_DIGEST="$(
        printf '%s' "$RELEASE_JSON" |
          ${pkgs.jq}/bin/jq -r \
            '.assets[] | select(.name == "omp-linux-x64") | .digest'
      )"

      if [ -z "$LATEST_VERSION" ] ||
         [ "$LATEST_VERSION" = "null" ] ||
         [ -z "$ASSET_URL" ] ||
         [ "$ASSET_URL" = "null" ] ||
         [ -z "$ASSET_DIGEST" ] ||
         [ "$ASSET_DIGEST" = "null" ]; then
        echo "Could not determine the latest OMP release."
        exit 1
      fi

      CURRENT=""

      if [ -x "$HOME/.local/bin/omp" ]; then
        CURRENT="$(
          "$HOME/.local/bin/omp" --version 2>/dev/null |
            ${pkgs.gnugrep}/bin/grep -Eo \
              '[0-9]+\.[0-9]+\.[0-9]+' |
            ${pkgs.coreutils}/bin/head -n 1 ||
            true
        )"
      fi

      if [ "$CURRENT" = "$LATEST_VERSION" ]; then
        echo "OMP $CURRENT is already latest."
      else
        echo "Installing OMP ''${CURRENT:-not installed} -> $LATEST_VERSION"

        ${pkgs.coreutils}/bin/mkdir -p "$HOME/.local/bin"

        TMP="$(${pkgs.coreutils}/bin/mktemp)"
        trap '${pkgs.coreutils}/bin/rm -f "$TMP"' EXIT

        ${pkgs.curl}/bin/curl \
          -fsSL \
          --connect-timeout 10 \
          --speed-limit 1024 \
          --speed-time 30 \
          "$ASSET_URL" \
          -o "$TMP"

        EXPECTED_SHA256="''${ASSET_DIGEST#sha256:}"

        ACTUAL_SHA256="$(
          ${pkgs.coreutils}/bin/sha256sum "$TMP" |
            ${pkgs.coreutils}/bin/cut -d ' ' -f 1
        )"

        if [ "$ACTUAL_SHA256" != "$EXPECTED_SHA256" ]; then
          echo "OMP checksum verification failed."
          echo "Expected: $EXPECTED_SHA256"
          echo "Actual:   $ACTUAL_SHA256"
          exit 1
        fi

        ${pkgs.coreutils}/bin/install \
          -m 755 \
          "$TMP" \
          "$HOME/.local/bin/omp"

        echo "Installed OMP $LATEST_VERSION"

        "$HOME/.local/bin/omp" --version
      fi
    '';
}
