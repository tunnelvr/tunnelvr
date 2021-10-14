extends Spatial

const XCnode = preload("res://nodescenes/XCnode.tscn")
const XCnode_knot = preload("res://nodescenes/XCnode_knot.tscn")

# primary data
var xcresource = ""     # source file
var nodepoints = { }    # { nodename:Vector3 } in local coordinate system
var onepathpairs = [ ]  # [ Anodename0, Anodename1, Bnodename0, Bnodename1, ... ]
var drawingtype = DRAWING_TYPE.DT_XCDRAWING # DT_CENTRELINE, DT_ROPEHANG
var drawingvisiblecode = DRAWING_TYPE.VIZ_XCD_HIDE
var ropehangdetectedtype = DRAWING_TYPE.RH_NORMAL

var xcchangesequence = -1
var xcflatshellmaterial = "simpledirt"

var imgwidth = 0
var imgtrimleftdown = Vector2(0,0)
var imgtrimrightup = Vector2(0,0)
var additionalproperties = null  # { stationnamecommonroot:, flagsignlabels: { nodename:label } }

# derived data
var xctubesconn = [ ]   # references to xctubes that connect to here (could use their names instead)
var maxnodepointnumber = 0
var nodepointmean = Vector3(0,0,0)
var nodepointylo = 0.0
var nodepointyhi = 0.0
var imgheightwidthratio = 0  # known from the xcresource image (though could be cached)

var shortestpathseglength = 0.0
var closewidthsca = 1.0
var linewidth = 0.05

static func tubesectorfromxchole(xcname, sketchsystem):
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

func measurexcmatch(ltransformpos, lnextnodepoints):
	var dist = 0.0
	for k in lnextnodepoints.keys():
		var pt = ltransformpos.xform(lnextnodepoints[k])
		var npt = nodepoints.get(k)
		if npt != null:
			dist += pt.distance_to(transform.xform(npt))
		else:
			dist += 1.0
		dist += max(0, len(nodepoints) - len(lnextnodepoints))
	return dist
		
func setxcdrawingvisiblehideL(hidenodes):
	assert ($XCdrawingplane/CollisionShape.disabled == (not $XCdrawingplane.visible))
	if drawingtype == DRAWING_TYPE.DT_XCDRAWING and get_name().begins_with("Hole;"):
		var xctubesector = tubesectorfromxchole(get_name(), get_node("/root/Spatial/SketchSystem"))
		if xctubesector != null:
			xctubesector.visible = (not hidenodes) or (len(nodepoints) == 0)
			xctubesector.get_node("CollisionShape").disabled = not xctubesector.visible
		$XCdrawingplane.visible = false
		$XCdrawingplane/CollisionShape.disabled = true
	else:
		$XCdrawingplane.visible = false
		$XCdrawingplane/CollisionShape.disabled = true
	var rnodesvisible = (not hidenodes) or (drawingtype != DRAWING_TYPE.DT_XCDRAWING) or (len(xctubesconn) == 0)
	$XCnodes.visible = rnodesvisible
	$PathLines.visible = rnodesvisible
	for xcn in $XCnodes.get_children():
		xcn.get_node("CollisionShape").disabled = not rnodesvisible
	assert ($XCdrawingplane.visible != $XCdrawingplane/CollisionShape.disabled)

func setxcdrawingvisibleL():
	assert ($XCdrawingplane.visible != $XCdrawingplane/CollisionShape.disabled)	
	if not $XCdrawingplane.visible and drawingtype == DRAWING_TYPE.DT_XCDRAWING:
		setxcdrawingwidthfromnodes()
	if drawingtype == DRAWING_TYPE.DT_XCDRAWING and get_name().begins_with("Hole;"):
		var xctubesector = tubesectorfromxchole(get_name(), get_node("/root/Spatial/SketchSystem"))
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


func xcconnectstoshell():
	for xctubeconn in xctubesconn:
		if xctubeconn.get_node("XCtubesectors").get_child_count() != 0:
			return true
	return false

