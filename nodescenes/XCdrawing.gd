extends Spatial

const XCnode = preload("res://nodescenes/XCnode.tscn")
const XCnode_knot = preload("res://nodescenes/XCnode_knot.tscn")

# primary data
var xcresource = ""     # source file
var nodepoints = { }    # { nodename:Vector3 } in local coordinate system
var onepathpairs = [ ]  # [ Anodename0, Anodename1, Bnodename0, Bnodename1, ... ]
var drawingtype = DRAWING_TYPE.DT_XCDRAWING
var drawingvisiblecode = DRAWING_TYPE.VIZ_XCD_HIDE
var xcchangesequence = -1
var xcflatshellmaterial = "simpledirt"

var imgwidth = 0
var imgtrimleftdown = Vector2(0,0)
var imgtrimrightup = Vector2(0,0)


# derived data
var xctubesconn = [ ]   # references to xctubes that connect to here (could use their names instead)
var maxnodepointnumber = 0
var imgheightwidthratio = 0  # known from the xcresource image (though could be cached)

var linewidth = 0.05

func DeHoleTubeShell(xcname):
	var sketchsystem = get_node("/root/Spatial/SketchSystem")
	var hxc = xcname.split(";")
	assert (len(hxc) == 3 or len(hxc) == 4)
	assert (hxc[0] == "Hole")
	var i = 0 if len(hxc) == 3 else int(hxc[1])
	var xcname0 = hxc[-2]
	var xcname1 = hxc[-1]
	var xctube = sketchsystem.findxctube(xcname0, xcname1)
	if xctube != null and i < xctube.get_node("XCtubesectors").get_child_count():
		return xctube.get_node("XCtubesectors").get_child(i)
	return null
		
func updatetubeshellsconn():
	var updatetubeshells = [ ]
	for xctube in xctubesconn:
		updatetubeshells.push_back({ "tubename":xctube.get_name(), "xcname0":xctube.xcname0, "xcname1":xctube.xcname1 })
	return updatetubeshells

		
func setxcdrawingvisiblehideL(hidenodes):
	assert ($XCdrawingplane.visible != $XCdrawingplane/CollisionShape.disabled)	
	if drawingtype == DRAWING_TYPE.DT_XCDRAWING and get_name().begins_with("Hole"):
		var xctubesector = DeHoleTubeShell(get_name())
		if xctubesector != null:
			xctubesector.visible = false
			xctubesector.get_node("CollisionShape").disabled = true
		$XCdrawingplane.visible = false
		$XCdrawingplane/CollisionShape.disabled = true
	else:
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
	if drawingtype == DRAWING_TYPE.DT_XCDRAWING and get_name().begins_with("Hole"):
		var xctubesector = DeHoleTubeShell(get_name())
		if xctubesector != null:
			xctubesector.visible = true
			xctubesector.get_node("CollisionShape").disabled = false
	else:
		$XCdrawingplane.visible = true
		$XCdrawingplane/CollisionShape.disabled = false


	$XCnodes.visible = true
	$PathLines.visible = true
	for xcn in $XCnodes.get_children():
		xcn.get_node("CollisionShape").disabled = false
	assert ($XCdrawingplane.visible != $XCdrawingplane/CollisionShape.disabled)

