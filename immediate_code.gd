tool
extends EditorScript

# *******
# Control-Shift X to run this code in the editor
# *******

var d = "/home/julian/data/pointclouds/potreetests/outdir/"

func distAABB(aabb : AABB, p):
	var vx = max(aabb.position.x - p.x, p.x - aabb.end.x)
	var vy = max(aabb.position.y - p.y, p.y - aabb.end.y)
	var vz = max(aabb.position.z - p.z, p.z - aabb.end.z)
	return Vector3(max(0, vx), max(0, vy), max(0, vz))

func xx(a):
	a.x += 20
	print(a)
func _run():
	var a = Vector3(10,20,30)
	var b = AABB(Vector3(10,10,10), Vector3(20,30,40))
	print(distAABB(b, Vector3(15,45,555)))
