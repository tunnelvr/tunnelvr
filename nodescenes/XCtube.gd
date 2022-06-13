extends Spatial

# primary data
var xcname0 : String 
var xcname1 : String

var xcdrawinglink = [ ]      # [ 0nodenamefrom, 0nodenameto, 1nodenamefrom, 1nodenameto, ... ]
var xcsectormaterials = [ ]  # [ 0material, 1material, ... ]
var xclinkintermediatenodes = null 		 # [ 0[Vector3(u,v,lambda), Vector3, Vector3], 1[ ], 2[ ] ] parallel to the drawinglinks, if it is set

var xctchangesequence = -1

# derived data
var pickedpolykey0 = -1
var pickedpolykey1 = -1

var planeintersectaxisvec = null
var planeintersectpoint = null
var planealongvecwhenparallel = null


const linewidth = 0.02

func exportxctrpcdata(stripruntimedataforsaving):   # read by xctubefromdata()
	var res = { "tubename":get_name(),
				"xcname0":xcname0, 
				"xcname1":xcname1, 
				"xcdrawinglink":xcdrawinglink, 
				"xcsectormaterials":xcsectormaterials 
				# "prevdrawinglinks": [ node0, node1, material, xclinkintermediatenodes,... ] ]
				# "newdrawinglinks":
			  }
	if xclinkintermediatenodes != null:
		res["xclinkintermediatenodes"] = xclinkintermediatenodes
	if not stripruntimedataforsaving:
		res["xctchangesequence"] = xctchangesequence
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
	var pathlinesvisible = ((xcdrawing0.drawingvisiblecode & DRAWING_TYPE.VIZ_XCD_NODES_VISIBLE) != 0) or \
						   ((xcdrawing1.drawingvisiblecode & DRAWING_TYPE.VIZ_XCD_NODES_VISIBLE) != 0) or \
						   ($XCtubesectors.get_child_count() == 0) or \
						   (xcdrawing1.drawingtype == DRAWING_TYPE.DT_FLOORTEXTURE)
	$PathLines.visible = pathlinesvisible
	for inode in $PathLines.get_children():
		inode.visible = pathlinesvisible
		inode.get_node("CollisionShape").disabled = not pathlinesvisible
		

func centrelineconnectionfloortransformpos(sketchsystem):
	assert (len(xcdrawinglink) != 0)
	var xcdrawingCentreline = sketchsystem.get_node("XCdrawings").get_node(xcname0)
	var xcdrawingFloor = sketchsystem.get_node("XCdrawings").get_node(xcname1)
	assert (xcdrawingCentreline.drawingtype == DRAWING_TYPE.DT_CENTRELINE and xcdrawingFloor.drawingtype == DRAWING_TYPE.DT_FLOORTEXTURE)
	var xcdatalist = [ ]
	var bsingledrag = (len(xcdrawinglink) == 2)
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

		var vxlen = Vector2(vx.x, vx.z).length()
		var vxclen = Vector2(vxc.x, vxc.z).length()
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
			print("Floormove ", transformpos)
			xcdatalist = [ xcndata, txcdata ]

	return xcdatalist
		
func encodeintermediatenodename(linkindex, nodeindex):
	return "j%di%d"%[linkindex, nodeindex]
func decodeintermediatenodenamelinkindex(inodename):
	return int(inodename.split("i")[0])
func decodeintermediatenodenamenodeindex(inodename):
	return int(inodename.split("i")[1])

var tubelinklinewidth = 0.02
func updatefloorcentrelinepositionlinks(sketchsystem):
	var surfaceTool = SurfaceTool.new()
	surfaceTool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var xcdrawing0 = sketchsystem.get_node("XCdrawings").get_node(xcname0)
	var xcdrawing1 = sketchsystem.get_node("XCdrawings").get_node(xcname1)
	assert(xcdrawing0.drawingtype == DRAWING_TYPE.DT_CENTRELINE and xcdrawing1.drawingtype == DRAWING_TYPE.DT_FLOORTEXTURE)
	assert ((len(xcdrawinglink)%2) == 0)
	for j in range(0, len(xcdrawinglink), 2):
		var p0 = xcdrawing0.transform * xcdrawing0.nodepoints[xcdrawinglink[j]]
		var p1 = xcdrawing1.transform * xcdrawing1.nodepoints[xcdrawinglink[j+1]]
		Polynets.addarrowmesh(surfaceTool, p0, p1, xcdrawing1.global_transform.basis.x, tubelinklinewidth, [])
	surfaceTool.generate_normals()
	$PathLines.mesh = surfaceTool.commit()
	$PathLines.set_surface_material(0, get_node("/root/Spatial/MaterialSystem").pathlinematerial("floorposition"))
	$PathLines.layers = CollisionLayer.VL_xctubeposlines
	$PathLines.visible = true

