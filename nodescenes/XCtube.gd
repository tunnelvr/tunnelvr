extends Spatial

var otxcdIndex0 : int
var otxcdIndex1 : int
var xcdrawinglink = [ ]  # [ nodepoints_ifrom0, nodepoints_ito0, nodepoints_ifrom1, nodepoints_ito1, ... ]
const linewidth = 0.02

func xcapplyonepath(xcn0, xcn1):
	print("xcapplyonepathxcapplyonepath-pre", xcn0, xcn1, xcdrawinglink)
	for j in range(0, len(xcdrawinglink), 2):
		if xcdrawinglink[j] == xcn0.otIndex and xcdrawinglink[j+1] == xcn1.otIndex:
			xcdrawinglink.remove(j+1)
			xcdrawinglink.remove(j)
			xcn0 = null
			break
	if xcn0 != null:
		xcdrawinglink.append(xcn0.otIndex)
		xcdrawinglink.append(xcn1.otIndex)
	var xcdrawings = xcn1.get_parent().get_parent().get_parent()
	print("xcapplyonepathxcapplyonepath-post", xcdrawinglink)
	assert ((len(xcdrawinglink)%2) == 0)
	updatexclinkpaths(xcdrawings)

func removetubenodepoint(otxcdIndex, xcnIndex, xcnIndexE):
	# this function very closely bound with the tail copy onto deleted one method
	assert ((otxcdIndex == otxcdIndex0) or (otxcdIndex == otxcdIndex1))
	var m = 0 if otxcdIndex == otxcdIndex0 else 1
	print("rrremoveotnodepoint-pre ", otxcdIndex, " ", xcnIndex, xcdrawinglink)
	for j in range(len(xcdrawinglink) - 2, -1, -2):
		if xcdrawinglink[j+m] == xcnIndex:
			xcdrawinglink[j] = xcdrawinglink[-2]
			xcdrawinglink[j+1] = xcdrawinglink[-1]
			xcdrawinglink.resize(len(xcdrawinglink) - 2)
		elif xcdrawinglink[j+m] == xcnIndexE:
			xcdrawinglink[j+m] = xcnIndex
	print("rrremoveotnodepoint-post ", otxcdIndex, " ", xcnIndex, xcdrawinglink)

		
func updatexclinkpaths(xcdrawings):
	var surfaceTool = SurfaceTool.new()
	surfaceTool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var xcdrawing0 = xcdrawings.get_child(otxcdIndex0)
	var xcdrawing1 = xcdrawings.get_child(otxcdIndex1)
	print("llll", xcdrawings, xcdrawing0, xcdrawing1, xcdrawinglink)
	assert ((len(xcdrawinglink)%2) == 0)
	for j in range(0, len(xcdrawinglink), 2):
		#var p0 = xcdrawing0.nodepoints[xcdrawinglink[j]]
		#var p1 = xcdrawing1.nodepoints[xcdrawinglink[j+1]]
		var p0 = xcdrawing0.get_node("XCnodes").get_child(xcdrawinglink[j]).global_transform.origin
		var p1 = xcdrawing1.get_node("XCnodes").get_child(xcdrawinglink[j+1]).global_transform.origin
		print("jjjjuj", j, p0, p1)
		var perp = linewidth*Vector2(-(p1.z - p0.z), p1.x - p0.x).normalized()
		var p0left = p0 - Vector3(perp.x, 0, perp.y)
		var p0right = p0 + Vector3(perp.x, 0, perp.y)
		var p1left = p1 - Vector3(perp.x, 0, perp.y)
		var p1right = p1 + Vector3(perp.x, 0, perp.y)
		surfaceTool.add_vertex(p0left)
		surfaceTool.add_vertex(p1left)
		surfaceTool.add_vertex(p0right)
		surfaceTool.add_vertex(p0right)
		surfaceTool.add_vertex(p1left)
		surfaceTool.add_vertex(p1right)
	surfaceTool.generate_normals()
	$PathLines.mesh = surfaceTool.commit()
	print("ususxxxxc ", len($PathLines.mesh.get_faces()), " ", len($PathLines.mesh.get_faces())) #surfaceTool.generate_normals()
	#updateworkingshell()



func add_uvvertex(surfaceTool, xcnodes, poly, ila, i, floorsize, dfinv):
	var pt = xcnodes.get_child(poly[(ila+i)%len(poly)]).global_transform.origin
	var afloorpoint = dfinv.xform(pt)
	var uvpt = Vector2(afloorpoint.x/floorsize.x + 0.5, afloorpoint.z/floorsize.y + 0.5)
	surfaceTool.add_uv(uvpt)
	surfaceTool.add_vertex(pt)
	
