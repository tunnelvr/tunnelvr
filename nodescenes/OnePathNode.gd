extends StaticBody


var otIndex # use for indexing into OneTunnel lists of nodes

# for cycling around each node anti-clockwise and using for generating the areas
var drawingname = "unknown" # background image clicked on
var uvpoint = Vector2(0, 0) # uv point in background image
var wallangle = 0.0
var wallgroup = 0           # these should share the same wall angle

func _ready():
	pass

func getnodetype():
	return "ntPath"

func set_materialoverride(material):
	$CollisionShape/MeshInstance.material_override = material

	
