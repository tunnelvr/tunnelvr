tool
extends EditorScript

# *******
# Control-Shift X to run this code in the editor
# *******

const CentrelineStationNode = preload("res://nodescenes/StationNode.tscn")

func _ready():
	print("jjo")
	
	
	
func _run():
	var a = [10,20,30]
	a.remove(-1)
	print(a)