func makeflaglabels(ptsignroot, ptsigntopy, postrad, flagsigns):
	var labelgenerator = get_node("/root/Spatial/LabelGenerator")
	var ptsigntop = Vector3(ptsignroot.x, ptsigntopy, ptsignroot.z)
	for xcn in get_node("XCnodes").get_children():
		if xcn.has_node("FlagLabel"):
			xcn.get_node("FlagLabel").visible = false
	for i in range(len(flagsigns)):
		var flagmsg = flagsigns[i][0]
		var nodefurthest = flagsigns[i][1]
		var vecletters = flagsigns[i][2]
		var veclettersup = flagsigns[i][3]
		var xcn = get_node("XCnodes").get_node(nodefurthest)
		var flaglabel = xcn.get_node_or_null("FlagLabel")
		if flaglabel == null:
			var materialsystem = get_node("/root/Spatial/MaterialSystem")
			var flaglabelmaterialnode = materialsystem.get_node("labelmaterials/FlagLabel")
			flaglabel = flaglabelmaterialnode.duplicate()
			var mat = flaglabel.get_surface_material(0).duplicate()
			flaglabel.mesh = flaglabel.mesh.duplicate()
			flaglabel.set_surface_material(0, mat)
			xcn.add_child(flaglabel)
		flaglabel.visible = true
		var flagbasis = Basis(vecletters, veclettersup, vecletters.cross(veclettersup))
		flaglabel.global_transform = Transform(flagbasis, ptsigntop + flagbasis.x*(0*flaglabel.mesh.size.x/2))
		flaglabel.scale.y = (1 if ptsigntopy > ptsignroot.y else -1)
		print("fff ", flaglabel.global_transform, flagmsg)
		var cflagmsg = "[color=#00FFFF]"+flagmsg+"[/color]"
		labelgenerator.remainingropelabels.push_back([get_name(), xcn.get_name(), cflagmsg])
		labelgenerator.restartlabelmakingprocess(null)


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
		var hidenodeshang = ((drawingvisiblecode & DRAWING_TYPE.VIZ_XCD_NODES_VISIBLE) == 0) and (len(onepathpairs) != 0)
		if hidenodeshang:
			var ropeseqs = Polynets.makeropenodesequences(nodepoints, onepathpairs, $RopeHang.oddropeverts)
			var cuboidfacs = Polynets.cuboidfromropenodesequences(nodepoints, ropeseqs)
			var stalseqax = Polynets.stalfromropenodesequences(nodepoints, ropeseqs) if cuboidfacs == null else null
			var signseqax = Polynets.signpostfromropenodesequences(nodepoints, ropeseqs, (additionalproperties if additionalproperties != null else {}).get("flagsignlabels", {})) if (cuboidfacs == null and stalseqax == null) else null
			if cuboidfacs != null:
				print("cuboidfacs ", cuboidfacs)
				var cuboidshellmesh = Polynets.makecuboidshellmesh(nodepoints, cuboidfacs[0])
				var cuboidshellmesh1 = Polynets.makerailcuboidshellmesh(nodepoints, cuboidfacs[1])
				updatexcshellmesh(cuboidshellmesh1)
				$RopeHang.visible = false
				$PathLines.visible = false
				for xcn in $XCnodes.get_children():
					xcn.visible = (xcn.get_name()[0] == "a")
					xcn.get_node("CollisionShape").disabled = not xcn.visible
				ropehangdetectedtype = DRAWING_TYPE.RH_BOULDER
									#
			elif stalseqax != null:
				var stalshellmesh = Polynets.makestalshellmesh(stalseqax[0], stalseqax[1], stalseqax[2])
				updatexcshellmesh(stalshellmesh)
				$RopeHang.visible = false
				$PathLines.visible = false
				for xcn in $XCnodes.get_children():
					xcn.visible = (stalseqax[3].find(xcn.get_name()) != -1)
					xcn.get_node("CollisionShape").disabled = not xcn.visible
				ropehangdetectedtype = DRAWING_TYPE.RH_STAL

			elif signseqax != null:
				print("signseqax ", signseqax)
				var signshellmesh = Polynets.makesignpostshellmesh(self, signseqax[0], signseqax[1], 0.041)
				updatexcshellmesh(signshellmesh)
				makeflaglabels(signseqax[0], signseqax[1], 0.041, signseqax[2])
				$RopeHang.visible = false
				$PathLines.visible = false
				for xcn in $XCnodes.get_children():
					xcn.visible = (signseqax[3].find(xcn.get_name()) != -1)
					xcn.get_node("CollisionShape").disabled = not xcn.visible
				ropehangdetectedtype = DRAWING_TYPE.RH_FLAGSIGN

			elif len($RopeHang.oddropeverts) <= 2:
				var middlenodes = $RopeHang.updatehangingropepathsArrayMesh_Verlet(nodepoints, ropeseqs)
				for xcn in $XCnodes.get_children():
					xcn.visible = ((xcn.get_name()[0] == "a") or (middlenodes.find(xcn.get_name()) == -1))
					xcn.get_node("CollisionShape").disabled = not xcn.visible
					if xcn.has_node("RopeLabel"):
						xcn.get_node("RopeLabel").visible = false
				$RopeHang.visible = true
				$PathLines.visible = false
				get_node("/root/Spatial/VerletRopeSystem").addropehang($RopeHang)
				ropehangdetectedtype = DRAWING_TYPE.RH_NORMAL

			else:
				print("Not an identified rope shape type, unhiding nodeshang")
				hidenodeshang = false
				ropehangdetectedtype = DRAWING_TYPE.RH_NORMAL

		if not hidenodeshang:
			for xcn in $XCnodes.get_children():
				xcn.transform.origin = nodepoints[xcn.get_name()]
			updatelinearropepaths()
			var xcflatshell = get_node_or_null("XCflatshell")
			if xcflatshell != null:
				xcflatshell.visible = false
				xcflatshell.get_node("CollisionShape").disabled = true
				
			for xcn in $XCnodes.get_children():
				xcn.visible = true
				xcn.get_node("CollisionShape").disabled = not xcn.visible
				if xcn.has_node("RopeLabel"):
					xcn.get_node("RopeLabel").visible = false
			$RopeHang.visible = false
			$PathLines.visible = true
		$XCdrawingplane.visible = false
		$XCdrawingplane/CollisionShape.disabled = true

		
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
				planviewsystem.planviewcontrols.get_node("ColorRectURL").visible = false
				planviewsystem.planviewcontrols.get_node("ColorRectURL/LabelXCresource").text = ""
			$XCdrawingplane.visible = false
			$XCdrawingplane/CollisionShape.disabled = true

		elif (drawingvisiblecode & DRAWING_TYPE.VIZ_XCD_FLOOR_NORMAL) != 0:
			setxcdrawingvisibleL()
			if (drawingvisiblecode_old & DRAWING_TYPE.VIZ_XCD_FLOOR_HIDDEN) != 0:
				get_node("/root/Spatial/ImageSystem").fetchpaperdrawing(self)
			var matname
			if (drawingvisiblecode & DRAWING_TYPE.VIZ_XCD_FLOOR_ACTIVE_B) != 0:
				planviewsystem.activetargetfloor = self
				var floorstyleid = DRAWING_TYPE.FS_NORMAL
				if ((drawingvisiblecode & DRAWING_TYPE.VIZ_XCD_FLOOR_GHOSTLY_B) != 0):
					if ((drawingvisiblecode & DRAWING_TYPE.VIZ_XCD_FLOOR_NOSHADE_B) != 0):
						floorstyleid = DRAWING_TYPE.FS_PHOTO
					else:
						floorstyleid = DRAWING_TYPE.FS_GHOSTLY
				elif ((drawingvisiblecode & DRAWING_TYPE.VIZ_XCD_FLOOR_NOSHADE_B) != 0):
					#floorstyleid = DRAWING_TYPE.FS_UNSHADED
					floorstyleid = DRAWING_TYPE.FS_GHOSTLY
					
				planviewsystem.planviewcontrols.get_node("FloorMove/FloorStyle").selected = floorstyleid
				planviewsystem.planviewcontrols.get_node("ColorRectURL/LabelXCresource").text = xcresource.replace("%20", " ")
				planviewsystem.planviewcontrols.get_node("ColorRectURL").visible = true
				if (drawingvisiblecode & DRAWING_TYPE.VIZ_XCD_FLOOR_NOSHADE_B) != 0:
					matname = "xcdrawingmaterials/floorborderedactive"
				elif (drawingvisiblecode & DRAWING_TYPE.VIZ_XCD_FLOOR_GHOSTLY_B) != 0:
					matname = "xcdrawingmaterials/floorborderedghostlyactive"
				else:
					matname = "xcdrawingmaterials/floorborderedactive"
			else:
				if planviewsystem.activetargetfloor == self:
					planviewsystem.activetargetfloor = null
					planviewsystem.planviewcontrols.get_node("ColorRectURL").visible = false
					planviewsystem.planviewcontrols.get_node("ColorRectURL/LabelXCresource").text = ""
				if (drawingvisiblecode & DRAWING_TYPE.VIZ_XCD_FLOOR_NOSHADE_B) != 0:
					matname = "xcdrawingmaterials/floorborderedunshaded"
				elif (drawingvisiblecode & DRAWING_TYPE.VIZ_XCD_FLOOR_GHOSTLY_B) != 0:
					matname = "xcdrawingmaterials/floorborderedghostly"
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
		var FloorStyle = planviewsystem.planviewcontrols.get_node("FloorMove/FloorStyle")
		FloorStyle.disabled = (planviewsystem.activetargetfloor == null)
		if FloorStyle.disabled:
			FloorStyle.selected = 0
		else:
			FloorStyle.set_item_disabled(4, not notubeconnections_so_delxcable())

			
