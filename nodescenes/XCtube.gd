extends Spatial

# primary data
var xcname0 : String 
var xcname1 : String

# this should be a list of dicts so we can run more info into them
var xcdrawinglink = [ ]      # [ 0nodenamefrom, 0nodenameto, 1nodenamefrom, 1nodenameto, ... ]
var xcsectormaterials = [ ]  # [ 0material, 1material, ... ]
var xclinkintermediatenodes = null 		 # [ 0[Vector3(u,v,lambda), Vector3, Vector3], 1[ ], 2[ ] ] parallel to the drawinglinks, if it is set

# derived data
var positioningtube = false
var pickedpolyindex0 = -1
var pickedpolyindex1 = -1

var planeintersectaxisvec = null
var planeintersectpoint = null
var planealongvecwhenparallel = null


const linewidth = 0.02

func exportxctrpcdata():   # read by xctubefromdata()
	var res = { "name":get_name(),  # tubename
				"xcname0":xcname0, 
				"xcname1":xcname1, 
				"xcdrawinglink":xcdrawinglink, 
				"xcsectormaterials":xcsectormaterials 
				# "prevdrawinglinks": [ node0, node1, material, xclinkintermediatenodes,... ] ]
				# "newdrawinglinks":
			  }
	if xclinkintermediatenodes != null:
		res["xclinkintermediatenodes"] = xclinkintermediatenodes
	return res 


func linkspresentindex(nodename0, nodename1):
	for j in range(int(len(xcdrawinglink)/2)):
		if xcdrawinglink[j*2] == nodename0 and (nodename1 == null or xcdrawinglink[j*2+1] == nodename1):
			return j
	return -1

const rN = 4
func mergexctrpcdata(xctdata):
	if "xcdrawinglink" in xctdata:
		xcdrawinglink = xctdata["xcdrawinglink"]
		xcsectormaterials = xctdata["xcsectormaterials"]
		xclinkintermediatenodes = xctdata.get("xclinkintermediatenodes", null)
	if "prevdrawinglinks" in xctdata:
			 # "prevdrawinglinks": [ node0, node1, material, xclinkintermediatenodes, ... ] ]
			 # "newdrawinglinks":
		assert (len(xcsectormaterials)*2 == len(xcdrawinglink))
		assert (xclinkintermediatenodes == null or len(xclinkintermediatenodes) == len(xcsectormaterials))
		var drawinglinksErase = xctdata["prevdrawinglinks"]
		var drawinglinksAdd = xctdata["newdrawinglinks"]
		var nE = int(len(drawinglinksErase)/rN)
		var nA = int(len(drawinglinksAdd)/rN)
		assert (len(drawinglinksErase) == nE*rN)
		assert (len(drawinglinksAdd) == nA*rN)
		var iA = 0
		var m0 = xctdata["m0"]
		var m1 = 1-m0
		var materialsectorschanged = [ ]
		for iE in range(nE):
			var j = linkspresentindex(drawinglinksErase[iE*rN+m0], drawinglinksErase[iE*rN+m1])
			if j != -1:
				if iA < nA and drawinglinksAdd[iA*rN] == drawinglinksErase[iE*rN] and drawinglinksAdd[iA*rN+1] == drawinglinksErase[iE*rN+1]:
					if drawinglinksAdd[iA*rN+2] != null:
						xcsectormaterials[j] = drawinglinksAdd[iA*rN+2]
						materialsectorschanged.push_back(j)
					if drawinglinksErase[iE*rN+3] != null:
						for dv in drawinglinksErase[iE*rN+3]:
							removexclinkintermediatenode(j, dv)
					if drawinglinksAdd[iA*rN+3] != null:
						for dv in drawinglinksAdd[iA*rN+3]:
							insertxclinkintermediatenode(j, dv)
					iA += 1
				else:
					xcdrawinglink.remove(j*2+1)
					xcdrawinglink.remove(j*2)
					xcsectormaterials.remove(j)
					if xclinkintermediatenodes != null:
						xclinkintermediatenodes.remove(j)

		while iA < nA:
			var j = linkspresentindex(drawinglinksAdd[iA*rN+m0], drawinglinksAdd[iA*rN+m1])
			if j == -1:
				xcdrawinglink.push_back(drawinglinksAdd[iA*rN+m0])
				xcdrawinglink.push_back(drawinglinksAdd[iA*rN+m1])
				xcsectormaterials.push_back(drawinglinksAdd[iA*rN+2])


				if xclinkintermediatenodes != null:
					xclinkintermediatenodes.push_back(drawinglinksAdd[iA*rN+3] if drawinglinksAdd[iA*rN+3] != null else [])
				elif drawinglinksAdd[iA*rN+3] != null:
					xclinkintermediatenodes = [ ]
					for ji in len(xcsectormaterials) - 1:
						xclinkintermediatenodes.push_back([ ])
					xclinkintermediatenodes.push_back(drawinglinksAdd[iA*rN+3])
			else:
				print("wrong: sector already here")
				xcsectormaterials[j] = drawinglinksAdd[iA*rN+2]
				if xclinkintermediatenodes != null:
					xclinkintermediatenodes[j] = drawinglinksAdd[iA*rN+3] if drawinglinksAdd[iA*rN+3] != null else []
			iA += 1
		if len(materialsectorschanged) != 0:
			xctdata["materialsectorschanged"] = materialsectorschanged
		assert (len(xcsectormaterials)*2 == len(xcdrawinglink))
		assert (xclinkintermediatenodes == null or len(xclinkintermediatenodes) == len(xcsectormaterials))
		
