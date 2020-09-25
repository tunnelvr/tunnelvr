extends Spatial

# primary data
var xcname0 : String 
var xcname1 : String

# this should be a list of dicts so we can run more info into them
var xcdrawinglink = [ ]      # [ 0nodenamefrom, 0nodenameto, 1nodenamefrom, 1nodenameto, ... ]
var xcsectormaterials = [ ]  # [ 0material, 1material, ... ]

# derived data
var positioningtube = false
var pickedpolyindex0 = -1
var pickedpolyindex1 = -1

const linewidth = 0.02

func _ready():
	pass
	
func xctubeapplyonepath(xcn0, xcn1):
	print("xcapplyonepathxcapplyonepath-pre", xcn0, xcn1, xcdrawinglink)
	assert (xcn0.get_parent().get_parent().get_name() == xcname0 and xcn1.get_parent().get_parent().get_name() == xcname1)
	for j in range(0, len(xcdrawinglink), 2):
		if xcdrawinglink[j] == xcn0.get_name() and xcdrawinglink[j+1] == xcn1.get_name():
			xcdrawinglink.remove(j+1)
			xcdrawinglink.remove(j)
			xcn0 = null
			break
	if xcn0 != null:
		xcdrawinglink.append(xcn0.get_name())
		xcdrawinglink.append(xcn1.get_name())
	print("xcapplyonepathxcapplyonepath-post", xcdrawinglink)
	assert ((len(xcdrawinglink)%2) == 0)

func removetubenodepoint(xcname, nodename):
	assert ((xcname == xcname0) or (xcname == xcname1))
	var m = 0 if xcname == xcname0 else 1
	var nodelinkedto = false
	for j in range(len(xcdrawinglink) - 2, -1, -2):
		if xcdrawinglink[j+m] == nodename:
			xcdrawinglink[j] = xcdrawinglink[-2]
			xcdrawinglink[j+1] = xcdrawinglink[-1]
			xcdrawinglink.resize(len(xcdrawinglink) - 2)
			nodelinkedto = true
	return nodelinkedto

func checknodelinkedto(xcname, nodename):
	assert ((xcname == xcname0) or (xcname == xcname1))
	var m = 0 if xcname == xcname0 else 1
	for j in range(len(xcdrawinglink) - 2, -1, -2):
		if xcdrawinglink[j+m] == nodename:
			return true
	return false

func exportxctrpcdata():   # read by xctubefromdata()
	return { "name":get_name(), 
			 "xcname0":xcname0, 
			 "xcname1":xcname1, 
			 "xcdrawinglink":xcdrawinglink, 
			 "xcsectormaterials":xcsectormaterials 
		   }

func shiftxcdrawingposition(sketchsystem):
	if len(xcdrawinglink) == 0:
		return
	print("...shiftxcdrawingposition")
	var xcdrawingFloor = sketchsystem.get_node("XCdrawings").get_node(xcname0)
	var xcdrawingXC = sketchsystem.get_node("XCdrawings").get_node(xcname1)
	assert (xcdrawingFloor.drawingtype == DRAWING_TYPE.DT_FLOORTEXTURE and xcdrawingXC.drawingtype == DRAWING_TYPE.DT_XCDRAWING)
	var bsingledrag = len(xcdrawinglink) == 2
	var opn0 = xcdrawingFloor.get_node("XCnodes").get_node(xcdrawinglink[-2 if bsingledrag else -4])
	var xcn0 = xcdrawingXC.get_node("XCnodes").get_node(xcdrawinglink[-1 if bsingledrag else -3])
	if bsingledrag:
		var xcn0rel = xcn0.global_transform.origin - xcdrawingXC.global_transform.origin
		var pt0 = opn0.global_transform.origin - xcn0rel
		xcdrawingXC.setxcpositionorigin(Vector3(pt0.x, xcdrawingXC.global_transform.origin.y, pt0.z))

	else:
		var opn1 = xcdrawingFloor.get_node("XCnodes").get_node(xcdrawinglink[-2])
		var xcn1 = xcdrawingXC.get_node("XCnodes").get_node(xcdrawinglink[-1])
		var vx = opn1.global_transform.origin - opn0.global_transform.origin
		var vx2 = Vector2(vx.x, vx.z)
		xcdrawingXC.setxcpositionangle((-vx2).angle())
		var vxc = xcn1.global_transform.origin - xcn0.global_transform.origin
		var vxc2 = Vector2(vxc.x, vxc.z)
		var vx2len = vx2.length()
		var vxc2len = vxc2.length()
		var vdot = vx2.dot(vxc2) # should be colinear
		if vdot != 0:
			xcdrawingXC.scalexcnodepointspointsxy(vx2len/vxc2len*(sign(vdot)), 1)
		var xco = opn0.global_transform.origin - xcn0.global_transform.origin + xcdrawingXC.global_transform.origin
		xcdrawingXC.setxcpositionorigin(Vector3(xco.x, xcdrawingXC.global_transform.origin.y, xco.z))
		xcdrawingXC.updatexcpaths()
		
	sketchsystem.sharexcdrawingovernetwork(xcdrawingXC)
	for xctube in xcdrawingXC.xctubesconn:
		if sketchsystem.get_node("XCdrawings").get_node(xctube.xcname0).drawingtype == DRAWING_TYPE.DT_XCDRAWING:  # not other floor types pointing in
			xctube.updatetubelinkpaths(sketchsystem)
			sketchsystem.sharexctubeovernetwork(xctube)

