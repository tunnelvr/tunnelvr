tool
extends EditorScript

# *******
# Control-Shift X to run this code in the editor
# *******


func _run():

	var a = Vector3(0,0,0)
	var b = Vector3(2,0,0)
	var c = Vector3(1,1,0)
	var pre_a = a - (c-a)*5
	var post_b = b + (b-c)*5
	for i in range(11):
		var weight = i/10.0
		print(a.cubic_interpolate(b, pre_a, post_b, weight))
