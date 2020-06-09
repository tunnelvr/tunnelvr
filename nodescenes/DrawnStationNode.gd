extends StaticBody

var stationname = "unknown"
var drawingname = "unknown"
var uvpoint = Vector2(0, 0) # uv point in background image

func _ready():
	pass

func getnodetype():
	return "ntDrawnStation"

func set_materialoverride(material):
	$CollisionShape/MeshInstance.material_override = material
	
