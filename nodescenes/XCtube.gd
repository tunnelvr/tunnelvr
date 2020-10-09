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

var tubesectorptindexlists = [ ]

const linewidth = 0.02
	


func exportxctrpcdata():   # read by xctubefromdata()
	return { "name":get_name(),  # tubename
			 "xcname0":xcname0, 
			 "xcname1":xcname1, 
			 "xcdrawinglink":xcdrawinglink, 
			 "xcsectormaterials":xcsectormaterials 
			 # "prevdrawinglinks": [ node0, node1, material, ... ] ]
			 # "newdrawinglinks":
		   }

func linkspresentindex(nodename0, nodename1):
	for j in range(int(len(xcdrawinglink)/2)):
		if xcdrawinglink[j*2] == nodename0 and xcdrawinglink[j*2+1] == nodename1:
			return j
	return -1

func mergexctrpcdata(xctdata):
	if "xcdrawinglink" in xctdata:
		xcdrawinglink = xctdata["xcdrawinglink"]
		xcsectormaterials = xctdata["xcsectormaterials"]
	if "prevdrawinglinks" in xctdata:
			 # "prevdrawinglinks": [ node0, node1, material, ... ] ]
			 # "newdrawinglinks":
		assert (len(xcsectormaterials)*2 == len(xcdrawinglink))
		var drawinglinksErase = xctdata["prevdrawinglinks"]
		var drawinglinksAdd = xctdata["newdrawinglinks"]
		var nE = int(len(drawinglinksErase)/3)
		var nA = int(len(drawinglinksAdd)/3)
		var iA = 0
		var m0 = xctdata["m0"]
		var m1 = 1-m0
		var materialsectorschanged = [ ]
		for iE in range(nE):
			var j = linkspresentindex(drawinglinksErase[iE*3+m0], drawinglinksErase[iE*3+m1])
			if j != -1:
				if iA < nA and drawinglinksAdd[iA*3] == drawinglinksErase[iE*3] and drawinglinksAdd[iA*3+1] == drawinglinksErase[iE*3+1]:
					xcsectormaterials[j] = drawinglinksAdd[iA*3+2]
					iA += 1
					materialsectorschanged.push_back(j)
				else:
					xcdrawinglink.remove(j*2+1)
					xcdrawinglink.remove(j*2)
					xcsectormaterials.remove(j)
		while iA < nA:
			var j = linkspresentindex(drawinglinksAdd[iA*3+m0], drawinglinksAdd[iA*3+m1])
			if j == -1:
				xcdrawinglink.push_back(drawinglinksAdd[iA*3+m0])
				xcdrawinglink.push_back(drawinglinksAdd[iA*3+m1])
				xcsectormaterials.push_back(drawinglinksAdd[iA*3+2])	
			else:
				print("wrong: sector already here")
				xcsectormaterials[j] = drawinglinksAdd[iA*3+2]
			iA += 1
		if len(materialsectorschanged) != 0:
			xctdata["materialsectorschanged"] = materialsectorschanged
		assert (len(xcsectormaterials)*2 == len(xcdrawinglink))


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
		
	#sketchsystem.sharexcdrawingovernetwork(xcdrawingXC)
	print("Not sharing xcdrawing position -- use actsketchchange technology")
	for xctube in xcdrawingXC.xctubesconn:
		if sketchsystem.get_node("XCdrawings").get_node(xctube.xcname0).drawingtype == DRAWING_TYPE.DT_XCDRAWING:  # not other floor types pointing in
			xctube.updatetubelinkpaths(sketchsystem)
			#sketchsystem.sharexctubeovernetwork(xctube)

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

func maketubepolyassociation_andreorder(xcdrawing0, xcdrawing1):
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


