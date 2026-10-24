{ pkgs, lib, config, ... }:

{
  imports = [
    ./omp
  ];

  home.username = "sudhz";
  home.homeDirectory = "/home/sudhz";
  home.stateVersion = "26.05";

  programs.home-manager.enable = true;

  home.sessionPath = [
    "${config.home.homeDirectory}/.local/bin"
  ];

  fonts.fontconfig.enable = true;

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
    dufs

    # Development
    nodejs
    bun
    (python3.withPackages (ps: [ ps.numpy ]))

    # Browser
    chromium
    noto-fonts
    noto-fonts-color-emoji

    # Fonts for OMP's SVG rendering
    freefont_ttf

    # Terminal / build tools
    tmux
    gcc
    gnumake
  ];

  # Keep old Nix generations from filling the VPS disk.
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 7d";
  };

  # Nix's newer systemctl can't talk to Ubuntu's user systemd; use the host one.
  systemd.user.systemctlPath = "/usr/bin/systemctl";

  # Install or update the gh-image GitHub CLI extension.
  home.activation.installLatestGhImage = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    ${pkgs.gh}/bin/gh extension install drogers0/gh-image --force
  '';
}
