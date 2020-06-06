extends StaticBody

var i   # use for indexing the nodes on save
var pathvectorseq = [ ]  # [ (arg, pathindex) ]for allocating the areas 

func _ready():
	pass

func set_materialoverride(material):
	$CollisionShape/MeshInstance.material_override = material

	
