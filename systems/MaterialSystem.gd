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
