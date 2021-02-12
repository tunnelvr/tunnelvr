tool
extends EditorScript

# *******
# Control-Shift X to run this code in the editor
# *******
var regex = RegEx.new()

func _run():
	var s = ["asd", "sdf", "999"]
	s = []
	var g = PoolStringArray(s).join("\n")
	print([g])
	
