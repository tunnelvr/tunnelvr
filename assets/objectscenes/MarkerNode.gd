extends RigidBody

func _ready():
	#var m = $CollisionShape/MeshInstance.mesh.material
	#m.set_shader_param("albedo",  Color(randf(), randf(), randf()))
	pass
	
func jump_up():
	set_axis_velocity(Vector3(0,10,0.1))
