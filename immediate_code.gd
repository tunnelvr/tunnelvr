tool
extends EditorScript

# *******
# Control-Shift X to run this code in the editor
# *******


func _run():
	var p0 = Vector3(0,0,0)
	var p1 = Vector3(1,0,0)
	var p2 = Vector3(0,1,0)
	var f = Vector3(0.2,0.5,-100)
	var v = Vector3(0,0,-0.2)
	print(Geometry.ray_intersects_triangle(f, v, p0, p1, p2))
