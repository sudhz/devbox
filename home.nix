{ pkgs, inputs, ... }:

{
  home.username = "sudhz";
  home.homeDirectory = "/home/sudhz";

  # Keep this at the version where this config was first created.
  home.stateVersion = "26.05";

  programs.home-manager.enable = true;

  home.packages = with pkgs; [
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

    nodejs_22
    bun
    python3

    tmux
    gcc
    gnumake

    inputs.herdr-nix.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];
}
