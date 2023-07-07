{ godot-headless, godot_4, godot-source }:
godot-headless.overrideAttrs (_: {
  godot = godot_4;
  version = godot-source.rev;
  src = godot-source;
})
