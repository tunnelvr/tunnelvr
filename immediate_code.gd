tool
extends EditorScript

# *******
# Control-Shift X to run this code in the editor
# *******

func _run():
	var x = {"a":Transform()}
	x["a"].origin = Vector3(1,2,3)
	var y = x.duplicate()
	print(x["a"] == y["a"])
	y["a"].origin = Vector3(4,5,6)
	print(x["a"] == y["a"])
