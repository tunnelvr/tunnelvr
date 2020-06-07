extends StaticBody

var stationname = "unknown"

func _ready():
	pass

func set_materialoverride(material):
	$CollisionShape/MeshInstance.material_override = material

	
