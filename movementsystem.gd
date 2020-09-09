extends Node

onready var playerMe = get_parent()
onready var headcam = playerMe.get_node('HeadCam')
onready var handleft = playerMe.get_node("HandLeft")
onready var handright = playerMe.get_node("HandRight")

onready var kinematic_body: KinematicBody = playerMe.get_node("KinematicBody")
onready var collision_shape: CollisionShape = playerMe.get_node("KinematicBody/CollisionShape")
onready var tail : RayCast = playerMe.get_node("KinematicBody/Tail")

onready var tiptouchray = get_node("/root/Spatial/BodyObjects/MovePointThimble/TipTouchRay")

var nextphysicsrotatestep = 0.0  # avoid flicker if done in _physics_process 
var velocity = Vector3(0.0, 0.0, 0.0)
var gravity = -30.0
var groundspikedrelative = null
var groundspikedplayerposition = null

export var walkspeed = 180.0
export var flyspeed = 5.0
export var drag_factor = 0.1

func _ready():
	#handleft.connect("button_pressed", self, "_on_button_pressed")
	#handleft.connect("button_release", self, "_on_button_release")
	assert (ARVRServer.world_scale == 1.0)
	
var laserangleadjustmode = false
var laserangleoriginal = 0
var laserhandanglevector = Vector2(0,0)
var prevlaserangleoffset = 0

onready var audiobusrecordeffect = AudioServer.get_bus_effect(AudioServer.get_bus_index("Record"), 0)

func _on_button_pressed(p_button):
	if Tglobal.questhandtracking:
		print("Hand-tracked pinch button on ", p_button)
		if p_button == BUTTONS.HT_PINCH_MIDDLE_FINGER:
			get_node("/root/Spatial/GuiSystem/GreenBlob").global_transform.origin = get_node("/root/Spatial/BodyObjects/MovePointThimble").global_transform.origin
		return
	
	if p_button == BUTTONS.VR_PAD:
		var joypos = Vector2(handleft.get_joystick_axis(0), handleft.get_joystick_axis(1))
		if abs(joypos.y) < 0.5 and abs(joypos.x) > 0.1:
			nextphysicsrotatestep += (1 if joypos.x > 0 else -1)*(22.5 if abs(joypos.x) > 0.8 else 90.0)

	laserangleadjustmode = (p_button == BUTTONS.VR_GRIP) and tiptouchray.is_colliding() and tiptouchray.get_collider() == handright.get_node("HeelHotspot")
	if laserangleadjustmode:
		laserangleoriginal = handright.get_node("LaserOrient").rotation.x
		laserhandanglevector = Vector2(handleft.global_transform.basis.x.dot(handright.global_transform.basis.y), handleft.global_transform.basis.y.dot(handright.global_transform.basis.y))
		
	if p_button == BUTTONS.VR_BUTTON_BY:
		audiobusrecordeffect.set_recording_active(true)
		print("Doing the recording ", audiobusrecordeffect)
		get_node("/root/Spatial/GuiSystem/GreenBlob").global_transform.origin = get_node("/root/Spatial/BodyObjects/MovePointThimble").global_transform.origin

	if p_button == BUTTONS.VR_GRIP:
		handleft.get_node("csghandleft").setpartcolor(4, "#00CC00")

		
func _on_button_release(p_button):
	if Tglobal.questhandtracking:
		print("Hand-tracked pinch button off ", p_button)
		return
	
	if laserangleadjustmode:
		laserangleadjustmode = false
		handright.rumble = 0.0

	if p_button == BUTTONS.VR_BUTTON_BY:
		var recording = audiobusrecordeffect.get_recording()
		if recording != null:
			recording.save_to_wav("user://record3.wav")
			audiobusrecordeffect.set_recording_active(false)
			#print("Saved WAV file to: %s\n(%s)" % ["user://record3.wav", ProjectSettings.globalize_path("user://record3.wav")])
			print("end_recording ", audiobusrecordeffect)
			#handleft.get_node("AudioStreamPlayer3D").stream = recording
			#handleft.get_node("AudioStreamPlayer3D").play()
			print("recording length ", recording.get_data().size())
			print("fastlz ", recording.get_data().compress(File.COMPRESSION_FASTLZ).size())
			print("COMPRESSION_DEFLATE ", recording.get_data().compress(File.COMPRESSION_DEFLATE).size())
			print("COMPRESSION_ZSTD ", recording.get_data().compress(File.COMPRESSION_ZSTD).size())
			print("COMPRESSION_GZIP ", recording.get_data().compress(File.COMPRESSION_GZIP).size())
			playerMe.playvoicerecording(recording.get_data())
			if Tglobal.connectiontoserveractive:
				playerMe.rpc("playvoicerecording", recording.get_data())

	if p_button == BUTTONS.VR_GRIP:
		handleft.get_node("csghandleft").setpartcolor(4, "#FFFFFF")


