tool
extends EditorScript

# *******
# Control-Shift X to run this code in the editor
# *******



func _run():
	var pts = [ Vector2(1,0), Vector2(0,0), Vector2(1,1), Vector2(0.5,0.2) ]
	var c = Geometry.convex_hull_2d(PoolVector2Array(pts))
	var d = Geometry.triangulate_delaunay_2d(PoolVector2Array(pts.slice(0,2)))
	print(d)
	
