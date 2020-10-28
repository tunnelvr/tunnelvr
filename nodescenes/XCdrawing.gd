extends Spatial

const XCnode = preload("res://nodescenes/XCnode.tscn")
const XCnode_centreline = preload("res://nodescenes/XCnode_centreline.tscn")

# primary data
var xcresource = ""     # source file
var nodepoints = { }    # { nodename:Vector3 } in local coordinate system
var onepathpairs = [ ]  # [ Anodename0, Anodename1, Bnodename0, Bnodename1, ... ]
var drawingtype = DRAWING_TYPE.DT_XCDRAWING
var xcflatshellmaterial = "simpledirt"

var imgwidth = 0
var imgtrimleftdown = Vector2(0,0)
var imgtrimrightup = Vector2(0,0)

# derived data
var xctubesconn = [ ]   # references to xctubes that connect to here (could use their names instead)
var maxnodepointnumber = 0
var imgheightwidthratio = 0  # known from the xcresource image (though could be cached)

var linewidth = 0.05

func setxcdrawingvisiblehide(hidenodes):
	assert ($XCdrawingplane.visible != $XCdrawingplane/CollisionShape.disabled)	
	$XCdrawingplane.visible = false
	$XCdrawingplane/CollisionShape.disabled = true
	if hidenodes:
		$XCnodes.visible = Tglobal.tubedxcsvisible or (drawingtype != DRAWING_TYPE.DT_XCDRAWING) or (len(xctubesconn) == 0)
		$PathLines.visible = $XCnodes.visible
		for xcn in $XCnodes.get_children():
			xcn.get_node("CollisionShape").disabled = true
	assert ($XCdrawingplane.visible != $XCdrawingplane/CollisionShape.disabled)

func setxcdrawingvisible():
	assert ($XCdrawingplane.visible != $XCdrawingplane/CollisionShape.disabled)	
	if not $XCdrawingplane.visible and drawingtype == DRAWING_TYPE.DT_XCDRAWING:
		var scax = 0.0
		var scay = 0.0
		for nodepoint in nodepoints.values():
			scax = max(scax, abs(nodepoint.x))
			scay = max(scay, abs(nodepoint.y))
		$XCdrawingplane.set_scale(Vector3(scax + 2, scay + 2, 1.0))
	if not get_name().begins_with("Hole"):
		$XCdrawingplane.visible = true
		$XCdrawingplane/CollisionShape.disabled = false
	$XCnodes.visible = true
	$PathLines.visible = true
	for xcn in $XCnodes.get_children():
		xcn.get_node("CollisionShape").disabled = false
	assert ($XCdrawingplane.visible != $XCdrawingplane/CollisionShape.disabled)

		
func updateformetresquaresscaletexture():
	var mat = $XCdrawingplane/CollisionShape/MeshInstance.get_surface_material(0)
	mat.uv1_scale = $XCdrawingplane.get_scale()
	mat.uv1_offset = -$XCdrawingplane.get_scale()/2

func expandxcdrawingscale(nodepointglobal):
	var nodepointlocal = global_transform.xform_inv(nodepointglobal)
	var ascax = abs(nodepointlocal.x) + 2
	var ascay = abs(nodepointlocal.y) + 2
	if ascax > $XCdrawingplane.scale.x:
		$XCdrawingplane.scale.x = ascax
	if ascay > $XCdrawingplane.scale.y:
		$XCdrawingplane.scale.y = ascay
	updateformetresquaresscaletexture()

func expandxcdrawingfitxcdrawing(xcdrawing):
	var scax = 0.0
	var scay = 0.0
	for xcn in xcdrawing.get_node("XCnodes").get_children():
		var nodepointlocal = global_transform.xform_inv(xcn.global_transform.origin)
		scax = max(scax, abs(nodepointlocal.x))
		scay = max(scay, abs(nodepointlocal.y))
	var ascax = scax + 2.0
	var ascay = scay + 2.0
	if ascax > $XCdrawingplane.scale.x:
		$XCdrawingplane.scale.x = ascax
	if ascay > $XCdrawingplane.scale.y:
		$XCdrawingplane.scale.y = ascay
	updateformetresquaresscaletexture()
	