func shiftfloorfromdrawnstations(sketchsystem):
	if len(xcdrawinglink) == 0:
		return
	var xcdrawingCentreline = sketchsystem.get_node("XCdrawings").get_node(xcname0)
	var xcdrawingFloor = sketchsystem.get_node("XCdrawings").get_node(xcname1)
	assert (xcdrawingCentreline.drawingtype == DRAWING_TYPE.DT_CENTRELINE and xcdrawingFloor.drawingtype == DRAWING_TYPE.DT_FLOORTEXTURE)
	print("...shiftdrawingfloorposition")
	var bsingledrag = len(xcdrawinglink) == 2
	var opn0 = xcdrawingCentreline.get_node("XCnodes").get_node(xcdrawinglink[-2 if bsingledrag else -4])
	var xcn0 = xcdrawingFloor.get_node("XCnodes").get_node(xcdrawinglink[-1 if bsingledrag else -3])
	if bsingledrag:
		var xcn0rel = xcn0.global_transform.origin - xcdrawingFloor.global_transform.origin
		var pt0 = opn0.global_transform.origin - Vector3(xcn0rel.x, 0, xcn0rel.z)
		xcdrawingFloor.setxcpositionorigin(pt0)   # global_transform.origin = Vector3(pt0.x, 0, pt0.z)

	else:
		var opn1 = xcdrawingCentreline.get_node("XCnodes").get_node(xcdrawinglink[-2])
		var xcn1 = xcdrawingFloor.get_node("XCnodes").get_node(xcdrawinglink[-1])
		var vx = opn1.global_transform.origin - opn0.global_transform.origin
		var vxc = xcn1.global_transform.origin - xcn0.global_transform.origin
		var vxcl = xcn1.transform.origin - xcn0.transform.origin
		var vxang = Vector2(-vx.x, -vx.z).angle()
		#var vxcang = Vector2(-vxc.x, -vxc.z).angle()
		var vxclang = Vector2(-vxcl.x, vxcl.y).angle()

		var vxlen = vx.length()
		var vxclen = vxc.length()
		if vxlen != 0 and vxclen != 0:
			var sca = vxlen/vxclen
			xcdrawingFloor.get_node("XCdrawingplane").scale *= Vector3(sca, sca, 1)
			xcdrawingFloor.scalexcnodepointspointsxy(sca, sca)
		#xcdrawingFloor.rotation.y += vxcang - vxang
		xcdrawingFloor.rotation = Vector3(-deg2rad(90), vxclang - vxang, 0)  # should be in setxcpositionangle
		var xco = opn0.global_transform.origin - xcn0.global_transform.origin + xcdrawingFloor.global_transform.origin
		xcdrawingFloor.setxcpositionorigin(xco)
		

func positionfromtubelinkpaths(sketchsystem):
	if positioningtube:
		if sketchsystem.get_node("XCdrawings").get_node(xcname1).drawingtype == DRAWING_TYPE.DT_XCDRAWING:
			shiftxcdrawingposition(sketchsystem)
		elif sketchsystem.get_node("XCdrawings").get_node(xcname0).drawingtype == DRAWING_TYPE.DT_CENTRELINE:
			shiftfloorfromdrawnstations(sketchsystem)	
		
