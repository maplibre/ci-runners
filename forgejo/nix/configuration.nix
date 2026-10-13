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
  # OpenTofu deploys this configuration; never reconfigure from user-data.
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

  # The EC2 udev rules name the volume after its attachment device. A blank volume is
  # formatted on first mount. nofail keeps SSH and SSM reachable without the volume.
  fileSystems.${dataDir} = {
    device = "/dev/sdf";
    fsType = "ext4";
    autoFormat = true;
    options = [
      "nofail"
      "x-systemd.device-timeout=5min"
    ];
  };

  # A dedicated user gives clone URLs of the form git@git.maplibre.org:owner/repo.
  # Fixed IDs keep the data volume's ownership valid on a replacement instance.
  users.users.git = {
    uid = 995;
    home = cfg.stateDir;
    useDefaultShell = true;
    group = "git";
    isSystemUser = true;
  };
  users.groups.git.gid = 992;

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
  services.postgresql.dataDir = postgresDataDir;
  systemd.tmpfiles.rules = [ "d ${postgresDataDir} 0700 postgres postgres -" ];
  # Boot-time tmpfiles may run before the volume is mounted, so apply the data
  # volume's rules again once it is, before the services that use it.
  systemd.services.data-directories =
    let
      services = [
        "postgresql.service"
        "forgejo-secrets.service"
        "forgejo.service"
      ];
    in
    {
      description = "Create directories on the data volume";
      unitConfig.RequiresMountsFor = [ dataDir ];
      requiredBy = services;
      before = services;
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${config.systemd.package}/bin/systemd-tmpfiles --create --prefix=${dataDir}";
      };
    };

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