func fa(a, b):
	return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1])

func maketubeshell(drawnfloor):
	var floorsize = drawnfloor.get_node("MeshInstance").mesh.size
	var dfinv = drawnfloor.global_transform.affine_inverse()
	
	var xcdrawings = get_node("../../XCdrawings")
	var xcdrawing0 = xcdrawings.get_child(otxcdIndex0)
	var xcdrawing1 = xcdrawings.get_child(otxcdIndex1)
	var polys0 = xcdrawing0.makexcdpolys()  # arrays of indexes to nodes ending with [Nsinglenodes, orientation]
	var polys1 = xcdrawing1.makexcdpolys()  # arrays of indexes to nodes ending with [Nsinglenodes, orientation]
	
	# for now just the single good polygon
	var poly0 = null
	for poly in polys0:
		if poly[-2] == 1000 and poly[-1]:
			poly0 = poly.slice(0, len(poly)-3)
	var poly1 = null
	for poly in polys1:
		if poly[-2] == 1000 and poly[-1]:
			poly1 = poly.slice(0, len(poly)-3)
	print("opopolys", poly0, poly1)
	if xcdrawing0.global_transform.basis.z.dot(xcdrawing1.global_transform.basis.z) < 0:
		poly1.invert()
		print("reversssing poly1", xcdrawing0.global_transform.basis.z, xcdrawing1.global_transform.basis.z, poly1)
		
	# get all the connections in here between the polygons but in the right order
	var ila = [ ]  # [ [ il0, il1 ] ]
	for j in range(0, len(xcdrawinglink), 2):
		var il0 = poly0.find(xcdrawinglink[j])
		var il1 = poly1.find(xcdrawinglink[j+1])
		if il0 != -1 and il1 != -1:
			ila.append([il0, il1])
	if len(ila) == 0:
		return null
	ila.sort_custom(self, "fa")
	print("ilililia", xcdrawinglink, ila)
	
	var surfaceTool = SurfaceTool.new()
	surfaceTool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var xcnodes0 = xcdrawing0.get_node("XCnodes")
	var xcnodes1 = xcdrawing1.get_node("XCnodes")
	for i in range(len(ila)):
		var ila0 = ila[i][0]
		var ila0N = ila[i+1][0] - ila0  if i < len(ila)-1  else len(poly0) + ila[0][0] - ila0 
		var ila1 = ila[i][1]
		var ila1N = ila[(i+1)%len(ila)][1] - ila1
		if ila1N < 0 or len(ila) == 1:   # there's a V-shaped case where this isn't good enough
			ila1N += len(poly1)
		print("  iiilla ", [ila0, ila0N, ila1, ila1N])

		var acc = -ila0N/2  if ila0N>=ila1N  else  ila1N/2
		var i0 = 0
		var i1 = 0
		while i0 < ila0N or i1 < ila1N:
			if acc < 0:
				acc += ila1N
				add_uvvertex(surfaceTool, xcnodes0, poly0, ila0, i0, floorsize, dfinv)
				add_uvvertex(surfaceTool, xcnodes1, poly1, ila1, i1, floorsize, dfinv)
				i0 += 1
				add_uvvertex(surfaceTool, xcnodes0, poly0, ila0, i0, floorsize, dfinv)
			else:
				acc -= ila0N
				add_uvvertex(surfaceTool, xcnodes0, poly0, ila0, i0, floorsize, dfinv)
				add_uvvertex(surfaceTool, xcnodes1, poly1, ila1, i1, floorsize, dfinv)
				i1 += 1
				add_uvvertex(surfaceTool, xcnodes1, poly1, ila1, i1, floorsize, dfinv)
		
	surfaceTool.generate_normals()
	return surfaceTool.commit()

func updatetubeshell(drawnfloor, makevisible):
	if makevisible:
		var tubeshellmesh = maketubeshell(drawnfloor)
		if tubeshellmesh != null:
			$XCtubeshell/MeshInstance.mesh = tubeshellmesh
			$XCtubeshell/CollisionShape.shape.set_faces(tubeshellmesh.get_faces())
			$XCtubeshell.visible = true
			$XCtubeshell/CollisionShape.disabled = false
		else:
			$XCtubeshell.visible = false
			$XCtubeshell/CollisionShape.disabled = true
	else:
		$XCtubeshell.visible = false
		$XCtubeshell/CollisionShape.disabled = true