func updatetubelinkpaths(sketchsystem):
	var surfaceTool = SurfaceTool.new()
	surfaceTool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var xcdrawing0 = sketchsystem.get_node("XCdrawings").get_node(xcname0)
	var xcdrawing1 = sketchsystem.get_node("XCdrawings").get_node(xcname1)
	var xcdrawing0nodes = xcdrawing0.get_node("XCnodes")
	var xcdrawing1nodes = xcdrawing1.get_node("XCnodes")
	assert ((len(xcdrawinglink)%2) == 0)
	for j in range(0, len(xcdrawinglink), 2):
		#var p0 = xcdrawing0.nodepoints[xcdrawinglink[j]]
		#var p1 = xcdrawing1.nodepoints[xcdrawinglink[j+1]]
		var p0 = xcdrawing0nodes.get_node(xcdrawinglink[j]).global_transform.origin + Vector3(0,0.001,0)
		var p1 = xcdrawing1nodes.get_node(xcdrawinglink[j+1]).global_transform.origin + Vector3(0,0.001,0)
		var vec = p1 - p0
		var veclen = max(0.01, vec.length())
		var perp = Vector3(1, 0, 0)
		if xcdrawing1.drawingtype == DRAWING_TYPE.DT_XCDRAWING:
			perp = vec.cross(xcdrawing1.global_transform.basis.y).normalized()
			if perp == Vector3(0, 0, 0) or positioningtube:
				perp = xcdrawing1.global_transform.basis.x
		var arrowlen = min(0.4, veclen*0.5)
		var p0left = p0 - linewidth*perp
		var p0right = p0 + linewidth*perp
		var p1left = p1 - linewidth*perp
		var p1right = p1 + linewidth*perp
		var pa = p1 - vec*(arrowlen/veclen)
		var arrowfac = max(2*linewidth, arrowlen/2)
		surfaceTool.add_vertex(p0left)
		surfaceTool.add_vertex(p1left)
		surfaceTool.add_vertex(p0right)
		surfaceTool.add_vertex(p0right)
		surfaceTool.add_vertex(p1left)
		surfaceTool.add_vertex(p1right)
		surfaceTool.add_vertex(p1)
		surfaceTool.add_vertex(pa + arrowfac*perp)
		surfaceTool.add_vertex(pa - arrowfac*perp)
	surfaceTool.generate_normals()
	$PathLines.mesh = surfaceTool.commit()
	$PathLines.set_surface_material(0, get_node("/root/Spatial/MaterialSystem").pathlinematerial("normal"))
	#print("ususxxxxc ", len($PathLines.mesh.get_faces()), " ", len($PathLines.mesh.get_faces())) #surfaceTool.generate_normals()

func pickpolysindex(polys, meetnodenames):
	for i in range(len(polys)):
		var meetsallnodes = true
		for meetnodename in meetnodenames:
			if not polys[i].has(meetnodename):
				meetsallnodes = false
				break
		if meetsallnodes:
			return i
	return -1

func fa(a, b):
	return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1])

