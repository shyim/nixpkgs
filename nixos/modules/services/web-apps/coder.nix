{ config, lib, options, pkgs, ... }:

with lib;

let
  cfg = config.services.coder;
in {
  options = {
    services.coder = {
      enable = mkEnableOption (lib.mdDoc "Coder enable the service");

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

      virtualHost = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = lib.mdDoc ''
          Name of the nginx virtualhost to use and setup. If null, do not setup any virtualhost.
        '';
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
    systemd.services.coder = let
      # see https://github.com/coder/coder/issues/4731
      pgCtl = pkgs.writeScript "pg_ctl" ''
        #!${pkgs.bash}/bin/bash

        exec ${pkgs.postgresql_14}/bin/pg_ctl "$@" -o '--unix_socket_directories=${cfg.homeDir}'
      '';
    in {
      description = "Coder - Self-hosted developer workspaces on your infra";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];

      preStart = ''
        mkdir -p ${cfg.homeDir}/.config/coderv2/postgres/bin/bin
        rm -f ${cfg.homeDir}/.config/coderv2/postgres/bin/bin/initdb
        rm -f ${cfg.homeDir}/.config/coderv2/postgres/bin/bin/pg_ctl
        rm -f ${cfg.homeDir}/.config/coderv2/postgres/bin/bin/postgres
        rm -f ${cfg.homeDir}/.config/coderv2/postgres/bin/share
        ln -s ${pkgs.postgresql_14}/bin/initdb ${cfg.homeDir}/.config/coderv2/postgres/bin/bin/initdb
        ln -s ${pgCtl} ${cfg.homeDir}/.config/coderv2/postgres/bin/bin/pg_ctl
        ln -s ${pkgs.postgresql_14}/bin/postgres ${cfg.homeDir}/.config/coderv2/postgres/bin/bin/postgres
        ln -s ${pkgs.postgresql_14}/share ${cfg.homeDir}/.config/coderv2/postgres/bin/
      '';

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
        Type = "notify";
        ProtectSystem = "full";
        PrivateTmp = "yes";
        PrivateDevices = "yes";
        SecureBits = "keep-caps";
        AmbientCapabilities="CAP_IPC_LOCK CAP_NET_BIND_SERVICE";
        CacheDirectory="coder";
        CapabilityBoundingSet="CAP_SYSLOG CAP_IPC_LOCK CAP_NET_BIND_SERVICE";
        KillSignal="SIGINT";
        KillMode="mixed";
        NoNewPrivileges="yes";
        Restart ="on-failure";
        RestartSec=5;
        TimeoutStopSec=90;
        ExecStart = ''
          ${cfg.package}/bin/coder server
        '';
        User = "coder";
        Group = "coder";
      };
    };

    users.users.coder = {
      description = "Coder service user";
      group = "coder";
      home = cfg.homeDir;
      createHome = true;
      isSystemUser = true;
    };
    users.groups.coder = {};

    services.nginx = mkIf (cfg.virtualHost != null) {
      enable = true;
      recommendedProxySettings = true;
      virtualHosts.${cfg.virtualHost} = {
        locations."/".proxyPass = "http://${cfg.listenAddress}";
      };
    };
  };
}
