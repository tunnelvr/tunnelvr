extends Spatial


# To run on nixos, go to directory, do nix develop, then cd .. then godot

# xcdfullsetvisibilitycollision to use CollisionLayers technology instead
# Treeview to show which are downloaded

# * godot docs.  assert returns null from the function it's in when you ignore it
# * check out HDR example https://godotengine.org/asset-library/asset/110

# * pointertargettypes should be an enum for itself

# https://developer.oculus.com/learn/hands-design-interactions/
# https://developer.oculus.com/learn/hands-design-ui/
# https://learn.unity.com/tutorial/unit-5-hand-presence-and-interaction?uv=2018.4&courseId=5d955b5dedbc2a319caab9a0#5d96924dedbc2a6236bc1191
# https://www.youtube.com/watch?v=gpQePH-Ffbw

# * VR leads@skydeas1 and @brainonsilicon in Leeds (can do a trip there)

# * Need to ask to improve the documentation on https://docs.godotengine.org/en/latest/classes/class_meshinstance.html#class-meshinstance-method-set-surface-material
# *   See also https://godotengine.org/qa/3488/how-to-generate-a-mesh-with-multiple-materials
# *   And explain how meshes can have their own materials, that are copied into material/0, and the material reappears if material/0 set to null
# * CSG mesh with multiple materials group should have material0, material1 etc

# use this to sniff out waiting for godot performances https://www.concordtheatricals.co.uk/p/7476/waiting-for-godot
	
# optimize for GPU running using renderdoc:  https://developer.oculus.com/documentation/unity/ts-renderdoc-capture/
# https://developer.oculus.com/blog/how-to-level-up-your-profiling-with-renderdoc-for-oculus/
# bottom left of renderdock select 1: replay context quest (not profiling mode)
# select program executable path tunnelvr, and launch.  (It records it, but needs the hardware to replay it and get the timings)
# make a capture, save it, then put quest into profiling mode and open capture with options to set fastest

# to work on
# waterlevel - more intermediate points
# waterlevel - track the dict between tubes and ropes in the system 
# waterlevel - delay operating it until tubes have all loaded (put in a later process operation)

# why does making one xc totally change the file so it can't be diffed?
# shared world; the laser of the other guy is now not visible
# planview stealing
# animation of moving the floor or planview to the new place.
# hide tubes should hide water and boulders as well
# make image system work in parallel with up to 4 images

# networking, keyboard operation, planview, 



var hostipnumber: String = ""
export var hostportnumber: int = 4546
export var udpserverdiscoveryport: int = 4547
export var potreeportnumber: int = 8000

export var enablevr: = true
export var forcephoneoverlay: = false
export var usewebsockets: = false

var ovr_hand_tracking = null
var ovr_guardian_system = null

var _openxr_configuration
var _openxr_enabled_extensions : Array

onready var playerMe = $Players/PlayerMe
onready var mqttsystem = null 

export var forceopenVR = false

func checkloadinterface(larvrinterfacename):
	var available_interfaces = ARVRServer.get_interfaces()
	for x in available_interfaces:
		if x["name"] == larvrinterfacename:
			Tglobal.arvrinterface = ARVRServer.find_interface(larvrinterfacename)
			if Tglobal.arvrinterface != null:
				Tglobal.arvrinterfacename = larvrinterfacename
				print("Found VR interface ", x)
				return true
	return false


func setnetworkidname(player, networkID):
	player.networkID = networkID
	player.set_network_master(networkID)
	player.set_name("NetworkedPlayer"+String(networkID))
	
func delayednetworkstart():
	yield(get_tree().create_timer(8.0), "timeout")
	$GuiSystem/GUIPanel3D/Viewport/GUI/Panel/Networkstate.selected = 2
	$GuiSystem/GUIPanel3D._on_networkstate_selected($GuiSystem/GUIPanel3D/Viewport/GUI/Panel/Networkstate.selected)

	
