{ config, lib, options, pkgs, ... }:

with lib;

let
  cfg = config.services.coder;
in {
  options = {
    services.coder = {
      enable = mkEnableOption (lib.mdDoc "Coder service");

      user = mkOption {
        type = types.str;
        default = "coder";
        description = lib.mdDoc ''
          User under which the coder service runs.
        '';
      };

      group = mkOption {
        type = types.str;
        default = "coder";
        description = lib.mdDoc ''
          Group under which the coder service runs.
        '';
      };

      package = mkOption {
        type = types.package;
        default = pkgs.coder;
        description = lib.mdDoc ''
          Package to use for the service
        '';
        defaultText = literalExpression "pkgs.coder";
      };

      homeDir = mkOption {
        type = types.str;
        description = lib.mdDoc ''
          Home directory for coder user
        '';
        default = "/var/lib/coder";
      };

      listenAddress = mkOption {
        type = types.str;
        description = lib.mdDoc ''
          Listen address
        '';
        default = "127.0.0.1:3000";
      };

      accessUrl = mkOption {
        type = types.nullOr types.str;
        description = lib.mdDoc ''
          Access URL should be a external IP address or domain with DNS records pointing to Coder
        '';
        default = null;
        example = "https://coder.example.com";
      };

      wildcardAccessUrl = mkOption {
        type = types.nullOr types.str;
        description = lib.mdDoc ''
          If you are providing TLS certificates directly to the Coder server, you must use a single certificate for the root and wildcard domains
        '';
        default = null;
        example = "*.coder.example.com";
      };

      postgresqlUrl = mkOption {
        type = types.nullOr types.str;
        description = lib.mdDoc ''
          Coder uses a PostgreSQL database to store users, workspace metadata, and other deployment information
        '';
        default = null;
        example = "postgresql://root:root@database/coder?sslmode=disable";
      };

      tlsCert = mkOption {
        type = types.nullOr types.str;
        description = lib.mdDoc ''
          The path to the TLS certificate.
        '';
        default = null;
      };

      tlsKey = mkOption {
        type = types.nullOr types.str;
        description = lib.mdDoc ''
          The path to the TLS key.
        '';
        default = null;
      };
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.postgresqlUrl == null;
        message = "Coder requires a valid postgres url set to services.coder.postgresqlUrl";
      }
    ];

    systemd.services.coder = {
      description = "Coder - Self-hosted developer workspaces on your infra";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];

      environment = {
        CODER_ACCESS_URL = cfg.accessUrl;
        CODER_WILDCARD_ACCESS_URL = cfg.wildcardAccessUrl;
        CODER_PG_CONNECTION_URL = cfg.postgresqlUrl;
        CODER_ADDRESS = cfg.listenAddress;
        CODER_TLS_ENABLE = optionalString (cfg.tlsCert != null) "1";
        CODER_TLS_CERT_FILE = cfg.tlsCert;
        CODER_TLS_KEY_FILE = cfg.tlsKey;
      };

      serviceConfig = {
        ProtectSystem = "full";
        PrivateTmp = "yes";
        PrivateDevices = "yes";
        SecureBits = "keep-caps";
        AmbientCapabilities = "CAP_IPC_LOCK CAP_NET_BIND_SERVICE";
        CacheDirectory = "coder";
        CapabilityBoundingSet = "CAP_SYSLOG CAP_IPC_LOCK CAP_NET_BIND_SERVICE";
        KillSignal = "SIGINT";
        KillMode = "mixed";
        NoNewPrivileges = "yes";
        Restart = "on-failure";
        RestartSec = 5;
        TimeoutStopSec = 90;
        ExecStart = "${cfg.package}/bin/coder server";
        User = cfg.user;
        Group = cfg.group;
      };
    };

    users.groups.${cfg.group} = { };
    users.users.${cfg.user} = {
      description = "Coder service user";
      group = cfg.group;
      home = cfg.homeDir;
      createHome = true;
      isSystemUser = true;
    };
  };
}
