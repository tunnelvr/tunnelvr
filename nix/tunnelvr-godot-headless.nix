{ godot-headless, godot-source }:
godot-headless.overrideAttrs (_: {
  version = godot-source.rev;
  src = godot-source;
})
