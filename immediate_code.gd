tool
extends EditorScript

# *******
# Control-Shift X to run this code in the editor
# *******

var d = "/home/julian/data/pointclouds/potreetests/outdir/"

func xx(a):
	a.x += 20
	print(a)
func _run():
	var a = Vector3(10,20,30)
	xx(a)
	print(a)
