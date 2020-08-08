extends Node

onready var playernode = get_parent()
onready var headcam = playernode.get_node('HeadCam')
onready var handleft = playernode.get_node("HandLeft")
onready var handright = playernode.get_node("HandRight")
onready var kinematic_body: KinematicBody = playernode.get_node("KinematicBody")
onready var collision_shape: CollisionShape = playernode.get_node("KinematicBody/CollisionShape")
onready var tail : RayCast = playernode.get_node("KinematicBody/Tail")
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
	handleft.connect("button_pressed", self, "_on_button_pressed")
	print("ARVRinterfaces ", ARVRServer.get_interfaces())

func _on_button_pressed(p_button):
	if p_button == Buttons.VR_PAD:
		var left_right = handleft.get_joystick_axis(0)
		var up_down = handleft.get_joystick_axis(1)
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
			var markernode = preload("res://nodescenes/MarkerNode.tscn").instance()
			var boulderclutter = get_node("/root/Spatial/BoulderClutter")
			var nc = boulderclutter.get_child_count()
			markernode.get_node("CollisionShape").scale = Vector3(0.4, 0.6, 0.4) if ((nc%2) == 0) else Vector3(0.2, 0.4, 0.2)
			markernode.global_transform.origin = handright.global_transform.origin - 0.9*handright.global_transform.basis.z
			markernode.linear_velocity = -5.1*handright.global_transform.basis.z
			boulderclutter.add_child(markernode)

	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		if playernode.arvrinterface == null or playernode.arvrinterface.get_tracking_status() == ARVRInterface.ARVR_NOT_TRACKING:
			var rhvec = mousecontrollervec + Vector3(event.relative.x, event.relative.y, 0)*0.002
			rhvec.x = clamp(rhvec.x, -0.4, 0.4)
			rhvec.y = clamp(rhvec.y, -0.3, 0.6)
			mousecontrollervec = rhvec.normalized()*0.8

func _physics_process(delta):
	# Adjust the height of our player according to our camera position
	var player_height = max(player_radius, headcam.transform.origin.y + player_radius)
	collision_shape.shape.radius = player_radius
	collision_shape.shape.height = player_height - (player_radius * 2.0)
	collision_shape.transform.origin.y = (player_height / 2.0)
	#print(get_viewport().get_mouse_position(), Input.get_mouse_mode())
	handleft.visible = playernode.arvrinterface != null and handleft.get_is_active()

	if nextphysicsrotatestep != 0:
		var t1 = Transform()
		var t2 = Transform()
		var rot = Transform()
		t1.origin = -headcam.transform.origin
		t2.origin = headcam.transform.origin
		rot = rot.rotated(Vector3(0.0, -1, 0.0), deg2rad(nextphysicsrotatestep))
		playernode.transform *= t2 * rot * t1
		nextphysicsrotatestep = 0.0
		
	var left_right = handleft.get_joystick_axis(0) if handleft.get_is_active() else 0.0
	var forwards_backwards = handleft.get_joystick_axis(1) if handleft.get_is_active() else 0.0

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
		
	if playernode.arvrinterface == null:
		if Input.is_action_pressed("lh_shift") and lhkeyvec != Vector2(0,0):
			var vtarget = -headcam.global_transform.basis.z*20 + headcam.global_transform.basis.x*lhkeyvec.x*15*delta + Vector3(0, lhkeyvec.y, 0)*15*delta
			headcam.look_at(headcam.global_transform.origin + vtarget, Vector3(0,1,0))
			playernode.rotation_degrees.y += headcam.rotation_degrees.y
			headcam.rotation_degrees.y = 0
		var mvec = headcam.global_transform.basis.xform(mousecontrollervec)
		handright.global_transform.origin = headcam.global_transform.origin + mvec
		handright.look_at(handright.global_transform.origin + 1.0*mvec + 0.0*headcam.global_transform.basis.z, Vector3(0,1,0))
		handright.global_transform.origin.y -= 0.3
		
	if handleft.is_button_pressed(Buttons.VR_GRIP) or Input.is_action_pressed("lh_fly"):
		if handleft.is_button_pressed(Buttons.VR_TRIGGER) or Input.is_action_pressed("lh_forward") or Input.is_action_pressed("lh_backward"):
			var curr_transform = kinematic_body.global_transform
			var flydir = handleft.global_transform.basis.z if handleft.get_is_active() else headcam.global_transform.basis.z
			if forwards_backwards < -0.5:
				flydir = -flydir
			velocity = flydir.normalized() * -delta * max_speed * world_scale
			velocity = kinematic_body.move_and_slide(velocity)
			var movement = (kinematic_body.global_transform.origin - curr_transform.origin)
			playernode.global_transform.origin += movement
	
	else:
		var curr_transform = kinematic_body.global_transform
		var camera_transform = headcam.global_transform
		curr_transform.origin = camera_transform.origin
		curr_transform.origin.y = playernode.global_transform.origin.y
		
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
		playernode.global_transform.origin += movement
		
		# Return this back to where it was so we can use its collision shape for other things too
		kinematic_body.global_transform.origin = curr_transform.origin

	var doppelganger = playernode.doppelganger
	if is_inside_tree() and is_instance_valid(doppelganger):
		doppelganger.global_transform.origin.y = playernode.global_transform.origin.y
		doppelganger.global_transform.basis = Basis(-playernode.global_transform.basis.x, playernode.global_transform.basis.y, -playernode.global_transform.basis.z)
		#doppelganger.global_transform.rotate_y(PI/2)
		doppelganger.get_node("HeadCam").transform = headcam.transform
		doppelganger.get_node("HandLeft").visible = handleft.visible
		doppelganger.get_node("HandLeft").transform = handleft.transform
		doppelganger.get_node("HandRight").visible = handright.visible
		doppelganger.get_node("HandRight").transform = handright.transform
	playernode.rpc_unreliable("setavatarposition", playernode.global_transform, headcam.transform, handleft.transform if handleft.visible else null, handright.transform if handright.visible else null)
	