func exportxcrpcdata():
	if drawingtype == DRAWING_TYPE.DT_FLOORTEXTURE:
		return { "name":get_name(), 
				 "xcresource":xcresource,
				 "drawingtype":drawingtype,
				 "transformpos":transform,
				 "nodepoints": nodepoints, 
				 "maxnodepointnumber":maxnodepointnumber,
				 "imgtrim":{ "imgwidth":imgwidth, "imgtrimleftdown":imgtrimleftdown, "imgtrimrightup":imgtrimrightup, "imgheightwidthratio":imgheightwidthratio },
				 "visible":true 
			   }
		
	return { "name":get_name(), 
			 "xcresource":xcresource,
			 "drawingtype":drawingtype,
			 #"prevtransformpos":
			 "transformpos":transform,
			 #"imgtrim":{imgwidth,imgtrimleftdown,imgtrimrightup,(heightwidthratio of xcresource)}
			 #"previmgtrim":{imgwidth,imgtrimleftdown,imgtrimrightup}
			 "nodepoints": nodepoints, 
			 # "prevnodepoints":
			 # "nextnodepoints":
			 "onepathpairs":onepathpairs,
			 # "prevonepathpairs":
			 # "newonepathpairs"
			 "maxnodepointnumber":maxnodepointnumber,
			 "visible":$XCdrawingplane.visible 
		   }
		
func applytrimmedpaperuvscale():
	get_node("XCdrawingplane").transform.origin = Vector3((imgtrimleftdown.x + imgtrimrightup.x)*0.5, (imgtrimleftdown.y + imgtrimrightup.y)*0.5, 0)
	get_node("XCdrawingplane").scale = Vector3((imgtrimrightup.x - imgtrimleftdown.x)*0.5, (imgtrimrightup.y - imgtrimleftdown.y)*0.5, 1)
	var m = get_node("XCdrawingplane/CollisionShape/MeshInstance").get_surface_material(0)
	var imgheight = imgwidth*imgheightwidthratio
	if imgheightwidthratio == 0:
		imgheight = imgwidth
	m.set_shader_param("uv1_scale", Vector3((imgtrimrightup.x - imgtrimleftdown.x)/imgwidth, (imgtrimrightup.y - imgtrimleftdown.y)/imgheight, 1))
	m.set_shader_param("uv1_offset", Vector3((imgtrimleftdown.x - (-imgwidth*0.5))/imgwidth, -(imgtrimrightup.y - (imgheight*0.5))/imgheight, 0))

func mergexcrpcdata(xcdata):
	assert ((get_name() == xcdata["name"]) and (not ("drawingtype" in xcdata) or drawingtype == xcdata["drawingtype"]))
	if "transformpos" in xcdata:
		set_transform(xcdata["transformpos"])

	if "imgtrim" in xcdata:
		var imgtrim = xcdata["imgtrim"]
		imgwidth = imgtrim["imgwidth"]
		imgtrimleftdown = imgtrim["imgtrimleftdown"]
		imgtrimrightup = imgtrim["imgtrimrightup"]
		if imgheightwidthratio == 0 and "imgheightwidthratio" in imgtrim:
			imgheightwidthratio = imgtrim["imgheightwidthratio"]
		applytrimmedpaperuvscale()
		
	if "nodepoints" in xcdata:
		nodepoints = xcdata["nodepoints"]
		for xcn in $XCnodes.get_children():
			if not nodepoints.has(xcn.get_name()):
				xcn.queue_free()
		for k in nodepoints:
			var xcn = $XCnodes.get_node(k) if $XCnodes.has_node(k) else null
			if xcn == null:
				if drawingtype == DRAWING_TYPE.DT_CENTRELINE:
					xcn = XCnode_centreline.instance()
				else:
					xcn = XCnode.instance()
					if k.begins_with("r"):
						var materialsystem = get_node("/root/Spatial/MaterialSystem")
						xcn.get_node("CollisionShape/MeshInstance").set_surface_material(0, materialsystem.nodematerial("normalhole"))
				xcn.set_name(k)
				$XCnodes.add_child(xcn)
			xcn.translation = nodepoints[k]
			
	if "prevnodepoints" in xcdata:
		var nodepointsErase = xcdata["prevnodepoints"]
		var nodepointsAdd = xcdata["nextnodepoints"]
		for nE in nodepointsErase:
			nodepoints.erase(nE)
			if $XCnodes.has_node(nE) and not (nE in nodepointsAdd):
				var xcn = $XCnodes.get_node(nE)
				xcn.queue_free()
				$XCnodes.remove_child(xcn)
		for nA in nodepointsAdd:
			nodepoints[nA] = nodepointsAdd[nA]
			var xcn = $XCnodes.get_node_or_null(nA)
			if xcn == null:
				xcn = XCnode.instance()
				xcn.set_name(nA)
				$XCnodes.add_child(xcn)
			xcn.translation = nodepointsAdd[nA]
			
	if "maxnodepointnumber" in xcdata:
		maxnodepointnumber = xcdata["maxnodepointnumber"]

	if "onepathpairs" in xcdata:
		onepathpairs = xcdata["onepathpairs"]
	
	if "prevonepathpairs" in xcdata:
		var onepathpairsErase = xcdata["prevonepathpairs"]
		var onepathpairsAdd = xcdata["newonepathpairs"]
		for i in range(0, len(onepathpairsErase), 2):
			var j = pairpresentindex(onepathpairsErase[i], onepathpairsErase[i+1])
			if j != -1:
				onepathpairs[j] = onepathpairs[-2]
				onepathpairs[j+1] = onepathpairs[-1]
				onepathpairs.resize(len(onepathpairs) - 2)
		for i in range(0, len(onepathpairsAdd), 2):
			var j = pairpresentindex(onepathpairsAdd[i], onepathpairsAdd[i+1])
			if j == -1:
				onepathpairs.push_back(onepathpairsAdd[i])
				onepathpairs.push_back(onepathpairsAdd[i+1])

	for j in range(len(onepathpairs)-2, -1, -2):
		var p0 = nodepoints.get(onepathpairs[j])
		var p1 = nodepoints.get(onepathpairs[j+1])
		if p0 == null or p1 == null:
			print("Deleting unknown point from onepathpairs ", (onepathpairs[j] if p0 == null else ""), "  ", (onepathpairs[j+1] if p1 == null else ""))
			assert (false)
			onepathpairs[j] = onepathpairs[-2]
			onepathpairs[j+1] = onepathpairs[-1]

	updatexcpaths()
	if "visible" in xcdata:
		if xcdata["visible"]:
			setxcdrawingvisible()
		else:
			setxcdrawingvisiblehide(true)


