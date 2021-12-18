tool
extends EditorScript

# *******
# Control-Shift X to run this code in the editor
# *******


func _run():
	var x = "sdfsdf  #potresesd/   "
	print(x.split(":", true, 1)[-1].strip_edges().lstrip("#*"))
