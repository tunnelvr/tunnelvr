extends StaticBody

var i   # use for indexing the nodes on save

func _ready():
	pass

func set_materialoverride(material):
	$CollisionShape/MeshInstance.material_override = material

	