func _ready():
	print("  Available Interfaces are %s: " % str(ARVRServer.get_interfaces()));
	print("Initializing VR" if enablevr else "VR disabled");
	playerMe.playeroperatingsystem = OS.get_name()

	$PhoneOverlay.visible = false
	if OS.has_feature("Server"):
		print("On server mode, autostart server connection")
		call_deferred("delayednetworkstart")
		# export Linux/X11 runable, go into directory and run
		# ../../Godot_v3.2.3-stable_linux_server.64 --main-pack linuxserverversion.pck	
		# Using Ubuntu App on Windows to get the command line
		playerMe.playerplatform = "Server"

	elif OS.has_feature("HTML5"):
		playerMe.playerplatform = "HTML5"
		print("warning: untested HTML5 mode")
		

	elif OS.has_feature("Quest"):
		if not checkloadinterface("OpenXR"):
			push_error("Error: Quest device not able to find OpenXR interface")
		var openxr_config_res := load("res://addons/godot-openxr/config/OpenXRConfig.gdns")
		if not openxr_config_res:
			push_error("OpenXR: Unable to load OpenXRConfig.gdns")
		_openxr_configuration = openxr_config_res.new()
		_openxr_configuration.render_target_size_multiplier = 1.0

		if not Tglobal.arvrinterface.interface_is_initialized:
			print("OpenXR: Initializing interface")
			if not Tglobal.arvrinterface.initialize():
				push_error("OpenXR: Failed to initialize")
		print("OpenXR: System name: ", _openxr_configuration.get_system_name())
		#ARVRServer.connect("openxr_session_begun", self, "_on_openxr_session_begun")
		#ARVRServer.connect("openxr_visible_state", self, "_on_openxr_visible_state")
		#ARVRServer.connect("openxr_focused_state", self, "_on_openxr_focused_state")
		_openxr_enabled_extensions = _openxr_configuration.get_enabled_extensions()
		#if enable_passthrough and _openxr_is_passthrough_supported():
		#	enable_passthrough = _openxr_start_passthrough()
		get_viewport().arvr = true
		$PlanViewSystem.slowviewportframerateenabled = true
		playerMe.playerplatform = "Quest"

	elif OS.has_feature("Android"):
		playerMe.playerplatform = "AndroidPhone"
		playerMe.get_node("HeadCam/HeadtorchLight").shadow_enabled = false
		$PhoneOverlay.setupphoneoverlaysystem(true)
		print("Engine.target_fps ", Engine.target_fps)
		print("Engine.iterations_per_second ", Engine.iterations_per_second)
		Engine.target_fps = 30


	elif not forceopenVR and enablevr and checkloadinterface("Oculus"):
		print("  Found Oculus Interface.");
		if Tglobal.arvrinterface.initialize():
			get_viewport().arvr = true;
			Engine.target_fps = 80 # TODO: this is headset dependent (RiftS == 80)=> figure out how to get this info at runtime
			Engine.iterations_per_second = 80
			OS.vsync_enabled = false;
			print("  Success initializing Oculus Interface.");
			# C:/Users/henry/Appdata/Local/Android/Sdk/platform-tools/adb.exe logcat -s VrApi

			# also for installing when the android signing isn't working
			# jarsigner -verbose -sigalg SHA1withRSA -digestalg SHA1 -keystore .android\debug.keystore godot_oculus_quest_toolkit_demo_v0.4.2.apk androiddebugkey
			# c:\Users\Julian\AppData\Local\Android\Sdk\platform-tools\adb install godot_oculus_quest_toolkit_demo_v0.4.2.apk
			# "C:\Program Files\Android\Android Studio\jre\bin\keytool.exe" -printcert -jarfile godot_oculus_quest_toolkit_demo_v0.4.2.apk


		else:
			Tglobal.arvrinterface = null
		playerMe.playerplatform = "Rift"
				
	elif enablevr and checkloadinterface("OpenVR"):
		print("found openvr, initializing")
		if Tglobal.arvrinterface.initialize():
			var viewport = get_viewport()
			viewport.arvr = true
			print("tttt", viewport.hdr, " ", viewport.keep_3d_linear)
			#viewport.hdr = false
			viewport.keep_3d_linear = true
			Engine.target_fps = 90
			Engine.iterations_per_second = 90
			OS.vsync_enabled = false;
			print("  Success initializing OpenVR Interface.");
			playerMe.playerplatform = "Vive"
			get_node("/root/Spatial/BodyObjects/PlayerDirections").snapturnemovementjoystick = DRAWING_TYPE.JOYPOS_RIGHTCONTROLLER_PADDOWN
			
		else:
			Tglobal.arvrinterface = null
			Tglobal.arvrinterfacename = "none"
			playerMe.playerplatform = "PC"
					
	elif enablevr and false and checkloadinterface("Native mobile"):
		print("found nativemobile, initializing")
		if Tglobal.arvrinterface.initialize():
			var viewport = get_viewport()
			viewport.arvr = true
			viewport.render_target_v_flip = true # <---- for your upside down screens
			viewport.transparent_bg = true       # <--- For the AR
			Tglobal.arvrinterface.k1 = 0.2       # Lens distortion constants
			Tglobal.arvrinterface.k2 = 0.23

	else:
		playerMe.playerplatform = "PC"
		if forcephoneoverlay:
			print("Running phone overlay on PC")
			$PhoneOverlay.setupphoneoverlaysystem(false)

	$GuiSystem/GUIPanel3D.toplevelcalled_ready()
	$PlanViewSystem.transferintorealviewport()

	playerMe.initplayerappearance_me()
	$SketchSystem.pointersystem = playerMe.get_node("pointersystem")
	
	Tglobal.VRoperating = (Tglobal.arvrinterfacename != "none")
	if Tglobal.VRoperating:
		#$BodyObjects/Locomotion_WalkInPlace.initjogdetectionsystem(playerMe.get_node("HeadCam"))
		if Tglobal.arvrinterfacename == "OpenXR" and playerMe.playerplatform == "Quest":
			playerMe.initquesthandtrackingnow()
			$WorldEnvironment/DirectionalLight.shadow_enabled = false
			#$BodyObjects/PlayerDirections.initquesthandcontrollersignalconnections()
		else:
			playerMe.initnormalvrtrackingnow()
		$BodyObjects/PlayerDirections.initcontrollersignalconnections()
			
	else:
		print("*** VR not operating")
	Tglobal.primarycamera_instanceid = $Players/PlayerMe/HeadCam.get_instance_id() 
		
	print("*-*-*-*  requesting permissions: ", OS.request_permissions())
	# this relates to Android permissions: 	change_wifi_multicast_state, internet, 
	#										read_external_storage, write_external_storage, 
	#										capture_audio_output
	var perm = OS.get_granted_permissions()
	print("Granted permissions: ", perm)

	#if true:
	$SketchSystem.loadsketchsystemL("res://surveyscans/loneoak.res")

	playerMe.global_transform.origin.y += 5
	$GuiSystem/GUIPanel3D.updateplayerlist()
	get_node("/root").msaa = Viewport.MSAA_4X
	
	$BatFlutter/BatCentre/batflap/AnimationPlayer.playback_speed = 2.0
	$BatFlutter/BatCentre/batflap/AnimationPlayer.get_animation("ArmatureAction").loop = true
	$BatFlutter/BatCentre/batflap/AnimationPlayer.play("ArmatureAction")