func updatecentrelineassociationlinks(sketchsystem):
	var surfaceTool = SurfaceTool.new()
	surfaceTool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var xcdrawing0 = sketchsystem.get_node("XCdrawings").get_node(xcname0)
	var xcdrawing1 = sketchsystem.get_node("XCdrawings").get_node(xcname1)
	assert(xcdrawing0.drawingtype == DRAWING_TYPE.DT_CENTRELINE and xcdrawing1.drawingtype == DRAWING_TYPE.DT_CENTRELINE)
	assert ((len(xcdrawinglink)%2) == 0)
	var sperp = Vector3(0, 0, 0)
	for j in range(0, len(xcdrawinglink), 2):
		var p0 = xcdrawing0.transform * xcdrawing0.nodepoints[xcdrawinglink[j]]
		var p1 = xcdrawing1.transform * xcdrawing1.nodepoints[xcdrawinglink[j+1]]
		var vec = p1 - p0
		var perp = vec.cross(Vector3(0, 1, 0)).normalized()
		if perp == Vector3(0, 0, 0):
			perp = Vector3(1, 0, 0)
		sperp += perp
		Polynets.addarrowmesh(surfaceTool, p0, p1, perp, tubelinklinewidth*2, [])
		Polynets.addarrowmesh(surfaceTool, p0, p1, vec.cross(perp).normalized(), tubelinklinewidth*2, [])

	var nodepointsmap = Centrelinedata.centrelinenodeassociation(xcdrawing1.nodepoints, xcdrawing0.nodepoints, xcdrawinglink)
	var fperp = sperp.normalized() * tubelinklinewidth
	for nodefromname in nodepointsmap:
		var nodetoname = nodepointsmap[nodefromname]
		var p1 = xcdrawing1.transform * xcdrawing1.nodepoints[nodefromname]
		var p0 = xcdrawing0.transform * xcdrawing0.nodepoints[nodetoname]
		var p0left = p0 - fperp
		var p0right = p0 + fperp
		var p1left = p1 - fperp
		var p1right = p1 + fperp
		surfaceTool.add_vertex(p0left)
		surfaceTool.add_vertex(p1left)
		surfaceTool.add_vertex(p0right)
		surfaceTool.add_vertex(p0right)
		surfaceTool.add_vertex(p1left)
		surfaceTool.add_vertex(p1right)
		
	surfaceTool.generate_normals()
	$PathLines.mesh = surfaceTool.commit()
	$PathLines.set_surface_material(0, get_node("/root/Spatial/MaterialSystem").pathlinematerial("centrelineassociation"))
	$PathLines.layers = CollisionLayer.VL_xctubeposlines
	$PathLines.visible = true

func updatetubelinkpaths(sketchsystem):
	var surfaceTool = SurfaceTool.new()
	surfaceTool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var xcdrawing0 = sketchsystem.get_node("XCdrawings").get_node(xcname0)
	var xcdrawing1 = sketchsystem.get_node("XCdrawings").get_node(xcname1)
	makeplaneintersectionaxisvec(xcdrawing0, xcdrawing1)
	assert ((len(xcdrawinglink)%2) == 0)
	var nlinksfound = 0
	for j in range(0, len(xcdrawinglink), 2):
		var lp0 = xcdrawing0.nodepoints.get(xcdrawinglink[j])
		var lp1 = xcdrawing1.nodepoints.get(xcdrawinglink[j+1])
		if lp0 == null:
			print(" *** Error: tube ", get_name(), " link node ", xcdrawinglink[j], " missing from ", xcname0)
			continue
		if lp1 == null:
			print(" *** Error: tube ", get_name(), " link node ", xcdrawinglink[j+1], " missing from ", xcname1)
			continue
		nlinksfound += 1
		var p0 = xcdrawing0.transform * xcdrawing0.nodepoints[xcdrawinglink[j]]
		var p1u = xcdrawing1.nodepoints[xcdrawinglink[j+1]]
		var p1 = xcdrawing1.transform * p1u
		var vec = p1 - p0
		var perp = Vector3(1, 0, 0)
		if xcdrawing1.drawingtype == DRAWING_TYPE.DT_XCDRAWING:
			perp = vec.cross(xcdrawing1.global_transform.basis.y).normalized()
			if perp == Vector3(0, 0, 0):
				perp = xcdrawing1.global_transform.basis.x
		var vsmallrotright = ((p1u.x > xcdrawing1.nodepointmean.x) == (p1u.y > xcdrawing1.nodepointmean.y))
		perp = perp.rotated(xcdrawing1.global_transform.basis.z, deg2rad(5 if vsmallrotright else -5))
		var jb = j/2
		var nintermediatenodes = (0 if xclinkintermediatenodes == null else len(xclinkintermediatenodes[jb]))
		var intermediatepts = [ ]
		if nintermediatenodes != 0:
			for i in range(nintermediatenodes):
				var p1mtrans = intermedpointposT(p0, p1, xclinkintermediatenodes[jb][i])
				intermediatepts.push_back(p1mtrans.origin)
				var inodename = encodeintermediatenodename(jb, i)
				var inode = $PathLines.get_node_or_null(inodename)
				if inode == null:
					inode = preload("res://nodescenes/XCnode_intermediate.tscn").instance()
					inode.set_name(inodename)
					$PathLines.add_child(inode)
				inode.global_transform = p1mtrans
		var im = nintermediatenodes 
		while true:
			var imnodename = encodeintermediatenodename(jb, im)
			if not $PathLines.has_node(imnodename):
				break
			$PathLines.get_node(imnodename).queue_free()
			im += 1
		Polynets.addarrowmesh(surfaceTool, p0, p1, perp, tubelinklinewidth, intermediatepts)
			
	var jbm = len(xcdrawinglink) 
	while $PathLines.has_node(encodeintermediatenodename(jbm, 0)):
		var im = 0
		var imnodename = encodeintermediatenodename(jbm, im)
		if not $PathLines.has_node(imnodename):
			break
		$PathLines.get_node(imnodename).queue_free()
		im += 1

	if nlinksfound == 0:
		return false
	surfaceTool.generate_normals()
	$PathLines.mesh = surfaceTool.commit()
	assert($PathLines.get_surface_material_count() != 0)
	$PathLines.set_surface_material(0, get_node("/root/Spatial/MaterialSystem").pathlinematerial("normal"))
	return true


func fa(a, b):
	return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1])

func reordersecondvalstoavoiddoublelooping(ila):
	for i in range(len(ila)):
		var im1 = len(ila)-1 if i == 0 else i-1
		if ila[i][1] != ila[im1][1]:
			var i1 = i
			while i1 < len(ila) - 1 and ila[i1+1][0] == ila[i][0]:
				i1 += 1
			var i1p1 = (i1+1)%len(ila)
			if ila[im1][1] > ila[i][1] and ila[i1][1] > ila[i1p1][1] and i1 != i:
				var ilai = ila[i]
				for j in range(i, i1):
					ila[j] = ila[j+1]
				ila[i1] = ilai

