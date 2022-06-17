tool
extends EditorScript

# *******
# Control-Shift X to run this code in the editor
# *******

var a = [10,20,30]
func _run():
	var t = Transform(Vector3(1,0,0), Vector3(0,0,-1), Vector3(0,1,0), Vector3(0,0,0))
	#print(t.basis.z)
	for i in range(len(a)-1, -1, -1):
		print(i)
		if i == 0:	a.pop_at(i)
	print(a)