func nextplayernetworkidinringskippingdoppelganger(deletedid):
	for _i in range($Players.get_child_count()):
		var nextringplayer = $Players.get_child((playerMe.get_index()+1)%$Players.get_child_count())
		if deletedid == 0 or nextringplayer.networkID != deletedid:
			if nextringplayer.networkID != 0:
				return nextringplayer.networkID
	return 0
	
# May need to use Windows Defender Firewall -> Inboard rules -> New Rule and ports
# Also there's another setting change to allow pings
# If there is judder, then it could be the realtime virus and threat protection settings.  https://forum.unity.com/threads/performance-problems-with-vive-and-vr-regular-vr-waitforgpu-spikes.521849/

var deferred_player_connected_list = [ ]
var players_connected_list = [ ]
func _player_connected(id):
	print("_player_connected ", id)
	if not Tglobal.connectiontoserveractive:
		print("deferring playerconnect to after _connected_to_server() call: ", id)
		deferred_player_connected_list.push_back(id)
		return
	playerMe.set_name("NetworkedPlayer"+String(playerMe.networkID))
	var playerothername = "NetworkedPlayer"+String(id)
	if not $Players.has_node(playerothername):
		print("instancing for ", playerothername)
		var playerOther = load("res://nodescenes/PlayerPuppet.tscn").instance()
		setnetworkidname(playerOther, id)
		print("setnetworkidname for ", playerothername)
		playerOther.visible = false
		$Players.add_child(playerOther)
		print("Added ", playerothername, " to $Players")
		
	#$GuiSystem/GUIPanel3D.updateplayerlist()
	playerMe.bouncetestnetworkID = nextplayernetworkidinringskippingdoppelganger(0)
	Tglobal.morethanoneplayer = $Players.get_child_count() >= 2
	print(" playerMe networkID ", playerMe.networkID, " ", get_tree().get_network_unique_id())
	assert(playerMe.networkID != 0)
	playerMe.rpc_id(id, "initplayerappearanceJ", playerMe.playerappearancedict())
	players_connected_list.push_back(id)
	$GuiSystem/GUIPanel3D/Viewport/GUI/Panel/Label.text = "player "+String(id)+" connected"

	if playerMe.networkID == 1:
		print("Converting sketchsystemtodict")
		var sketchdatadict = $SketchSystem.sketchsystemtodict(false)
		var GithubAPI = get_node("/root/Spatial/ImageSystem/GithubAPI")
		if GithubAPI.ghcurrentname == sketchdatadict["sketchname"]+".res":
			sketchdatadict["ghcurrentsha"] = GithubAPI.ghcurrentsha
			print("setting ghcurrentsha ", GithubAPI.ghcurrentsha)
		assert(playerMe.networkID != 0)
		print("Generating sketchdicttochunks")
		var xcdatachunks = $SketchSystem.sketchdicttochunks(sketchdatadict)
		print("Generated ", len(xcdatachunks), " chunks")
		for xcdatachunk in xcdatachunks:
			$SketchSystem.rpc_id(id, "actsketchchangeL", xcdatachunk)
			yield(get_tree().create_timer(0.2), "timeout")
		$SketchSystem.rpc_id(id, "actsketchchangeL", [{"planview":$PlanViewSystem.planviewtodict()}]) 
		var xcvizstates = { }
		for xcdrawing in $SketchSystem/XCdrawings.get_children():
			if xcdrawing.drawingtype == DRAWING_TYPE.DT_XCDRAWING and xcdrawing.drawingvisiblecode != DRAWING_TYPE.VIZ_XCD_HIDE:
				xcvizstates[xcdrawing.get_name()] = xcdrawing.drawingvisiblecode
		if xcvizstates:
			print("sending out vizstates ", xcvizstates)
			$SketchSystem.rpc_id(id, "actsketchchangeL", [{"prevxcvizstates":{}, "xcvizstates":xcvizstates}])
	# {dukest1resurvey2009,12s0:2, s12009211:2}