func setdrawingvisiblecode(ldrawingvisiblecode):
	var drawingvisiblecode_old = drawingvisiblecode
	drawingvisiblecode = ldrawingvisiblecode
	if drawingtype == DRAWING_TYPE.DT_XCDRAWING:
		if (drawingvisiblecode & DRAWING_TYPE.VIZ_XCD_PLANE_VISIBLE) != 0:
			setxcdrawingvisibleL()
		else:
			setxcdrawingvisiblehideL((drawingvisiblecode & DRAWING_TYPE.VIZ_XCD_NODES_VISIBLE) == 0)
	elif drawingtype == DRAWING_TYPE.DT_CENTRELINE:
		assert (drawingvisiblecode == DRAWING_TYPE.VIZ_XCD_HIDE)
		setxcdrawingvisiblehideL(true)

	elif drawingtype == DRAWING_TYPE.DT_ROPEHANG:
		var hidenodeshang = ((drawingvisiblecode & DRAWING_TYPE.VIZ_XCD_NODES_VISIBLE) == 0)
		if hidenodeshang:
			var middlenodes = updatehangingropepaths()
			for xcn in $XCnodes.get_children():
				xcn.visible = ((xcn.get_name()[0] == "a") or (middlenodes.find(xcn.get_name()) == -1))
				xcn.get_node("CollisionShape").disabled = not xcn.visible
		else:
			updatelinearropepaths()
			for xcn in $XCnodes.get_children():
				xcn.visible = true
				xcn.get_node("CollisionShape").disabled = not xcn.visible
		
	elif drawingtype == DRAWING_TYPE.DT_FLOORTEXTURE:
		var planviewsystem = get_node("/root/Spatial/PlanViewSystem")
		var mat = $XCdrawingplane/CollisionShape/MeshInstance.get_surface_material(0)
		if (drawingvisiblecode & DRAWING_TYPE.VIZ_XCD_FLOOR_FUNDAMENTALMATERIAL_MASK) != (drawingvisiblecode_old & DRAWING_TYPE.VIZ_XCD_FLOOR_FUNDAMENTALMATERIAL_MASK):
			var fmatname = "xcdrawingmaterials/floorbordered"
			if ((drawingvisiblecode & DRAWING_TYPE.VIZ_XCD_FLOOR_GHOSTLY_B) != 0):
				fmatname = "xcdrawingmaterials/floorborderedghostly"
			elif ((drawingvisiblecode & DRAWING_TYPE.VIZ_XCD_FLOOR_NOSHADE_B) != 0):
				fmatname = "xcdrawingmaterials/floorborderedunshaded"
			var fnewmat = get_node("/root/Spatial/MaterialSystem").get_node(fmatname).get_surface_material(0).duplicate()
			fnewmat.set_shader_param("texture_albedo", mat.get_shader_param("texture_albedo"))
			mat = fnewmat
			$XCdrawingplane/CollisionShape/MeshInstance.set_surface_material(0, mat)
			applytrimmedpaperuvscale()
	
		if (drawingvisiblecode & DRAWING_TYPE.VIZ_XCD_FLOOR_HIDDEN) != 0:
			setxcdrawingvisiblehideL(true)
			if planviewsystem.activetargetfloor == self:
				planviewsystem.activetargetfloor = null
			$XCdrawingplane.visible = false
			$XCdrawingplane/CollisionShape.disabled = true

		elif (drawingvisiblecode & DRAWING_TYPE.VIZ_XCD_FLOOR_NORMAL) != 0:
			setxcdrawingvisibleL()
			var matname
			if (drawingvisiblecode & DRAWING_TYPE.VIZ_XCD_FLOOR_ACTIVE_B) != 0:
				planviewsystem.activetargetfloor = self
				var floorstyleid = 0
				if ((drawingvisiblecode & DRAWING_TYPE.VIZ_XCD_FLOOR_GHOSTLY_B) != 0):
					floorstyleid = 2
				elif ((drawingvisiblecode & DRAWING_TYPE.VIZ_XCD_FLOOR_NOSHADE_B) != 0):
					floorstyleid = 1
				planviewsystem.planviewcontrols.get_node("FloorMove/FloorStyle").selected = floorstyleid
				planviewsystem.planviewcontrols.get_node("FloorMove/LabelXCresource").text = xcresource.replace("%20", " ")
				if (drawingvisiblecode & DRAWING_TYPE.VIZ_XCD_FLOOR_GHOSTLY_B) != 0:
					matname = "xcdrawingmaterials/floorborderedghostlyactive"
				else:
					matname = "xcdrawingmaterials/floorborderedactive"
			else:
				if planviewsystem.activetargetfloor == self:
					planviewsystem.activetargetfloor = null
					planviewsystem.planviewcontrols.get_node("FloorMove/FloorStyle").selected = 0
					planviewsystem.planviewcontrols.get_node("FloorMove/LabelXCresource").text = ""
				if (drawingvisiblecode & DRAWING_TYPE.VIZ_XCD_FLOOR_GHOSTLY_B) != 0:
					matname = "xcdrawingmaterials/floorborderedghostly"
				elif (drawingvisiblecode & DRAWING_TYPE.VIZ_XCD_FLOOR_NOSHADE_B) != 0:
					matname = "xcdrawingmaterials/floorborderedunshaded"
				else:
					matname = "xcdrawingmaterials/floorbordered"
			var matc = get_node("/root/Spatial/MaterialSystem").get_node(matname).get_surface_material(0)
			mat.set_shader_param("albedo", matc.get_shader_param("albedo"))
			mat.set_shader_param("albedo_border", matc.get_shader_param("albedo_border"))
			mat.set_shader_param("uv_borderwidth", matc.get_shader_param("uv_borderwidth"))
			$XCdrawingplane.visible = true
			$XCdrawingplane/CollisionShape.disabled = false
			var cl = CollisionLayer.CL_PointerFloor
			if not ((drawingvisiblecode & DRAWING_TYPE.VIZ_XCD_FLOOR_GHOSTLY_B) != 0):
				cl |= CollisionLayer.CL_Environment
			$XCdrawingplane.collision_layer = cl
			
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
	
