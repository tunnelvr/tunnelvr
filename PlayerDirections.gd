extends Node

onready var selfSpatial = get_node("/root/Spatial")
onready var playerMe = get_node("/root/Spatial/Players/PlayerMe")
onready var HeadCam = playerMe.get_node("HeadCam")
onready var HandLeft = playerMe.get_node("HandLeft")
onready var HandRight = playerMe.get_node("HandRight")
onready var HandLeftController = playerMe.get_node("HandLeftController")

var flyspeed = 5.0
var walkspeed = 3.0
var nextphysicsrotatestep = 0.0
var nextphysicssetposition = null
var playerdirectedflight = false
var playerdirectedflightvelocity = Vector3(0,0,0)
var playerdirectedwalkingvelocity = Vector3(0,0,0)

var forceontogroundtimedown = 0
var floorprojectdistance = 10

const playeraudiencedistance = 5.0
const playeraudiencesidedisplacement = 4.0
const playerspawnoffsetheight = 3.0

var joyposxrotsnaphysteresis = 0
var forebackmovementjoystick = DRAWING_TYPE.JOYPOS_LEFTCONTROLLER
var strafemovementjoystick = DRAWING_TYPE.JOYPOS_LEFTCONTROLLER
var snapturnemovementjoystick = DRAWING_TYPE.JOYPOS_RIGHTCONTROLLER

func setasaudienceofpuppet(playerpuppet, puppetheadtrans, lforceontogroundtimedown):
	var puppetheadpos = puppetheadtrans.origin
	var veceyes = Vector3(puppetheadtrans.basis.z.x, 0, puppetheadtrans.basis.z.z).normalized()
	var vecperp = Vector3(veceyes.z, 0, -veceyes.x)
	var cenpos = puppetheadtrans.origin - veceyes*(playeraudiencedistance*0.5)*playerpuppet.playerscale
	var playerlam = (playerMe.networkID%10000)/10000.0
	var playerheadbasis = puppetheadtrans.basis.rotated(Vector3(0,1,0), deg2rad(180))
	print("playerheadbasisplayerheadbasis ", playerheadbasis.determinant())
	var playerheadpos = cenpos - veceyes*(playeraudiencedistance*0.5)*playerMe.playerscale + \
								 vecperp*(playerlam-0.5)*2*playeraudiencesidedisplacement
	#  Solve: headtrans = playerMe.global_transform * playerMe.get_node("HeadCam").transform 
	var backrelorigintrans = Transform(playerheadbasis, playerheadpos) * playerMe.get_node("HeadCam").transform.inverse()
	var viewtopuppetvec = playerheadpos - puppetheadpos
	var relang = Vector2(viewtopuppetvec.x, viewtopuppetvec.z).angle_to(Vector2(playerMe.global_transform.basis.z.x, playerMe.global_transform.basis.z.z))
	#var angvec = Vector2(playerMe.global_transform.basis.x.dot(backrelorigintrans.basis.x), playerMe.global_transform.basis.z.dot(backrelorigintrans.basis.x))
	nextphysicsrotatestep = -rad2deg(relang)
	nextphysicssetposition = backrelorigintrans.origin + Vector3(0, playerspawnoffsetheight, 0)
	forceontogroundtimedown = lforceontogroundtimedown
	floorprojectdistance = playerspawnoffsetheight*2

func setatheadtrans(headtrans, lforceontogroundtimedown):
	#  Solve: headtrans = playerMe.global_transform * playerMe.get_node("HeadCam").transform 
	var backrelorigintrans = headtrans * playerMe.get_node("HeadCam").transform.inverse()
	var viewtopuppetvec = headtrans.basis.z
	var relang = Vector2(viewtopuppetvec.x, viewtopuppetvec.z).angle_to(Vector2(playerMe.global_transform.basis.z.x, playerMe.global_transform.basis.z.z))
	#var angvec = Vector2(playerMe.global_transform.basis.x.dot(backrelorigintrans.basis.x), playerMe.global_transform.basis.z.dot(backrelorigintrans.basis.x))
	nextphysicsrotatestep = -rad2deg(relang)
	nextphysicssetposition = backrelorigintrans.origin + Vector3(0, playerspawnoffsetheight, 0)
	forceontogroundtimedown = lforceontogroundtimedown

func initcontrollersignalconnections():
	HandLeftController.connect("button_pressed", self, "_on_button_pressed")
	HandLeftController.connect("button_release", self, "_on_button_release")

