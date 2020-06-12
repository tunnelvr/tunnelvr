tool
extends EditorScript

# *******
# Control-Shift X to run this code in the editor
# *******

const CentrelineStationNode = preload("res://nodescenes/StationNode.tscn")

func _ready():
	print("jjo")
	
func _run():
	print("Hello from the Godot Editor!")

	var a = PoolVector3Array()
	a.append(Vector3(2,3,4))
	var b = PoolRealArray()
	b.append_array([1,2,3])
	for c in a:
		print("c", c)
	print(b)
	var x = {1:2, 9:a, "kk":b}
	print(to_json(x))
	print(a)
	print(3091/2405.0)
	return
		
	#var drawnfloor = get_scene().get_node("drawnfloor")

	#var dp = drawnfloor.global_transform.xform(floorpoint)
	#var t = Transform(Vector3(0.082234, 0, 0.996613), Vector3(0, 0, 1), Vector3(-0.896952, 0, 0.074011), Vector3(1.0809, 0, 0))
	#print(p)
	#print(t.xform(t.xform_inv(p)))

	#local_point += Vector3(0.5, -0.5, 0) # X is about 0 to 1, Y is about 0 to -1.
	#return local_point
