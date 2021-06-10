This repository is a **Flake**. A Flake is something that will be consumed by
another system, in our case a server on Hetzner. Thus, we have the concept of
them/us (like git branches), or of a producer/consumer.

This tunnelvr repository has a `flake.nix` at its root, it provides a
`nixosModule` named `tunnelvr` which has a systemd service. In this context, it
is the producer, which will be consumed by the Hetzner server.

Our Hetzner server will only do what this tunnelvr repository's `flake.nix`
tells it to. Nothing more nothing less.

# Cheatsheet

### Follow the log of tunnelvr on the Hetzner server

```
journalctl -fu tunnelvr
```

### Updating the `flake.lock`

#### TunnelVR (Producer)

1. In `flake.nix`, modify the `inputs.tunnelvr.url` to refer to the new tag you
   want to be available to all consumers of this flake.

    ###### Before:
    ```nix
    {
      inputs = {
        tunnelvr = {
          url = "github:goatchurchprime/tunnelvr/v0.5.1";
          flake = false;
        };
      };
    }
    ```
    ###### After:
    ```nix
    {
      inputs = {
        tunnelvr = {
          url = "github:goatchurchprime/tunnelvr/v0.6.2";
          flake = false;
        };
      };
    }
    ```

2. Run `nix flake lock --update-input tunnelvr`

#### Hetzner (Consumer)

This will update tunnelvr from the perspective of the server and make any
changes to the [flake.nix](flake.nix) of this repo true. For example, if you
have changed the version or source of Godot by modifying `inputs.godot.url`, it
will recompile Godot and use it for running the TunnelVR pck file.

1. `nixos-rebuild switch --update-input tunnelvr`