func detectdualconicalproblemwarning(ila, lenpoly1):
	for i in range(len(ila)):
		if i == 0 or ila[i][0] != ila[i-1][0]:
			var i1 = i
			while i1 < len(ila) - 1 and ila[i1+1][0] == ila[i][0]:
				i1 += 1
			if i != i1:
				var ila1N = ila[i1][1] - ila[i][1]
				if ila1N < 0:
					ila1N += lenpoly1
				if ila1N > lenpoly1/2:
					return true
	return false			

func maketubepolyassociation_andreorder(xcdrawing0, xcdrawing1):
	assert ((xcdrawing0.get_name() == xcname0) and (xcdrawing1.get_name() == xcname1))
	var polysdict0 = Polynets.makexcdpolysDict(xcdrawing0.nodepoints, xcdrawing0.onepathpairs)
	var polysdict1 = Polynets.makexcdpolysDict(xcdrawing1.nodepoints, xcdrawing1.onepathpairs)
	var polys0islinearpath = polysdict0.has("linearpath")
	var polys1islinearpath = polysdict1.has("linearpath")
	
	#assert ((len(polys0) != 1) or (len(polys0[0]) == 0))
	#assert ((len(polys1) != 1) or (len(polys1[0]) == 0))
	pickedpolykey0 = Polynets.pickpolyskey(polysdict0, xcdrawinglink, 0)
	pickedpolykey1 = Polynets.pickpolyskey(polysdict1, xcdrawinglink, 1)
	
	if pickedpolykey0 == "" or pickedpolykey1 == "" or len(xcdrawinglink) == 0:
		if pickedpolykey0 == "":
			print(" *** no connecting poly available ", xcname0, polysdict0, " 0:", xcdrawinglink)
		if pickedpolykey1 == "":
			print(" *** no connecting poly available ", xcname1, polysdict1, " 1:", xcdrawinglink)
		return [[], [], []]

	var tubevec = xcdrawing1.transform.xform(xcdrawing1.nodepointmean) - xcdrawing0.transform.xform(xcdrawing0.nodepointmean)
	var xcdrawing0basisz = xcdrawing0.transform.basis.z
	var xcdrawing1basisz = xcdrawing1.transform.basis.z
	var tubevecdot0 = xcdrawing0basisz.dot(tubevec)
	var tubevecdot1 = xcdrawing1basisz.dot(tubevec)
	var polyinvert0 = (tubevecdot0 <= 0) == (pickedpolykey0 != "outerpoly")
	var polyinvert1 = (tubevecdot1 <= 0) == (pickedpolykey1 != "outerpoly")
	#var tubenormdot = xcdrawing0basisz.dot(xcdrawing1basisz)
	#if ((tubenormdot < 0) == (polyinvert0 == polyinvert1)) and not polys0islinearpath and not polys1islinearpath:
	#	print("invert problem?")

	var poly0 = polysdict0[pickedpolykey0].duplicate()
	var poly1 = polysdict1[pickedpolykey1].duplicate()
	if polyinvert0:
		poly0.invert()
	var ilp0 = poly0.find(xcdrawinglink[0])
	if ilp0 != 0 and not polys0islinearpath:
		poly0 = poly0.slice(ilp0, len(poly0)-1) + poly0.slice(0, ilp0-1)
	if polyinvert1:
		poly1.invert()
	var ilp1 = poly1.find(xcdrawinglink[1])
	if ilp1 != 0 and not polys1islinearpath:
		poly1 = poly1.slice(ilp1, len(poly1)-1) + poly1.slice(0, ilp1-1)

	while len(xcsectormaterials) < len(xcdrawinglink)/2:
		xcsectormaterials.append(get_node("/root/Spatial/MaterialSystem").tubematerialnamefromnumber(0 if ((len(xcsectormaterials)%2) == 0) else 1))
	xcsectormaterials.resize(len(xcdrawinglink)/2)

	# get all the connections in here between the polygons but in the right order
	var ila = [ ]  # [ [il0, il1] ] then [ {"il0", "il1", "j", "il0N", il1N" ] ]
	var xcdrawinglinkneedsreorder = false
	var missingjvals = [ ]
	var _il0coincident = true
	var il1coincident = true
	var loops1 = 0
	for j in range(0, len(xcdrawinglink), 2):
		var il0 = poly0.find(xcdrawinglink[j])
		var il1 = poly1.find(xcdrawinglink[j+1])
		if j != 0:
			if il0 != ila[-1][0]:
				_il0coincident = false
			if il1 != ila[-1][1]:
				il1coincident = false
		if il0 != -1 and il1 != -1:
			if j != 0 and len(ila) != 0:
				if ila[-1][0] > il0:
					xcdrawinglinkneedsreorder = true
				if ila[-1][1] > il1:
					loops1 += 1
			ila.append([il0, il1, j])
		else:
			missingjvals.append(j)
	if ila[-1][1] > ila[0][1]:
		loops1 += 1
	assert ((loops1 == 0) == il1coincident)
	if loops1 == 2:
		xcdrawinglinkneedsreorder = true
	
	if xcdrawinglinkneedsreorder or (len(missingjvals) != 0 and (missingjvals.min() < len(xcdrawinglink) - 2*len(missingjvals))):
		ila.sort_custom(self, "fa")
		reordersecondvalstoavoiddoublelooping(ila)
		if detectdualconicalproblemwarning(ila, len(poly1)):
			print("dualconicalproblemwarning on tube: ", get_name())
		var newxcdrawinglink = [ ]
		var newxcsectormaterials = [ ]
		var newxclinkintermediatenodes = null
		if xclinkintermediatenodes != null:
			 newxclinkintermediatenodes = [ ]
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
			var sketchsystem = get_node("/roost/Spatial/SketchSystem")
			updatetubelinkpaths(sketchsystem)

	else:
		if detectdualconicalproblemwarning(ila, len(poly1)):
			print("dualconicalproblemwarning on tube: ", get_name())

	var ilaM = [ ]  #  [ {"il0", "il0N",  "il1", "il1N",    "i", "i1" ] ]
	var sum0N = 0
	var sum1N = 0
	for i in range(len(ila)):
		var i1 = (i+1)%len(ila)
		var ila0 = ila[i][0]
		var ila0N = ila[i1][0] - ila0
		if i1 == 0:
			ila0N += len(poly0)
		assert (ila0N >= 0)
		var ila1 = ila[i][1]
		var ila1N = ila[i1][1] - ila1
		if (ila1N < 0) or (il1coincident and i1 == 0):
			ila1N += len(poly1)
		sum0N += ila0N
		sum1N += ila1N
		ilaM.append({"ila0":ila0, "ila0N":ila0N,   "ila1":ila1, "ila1N":ila1N,   "i":i, "i1":i1})
	if sum0N != len(poly0) or sum1N != len(poly1):
		print("warning wrong looped polys ", [sum0N, len(poly0)], [sum1N, len(poly1)])
		reordersecondvalstoavoiddoublelooping(ila)
		
	if polys0islinearpath:
		assert (pickedpolykey0 == "linearpath")
		for j in range(len(ilaM)):
			if ilaM[j]["ila0"] == len(poly0)-1 and ilaM[j]["ila0N"] == 1:
				ilaM[j]["opensector"] = true
				break
	if polys1islinearpath:
		assert (pickedpolykey1 == "linearpath")
		for j in range(len(ilaM)):
			if ilaM[j]["ila1"] == len(poly1)-1 and ilaM[j]["ila1N"] == 1:
				ilaM[j]["opensector"] = true
				break
	return [poly0, poly1, ilaM]
	
	
