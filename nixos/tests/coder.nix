import ./make-test-python.nix ({ pkgs, ... }: {
  name = "coder";
  meta = with pkgs.lib.maintainers; {
    maintainers = [ shyim ];
  };

  nodes.machine =
    { pkgs, ... }:
    {
      services.postgresql = {
        enable = true;
        ensureDatabases = [
          "coder"
        ];
        ensureUsers = [{
          name = "coder";
          ensurePermissions = {
            "DATABASE \"coder\"" = "ALL PRIVILEGES";
          };
          }
        ];
      };
      services.coder = {
        enable = true;
        accessUrl = "http://localhost:3000";
        postgresqlUrl = "user=coder database=coder host=/run/postgresql sslmode=disable";
      };
    };

  testScript = ''
    machine.start()
    machine.wait_for_unit("postgresql.service")
    machine.wait_for_unit("coder.service")
    machine.wait_for_open_port(3000)

    machine.succeed("curl --fail http://localhost:3000")
  '';
})