func setxctubepathlinevisibility(sketchsystem):
	var xcdrawing0 = sketchsystem.get_node("XCdrawings").get_node(xcname0)
	var xcdrawing1 = sketchsystem.get_node("XCdrawings").get_node(xcname1)
	#var pathlinesvisible = xcdrawing0.get_node("PathLines").visible or xcdrawing1.get_node("PathLines").visible
	var pathlinesvisible = (xcdrawing0.drawingvisiblecode == DRAWING_TYPE.VIZ_XCD_PLANE_AND_NODES_VISIBLE) or \
						   (xcdrawing1.drawingvisiblecode == DRAWING_TYPE.VIZ_XCD_PLANE_AND_NODES_VISIBLE)
	$PathLines.visible = pathlinesvisible
	for inode in $PathLines.get_children():
		inode.visible = pathlinesvisible
		inode.get_node("CollisionShape").disabled = not pathlinesvisible

func centrelineconnectionfloortransformpos(sketchsystem):
	assert (len(xcdrawinglink) != 0)
	var xcdrawingCentreline = sketchsystem.get_node("XCdrawings").get_node(xcname0)
	var xcdrawingFloor = sketchsystem.get_node("XCdrawings").get_node(xcname1)
	assert (xcdrawingCentreline.drawingtype == DRAWING_TYPE.DT_CENTRELINE and xcdrawingFloor.drawingtype == DRAWING_TYPE.DT_FLOORTEXTURE)
	var xcdatalist = null
	var bsingledrag = len(xcdrawinglink) == 2
	var opn0 = xcdrawingCentreline.get_node("XCnodes").get_node(xcdrawinglink[-2 if bsingledrag else -4])
	var xcn0 = xcdrawingFloor.get_node("XCnodes").get_node(xcdrawinglink[-1 if bsingledrag else -3])
	if bsingledrag:
		var pt0 = xcdrawingFloor.global_transform.origin + opn0.global_transform.origin - xcn0.global_transform.origin
		xcdatalist = [{ "name":xcname1, 
						"prevtransformpos":xcdrawingFloor.transform, 
						"transformpos":Transform(xcdrawingFloor.transform.basis, Vector3(pt0.x, xcdrawingFloor.transform.origin.y, pt0.z)) 
					 }]
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
			var transformpos = Transform(Vector3(1,0,0), Vector3(0,0,-1), Vector3(0,1,0), Vector3(0,0,0)).rotated(Vector3(0,1,0), vxclang - vxang)
			var pt0 = opn0.global_transform.origin - transformpos*(xcn0.transform.origin*Vector3(sca, sca, 1))
			transformpos.origin = Vector3(pt0.x, xcdrawingFloor.global_transform.origin.y, pt0.z)
			var xcndata = { "name":xcname1, 
							"prevnodepoints":xcdrawingFloor.nodepoints.duplicate(),
							"nextnodepoints":{ }
						  }
			for floornodename in xcdrawingFloor.nodepoints:
				xcndata["nextnodepoints"][floornodename] = xcdrawingFloor.nodepoints[floornodename]*Vector3(sca, sca, 1)
			var d = xcdrawingFloor
			var txcdata = { "name":xcname1, 
							"prevtransformpos":xcdrawingFloor.transform, 
							"transformpos":transformpos, 
							"previmgtrim": { "imgwidth":d.imgwidth, "imgtrimleftdown":d.imgtrimleftdown, "imgtrimrightup":d.imgtrimrightup },
							"imgtrim": { "imgwidth":d.imgwidth*sca, "imgtrimleftdown":d.imgtrimleftdown*sca, "imgtrimrightup":d.imgtrimrightup*sca }
						  }
			xcdatalist = [ xcndata, txcdata ]

	return xcdatalist
		
