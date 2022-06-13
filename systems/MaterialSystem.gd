extends Spatial

func _ready():
	visible = false
	#setnodematerialdistancefade(2.0, 3.0)

func tubematerialnamefromnumber(n):
	var mm = $tubematerials.get_child(n)
	return mm.get_name()

func tubematerial(name, highlighted):
	var mm = $tubematerials.get_node(name) if $tubematerials.has_node(name) else $tubematerials.get_child(0)
	if highlighted:
		mm = mm.get_node("highlight")
	return mm.get_surface_material(0)
	
func updatetubesectormaterial(xctubesector, name, highlighted):
	xctubesector.visible = true
	xctubesector.get_node("CollisionShape").disabled = false
	xctubesector.get_node("MeshInstance").set_surface_material(0, tubematerial(name, highlighted))
	xctubesector.collision_layer = CollisionLayer.CL_CaveWallTrans if name == "hole" else CollisionLayer.CL_CaveWall

func updateflatshellmaterial(xcdrawing, highlight):
	var xctubesector = xcdrawing.get_node("XCflatshell")
	xctubesector.visible = true
	xctubesector.get_node("CollisionShape").disabled = false
	var meshinstance = xctubesector.get_node("MeshInstance")

	var shellfacematerials = xcdrawing.additionalproperties.get("shellfacematerials", {}) if xcdrawing.additionalproperties != null else {}
	var materialname = xcdrawing.xcflatshellmaterial
	for i in range(meshinstance.get_surface_material_count()):
		if xcdrawing.shellfaceindexes.has(i):
			var materialnodename = xcdrawing.shellfaceindexes[i]
			if shellfacematerials.has(materialnodename):
				materialname = shellfacematerials[materialnodename]
		meshinstance.set_surface_material(i, tubematerial(materialname, highlight=="all"))

	if materialname == "hole":
		xctubesector.collision_layer = CollisionLayer.CL_CaveWallTrans
	elif xcdrawing.drawingtype == DRAWING_TYPE.DT_ROPEHANG and xcdrawing.ropehangdetectedtype == DRAWING_TYPE.RH_FLAGSIGN:
		xctubesector.collision_layer = CollisionLayer.CL_CaveWallTrans
	else:
		xctubesector.collision_layer = CollisionLayer.CL_CaveWall


func nodematerial(mtype):
	var mm = $nodematerial.get_node(mtype)
	return mm.get_surface_material(0)

func setnodematerialdistancefade(startfadedistance, invisibledistance):
	for mm in $nodematerial.get_children():
		if not ("selected" in mm.name or "highlight" in mm.name):
			var mat = mm.get_surface_material(0)
			mat.distance_fade_mode = SpatialMaterial.DISTANCE_FADE_PIXEL_ALPHA
			mat.distance_fade_max_distance = startfadedistance
			mat.distance_fade_min_distance = invisibledistance

func lasermaterial(mtype):
	var mm = $lasermaterial.get_node(mtype)
	return mm.get_surface_material(0)

func lasermaterialN(itype):
	return lasermaterial(["spot", "spotselected", "spotinair", "spotselectedinair"][itype])

func pathlinematerial(mtype):
	var mm = $pathlines.get_node(mtype)
	return mm.get_surface_material(0)

func xcdrawingmaterial(mtype):
	var mm = $xcdrawingmaterials.get_node(mtype)
	return mm.get_surface_material(0)
	
func adjustmaterialtotorchlight(torchon):
	$xcdrawingmaterials/normal.get_surface_material(0).albedo_color.a = 0.33 if torchon else 0.43
	$xcdrawingmaterials/active.get_surface_material(0).albedo_color.a = 0.33 if torchon else 0.43
	$xcdrawingmaterials/highlight.get_surface_material(0).albedo_color.a = 0.33 if torchon else 0.43
	$tubematerials/hole.get_surface_material(0).albedo_color.a = 0.11 if torchon else 0.18