func updateformetresquaresscaletexture():
	var mat = $XCdrawingplane/CollisionShape/MeshInstance.get_surface_material(0)
	if mat != null:
		mat.uv1_scale = $XCdrawingplane.get_scale()
		mat.uv1_offset = -$XCdrawingplane.get_scale()/2

func expandxcdrawingscale(nodepointglobal):
	assert (drawingtype == DRAWING_TYPE.DT_XCDRAWING)
	var nodepointlocal = global_transform.xform_inv(nodepointglobal)
	var ascax = abs(nodepointlocal.x) + 2
	var ascay = abs(nodepointlocal.y) + 2
	if ascax > $XCdrawingplane.scale.x:
		$XCdrawingplane.scale.x = ascax
	if ascay > $XCdrawingplane.scale.y:
		$XCdrawingplane.scale.y = ascay
	updateformetresquaresscaletexture()

func setxcdrawingwidthfromnodes():
	var scax = 0.0
	var scay = 0.0
	for nodepoint in nodepoints.values():
		scax = max(scax, abs(nodepoint.x))
		scay = max(scay, abs(nodepoint.y))
	$XCdrawingplane.set_scale(Vector3(scax + 2, scay + 2, 1.0))

func expandxcdrawingfitprojectedfromxcdrawingnodes(xcdrawing):
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
	