func exportxcrpcdata(include_xcchangesequence):
	var d
	if drawingtype == DRAWING_TYPE.DT_FLOORTEXTURE:
		d = { "name":get_name(), 
				 "xcresource":xcresource,
				 "drawingtype":drawingtype,
				 "transformpos":transform,
				 "nodepoints": nodepoints, 
				 "imgtrim":{ "imgwidth":imgwidth, "imgtrimleftdown":imgtrimleftdown, "imgtrimrightup":imgtrimrightup, "imgheightwidthratio":imgheightwidthratio },
				 "visible":true, # to abolish 
				 "drawingvisiblecode":drawingvisiblecode
			   }
		
	else:
		d = { "name":get_name(), 
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
			 #"xcflatshellmaterial"
			 # "prevxcflatshellmaterial"
			 # "nextxcflatshellmaterial"
			 "visible":$XCdrawingplane.visible, # to abolish
			 "drawingvisiblecode":drawingvisiblecode
		   }
		if xcflatshellmaterial != "simpledirt":
			d["xcflatshellmaterial"] = xcflatshellmaterial
			
	if include_xcchangesequence:
		d["xcchangesequence"] = xcchangesequence
	return d
	
func applytrimmedpaperuvscale():
	get_node("XCdrawingplane").transform.origin = Vector3((imgtrimleftdown.x + imgtrimrightup.x)*0.5, (imgtrimleftdown.y + imgtrimrightup.y)*0.5, 0)
	get_node("XCdrawingplane").scale = Vector3((imgtrimrightup.x - imgtrimleftdown.x)*0.5, (imgtrimrightup.y - imgtrimleftdown.y)*0.5, 1)
	var m = get_node("XCdrawingplane/CollisionShape/MeshInstance").get_surface_material(0)
	var imgheight = imgwidth*imgheightwidthratio
	if imgheightwidthratio == 0:
		imgheight = imgwidth
	m.set_shader_param("uv1_scale", Vector3((imgtrimrightup.x - imgtrimleftdown.x)/imgwidth, (imgtrimrightup.y - imgtrimleftdown.y)/imgheight, 1))
	m.set_shader_param("uv1_offset", Vector3((imgtrimleftdown.x - (-imgwidth*0.5))/imgwidth, -(imgtrimrightup.y - (imgheight*0.5))/imgheight, 0))