func _player_disconnected(id):
	print("_player_disconnected ", id)
	if id in deferred_player_connected_list:
		print(" _player_disconnected id still in  deferred_player_connected_list")
		deferred_player_connected_list.erase(id)
		return
	assert (id in players_connected_list)
	players_connected_list.erase(id)
	var playerothername = "NetworkedPlayer"+String(id)
	Tglobal.morethanoneplayer = $Players.get_child_count() >= 2
	var playerOther = $Players.get_node_or_null(playerothername)
	if playerOther != null:
		Tglobal.soundsystem.quicksound("PlayerDepart", playerOther.get_node("HeadCam").global_transform.origin)
		print("Removing ", playerothername, " from $Players: ", playerOther.playerhumanname)
		playerOther.queue_free()
	yield(get_tree(), "idle_frame")
	$GuiSystem/GUIPanel3D.updateplayerlist()
	playerMe.bouncetestnetworkID = nextplayernetworkidinringskippingdoppelganger(id)
	$GuiSystem/GUIPanel3D/Viewport/GUI/Panel/Label.text = "player "+String(id)+" disconnected"
	#get_node("/root/Spatial/MQTTExperiment").call_deferred("mqttupdatenetstatus")
		
func setconnectiontoserveractive(b):
	Tglobal.connectiontoserveractive = b
	playerMe.get_node("HandRight/HandFlickFaceY").set_surface_material(0, $MaterialSystem/handmaterials.get_node("serverconnected" if Tglobal.connectiontoserveractive else "serverdisconnected").get_surface_material(0))
	if not Tglobal.connectiontoserveractive:
		setnetworkidname(playerMe, 0)
	
	