func exportxcrpcdata(stripruntimedataforsaving):
	var d
	if drawingtype == DRAWING_TYPE.DT_FLOORTEXTURE:
		d = { "name":get_name(), 
			  "xcresource":xcresource,
			  "drawingtype":drawingtype,
			  "transformpos":transform,
			  "nodepoints": nodepoints, 
			  "imgtrim":{ "imgwidth":imgwidth, "imgtrimleftdown":imgtrimleftdown, "imgtrimrightup":imgtrimrightup, "imgheightwidthratio":imgheightwidthratio },
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
			  "drawingvisiblecode":drawingvisiblecode
			}
		if xcflatshellmaterial != "simpledirt":
			d["xcflatshellmaterial"] = xcflatshellmaterial
		if additionalproperties != null:
			d["additionalproperties"] = additionalproperties
			
	if not stripruntimedataforsaving:
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
					xcn.get_node("CollisionShape").scale = Vector3(closewidthsca, closewidthsca, closewidthsca)
					$XCnodes.add_child(xcn)
					xcn.translation = nodepointsAdd[nA]
					xcn.get_node("CollisionShape/MeshInstance").layers = CollisionLayer.VL_xcdrawingnodes

				elif drawingtype == DRAWING_TYPE.DT_FLOORTEXTURE:
					xcn = XCnode.instance()
					xcn.set_name(nA)
					maxnodepointnumber = max(maxnodepointnumber, int(nA))
					xcn.scale = Vector3(closewidthsca, closewidthsca, closewidthsca)
					var materialsystem = get_node("/root/Spatial/MaterialSystem")
					xcn.get_node("CollisionShape/MeshInstance").set_surface_material(0, materialsystem.nodematerial("normalfloorpos"))
					$XCnodes.add_child(xcn)
					xcn.translation = nodepointsAdd[nA]
					xcn.get_node("CollisionShape/MeshInstance").layers = CollisionLayer.VL_xctubeposlines
					xcn.collision_layer = CollisionLayer.CL_CentrelineStation
					
				elif drawingtype == DRAWING_TYPE.DT_ROPEHANG:
					xcn = XCnode_knot.instance()
					var materialsystem = get_node("/root/Spatial/MaterialSystem")
					var mat = null
					if nA[0] == "k":
						xcn.get_node("CollisionShape").scale = Vector3(closewidthsca, closewidthsca*knotyscale, closewidthsca)
						mat = materialsystem.nodematerial("normalknot")
					else:
						xcn.get_node("CollisionShape").scale = Vector3(closewidthsca, closewidthsca, closewidthsca)
						mat = materialsystem.nodematerial("normalknotwall")
					xcn.get_node("CollisionShape/MeshInstance").set_surface_material(0, mat)
					xcn.set_name(nA)
					maxnodepointnumber = max(maxnodepointnumber, int(nA))
					$XCnodes.add_child(xcn)
					xcn.translation = nodepointsAdd[nA]
					xcn.get_node("CollisionShape/MeshInstance").layers = CollisionLayer.VL_xcdrawingnodes

			else:
				xcn.translation = nodepointsAdd[nA]

		var nodepointsum = Vector3(0,0,0)
		nodepointylo = 0.0
		nodepointyhi = 0.0
		var firstnodepoint = true
		for p in nodepoints.values():
			nodepointsum += p
			if p.y < nodepointylo or firstnodepoint:
				nodepointylo = p.y
			if p.y > nodepointyhi or firstnodepoint:
				nodepointyhi = p.y
				firstnodepoint = false
		nodepointmean = nodepointsum/max(1, len(nodepoints))

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
			var j = pairpresentindex(onepathpairsAdd[i], onepathpairsAdd[i+1]) if drawingtype != DRAWING_TYPE.DT_CENTRELINE else -1
			if j == -1:
				onepathpairs.push_back(onepathpairsAdd[i])
				onepathpairs.push_back(onepathpairsAdd[i+1])

	if "xcflatshellmaterial" in xcdata:
		xcflatshellmaterial = xcdata["xcflatshellmaterial"]
	if "prevxcflatshellmaterial" in xcdata:
		xcflatshellmaterial = xcdata["nextxcflatshellmaterial"]
		if has_node("XCflatshell"):
			var materialsystem = get_node("/root/Spatial/MaterialSystem")
			materialsystem.updateflatshellmaterial(self, xcflatshellmaterial, false)

	if "nodepoints" in xcdata or "prevnodepoints" in xcdata or "onepathpairs" in xcdata or "prevonepathpairs" in xcdata:
		var shortestpathseglengthsq = -1.0
		for j in range(0, len(onepathpairs), 2):
			var p0 = nodepoints.get(onepathpairs[j])
			var p1 = nodepoints.get(onepathpairs[j+1])
			if p0 == null or p1 == null:
				print("***  Deleting unknown point from onepathpairs ", (onepathpairs[j] if p0 == null else ""), "  ", (onepathpairs[j+1] if p1 == null else ""))
				#assert (false)  # assert (fromremotecall)
				onepathpairs[j] = onepathpairs[-2]
				onepathpairs[j+1] = onepathpairs[-1]
			else:
				var vlensq = p0.distance_squared_to(p1)
				if shortestpathseglengthsq == -1.0 or vlensq < shortestpathseglengthsq:
					shortestpathseglengthsq = vlensq
		shortestpathseglength = sqrt(max(0, shortestpathseglengthsq))

	if "additionalproperties" in xcdata:
		additionalproperties = xcdata["additionalproperties"]
	if "drawingvisiblecode" in xcdata:
		setdrawingvisiblecode(xcdata["drawingvisiblecode"])
		
	if drawingtype == DRAWING_TYPE.DT_CENTRELINE:
		if xcdata.get("partialxcchunk", "no") != "yes":
			updatexcpaths_centreline($PathLines, linewidth)
			var labelgenerator = get_node("/root/Spatial/LabelGenerator")
			labelgenerator.addnodestolabeltask(self)
			var playermeheadcam = get_node("/root/Spatial").playerMe.get_node("HeadCam")
			labelgenerator.restartlabelmakingprocess(playermeheadcam.global_transform.origin)
		
	elif drawingtype != DRAWING_TYPE.DT_ROPEHANG:
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