const knotyscale = 0.5
func mergexcrpcdata(xcdata):
	assert ((get_name() == xcdata["name"]) and (not ("drawingtype" in xcdata) or drawingtype == xcdata["drawingtype"]))
	var updatexcflatshell = false
	if "transformpos" in xcdata:
		set_transform(xcdata["transformpos"])

	if drawingtype == DRAWING_TYPE.DT_CENTRELINE:
		print("Centreline now being merged: ", get_name())

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
				if drawingtype == DRAWING_TYPE.DT_XCDRAWING:
					xcn = XCnode.instance()
					if nA.begins_with("r"):
						var materialsystem = get_node("/root/Spatial/MaterialSystem")
						xcn.get_node("CollisionShape/MeshInstance").set_surface_material(0, materialsystem.nodematerial("normalhole"))
					xcn.set_name(nA)
					maxnodepointnumber = max(maxnodepointnumber, int(nA))
					$XCnodes.add_child(xcn)
					xcn.translation = nodepointsAdd[nA]
					xcn.get_node("CollisionShape/MeshInstance").layers = CollisionLayer.VL_xcdrawingnodes

				elif drawingtype == DRAWING_TYPE.DT_FLOORTEXTURE:
					xcn = XCnode.instance()
					xcn.set_name(nA)
					maxnodepointnumber = max(maxnodepointnumber, int(nA))
					$XCnodes.add_child(xcn)
					xcn.translation = nodepointsAdd[nA]
					xcn.get_node("CollisionShape/MeshInstance").layers = CollisionLayer.VL_xctubeposlines

				elif drawingtype == DRAWING_TYPE.DT_ROPEHANG:
					xcn = XCnode_knot.instance()
					var materialsystem = get_node("/root/Spatial/MaterialSystem")
					xcn.get_node("CollisionShape/MeshInstance").set_surface_material(0, materialsystem.nodematerial("normalknot"))
					if nA[0] == "k":
						xcn.scale.y = knotyscale
					xcn.set_name(nA)
					maxnodepointnumber = max(maxnodepointnumber, int(nA))
					$XCnodes.add_child(xcn)
					xcn.translation = nodepointsAdd[nA]
					xcn.get_node("CollisionShape/MeshInstance").layers = CollisionLayer.VL_xcdrawingnodes

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

	if "xcflatshellmaterial" in xcdata:
		xcflatshellmaterial = xcdata["xcflatshellmaterial"]
	if "prevxcflatshellmaterial" in xcdata:
		xcflatshellmaterial = xcdata["nextxcflatshellmaterial"]
		var xcflatshell = get_node_or_null("XCflatshell")
		if xcflatshell != null:
			var materialsystem = get_node("/root/Spatial/MaterialSystem")
			materialsystem.updatetubesectormaterial(xcflatshell, xcflatshellmaterial, false)

	for j in range(len(onepathpairs)-2, -1, -2):
		var p0 = nodepoints.get(onepathpairs[j])
		var p1 = nodepoints.get(onepathpairs[j+1])
		if p0 == null or p1 == null:
			print("Deleting unknown point from onepathpairs ", (onepathpairs[j] if p0 == null else ""), "  ", (onepathpairs[j+1] if p1 == null else ""))
			assert (false)  # assert (fromremotecall)
			onepathpairs[j] = onepathpairs[-2]
			onepathpairs[j+1] = onepathpairs[-1]

	if "drawingvisiblecode" in xcdata or "visible" in xcdata:
		if not ("drawingvisiblecode" in xcdata):
			if drawingtype == DRAWING_TYPE.DT_XCDRAWING:
				xcdata["drawingvisiblecode"] = DRAWING_TYPE.VIZ_XCD_PLANE_VISIBLE if xcdata["visible"] else DRAWING_TYPE.VIZ_XCD_HIDE
			elif drawingtype == DRAWING_TYPE.DT_FLOORTEXTURE:
				xcdata["drawingvisiblecode"] = DRAWING_TYPE.VIZ_XCD_FLOOR_NORMAL if xcdata["visible"] else DRAWING_TYPE.VIZ_XCD_FLOOR_HIDDEN
			elif drawingtype == DRAWING_TYPE.DT_CENTRELINE:
				xcdata["drawingvisiblecode"] = DRAWING_TYPE.VIZ_XCD_HIDE
		setdrawingvisiblecode(xcdata["drawingvisiblecode"])
	if drawingtype != DRAWING_TYPE.DT_ROPEHANG:
		updatexcpaths()
	
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

func newuniquexcnodename(ch):
	while true:
		maxnodepointnumber += 1
		var newnodename = ch+String(maxnodepointnumber)
		if not $XCnodes.has_node(newnodename):
			return newnodename

const uvfacx = 0.2
const uvfacy = 0.4

