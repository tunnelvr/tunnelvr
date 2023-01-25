extends Node

onready var selfSpatial = get_node("/root/Spatial")
onready var playerMe = get_node("/root/Spatial/Players/PlayerMe")
onready var HeadCam = playerMe.get_node("HeadCam")
onready var HandLeft = playerMe.get_node("HandLeft")
onready var HandRight = playerMe.get_node("HandRight")
onready var HandLeftController = playerMe.get_node("HandLeftController")
onready var planviewsystem = get_node("/root/Spatial/PlanViewSystem")

var flyspeed = 5.0
var walkspeed = 3.0
var nextphysicsrotatestep = 0.0
var nextphysicssetposition = null
var playerdirectedflight = false
var playerdirectedflightvelocity = Vector3(0,0,0)
var playerdirectedwalkingvelocity = Vector3(0,0,0)

var colocatedplayer = null
var colocatedflagtrail = null

var forceontogroundtimedown = 0
var floorprojectdistance = 10

const playeraudiencedistance = 3.0
const playeraudiencesidedisplacement = 2.0
const playerspawnoffsetheight = 1.5

var joyposxrotsnaphysteresis = 0
var forebackmovementjoystick = DRAWING_TYPE.JOYPOS_LEFTCONTROLLER
var strafemovementjoystick = DRAWING_TYPE.JOYPOS_LEFTCONTROLLER
var snapturnemovementjoystick = DRAWING_TYPE.JOYPOS_RIGHTCONTROLLER

func setasaudienceofpuppet(puppetheadtrans, lforceontogroundtimedown):
	var puppetheadpos = puppetheadtrans.origin
	var veceyes = Vector3(puppetheadtrans.basis.z.x, 0, puppetheadtrans.basis.z.z).normalized()
	var vecperp = Vector3(veceyes.z, 0, -veceyes.x)
	var cenpos = puppetheadtrans.origin - veceyes*(playeraudiencedistance*0.5)*playerMe.playerscale
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
			joypossnapturn = HandRight.joypos.x*(2.0 if HandRight.vrpadbuttonheld else 0.2)
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

	if Tglobal.phonethumbmotionposition != null:
		joyposforeback += -Tglobal.phonethumbmotionposition.y*1.5
		joyposstrafe += Tglobal.phonethumbmotionposition.x*1.5

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
		var housahedronslowerfactor = 1.0 # 0.5
		if playerdirectedflight: 
			playerdirectedflightvelocity = (-HeadCam.global_transform.basis.z*joyposforeback + HeadCam.global_transform.basis.x*joyposstrafe)*flyspeed*playerMe.playerscale*housahedronslowerfactor
		else:
			var dir = Vector3(HeadCam.global_transform.basis.z.x, 0, HeadCam.global_transform.basis.z.z).normalized()
			var perpdir = Vector3(dir.z, 0, -dir.x)
			playerdirectedwalkingvelocity = (-dir*joyposforeback + perpdir*joyposstrafe)*walkspeed*playerMe.playerwalkscale*housahedronslowerfactor
			
func _on_button_pressed(p_button):
	var pointersystem = playerMe.get_node("pointersystem")
	if p_button == BUTTONS.VR_MENU and Tglobal.arvrinterfacename == "OpenXR":
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

func setcolocflagtrailatpos():
	var pt = playerMe.get_node("HeadCam").global_transform.origin
	var flagtrailpoints = colocatedflagtrail["flagtrailpoints"]
	var ftpindex = len(flagtrailpoints) - 2
	var ftplambda = 1.0
	var ftptrailpos = colocatedflagtrail["flagtraillength"]
	var Lftptrailpos = 0.0
	var distsq = (flagtrailpoints[-1] - pt).length_squared()
	for i in range(0, len(flagtrailpoints)-1):
		var pt0 = colocatedflagtrail["flagtrailpoints"][i]
		var pt1 = colocatedflagtrail["flagtrailpoints"][i+1]
		var v = pt1 - pt0
		var pv = pt - pt0
		var vlensq = v.length_squared()
		if vlensq != 0.0:
			var vlen = sqrt(vlensq)
			var lam = pv.dot(v)/vlensq
			if lam < 1.0:
				if lam <= 0.0:
					lam = 0.0
				var ldistsq = (pt0 + v*lam - pt).length_squared()
				if ldistsq < distsq:
					ftpindex = i
					ftplambda = lam
					ftptrailpos = Lftptrailpos + ftplambda*vlen
					distsq = ldistsq
			Lftptrailpos += vlen
	colocatedflagtrail["ftpindex"] = ftpindex
	colocatedflagtrail["ftplambda"] = ftplambda
	colocatedflagtrail["ftptrailpos"] = ftptrailpos
	suppresstrailposvaluechanged = true
	planviewsystem.planviewcontrols.get_node("PathFollow/HSliderTrailpos").value = 100*colocatedflagtrail["ftptrailpos"]/colocatedflagtrail["flagtraillength"]
	suppresstrailposvaluechanged = false
	return lerp(flagtrailpoints[ftpindex], flagtrailpoints[ftpindex+1], ftplambda)				
				
