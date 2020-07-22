extends StaticBody


var otIndex # use for indexing into OneTunnel lists of nodes

# for cycling around each node anti-clockwise and using for generating the areas
var drawingname = "unknown" # background image clicked on
var uvpoint = Vector2(0, 0) # uv point in background image

func _ready():
	pass

func set_materialoverride(material):
	$CollisionShape/MeshInstance.material_override = material

	
