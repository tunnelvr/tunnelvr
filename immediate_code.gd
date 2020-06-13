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
	var inwardvec = Vector3(0, 0.002, -1) 
	var iv0 = inwardvec.cross(Vector3(0, 0, 1)).normalized()
	if iv0.length_squared() == 0:
		iv0 = inwardvec.cross(Vector3(1, 0, 0))
	var iv1 = iv0.cross(inwardvec)
	print(iv0, iv1)

#		var vec = Vector2(vec3.x, vec3.z)
#		Lpathvectorseq[i0].append([vec.angle(), i])
#		Lpathvectorseq[i1].append([(-vec).angle(), i])

	return