func advancecolocflagtrailatpos(dist):
	var flagtrailpoints = colocatedflagtrail["flagtrailpoints"]
	var ftpindex = colocatedflagtrail["ftpindex"]
	var ftplambda = colocatedflagtrail["ftplambda"]
	var ftptrailpos = colocatedflagtrail["ftptrailpos"]
	var pt = lerp(flagtrailpoints[ftpindex], flagtrailpoints[ftpindex+1], ftplambda)
	var ddist = abs(dist)
	var ddirfore = (dist >= 0.0)
	while true:
		if ddirfore:
			var ptend = flagtrailpoints[ftpindex+1]
			var disttoend = (ptend - pt).length()
			if ddist <= disttoend:
				if disttoend != 0.0:
					ftplambda += (ddist/disttoend)*(1.0 - ftplambda)
				else:
					ftplambda = 1.0
				ftptrailpos += ddist
				break
			ftplambda = 1.0
			ddist -= disttoend
			ftptrailpos += disttoend
			if ftpindex == len(flagtrailpoints) - 2:
				ftptrailpos = colocatedflagtrail["flagtraillength"]
				break
			ftpindex += 1
			ftplambda = 0.0
		else:
			var ptend = flagtrailpoints[ftpindex]
			var disttoend = (ptend - pt).length()
			if ddist <= disttoend:
				if disttoend != 0.0:
					ftplambda -= (ddist/disttoend)*(ftplambda)
				else:
					ftplambda = 0.0
				ftptrailpos -= ddist
				break
			ftplambda = 0.0
			ddist -= disttoend
			if ftpindex == 0:
				ftptrailpos = 0.0
				break
			ftpindex -= 1
			ftplambda = 1.0
	colocatedflagtrail["ftpindex"] = ftpindex
	colocatedflagtrail["ftplambda"] = ftplambda
	colocatedflagtrail["ftptrailpos"] = ftptrailpos
	return lerp(flagtrailpoints[ftpindex], flagtrailpoints[ftpindex+1], ftplambda)

const hslidertrailspeeddeadzone = 0.05
func advancablecolocflagtrail():
	if planviewsystem.planviewcontrols.get_node("PathFollow/Tracktrail").pressed:
		var hstval = planviewsystem.planviewcontrols.get_node("PathFollow/HSliderTrailspeed").value
		var val = hstval*0.01
		if abs(val) > hslidertrailspeeddeadzone:
			if val > 0.0:
				if colocatedflagtrail["ftpindex"] < len(colocatedflagtrail["flagtrailpoints"]) - 2 or colocatedflagtrail["ftplambda"] < 1.0:
					return true
				if planviewsystem.planviewcontrols.get_node("PathFollow/Trailbounce").pressed:
					planviewsystem.planviewcontrols.get_node("PathFollow/HSliderTrailspeed").value = -hstval
					return true
			else:
				if colocatedflagtrail["ftpindex"] > 0 or colocatedflagtrail["ftplambda"] > 0.0:
					return true
				if planviewsystem.planviewcontrols.get_node("PathFollow/Trailbounce").pressed:
					planviewsystem.planviewcontrols.get_node("PathFollow/HSliderTrailspeed").value = -hstval
					return true
	return false

var suppresstrailposvaluechanged = false
func advancecolocflagtrailatposF(fac):
	var hstval = planviewsystem.planviewcontrols.get_node("PathFollow/HSliderTrailspeed").value
	var val = hstval*0.01
	var newpos = advancecolocflagtrailatpos(val*fac)
	suppresstrailposvaluechanged = true
	planviewsystem.planviewcontrols.get_node("PathFollow/HSliderTrailpos").value = 100*colocatedflagtrail["ftptrailpos"]/colocatedflagtrail["flagtraillength"]
	suppresstrailposvaluechanged = false
	return newpos
	
func hslidertrailpos_valuechanged(value):
	if colocatedflagtrail != null and not suppresstrailposvaluechanged:
		var val = value/100.0*colocatedflagtrail["flagtraillength"]
		colocatedflagtrail["ftpindex"] = 0
		colocatedflagtrail["ftplambda"] = 0.0
		colocatedflagtrail["ftptrailpos"] = 0.0
		advancecolocflagtrailatpos(val)