func encodeintermediatenodename(linkindex, nodeindex):
	return "j%di%d"%[linkindex, nodeindex]
func decodeintermediatenodenamelinkindex(inodename):
	return int(inodename.split("i")[0])
func decodeintermediatenodenamenodeindex(inodename):
	return int(inodename.split("i")[1])

func updatetubelinkpaths(sketchsystem):
	var surfaceTool = SurfaceTool.new()
	surfaceTool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var xcdrawing0 = sketchsystem.get_node("XCdrawings").get_node(xcname0)
	var xcdrawing1 = sketchsystem.get_node("XCdrawings").get_node(xcname1)
	var xcdrawing0nodes = xcdrawing0.get_node("XCnodes")
	var xcdrawing1nodes = xcdrawing1.get_node("XCnodes")
	assert ((len(xcdrawinglink)%2) == 0)
	for j in range(0, len(xcdrawinglink), 2):
		var p0 = xcdrawing0.transform * xcdrawing0.nodepoints[xcdrawinglink[j]]
		var p1 = xcdrawing1.transform * xcdrawing1.nodepoints[xcdrawinglink[j+1]]
		#var p0 = xcdrawing0nodes.get_node(xcdrawinglink[j]).global_transform.origin
		#var p1 = xcdrawing1nodes.get_node(xcdrawinglink[j+1]).global_transform.origin
		var vec = p1 - p0
		var veclen = max(0.01, vec.length())
		var perp = Vector3(1, 0, 0)
		if xcdrawing1.drawingtype == DRAWING_TYPE.DT_XCDRAWING:
			perp = vec.cross(xcdrawing1.global_transform.basis.y).normalized()
			if perp == Vector3(0, 0, 0) or positioningtube:
				perp = xcdrawing1.global_transform.basis.x
		var arrowlen = min(0.4, veclen*0.5)

		var p0m = p0
		var p0mleft = p0m - linewidth*perp
		var p0mright = p0m + linewidth*perp
		var jb = j/2
		var nintermediatenodes = (0 if xclinkintermediatenodes == null else len(xclinkintermediatenodes[jb]))
		for i in range(nintermediatenodes+1):
			var p1m
			var p1mtrans
			if i < nintermediatenodes:
				p1mtrans = intermedpointposT(p0, p1, xclinkintermediatenodes[jb][i])
				p1m = p1mtrans.origin
			else:
				p1m = p1
				p1mtrans = null
			var p1mleft = p1m - linewidth*perp
			var p1mright = p1m + linewidth*perp
			surfaceTool.add_vertex(p0mleft)
			surfaceTool.add_vertex(p1mleft)
			surfaceTool.add_vertex(p0mright)
			surfaceTool.add_vertex(p0mright)
			surfaceTool.add_vertex(p1mleft)
			surfaceTool.add_vertex(p1mright)
			if i < nintermediatenodes:
				p0m = p1m
				p0mleft = p1mleft
				p0mright = p1mright
				var inodename = encodeintermediatenodename(jb, i)
				var inode = $PathLines.get_node_or_null(inodename)
				if inode == null:
					inode = preload("res://nodescenes/XCnode_intermediate.tscn").instance()
					inode.set_name(inodename)
					$PathLines.add_child(inode)
				inode.global_transform = p1mtrans
			else:
				var pa = p1m - (p1m - p0m).normalized()*arrowlen
				var arrowfac = max(2*linewidth, arrowlen/2)
				surfaceTool.add_vertex(p1m)
				surfaceTool.add_vertex(pa + arrowfac*perp)
				surfaceTool.add_vertex(pa - arrowfac*perp)
				
		
		var im = nintermediatenodes 
		while true:
			var imnodename = encodeintermediatenodename(jb, im)
			if not $PathLines.has_node(imnodename):
				break
			$PathLines.get_node(imnodename).queue_free()
			im += 1
			
	var jbm = len(xcdrawinglink) 
	while $PathLines.has_node(encodeintermediatenodename(jbm, 0)):
		var im = 0
		var imnodename = encodeintermediatenodename(jbm, im)
		if not $PathLines.has_node(imnodename):
			break
		$PathLines.get_node(imnodename).queue_free()
		im += 1

	surfaceTool.generate_normals()
	$PathLines.mesh = surfaceTool.commit()
	$PathLines.set_surface_material(0, get_node("/root/Spatial/MaterialSystem").pathlinematerial("normal"))


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
		var newxclinkintermediatenodes = null if xclinkintermediatenodes == null else [ ]
		for i in range(len(ila)):
			newxcdrawinglink.append(poly0[ila[i][0]])
			newxcdrawinglink.append(poly1[ila[i][1]])
			newxcsectormaterials.append(xcsectormaterials[ila[i][2]/2])
			if newxclinkintermediatenodes != null:
				newxclinkintermediatenodes.append(xclinkintermediatenodes[ila[i][2]/2])
		for j in missingjvals:
			newxcdrawinglink.append(xcdrawinglink[j])
			newxcdrawinglink.append(xcdrawinglink[j+1])
			newxcsectormaterials.append(xcsectormaterials[j/2])
			if newxclinkintermediatenodes != null:
				newxclinkintermediatenodes.append(xclinkintermediatenodes[j/2])
		assert(len(xcdrawinglink) == len(newxcdrawinglink))
		xcdrawinglink = newxcdrawinglink
		xcsectormaterials = newxcsectormaterials
		xclinkintermediatenodes = newxclinkintermediatenodes
		if xclinkintermediatenodes != null:
			var sketchsystem = get_node("/root/Spatial/SketchSystem")
			updatetubelinkpaths(sketchsystem)

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
				xctdatadel["prevdrawinglinks"].push_back(xclinkintermediatenodes[i] if xclinkintermediatenodes != null else null)

				xctdata0["newdrawinglinks"].push_back(poly0[ila0])
				xctdata0["newdrawinglinks"].push_back(xcname)
				xctdata0["newdrawinglinks"].push_back(xcsectormaterials[i])
				xctdata0["newdrawinglinks"].push_back(xclinkintermediatenodes[i] if xclinkintermediatenodes != null else null)

				xctdata1["newdrawinglinks"].push_back(xcname)
				xctdata1["newdrawinglinks"].push_back(poly1[ila1])
				xctdata1["newdrawinglinks"].push_back(xcsectormaterials[i])
				xctdata1["newdrawinglinks"].push_back(null)
			
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