func paraba(L, q):
	var qsq = q*q
	var qcu = q*qsq
	var yc = 0.6846094267632553 + q*0.5490693560779955 + qsq*0.10155603064930156 + qcu*(-0.0065641284014727455)
	var yb = 0.32724146179683267 + q*(-0.1282922369501835) + qsq*0.005644904325406289 + qcu*0.0005066041448132827
	var ya = 0.014515220403965912 + q*0.005970564724231822 + qsq*(-0.00083630038220914)
	return (-yb + sqrt(yb*yb - 4*ya*(yc-L)))/(2*ya)

func genrpsquare(p, valong, hv, rad):
	var pv = -hv.cross(valong)
	var ps = p+pv*rad+hv*rad
	return [ ps, p+pv*rad-hv*rad, p-pv*rad-hv*rad, p-pv*rad+hv*rad, ps ]

func ropeseqtubesurface(surfaceTool, rpts, hangperpvec, rad, L):
	var p0 = rpts[0]
	var p1 = rpts[1]
	var v0 = (p1 - p0).normalized()
	var rps0 = genrpsquare(p0, v0, hangperpvec, rad)
	var rtexv = [ 0.0, 0.25, 0.5, 0.75, 1.0 ]
	var p0u = 0.0
	var v1 = v0
	for i in range(1, len(rpts)):
		var p1u = p0u + (p1-p0).length()*uvfacx
		var p2 = null
		var v2 = null
		if i+1 < len(rpts):
			p2 = rpts[i+1]
			v2 = (p2 - p1).normalized()
			v1 = (v0 + v2).normalized()
		var rps1 = genrpsquare(p1, v1, hangperpvec, rad)
		for j in range(len(rtexv)-1):
			surfaceTool.add_uv(Vector2(p0u, rtexv[j]))
			surfaceTool.add_vertex(rps0[j])
			surfaceTool.add_uv(Vector2(p1u, rtexv[j]))
			surfaceTool.add_vertex(rps1[j])
			surfaceTool.add_uv(Vector2(p0u, rtexv[j+1]))
			surfaceTool.add_vertex(rps0[j+1])
			surfaceTool.add_uv(Vector2(p0u, rtexv[j+1]))
			surfaceTool.add_vertex(rps0[j+1])
			surfaceTool.add_uv(Vector2(p1u, rtexv[j]))
			surfaceTool.add_vertex(rps1[j])
			surfaceTool.add_uv(Vector2(p1u, rtexv[j+1]))
			surfaceTool.add_vertex(rps1[j+1])
		
		p0 = p1
		p1 = p2
		rps0 = rps1
		v1 = v2
		p0u = p1u
	print("ropelength L=", L, " curveL=", p0u/uvfacx)

func updatehangingropepaths():
	var middlenodes = [ ]
	if len(onepathpairs) == 0:
		$PathLines.mesh = null
		return middlenodes

	var ropesequences = Polynets.makeropenodesequences(nodepoints, onepathpairs)
	var surfaceTool = SurfaceTool.new()
	surfaceTool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ropeseq in ropesequences:
		var L = 0.0
		for i in range(1, len(ropeseq)):
			L += (nodepoints[ropeseq[i-1]] - nodepoints[ropeseq[i]]).length()
			if i != len(ropeseq)-1:
				middlenodes.push_back(ropeseq[i])
		var rpt0 = nodepoints[ropeseq[0]]
		var rptF = nodepoints[ropeseq[-1]]		
		var vec = rptF - rpt0
		var H = Vector2(vec.x, vec.z).length()
		var rpts = [ ]
		var hangperpvec
		if H < 0.01:
			rpts = [rpt0, rptF]
			hangperpvec = Vector3(1,0,0)
		elif len(ropeseq) == 2:
			rpts = [rpt0, rptF]
			hangperpvec = Vector3(vec.z, 0, -vec.x)/H
		else:
			hangperpvec = Vector3(vec.z, 0, -vec.x)/H
			var q = vec.y/H
			var a = paraba(L/H, q)
			var N = int(max(L/0.1, 4))
			rpts = [ ]
			for i in range(N+1):
				var x = i*1.0/N
				var y = x*x*a + x*(q-a)
				rpts.push_back(Vector3(rpt0.x + x*vec.x, rpt0.y + y*H, rpt0.z + x*vec.z))
		ropeseqtubesurface(surfaceTool, rpts, hangperpvec, linewidth/2, L)
	surfaceTool.generate_normals()
	var newmesh = surfaceTool.commit()
	$PathLines.mesh = newmesh
	var materialsystem = get_node("/root/Spatial/MaterialSystem")
	$PathLines.set_surface_material(0, materialsystem.pathlinematerial("rope"))
	return middlenodes

