extends Spatial

func tubematerialnamefromnumber(n):
	var mm = $tubematerials.get_child(n)
	return mm.get_name()

func gettubematerial(name, highlighted):
	var mm = $tubematerials.get_node(name) if $tubematerials.has_node(name) else $tubematerials.get_child(0)
	if highlighted:
		mm = mm.get_node("highlight")
	return mm.get_surface_material(0)

func advancetubematerial(name, dir):
	var mm = $tubematerials.get_node(name) if $tubematerials.has_node(name) else $tubematerials.get_child(0)
	var n = mm.get_index()
	var np = (n + dir + $tubematerials.get_child_count())%$tubematerials.get_child_count()
	return $tubematerials.get_child(np).get_name()

func tubematerialtransparent(highlighted):
	var mm = $transparent
	if highlighted:
		mm = mm.get_node("highlight")
	return mm.get_surface_material(0)

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
	$xcdrawingmaterials/normal.get_surface_material(0).albedo_color.a = 0.23 if torchon else 0.43
	$xcdrawingmaterials/active.get_surface_material(0).albedo_color.a = 0.23 if torchon else 0.43
	$xcdrawingmaterials/highlight.get_surface_material(0).albedo_color.a = 0.23 if torchon else 0.43

	
	