func HoleName(i):
	return "Hole"+("" if i == 0 else ";"+str(i))+";"+xcname0+";"+xcname1

func ConstructHoleXC(i, sketchsystem):
	assert (xcsectormaterials[i] == "hole")
	var xcdrawingholename = HoleName(i)
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

	if xcdrawinghole != null:
		xcdata["prevonepathpairs"] = xcdrawinghole.onepathpairs.duplicate()
		xcdata["prevnodepoints"] = xcdrawinghole.nodepoints.duplicate()

	var shellcontour = extractshellcontour(sketchsystem.get_node("XCdrawings"), i)
	var prevname = shellcontour[-1][0]
	for sc in shellcontour:
		xcdata["nextnodepoints"][sc[0]] = xcdata["transformpos"].xform_inv(sc[1])
		xcdata["newonepathpairs"].push_back(prevname)
		xcdata["newonepathpairs"].push_back(sc[0])
		prevname = sc[0]
	return xcdata


func advanceuvFar(uvFixed, ptFixed, uvFar, ptFar, ptFarNew, bclockwise):
	var uvvec = uvFar - uvFixed
	var uvperpvec = Vector2(uvvec.y, -uvvec.x) if bclockwise else Vector2(-uvvec.y, uvvec.x)
	var uvvecleng = uvvec.length()
	var vecFar = ptFar - ptFixed
	var vecFarNew = ptFarNew - ptFixed
	var vecFarFarNewprod = vecFar.length()*vecFarNew.length()
	if vecFarFarNewprod == 0:
		return uvFar
	var vecFarFarNewRatio = vecFarNew.length()/vecFar.length()
	var vecFarNewCos = vecFar.dot(vecFarNew)/vecFarFarNewprod
	var vecFarNewSin = vecFar.cross(vecFarNew).length()/vecFarFarNewprod
	var uvvecnew = uvvec*vecFarNewCos + uvperpvec*vecFarNewSin
	var uvvecnewR = uvvecnew*vecFarFarNewRatio
	return uvFixed + uvvecnewR

