{ pkgs, inputs, lib, config, ... }:

let
  herdrPackage =
    inputs.herdr-nix.packages.${pkgs.stdenv.hostPlatform.system}.default;

  reviewrInstallPath = lib.makeBinPath [
    pkgs.git
    pkgs.bash
    pkgs.curl
    pkgs.coreutils
    pkgs.gnugrep
    pkgs.gnused
    pkgs.gawk
    pkgs.gnutar
    pkgs.gzip
  ];
in
{
  home.username = "sudhz";
  home.homeDirectory = "/home/sudhz";
  home.stateVersion = "26.05";

  programs.home-manager.enable = true;

  home.sessionPath = [
    "${config.home.homeDirectory}/.local/bin"
  ];

  # Herdr
  xdg.configFile."herdr/config.toml".source =
    config.lib.file.mkOutOfStoreSymlink
      "${config.home.homeDirectory}/devbox/herdr/config.toml";

  # Herdr Reviewr
  xdg.configFile."herdr/plugins/config/persiyanov.reviewr/config.toml".source =
    config.lib.file.mkOutOfStoreSymlink
      "${config.home.homeDirectory}/devbox/herdr/reviewr.toml";

  # OMP user configuration.
  # Credentials and runtime state remain local in ~/.omp/agent.
  home.file.".omp/agent/config.yml".source =
    config.lib.file.mkOutOfStoreSymlink
      "${config.home.homeDirectory}/devbox/omp/config.yml";

  home.file.".omp/agent/mcp.json".source =
    config.lib.file.mkOutOfStoreSymlink
      "${config.home.homeDirectory}/devbox/omp/mcp.json";

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
    ffmpeg
    cloudflared

    # Development
    nodejs_22
    bun
    python3

    # Terminal / build tools
    tmux
    gcc
    gnumake
  ] ++ [
    herdrPackage
  ];

  # Keep old Nix generations from filling the VPS disk.
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 7d";
  };

  # Install or update OMP from its official prebuilt Linux x64 release.
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

  # Install Reviewr automatically and ensure its stable launch links exist.
  home.activation.installReviewr =
    lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      HERDR="${herdrPackage}/bin/herdr"

      export PATH="${reviewrInstallPath}:$PATH"

      PLUGIN_JSON="$(
        "$HERDR" plugin list \
          --plugin persiyanov.reviewr \
          --json
      )"

      if printf '%s' "$PLUGIN_JSON" |
        ${pkgs.jq}/bin/jq -e \
          '.result.plugins | any(.plugin_id == "persiyanov.reviewr")' \
        >/dev/null 2>&1; then

        echo "Herdr Reviewr plugin already installed."
      else
        echo "Installing Herdr Reviewr plugin..."

        "$HERDR" plugin install \
          persiyanov/herdr-reviewr \
          --yes

        PLUGIN_JSON="$(
          "$HERDR" plugin list \
            --plugin persiyanov.reviewr \
            --json
        )"
      fi

      REVIEWR_ROOT="$(
        printf '%s' "$PLUGIN_JSON" |
          ${pkgs.jq}/bin/jq -r \
            '.result.plugins[]
             | select(.plugin_id == "persiyanov.reviewr")
             | .plugin_root'
      )"

      REVIEWR_BIN="$REVIEWR_ROOT/bin/herdr-reviewr"

      if [ -z "$REVIEWR_ROOT" ] ||
         [ "$REVIEWR_ROOT" = "null" ] ||
         [ ! -x "$REVIEWR_BIN" ]; then
        echo "Could not locate the installed Herdr Reviewr binary."
        exit 1
      fi

      ${pkgs.coreutils}/bin/mkdir -p \
        "$HOME/.local/bin" \
        "$HOME/.local/state/herdr/plugins/persiyanov.reviewr/bin"

      ${pkgs.coreutils}/bin/ln -sfn \
        "$REVIEWR_BIN" \
        "$HOME/.local/bin/herdr-reviewr"

      ${pkgs.coreutils}/bin/ln -sfn \
        "$REVIEWR_BIN" \
        "$HOME/.local/state/herdr/plugins/persiyanov.reviewr/bin/herdr-reviewr"

      echo "Herdr Reviewr launch links are ready."
    '';
}
