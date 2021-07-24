tool
extends EditorScript

# *******
# Control-Shift X to run this code in the editor
# *******

func D_run():
	var a = PoolStringArray()
	a.push_back("d")
	if a:
		print("hji there")


func _run():
	print(Vector3(1,0,0).cross(Vector3(0,1,0)))
	
