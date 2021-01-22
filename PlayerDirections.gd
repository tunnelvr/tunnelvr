extends Node

onready var playerMe = get_node("/root/Spatial/Players/PlayerMe")
onready var HeadCam = playerMe.get_node("HeadCam")
onready var HandLeft = playerMe.get_node("HandLeft")
onready var HandLeftController = playerMe.get_node("HandLeftController")

var flyspeed = 5.0
var walkspeed = 3.0
var nextphysicsrotatestep = 0.0
var nextphysicssetposition = null
var playerdirectedflight = false
var playerdirectedflightvelocity = Vector3(0,0,0)
var playerdirectedwalkingvelocity = Vector3(0,0,0)
var flywalkreversed = false
var forceontogroundtimedown = 0
var floorprojectdistance = 10

const playeraudiencedistance = 5.0
const playeraudiencesidedisplacement = 4.0
const playerspawnoffsetheight = 3.0

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



var joyposxrotsnaphysteresis = 0 
func _physics_process(delta):
	playerdirectedflight = ((HandLeft.gripbuttonheld or Input.is_action_pressed("lh_ctrl")) != flywalkreversed) or \
							(playerMe.playerscale != 1.0)
	playerdirectedflightvelocity = Vector3(0,0,0)
	playerdirectedwalkingvelocity = Vector3(0,0,0)

	var joypos = HandLeft.joypos
	if not Input.is_action_pressed("lh_shift"):
		if Input.is_action_pressed("lh_forward"):   joypos.y += 1
		if Input.is_action_pressed("lh_backward"):  joypos.y += -1
		if Input.is_action_pressed("lh_left"):      joypos.x += -1
		if Input.is_action_pressed("lh_right"):     joypos.x += 1

	if not Tglobal.questhandtrackingactive and not Tglobal.controlslocked:
		if abs(joypos.x) < 0.4 and joyposxrotsnaphysteresis != 2:
			joyposxrotsnaphysteresis = 0
		elif joyposxrotsnaphysteresis == 0:
			if abs(joypos.x) > 0.9:
				joyposxrotsnaphysteresis = (1 if joypos.x > 0 else -1)
				nextphysicsrotatestep += joyposxrotsnaphysteresis*22.5

	if HandLeft.triggerbuttonheld and HandLeft.pointervalid and not Tglobal.controlslocked:
		var vec = -(playerMe.global_transform*HandLeft.pointerposearvrorigin).basis.z
		if playerdirectedflight:
			var flyacceleration = lerp(1.0, 5.0, (joypos.y-0.7)/0.3) if joypos.y>0.8 else 1.0
			playerdirectedflightvelocity = vec.normalized()*flyspeed*flyacceleration*playerMe.playerflyscale
		else:
			playerdirectedwalkingvelocity = Vector3(vec.x, 0, vec.z).normalized()*walkspeed
			var vang = rad2deg(Vector2(Vector2(vec.x, vec.z).length(), vec.y).angle())
			if vang > 45:
				#playerdirectedwalkingvelocity = -playerdirectedwalkingvelocity
				playerdirectedwalkingvelocity = Vector3(HeadCam.global_transform.basis.z.x, 0, HeadCam.global_transform.basis.z.z).normalized()*walkspeed

	elif not Tglobal.questhandtrackingactive and not Tglobal.controlslocked and abs(joypos.y) > 0.2:
		if playerdirectedflight: 
			playerdirectedflightvelocity = HeadCam.global_transform.basis.z*(-joypos.y*flyspeed)*playerMe.playerscale
		else:
			var dir = Vector3(HeadCam.global_transform.basis.z.x, 0, HeadCam.global_transform.basis.z.z)
			playerdirectedwalkingvelocity = dir.normalized()*(-joypos.y*walkspeed)
			
func _on_button_pressed(p_button):
	if p_button == BUTTONS.VR_PAD:
		var joypos = HandLeft.joypos
		if abs(joypos.y) < 0.5 and abs(joypos.x) > 0.1:
			nextphysicsrotatestep += (1 if joypos.x > 0 else -1)*(22.5 if abs(joypos.x) > 0.8 else 90.0)
			joyposxrotsnaphysteresis = 2

var laserangleadjustmode = false
var laserangleoriginal = 0
var laserhandanglevector = Vector2(0,0)
var prevlaserangleoffset = 0
