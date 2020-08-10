extends Spatial

var otxcdIndex0 : String 
var otxcdIndex1 : String    # setting to -1 means the floor sketch
var xcdrawinglink = [ ]  # [ nodepoints_ifrom0, nodepoints_ito0, nodepoints_ifrom1, nodepoints_ito1, ... ]
const linewidth = 0.02

const materialdirt = preload("res://lightweighttextures/simpledirt.material")
const materialscanimage = preload("res://surveyscans/scanimagefloor.material")
const materialrock = preload("res://lightweighttextures/partialrock.material")

const materials = [ materialdirt, materialscanimage, materialrock ]

func togglematerialcycle():
	var m = materials.find($XCtubeshell/MeshInstance.get_surface_material(0))
	for i in range($XCtubeshell/MeshInstance.get_surface_material_count()):
		$XCtubeshell/MeshInstance.set_surface_material(i, materials[(i+1+m)%len(materials)])

func xctubeapplyonepath(xcn0, xcn1):
	print("xcapplyonepathxcapplyonepath-pre", xcn0, xcn1, xcdrawinglink)
	var xcdrawings = xcn0.get_parent().get_parent().get_parent()
	var sketchsystem = xcdrawings.get_parent()
	for j in range(0, len(xcdrawinglink), 2):
		if xcdrawinglink[j] == xcn0.otIndex and xcdrawinglink[j+1] == xcn1.otIndex:
			xcdrawinglink.remove(j+1)
			xcdrawinglink.remove(j)
			xcn0 = null
			break
	if xcn0 != null:
		xcdrawinglink.append(xcn0.otIndex)
		xcdrawinglink.append(xcn1.otIndex)
	print("xcapplyonepathxcapplyonepath-post", xcdrawinglink)
	assert ((len(xcdrawinglink)%2) == 0)
	updatetubelinkpaths(xcdrawings, sketchsystem)

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

func shiftxcdrawingposition(xcdrawings, sketchsystem):
	print("...shiftxcdrawingposition")
	var xcdrawing = xcdrawings.get_node(otxcdIndex0)
	var xcdrawing0nodes = xcdrawing.get_node("XCnodes")
	var xcdrawing1nodes = sketchsystem.get_node("floordrawing/XCnodes")
	if len(xcdrawinglink) == 0:
		return
	var bscalexcnodepointspointsx_called = false
	var bsingledrag = len(xcdrawinglink) == 2
	var xcn0 = xcdrawing0nodes.get_child(xcdrawinglink[-2 if bsingledrag else -4])
	var opn0 = xcdrawing1nodes.get_child(xcdrawinglink[-1 if bsingledrag else -3])
	if bsingledrag:
		var xcn0rel = xcn0.global_transform.origin - xcdrawing.global_transform.origin
		var pt0 = opn0.global_transform.origin - Vector3(xcn0rel.x, 0, xcn0rel.z)
		xcdrawing.setxcpositionorigin(pt0)

	else:
		var xcn1 = xcdrawing0nodes.get_child(xcdrawinglink[-2])
		var opn1 = xcdrawing1nodes.get_child(xcdrawinglink[-1])  # OnePathNodes
		var vx = opn1.global_transform.origin - opn0.global_transform.origin
		var vxc = xcn1.global_transform.origin - xcn0.global_transform.origin
		var vxlen = vx.length()
		var vxclen = vxc.length()
		if vxlen != 0 and vxclen != 0:
			xcdrawing.scalexcnodepointspointsx(vxlen/vxclen)
			bscalexcnodepointspointsx_called = true
		xcdrawing.setxcpositionangle(Vector2(-vx.x, -vx.z).angle())
		var xco = opn0.global_transform.origin - xcn0.global_transform.origin + xcdrawing.global_transform.origin
		xcdrawing.setxcpositionorigin(xco)
		
	if bscalexcnodepointspointsx_called:
		xcdrawing.updatexcpaths()
	for xctube in xcdrawing.xctubesconn:
		if xctube.otxcdIndex1 != "floordrawing":
			xctube.updatetubelinkpaths(xcdrawings, sketchsystem)
		
		
func updatetubelinkpaths(xcdrawings, sketchsystem):
	var bgroundanchortype = otxcdIndex1 == "floordrawing"
	if bgroundanchortype:
		shiftxcdrawingposition(xcdrawings, sketchsystem)
	
	var surfaceTool = SurfaceTool.new()
	surfaceTool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var xcdrawing0nodes = xcdrawings.get_node(otxcdIndex0).get_node("XCnodes")
	var xcdrawing1nodes = xcdrawings.get_node(otxcdIndex1).get_node("XCnodes") if not bgroundanchortype else sketchsystem.get_node("floordrawing/XCnodes")
	print("llll", xcdrawings, xcdrawing0nodes, xcdrawing1nodes, xcdrawinglink)
	assert ((len(xcdrawinglink)%2) == 0)
	for j in range(0, len(xcdrawinglink), 2):
		#var p0 = xcdrawing0.nodepoints[xcdrawinglink[j]]
		#var p1 = xcdrawing1.nodepoints[xcdrawinglink[j+1]]
		var p0 = xcdrawing0nodes.get_child(xcdrawinglink[j]).global_transform.origin
		var p1 = xcdrawing1nodes.get_child(xcdrawinglink[j+1]).global_transform.origin
		print("jjjjuj", j, p0, p1)
		var perp = linewidth*Vector2(-(p1.z - p0.z), p1.x - p0.x).normalized()
		if perp == Vector2(0, 0):
			perp = Vector2(linewidth, 0)
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
	#if not bgroundanchortype:
	#	updatetubeshell(sketchsystem.get_node("floordrawing"), $XCtubeshell.visible)

