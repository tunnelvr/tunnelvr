extends ARVROrigin

var doppelganger = null 

var networkID = 0
var playerplatform = ""
onready var playertunnelvrversion = Tglobal.tunnelvrversion
var guardianpoly = null
var executingfeaturesavailable = [ ]
var playerscale = 1.0
var playerflyscale = 1.0
var playerwalkscale = 1.0

var bouncetestnetworkID = 0
onready var LaserOrient = get_node("/root/Spatial/BodyObjects/LaserOrient")
onready var LaserSelectLine = get_node("/root/Spatial/BodyObjects/LaserSelectLine")
onready var PlanViewSystem = get_node("/root/Spatial/PlanViewSystem")
var ovr_hand_tracking = null
var ovr_guardian_system = null
onready var guipanel3d = get_node("/root/Spatial/GuiSystem/GUIPanel3D")

func _ready():
	setheadtorchlight(guipanel3d.get_node("Viewport/GUI/Panel/ButtonHeadtorch").pressed)

func initplayerappearance_me():
	var d = hash(String(OS.get_unix_time())+"abc")
	var headcolour = Color.from_hsv((d%10000)/10000.0, 0.5 + (d%2222)/6666.0, 0.75)
	if playerplatform == "Server":
		headcolour = Color(0.01, 0.01, 0.05)
	print("Head colour ", headcolour, " ", [OS.get_unique_id()])
	var mat = get_node("HeadCam/csgheadmesh/skullcomponent").material
	mat.albedo_color = headcolour
	print(mat.albedo_color)
	if ovr_guardian_system != null:
		guardianpoly = ovr_guardian_system.get_boundary_geometry()
	else:
		guardianpoly = PoolVector3Array([Vector3(1,0,1), Vector3(1,0,-1), Vector3(-1,0,-1), Vector3(-1,0,1)])
	if guardianpoly != null:
		get_node("GuardianPoly/floorareamesh").mesh = Polynets.triangulatepolygon(guardianpoly)
		get_node("GuardianPoly/floorareamesh").set_surface_material(0, get_node("/root/Spatial/MaterialSystem").xcdrawingmaterial("guardianpoly"))
		get_node("GuardianPoly/floorareamesh").visible = true
	executingfeaturesavailable = get_node("/root/Spatial/ExecutingFeatures").executingfeaturesavailable()
	
func setheadtorchlight(torchon):
	if torchon:
		$HeadCam/HeadtorchLight.visible = true
		get_node("/root/Spatial/WorldEnvironment").environment = preload("res://environments/underground_env.tres")
		# waiting for godot 4  https://github.com/godotengine/godot/issues/19438
		#get_node("/root/Spatial").playerMe.get_node("HeadCam").cull_mask &= 1048575 - 4096
		get_node("/root/Spatial/WorldEnvironment/DirectionalLight").visible = false
		get_node("/root/Spatial/MaterialSystem").adjustmaterialtotorchlight(true)
	else:
		$HeadCam/HeadtorchLight.visible = false
		get_node("/root/Spatial/WorldEnvironment").environment = preload("res://environments/default_env.tres")
		#get_node("/root/Spatial").playerMe.get_node("HeadCam").cull_mask |= 4096
		get_node("/root/Spatial/WorldEnvironment/DirectionalLight").visible = true
		get_node("/root/Spatial/MaterialSystem").adjustmaterialtotorchlight(false)
	#var dl = get_node_or_null("/root/Spatial/WorldEnvironment/DirectionalLight2")
	#if dl != null:
	#	dl.shadow_enabled = not torchon
	get_node("/root/Spatial/SoundSystem").quicksound("ClickSound", $HeadCam.global_transform.origin + $HeadCam.global_transform.basis.y * 0.2)
	if Tglobal.connectiontoserveractive:
		rpc("puppetsetheadtorchlight", torchon)
	if is_instance_valid(doppelganger):
		doppelganger.puppetsetheadtorchlight(torchon)

