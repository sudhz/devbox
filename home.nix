{ pkgs, ... }:

{
  home.username = "sudhz";
  home.homeDirectory = "/home/sudhz";

  # Keep this at the version where this config was first created.
  home.stateVersion = "26.05";

  programs.home-manager.enable = true;

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

    # Terminal/dev utilities
    tmux
    gcc
    gnumake
  ];
}