func initquesthandcontrollersignalconnections():
	pass

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
	playerdirectedflight = ((HandLeft.gripbuttonheld or Input.is_action_pressed("lh_ctrl"))) or playerMe.playerghostphysics
	playerdirectedflightvelocity = Vector3(0,0,0)
	playerdirectedwalkingvelocity = Vector3(0,0,0)

	var joyposforeback = 0.0
	var joyposstrafe = 0.0
	var joypossnapturn = 0.0
	if forebackmovementjoystick != DRAWING_TYPE.JOYPOS_DISABLED:
		joyposforeback = HandLeft.joypos.y if forebackmovementjoystick == DRAWING_TYPE.JOYPOS_LEFTCONTROLLER else HandRight.joypos.y
	if strafemovementjoystick != DRAWING_TYPE.JOYPOS_DISABLED:
		joyposstrafe = HandLeft.joypos.x if forebackmovementjoystick == DRAWING_TYPE.JOYPOS_LEFTCONTROLLER else HandRight.joypos.x
	if snapturnemovementjoystick != DRAWING_TYPE.JOYPOS_DISABLED:
		if snapturnemovementjoystick == DRAWING_TYPE.JOYPOS_RIGHTCONTROLLER_PADDOWN:
			joypossnapturn = HandRight.joypos.x*(2 if HandRight.vrpadbuttonheld else 0.2)
		else:
			joypossnapturn = HandLeft.joypos.x if snapturnemovementjoystick == DRAWING_TYPE.JOYPOS_LEFTCONTROLLER else HandRight.joypos.x

	if not Tglobal.virtualkeyboardactive:
		if not Input.is_action_pressed("lh_shift"):
			if Input.is_action_pressed("lh_forward"):   joyposforeback += 1
			if Input.is_action_pressed("lh_backward"):  joyposforeback += -1
			if Input.is_action_pressed("lh_left"):      joyposstrafe += -1
			if Input.is_action_pressed("lh_right"):     joyposstrafe += 1
		elif snapturnemovementjoystick != DRAWING_TYPE.JOYPOS_DISABLED:
			if Input.is_action_pressed("lh_left"):      joypossnapturn += -1
			if Input.is_action_pressed("lh_right"):     joypossnapturn += 1


	if not Tglobal.questhandtrackingactive and not Tglobal.controlslocked:
		if abs(joypossnapturn) < 0.4 and joyposxrotsnaphysteresis != 2:
			joyposxrotsnaphysteresis = 0
		elif joyposxrotsnaphysteresis == 0:
			if abs(joypossnapturn) > 0.9:
				joyposxrotsnaphysteresis = (1 if joypossnapturn > 0 else -1)
				nextphysicsrotatestep += joyposxrotsnaphysteresis*22.5

	if HandLeft.triggerbuttonheld and HandLeft.pointervalid and not Tglobal.controlslocked:
		var vec = -(playerMe.global_transform*HandLeft.pointerposearvrorigin).basis.z
		if playerdirectedflight:
			var flyacceleration = lerp(1.0, 5.0, (joyposforeback-0.7)/0.3) if joyposforeback>0.8 else 1.0
			playerdirectedflightvelocity = vec.normalized()*flyspeed*flyacceleration*playerMe.playerflyscale
		else:
			playerdirectedwalkingvelocity = Vector3(vec.x, 0, vec.z).normalized()*walkspeed*playerMe.playerwalkscale
			var vang = rad2deg(Vector2(Vector2(vec.x, vec.z).length(), vec.y).angle())
			if vang > 45:
				#playerdirectedwalkingvelocity = -playerdirectedwalkingvelocity
				playerdirectedwalkingvelocity = Vector3(HeadCam.global_transform.basis.z.x, 0, HeadCam.global_transform.basis.z.z).normalized()*walkspeed*playerMe.playerwalkscale

	elif not Tglobal.questhandtrackingactive and not Tglobal.controlslocked and (abs(joyposforeback) > 0.2 or abs(joyposstrafe) > 0.2):
		if playerdirectedflight: 
			playerdirectedflightvelocity = (-HeadCam.global_transform.basis.z*joyposforeback + HeadCam.global_transform.basis.x*joyposstrafe)*flyspeed*playerMe.playerscale
		else:
			var dir = Vector3(HeadCam.global_transform.basis.z.x, 0, HeadCam.global_transform.basis.z.z).normalized()
			var perpdir = Vector3(dir.z, 0, -dir.x)
			playerdirectedwalkingvelocity = (-dir*joyposforeback + perpdir*joyposstrafe)*walkspeed*playerMe.playerwalkscale
			
func _on_button_pressed(p_button):
	var pointersystem = playerMe.get_node("pointersystem")
	if p_button == BUTTONS.VR_MENU and Tglobal.arvrinterfacename == "OVRMobile":
		pointersystem.buttonpressed_vrby()

	elif p_button == BUTTONS.VR_PAD:
		var joypos = HandLeft.joypos
		if abs(joypos.y) < 0.5 and abs(joypos.x) > 0.1:
			nextphysicsrotatestep += (1 if joypos.x > 0 else -1)*(22.5 if abs(joypos.x) > 0.8 else 90.0)
			#if Tglobal.arvrinterfacename != "OVRMobile" and Tglobal.arvrinterfacename != "Oculus":
			#	print("clicked turn (touchpad type), disabling non-click snap rotate")
			#	joyposxrotsnaphysteresis = 2

	elif not Tglobal.questhandtrackingactive and p_button == BUTTONS.VR_BUTTON_BY:
		pointersystem.set_handflickmotiongestureposition(pointersystem.handflickmotiongestureposition_shortpos if Tglobal.handflickmotiongestureposition == pointersystem.handflickmotiongestureposition_normal else pointersystem.handflickmotiongestureposition_normal)
		
func _on_button_release(p_button):
	if p_button == BUTTONS.VR_BUTTON_BY:
		pass



var laserangleadjustmode = false
var laserangleoriginal = 0
var laserhandanglevector = Vector2(0,0)
var prevlaserangleoffset = 0
