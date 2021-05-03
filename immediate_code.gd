tool
extends EditorScript

# *******
# Control-Shift X to run this code in the editor
# *******

func _run():
	var x = Transform()
	x = {"aaa":true}
	print(to_json([(x)]))
	
