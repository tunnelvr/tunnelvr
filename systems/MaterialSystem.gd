extends Spatial

func _ready():
	visible = false

func tubematerialnamefromnumber(n):
	var mm = $tubematerials.get_child(n)
	return mm.get_name()

func updatetubesectormaterial(xctubesector, name, highlighted):
	xctubesector.visible = true
	xctubesector.get_node("CollisionShape").disabled = false
	var mm = $tubematerials.get_node(name) if $tubematerials.has_node(name) else $tubematerials.get_child(0)
	if highlighted:
		mm = mm.get_node("highlight")
	xctubesector.get_node("MeshInstance").set_surface_material(0, mm.get_surface_material(0))
	xctubesector.collision_layer = CollisionLayer.CL_CaveWallTrans if name == "hole" else CollisionLayer.CL_CaveWall

func advancetubematerial(name, dir):
	var mm = $tubematerials.get_node(name) if $tubematerials.has_node(name) else $tubematerials.get_child(0)
	var n = mm.get_index()
	var np = (n + dir + $tubematerials.get_child_count())%$tubematerials.get_child_count()
	return $tubematerials.get_child(np).get_name()

func nodematerial(mtype):
	var mm = $nodematerial.get_node(mtype)
	return mm.get_surface_material(0)

func lasermaterial(mtype):
	var mm = $lasermaterial.get_node(mtype)
	return mm.get_surface_material(0)

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

	
	
