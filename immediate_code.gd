tool
extends EditorScript

# *******
# Control-Shift X to run this code in the editor
# *******
var regex = RegEx.new()

func _run():
	var fname = "server/savegame3.res"
	print(fname.split("/")[-1].split(".")[0])
