extends Node


func _ready():
	$RayCast.collision_mask = CollisionLayer.CL_CaveWall

func drawwaterlevelmesh(waterflowlevelvectors, nodepoints):
	var raycast = $RayCast
	var arraymesh = ArrayMesh.new()
	var surfaceTool = SurfaceTool.new()
	surfaceTool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for nodename in waterflowlevelvectors:
		var cpt = nodepoints[nodename]
		raycast.transform.origin = cpt
		raycast.cast_to = Vector3(0, -10, 0)
		raycast.force_raycast_update()
		if raycast.is_colliding():
			print("water collision point ", raycast.get_collision_point())
		
		var v = waterflowlevelvectors[nodename]
		var vf = -Vector2(v.x, v.z)*4
		var vfperp = Vector2(vf.y, -vf.x)
		var prevvv = null
		var prevpr = null
		for i in range(11):
			var a = deg2rad((i - 5)/5.0*45)
			var vv = cos(a)*vf - sin(a)*vfperp
			var pr = cpt + Vector3(vv.x, 0, vv.y)
			if i != 0:
				surfaceTool.add_uv(Vector2(0, 0))
				surfaceTool.add_vertex(cpt)
				surfaceTool.add_uv(prevvv)
				surfaceTool.add_vertex(prevpr)
				surfaceTool.add_uv(vv)
				surfaceTool.add_vertex(pr)
			prevvv = vv
			prevpr = pr
	surfaceTool.generate_normals()
	surfaceTool.generate_tangents()
	surfaceTool.commit(arraymesh)
	return arraymesh