func slicetubetoxcdrawing(xcdrawing, xcdata, xctdatadel, xctdata0, xctdata1):
	var xcdrawings = get_node("/root/Spatial/SketchSystem/XCdrawings")
	var xcdrawing0 = xcdrawings.get_node(xcname0)
	var xcdrawing1 = xcdrawings.get_node(xcname1)
	var mtpa = maketubepolyassociation_andreorder(xcdrawing0, xcdrawing1)
	var poly0 = mtpa[0]
	var poly1 = mtpa[1]
	var ilaM = mtpa[2]
	if len(ilaM) == 0:
		return false
	
	var xcnodes0 = xcdrawing0.get_node("XCnodes")
	var xcnodes1 = xcdrawing1.get_node("XCnodes")
	var xcnamefirst = null	
	var xcnamelast = null
	var lamoutofrange = false
	var xcnormal = xcdrawing.transform.basis.z
	var xcdot = xcnormal.dot(xcdrawing.transform.origin)
	var sliceclearancedist = 0.02
	var prevpathisopensector = true
	var opensectornodepoints = [ ]
	for li in range(len(ilaM)):
		var i = ilaM[li]["i"]
		assert (i == li)
		var ila0 = ilaM[li]["ila0"]
		var ila0N = ilaM[li]["ila0N"]
		var ila1 = ilaM[li]["ila1"]
		var ila1N = ilaM[li]["ila1N"]
		var isopensector = ilaM[li].get("opensector", false)
		var acc = -ila0N/2.0  if ila0N>=ila1N  else  ila1N/2.0
		var i0 = 0
		var i1 = 0
		while i0 < ila0N or i1 < ila1N:
			var pt0 = xcnodes0.get_node(poly0[(ila0+i0)%len(poly0)]).global_transform.origin
			var pt1 = xcnodes1.get_node(poly1[(ila1+i1)%len(poly1)]).global_transform.origin
			# 0 = xcdrawing.global_transform.basis.z.dot(pt0 + lam*(pt1 - pt0) - xcdrawing.global_transform.origin)
			# lam*xcdrawing.global_transform.basis.z.dot(pt0 - pt1) = xcdrawing.global_transform.basis.z.dot(pt0 - xcdrawing.global_transform.origin)
			var ptvec = pt0 - pt1
			var lam = (xcnormal.dot(pt0) - xcdot)/xcnormal.dot(ptvec)
			var lamfromedge = min(lam, 1 - lam)
			if lam < 0.0 or lamfromedge*ptvec.length() < sliceclearancedist:
				print("Slice point out of range ", lam)
				lamoutofrange = true
			var xcpoint = xcdrawing.transform.xform_inv(lerp(pt0, pt1, lam))
			xcpoint.z = 0.0

			var xcname = xcdrawing.newuniquexcnodename("p")
			if i0 == 0 and i1 == 0:
				xctdatadel["prevdrawinglinks"].push_back(poly0[ila0])
				xctdatadel["prevdrawinglinks"].push_back(poly1[ila1])
				xctdatadel["prevdrawinglinks"].push_back(xcsectormaterials[i])
				xctdatadel["prevdrawinglinks"].push_back(xclinkintermediatenodes[i] if xclinkintermediatenodes != null else null)

				var iin = 0

				xctdata0["newdrawinglinks"].push_back(poly0[ila0])
				xctdata0["newdrawinglinks"].push_back(xcname)
				xctdata0["newdrawinglinks"].push_back(xcsectormaterials[i])
				if xclinkintermediatenodes != null:
					xctdata0["newdrawinglinks"].push_back([])
					while iin < len(xclinkintermediatenodes[i]) and xclinkintermediatenodes[i][iin].z < lam-0.01:
						xctdata0["newdrawinglinks"].back().push_back(Vector3(xclinkintermediatenodes[i][iin].x, xclinkintermediatenodes[i][iin].y, inverse_lerp(0, lam, xclinkintermediatenodes[i][iin].z)))
						iin += 1
				else:
					xctdata0["newdrawinglinks"].push_back(null)

				xctdata1["newdrawinglinks"].push_back(xcname)
				xctdata1["newdrawinglinks"].push_back(poly1[ila1])
				xctdata1["newdrawinglinks"].push_back(xcsectormaterials[i])
				if xclinkintermediatenodes != null:
					xctdata1["newdrawinglinks"].push_back([])
					while iin < len(xclinkintermediatenodes[i]):
						if xclinkintermediatenodes[i][iin].z > lam+0.01:
							xctdata1["newdrawinglinks"].back().push_back(Vector3(xclinkintermediatenodes[i][iin].x, xclinkintermediatenodes[i][iin].y, inverse_lerp(lam, 1, xclinkintermediatenodes[i][iin].z)))
						iin += 1
				else:
					xctdata1["newdrawinglinks"].push_back(null)
			
			xcdata["nextnodepoints"][xcname] = xcpoint
			assert (i0 <= ila0N and i1 <= ila1N)
			if i0 < ila0N and (acc - ila0N < 0 or i1 == ila1N):
				acc += ila1N
				i0 += 1
			if i1 < ila1N and (acc >= 0 or i0 == ila0N):
				acc -= ila0N
				i1 += 1
			if xcnamelast != null:
				if not prevpathisopensector:
					xcdata["newonepathpairs"].push_back(xcnamelast)
					xcdata["newonepathpairs"].push_back(xcname)
				else:
					opensectornodepoints.push_back(xcnamelast)
					opensectornodepoints.push_back(xcname)
			xcnamelast = xcname
			prevpathisopensector = isopensector
			if xcnamefirst == null:
				xcnamefirst = xcname
	if not prevpathisopensector:
		xcdata["newonepathpairs"].push_back(xcnamelast)
		xcdata["newonepathpairs"].push_back(xcnamefirst)
	else:
		opensectornodepoints.push_back(xcnamelast)
		opensectornodepoints.push_back(xcnamefirst)
		
	if len(opensectornodepoints) != 0:
		opensectornodepoints.sort()
		while len(opensectornodepoints) >= 2:
			if opensectornodepoints[-2] == opensectornodepoints[-1]:
				xcdata["nextnodepoints"].erase(opensectornodepoints[-1])
				opensectornodepoints.pop_back()
			opensectornodepoints.pop_back()
	
	if lamoutofrange:
		return false
	return true