func maketubepolyassociation(xcdrawing0, xcdrawing1):
	assert ((xcdrawing0.get_name() == xcname0) and (xcdrawing1.get_name() == xcname1))
	var polys0 = Polynets.makexcdpolys(xcdrawing0.nodepoints, xcdrawing0.onepathpairs, true)
	var polys1 = Polynets.makexcdpolys(xcdrawing1.nodepoints, xcdrawing1.onepathpairs, true)
	pickedpolyindex0 = pickpolysindex(polys0, xcdrawinglink.slice(0, len(xcdrawinglink), 2))
	pickedpolyindex1 = pickpolysindex(polys1, xcdrawinglink.slice(1, len(xcdrawinglink), 2))
	
	if pickedpolyindex0 == -1 or pickedpolyindex1 == -1:
		print("no connecting poly available", polys0, polys1)
		return [[], [], []]

	var tubevec = xcdrawing1.global_transform.origin - xcdrawing0.global_transform.origin
	var tubevecdot0 = xcdrawing0.global_transform.basis.z.dot(tubevec)
	var tubevecdot1 = xcdrawing1.global_transform.basis.z.dot(tubevec)
	var polyinvert0 = (tubevecdot0 <= 0) == (pickedpolyindex0 != len(polys0) - 1)
	var polyinvert1 = (tubevecdot1 <= 0) == (pickedpolyindex1 != len(polys1) - 1)
	#var tubenormdot = xcdrawing0.global_transform.basis.z.dot(xcdrawing1.global_transform.basis.z)
	#if not ((tubenormdot < 0) != (polyinvert0 != polyinvert1)):
	#	print("invert problem?")
	var poly0 = polys0[pickedpolyindex0].duplicate()
	var poly1 = polys1[pickedpolyindex1].duplicate()
	if polyinvert0:
		poly0.invert()
	if polyinvert1:
		poly1.invert()
	#print("opopolys", poly0, poly1)
	
	#if xcdrawing0.global_transform.basis.z.dot(xcdrawing1.global_transform.basis.z) < 0:
	#	poly1.invert()
	#	print("reversssing poly1", xcdrawing0.global_transform.basis.z, xcdrawing1.global_transform.basis.z, poly1)

	while len(xcsectormaterials) < len(xcdrawinglink)/2:
		xcsectormaterials.append(get_node("/root/Spatial/MaterialSystem").tubematerialnamefromnumber(0 if ((len(xcsectormaterials)%2) == 0) else 1))
	xcsectormaterials.resize(len(xcdrawinglink)/2)

	# get all the connections in here between the polygons but in the right order
	var ila = [ ]  # [ [ il0, il1 ] ]
	var xcdrawinglinkneedsreorder = false
	var missingjvals = [ ]
	for j in range(0, len(xcdrawinglink), 2):
		var il0 = poly0.find(xcdrawinglink[j])
		var il1 = poly1.find(xcdrawinglink[j+1])
		if il0 != -1 and il1 != -1:
			ila.append([il0, il1, j])
		else:
			missingjvals.append(j)
		if j != 0 and not fa(ila[-2], ila[-1]):
			xcdrawinglinkneedsreorder = true
	if xcdrawinglinkneedsreorder or (len(missingjvals) != 0 and (missingjvals.min() < len(xcdrawinglink) - 2*len(missingjvals))):
		ila.sort_custom(self, "fa")
		var newxcdrawinglink = [ ]
		var newxcsectormaterials = [ ]
		for i in range(len(ila)):
			newxcdrawinglink.append(poly0[ila[i][0]])
			newxcdrawinglink.append(poly1[ila[i][1]])
			newxcsectormaterials.append(xcsectormaterials[ila[i][2]/2])
		for j in missingjvals:
			newxcdrawinglink.append(xcdrawinglink[j])
			newxcdrawinglink.append(xcdrawinglink[j+1])
			newxcsectormaterials.append(xcsectormaterials[j/2])
		assert(len(xcdrawinglink) == len(newxcdrawinglink))
		xcdrawinglink = newxcdrawinglink
		xcsectormaterials = newxcsectormaterials
		
	return [poly0, poly1, ila]

func add_uvvertex(surfaceTool, xcnodes, poly, ila, i, floorsize, dfinv):
	var pt = xcnodes.get_node(poly[(ila+i)%len(poly)]).global_transform.origin
	if dfinv != null:
		var afloorpoint = dfinv.xform(pt)
		var uvpt = Vector2(afloorpoint.x/floorsize.x + 0.5, afloorpoint.z/floorsize.y + 0.5)
		surfaceTool.add_uv(uvpt)
	surfaceTool.add_vertex(pt)

func maketubeshell(xcdrawings):
	var sketchsystem = xcdrawings.get_parent()
	var floordrawing = null # sketchsystem.getactivefloordrawing()
	var floorsize = floordrawing.get_node("XCdrawingplane/CollisionShape/MeshInstance").mesh.size if floordrawing != null else null
	var dfinv = floordrawing.get_node("XCdrawingplane/CollisionShape/MeshInstance").global_transform.affine_inverse() if floordrawing != null else null
	
	var xcdrawing0 = xcdrawings.get_node(xcname0)
	var xcdrawing1 = xcdrawings.get_node(xcname1)
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
		#print("  iiilla ", [ila0, ila0N, ila1, ila1N])
		var surfaceTool = SurfaceTool.new()
		#surfaceTool.set_material(Material.new())
		surfaceTool.begin(Mesh.PRIMITIVE_TRIANGLES)

		var acc = -ila0N/2.0  if ila0N>=ila1N  else  ila1N/2
		var i0 = 0
		var i1 = 0
		while i0 < ila0N or i1 < ila1N:
			assert (i0 <= ila0N and i1 <= ila1N)
			if i0 < ila0N and (acc - ila0N < 0 or i1 == ila1N):
				acc += ila1N
				add_uvvertex(surfaceTool, xcnodes0, poly0, ila0, i0, floorsize, dfinv)
				add_uvvertex(surfaceTool, xcnodes1, poly1, ila1, i1, floorsize, dfinv)
				i0 += 1
				add_uvvertex(surfaceTool, xcnodes0, poly0, ila0, i0, floorsize, dfinv)
			if i1 < ila1N and (acc >= 0 or i0 == ila0N):
				acc -= ila0N
				add_uvvertex(surfaceTool, xcnodes0, poly0, ila0, i0, floorsize, dfinv)
				add_uvvertex(surfaceTool, xcnodes1, poly1, ila1, i1, floorsize, dfinv)
				i1 += 1
				add_uvvertex(surfaceTool, xcnodes1, poly1, ila1, i1, floorsize, dfinv)
		
		surfaceTool.generate_normals()
		surfaceTool.commit(arraymesh)
	return arraymesh