func ropepathseqribbons(surfaceTool):
	var middlenodes = [ ]
	var ropesequences = Polynets.makeropenodesequences(nodepoints, onepathpairs, null)
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
	return middlenodes
	
func ropepointreprojectXYZ(uv, sketchsystem):  #  opposite of ropepointtargetUV
	var usecl = uv.x*Tglobal.wingmeshuvudivisions
	var usec = int(clamp(floor(usecl), 0, Tglobal.wingmeshuvudivisions-1))
	var ropepointlamda = usecl - usec
	var aroundsegmentl = uv.y*Tglobal.wingmeshuvvdivisions
	var aroundsegment = int(clamp(floor(aroundsegmentl), 0, Tglobal.wingmeshuvvdivisions-1))
	var lambdaCalong = aroundsegmentl - aroundsegment
	var xctube = sketchsystem.get_node("XCtubes").get_node_or_null("XCtube_ws%d_ws%d" % [usec, usec+1])
	if xctube == null:
		return null
	var xcdrawing0 = sketchsystem.get_node("XCdrawings").get_node(xctube.xcname0)
	var xcdrawing1 = sketchsystem.get_node("XCdrawings").get_node(xctube.xcname1)
	var xcdrawing0nodes = xcdrawing0.get_node("XCnodes")
	var xcdrawing1nodes = xcdrawing1.get_node("XCnodes")

	var jA = aroundsegment*2
	var p0 = xcdrawing0nodes.get_node(xctube.xcdrawinglink[jA]).global_transform.origin
	var p1 = xcdrawing1nodes.get_node(xctube.xcdrawinglink[jA+1]).global_transform.origin
	var pc = lerp(p0, p1, ropepointlamda)
	
	var jB = (jA + 2) % len(xctube.xcdrawinglink)
	var p0B = xcdrawing0nodes.get_node(xctube.xcdrawinglink[jB]).global_transform.origin
	var p1B = xcdrawing1nodes.get_node(xctube.xcdrawinglink[jB+1]).global_transform.origin
	var pcB = lerp(p0B, p1B, ropepointlamda)

	return lerp(pc, pcB, lambdaCalong)