func setallbackfacecull(cull_mode):
	for tmesh in get_node("tubematerials").get_children():
		var tmat = tmesh.get_surface_material(0)
		if tmat is SpatialMaterial:
			tmat.params_cull_mode = cull_mode
		else:
			print("cant' change backface cull on material ", tmesh.get_name())

remote func setfloormaptexture(xcfloorname):
	var xcdrawings = get_node("/root/Spatial/SketchSystem/XCdrawings")
	var xcfloor = xcdrawings.get_node(xcfloorname)
	var floormesh = xcfloor.get_node("XCdrawingplane/CollisionShape/MeshInstance")
	var Dfloorplanescale = xcfloor.get_node("XCdrawingplane").scale
	var xcfloorimgheight = xcfloor.imgwidth*xcfloor.imgheightwidthratio
	var floorplanescale = Vector3(xcfloor.imgwidth*0.5, xcfloorimgheight*0.5, 1)

	print(Dfloorplanescale, floorplanescale)
	floorplanescale = Dfloorplanescale
	
# get proper corners from the bits we have trimmed back 
	#var floormeshdiagonal2 = Vector3(floorplanescale.x*floormesh.mesh.size.x/2, -floorplanescale.y*floormesh.mesh.size.y/2, 0.0)
	#var floorplane00 = xcfloor.transform.xform(-floormeshdiagonal2)
	#var floorplane11 = xcfloor.transform.xform(floormeshdiagonal2)
	var floorplane00 = xcfloor.transform.xform(Vector3(xcfloor.imgtrimleftdown.x, xcfloor.imgtrimrightup.y, 0.0))
	var floorplane11 = xcfloor.transform.xform(Vector3(xcfloor.imgtrimrightup.x, xcfloor.imgtrimleftdown.y, 0.0))
	var uv2_xvec = Vector3(xcfloor.transform.basis.x.x, -xcfloor.transform.basis.x.z, 0.0)
	var uv2_yvec = Vector3(-uv2_xvec.y, uv2_xvec.x, 0.0)
	var rfloorplane00 = floorplane00.x*uv2_xvec + floorplane00.z*uv2_yvec
	var rfloorplane11 = floorplane11.x*uv2_xvec + floorplane11.z*uv2_yvec
		
	# Solve: rfloorplane00*uv2_scale + uv2_offset = flooruv1offset
	# 		 rfloorplane11*uv2_scale + uv2_offset = flooruv1offset + flooruv1scale
	# (rfloorplane11-rfloorplane00)*uv2_scale = flooruv1scalex
	var floordrawingmaterial = floormesh.get_surface_material(0)
	var floortexture = floordrawingmaterial.get_shader_param("texture_albedo")
	var floormapmesh = $tubematerials.get_node("floormap")
	var floormapmeshmat = floormapmesh.get_surface_material(0)
	floormapmeshmat.set_shader_param("texture_albedo", floortexture)
	var flooruv1scale = floordrawingmaterial.get_shader_param("uv1_scale")
	var flooruv1offset = floordrawingmaterial.get_shader_param("uv1_offset")
	var uv2_scale = Vector3(flooruv1scale.x/(rfloorplane11.x - rfloorplane00.x), flooruv1scale.y/(rfloorplane11.y - rfloorplane00.y), 1.0)
	var uv2_offset = Vector3(flooruv1offset.x - rfloorplane00.x*uv2_scale.x, flooruv1offset.y - rfloorplane00.y*uv2_scale.y, 0.0)
	print(rfloorplane00*uv2_scale + uv2_offset, flooruv1offset)
	print(rfloorplane11*uv2_scale + uv2_offset, flooruv1offset + flooruv1scale)


	floormapmeshmat.set_shader_param("uv2_xvec", uv2_xvec)
	floormapmeshmat.set_shader_param("uv2_scale", uv2_scale)
	floormapmeshmat.set_shader_param("uv2_offset", uv2_offset)

