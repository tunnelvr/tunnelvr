extends Node

enum MOVEMENT_TYPE { MOVE_AND_ROTATE, MOVE_AND_STRAFE }

onready var origin_node = get_node("..")
onready var camera_node = origin_node.get_node('HeadCam')
onready var controller = origin_node.get_node("HandLeft")
onready var controllerRight = origin_node.get_node("HandRight")
onready var kinematic_body: KinematicBody = origin_node.get_node("KinematicBody")
onready var collision_shape: CollisionShape = origin_node.get_node("KinematicBody/CollisionShape")
onready var tail : RayCast = origin_node.get_node("KinematicBody/Tail")
onready var world_scale = ARVRServer.world_scale

var player_radius = 0.25
var nextphysicsrotatestep = 0.0  # avoid flicker if done in _physics_process 
var mousecontrollervec = Vector3(0.2, -0.1, -0.5)
var velocity = Vector3(0.0, 0.0, 0.0)
var gravity = -30.0

export var max_speed = 300.0
export var drag_factor = 0.1

enum Buttons { VR_TRIGGER = 15, VR_PAD=14, VR_BUTTON_BY=1, VR_GRIP=2 }

func _ready():
	controller.connect("button_pressed", self, "_on_button_pressed")
	print("ARVRinterfaces ", ARVRServer.get_interfaces())

func _on_button_pressed(p_button):
	if p_button == Buttons.VR_PAD:
		var left_right = controller.get_joystick_axis(0)
		var up_down = controller.get_joystick_axis(1)
		if abs(up_down) < 0.5 and abs(left_right) > 0.1:
			nextphysicsrotatestep += (1 if left_right > 0 else -1)*(22.5 if abs(left_right) > 0.8 else 90.0)

func _input(event):
	if event is InputEventKey and event.pressed:
		if event.is_action_pressed("lh_left") and not Input.is_action_pressed("lh_shift"):
			nextphysicsrotatestep += -22.5
		if event.is_action_pressed("lh_right") and not Input.is_action_pressed("lh_shift"):
			nextphysicsrotatestep += 22.5
		if event.is_action_pressed("ui_cancel"):
			if Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE:
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			else:
				Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		if event.is_action_pressed("newboulder"):
			print("making new boulder")
			var righthand = controllerRight
			var markernode = preload("res://nodescenes/MarkerNode.tscn").instance()
			var boulderclutter = get_node("/root/Spatial/BoulderClutter")
			var nc = boulderclutter.get_child_count()
			markernode.get_node("CollisionShape").scale = Vector3(0.4, 0.6, 0.4) if ((nc%2) == 0) else Vector3(0.2, 0.4, 0.2)
			markernode.global_transform.origin = righthand.global_transform.origin - 0.9*righthand.global_transform.basis.z
			markernode.linear_velocity = -5.1*righthand.global_transform.basis.z
			boulderclutter.add_child(markernode)

	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		if origin_node.arvrinterface == null or origin_node.arvrinterface.get_tracking_status() == ARVRInterface.ARVR_NOT_TRACKING:
			var rhvec = mousecontrollervec + Vector3(event.relative.x, event.relative.y, 0)*0.006
			rhvec.x = clamp(rhvec.x, -0.4, 0.4)
			rhvec.y = clamp(rhvec.y, -0.3, 0.6)
			mousecontrollervec = rhvec.normalized()*0.8

		
