extends StaticBody


var otIndex # use for indexing into OneTunnel lists of nodes

func _ready():
	pass

func set_materialoverride(material):
	$CollisionShape/MeshInstance.material_override = material

	
