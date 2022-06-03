tool
extends EditorScript

# *******
# Control-Shift X to run this code in the editor
# *******


func _run():
	var t = Transform(Vector3(1,0,0), Vector3(0,0,-1), Vector3(0,1,0), Vector3(0,0,0))
	print(t.basis.z)