func get_pt(xcdrawing, poly, ila, i):
	return xcdrawing.transform * xcdrawing.nodepoints[poly[(ila+i)%len(poly)]]

func initialtuberails(xcdrawing0, poly0, ila0, ila0N, xcdrawing1, poly1, ila1, ila1N):
	var acc = -ila0N/2.0  if ila0N>=ila1N  else  ila1N/2
	var i0 = 0
	var i1 = 0

	var pti0 = get_pt(xcdrawing0, poly0, ila0, i0)
	var pti1 = get_pt(xcdrawing1, poly1, ila1, i1)
	var uvi0 = Vector2(0, 0)
	var uvi1 = Vector2(pti0.distance_to(pti1),0)

	var tuberail0 = [ [ pti0, uvi0, 0.0 ] ]
	var tuberail1 = [ [ pti1, uvi1, 0.0 ] ]
	while i0 < ila0N or i1 < ila1N:
		assert (i0 <= ila0N and i1 <= ila1N)
		if i0 < ila0N and (acc - ila0N < 0 or i1 == ila1N):
			acc += ila1N
			i0 += 1
			var pti0next = get_pt(xcdrawing0, poly0, ila0, i0)
			uvi0 = advanceuvFar(uvi1, pti1, uvi0, pti0, pti0next, true)
			pti0 = pti0next
		if i1 < ila1N and (acc >= 0 or i0 == ila0N):
			acc -= ila0N
			i1 += 1
			var pti1next = get_pt(xcdrawing1, poly1, ila1, i1)
			uvi1 = advanceuvFar(uvi0, pti0, uvi1, pti1, pti1next, false)
			pti1 = pti1next
		tuberail0.push_back([pti0, uvi0, i0*1.0/ila0N if ila0N != 0 else 1.0])
		tuberail1.push_back([pti1, uvi1, i1*1.0/ila1N if ila1N != 0 else 1.0])
	return [tuberail0, tuberail1]
		

