extends Node

onready var playerMe = get_node("/root/Spatial/Players/PlayerMe")
onready var HeadCam = playerMe.get_node("HeadCam")
onready var HandLeft = playerMe.get_node("HandLeft")
onready var MovePointThimble = get_node("../MovePointThimble")
onready var tiptouchray = MovePointThimble.get_node("TipTouchRay")

var flyspeed = 5.0
var walkspeed = 3.0
var newgreenblobposition = null
var nextphysicsrotatestep = 0.0
var playerdirectedflight = false
var playerdirectedflightvelocity = Vector3(0,0,0)
var playerdirectedwalkingvelocity = Vector3(0,0,0)

func _ready():
	if Tglobal.VRstatus != "none":
		HandLeft.connect("button_pressed", self, "_on_questhandtracking_button_pressed" if Tglobal.questhandtracking else "_on_button_pressed")
		HandLeft.connect("button_release", self, "_on_questhandtracking_button_release" if Tglobal.questhandtracking else "_on_button_release")

func _input(event):
	if event is InputEventKey and event.pressed and not Input.is_action_pressed("lh_shift"):
		if event.is_action_pressed("lh_left"):  nextphysicsrotatestep += -22.5
		if event.is_action_pressed("lh_right"): nextphysicsrotatestep += 22.5

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
		var fvec = Vector2(vec.x, vec.z)
		greenblob.get_node("SteeringSphere/TouchpointOrientation").rotation = Vector3(Vector2(fvec.length(), vec.y).angle(), -fvec.angle() - greenblob.get_node("..").rotation.y - deg2rad(90), 0)
		if playerdirectedflight:
			playerdirectedflightvelocity = vec.normalized()*flyspeed
		else:
			playerdirectedwalkingvelocity = fvec.normalized()*walkspeed


func _on_questhandtracking_button_pressed(p_button):
	if p_button == BUTTONS.HT_PINCH_MIDDLE_FINGER:
		newgreenblobposition = MovePointThimble.global_transform.origin
	if p_button == BUTTONS.HT_PINCH_INDEX_FINGER:
		playerdirectedflight = true
		
func _on_questhandtracking_button_release(p_button):
	if p_button == BUTTONS.HT_PINCH_INDEX_FINGER:
		playerdirectedflight = true

func _on_button_pressed(p_button):
	if p_button == BUTTONS.VR_PAD:
		var joypos = Vector2(HandLeft.get_joystick_axis(0), HandLeft.get_joystick_axis(1))
		if abs(joypos.y) < 0.5 and abs(joypos.x) > 0.1:
			nextphysicsrotatestep += (1 if joypos.x > 0 else -1)*(22.5 if abs(joypos.x) > 0.8 else 90.0)

	if p_button == BUTTONS.VR_BUTTON_BY:
		newgreenblobposition = get_node("/root/Spatial/BodyObjects/MovePointThimble").global_transform.origin

	if p_button == BUTTONS.VR_GRIP:
		HandLeft.get_node("csghandleft").setpartcolor(4, "#00CC00")
		playerdirectedflight = true

		
func _on_button_release(p_button):
	if p_button == BUTTONS.VR_BUTTON_BY:
		pass
		
	if p_button == BUTTONS.VR_GRIP:
		HandLeft.get_node("csghandleft").setpartcolor(4, "#FFFFFF")
		playerdirectedflight = false