func _physics_process(delta):
	# Adjust the height of our player according to our camera position
	var player_height = max(player_radius, camera_node.transform.origin.y + player_radius)
	collision_shape.shape.radius = player_radius
	collision_shape.shape.height = player_height - (player_radius * 2.0)
	collision_shape.transform.origin.y = (player_height / 2.0)
	#print(get_viewport().get_mouse_position(), Input.get_mouse_mode())
	controller.visible = controller.get_is_active() and origin_node.arvrinterface != null

	if nextphysicsrotatestep != 0:
		var t1 = Transform()
		var t2 = Transform()
		var rot = Transform()
		t1.origin = -camera_node.transform.origin
		t2.origin = camera_node.transform.origin
		rot = rot.rotated(Vector3(0.0, -1, 0.0), deg2rad(nextphysicsrotatestep))
		origin_node.transform *= t2 * rot * t1
		nextphysicsrotatestep = 0.0
		
	var left_right = controller.get_joystick_axis(0) if controller.get_is_active() else 0.0
	var forwards_backwards = controller.get_joystick_axis(1) if controller.get_is_active() else 0.0

	var lhkeyvec = Vector2(0, 0)
	if Input.is_action_pressed("lh_forward"):
		lhkeyvec.y += 1
	if Input.is_action_pressed("lh_backward"):
		lhkeyvec.y += -1
	if Input.is_action_pressed("lh_left"):
		lhkeyvec.x += 1
	if Input.is_action_pressed("lh_right"):
		lhkeyvec.x += -1
	if not Input.is_action_pressed("lh_shift"):
		forwards_backwards += 0.6*lhkeyvec.y*60*delta
		left_right += -0.6*lhkeyvec.x*60*delta
		
	if origin_node.arvrinterface == null:
		if Input.is_action_pressed("lh_shift") and lhkeyvec != Vector2(0,0):
			var vtarget = -camera_node.global_transform.basis.z*20 + camera_node.global_transform.basis.x*lhkeyvec.x*15*delta + Vector3(0, lhkeyvec.y, 0)*15*delta
			camera_node.look_at(camera_node.global_transform.origin + vtarget, Vector3(0,1,0))
			origin_node.rotation_degrees.y += camera_node.rotation_degrees.y
			camera_node.rotation_degrees.y = 0
		var mvec = camera_node.global_transform.basis.xform(mousecontrollervec)
		controllerRight.global_transform.origin = camera_node.global_transform.origin + mvec
		controllerRight.look_at(controllerRight.global_transform.origin + 1.0*mvec + 0.0*camera_node.global_transform.basis.z, Vector3(0,1,0))
		controllerRight.global_transform.origin.y -= 0.3
		
	if controller.is_button_pressed(Buttons.VR_GRIP) or Input.is_action_pressed("lh_fly"):
		if controller.is_button_pressed(Buttons.VR_TRIGGER) or Input.is_action_pressed("lh_forward") or Input.is_action_pressed("lh_backward"):
			var curr_transform = kinematic_body.global_transform
			var flydir = controller.global_transform.basis.z if controller.get_is_active() else camera_node.global_transform.basis.z
			if forwards_backwards < -0.5:
				flydir = -flydir
			velocity = flydir.normalized() * -delta * max_speed * world_scale
			velocity = kinematic_body.move_and_slide(velocity)
			var movement = (kinematic_body.global_transform.origin - curr_transform.origin)
			origin_node.global_transform.origin += movement
	
	else:
		var curr_transform = kinematic_body.global_transform
		var camera_transform = camera_node.global_transform
		curr_transform.origin = camera_transform.origin
		curr_transform.origin.y = origin_node.global_transform.origin.y
		
		# now we move it slightly back
		var forward_dir = -camera_transform.basis.z
		forward_dir.y = 0.0
		if forward_dir.length() > 0.01:
			curr_transform.origin += forward_dir.normalized() * -0.75 * player_radius
		
		kinematic_body.global_transform = curr_transform
		
		# we'll handle gravity separately
		var gravity_velocity = Vector3(0.0, velocity.y, 0.0)
		velocity.y = 0.0
		
		# Apply our drag
		velocity *= (1.0 - drag_factor)
		
		if (abs(forwards_backwards) > 0.1 and tail.is_colliding()):
			var dir = camera_transform.basis.z
			dir.y = 0.0					
			velocity = dir.normalized() * -forwards_backwards * delta * max_speed * world_scale
			#velocity = velocity.linear_interpolate(dir, delta * 100.0)		
		
		# apply move and slide to our kinematic body
		velocity = kinematic_body.move_and_slide(velocity, Vector3(0.0, 1.0, 0.0))
		
		# apply our gravity
		gravity_velocity.y += gravity * delta
		gravity_velocity = kinematic_body.move_and_slide(gravity_velocity, Vector3(0.0, 1.0, 0.0))
		velocity.y = gravity_velocity.y
		
		# now use our new position to move our origin point
		var movement = (kinematic_body.global_transform.origin - curr_transform.origin)
		origin_node.global_transform.origin += movement
		
		# Return this back to where it was so we can use its collision shape for other things too
		kinematic_body.global_transform.origin = curr_transform.origin

	
