tool
extends EditorScript

# *******
# Control-Shift X to run this code in the editor
# *******

func sortquatfunc(a, b):
	return a.x < b.x or (a.x == b.x and (a.y < b.y or (a.y == b.y and (a.z < b.z or (a.z == b.z and a.w < b.w)))))

func _run():
	var a = {"1":2}
	var b = {"o":9}
	print(a.duplicate())
	for i in range(9, 0, -1):
		print(i)
	
