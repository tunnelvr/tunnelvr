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
	# ajajaja (2.702797, 0.000828, -6.352633)  (2.297801, 0.000828, -6.319214)
	# 0.082234, 0, -0.896952, 0, 1, 0, 0.996613, 0, 0.074011 - 1.0809, 0, 0
	#var t = Transform(0.082234, 0, -0.896952, 0, 1, 0, 0.996613, 0, 0.074011 - 1.0809, 0, 0)
	#var t = Transform(Vector3(0.082234, 0, 0.996613), Vector3(0, 0, 1), Vector3(-0.896952, 0, 0.074011).normalized(), Vector3(0, 0, 0))
	#var t = Transform(Vector3(2,0,0), Vector3(0,1,0), Vector3(0,0,1), Vector3(0,0,0))
	print(3091/2405.0)
	var t = Transform(Vector3(0.082234, 0, 0.996613), Vector3(0, 1, 0), Vector3(-0.896952, 0, 0.074011), Vector3(0, 0, 0))
	var it = t.affine_inverse()
	print(it)
	var p = Vector3(2.702797, 0.000828, -6.352633)
	print(p)
	print(it.xform(t.xform(p)))
	return
		
	var drawnfloor = get_scene().get_node("drawnfloor")
	var floorpoint = drawnfloor.global_transform.xform_inv(p)
	var dp = drawnfloor.global_transform.xform(floorpoint)
	#var t = Transform(Vector3(0.082234, 0, 0.996613), Vector3(0, 0, 1), Vector3(-0.896952, 0, 0.074011), Vector3(1.0809, 0, 0))
	#print(p)
	#print(t.xform(t.xform_inv(p)))

	#local_point += Vector3(0.5, -0.5, 0) # X is about 0 to 1, Y is about 0 to -1.
	#return local_point
