extends StaticBody

var stationname = "unknown"

func _ready():
	pass

func getnodetype():
	return "ntStation"

func set_materialoverride(material):
	$CollisionShape/MeshInstance.material_override = material
	
