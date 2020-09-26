extends Node

onready var playerMe = get_node("/root/Spatial/Players/PlayerMe")
onready var HeadCam = playerMe.get_node("HeadCam")
onready var HandLeft = playerMe.get_node("HandLeft")
onready var HandLeftController = playerMe.get_node("HandLeftController")
onready var MovePointThimble = get_node("../MovePointThimble")
onready var tiptouchray = MovePointThimble.get_node("TipTouchRay")
onready var GroundSpikePoint = tiptouchray.get_node("GroundSpikePoint")

var flyspeed = 5.0
var walkspeed = 3.0
var nextphysicsrotatestep = 0.0
var playerdirectedflight = false
var playerdirectedflightvelocity = Vector3(0,0,0)
var playerdirectedwalkingvelocity = Vector3(0,0,0)
var clawengageposition = null


func initcontrollersignalconnections():
	HandLeftController.connect("button_pressed", self, "_on_button_pressed")
	HandLeftController.connect("button_release", self, "_on_button_release")

func initquesthandcontrollersignalconnections():
	HandLeftController.connect("button_pressed", self, "_on_questhandtracking_button_pressed")
	HandLeftController.connect("button_release", self, "_on_questhandtracking_button_release")


func _input(event):
	if event is InputEventKey and event.pressed and not Input.is_action_pressed("lh_shift"):
		if event.is_action_pressed("lh_left"):  nextphysicsrotatestep += -22.5
		if event.is_action_pressed("lh_right"): nextphysicsrotatestep += 22.5

func endclawengagement():
	Tglobal.soundsystem.quicksound("ClawReleaseSound", GroundSpikePoint.global_transform.origin)
	GroundSpikePoint.visible = false
	clawengageposition = null

var prevgait = ""
func _process(delta):
	return
	var WIP = get_node("../Locomotion_WalkInPlace")
	var gait = WIP.getgait()
	if gait != prevgait:
		print("WIP gait ", gait) 
		prevgait = gait
	if WIP.step_low_just_detected:
		print("WIP step_low_just_detected")
	if WIP.step_high_just_detected:
		print("WIP step_high_just_detected")

func _physics_process(delta):
	playerdirectedflightvelocity = Vector3(0,0,0)
	playerdirectedwalkingvelocity = Vector3(0,0,0)

	var joypos = HandLeft.joypos
	if not Input.is_action_pressed("lh_shift"):
		if Input.is_action_pressed("lh_forward"):   joypos.y += 1
		if Input.is_action_pressed("lh_backward"):  joypos.y += -1
		if Input.is_action_pressed("lh_left"):      joypos.x += -1
		if Input.is_action_pressed("lh_right"):     joypos.x += 1

	if HandLeft.triggerbuttonheld and HandLeft.pointervalid and not Tglobal.controlslocked:
		var vec = -(playerMe.global_transform*HandLeft.pointerposearvrorigin).basis.z
		if playerdirectedflight:
			if clawengageposition != null:
				endclawengagement()
			playerdirectedflightvelocity = vec.normalized()*flyspeed
		else:
			playerdirectedwalkingvelocity = Vector3(vec.x, 0, vec.z).normalized()*walkspeed
			var vang = rad2deg(Vector2(Vector2(vec.x, vec.z).length(), vec.y).angle())
			if vang > 45:
				#playerdirectedwalkingvelocity = -playerdirectedwalkingvelocity
				playerdirectedwalkingvelocity = Vector3(HeadCam.global_transform.basis.z.x, 0, HeadCam.global_transform.basis.z.z).normalized()*walkspeed

	elif not playerdirectedflight and not Tglobal.questhandtracking and not Tglobal.controlslocked:
		var dir = Vector3(HeadCam.global_transform.basis.z.x, 0, HeadCam.global_transform.basis.z.z)
		playerdirectedwalkingvelocity = dir.normalized()*(-HandLeft.joypos.y*walkspeed)
		
				
	var isgroundspiked = tiptouchray.is_colliding() and tiptouchray.get_collider().get_parent().get_name() == "XCtubesectors"
	if isgroundspiked:
		if clawengageposition == null:
			clawengageposition = tiptouchray.get_collision_point()
			GroundSpikePoint.global_transform.origin = clawengageposition
			GroundSpikePoint.visible = true
			Tglobal.soundsystem.quicksound("ClawGripSound", clawengageposition)
	elif clawengageposition != null:
		endclawengagement()

func _on_questhandtracking_button_pressed(p_button):
	if Tglobal.controlslocked:
		print("Controls locked")	
	elif p_button == BUTTONS.HT_PINCH_MIDDLE_FINGER:
		playerdirectedflight = true
				
func _on_questhandtracking_button_release(p_button):
	if Tglobal.controlslocked:
		print("Controls locked")	
	if p_button == BUTTONS.HT_PINCH_MIDDLE_FINGER:
		playerdirectedflight = false

func _on_button_pressed(p_button):
	if p_button == BUTTONS.VR_PAD:
		var joypos = HandLeft.joypos
		if abs(joypos.y) < 0.5 and abs(joypos.x) > 0.1:
			nextphysicsrotatestep += (1 if joypos.x > 0 else -1)*(22.5 if abs(joypos.x) > 0.8 else 90.0)

	if p_button == BUTTONS.VR_GRIP:
		playerdirectedflight = true

		
func _on_button_release(p_button):
	if p_button == BUTTONS.VR_BUTTON_BY:
		pass
	if p_button == BUTTONS.VR_GRIP:
		playerdirectedflight = false

var laserangleadjustmode = false
var laserangleoriginal = 0
var laserhandanglevector = Vector2(0,0)
var prevlaserangleoffset = 0


func DMakeNewBoulder(event):
	#if event is InputEventKey and event.pressed and event.is_action_pressed("newboulder"):
	print("making new boulder")
	var HandRight = playerMe.get_node("HandRight")
	var markernode = preload("res://nodescenes/MarkerNode.tscn").instance()
	var boulderclutter = get_node("/root/Spatial/BoulderClutter")
	var nc = boulderclutter.get_child_count()
	markernode.get_node("CollisionShape").scale = Vector3(0.4, 0.6, 0.4) if ((nc%2) == 0) else Vector3(0.2, 0.4, 0.2)
	markernode.global_transform.origin = HandRight.global_transform.origin - 0.9*HandRight.global_transform.basis.z
	markernode.linear_velocity = -5.1*HandRight.global_transform.basis.z
	boulderclutter.add_child(markernode)
