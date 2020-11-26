extends Spatial

const XCnode = preload("res://nodescenes/XCnode.tscn")
const XCnode_centreline = preload("res://nodescenes/XCnode_centreline.tscn")

# primary data
var xcresource = ""     # source file
var nodepoints = { }    # { nodename:Vector3 } in local coordinate system
var onepathpairs = [ ]  # [ Anodename0, Anodename1, Bnodename0, Bnodename1, ... ]
var drawingtype = DRAWING_TYPE.DT_XCDRAWING
var xcchangesequence = -1
var xcflatshellmaterial = "simpledirt"

var imgwidth = 0
var imgtrimleftdown = Vector2(0,0)
var imgtrimrightup = Vector2(0,0)

var drawingvisiblecode = DRAWING_TYPE.VIZ_XCD_HIDE

# derived data
var xctubesconn = [ ]   # references to xctubes that connect to here (could use their names instead)
var maxnodepointnumber = 0
var imgheightwidthratio = 0  # known from the xcresource image (though could be cached)

var linewidth = 0.05

func setxcdrawingvisiblehideL(hidenodes):
	assert ($XCdrawingplane.visible != $XCdrawingplane/CollisionShape.disabled)	
	$XCdrawingplane.visible = false
	$XCdrawingplane/CollisionShape.disabled = true
	if hidenodes and drawingtype != DRAWING_TYPE.DT_CENTRELINE:
		var rvisible = (drawingtype != DRAWING_TYPE.DT_XCDRAWING) or (len(xctubesconn) == 0)
		$XCnodes.visible = rvisible
		$PathLines.visible = rvisible
		for xcn in $XCnodes.get_children():
			xcn.get_node("CollisionShape").disabled = not rvisible
	assert ($XCdrawingplane.visible != $XCdrawingplane/CollisionShape.disabled)

func setxcdrawingvisibleL():
	assert ($XCdrawingplane.visible != $XCdrawingplane/CollisionShape.disabled)	
	if not $XCdrawingplane.visible and drawingtype == DRAWING_TYPE.DT_XCDRAWING:
		var scax = 0.0
		var scay = 0.0
		for nodepoint in nodepoints.values():
			scax = max(scax, abs(nodepoint.x))
			scay = max(scay, abs(nodepoint.y))
		$XCdrawingplane.set_scale(Vector3(scax + 2, scay + 2, 1.0))
	if not (drawingtype == DRAWING_TYPE.DT_XCDRAWING and get_name().begins_with("Hole")):
		$XCdrawingplane.visible = true
		$XCdrawingplane/CollisionShape.disabled = false
	$XCnodes.visible = true
	$PathLines.visible = true
	for xcn in $XCnodes.get_children():
		xcn.get_node("CollisionShape").disabled = false
	assert ($XCdrawingplane.visible != $XCdrawingplane/CollisionShape.disabled)

