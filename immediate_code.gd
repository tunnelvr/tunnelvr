tool
extends EditorScript

# *******
# Control-Shift X to run this code in the editor
# *******
var regex = RegEx.new()
func _run():
	var x = "10.31.299.7"
	x = x.split(".")
	print(PoolStringArray(x).join("---"))
