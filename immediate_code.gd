tool
extends EditorScript

# *******
# Control-Shift X to run this code in the editor
# *******


func _run():
	var v = Basis().rotated(Vector3(1,0,0), deg2rad(-90))
	print(v)
	var rotzminus90 = Basis(Vector3(1,0,0), Vector3(0,0,-1), Vector3(0,1,0))
	print(rotzminus90)
	var p = Vector3(4000, 60000, 1)
	print(rotzminus90.xform(p))
	