func setdrawingvisiblecode(ldrawingvisiblecode):
	var alreadynoshade = (drawingvisiblecode == DRAWING_TYPE.VIZ_XCD_FLOOR_NOSHADE) or (drawingvisiblecode == DRAWING_TYPE.VIZ_XCD_FLOOR_NOSHADE_ACTIVE)
	drawingvisiblecode = ldrawingvisiblecode
	if drawingtype == DRAWING_TYPE.DT_XCDRAWING:
		if (drawingvisiblecode & DRAWING_TYPE.VIZ_XCD_PLANE_VISIBLE) != 0:
			setxcdrawingvisibleL()
		else:
			setxcdrawingvisiblehideL((drawingvisiblecode & DRAWING_TYPE.VIZ_XCD_NODES_VISIBLE) == 0)
	elif drawingtype == DRAWING_TYPE.DT_CENTRELINE:
		assert (drawingvisiblecode == DRAWING_TYPE.VIZ_XCD_HIDE)
		setxcdrawingvisiblehideL(true)
	elif drawingtype == DRAWING_TYPE.DT_FLOORTEXTURE:
		var planviewsystem = get_node("/root/Spatial/PlanViewSystem")
		var mat = $XCdrawingplane/CollisionShape/MeshInstance.get_surface_material(0)
		var noshade = (drawingvisiblecode == DRAWING_TYPE.VIZ_XCD_FLOOR_NOSHADE) or (drawingvisiblecode == DRAWING_TYPE.VIZ_XCD_FLOOR_NOSHADE_ACTIVE)
		if alreadynoshade != noshade:
			var m = get_node("/root/Spatial/MaterialSystem").get_node("xcdrawingmaterials/floorunshaded" if noshade else "xcdrawingmaterials/floorbordered").get_surface_material(0).duplicate()
			m.set_shader_param("texture_albedo", mat.get_shader_param("texture_albedo"))
			mat = m
			$XCdrawingplane/CollisionShape/MeshInstance.set_surface_material(0, mat)
			applytrimmedpaperuvscale()
	
		if drawingvisiblecode == DRAWING_TYPE.VIZ_XCD_FLOOR_NORMAL or drawingvisiblecode == DRAWING_TYPE.VIZ_XCD_FLOOR_NOSHADE:
			setxcdrawingvisibleL()
			var matc = get_node("/root/Spatial/MaterialSystem").get_node("xcdrawingmaterials/floorunshaded" if noshade else "xcdrawingmaterials/floorbordered").get_surface_material(0)
			mat.set_shader_param("albedo", matc.get_shader_param("albedo"))
			mat.set_shader_param("albedo_border", matc.get_shader_param("albedo_border"))
			if planviewsystem.activetargetfloor == self:
				 planviewsystem.setactivetargetfloor(null)
			$XCdrawingplane.visible = true
			$XCdrawingplane/CollisionShape.disabled = false
		elif drawingvisiblecode == DRAWING_TYPE.VIZ_XCD_FLOOR_ACTIVE or drawingvisiblecode == DRAWING_TYPE.VIZ_XCD_FLOOR_NOSHADE_ACTIVE:
			setxcdrawingvisibleL()
			var matc = get_node("/root/Spatial/MaterialSystem").get_node("xcdrawingmaterials/floorborderedactive").get_surface_material(0)
			mat.set_shader_param("albedo", matc.get_shader_param("albedo"))
			mat.set_shader_param("albedo_border", matc.get_shader_param("albedo_border"))
			planviewsystem.setactivetargetfloor(self)
			$XCdrawingplane.visible = true
			$XCdrawingplane/CollisionShape.disabled = false
		elif drawingvisiblecode == DRAWING_TYPE.VIZ_XCD_FLOOR_HIDDEN or drawingvisiblecode == DRAWING_TYPE.VIZ_XCD_FLOOR_DELETED:
			setxcdrawingvisiblehideL(true)
			if planviewsystem.activetargetfloor == self:
				 planviewsystem.setactivetargetfloor(null)
			$XCdrawingplane.visible = false
			$XCdrawingplane/CollisionShape.disabled = true

		
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
				 "imgtrim":{ "imgwidth":imgwidth, "imgtrimleftdown":imgtrimleftdown, "imgtrimrightup":imgtrimrightup, "imgheightwidthratio":imgheightwidthratio },
				 "visible":true, # to abolish 
				 "drawingvisiblecode":drawingvisiblecode
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
			 "visible":$XCdrawingplane.visible, # to abolish
			 "drawingvisiblecode":drawingvisiblecode
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

	if drawingtype == DRAWING_TYPE.DT_CENTRELINE:
		print("Centreline being now input")

	if "imgtrim" in xcdata:
		var imgtrim = xcdata["imgtrim"]
		imgwidth = imgtrim["imgwidth"]
		imgtrimleftdown = imgtrim["imgtrimleftdown"]
		imgtrimrightup = imgtrim["imgtrimrightup"]
		if imgheightwidthratio == 0 and "imgheightwidthratio" in imgtrim:
			imgheightwidthratio = imgtrim["imgheightwidthratio"]
		applytrimmedpaperuvscale()
		
	if "nodepoints" in xcdata or "prevnodepoints" in xcdata:
		var nodepointsErase = xcdata.get("prevnodepoints")
		var nodepointsAdd = xcdata.get("nextnodepoints")
		if nodepointsErase == null:
			nodepointsErase = [ ]
			nodepointsAdd = xcdata["nodepoints"]
			for xcn in $XCnodes.get_children():
				nodepointsErase.push_back(xcn.get_name())
			
		for nE in nodepointsErase:
			nodepoints.erase(nE)
			if $XCnodes.has_node(nE) and not (nE in nodepointsAdd):
				var xcn = $XCnodes.get_node_or_null(nE)
				if xcn != null:
					xcn.queue_free()
					$XCnodes.remove_child(xcn)
		for nA in nodepointsAdd:
			nodepoints[nA] = nodepointsAdd[nA]
			var xcn = $XCnodes.get_node_or_null(nA)
			if xcn == null:
				if drawingtype != DRAWING_TYPE.DT_CENTRELINE:
					xcn = XCnode.instance()
					if nA.begins_with("r"):
						var materialsystem = get_node("/root/Spatial/MaterialSystem")
						xcn.get_node("CollisionShape/MeshInstance").set_surface_material(0, materialsystem.nodematerial("normalhole"))
					xcn.set_name(nA)
					maxnodepointnumber = max(maxnodepointnumber, int(nA))
					$XCnodes.add_child(xcn)
					xcn.translation = nodepointsAdd[nA]
			else:
				xcn.translation = nodepointsAdd[nA]
		
	if "onepathpairs" in xcdata:   # full overwrite
		onepathpairs = xcdata["onepathpairs"]
		var i = len(onepathpairs) - 2
		while i > 0:
			if onepathpairs[i] == onepathpairs[i+1]:
				print("Deleting loop edge in onepathpairs on input")
				onepathpairs[i] = onepathpairs[-2]
				onepathpairs[i+1] = onepathpairs[-1]
				onepathpairs.resize(len(onepathpairs)-2)
			i -= 2
	
	if "prevonepathpairs" in xcdata:  # diff case 
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
			assert (false)  # assert (fromremotecall)
			onepathpairs[j] = onepathpairs[-2]
			onepathpairs[j+1] = onepathpairs[-1]

	updatexcpaths()
	if "drawingvisiblecode" in xcdata or "visible" in xcdata:
		if not ("drawingvisiblecode" in xcdata):
			if drawingtype == DRAWING_TYPE.DT_XCDRAWING:
				xcdata["drawingvisiblecode"] = DRAWING_TYPE.VIZ_XCD_PLANE_VISIBLE if xcdata["visible"] else DRAWING_TYPE.VIZ_XCD_HIDE
			elif drawingtype == DRAWING_TYPE.DT_FLOORTEXTURE:
				xcdata["drawingvisiblecode"] = DRAWING_TYPE.VIZ_XCD_FLOOR_NORMAL if xcdata["visible"] else DRAWING_TYPE.VIZ_XCD_FLOOR_HIDDEN
			elif drawingtype == DRAWING_TYPE.DT_CENTRELINE:
				xcdata["drawingvisiblecode"] = DRAWING_TYPE.VIZ_XCD_HIDE
		setdrawingvisiblecode(xcdata["drawingvisiblecode"])
	
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
	while true:
		maxnodepointnumber += 1
		var newnodename = "p"+String(maxnodepointnumber)
		if not $XCnodes.has_node(newnodename):
			return newnodename
		
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
	
func updatexctubeshell(xcdrawings):
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
		
func notubeconnections_so_delxcable():
	for xctube in xctubesconn:
		if len(xctube.xcdrawinglink) != 0:
			return false
	return true