func _connected_to_server():
	print("_connected_to_server")
	var newnetworkID = get_tree().get_network_unique_id()
	if playerMe.networkID != newnetworkID:
		print("setting the newnetworkID: ", newnetworkID)
		setnetworkidname(playerMe, newnetworkID)
	$GuiSystem/GUIPanel3D/Viewport/GUI/Panel/Label.text = "connected as "+String(playerMe.networkID)
	get_node("BodyObjects/LaserOrient/NotificationTorus").visible = false
			
	print("SETTING connectiontoserveractive true now")
	setconnectiontoserveractive(true)
	assert(playerMe.networkID != 0)
	playerMe.rpc("initplayerappearanceJ", playerMe.playerappearancedict())
	
	while len(deferred_player_connected_list) != 0:
		var id = deferred_player_connected_list.pop_front()
		print("Now calling deferred _player_connected on id ", id)
		call_deferred("_player_connected", id)
	

var sumdelta = 0.0
func _process(delta):
	#	$BatFlutter/BatCentre/batflap/AnimationPlayer.get_animation("ArmatureAction").loop = true
	#	$BatFlutter/BatCentre/batflap/AnimationPlayer.play("ArmatureAction")
	$BatFlutter.rotation_degrees.y += delta*60
	sumdelta += delta
	$BatFlutter/BatCentre/batflap/CPUParticles.emitting = ((int(sumdelta) % 20) < 9)
				
func clearallprocessactivityforreload():
	$VerletRopeSystem.clearallverletactivity()
	$LabelGenerator.clearalllabelactivity()
	$ImageSystem.clearallimageloadingactivity()
	
	if playerMe != null:
		var pointersystem = playerMe.get_node("pointersystem")
		pointersystem.clearactivetargetnode()  # clear all the objects before they are freed
		#pointersystem.clearpointertargetmaterial()
		pointersystem.clearpointertarget()
		pointersystem.setactivetargetwall(null)

func _input(event):
	if event is InputEventKey and event.pressed and event.scancode == KEY_3:
		#print(get_viewport())
		#var cam = get_viewport().get_camera()
		#print(cam)
		#var env = get_viewport().get_camera().environment
		var env = $WorldEnvironment.environment
		print(env)
		env.background_sky = PanoramaSky.new()
		var sky = env.background_sky
		print(sky)
		sky.set_panorama(null)
		sky.set_panorama($WorldEnvironment/SkyboxCreator.get_texture())

	if event is InputEventKey and event.pressed and event.scancode == KEY_4:
		#print(get_viewport())
		#var cam = get_viewport().get_camera()
		#print(cam)
		#var env = get_viewport().get_camera().environment
		$WorldEnvironment/CameraViewport.render_target_update_mode = Viewport.UPDATE_ONCE
		$WorldEnvironment/CameraViewport/Camera.global_transform = $Players/PlayerMe/HeadCam.global_transform
		yield(get_tree().create_timer(0.5), "timeout")
		var env = $WorldEnvironment.environment
		print(env)
		env.background_sky = PanoramaSky.new()
		var sky = env.background_sky
		print(sky)
		sky.set_panorama(null)
		sky.set_panorama($WorldEnvironment/CameraViewport.get_texture())
		
		
