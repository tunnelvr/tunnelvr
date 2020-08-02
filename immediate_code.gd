tool
extends EditorScript

# *******
# Control-Shift X to run this code in the editor
# *******

const CentrelineStationNode = preload("res://nodescenes/StationNode.tscn")

func _ready():
	print("jjo")
	
func fa(a, b):
	
	print(a, b)
	return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1])
	
	
func _run():
	var a = [ ]
	a.append(10)
	a.append(20)
	a.append(30)
	print(a)
	print(a.pop_back())
	print(a)		
