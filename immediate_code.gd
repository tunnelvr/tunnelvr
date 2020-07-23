tool
extends EditorScript

# *******
# Control-Shift X to run this code in the editor
# *******

const CentrelineStationNode = preload("res://nodescenes/StationNode.tscn")

func _ready():
	print("jjo")
	
func _run():
	print("Hello from the Godot Editor!")
	var x = [ ]
	var y = [ ]
	y.push_back(9)
	y.push_back(19)
	x.push_back(y)
	y.push_back(29)
	print(x)	
	print(y)
	return
