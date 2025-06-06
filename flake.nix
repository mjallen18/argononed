{
  description = "Flake for Argon One Daemon (argononed) on aarch64";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
        argononedPkg = pkgs.callPackage ./OS/nixos/pkg.nix {
          inherit (pkgs) dtc installShellFiles;
          logLevel = 5;
        };
      in {
        packages.default = argononedPkg;

        nixosModules.argononed = { config, lib, pkgs, ... }:
          with lib;
          let
            cfg = config.services.argononed;
          in {
            options.services.argononed = {
              enable = mkEnableOption "Argon One fan and button daemon";

              package = mkOption {
                type = types.package;
                default = pkgs.argononed;
                defaultText = literalExpression "pkgs.argononed";
                description = "argononed package to use.";
              };

              configFile = mkOption {
                type = types.path;
                default = pkgs.writeText "argononed.conf" ''
                  55=10
                  60=55
                  65=100
                '';
                description = "argononed.conf content for fan control thresholds.";
              };
            };

            config = mkIf cfg.enable {
              users.users.argononed = {
                isSystemUser = true;
                group = "argononed";
              };

              users.groups.argononed = {};

              environment.etc."argononed.conf".source = cfg.configFile;

              systemd.services.argononed = {
                description = "Argon One Fan and Button Daemon";
                wantedBy = [ "multi-user.target" ];
                after = [ "network.target" ];
                serviceConfig = {
                  ExecStart = "${cfg.package}/bin/argononed";
                  ExecStopPost = "${cfg.package}/bin/argonone-shutdown";
                  Restart = "on-failure";
                  User = "argononed";
                  Group = "argononed";
                  Type = "simple";
                };
              };

              services.dbus.enable = true;
              services.logind.enable = mkDefault true;
            };
          };
      });
}
