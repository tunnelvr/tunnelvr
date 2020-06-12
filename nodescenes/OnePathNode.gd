extends StaticBody

var i   # use for indexing the nodes on save
var otIndex # use for indexing into OneTunnel lists of nodes

# for cycling around each node anti-clockwise and using for generating the areas
var pathvectorseq = [ ]  # [ (arg, pathindex) ]
var drawingname = "unknown"        # background image clicked on
var uvpoint = Vector2(0, 0) # uv point in background image
var wallangle = 0.0

func _ready():
	pass

func getnodetype():
	return "ntPath"

func set_materialoverride(material):
	$CollisionShape/MeshInstance.material_override = material

	
