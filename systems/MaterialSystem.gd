extends Spatial

func _ready():
	visible = false

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

func updateflatshellmaterial(xcdrawing, name, highlighted):
	var xctubesector = xcdrawing.get_node("XCflatshell")
	xctubesector.visible = true
	xctubesector.get_node("CollisionShape").disabled = false
	xctubesector.get_node("MeshInstance").set_surface_material(0, tubematerial(name, highlighted))
	if name == "hole":
		xctubesector.collision_layer = CollisionLayer.CL_CaveWallTrans
	elif xcdrawing.drawingtype == DRAWING_TYPE.DT_ROPEHANG and xcdrawing.ropehangdetectedtype == DRAWING_TYPE.RH_FLAGSIGN:
		xctubesector.collision_layer = CollisionLayer.CL_CaveWallTrans
	else:
		xctubesector.collision_layer = CollisionLayer.CL_CaveWall


func nodematerial(mtype):
	var mm = $nodematerial.get_node(mtype)
	return mm.get_surface_material(0)

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

# var bbackfacecull
remote func togglebackfacecull():
	for tmesh in get_node("tubematerials").get_children():
		var tmat = tmesh.get_surface_material(0)
		if tmat.params_cull_mode == SpatialMaterial.CULL_DISABLED:
			tmat.params_cull_mode = SpatialMaterial.CULL_BACK
		elif tmat.params_cull_mode == SpatialMaterial.CULL_BACK:
			tmat.params_cull_mode = SpatialMaterial.CULL_DISABLED

remote func setfloormaptexture(xcfloorname):
	var xcdrawings = get_node("/root/Spatial/SketchSystem/XCdrawings")
	var xcfloor = xcdrawings.get_node(xcfloorname)
	var floormesh = xcfloor.get_node("XCdrawingplane/CollisionShape/MeshInstance")
	var floorplanescale = xcfloor.get_node("XCdrawingplane").scale
	var floormeshdiagonal2 = Vector3(floorplanescale.x*floormesh.mesh.size.x/2, -floorplanescale.y*floormesh.mesh.size.y/2, 0.0)
	var floorplane00 = xcfloor.transform.xform(-floormeshdiagonal2)
	var floorplane11 = xcfloor.transform.xform(floormeshdiagonal2)
	var uv2_xvec = Vector3(xcfloor.transform.basis.x.x, -xcfloor.transform.basis.x.z, 0.0)
	var uv2_yvec = Vector3(-uv2_xvec.y, uv2_xvec.x, 0.0)
	var rfloorplane00 = floorplane00.x*uv2_xvec + floorplane00.z*uv2_yvec
	var rfloorplane11 = floorplane11.x*uv2_xvec + floorplane11.z*uv2_yvec
	# Solve: rfloorplane00*uv2_scale + uv2_offset = flooruv1offset
	# 		 rfloorplane11*uv2_scale + uv2_offset = flooruv1offset + flooruv1scale
	# (rfloorplane11-rfloorplane00)*uv2_scale = flooruv1scale
	var floordrawingmaterial = floormesh.get_surface_material(0)
	var floortexture = floordrawingmaterial.get_shader_param("texture_albedo")
	var floormapmesh = $tubematerials.get_node("floormap")
	var floormapmeshmat = floormapmesh.get_surface_material(0)
	floormapmeshmat.set_shader_param("texture_albedo", floortexture)
	var flooruv1scale = floordrawingmaterial.get_shader_param("uv1_scale")
	var flooruv1offset = floordrawingmaterial.get_shader_param("uv1_offset")
	var uv2_scale = Vector3(flooruv1scale.x/(rfloorplane11.x - rfloorplane00.x), flooruv1scale.y/(rfloorplane11.y - rfloorplane00.y), 1.0)
	var uv2_offset = Vector3(flooruv1offset.x - rfloorplane00.x*uv2_scale.x, flooruv1offset.y - rfloorplane00.y*uv2_scale.y, 0.0)
	floormapmeshmat.set_shader_param("uv2_xvec", uv2_xvec)
	floormapmeshmat.set_shader_param("uv2_scale", uv2_scale)
	floormapmeshmat.set_shader_param("uv2_offset", uv2_offset)