func triangulatetuberung(surfaceTool, tuberail0rung0, tuberail1rung0, tuberail0rung1, tuberail1rung1):
	surfaceTool.add_uv(tuberail0rung0[1])
	surfaceTool.add_uv2(tuberail0rung0[1])
	surfaceTool.add_vertex(tuberail0rung0[0])

	surfaceTool.add_uv(tuberail1rung0[1])
	surfaceTool.add_uv2(tuberail1rung0[1])
	surfaceTool.add_vertex(tuberail1rung0[0])

	if tuberail1rung0[0] != tuberail1rung1[0]:
		surfaceTool.add_uv(tuberail1rung1[1])
		surfaceTool.add_uv2(tuberail1rung1[1])
		surfaceTool.add_vertex(tuberail1rung1[0])
		if tuberail0rung0[0] == tuberail0rung1[0]:
			return

		surfaceTool.add_uv(tuberail0rung0[1])
		surfaceTool.add_uv2(tuberail0rung0[1])
		surfaceTool.add_vertex(tuberail0rung0[0])

		surfaceTool.add_uv(tuberail1rung1[1])
		surfaceTool.add_uv2(tuberail1rung1[1])
		surfaceTool.add_vertex(tuberail1rung1[0])

	surfaceTool.add_uv(tuberail0rung1[1])
	surfaceTool.add_uv2(tuberail0rung1[1])
	surfaceTool.add_vertex(tuberail0rung1[0])


func triangulatetuberails(surfaceTool, tuberail0, tuberail1):
	for i in range(len(tuberail0)-1):
		triangulatetuberung(surfaceTool, tuberail0[i], tuberail1[i], tuberail0[i+1], tuberail1[i+1])

func intermediaterailsequence(zi, zi1, railsequencerung0, railsequencerung1):
	var ij = -1
	var i1j = -1
	var zij0 = Vector3(0,0,0)
	var zi1j0 = Vector3(0,0,0)
	var zij1 = Vector3(0,0,1) if len(zi) == 0 else zi[0]
	var zi1j1 = Vector3(0,0,1) if len(zi1) == 0 else zi1[0]

	while true:
		assert(ij < len(zi) or i1j < len(zi1))
		var adv = 0
		if ij == len(zi):
			adv = 1
		elif i1j == len(zi1):
			adv = -1
		elif zi1j1.z < zij1.z:
			if zi1j1.z - zij0.z < zij1.z - zi1j1.z:
				adv = 1
		else:
			if zij1.z - zi1j0.z < zi1j1.z - zij1.z:
				adv = -1

		if adv <= 0:
			ij += 1
			zij0 = zij1
			if ij != len(zi):
				zij1 = Vector3(0,0,1) if ij+1 == len(zi) else zi[ij+1] 
		if adv >= 0:
			i1j += 1
			zi1j0 = zi1j1
			if i1j != len(zi1):
				zi1j1 = Vector3(0,0,1) if i1j+1 == len(zi1) else zi1[i1j+1] 
		if ij == len(zi) and i1j == len(zi1):
			break
		railsequencerung0.push_back(zij0)
		railsequencerung1.push_back(zi1j0)
	
func intermedpointpos(p0, p1, dp):
	var sp = lerp(p0, p1, dp.z)
	var spbasis = intermedpointplanebasis(sp)
	return sp + spbasis.x*dp.x + spbasis.y*dp.y

func intermedpointposT(p0, p1, dp):
	var sp = lerp(p0, p1, dp.z)
	var spbasis = intermedpointplanebasis(sp)
	return Transform(spbasis, sp + spbasis.x*dp.x + spbasis.y*dp.y)
	
func slicerungsatintermediatetuberail(tuberail0, tuberail1, rung0k, rung1k):
	assert(len(tuberail0) == len(tuberail1))
	var tuberailk = [ ]
	for i in range(len(tuberail0)):
		var dpi
		var x
		if i != 0 and i != len(tuberail0) - 1:
			var u0 = tuberail0[i][2]
			var u1 = tuberail1[i][2]
			var z0 = rung0k.z
			var z1 = rung1k.z
			x = (z0 + (z1-z0)*u0) / (1 - (z1-z0)*(u1-u0))
			var y = u0 + x*(u1-u0)
			assert(is_equal_approx(x, z0 + y*(z1-z0)))
			assert(0 <= x and x <= 1 and 0 <= y and y <= 1)
			dpi = lerp(rung0k, rung1k, y)
		else:
			if i == 0:
				assert(tuberail0[i][2] == 0.0 and tuberail1[i][2] == 0.0)
				dpi = rung0k
			else:
				assert(tuberail0[i][2] == 1.0 and tuberail1[i][2] == 1.0)
				dpi = rung1k
			x = dpi.z
		tuberailk.push_back([intermedpointpos(tuberail0[i][0], tuberail1[i][0], dpi), lerp(tuberail0[i][1], tuberail1[i][1], x)])
	return tuberailk


