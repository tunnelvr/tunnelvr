extends Node

onready var playerMe = get_node("/root/Spatial/Players/PlayerMe")
onready var HeadCam = playerMe.get_node("HeadCam")
onready var HandLeft = playerMe.get_node("HandLeft")
onready var HandRight = playerMe.get_node("HandLeft")
onready var MovePointThimble = get_node("../MovePointThimble")
onready var tiptouchray = MovePointThimble.get_node("TipTouchRay")
onready var GroundSpikePoint = tiptouchray.get_node("GroundSpikePoint")

var flyspeed = 5.0
var walkspeed = 3.0
var newgreenblobposition = null
var nextphysicsrotatestep = 0.0
var playerdirectedflight = false
var playerdirectedflightvelocity = Vector3(0,0,0)
var playerdirectedwalkingvelocity = Vector3(0,0,0)
var clawengageposition = null


func inithandvrsignalconnections():
	HandLeft.connect("button_pressed", self, "_on_questhandtracking_button_pressed" if Tglobal.questhandtracking else "_on_button_pressed")
	HandLeft.connect("button_release", self, "_on_questhandtracking_button_release" if Tglobal.questhandtracking else "_on_button_release")

func _input(event):
	if event is InputEventKey and event.pressed and not Input.is_action_pressed("lh_shift"):
		if event.is_action_pressed("lh_left"):  nextphysicsrotatestep += -22.5
		if event.is_action_pressed("lh_right"): nextphysicsrotatestep += 22.5

func endclawengagement():
	Tglobal.soundsystem.quicksound("ClawReleaseSound", GroundSpikePoint.global_transform.origin)
	GroundSpikePoint.visible = false
	clawengageposition = null

func _physics_process(delta):
	playerdirectedflightvelocity = Vector3(0,0,0)
	playerdirectedwalkingvelocity = Vector3(0,0,0)

	var joypos = Vector2(0, 0)
	if Tglobal.VRstatus != "none" and not Tglobal.questhandtracking and HandLeft.get_is_active():
		joypos = Vector2(HandLeft.get_joystick_axis(0), HandLeft.get_joystick_axis(1))
	if not Input.is_action_pressed("lh_shift"):
		if Input.is_action_pressed("lh_forward"):   joypos.y += 1
		if Input.is_action_pressed("lh_backward"):  joypos.y += -1
		if Input.is_action_pressed("lh_left"):      joypos.x += -1
		if Input.is_action_pressed("lh_right"):     joypos.x += 1

	if playerdirectedflight and Tglobal.VRstatus != "none" and not Tglobal.questhandtracking and HandLeft.get_is_active():
		if clawengageposition != null:
			endclawengagement()
		if HandLeft.is_button_pressed(BUTTONS.VR_TRIGGER) or Input.is_action_pressed("lh_forward") or Input.is_action_pressed("lh_backward"):
			var flydir = HandLeft.global_transform.basis.z if HandLeft.get_is_active() else HeadCam.global_transform.basis.z
			if joypos.y < -0.5:
				flydir = -flydir
			playerdirectedflightvelocity = -flydir.normalized()*flyspeed
			if HandLeft.is_button_pressed(BUTTONS.VR_PAD):
				playerdirectedflightvelocity *= 3.0

	if not playerdirectedflight and Tglobal.VRstatus != "none" and not Tglobal.questhandtracking and HandLeft.get_is_active():
		var dir = Vector3(HeadCam.global_transform.basis.z.x, 0, HeadCam.global_transform.basis.z.z)
		playerdirectedwalkingvelocity = dir.normalized()*(-joypos.y*walkspeed)

	if tiptouchray.is_colliding() and tiptouchray.get_collider().get_name() == "GreenBlob":
		var greenblob = tiptouchray.get_collider()
		var vec = greenblob.get_node("SteeringSphere").global_transform.origin - tiptouchray.get_collision_point()
		var fvec2 = Vector2(vec.x, vec.z)
		greenblob.get_node("SteeringSphere/TouchpointOrientation").rotation = Vector3(Vector2(fvec2.length(), vec.y).angle(), -fvec2.angle() - greenblob.get_node("..").rotation.y - deg2rad(90), 0)
		if playerdirectedflight:
			playerdirectedflightvelocity = vec.normalized()*flyspeed
		else:
			playerdirectedwalkingvelocity = Vector3(vec.x, 0, vec.z).normalized()*walkspeed

	var isgroundspiked = tiptouchray.is_colliding() and tiptouchray.get_collider().get_name() == "XCtubeshell"
	if isgroundspiked:
		if clawengageposition == null:
			clawengageposition = tiptouchray.get_collision_point()
			GroundSpikePoint.global_transform.origin = clawengageposition
			GroundSpikePoint.visible = true
			Tglobal.soundsystem.quicksound("ClawGripSound", clawengageposition)
	elif clawengageposition != null:
		endclawengagement()