func seteyestate(eyesopen):
	if Tglobal.connectiontoserveractive:
		rpc("puppeteyestate", eyesopen)
	if is_instance_valid(doppelganger):
		doppelganger.puppeteyestate(eyesopen)
	$HeadCam/csgheadmesh/righteye.visible = eyesopen
	$HeadCam/csgheadmesh/lefteye.visible = eyesopen

func setdoppelganger(doppelgangeron):
	if doppelgangeron:
		if doppelganger == null:
			doppelganger = load("res://nodescenes/PlayerPuppet.tscn").instance()
			doppelganger.set_name("Doppelganger")
			doppelganger.get_node("HeadCam/csgheadmesh/skullcomponent").material.albedo_color = get_node("HeadCam/csgheadmesh/skullcomponent").material.albedo_color
			get_parent().add_child(doppelganger)
			doppelganger.initplayerappearanceJ(playerappearancedict())
			doppelganger.networkID = -10
			
		doppelganger.visible = true
		doppelganger.global_transform.origin = $HeadCam.global_transform.origin - 3*Vector3($HeadCam.global_transform.basis.z.x, 0, $HeadCam.global_transform.basis.z.z).normalized()
		Tglobal.soundsystem.quicksound("PlayerArrive", doppelganger.global_transform.origin)
		
	elif not doppelgangeron and doppelganger != null:
		Tglobal.soundsystem.quicksound("PlayerDepart", doppelganger.global_transform.origin)
		doppelganger.queue_free()
		doppelganger = null	
	get_node("/root/Spatial/GuiSystem/GUIPanel3D").updateplayerlist()
	

var handflickdistancestack = [ ]
const handflickdistancestack_sizemax = 4
const handflickvelocitylimit = 1.5
const handflicktimerlimit = 0.05
const handflickvelsumlimit = 0.013
var handflickmotiontransit = 0
var handflickmotiontimer = 0.0
var handflickfacesum = 0.0
var handflickvelsum = 0.0
var handflickmotiongesture = 0

func _physics_process(delta):
	$HandLeft.middleringbutton.get_node("MeshInstance").get_surface_material(0).emission_energy = 1 if $HandLeft/RayCast.is_colliding() else 0
	$HandRight.middleringbutton.get_node("MeshInstance").get_surface_material(0).emission_energy = 1 if $HandRight/RayCast.is_colliding() else 0

	var handflickface = 0.0
	if $HandRight.handstate:
		var handprojectionpoint = $HandRight.global_transform.origin + $HandRight.global_transform.basis.x*(-0.2)
		var handflickpos = handprojectionpoint - $HeadCam.global_transform.origin
		if len(handflickdistancestack) >= handflickdistancestack_sizemax:
			handflickdistancestack.pop_front()
		handflickdistancestack.push_back(handflickpos.length())
		handflickface = handflickpos.dot($HandRight/HandFlickFaceY.global_transform.basis.y)
	else:
		handflickdistancestack.clear()
		handflickmotiontransit = 0
	if len(handflickdistancestack) == handflickdistancestack_sizemax:
		var handflickvel = (handflickdistancestack[0] - handflickdistancestack[handflickdistancestack_sizemax-1])/(delta*handflickdistancestack_sizemax)
		if abs(handflickvel) > handflickvelocitylimit:
			#print("v ", handflickvel, " ", handflickmotiontimer+delta, " ", handflickface)
			var lhandflickmotiontransit = (1 if handflickvel > 0 else -1)
			if handflickmotiontransit == lhandflickmotiontransit:
				handflickmotiontimer += delta
				handflickfacesum += handflickface*delta
				handflickvelsum = handflickvel*delta

			else:
				handflickmotiontimer = 0.0
				handflickmotiontransit = lhandflickmotiontransit
				handflickfacesum = 0.0
				handflickvelsum = 0.0

		elif handflickmotiontransit != 0:
			if handflickmotiontimer > handflicktimerlimit and handflickfacesum > 0.0 and abs(handflickvelsum) > handflickvelsumlimit:
				handflickmotiongesture = handflickmotiontransit
				print("handflickgesture ", handflickmotiongesture, " ", handflickfacesum, "  ", handflickvelsum)
			else:
				print("handflick f gesture ", handflickmotiontimer, " ", handflickfacesum, "  ", handflickvelsum)

			handflickdistancestack.clear()
			handflickmotiontransit = 0