func updatetubeshell(xcdrawings):
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
	for i in range(len(ila)):
		var ila0 = ila[i][0]
		var ila0N = ila[i+1][0] - ila0  if i < len(ila)-1  else len(poly0) + ila[0][0] - ila0 
		var ila1 = ila[i][1]
		var ila1N = ila[(i+1)%len(ila)][1] - ila1
		if ila1N < 0 or len(ila) == 1:   # there's a V-shaped case where this isn't good enough
			ila1N += len(poly1)
			
		var tuberails = initialtuberails(xcdrawing0, poly0, ila0, ila0N, xcdrawing1, poly1, ila1, ila1N)
		var tuberail0 = tuberails[0]
		var tuberail1 = tuberails[1]
		var surfaceTool = SurfaceTool.new()
		surfaceTool.begin(Mesh.PRIMITIVE_TRIANGLES)
		if xclinkintermediatenodes != null:
			assert (len(ila) == len(xclinkintermediatenodes))
			var xclinkintermediatenodesi = xclinkintermediatenodes[i]
			var xclinkintermediatenodesi1 = xclinkintermediatenodes[(i+1)%len(ila)]
			var railsequencerung0 = [ ]
			var railsequencerung1 = [ ]
			intermediaterailsequence(xclinkintermediatenodesi, xclinkintermediatenodesi1, railsequencerung0, railsequencerung1)
			assert(len(railsequencerung0) == len(railsequencerung1))
			var tuberailk0 = tuberail0
			for k in range(len(railsequencerung0)+1):
				var tuberailk1
				if k < len(railsequencerung0):
					tuberailk1 = slicerungsatintermediatetuberail(tuberail0, tuberail1, railsequencerung0[k], railsequencerung1[k])
				else:
					tuberailk1 = tuberail1
				triangulatetuberails(surfaceTool, tuberailk0, tuberailk1)
				tuberailk0 = tuberailk1
		else:
			triangulatetuberails(surfaceTool, tuberail0, tuberail1)
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

		if xcsectormaterials[i] == "hole":
			var sketchsystem = get_node("/root/Spatial/SketchSystem")
			var xcdrawinghole = sketchsystem.get_node_or_null("XCdrawings").get_node(HoleName(i))
			if xcdrawinghole != null and len(xcdrawinghole.xctubesconn) != 0:
				xctubesector.get_node("MeshInstance").visible = false
				xctubesector.get_node("CollisionShape").disabled = true
		$XCtubesectors.add_child(xctubesector)


func shellcontourxcside(xcdrawing, poly, ila, ilaN, pref):
	var scc = [ ]
	for j in range(ilaN+1):
		var nodename = poly[(ila+j)%len(poly)]
		scc.push_back([pref%nodename, xcdrawing.transform * xcdrawing.nodepoints[nodename]])
	return scc
	
func shellcontourintermed(p0, p1, xclinkintermediatenodes, pref):
	var scc = [ ]
	for j in range(len(xclinkintermediatenodes)):
		var dp = xclinkintermediatenodes[j]
		var sp = lerp(p0, p1, dp.z)
		var spbasis = intermedpointplanebasis(sp)
		scc.push_back([pref%j, sp + spbasis.x*dp.x + spbasis.y*dp.y])
	return scc
	