func HoleName(i):
	return "Hole"+("" if i == 0 else ";"+str(i))+";"+xcname0+";"+xcname1

func ConstructHoleXC(i, sketchsystem):
	assert (xcsectormaterials[i] == "hole")
	var xcdrawingholename = HoleName(i)
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

	var xcdrawinghole = sketchsystem.get_node("XCdrawings").get_node_or_null(xcdrawingholename)
	if xcdrawinghole != null:
		xcdata["prevonepathpairs"] = xcdrawinghole.onepathpairs.duplicate()
		xcdata["prevnodepoints"] = xcdrawinghole.nodepoints.duplicate()

	var shellcontour = extractshellcontourforholexc(sketchsystem, i)
	if shellcontour == null:
		return null
	var prevname = shellcontour[-1][0]
	for sc in shellcontour:
		xcdata["nextnodepoints"][sc[0]] = xcdata["transformpos"].xform_inv(sc[1])
		xcdata["newonepathpairs"].push_back(prevname)
		xcdata["newonepathpairs"].push_back(sc[0])
		prevname = sc[0]
	return xcdata

func gettubeshellholes(sketchsystem):
	var tubeshellholeindexes = null
	for i in range(len(xcsectormaterials)):
		if xcsectormaterials[i] == "hole":
			var xcdrawingholename = HoleName(i)
			var xcdrawinghole = sketchsystem.get_node("XCdrawings").get_node_or_null(xcdrawingholename)
			if xcdrawinghole != null and len(xcdrawinghole.nodepoints) != 0:
				if tubeshellholeindexes == null:
					tubeshellholeindexes = [ xcdrawinghole ]
				tubeshellholeindexes.push_back(i)
	return tubeshellholeindexes