func slicetubetoxcdrawing(xcdrawing, xcdrawinglink0, xcdrawinglink1):
	var xcdrawings = get_node("/root/Spatial/SketchSystem/XCdrawings")
	var xcdrawing0 = xcdrawings.get_node(xcname0)
	var xcdrawing1 = xcdrawings.get_node(xcname1)
	var mtpa = maketubepolyassociation(xcdrawing0, xcdrawing1)
	var poly0 = mtpa[0]
	var poly1 = mtpa[1]
	var ila = mtpa[2]
	if len(ila) == 0:
		return false
	
	var xcnodes0 = xcdrawing0.get_node("XCnodes")
	var xcnodes1 = xcdrawing1.get_node("XCnodes")
	var xcnfirst = null	
	var xcnlast = null
	var lamoutofrange = false
	for i in range(len(ila)):
		var ila0 = ila[i][0]
		var ila0N = ila[i+1][0] - ila0  if i < len(ila)-1  else len(poly0) + ila[0][0] - ila0 
		var ila1 = ila[i][1]
		var ila1N = ila[(i+1)%len(ila)][1] - ila1
		if ila1N < 0 or len(ila) == 1:   # there's a V-shaped case where this isn't good enough
			ila1N += len(poly1)
			
		var acc = -ila0N/2.0  if ila0N>=ila1N  else  ila1N/2.0
		var i0 = 0
		var i1 = 0
		while i0 < ila0N or i1 < ila1N:
			var pt0 = xcnodes0.get_node(poly0[(ila0+i0)%len(poly0)]).global_transform.origin
			var pt1 = xcnodes1.get_node(poly1[(ila1+i1)%len(poly1)]).global_transform.origin
			var xcn = xcdrawing.newxcnode()
			if i0 == 0 and i1 == 0:
				xcdrawinglink0.append(poly0[ila0])
				xcdrawinglink0.append(xcn.get_name())
				xcdrawinglink1.append(xcn.get_name())
				xcdrawinglink1.append(poly1[ila1])
			
			# 0 = xcdrawing.global_transform.basis.z.dot(pt0 + lam*(pt1 - pt0) - xcdrawing.global_transform.origin)
			# lam*xcdrawing.global_transform.basis.z.dot(pt0 - pt1) = xcdrawing.global_transform.basis.z.dot(pt0 - xcdrawing.global_transform.origin)
			var lam = xcdrawing.global_transform.basis.z.dot(pt0 - xcdrawing.global_transform.origin)/xcdrawing.global_transform.basis.z.dot(pt0 - pt1)
			if lam < 0.02 or lam > 0.98:
				lamoutofrange = true
			xcdrawing.setxcnpoint(xcn, lerp(pt0, pt1, lam), true)
				
			assert (i0 <= ila0N and i1 <= ila1N)
			if i0 < ila0N and (acc - ila0N < 0 or i1 == ila1N):
				acc += ila1N
				i0 += 1
			if i1 < ila1N and (acc >= 0 or i0 == ila0N):
				acc -= ila0N
				i1 += 1
			if xcnlast != null:
				xcdrawing.onepathpairs.append(xcnlast.get_name())
				xcdrawing.onepathpairs.append(xcn.get_name())
			xcnlast = xcn
			if xcnfirst == null:
				xcnfirst = xcn

	xcdrawing.onepathpairs.append(xcnlast.get_name())
	xcdrawing.onepathpairs.append(xcnfirst.get_name())
	
	# undo mysterious advancing of the sector links
	#xcdrawinglink1.push_back(xcdrawinglink1.pop_front())
	#xcdrawinglink1.push_back(xcdrawinglink1.pop_front())
	if lamoutofrange:
		xcdrawing.clearallcontents()
		return false
	
	return true


