tool
extends EditorScript

# *******
# Control-Shift X to run this code in the editor
# *******
var regex = RegEx.new()

func _run():
	var x = [2,3,4,5,6,76,7]
	print(x.slice(4,1,-1))
	var y = PoolVector2Array()
	y.resize(10)
	y[1] = Vector2(1,2)
	print(y)