# "C:\Program Files (x86)\Survex\aven.exe" Ireby\Ireby2\Ireby2.svx
# python surveyscans\convertdmptojson.py (after editing it for the input and output files)
func importcentrelinedata(centrelinedata, sketchsystem):
	$XCdrawingplane.visible = false
	$XCdrawingplane/CollisionShape.disabled = true
	drawingtype = DRAWING_TYPE.DT_CENTRELINE
	#assert (get_name() == "centreline")
	assert ($XCnodes.get_child_count() == 0 and len(nodepoints) == 0 and len(onepathpairs) == 0 and len(xctubesconn) == 0)

	var stationpointscoords = centrelinedata.stationpointscoords
	var stationpointsnames = centrelinedata.stationpointsnames
	var legsconnections = centrelinedata.legsconnections
	var legsstyles = centrelinedata.legsstyles
	
	# find centre (should use an AABB function if exists)
	var bb = [ stationpointscoords[0], stationpointscoords[1], stationpointscoords[2], 
			   stationpointscoords[0], stationpointscoords[1], stationpointscoords[2] ]
	for i in range(len(stationpointsnames)):
		for j in range(3):
			bb[j] = min(bb[j], stationpointscoords[i*3+j])
			bb[j+3] = max(bb[j+3], stationpointscoords[i*3+j])
	print("svx bounding box", bb)		
	$XCdrawingplane.set_scale(Vector3(1,1,1))
	global_transform = Transform()
	var stationpoints = [ ]
	for i in range(len(stationpointsnames)):
		var stationpointname = stationpointsnames[i].replace(".", ",")   # dots not allowed in node name, but commas are
		stationpointsnames[i] = stationpointname
		#nodepoints[k] = Vector3(stationpointscoords[i*3], 8.1+stationpointscoords[i*3+2], -stationpointscoords[i*3+1])
		var stationpoint = Vector3(stationpointscoords[i*3] - (bb[0]+bb[3])/2, 
								   stationpointscoords[i*3+2] - bb[2] + 1, 
								   -(stationpointscoords[i*3+1] - (bb[1]+bb[4])/2))
		stationpoints.append(stationpoint)
		if stationpointname == "":
			continue
		nodepoints[stationpointname] = stationpoint
		var xcn = XCnode_centreline.instance()
		$XCnodes.add_child(xcn)
		xcn.set_name(stationpointname)
		xcn.translation = nodepoints[stationpointname]
		maxnodepointnumber = max(maxnodepointnumber, int(stationpointname))
	for i in range(len(legsstyles)):
		if stationpointsnames[legsconnections[i*2]] == "" or stationpointsnames[legsconnections[i*2+1]] == "":
			continue
		onepathpairs.append(stationpointsnames[legsconnections[i*2]])
		onepathpairs.append(stationpointsnames[legsconnections[i*2+1]])
	updatexcpaths()

	# now make the cross sections
	var xsectgps = centrelinedata.xsectgps
	var hexonepathpairs = [ "hl","hu", "hu","hv", "hv","hr", "hr","he", "he","hd", "hd","hl"]
	for j in range(len(xsectgps)):
		var xsectgp = xsectgps[j]
		var xsectindexes = xsectgp.xsectindexes
		var xsectrightvecs = xsectgp.xsectrightvecs
		var xsectlruds = xsectgp.xsectlruds

		var xcdrawingSect = null
		for i in range(len(xsectindexes)):
			var sname = stationpointsnames[xsectindexes[i]]+"s"+String(j)
			if sketchsystem.get_node("XCdrawings").has_node(sname):
				continue
			var hexnodepoints = { }
			var xl = max(0.1, xsectlruds[i*4+0])
			var xr = max(0.1, xsectlruds[i*4+1])
			var xu = max(0.1, xsectlruds[i*4+2])
			var xd = max(0.1, xsectlruds[i*4+3])
			hexnodepoints["hl"] = Vector3(-xl, 0, 0)
			hexnodepoints["hr"] = Vector3(xr, 0, 0)
			hexnodepoints["hu"] = Vector3(-xl/2, xu, 0)
			hexnodepoints["hv"] = Vector3(+xr/2, xu, 0)
			hexnodepoints["hd"] = Vector3(-xl/2, -xd, 0)
			hexnodepoints["he"] = Vector3(+xr/2, -xd, 0)

			var p = stationpoints[xsectindexes[i]]
			var ang = Vector2(xsectrightvecs[i*2], -xsectrightvecs[i*2+1]).angle()
			var xcdrawingSect1 = sketchsystem.newXCuniquedrawing(DRAWING_TYPE.DT_XCDRAWING, sname)
			assert (xcdrawingSect1.get_name() == sname)
			var xcdata = { "name":xcdrawingSect1.get_name(), "xcresource":"station_"+sname, "drawingtype":DRAWING_TYPE.DT_XCDRAWING, 
						   "transformpos":Transform(Basis().rotated(Vector3(0,-1,0), ang), p), "maxnodepointnumber":0, 
						   "nodepoints":hexnodepoints, "onepathpairs":hexonepathpairs.duplicate(), "visible":false 
						 }
			xcdrawingSect1.mergexcrpcdata(xcdata)
			if xcdrawingSect != null:
				var xctube = sketchsystem.newXCtube(xcdrawingSect, xcdrawingSect1)
				xctube.xcdrawinglink = ["hl", "hl", "hr", "hr"].duplicate()
				xctube.updatetubelinkpaths(sketchsystem)
			xcdrawingSect = xcdrawingSect1
	