func FixtubeholeXCs(sketchsystem):
	var xcdatashellholes = [ ]
	for i in range(len(xcsectormaterials)):
		if xcsectormaterials[i] == "hole":
			xcdatashellholes.push_back(ConstructHoleXC(i, sketchsystem))
	var currentholexcnamesindexdistance = [ ]
	
	for i in range(len(xcsectormaterials)+5):
		var xcdrawingholename = HoleName(i)
		var xcdrawinghole = sketchsystem.get_node("XCdrawings").get_node_or_null(xcdrawingholename)
		if xcdrawinghole != null and len(xcdrawinghole.nodepoints) != 0:
			var cdist = -1.0
			var cj = -1
			for j in range(len(xcdatashellholes)):
				var dist = xcdrawinghole.measurexcmatch(xcdatashellholes[j]["transformpos"], xcdatashellholes[j]["nextnodepoints"])
				if cj == -1 or dist < cdist:
					cj = j
					cdist = dist
			currentholexcnamesindexdistance.push_back([cdist, xcdrawingholename, cj])
			
	currentholexcnamesindexdistance.sort()
	print("HoleXC association for xcdrawing renaming", currentholexcnamesindexdistance)
	var holexcorgnames = [ ]
	var holexcnewconstructs = [ ]
	var holexcnewnames = [ ]
	for i in range(len(currentholexcnamesindexdistance)):
		var holexcnewconstruct = xcdatashellholes[currentholexcnamesindexdistance[i][2]]
		if currentholexcnamesindexdistance[i][0] < 0.1 and not holexcnewnames.has(holexcnewconstruct["name"]):
			holexcnewnames.push_back(holexcnewconstruct["name"])
			if holexcnewconstruct["name"] != currentholexcnamesindexdistance[i][1]:
				holexcorgnames.push_back(currentholexcnamesindexdistance[i][1])
				holexcnewconstructs.push_back(holexcnewconstruct)
	if len(holexcorgnames) == 0:
		return null

	var xctdatatubedel = [ ]
	var xctdatatubenew = [ ]
	var xctdatadrawingdel = [ ]
	var updatetubeshells = [ ]
	var xcvizstates = { }
	for i in range(len(holexcorgnames)):
		var xcdrawingorgname = holexcorgnames[i]
		var xcdrawingnewname = holexcnewconstructs[i]["name"]
		var xcdrawing = sketchsystem.get_node("XCdrawings").get_node(xcdrawingorgname)
		print("ChangeHoleXCname ", xcdrawingorgname, " to ", xcdrawingnewname)
		for xctube in xcdrawing.xctubesconn:
			var drawinglinks = [ ]
			for j in range(0, len(xctube.xcdrawinglink), 2):
				drawinglinks.push_back(xctube.xcdrawinglink[j])
				drawinglinks.push_back(xctube.xcdrawinglink[j+1])
				drawinglinks.push_back(xctube.xcsectormaterials[j/2])
				drawinglinks.push_back(xctube.xclinkintermediatenodes[j/2] if xctube.xclinkintermediatenodes != null else null)
			xctdatatubedel.push_back({ "tubename":xctube.get_name(), 
									   "xcname0":xctube.xcname0, 
									   "xcname1":xctube.xcname1,
									   "prevdrawinglinks":drawinglinks,
									   "newdrawinglinks":[ ] })
			var xcname0new = xcdrawingnewname if xctube.xcname0 == xcdrawingorgname else xctube.xcname0
			var xcname1new = xcdrawingnewname if xctube.xcname1 == xcdrawingorgname else xctube.xcname1
			xctdatatubenew.push_back({ "tubename":"**notset", 
									   "xcname0":xcname0new, 
									   "xcname1":xcname1new,
									   "prevdrawinglinks":[ ],
									   "newdrawinglinks":drawinglinks })
			sketchsystem.setnewtubename(xctdatatubenew[-1])
			updatetubeshells.push_back({"tubename":xctdatatubenew[-1]["tubename"], "xcname0":xcname0new, "xcname1":xcname1new})

		xctdatadrawingdel.push_back({ "name":xcdrawingorgname, 
									  "prevnodepoints":xcdrawing.nodepoints.duplicate(),
									  "nextnodepoints":{ }, 
									  "prevonepathpairs":xcdrawing.onepathpairs.duplicate(),
									  "newonepathpairs": [ ] })
		xcvizstates[xcdrawingorgname] = DRAWING_TYPE.VIZ_XCD_HIDE
	var xcv = { "xcvizstates":xcvizstates, 
				"updatetubeshells":updatetubeshells,
				"updatexcshells":[ ] }
	for i in range(len(holexcorgnames)):
		var xcdrawingnewname = holexcnewconstructs[i]["name"]
		xcv["xcvizstates"][xcdrawingnewname] = DRAWING_TYPE.VIZ_XCD_NODES_VISIBLE
		xcv["updatexcshells"].push_back(xcdrawingnewname)
	return xctdatatubedel + xctdatadrawingdel + holexcnewconstructs + xctdatatubenew + [ xcv ]



static func get_pt(xcdrawing, poly, ila, i):
	return xcdrawing.transform * xcdrawing.nodepoints[poly[(ila+i)%len(poly)]]

static func initialtuberails(xcdrawing0, poly0, ila0, ila0N, xcdrawing1, poly1, ila1, ila1N):
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
			uvi0 = Polynets.advanceuvFar(uvi1, pti1, uvi0, pti0, pti0next, true)
			pti0 = pti0next
		if i1 < ila1N and (acc >= 0 or i0 == ila0N):
			acc -= ila0N
			i1 += 1
			var pti1next = get_pt(xcdrawing1, poly1, ila1, i1)
			uvi1 = Polynets.advanceuvFar(uvi0, pti0, uvi1, pti1, pti1next, false)
			pti1 = pti1next
		tuberail0.push_back([pti0, uvi0, i0*1.0/ila0N if ila0N != 0 else 1.0])
		tuberail1.push_back([pti1, uvi1, i1*1.0/ila1N if ila1N != 0 else 1.0])
	return [tuberail0, tuberail1]
		


	
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
	var xcdrawing0 = xcdrawings.get_node(xcname0)
	var xcdrawing1 = xcdrawings.get_node(xcname1)
	if xcdrawing0.drawingtype != DRAWING_TYPE.DT_XCDRAWING or xcdrawing1.drawingtype != DRAWING_TYPE.DT_XCDRAWING:
		print("skipping updatetubeshell on ", get_name())
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
		
	var mtpa = maketubepolyassociation_andreorder(xcdrawing0, xcdrawing1)
	var poly0 = mtpa[0]
	var poly1 = mtpa[1]
	var ilaM = mtpa[2]

	for li in range(len(ilaM)):
		if ilaM[li].get("opensector", false):
			continue
		var i = ilaM[li]["i"]
		var i1 = ilaM[li]["i1"]
		var ila0 = ilaM[li]["ila0"]
		var ila0N = ilaM[li]["ila0N"]
		var ila1 = ilaM[li]["ila1"]
		var ila1N = ilaM[li]["ila1N"]
			

		var tuberails = initialtuberails(xcdrawing0, poly0, ila0, ila0N, xcdrawing1, poly1, ila1, ila1N)
		var tuberail0 = tuberails[0]
		var tuberail1 = tuberails[1]
		var surfaceTool = SurfaceTool.new()
		surfaceTool.begin(Mesh.PRIMITIVE_TRIANGLES)
		if xclinkintermediatenodes != null:
			assert (len(ilaM) <= len(xclinkintermediatenodes))
			var xclinkintermediatenodesi = xclinkintermediatenodes[i]
			var xclinkintermediatenodesi1 = xclinkintermediatenodes[i1]
			var railsequencerung0 = [ ]
			var railsequencerung1 = [ ]
			Polynets.intermediaterailsequence(xclinkintermediatenodesi, xclinkintermediatenodesi1, railsequencerung0, railsequencerung1)
			assert(len(railsequencerung0) == len(railsequencerung1))
			var tuberailk0 = tuberail0
			for k in range(len(railsequencerung0)+1):
				var tuberailk1
				if k < len(railsequencerung0):
					tuberailk1 = slicerungsatintermediatetuberail(tuberail0, tuberail1, railsequencerung0[k], railsequencerung1[k])
				else:
					tuberailk1 = tuberail1
				Polynets.triangulatetuberails(surfaceTool, tuberailk0, tuberailk1)
				tuberailk0 = tuberailk1
		else:
			Polynets.triangulatetuberails(surfaceTool, tuberail0, tuberail1)
		surfaceTool.generate_normals()
		surfaceTool.generate_tangents()
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
			var xcdrawinghole = sketchsystem.get_node("XCdrawings").get_node_or_null(HoleName(i))
			if xcdrawinghole != null:
				if len(xcdrawinghole.nodepoints) != 0 and (xcdrawinghole.drawingvisiblecode & DRAWING_TYPE.VIZ_XCD_PLANE_VISIBLE) == 0:
					xctubesector.get_node("MeshInstance").visible = false
					xctubesector.get_node("CollisionShape").disabled = true
		$XCtubesectors.add_child(xctubesector)
		if Tglobal.hidecavewallstoseefloors:
			xctubesector.visible = false


