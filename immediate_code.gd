tool
extends EditorScript

# *******
# Control-Shift X to run this code in the editor
# *******
var regex = RegEx.new()
func _run():
	var x = "sdf_33_66"
	print(int(x.split("_")[1]))
