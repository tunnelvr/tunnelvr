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

remote func togglebackfacecull():
	for tmesh in get_node("tubematerials").get_children():
		var tmat = tmesh.get_surface_material(0)
		if tmat.params_cull_mode == SpatialMaterial.CULL_DISABLED:
			tmat.params_cull_mode = SpatialMaterial.CULL_BACK
		elif tmat.params_cull_mode == SpatialMaterial.CULL_BACK:
			tmat.params_cull_mode = SpatialMaterial.CULL_DISABLED

	