func slicetubetoxcdrawing(xcdrawing, xcdata, xctdatadel, xctdata0, xctdata1):
	var xcdrawings = get_node("/root/Spatial/SketchSystem/XCdrawings")
	var xcdrawing0 = xcdrawings.get_node(xcname0)
	var xcdrawing1 = xcdrawings.get_node(xcname1)
	var mtpa = maketubepolyassociation_andreorder(xcdrawing0, xcdrawing1)
	var poly0 = mtpa[0]
	var poly1 = mtpa[1]
	var ila = mtpa[2]
	if len(ila) == 0:
		return false
	
	var xcnodes0 = xcdrawing0.get_node("XCnodes")
	var xcnodes1 = xcdrawing1.get_node("XCnodes")
	var xcnamefirst = null	
	var xcnamelast = null
	var lamoutofrange = false
	var xcnormal = xcdrawing.global_transform.basis.z
	var xcdot = xcnormal.dot(xcdrawing.global_transform.origin)
	var sliceclearancedist = 0.02
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
			var xcname = xcdrawing.newuniquexcnodename()
			if i0 == 0 and i1 == 0:
				xctdatadel["prevdrawinglinks"].push_back(poly0[ila0])
				xctdatadel["prevdrawinglinks"].push_back(poly1[ila1])
				xctdatadel["prevdrawinglinks"].push_back(xcsectormaterials[i])

				xctdata0["newdrawinglinks"].push_back(poly0[ila0])
				xctdata0["newdrawinglinks"].push_back(xcname)
				xctdata0["newdrawinglinks"].push_back(xcsectormaterials[i])

				xctdata1["newdrawinglinks"].push_back(xcname)
				xctdata1["newdrawinglinks"].push_back(poly1[ila1])
				xctdata1["newdrawinglinks"].push_back(xcsectormaterials[i])
			
			# 0 = xcdrawing.global_transform.basis.z.dot(pt0 + lam*(pt1 - pt0) - xcdrawing.global_transform.origin)
			# lam*xcdrawing.global_transform.basis.z.dot(pt0 - pt1) = xcdrawing.global_transform.basis.z.dot(pt0 - xcdrawing.global_transform.origin)
			var ptvec = pt0 - pt1
			var lam = (xcnormal.dot(pt0) - xcdot)/xcnormal.dot(ptvec)
			var lamfromedge = min(lam, 1 - lam)
			if lam < 0.0 or lamfromedge*ptvec.length() < sliceclearancedist:
				print("Slice point out of range ", lam)
				lamoutofrange = true
			var xcpoint = xcdrawing.global_transform.xform_inv(lerp(pt0, pt1, lam))
			xcpoint.z = 0.0
			xcdata["nextnodepoints"][xcname] = xcpoint
			assert (i0 <= ila0N and i1 <= ila1N)
			if i0 < ila0N and (acc - ila0N < 0 or i1 == ila1N):
				acc += ila1N
				i0 += 1
			if i1 < ila1N and (acc >= 0 or i0 == ila0N):
				acc -= ila0N
				i1 += 1
			if xcnamelast != null:
				xcdata["newonepathpairs"].push_back(xcnamelast)
				xcdata["newonepathpairs"].push_back(xcname)
			xcnamelast = xcname
			if xcnamefirst == null:
				xcnamefirst = xcname

	xcdata["newonepathpairs"].push_back(xcnamelast)
	xcdata["newonepathpairs"].push_back(xcnamefirst)
	# undo mysterious advancing of the sector links
	#xcdrawinglink1.push_back(xcdrawinglink1.pop_front())
	#xcdrawinglink1.push_back(xcdrawinglink1.pop_front())
	if lamoutofrange:
		return false
	return true

