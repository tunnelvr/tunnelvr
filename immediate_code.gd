tool
extends EditorScript

# *******
# Control-Shift X to run this code in the editor
# *******

func _ready():
	print("jjo")
	
func t(x=null):
	print("x=", x)

func _run():
	var x = IP.get_local_addresses()
	var defaultfloortexture = "res://surveyscans/DukeStResurvey-drawnup-p3.jpg"
	var r = load(defaultfloortexture) 
	print(r)
	print(r.get_height())
	print(r.get_width())
