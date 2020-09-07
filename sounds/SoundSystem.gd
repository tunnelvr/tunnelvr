extends Spatial

# For lots of sounds to decorate everything
# https://opengameart.org/content/51-ui-sound-effects-buttons-switches-and-clicks

func _ready():
	Tglobal.soundsystem = self

func quicksound(sname, position):
	get_node(sname).global_transform.origin = position
	get_node(sname).play()