func shellcontourxcside(xcdrawing, poly, ila, ilaN, pref):
	var scc = [ ]
	for j in range(ilaN+1):
		var nodename = poly[(ila+j)%len(poly)]
		scc.push_back([pref%nodename, xcdrawing.transform * xcdrawing.nodepoints[nodename]])
	return scc
	
func shellcontourintermed(p0, p1, xclinkintermediatenodeds, pref):
	var scc = [ ]
	for j in range(len(xclinkintermediatenodeds)):
		var dp = xclinkintermediatenodeds[j]
		var sp = lerp(p0, p1, dp.z)
		var spbasis = intermedpointplanebasis(sp)
		scc.push_back([pref%j, sp + spbasis.x*dp.x + spbasis.y*dp.y])
	return scc
	
func extractshellcontourforholexc(sketchsystem, li):
	var xcdrawings = sketchsystem.get_node("XCdrawings")
	var xcdrawing0 = xcdrawings.get_node(xcname0)
	var xcdrawing1 = xcdrawings.get_node(xcname1)
	var mtpa = maketubepolyassociation_andreorder(xcdrawing0, xcdrawing1)
	var poly0 = mtpa[0]
	var poly1 = mtpa[1]
	var ilaM = mtpa[2]

	var i = ilaM[li]["i"]
	var i1 = ilaM[li]["i1"]
	var ila0 = ilaM[li]["ila0"]
	var ila0N = ilaM[li]["ila0N"]
	var ila1 = ilaM[li]["ila1"]
	var ila1N = ilaM[li]["ila1N"]

	var scc0 = shellcontourxcside(xcdrawing0, poly0, ila0, ila0N, "r0%s")
	var scc1 = shellcontourxcside(xcdrawing1, poly1, ila1, ila1N, "r1%s")
	var scctop
	var sccbot
	if xclinkintermediatenodes != null:
		scctop = shellcontourintermed(scc0[-1][1], scc1[-1][1], xclinkintermediatenodes[i1], "rt%d")
		sccbot = shellcontourintermed(scc0[0][1], scc1[0][1], xclinkintermediatenodes[i], "rb%d")
	else:
		scctop = [ ]
		sccbot = [ ]
	scc1.invert()
	sccbot.invert()
	return scc0 + scctop + scc1 + sccbot


func xctubetransitivechain(sketchsystem, xcdrawing0, nodename0, xcdrawing1, nodename1):
	assert (xcdrawing0.get_name() == xcname0)
	assert (xcdrawing1.get_name() == xcname1)
	var nodepoint0 = xcdrawing0.transform.xform(xcdrawing0.nodepoints[nodename0])
	var nodepoint1 = xcdrawing1.transform.xform(xcdrawing1.nodepoints[nodename1])
	var nodepointvec = nodepoint1 - nodepoint0
	var nodepointvecsq = nodepointvec.length_squared()
	var xcnamei = xcname0
	var nodenamej = nodename0
	var nodepointi = nodepoint0
	var lami = 0.0
	var xcdrawingi = xcdrawing0
	var ptseq = [ nodepoint0 ]
	var excltube = self
	for _k in range(5):
		var xctubei = null
		var xcnamei1 = null
		var xcdrawingi1 = null
		var dlinki = -1
		var nodenamej1 = null
		var lami1 = 0.0
		var nodepointi1 = null
		for xctubeconn in xcdrawingi.xctubesconn:
			if xctubeconn != excltube:
				if xctubeconn.xcname0 == xcnamei:
					xcnamei1 = xctubeconn.xcname1
					for i in range(0, len(xctubeconn.xcdrawinglink), len(xctubeconn.xcdrawinglink)-2):
						if xctubeconn.xcdrawinglink[i] == nodenamej:
							dlinki = int(i/2)
							nodenamej1 = xctubeconn.xcdrawinglink[i+1]
				else:
					assert (xctubeconn.xcname1 == xcnamei)
					xcnamei1 = xctubeconn.xcname0
					for i in range(0, len(xctubeconn.xcdrawinglink), len(xctubeconn.xcdrawinglink)-2):
						if xctubeconn.xcdrawinglink[i+1] == nodenamej:
							dlinki = int(i/2)
							nodenamej1 = xctubeconn.xcdrawinglink[i]
				if nodenamej1 != null:
					xcdrawingi1 = sketchsystem.get_node("XCdrawings").get_node(xcnamei1)
					nodepointi1 = xcdrawingi1.transform.xform(xcdrawingi1.nodepoints[nodenamej1])
					lami1 = nodepointvec.dot(nodepointi1 - nodepoint0)/nodepointvecsq
					if xcnamei1 == xcname1 or (lami1 > lami and lami1 < 1.0):
						assert (xcnamei1 != xcname1 or is_equal_approx(lami1, 1.0))
						xctubei = xctubeconn
						break
		if xctubei == null:
			return null

		if xctubei.xclinkintermediatenodes != null:
			var transintermednodes = xctubei.xclinkintermediatenodes[dlinki]
			print(xctubei.xcdrawinglink, transintermednodes)
			if xctubei.xcname0 == xcnamei:
				assert (xctubei.xcdrawinglink[dlinki*2+1] == nodenamej1)
				for dp in transintermednodes:
					ptseq.push_back(xctubei.intermedpointpos(nodepointi, nodepointi1, dp))
			else:
				assert (xctubei.xcname1 == xcnamei)
				assert (xctubei.xcdrawinglink[dlinki*2] == nodenamej1)
				for l in range(len(transintermednodes)-1, -1, -1):
					ptseq.push_back(xctubei.intermedpointpos(nodepointi1, nodepointi, transintermednodes[l]))

		if xcnamei1 == xcname1:
			if nodenamej1 == nodename1:
				assert (nodepointi1.is_equal_approx(nodepoint1))
				ptseq.push_back(nodepoint1)
				return ptseq
			else:
				return null

		lami = lami1
		xcnamei = xcnamei1
		xcdrawingi = xcdrawingi1
		nodenamej = nodenamej1
		nodepointi = nodepointi1
		ptseq.push_back(nodepointi1)
		excltube = xctubei
		
	print("failed to transitive chain in 5 steps")
	return null