func add_vertex(surfaceTool, xcnodes, poly, ila, i):
	var pt = xcnodes.get_node(poly[(ila+i)%len(poly)]).global_transform.origin
	surfaceTool.add_vertex(pt)

func updatetubeshell(xcdrawings, makevisible):
	if not makevisible:
		$XCtubesectors.visible = false
		for tubesector in $XCtubesectors.get_children():
			tubesector.get_node("CollisionShape").disabled = true
		return

	if $XCtubesectors.get_child_count() != 0:
		var xctubesectors_old = $XCtubesectors
		xctubesectors_old.set_name("XCtubesectors_old")
		for x in xctubesectors_old.get_children():
			x.queue_free()   # because it's not transitive (should file a ticket)
		xctubesectors_old.queue_free()
		var xctubesectors_new = Spatial.new()
		xctubesectors_new.set_name("XCtubesectors")
		add_child(xctubesectors_new)
		
	var xcdrawing0 = xcdrawings.get_node(xcname0)
	var xcdrawing1 = xcdrawings.get_node(xcname1)
	var mtpa = maketubepolyassociation(xcdrawing0, xcdrawing1)
	var poly0 = mtpa[0]
	var poly1 = mtpa[1]
	var ila = mtpa[2]

	var xcnodes0 = xcdrawing0.get_node("XCnodes")
	var xcnodes1 = xcdrawing1.get_node("XCnodes")
	for i in range(len(ila)):
		var ila0 = ila[i][0]
		var ila0N = ila[i+1][0] - ila0  if i < len(ila)-1  else len(poly0) + ila[0][0] - ila0 
		var ila1 = ila[i][1]
		var ila1N = ila[(i+1)%len(ila)][1] - ila1
		if ila1N < 0 or len(ila) == 1:   # there's a V-shaped case where this isn't good enough
			ila1N += len(poly1)
		#print("  iiilla ", [ila0, ila0N, ila1, ila1N])
		var surfaceTool = SurfaceTool.new()
		surfaceTool.begin(Mesh.PRIMITIVE_TRIANGLES)

		var acc = -ila0N/2.0  if ila0N>=ila1N  else  ila1N/2
		var i0 = 0
		var i1 = 0
		while i0 < ila0N or i1 < ila1N:
			assert (i0 <= ila0N and i1 <= ila1N)
			if i0 < ila0N and (acc - ila0N < 0 or i1 == ila1N):
				acc += ila1N
				add_vertex(surfaceTool, xcnodes0, poly0, ila0, i0)
				add_vertex(surfaceTool, xcnodes1, poly1, ila1, i1)
				i0 += 1
				add_vertex(surfaceTool, xcnodes0, poly0, ila0, i0)
			if i1 < ila1N and (acc >= 0 or i0 == ila0N):
				acc -= ila0N
				add_vertex(surfaceTool, xcnodes0, poly0, ila0, i0)
				add_vertex(surfaceTool, xcnodes1, poly1, ila1, i1)
				i1 += 1
				add_vertex(surfaceTool, xcnodes1, poly1, ila1, i1)
		
		surfaceTool.generate_normals()
		var tubesectormesh = surfaceTool.commit()
		var xctubesector = preload("res://nodescenes/XCtubeshell.tscn").instance()
		xctubesector.set_name("XCtubesector_"+String(i))
		xctubesector.get_node("MeshInstance").mesh = tubesectormesh
		var cps = ConcavePolygonShape.new()
		cps.margin = 0.01
		xctubesector.get_node("CollisionShape").shape = cps
		xctubesector.get_node("CollisionShape").shape.set_faces(tubesectormesh.get_faces())
		get_node("/root/Spatial/MaterialSystem").updatetubesectormaterial(xctubesector, xcsectormaterials[i], false)
		$XCtubesectors.add_child(xctubesector)

	
func xcdfullsetvisibilitycollision(bvisible):
	visible = bvisible
	for tubesector in $XCtubesectors.get_children():
		if visible:
			tubesector.get_node("CollisionShape").disabled = not tubesector.get_node("MeshInstance").visible
		else:
			tubesector.get_node("CollisionShape").disabled = true