func updatelinearropepaths():
	var middlenodes = [ ]
	if len(onepathpairs) == 0:
		$PathLines.mesh = null
		return middlenodes
	var countanchors = 0
	for nname in nodepoints:
		if nname[0] == "a":
			countanchors += 1
	resetclosewidthsca(1.0 if countanchors < 5 else 0.5)
	var surfaceTool = SurfaceTool.new()
	surfaceTool.begin(Mesh.PRIMITIVE_TRIANGLES)
	middlenodes = ropepathseqribbons(surfaceTool)

	surfaceTool.generate_normals()
	var newmesh = surfaceTool.commit()
	$PathLines.mesh = newmesh
	$PathLines.set_surface_material(0, get_node("RopeHang").ropematerialcolor)
	return middlenodes

func resetclosewidthsca(lclosewidthsca):
	if shortestpathseglength != 0.0 and shortestpathseglength < linewidth*3*lclosewidthsca:
		lclosewidthsca *= 0.5
		if shortestpathseglength < linewidth*3*lclosewidthsca:
			lclosewidthsca *= 0.5
	if closewidthsca != lclosewidthsca:
		closewidthsca = lclosewidthsca
		for xcn in $XCnodes.get_children():
			var kscale = 0.5 if xcn.get_name()[0] == "a" else 1.0
			xcn.get_node("CollisionShape").scale = Vector3(closewidthsca, closewidthsca*kscale, closewidthsca)


func updatexcpaths():
	var pathlines = $PathLines
	if len(onepathpairs) == 0:
		pathlines.mesh = null
		return
	resetclosewidthsca(1.0)
	var llinewidth = linewidth*closewidthsca
	
	var surfaceTool = SurfaceTool.new()
	surfaceTool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in range(0, len(onepathpairs), 2):
		var p0 = nodepoints[onepathpairs[j]]
		var p1 = nodepoints[onepathpairs[j+1]]
		var perp = Vector3(-(p1.y - p0.y), p1.x - p0.x, 0)
		var fperp = llinewidth*perp.normalized()
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
	for npname in nodepoints:
		var np = nodepoints[npname]
		if np.z != 0:
			var p0up = Vector3(np.x, np.y + llinewidth, 0)
			var p0down = Vector3(np.x, np.y - llinewidth*0.1, 0)
			var p1up = Vector3(np.x, np.y + llinewidth, np.z)
			var p1down = Vector3(np.x, np.y - llinewidth*0.1, np.z)
			surfaceTool.add_vertex(p0up)
			surfaceTool.add_vertex(p1up)
			surfaceTool.add_vertex(p0down)
			surfaceTool.add_vertex(p0down)
			surfaceTool.add_vertex(p1up)
			surfaceTool.add_vertex(p1down)
			
	surfaceTool.generate_normals()
	var newmesh = surfaceTool.commit()
	if pathlines.mesh == null or pathlines.get_surface_material_count() == 0:
		pathlines.mesh = newmesh
		assert(pathlines.get_surface_material_count() != 0)
		var materialsystem = get_node("/root/Spatial/MaterialSystem")
		pathlines.set_surface_material(0, materialsystem.pathlinematerial("normal"))
	else:
		var m = pathlines.get_surface_material(0)
		pathlines.mesh = newmesh
		pathlines.set_surface_material(0, m)


