extends RigidBody

var pointinghighlightmaterial = SpatialMaterial.new() #Make a new Spatial Material

func _ready():
	pointinghighlightmaterial.albedo_color = Color(0.92, 0.69, 0.13, 1.0) #Set color of new material

func set_materialoverride(material):
	$CollisionShape/MeshInstance.material_override = material

func set_highlight():
	$CollisionShape/MeshInstance.material_override = pointinghighlightmaterial
		
func clear_highlight():
	$CollisionShape/MeshInstance.material_override = null
	
func jump_up():
	set_axis_velocity(Vector3(0,10,0))