func extractshellcontour(xcdrawings, i):
	var xcdrawing0 = xcdrawings.get_node(xcname0)
	var xcdrawing1 = xcdrawings.get_node(xcname1)
	var mtpa = maketubepolyassociation_andreorder(xcdrawing0, xcdrawing1)
	var poly0 = mtpa[0]
	var poly1 = mtpa[1]
	var ila = mtpa[2]

	var ila0 = ila[i][0]
	var ila0N = ila[i+1][0] - ila0  if i < len(ila)-1  else len(poly0) + ila[0][0] - ila0 
	var ila1 = ila[i][1]
	var ila1N = ila[(i+1)%len(ila)][1] - ila1
	if ila1N < 0 or len(ila) == 1:   # there's a V-shaped case where this isn't good enough
		ila1N += len(poly1)
			
	var scc0 = shellcontourxcside(xcdrawing0, poly0, ila0, ila0N, "r0%s")
	var scc1 = shellcontourxcside(xcdrawing1, poly1, ila1, ila1N, "r1%s")
	var scctop
	var sccbot
	if xclinkintermediatenodes != null:
		scctop = shellcontourintermed(scc0[-1][1], scc1[-1][1], xclinkintermediatenodes[(i+1)%len(ila)], "rt%d")
		sccbot = shellcontourintermed(scc0[0][1], scc1[0][1], xclinkintermediatenodes[i], "rb%d")
	else:
		scctop = [ ]
		sccbot = [ ]
	scc1.invert()
	sccbot.invert()
	return scc0 + scctop + scc1 + sccbot
	
func makeplaneintersectionaxisvec(xcdrawing0, xcdrawing1):
	var n0 = xcdrawing0.transform.basis.z
	var n1 = xcdrawing1.transform.basis.z
	var c0 = n0.dot(xcdrawing0.transform.origin)
	var c1 = n1.dot(xcdrawing1.transform.origin)
	var n0dn1 = n0.dot(n1)
	var adet = 1 - n0dn1*n0dn1
	var lplaneintersectaxisvec = n0.cross(n1)
	var planeintersectaxisveclen = lplaneintersectaxisvec.length()
	if planeintersectaxisveclen > 0.0001 and adet > 0.0001:
		planeintersectaxisvec = lplaneintersectaxisvec/planeintersectaxisveclen
		# solve (a0 n0 + a1 n1) . ni = c0
		var ad0 = c0 - n0dn1*c1
		var ad1 = -n0dn1*c0 + c1
		planeintersectpoint = (n0*ad0 + n1*ad1)/adet
	else:
		planeintersectaxisvec = xcdrawing0.transform.basis.y
		planealongvecwhenparallel = xcdrawing0.transform.basis.x

func intermedpointplanebasis(pointertargetpoint):
	var byvec = planeintersectaxisvec
	var bxvec = planealongvecwhenparallel
	if planealongvecwhenparallel == null:
		var vtargetint = planeintersectpoint - pointertargetpoint
		var d = vtargetint.dot(planeintersectaxisvec)
		var vtargetintn = vtargetint - d*planeintersectaxisvec
		bxvec = vtargetintn.normalized()
	var bzvec = bxvec.cross(byvec)
	if not is_equal_approx(bzvec.length(), 1):
		print("bad zvecn ", bzvec.length())
	return Basis(bxvec, byvec, bzvec)


func removexclinkintermediatenode(j, dv):
	if xclinkintermediatenodes != null:
		for i in range(len(xclinkintermediatenodes[j])):
			if xclinkintermediatenodes[j][i].z == dv.z:
				xclinkintermediatenodes[j].remove(i)
				return
	print("no matching intermediate node to delete")

func insertxclinkintermediatenode(j, dv):
	if xclinkintermediatenodes == null:
		xclinkintermediatenodes = [ ]
		for ji in range(len(xcdrawinglink)/2):
			xclinkintermediatenodes.push_back([])
	assert(len(xclinkintermediatenodes) == len(xcdrawinglink)/2)
	var i = 0
	while i < len(xclinkintermediatenodes[j]) and xclinkintermediatenodes[j][i].z <= dv.z:
		i += 1
	if i < len(xclinkintermediatenodes[j]) and xclinkintermediatenodes[j][i].z == dv.z:
		xclinkintermediatenodes[j][i] = dv
	else:
		xclinkintermediatenodes[j].insert(i, dv)
		
	
	
