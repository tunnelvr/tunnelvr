tool
extends EditorScript

# *******
# Control-Shift X to run this code in the editor
# *******
var xx = null

func aa():
	var b = xx
	b.set(0, Vector3(99,99,99))
	print("f", b)
	print("ff", xx)
	
	
func _run():
	var x = PoolVector3Array()
	x.resize(9)
	x[1] = Vector3(0,1,2)
	xx = x
	aa()
	print(x)