func updatelinearropepaths():
	var middlenodes = [ ]
	if len(onepathpairs) == 0:
		$PathLines.mesh = null
		return middlenodes
	var ropesequences = Polynets.makeropenodesequences(nodepoints, onepathpairs)
	var surfaceTool = SurfaceTool.new()
	surfaceTool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ropeseq in ropesequences:
		var p0 = nodepoints[ropeseq[0]]
		var p1 = nodepoints[ropeseq[1]]
		var perp0 = Vector3(-(p1.y - p0.y), p1.x - p0.x, 0).normalized()
		var fperp0 = linewidth*perp0
		var p0left = p0 - fperp0
		var p0right = p0 + fperp0
		var p0u = 0.0
		var perp1 = perp0
		for i in range(1, len(ropeseq)):
			var p1u = p0u + (p1-p0).length()
			var p2 = null
			var perp2 = null
			if i+1 < len(ropeseq):
				middlenodes.push_back(ropeseq[i])
				p2 = nodepoints[ropeseq[i+1]]
				perp2 = Vector3(-(p2.y - p1.y), p2.x - p1.x, 0).normalized()
				perp1 = (perp0+perp2).normalized()
			var fperp1 = linewidth*perp1
			var p1left = p1 - fperp1
			var p1right = p1 + fperp1
			surfaceTool.add_uv(Vector2(p0u*uvfacx, 0.0))
			surfaceTool.add_vertex(p0left)
			surfaceTool.add_uv(Vector2(p1u*uvfacx, 0.0))
			surfaceTool.add_vertex(p1left)
			surfaceTool.add_uv(Vector2(p0u*uvfacx, uvfacy))
			surfaceTool.add_vertex(p0right)
			surfaceTool.add_uv(Vector2(p0u*uvfacx, uvfacy))
			surfaceTool.add_vertex(p0right)
			surfaceTool.add_uv(Vector2(p1u*uvfacx, 0.0))
			surfaceTool.add_vertex(p1left)
			surfaceTool.add_uv(Vector2(p1u*uvfacx, uvfacy))
			surfaceTool.add_vertex(p1right)
			
			p0 = p1
			p1 = p2
			p0left = p1left
			p0right = p1right
			perp1 = perp2
			p0u = p1u

	surfaceTool.generate_normals()
	var newmesh = surfaceTool.commit()
	$PathLines.mesh = newmesh
	var materialsystem = get_node("/root/Spatial/MaterialSystem")
	$PathLines.set_surface_material(0, materialsystem.pathlinematerial("rope"))
	return middlenodes

		
func updatexcpaths():
	if len(onepathpairs) == 0:
		return
	var surfaceTool = SurfaceTool.new()
	surfaceTool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in range(0, len(onepathpairs), 2):
		var p0 = nodepoints[onepathpairs[j]]
		var p1 = nodepoints[onepathpairs[j+1]]
		var perp
		if drawingtype != DRAWING_TYPE.DT_CENTRELINE:
			perp = Vector3(-(p1.y - p0.y), p1.x - p0.x, 0)
		else:
			perp = Vector3(-(p1.z - p0.z), 0, p1.x - p0.x)
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
	if $PathLines.mesh == null or $PathLines.get_surface_material_count() == 0:
		$PathLines.mesh = newmesh
		assert($PathLines.get_surface_material_count() != 0)
		var materialsystem = get_node("/root/Spatial/MaterialSystem")
		var matname = "centreline" if drawingtype == DRAWING_TYPE.DT_CENTRELINE else "normal"
		$PathLines.set_surface_material(0, materialsystem.pathlinematerial(matname))
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

