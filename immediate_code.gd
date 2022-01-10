tool
extends EditorScript

# *******
# Control-Shift X to run this code in the editor
# *******


func _run():
	var from = Vector3(0.2,1,-0.0001)
	var dir = Vector3(0,0,1)
	var a = Vector3(0,0,0)
	var b = Vector3(2,0,0)
	var c = Vector3(0,2,0)

	print(Geometry.ray_intersects_triangle(from, dir, a, b, c))
