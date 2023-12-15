{ godot3-headless, godot-source }:
godot3-headless.overrideAttrs (_: {
  version = godot-source.rev;
  src = godot-source;
})