func fa(a, b):
	return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1])

func maketubepolyassociation(xcdrawing0, xcdrawing1):
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
	if poly0 == null or poly1 == null:
		print("no connecting poly available", polys0, polys1)
		return [[], [], []]
		
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
	ila.sort_custom(self, "fa")
	print("ilililia", xcdrawinglink, ila)
	return [poly0, poly1, ila]

func add_uvvertex(surfaceTool, xcnodes, poly, ila, i, floorsize, dfinv):
	var pt = xcnodes.get_child(poly[(ila+i)%len(poly)]).global_transform.origin
	var afloorpoint = dfinv.xform(pt)
	var uvpt = Vector2(afloorpoint.x/floorsize.x + 0.5, afloorpoint.z/floorsize.y + 0.5)
	surfaceTool.add_uv(uvpt)
	surfaceTool.add_vertex(pt)

func maketubeshell(floordrawing):
	var floorsize = floordrawing.get_node("XCdrawingplane/CollisionShape/MeshInstance").mesh.size
	var dfinv = floordrawing.get_node("XCdrawingplane/CollisionShape/MeshInstance").global_transform.affine_inverse()
	
	var xcdrawings = get_node("../../XCdrawings")
	var xcdrawing0 = xcdrawings.get_node(otxcdIndex0)
	var xcdrawing1 = xcdrawings.get_node(otxcdIndex1)
	var mtpa = maketubepolyassociation(xcdrawing0, xcdrawing1)
	var poly0 = mtpa[0]
	var poly1 = mtpa[1]
	var ila = mtpa[2]
	if len(ila) == 0:
		return null
	
	#var surfaceTool = SurfaceTool.new()
	#surfaceTool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var arraymesh = ArrayMesh.new()
	#var surfaceTool = SurfaceTool.new()

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
		var surfaceTool = SurfaceTool.new()
		surfaceTool.set_material(materialdirt if i != 0 else materialscanimage)
		surfaceTool.begin(Mesh.PRIMITIVE_TRIANGLES)

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
		surfaceTool.commit(arraymesh)
	return arraymesh
	#return surfaceTool.commit()

func slicetubetoxcdrawing(xcdrawing, xcdrawinglink0, xcdrawinglink1, lam):
	var xcdrawings = get_node("../../XCdrawings")
	var xcdrawing0 = xcdrawings.get_node(otxcdIndex0)
	var xcdrawing1 = xcdrawings.get_node(otxcdIndex1)
	var mtpa = maketubepolyassociation(xcdrawing0, xcdrawing1)
	var poly0 = mtpa[0]
	var poly1 = mtpa[1]
	var ila = mtpa[2]
	if len(ila) == 0:
		return false
	
	var xcnodes0 = xcdrawing0.get_node("XCnodes")
	var xcnodes1 = xcdrawing1.get_node("XCnodes")
	var xcnlast = null	
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
			var pt0 = xcnodes0.get_child(poly0[(ila0+i0)%len(poly0)]).global_transform.origin
			var pt1 = xcnodes1.get_child(poly1[(ila1+i1)%len(poly1)]).global_transform.origin
			var xcn = xcdrawing.newxcnode(-1)
			if i0 == 0 and i1 == 0:
				xcdrawinglink0.append(poly0[ila0])
				xcdrawinglink0.append(xcn.otIndex)
				xcdrawinglink1.append(poly1[ila1])
				xcdrawinglink1.append(xcn.otIndex)
			
			xcn.global_transform.origin = lerp(pt0, pt1, lam)
			xcdrawing.copyxcntootnode(xcn)
			xcdrawing.nodepoints[xcn.otIndex].z = 0  # flatten into the plane
			xcdrawing.copyotnodetoxcn(xcn)
			if acc < 0:
				acc += ila1N
				i0 += 1
			else:
				acc -= ila0N
				i1 += 1
			if xcnlast != null:
				xcdrawing.onepathpairs.append(xcnlast.otIndex)
				xcdrawing.onepathpairs.append(xcn.otIndex)
			xcnlast = xcn
	xcdrawing.onepathpairs.append(xcnlast.otIndex)
	xcdrawing.onepathpairs.append(0)
	return true

func updatetubeshell(floordrawing, makevisible):
	if makevisible:
		var tubeshellmesh = maketubeshell(floordrawing)
		if tubeshellmesh != null:
			$XCtubeshell/MeshInstance.mesh = tubeshellmesh
			$XCtubeshell/MeshInstance.set_surface_material(0, materialrock)
			$XCtubeshell/MeshInstance.set_surface_material(1, materialdirt)
				#$XCtubeshell/MeshInstance.material_override = preload("res://surveyscans/simplerocktexture.material")   # this can cause crashes
			#$XCtubeshell/MeshInstance.material_override = preload("res://lightweighttextures/simpledirt.material")
			$XCtubeshell/CollisionShape.shape.set_faces(tubeshellmesh.get_faces())
			$XCtubeshell.visible = true
			$XCtubeshell/CollisionShape.disabled = false
		else:
			$XCtubeshell.visible = false
			$XCtubeshell/CollisionShape.disabled = true
	else:
		$XCtubeshell.visible = false
		$XCtubeshell/CollisionShape.disabled = true