func setxcnpoint(xcn, pt, planar):
	xcn.global_transform.origin = pt
	nodepoints[xcn.get_name()] = xcn.translation
	if planar:
		nodepoints[xcn.get_name()].z = 0
		xcn.translation = nodepoints[xcn.get_name()]
		

func pairpresentindex(i0, i1):
	for j in range(0, len(onepathpairs), 2):
		if (onepathpairs[j] == i0 and onepathpairs[j+1] == i1) or (onepathpairs[j] == i1 and onepathpairs[j+1] == i0):
			return j
	return -1

func newuniquexcnodename():
	maxnodepointnumber += 1
	return "p"+String(maxnodepointnumber)

func newxcnode(name=null):
	var xcn = XCnode.instance()
	if name == null:
		maxnodepointnumber += 1
		xcn.set_name("p"+String(maxnodepointnumber))
	else:
		xcn.set_name(name)
		maxnodepointnumber = max(maxnodepointnumber, int(name))
		
	nodepoints[xcn.get_name()] = Vector3()
	assert (not $XCnodes.has_node(xcn.get_name()))
	$XCnodes.add_child(xcn)
	return xcn


func updatexcpaths():
	if drawingtype == DRAWING_TYPE.DT_PAPERTEXTURE:
		return
	if len(onepathpairs) == 0:
		$PathLines.mesh = null
		return
		
	var surfaceTool = SurfaceTool.new()
	surfaceTool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in range(0, len(onepathpairs), 2):
		var p0 = nodepoints[onepathpairs[j]]
		var p1 = nodepoints[onepathpairs[j+1]]
		var perp = Vector3(-(p1.y - p0.y), p1.x - p0.x, 0) if drawingtype != DRAWING_TYPE.DT_CENTRELINE else Vector3(-(p1.z - p0.z), 0, p1.x - p0.x)
		var fperp = linewidth*perp.normalized()
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
	var newmesh = surfaceTool.commit()
	if $PathLines.mesh == null:
		$PathLines.mesh = newmesh
		var materialsystem = get_node("/root/Spatial/MaterialSystem")
		$PathLines.set_surface_material(0, materialsystem.pathlinematerial("centreline" if drawingtype == DRAWING_TYPE.DT_CENTRELINE else "normal"))
	else:
		var m = $PathLines.get_surface_material(0)
		$PathLines.mesh = newmesh
		$PathLines.set_surface_material(0, m)


