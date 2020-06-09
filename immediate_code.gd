tool
extends EditorScript

# *******
# Control-Shift X to run this code in the editor
# *******

const CentrelineStationNode = preload("res://nodescenes/StationNode.tscn")

func _run():
	print("Hello from the Godot Editor!")
	#var ma = k.mesh.get_mesh_arrays()
	#print(ma)
	var p = Vector3(39.992378, 3.824377, -20.602268)
	var drawnfloor = get_scene().get_node("drawnfloor")
	print(drawnfloor)
	var floorsize = drawnfloor.get_node("MeshInstance").mesh.size
	print(floorsize)
	print(drawnfloor.global_transform)
	print(drawnfloor.get_node("MeshInstance").global_transform)
	#var collider_scale = drawnfloor.mesh.basis
	var floorpoint = drawnfloor.global_transform.xform_inv(p)
	var uvpoint = Vector2(floorpoint.x/floorsize.x + 0.5, floorpoint.z/floorsize.y + 0.5)
	print(floorpoint)
	print(uvpoint)
	print(drawnfloor.scale)
	#local_point /= (collider_scale * collider_scale)
	#local_point += Vector3(0.5, -0.5, 0) # X is about 0 to 1, Y is about 0 to -1.
	#return local_point
