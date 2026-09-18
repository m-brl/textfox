inputs:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (pkgs.stdenv.hostPlatform) system;
  package = inputs.self.packages.${system}.default;
  firefoxConfigDir =
    "${config.programs.firefox.configPath}/"
    + (lib.optionalString pkgs.stdenv.hostPlatform.isDarwin "Profiles/");
  librewolfConfigDir =
    "${config.programs.librewolf.configPath}/"
    + (lib.optionalString pkgs.stdenv.hostPlatform.isDarwin "Profiles/");

  cfg = config.textfox;
  configDir = if cfg.librewolf then librewolfConfigDir else firefoxConfigDir;
in
{

  imports = [
    ./options.nix
    (lib.mkChangedOptionModule [ "textfox" "profile" ] [ "textfox" "profiles" ] (
      config:
      let
        profile = lib.getAttrFromPath [ "textfox" "profile" ] config;

      in
      [ profile ]
    ))
  ];

  options.textfox = {
    librewolf = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to apply the textfox configuration to Librewolf instead of Firefox";
    };

    profiles = lib.mkOption {
      type = with lib.types; listOf str;
      default = [ ];
      description = "List of Firefox profiles to apply the textfox configuration to";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.firefox = {
      enable = true;
      profiles = lib.mkMerge (
        map (profile: {
          "${profile}" = {
            extraConfig = builtins.readFile "${package}/user.js";
            containersForce = true;
            userChrome = lib.mkBefore (builtins.readFile "${package}/chrome/userChrome.css");
          };
        }) cfg.profiles
      );
    };

    home.file = lib.mkMerge (
      map (profile: {
        "${configDir}${profile}/chrome" = {
          source = pkgs.lib.cleanSourceWith {
            src = "${package}/chrome";
            filter = path: type: !(type == "regular" && baseNameOf path == "userChrome.css");
          };
          recursive = true;
        };
        "${configDir}${profile}/chrome/config.css" = {
          text = cfg.configCss;
        };
      }) cfg.profiles
    );
  };
}
