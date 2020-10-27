tool
extends EditorScript

# *******
# Control-Shift X to run this code in the editor
# *******

func _run():
	var t = str2var("Transform( 0.944959, -0.327188, 0, 0, 0, 0, -0.327188, -0.944959, 0, -21.0524, -0.666294, -24.4351 )")

	var a = Spatial.new()

	# Step 1: Uncomment this line and the the transforms don't match
	a.rotation_degrees = Vector3(-90, 0, 0)

	# Step 2: Then uncomment this line and the the transforms will match again
	print(a.transform)
	
	print("Transforms below should match!")
	print("Transform to apply: ", t)
	a.transform = t
	print("Transform of node:  ", a.transform)

	
