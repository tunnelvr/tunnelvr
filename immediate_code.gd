tool
extends EditorScript

# *******
# Control-Shift X to run this code in the editor
# *******

const CentrelineStationNode = preload("res://nodescenes/StationNode.tscn")

func _ready():
	print("jjo")
	
func t(x=null):
	print("x=", x)

func _run():
	var x = IP.get_local_addresses()
	#var r = load("res://surveyscans/DukeStResurvey-drawnup-p3.jpg")
	#print(r)
	var s = "sdfs.sdfs.ddd."
	print(s.replace(".", ","))