func _on_questhandtracking_button_pressed(p_button):
	if p_button == BUTTONS.HT_PINCH_MIDDLE_FINGER:
		newgreenblobposition = MovePointThimble.global_transform.origin
	elif p_button == BUTTONS.HT_PINCH_INDEX_FINGER:
		playerdirectedflight = true
				
func _on_questhandtracking_button_release(p_button):
	if p_button == BUTTONS.HT_PINCH_INDEX_FINGER:
		playerdirectedflight = false

func _on_button_pressed(p_button):
	if p_button == BUTTONS.VR_PAD:
		var joypos = Vector2(HandLeft.get_joystick_axis(0), HandLeft.get_joystick_axis(1))
		if abs(joypos.y) < 0.5 and abs(joypos.x) > 0.1:
			nextphysicsrotatestep += (1 if joypos.x > 0 else -1)*(22.5 if abs(joypos.x) > 0.8 else 90.0)

	if p_button == BUTTONS.VR_BUTTON_BY:
		newgreenblobposition = MovePointThimble.global_transform.origin

	if p_button == BUTTONS.VR_GRIP:
		HandLeft.get_node("csghandleft").setpartcolor(4, "#00CC00")
		playerdirectedflight = true

		
func _on_button_release(p_button):
	if p_button == BUTTONS.VR_BUTTON_BY:
		pass
		
	if p_button == BUTTONS.VR_GRIP:
		HandLeft.get_node("csghandleft").setpartcolor(4, "#FFFFFF")
		playerdirectedflight = false

func Dhanglelaserorient():
	var heelhotspot = tiptouchray.is_colliding() and tiptouchray.get_collider().get_name() == "HeelHotspot"
	if heelhotspot != HandRight.get_node("LaserOrient/MeshDial").visible:
		HandRight.get_node("LaserOrient/MeshDial").visible = heelhotspot
		HandLeft.get_node("csghandleft").setpartcolor(2, Color("222277") if heelhotspot else Color("#FFFFFF"))

	#laserangleadjustmode = (p_button == BUTTONS.VR_GRIP) and tiptouchray.is_colliding() and tiptouchray.get_collider() == handright.get_node("HeelHotspot")
	if laserangleadjustmode:
		laserangleoriginal = HandRight.get_node("LaserOrient").rotation.x
		laserhandanglevector = Vector2(HandLeft.global_transform.basis.x.dot(HandRight.global_transform.basis.y), HandLeft.global_transform.basis.y.dot(HandRight.global_transform.basis.y))

var laserangleadjustmode = false
var laserangleoriginal = 0
var laserhandanglevector = Vector2(0,0)
var prevlaserangleoffset = 0

func Dlaserangleadjustmode(delta):
	if HandLeft.is_button_pressed(BUTTONS.VR_GRIP):
		var laserangleoffset = 0
		if tiptouchray.is_colliding() and tiptouchray.get_collider() == HandRight.get_node("HeelHotspot"):
			var laserhandanglevectornew = Vector2(HandLeft.global_transform.basis.x.dot(HandRight.global_transform.basis.y), HandLeft.global_transform.basis.y.dot(HandRight.global_transform.basis.y))
			laserangleoffset = laserhandanglevector.angle_to(laserhandanglevectornew)
		HandRight.rumble = min(1.0, abs(prevlaserangleoffset - laserangleoffset)*delta*290)
		if HandRight.rumble < 0.1:
			HandRight.rumble = 0
		else:
			prevlaserangleoffset = laserangleoffset
		HandRight.get_node("LaserOrient").rotation.x = laserangleoriginal + laserangleoffset


func DMakeNewBoulder(event):
	#if event is InputEventKey and event.pressed and event.is_action_pressed("newboulder"):
	print("making new boulder")
	var markernode = preload("res://nodescenes/MarkerNode.tscn").instance()
	var boulderclutter = get_node("/root/Spatial/BoulderClutter")
	var nc = boulderclutter.get_child_count()
	markernode.get_node("CollisionShape").scale = Vector3(0.4, 0.6, 0.4) if ((nc%2) == 0) else Vector3(0.2, 0.4, 0.2)
	markernode.global_transform.origin = HandRight.global_transform.origin - 0.9*HandRight.global_transform.basis.z
	markernode.linear_velocity = -5.1*HandRight.global_transform.basis.z
	boulderclutter.add_child(markernode)