func remaptransitivechaintointermediates(transchain):
	var intermediatepoints = [ ]
	var p0 = transchain[0]
	var p1 = transchain[-1]
	for i in range(1, len(transchain)-1):
		var p = transchain[i]
		var ipbasis = intermedpointplanebasis(p)
		var l0 = ipbasis.z.dot(p0)
		var l1 = ipbasis.z.dot(p1)
		var lp = ipbasis.z.dot(p)
		var intermediatepointplanelambda = inverse_lerp(l0, l1, lp)
		var pc = intermedpointpos(p0, p1, Vector3(0, 0, intermediatepointplanelambda))
		var ix = ipbasis.x.dot(p - pc)
		var iy = ipbasis.y.dot(p - pc)
		var dp = Vector3(ix, iy, intermediatepointplanelambda)
		var Dp = intermedpointpos(p0, p1, dp)
		print(p, Dp)
		assert (p.is_equal_approx(intermedpointpos(p0, p1, dp)))
		intermediatepoints.push_back(dp)
	return intermediatepoints

func CopyHoleGapShape(li, sketchsystem):
	assert (xcsectormaterials[li] == "holegap")

	var xcdrawings = sketchsystem.get_node("XCdrawings")
	var xcdrawing0 = xcdrawings.get_node(xcname0)
	var xcdrawing1 = xcdrawings.get_node(xcname1)
	var mtpa = maketubepolyassociation_andreorder(xcdrawing0, xcdrawing1)
	var ilaM = mtpa[2]

	var i = ilaM[li]["i"]
	var i1 = ilaM[li]["i1"]
	assert (i == li)

	var transchain0 = xctubetransitivechain(sketchsystem, xcdrawing0, xcdrawinglink[i*2], xcdrawing1, xcdrawinglink[i*2+1])
	var transchain1 = xctubetransitivechain(sketchsystem, xcdrawing0, xcdrawinglink[i1*2], xcdrawing1, xcdrawinglink[i1*2+1])
	if transchain0 == null or transchain1 == null:
		return null
		
	var prevdrawinglinks = [ xcdrawinglink[i*2], xcdrawinglink[i*2+1], null, xclinkintermediatenodes[i].duplicate() if xclinkintermediatenodes != null else [], 
							 xcdrawinglink[i1*2], xcdrawinglink[i1*2+1], null, xclinkintermediatenodes[i1].duplicate() if xclinkintermediatenodes != null else [] ]
							
	var newdrawinglinks = [ xcdrawinglink[i*2], xcdrawinglink[i*2+1], null, remaptransitivechaintointermediates(transchain0), 
							xcdrawinglink[i1*2], xcdrawinglink[i1*2+1], null, remaptransitivechaintointermediates(transchain1) ]
	var xctdata = { "tubename":get_name(),
					"xcname0":xcname0,
					"xcname1":xcname1,
					"prevdrawinglinks":prevdrawinglinks,
					"newdrawinglinks":newdrawinglinks
				  }

	return xctdata


	
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
		for _ji in range(len(xcdrawinglink)/2):
			xclinkintermediatenodes.push_back([])
	assert(len(xclinkintermediatenodes) == len(xcdrawinglink)/2)
	var i = 0
	while i < len(xclinkintermediatenodes[j]) and xclinkintermediatenodes[j][i].z <= dv.z:
		i += 1
	if i < len(xclinkintermediatenodes[j]) and xclinkintermediatenodes[j][i].z == dv.z:
		xclinkintermediatenodes[j][i] = dv
	else:
		xclinkintermediatenodes[j].insert(i, dv)
		
func intermediatenodelerp(j, dvz):
	if xclinkintermediatenodes == null:
		return Vector3(0, 0, dvz)
	var i = 0
	while i < len(xclinkintermediatenodes[j]) and xclinkintermediatenodes[j][i].z <= dvz:
		i += 1
	var xcl0 = Vector3(0, 0, 0) if i == 0 else xclinkintermediatenodes[j][i-1]
	var xcl1 = Vector3(0, 0, 1) if i == len(xclinkintermediatenodes[j]) else xclinkintermediatenodes[j][i]
	var llam = inverse_lerp(xcl0.z, xcl1.z, dvz)
	var res = lerp(xcl0, xcl1, llam)
	assert (is_equal_approx(res.z, dvz))
	res.z = dvz
	return res
	
	
