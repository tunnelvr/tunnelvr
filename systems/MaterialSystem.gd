extends Spatial

func tubematerialfromnumber(n, highlighted):
	var mm = $tubematerials.get_child(n)
	if highlighted:
		mm = mm.get_node("highlight")
	return mm.get_surface_material(0)
