tool
extends EditorScript

# *******
# Control-Shift X to run this code in the editor
# *******

func sortquatfunc(a, b):
	return a.x < b.x or (a.x == b.x and (a.y < b.y or (a.y == b.y and (a.z < b.z or (a.z == b.z and a.w < b.w)))))

func _run():
	var a = Quat(2,2,3,4)
	var b = Quat(2,2,3,1)

	#a = Vector3(a.x, a.y, a.z)
	#b = Vector3(b.x, b.y, b.z)

	var c = [a, b]
	#print(a < b)
	print(c.sort_custom(self, "sortdfunc"))
	print(c)
	
