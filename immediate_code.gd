tool
extends EditorScript

# *******
# Control-Shift X to run this code in the editor
# *******

func sortquatfunc(a, b):
	return a.x < b.x or (a.x == b.x and (a.y < b.y or (a.y == b.y and (a.z < b.z or (a.z == b.z and a.w < b.w)))))

func _run():
	var pv = str2var("PoolVector2Array( -2.09919, 0.401242, -2.67936, -0.252724, -2.5968, -0.833202, -2.96993, -1.74177, -2.8073, -2.38384, -2.22055, -2.07475, -1.48647, -1.68874, -0.888462, -1.87072, -1.54024, 0, -1.3404, 1.02543 )")
	print(pv)
	var pi = Geometry.triangulate_polygon(pv)
	print(pi)
	pv.invert()
	print(pv)
	var pii = Geometry.triangulate_polygon(pv)
	print(pii)
	
