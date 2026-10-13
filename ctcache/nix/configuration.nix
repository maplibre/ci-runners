{
  pkgs,
  modulesPath,
  ...
}:
let
  ctcache = pkgs.callPackage ./package.nix { };
in
{
  imports = [ (modulesPath + "/virtualisation/amazon-image.nix") ];
  system.stateVersion = "26.05";
  networking.hostName = "maplibre-ctcache";
  networking.firewall.allowedTCPPorts = [ 5000 ];
  services.openssh.enable = true;
  services.amazon-ssm-agent.enable = true;
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
  nix.settings.max-jobs = 1;
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };
  services.journald.extraConfig = "SystemMaxUse=512M";
  users.groups.ctcache = { };
  users.users.ctcache = {
    isSystemUser = true;
    group = "ctcache";
  };
  systemd.tmpfiles.rules = [ "d /etc/ctcache 0700 root root -" ];
  systemd.services.ctcache = {
    description = "MapLibre clang-tidy cache";
    wantedBy = [ "multi-user.target" ];
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    unitConfig.ConditionPathExists = "/etc/ctcache/auth-key";
    environment = {
      CTCACHE_WEBROOT = "/var/lib/ctcache";
      # Matplotlib renders dashboard charts and needs a writable font/config cache.
      MPLCONFIGDIR = "/var/cache/ctcache/matplotlib";
    };
    preStart = ''
      ln -sfn ${ctcache}/share/ctcache/static /var/lib/ctcache/static
    '';
    script = ''
      exec ${ctcache}/bin/clang-tidy-cache-server \
        --port 5000 --save-path /var/lib/ctcache/index.json.gz \
        --save-interval 60 --max-cache-size 80 \
        --auth-key-writes "$(cat "$CREDENTIALS_DIRECTORY/auth-key")"
    '';
    serviceConfig = {
      User = "ctcache";
      Group = "ctcache";
      StateDirectory = "ctcache";
      CacheDirectory = "ctcache";
      WorkingDirectory = "/var/lib/ctcache";
      LoadCredential = "auth-key:/etc/ctcache/auth-key";
      Restart = "on-failure";
      RestartSec = 5;
      TimeoutStopSec = 30;
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      ProtectKernelTunables = true;
      ProtectControlGroups = true;
      RestrictSUIDSGID = true;
      UMask = "0077";
    };
  };
}
