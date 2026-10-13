{
  config,
  lib,
  pkgs,
  modulesPath,
  ...
}:
let
  domain = "git.maplibre.org";
  # Separate EBS volume holding repositories and the database. User-data formats it once.
  dataDir = "/data";
  cfg = config.services.forgejo;
  postgresDataDir = "${dataDir}/postgresql/${config.services.postgresql.package.psqlSchema}";
in
{
  imports = [ (modulesPath + "/virtualisation/amazon-image.nix") ];
  system.stateVersion = "26.05";
  networking.hostName = "maplibre-forgejo";
  networking.firewall.allowedTCPPorts = [
    22
    80
    443
  ];
  networking.firewall.allowedUDPPorts = [ 443 ];
  # User-data only bootstraps. Re-running it on every boot would revert later deploys.
  virtualisation.amazon-init.enable = false;
  services.amazon-ssm-agent.enable = true;
  # Port 22 is public because Git uses it, so only keys are accepted.
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
    };
  };
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };
  services.journald.extraConfig = "SystemMaxUse=512M";

  # nofail keeps SSH and SSM reachable without the volume; the services below wait for it.
  fileSystems.${dataDir} = {
    device = "/dev/disk/by-label/forgejo-data";
    fsType = "ext4";
    options = [
      "nofail"
      "x-systemd.device-timeout=5min"
    ];
  };

  # A dedicated user gives clone URLs of the form git@git.maplibre.org:owner/repo.
  users.users.git = {
    home = cfg.stateDir;
    useDefaultShell = true;
    group = "git";
    isSystemUser = true;
  };
  users.groups.git = { };

  services.forgejo = {
    enable = true;
    user = "git";
    group = "git";
    stateDir = "${dataDir}/forgejo";
    database = {
      type = "postgres";
      # Peer authentication requires the database and role to match the system user.
      name = "git";
      user = "git";
    };
    lfs.enable = true;
    settings = {
      DEFAULT.APP_NAME = "MapLibre Git";
      server = {
        DOMAIN = domain;
        ROOT_URL = "https://${domain}/";
        HTTP_ADDR = "127.0.0.1";
        HTTP_PORT = 3000;
      };
      service.DISABLE_REGISTRATION = true;
      session.COOKIE_SECURE = true;
      log.LEVEL = "Warn";
    };
  };
  systemd.services.forgejo.unitConfig.RequiresMountsFor = [ dataDir ];
  systemd.services.forgejo-secrets.unitConfig.RequiresMountsFor = [ dataDir ];

  services.postgresql.dataDir = postgresDataDir;
  systemd.tmpfiles.rules = [ "d ${postgresDataDir} 0700 postgres postgres -" ];

  services.caddy = {
    enable = true;
    virtualHosts.${domain}.extraConfig = ''
      reverse_proxy 127.0.0.1:3000
    '';
  };

  # Runs Forgejo's admin CLI as the service user, e.g. `forgejo-admin user list`.
  environment.systemPackages = [
    (pkgs.writeShellScriptBin "forgejo-admin" ''
      exec ${pkgs.util-linux}/bin/runuser -u ${cfg.user} -- env \
        FORGEJO_WORK_DIR=${cfg.stateDir} FORGEJO_CUSTOM=${cfg.customDir} \
        ${lib.getExe cfg.package} admin "$@"
    '')
  ];
}
