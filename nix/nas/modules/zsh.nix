{ config, pkgs, ... }:

let
  starshipConfig = pkgs.writeText "starship.toml" ''
    command_timeout = 500

    [hostname]
    ssh_symbol = "󰋊 "

    [git_status]
    disabled = true

    [git_metrics]
    disabled = true
  '';
in
{
  programs.zsh = {
    enable = true;

    autosuggestions.enable = true;
    syntaxHighlighting.enable = true;

    histSize = 100000;

    ohMyZsh = {
      enable = true;
      plugins = [
        "git"
        "kubectl"
        "helm"
        "extract"
        "common-aliases"
      ];
    };

    shellAliases = {
      k    = "kubectl";
      vim  = "nvim";
      vi   = "nvim";
      history = "fc -il 1";
    };

    interactiveShellInit = ''
      # History
      export HISTFILE="$HOME/.zsh_history"
      setopt EXTENDED_HISTORY
      setopt SHARE_HISTORY
      setopt HIST_EXPIRE_DUPS_FIRST
      setopt HIST_IGNORE_ALL_DUPS
      setopt HIST_SAVE_NO_DUPS
      setopt HIST_REDUCE_BLANKS

      # Misc
      setopt NO_HUP
      setopt NO_CHECK_JOBS
      setopt interactivecomments

      # Key bindings
      bindkey "^[Oc" forward-word
      bindkey "^[Od" backward-word
      bindkey "^U"   backward-kill-line

      # fzf
      source <(fzf --zsh)

      # kubeconfig auto-merge from ~/.kube/conf.d/
      if [ -d "$HOME/.kube/conf.d" ]; then
        for f in "$HOME"/.kube/conf.d/*; do
          KUBECONFIG="''${KUBECONFIG}:''${f}"
        done
        export KUBECONFIG
      fi

      # Starship prompt
      export STARSHIP_CONFIG=${starshipConfig}
      eval "$(starship init zsh)"
    '';
  };

  # Prevent zsh new-user wizard from running on first login
  system.userActivationScripts.zshrc = ''
    if [ ! -f "$HOME/.zshrc" ]; then
      touch "$HOME/.zshrc"
    fi
  '';

  environment.systemPackages = with pkgs; [
    fzf
    starship
    neovim
  ];
}