func ConstructHoleXC(i, sketchsystem):
	assert (xcsectormaterials[i] == "hole")
	var xcdrawingholename = "Hole"+("" if i == 0 else ";"+str(i))+";"+xcname0+";"+xcname1
	var xcdrawinghole = sketchsystem.get_node_or_null("XCdrawings").get_node(xcdrawingholename)
	var xcdata = { "name":xcdrawingholename, 
				   "drawingtype":DRAWING_TYPE.DT_XCDRAWING,
				   "prevnodepoints":{}, "nextnodepoints":{}, 
				   "prevonepathpairs":[], "newonepathpairs":[] }

	var tubesectormesh = $XCtubesectors.get_child(i).get_node("MeshInstance").mesh
	var mdt = MeshDataTool.new()
	mdt.create_from_surface(tubesectormesh, 0)
	var sumnormals = Vector3(0, 0, 0)
	var sumpoints = Vector3(0, 0, 0)
	for j in range(mdt.get_vertex_count()):
		sumnormals += mdt.get_vertex_normal(j)
		sumpoints += mdt.get_vertex(j)
	var avgnormal = sumnormals/mdt.get_vertex_count()
	var avgpoint = sumpoints/mdt.get_vertex_count()
	var drawingwallhangle = Vector2(Vector2(avgnormal.x, avgnormal.z).length(), avgnormal.y).angle()
	if abs(drawingwallhangle) < deg2rad(45):
		var drawingwallangle = Vector2(avgnormal.x, avgnormal.z).angle() + deg2rad(90)
		xcdata["transformpos"] = Transform(Basis().rotated(Vector3(0,-1,0), drawingwallangle), avgpoint) 
	else:
		xcdata["transformpos"] = Transform(Vector3(1,0,0), Vector3(0,0,-1), Vector3(0,1,0), avgpoint)

	var xcdrawing0 = sketchsystem.get_node("XCdrawings").get_node(xcname0)
	var xcdrawing1 = sketchsystem.get_node("XCdrawings").get_node(xcname1)
	var xcnsourcelist = [ ]
	for i0 in tubesectorptindexlists[i][0]:
		xcnsourcelist.push_back(xcdrawing0.get_node("XCnodes").get_node(i0))
	var xir = len(xcnsourcelist)
	for j in range(len(tubesectorptindexlists[i][1])-1, -1, -1):
		var i1 = tubesectorptindexlists[i][1][j]
		xcnsourcelist.push_back(xcdrawing1.get_node("XCnodes").get_node(i1))

	if xcdrawinghole != null:
		xcdata["prevonepathpairs"] = xcdrawinghole.onepathpairs.duplicate()
		xcdata["prevnodepoints"][name] = xcdrawinghole.nodepoints.duplicate()
		
	var prevname = "r"+xcnsourcelist[-1].get_name()
	for j in range(len(xcnsourcelist)):
		var xcnsource = xcnsourcelist[j]
		var name = ("" if j < xir else "r")+xcnsource.get_name()
		xcdata["nextnodepoints"][name] = xcdata["transformpos"].xform_inv(xcnsource.global_transform.origin)
		xcdata["newonepathpairs"].push_back(prevname)
		xcdata["newonepathpairs"].push_back(name)
		prevname = name
	return xcdata


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
	var mtpa = maketubepolyassociation_andreorder(xcdrawing0, xcdrawing1)
	var poly0 = mtpa[0]
	var poly1 = mtpa[1]
	var ila = mtpa[2]

	var xcnodes0 = xcdrawing0.get_node("XCnodes")
	var xcnodes1 = xcdrawing1.get_node("XCnodes")
	tubesectorptindexlists.clear()
	for i in range(len(ila)):
		var ila0 = ila[i][0]
		var ila0N = ila[i+1][0] - ila0  if i < len(ila)-1  else len(poly0) + ila[0][0] - ila0 
		var ila1 = ila[i][1]
		var ila1N = ila[(i+1)%len(ila)][1] - ila1
		if ila1N < 0 or len(ila) == 1:   # there's a V-shaped case where this isn't good enough
			ila1N += len(poly1)
			
		var tubesectorindexl = [ [ poly0[ila0] ], [ poly1[ila1] ] ]
		for j0 in range(ila0N):
			tubesectorindexl[0].push_back(poly0[(ila0+j0+1)%len(poly0)])
		for j1 in range(ila1N):
			tubesectorindexl[1].push_back(poly1[(ila1+j1+1)%len(poly1)])
		tubesectorptindexlists.push_back(tubesectorindexl)

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

