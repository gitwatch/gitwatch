{
  lib,
  pkgs,
  config,
  ...
}:
let
  gitwatch = pkgs.callPackage ./gitwatch.nix { };
  mkSystemdService =
    name: cfg:
    lib.nameValuePair "gitwatch-${name}" (
      let
        getvar = flag: var: if cfg."${var}" != null then "${flag} ${cfg."${var}"}" else "";
        branch = getvar "-b" "branch";
        fetcher = if cfg.remote == null then "true" else '''';
      in
      {
        inherit (cfg) enable;
        after = [ "network-online.target" ];
        wantedBy = [ "multi-user.target" ];
        description = "gitwatch for ${name}";
        path = with pkgs; [
          gitwatch
          git
          openssh
        ];
        script = ''
          if [ -n "${cfg.remote}" ] && ! [ -d "${cfg.path}" ]; then
            git clone ${branch} "${cfg.remote}" "${cfg.path}"
          fi
          ${fetcher}
          gitwatch ${getvar "-r" "remote"} ${getvar "-m" "message"} ${branch} ${cfg.path}
        '';
        serviceConfig.User = cfg.user;
      }
    );
in
{
  options.services.gitwatch = lib.mkOption {
    description = ''
      A set of git repositories to watch for.
 See
      [gitwatch](https://github.com/gitwatch/gitwatch) for more.
    '';
    default = { };
    example = {
      my-repo = {
        enable = true;
        user = "user";
        path = "/home/user/watched-project";
        remote = "git@github.com:me/my-project.git";
        message = "Auto-commit by gitwatch on %d";
      };
      disabled-repo = {
        enable = false;
        user = "user";
        path = "/home/user/disabled-project";
        remote = "git@github.com:me/my-old-project.git";
        branch = "autobranch";
      };
    };
    type =
      with lib.types;
      attrsOf (submodule {
        options = {
          enable = lib.mkEnableOption "watching for repo";
          path = lib.mkOption {
            description = "The path to repo in local machine";
            type = str;
          };
          user = lib.mkOption {
            description = "The name of services's user";
            type = str;
            default = "root";
          };
          remote = lib.mkOption {
            description = "Optional url of remote repository";
            type = nullOr str;
            default = null;
          };
          message = lib.mkOption {
            description = "Optional message to use in as commit message.";
            type = nullOr str;
            default = null;
          };
          branch = lib.mkOption {
            description = "Optional branch in remote repository";
            type = nullOr str;
            default = null;
          };
        };
      });
  };
  config.systemd.services = lib.mapAttrs' mkSystemdService config.services.gitwatch;
}
