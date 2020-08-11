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
	var v = {"a":[1,3,4], "b":[98, 34, 1]}	
	for s in v.values():
		s.sort()
	for s in v.values():
		print(s)
	
