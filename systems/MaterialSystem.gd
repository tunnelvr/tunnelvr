extends Spatial

func tubematerialfromnumber(n, highlighted):
	var mm = $tubematerials.get_child(n)
	if highlighted:
		mm = mm.get_node("highlight")
	return mm.get_surface_material(0)

func tubematerialtransparent(highlighted):
	var mm = $transparent
	if highlighted:
		mm = mm.get_node("highlight")
	return mm.get_surface_material(0)

func tubematerialcount():
	return $tubematerials.get_child_count()

func nodematerial(mtype):
	var mm = $nodematerial.get_node(mtype)
	return mm.get_surface_material(0)

func lasermaterial(mtype):
	var mm = $lasermaterial.get_node(mtype)
	return mm.get_surface_material(0)

func pathlinematerial(mtype):
	var mm = $pathlines.get_node(mtype)
	return mm.get_surface_material(0)

func xcdrawingmaterial(mtype, sca):
	var mm = $xcdrawingmaterials.get_node(mtype)
	var mat = mm.get_surface_material(0)
	if sca != null:
		assert (mtype != "normal")
		mat.uv1_scale = sca
		mat.uv1_offset = -sca/2
	return mat
	
func adjustmaterialtotorchlight(torchon):
	$xcdrawingmaterials/normal.get_surface_material(0).albedo_color.a = 0.1 if torchon else 0.43
	$xcdrawingmaterials/active.get_surface_material(0).albedo_color.a = 0.1 if torchon else 0.43
	$xcdrawingmaterials/highlight.get_surface_material(0).albedo_color.a = 0.1 if torchon else 0.43

	
	