func updatexcpaths_centreline(pathlines, mlinewidth):
	if len(onepathpairs) == 0:
		pathlines.mesh = null
		return
	var surfaceTool = SurfaceTool.new()
	surfaceTool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in range(0, len(onepathpairs), 2):
		var s0 = onepathpairs[j]
		var s1 = onepathpairs[j+1]
		var issplaysegline = Tglobal.splaystationnoderegex != null and (Tglobal.splaystationnoderegex.search(s0) or Tglobal.splaystationnoderegex.search(s1))
		var llinewidth = mlinewidth*0.5 if issplaysegline else mlinewidth
		var p0 = nodepoints[s0]
		var p1 = nodepoints[s1]
		var q0 = inverse_lerp(nodepointylo, nodepointyhi, p0.y)
		var q1 = inverse_lerp(nodepointylo, nodepointyhi, p1.y)
		var perp = Vector3(-(p1.z - p0.z), 0, p1.x - p0.x)
		if perp == Vector3(0,0,0):
			perp = Vector3(1,0,0)
		var fperp = llinewidth*perp.normalized()
		var p0left = p0 - fperp
		var p0right = p0 + fperp
		var p1left = p1 - fperp
		var p1right = p1 + fperp
		surfaceTool.add_uv(Vector2(q0, 0.0))
		surfaceTool.add_vertex(p0left)
		surfaceTool.add_uv(Vector2(q1, 0.0))
		surfaceTool.add_vertex(p1left)
		surfaceTool.add_uv(Vector2(q0, 1.0))
		surfaceTool.add_vertex(p0right)
		surfaceTool.add_uv(Vector2(q0, 1.0))
		surfaceTool.add_vertex(p0right)
		surfaceTool.add_uv(Vector2(q1, 0.0))
		surfaceTool.add_vertex(p1left)
		surfaceTool.add_uv(Vector2(q1, 1.0))
		surfaceTool.add_vertex(p1right)
	surfaceTool.generate_normals()
	var newmesh = surfaceTool.commit()
	if pathlines.mesh == null or pathlines.get_surface_material_count() == 0:
		pathlines.mesh = newmesh
		assert(pathlines.get_surface_material_count() != 0)
		var materialsystem = get_node("/root/Spatial/MaterialSystem")
		pathlines.set_surface_material(0, materialsystem.pathlinematerial("centreline"))
	else:
		var m = pathlines.get_surface_material(0)
		pathlines.mesh = newmesh
		pathlines.set_surface_material(0, m)




func makexctubeshell(xcdrawings):
	var polys = Polynets.makexcdpolys(nodepoints, onepathpairs)
	if len(polys) <= 2:
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
	
func updatexcshellmesh(xctubeshellmesh):
	if xctubeshellmesh != null:
		if not has_node("XCflatshell"):
			var xcflatshell = preload("res://nodescenes/XCtubeshell.tscn").instance()
			xcflatshell.set_name("XCflatshell")
			xcflatshell.get_node("CollisionShape").shape = ConcavePolygonShape.new()
			add_child(xcflatshell)
		$XCflatshell/MeshInstance.mesh = xctubeshellmesh
		$XCflatshell/CollisionShape.shape.set_faces(xctubeshellmesh.get_faces())
		get_node("/root/Spatial/MaterialSystem").updateflatshellmaterial(self, xcflatshellmaterial, false)
	else:
		if has_node("XCflatshell"):
			$XCflatshell.queue_free()

func notubeconnections_so_delxcable():
	for xctube in xctubesconn:
		if len(xctube.xcdrawinglink) != 0:
			return false
	return true

