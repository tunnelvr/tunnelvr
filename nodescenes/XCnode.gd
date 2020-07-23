extends StaticBody

var otIndex: int = 0

func _ready():
	pass

func set_materialoverride(material):
	$CollisionShape/MeshInstance.material_override = material
