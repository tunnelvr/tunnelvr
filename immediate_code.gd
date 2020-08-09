tool
extends EditorScript

# *******
# Control-Shift X to run this code in the editor
# *******

const CentrelineStationNode = preload("res://nodescenes/StationNode.tscn")

func _ready():
	print("jjo")
	
func _run():
	var x = IP.get_local_addresses()
	print(x)
	var a = [1,2,
	3]
	print(a)
