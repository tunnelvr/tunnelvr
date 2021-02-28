tool
extends EditorScript

# *******
# Control-Shift X to run this code in the editor
# *******
var regex = RegEx.new()

func _run():
	var x = [2,3,4,5,6,76,7]
	print(x.slice(0, 3), (x.slice(3, len(x)-1)))