func _input(event):
	if event is InputEventKey and event.pressed:
		if event.is_action_pressed("newboulder"):
			print("making new boulder")
			var markernode = preload("res://nodescenes/MarkerNode.tscn").instance()
			var boulderclutter = get_node("/root/Spatial/BoulderClutter")
			var nc = boulderclutter.get_child_count()
			markernode.get_node("CollisionShape").scale = Vector3(0.4, 0.6, 0.4) if ((nc%2) == 0) else Vector3(0.2, 0.4, 0.2)
			markernode.global_transform.origin = handright.global_transform.origin - 0.9*handright.global_transform.basis.z
			markernode.linear_velocity = -5.1*handright.global_transform.basis.z
			boulderclutter.add_child(markernode)

func _physics_process(delta):
	set_physics_process(false)
	var player_radius = collision_shape.shape.radius
	var player_height = max(player_radius*2, headcam.transform.origin.y + player_radius)
	collision_shape.shape.height = player_height - player_radius*2.0
	collision_shape.transform.origin.y = player_height/2.0
	#print(get_viewport().get_mouse_position(), Input.get_mouse_mode())
	var joypos = Vector2(handleft.get_joystick_axis(0), handleft.get_joystick_axis(1)) if (handleft.get_is_active() and not Tglobal.questhandtracking) else Vector2(0.0, 0.0)
	handleft.visible = Tglobal.VRstatus != "none" and handleft.get_is_active()
	var heelhotspot = tiptouchray.is_colliding() and tiptouchray.get_collider().get_name() == "HeelHotspot"
	if heelhotspot != handright.get_node("LaserOrient/MeshDial").visible:
		handright.get_node("LaserOrient/MeshDial").visible = heelhotspot
		handleft.get_node("csghandleft").setpartcolor(2, Color("222277") if heelhotspot else Color("#FFFFFF"))

	if nextphysicsrotatestep != 0:
		var t1 = Transform(Basis(), -headcam.transform.origin)
		var t2 = Transform(Basis(), headcam.transform.origin)
		var rot = Transform().rotated(Vector3(0.0, -1, 0.0), deg2rad(nextphysicsrotatestep))
		playerMe.transform *= t2 * rot * t1
		nextphysicsrotatestep = 0.0
	
	var lhkeyvec = Vector2(0, 0)
	if Input.is_action_pressed("lh_forward"):   lhkeyvec.y += 1
	if Input.is_action_pressed("lh_backward"):  lhkeyvec.y += -1
	if Input.is_action_pressed("lh_left"):      lhkeyvec.x += -1
	if Input.is_action_pressed("lh_right"):     lhkeyvec.x += 1
	if Input.is_action_pressed("lh_shift"):
		if Tglobal.VRstatus == "none" and lhkeyvec != Vector2(0,0):
			var vtarget = -headcam.global_transform.basis.z*20 + headcam.global_transform.basis.x*lhkeyvec.x*15*delta + Vector3(0, lhkeyvec.y, 0)*15*delta
			headcam.look_at(headcam.global_transform.origin + vtarget, Vector3(0,1,0))
			playerMe.rotation_degrees.y += headcam.rotation_degrees.y
			headcam.rotation_degrees.y = 0
	else:
		joypos += lhkeyvec
		

	var isflying = false
	var controlvelocity = Vector3(0, 0, 0)
	var isgroundspiked = tiptouchray.is_colliding() and tiptouchray.get_collider().get_name() == "XCtubeshell"
	if isgroundspiked:
		if groundspikedrelative == null:
			var clawengageposition = tiptouchray.get_collision_point()
			tiptouchray.get_node("GroundSpikePoint").global_transform.origin = clawengageposition
			tiptouchray.get_node("GroundSpikePoint").visible = true
			groundspikedrelative = clawengageposition - playerMe.global_transform.origin
			groundspikedplayerposition = playerMe.global_transform.origin
			Tglobal.soundsystem.quicksound("ClawGripSound", clawengageposition)
	elif groundspikedrelative != null:
		Tglobal.soundsystem.quicksound("ClawReleaseSound", tiptouchray.get_node("GroundSpikePoint").global_transform.origin)
		tiptouchray.get_node("GroundSpikePoint").visible = false
		groundspikedrelative = null
		print("exit ground spiked ")
	
	if isgroundspiked:
		var groundspikednowrelative = tiptouchray.get_node("GroundSpikePoint").global_transform.origin - playerMe.global_transform.origin
		playerMe.global_transform.origin = groundspikedplayerposition - (groundspikednowrelative - groundspikedrelative)
	elif tiptouchray.is_colliding() and tiptouchray.get_collider().get_name() == "GreenBlob":
		joypos += Vector2(0,1)
		var greenblob = tiptouchray.get_collider()
		var vec = greenblob.get_node("SteeringSphere").global_transform.origin - tiptouchray.get_collision_point()
		var fvec = Vector2(vec.x, vec.z)
		greenblob.get_node("SteeringSphere/TouchpointOrientation").rotation = Vector3(Vector2(fvec.length(), vec.y).angle(), -fvec.angle() - greenblob.get_node("..").rotation.y - deg2rad(90), 0)
		isflying = handleft.is_button_pressed(BUTTONS.HT_PINCH_INDEX_FINGER) if Tglobal.questhandtracking else handleft.is_button_pressed(BUTTONS.VR_GRIP)
		if isflying:
			controlvelocity = vec.normalized()*flyspeed
		else:
			controlvelocity = vec.normalized()
			controlvelocity.y = 0
			controlvelocity *= walkspeed
	elif Tglobal.questhandtracking:
		isflying = handleft.is_button_pressed(BUTTONS.HT_PINCH_INDEX_FINGER)
			
	elif handleft.is_button_pressed(BUTTONS.VR_GRIP) or Input.is_action_pressed("lh_fly"):
		isflying = true
		if handleft.is_button_pressed(BUTTONS.VR_TRIGGER) or Input.is_action_pressed("lh_forward") or Input.is_action_pressed("lh_backward"):
			var flydir = handleft.global_transform.basis.z if handleft.get_is_active() else headcam.global_transform.basis.z
			if joypos.y < -0.5:
				flydir = -flydir
			controlvelocity = -flydir.normalized()*flyspeed
			if handleft.is_button_pressed(BUTTONS.VR_PAD):
				controlvelocity *= 3.0
	else:
		if (abs(joypos.y) > 0.1 and tail.is_colliding()):
			var dir = Vector3(headcam.global_transform.basis.z.x, 0, headcam.global_transform.basis.z.z)
			controlvelocity = dir.normalized()*(-joypos.y*walkspeed)
	
	if isgroundspiked:
		pass

	elif laserangleadjustmode and handleft.is_button_pressed(BUTTONS.VR_GRIP):
		var laserangleoffset = 0
		if tiptouchray.is_colliding() and tiptouchray.get_collider() == handright.get_node("HeelHotspot"):
			var laserhandanglevectornew = Vector2(handleft.global_transform.basis.x.dot(handright.global_transform.basis.y), handleft.global_transform.basis.y.dot(handright.global_transform.basis.y))
			laserangleoffset = laserhandanglevector.angle_to(laserhandanglevectornew)
		handright.rumble = min(1.0, abs(prevlaserangleoffset - laserangleoffset)*delta*290)
		if handright.rumble < 0.1:
			handright.rumble = 0
		else:
			prevlaserangleoffset = laserangleoffset
		handright.get_node("LaserOrient").rotation.x = laserangleoriginal + laserangleoffset
		
	elif isflying:
		if controlvelocity != Vector3(0,0,0):
			var curr_transform = kinematic_body.global_transform
			velocity = kinematic_body.move_and_slide(controlvelocity)
			var movement = kinematic_body.global_transform.origin - curr_transform.origin
			kinematic_body.global_transform.origin = curr_transform.origin
			playerMe.global_transform.origin += movement
		else:
			velocity = Vector3(0,0,0)
	
	else:
		var curr_transform = kinematic_body.global_transform
		var camera_transform = headcam.global_transform
		curr_transform.origin = camera_transform.origin
		curr_transform.origin.y = playerMe.global_transform.origin.y
		
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
		
		if controlvelocity != Vector3(0,0,0):
			var dir = camera_transform.basis.z
			dir.y = 0.0
			velocity = controlvelocity*(delta)
			#velocity = velocity.linear_interpolate(dir, delta * 100.0)		
		
		# apply move and slide to our kinematic body
		velocity = kinematic_body.move_and_slide(velocity, Vector3(0.0, 1.0, 0.0))
		
		# apply our gravity
		gravity_velocity.y += gravity * delta
		gravity_velocity = kinematic_body.move_and_slide(gravity_velocity, Vector3(0.0, 1.0, 0.0))
		velocity.y = gravity_velocity.y
		
		# now use our new position to move our origin point
		var movement = (kinematic_body.global_transform.origin - curr_transform.origin)
		playerMe.global_transform.origin += movement
		
		# Return this back to where it was so we can use its collision shape for other things too
		kinematic_body.global_transform.origin = curr_transform.origin
	

