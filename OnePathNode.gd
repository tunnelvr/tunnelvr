extends StaticBody

var pointinghighlightmaterial = SpatialMaterial.new() #Make a new Spatial Material

func _ready():
	pointinghighlightmaterial.albedo_color = Color(0.92, 0.69, 0.13, 1.0) #Set color of new material

func set_highlight():
	$CollisionShape/MeshInstance.material_override = pointinghighlightmaterial
		
func clear_highlight():
	$CollisionShape/MeshInstance.material_override = null
	