remote func setavatarposition(positiondict):
	print("ppt nope not master ", positiondict)

remote func puppetenablegripmenus(gmlist, gmtransform):
	print("puppetenablegripmenus nope not master ", gmlist)

remote func puppetenableguipanel(guitransform):
	print("puppetenableguipanel nope not master ", guitransform)

remote func puppetsetheadtorchlight(torchon):
	print("puppetsetheadtorchlight nope not master ", torchon)

remote func puppeteyestate(eyesopen):
	print("puppeteyestate nope not master ", eyesopen)


puppet func bouncedoppelgangerposition(bouncebackID, positiondict):
	rpc_unreliable_id(bouncebackID, "setdoppelgangerposition", positiondict)

func swapcontrollers():
	if not Tglobal.questhandtracking:
		var cidl = $HandLeftController.controller_id
		var cidr = $HandRightController.controller_id
		$HandLeftController.controller_id = cidr
		$HandRightController.controller_id = cidl
		$HandLeft.controller_id = cidr
		$HandRight.controller_id = cidl

remotesync func playvoicerecording(wavrecording):
	print("playing recording ", wavrecording.size()) 
	var stream = AudioStreamSample.new()
	stream.format = AudioStreamSample.FORMAT_16_BITS
	stream.data = wavrecording
	stream.mix_rate = 44100
	stream.stereo = true
	$HandRight/AudioStreamPlayer3D.stream = stream
	$HandRight/AudioStreamPlayer3D.play()

func laserpointerdict():
	var ldict = { "orient":$HandRight.pointerposearvrorigin, 
				  "length": LaserOrient.get_node("Length").scale.z, 
				  "spotvisible": LaserOrient.get_node("LaserSpot").visible }
	if LaserSelectLine.visible:
		ldict["laserselectline"] = { "global_transform":LaserSelectLine.global_transform, 
									 "scalez":LaserSelectLine.get_node("Scale").scale.z }
	if PlanViewSystem.planviewactive and PlanViewSystem.get_node("RealPlanCamera/LaserScope").visible:
		ldict["planviewlaser"] = { "global_transform":PlanViewSystem.get_node("RealPlanCamera/LaserScope/LaserOrient").global_transform, 
								   "length":PlanViewSystem.get_node("RealPlanCamera/LaserScope/LaserOrient/Length").scale.z }
	return ldict

var footstepcount = 0
func puppetbodydict():
	return { "playertransform":transform, 
			 "headcamtransform":$HeadCam.transform, 
			 "footstepcount":footstepcount }

func playerpositiondict():
	var t0 = OS.get_ticks_msec()*0.001
	return { "timestamp": t0, 
			 "playerscale":playerscale,
			 "puppetbody": puppetbodydict(),
			 "handleft": $HandLeft.handpositiondict(t0), 
			 "handright": $HandRight.handpositiondict(t0), 
			 "laserpointer": laserpointerdict()
		   }

func playerappearancedict():
	return { "playerplatform":playerplatform, 
			 "playerheadcolour":get_node("HeadCam/csgheadmesh/skullcomponent").material.albedo_color, 
			 "torchon":get_node("HeadCam/HeadtorchLight").visible, 
			 "guardianpoly":guardianpoly, 
			 "executingfeaturesavailable":executingfeaturesavailable,
			 "tunnelvrversion":Tglobal.tunnelvrversion,
			 "cavesfilelist":guipanel3d.cavesfilelist()
			}


