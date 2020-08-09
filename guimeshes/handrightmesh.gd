extends CSGMesh

onready var parts = [ $csgpalm, self, $csgtip, $csgback, $csgnotch ]
func _ready():
	for part in parts:
		part.material = part.material.duplicate() if part.material != null else part.mesh.material.duplicate() 
			
func setpartcolor(i, color):
	parts[i].material.albedo_color = color
	