func makexctubeshell(xcdrawings):
	var polys = Polynets.makexcdpolys(nodepoints, onepathpairs, true)
	if len(polys) == 2:
		return null
	var forepolyindexes = [ ]
	var backpolyindexes = [ ]
	for xctube in xctubesconn:
		if not xctube.positioningtube:
			var polyindex = xctube.pickedpolyindex0 if xctube.xcname0 == get_name() else xctube.pickedpolyindex1
			if polyindex != -1:
				var xcdrawingOther = xcdrawings.get_node(xctube.xcname1 if xctube.xcname0 == get_name() else xctube.xcname0)
				var ftubevec = xcdrawingOther.global_transform.origin - global_transform.origin
				if 	global_transform.basis.z.dot(ftubevec) > 0:
					forepolyindexes.append(polyindex)
				else:
					backpolyindexes.append(polyindex)
	
	var polypartial = null
	if forepolyindexes == [ len(polys)-1 ]:
		polypartial = backpolyindexes
	elif backpolyindexes == [ len(polys)-1 ]:
		polypartial = forepolyindexes
	else:
		return null
	
	var polyindexes = [ ]
	for i in range(len(polys)-1):
		if not polypartial.has(i):
			polyindexes.append(i)
	
	var arraymesh = ArrayMesh.new()
	var surfaceTool = SurfaceTool.new()
	#surfaceTool.set_material(Material.new())
	surfaceTool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in polyindexes:
		var poly = polys[j]
		var pv = PoolVector2Array()
		for i in range(len(poly)):
			var p = poly[i]
			pv.append(Vector2(nodepoints[p].x, nodepoints[p].y))
		var pi = Geometry.triangulate_polygon(pv)
		for u in pi:
			#surfaceTool.add_vertex($XCnodes.get_node(poly[u]).global_transform.origin)
			var uvp = Vector2(nodepoints[poly[u]].x, nodepoints[poly[u]].y)
			surfaceTool.add_uv(uvp)
			surfaceTool.add_uv2(uvp)
			surfaceTool.add_vertex($XCnodes.get_node(poly[u]).transform.origin)
	surfaceTool.generate_normals()
	surfaceTool.commit(arraymesh)
	return arraymesh
	
func updatexctubeshell(xcdrawings, makevisible):
	if makevisible:
		var xctubeshellmesh = makexctubeshell(xcdrawings)
		if xctubeshellmesh != null:
			if not has_node("XCflatshell"):
				var xcflatshell = preload("res://nodescenes/XCtubeshell.tscn").instance()
				xcflatshell.set_name("XCflatshell")
				xcflatshell.get_node("CollisionShape").shape = ConcavePolygonShape.new()
				add_child(xcflatshell)
			$XCflatshell/MeshInstance.mesh = xctubeshellmesh
			$XCflatshell/CollisionShape.shape.set_faces(xctubeshellmesh.get_faces())
			get_node("/root/Spatial/MaterialSystem").updatetubesectormaterial($XCflatshell, xcflatshellmaterial, false)
		else:
			if has_node("XCflatshell"):
				$XCflatshell.queue_free()
	elif has_node("XCflatshell"):
		$XCflatshell.visible = false
		$XCflatshell/CollisionShape.disabled = true
		

func xcdfullsetvisibilitycollision(bvisible):
	visible = bvisible
	if drawingtype == DRAWING_TYPE.DT_CENTRELINE:
		$PathLines.visible = bvisible
		$XCnodes.visible = bvisible
		for xcn in get_node("XCnodes").get_children():
			xcn.get_node("CollisionShape").disabled = not bvisible
	else:
		if visible:
			$XCdrawingplane/CollisionShape.disabled = not $XCdrawingplane.visible
			if has_node("XCflatshell"):
				$XCflatshell/CollisionShape.disabled = not $XCflatshell.visible
		else:
			$XCdrawingplane/CollisionShape.disabled = true
			if has_node("XCflatshell"):
				$XCflatshell/CollisionShape.disabled = true