var Dleftquesthandcontrollername = "unknown"
var Drightquesthandcontrollername = "unknown"
var key_9toggle = false
func _process(delta):
	if Tglobal.questhandtracking:
		var rightquesthandcontrollername = $HandRightController.get_controller_name()
		if rightquesthandcontrollername != Drightquesthandcontrollername:
			print("Controller change: ", rightquesthandcontrollername)
			Drightquesthandcontrollername = rightquesthandcontrollername
		var leftquesthandcontrollername = $HandLeftController.get_controller_name()
		if leftquesthandcontrollername != Dleftquesthandcontrollername:
			print("Controller change: ", leftquesthandcontrollername)
			Dleftquesthandcontrollername = leftquesthandcontrollername

		if rightquesthandcontrollername == "Oculus Tracked Right Hand":
			if $HandRight.handstate == 2:
				$HandRight.handstate = 0
			$HandRight.process_ovrhandtracking(delta)
			Tglobal.questhandtrackingactive = true
		else:
			$HandRight.handstate = 2
			$HandRight.process_normalvrtracking(delta)
			Tglobal.questhandtrackingactive = false
			
		if leftquesthandcontrollername == "Oculus Tracked Left Hand":
			if $HandLeft.handstate == 2:
				$HandLeft.handstate = 0
			$HandLeft.process_ovrhandtracking(delta)
		else:
			$HandLeft.handstate = 2
			$HandLeft.process_normalvrtracking(delta)

	elif Tglobal.VRoperating:
		$HandLeft.process_normalvrtracking(delta)
		$HandRight.process_normalvrtracking(delta)
		
	else:
		var hx = 0
		if Input.is_action_pressed("lh_shift"):
			var lhkeyvec = Vector2(0, 0)
			if Input.is_action_pressed("lh_forward"):   lhkeyvec.y += 1
			if Input.is_action_pressed("lh_backward"):  lhkeyvec.y += -1
			if Input.is_action_pressed("lh_left"):      lhkeyvec.x += -1
			if Input.is_action_pressed("lh_right"):     lhkeyvec.x += 1
			hx = lhkeyvec.x
			lhkeyvec.x = 0
			#var vtarget = -$HeadCam.global_transform.basis.z*20 + $HeadCam.global_transform.basis.x*lhkeyvec.x*15*delta + Vector3(0, lhkeyvec.y, 0)*15*delta
			#$HeadCam.look_at($HeadCam.global_transform.origin + vtarget, Vector3(0,1,0))
			#rotation_degrees.y += $HeadCam.rotation_degrees.y
			#$HeadCam.rotation_degrees.y = 0
			$HeadCam.rotation_degrees.x = clamp($HeadCam.rotation_degrees.x + 90*delta*lhkeyvec.y, -89, 89)

			var duckrise = 0
			if Input.is_action_pressed("lh_duck"):  duckrise += -1
			if Input.is_action_pressed("lh_rise"):  duckrise += 1
			$HeadCam.translation.y = clamp($HeadCam.translation.y + duckrise*delta*1.1, 0.4, 1.8)

		if Input.is_action_just_pressed("ui_key_9"):
			$HandRight.handstate = 2 if ($HandRight.handstate == 1) else 1
		if $HandRight.handstate == 0:
			$HandRight.handstate = 1
		$HandRight.process_keyboardcontroltracking($HeadCam, Vector2(hx*0.033, 0), playerscale)

	if $HandRight.pointervalid:
		LaserOrient.transform = global_transform*$HandRight.pointerposearvrorigin
	else:
		LaserOrient.visible = false



func initkeyboardcontroltrackingnow():
	#$HandLeft.initkeyboardtracking()
	$HandRight.initkeyboardtracking()
	
func initnormalvrtrackingnow():
	$HandLeft.initnormalvrtracking($HandLeftController)
	$HandRight.initnormalvrtracking($HandRightController)

func initquesthandtrackingnow(lovr_hand_tracking):
	Tglobal.questhandtracking = true
	$HeadCam/HeadtorchLight.shadow_enabled = false

	ovr_hand_tracking = lovr_hand_tracking
	$HandLeft.initovrhandtracking(ovr_hand_tracking, $HandLeftController)
	$HandRight.initovrhandtracking(ovr_hand_tracking, $HandRightController)
	#get_node("/root/Spatial/GuiSystem/GUIPanel3D/Viewport/GUI/Panel/ButtonSwapControllers").disabled = true

