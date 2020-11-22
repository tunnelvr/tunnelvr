extends Spatial

# Stuff to do:

# rationalize the ResourceLoader.load(fetcheddrawingfile)  # imported as an Image, could be something else

# To release, export to the Linux, Windows and Quest2/Android platforms, zip the appropriate dlls and sos together and 
# Upload to Alex's machine.  To run, go into Ubuntu export Linux/X11 runable, go into /mnt/c/Users/henry/godot/tunnelvr_releases and run:
# ../Godot_v3.2.3-stable_linux_server.64  --main-pack tunnelvr_v0.5.0.pck

# xcdfullsetvisibilitycollision to use CollisionLayers technology instead
# scalebar on planview
# Treeview to show which are downloaded
# record zooming trimming position on each and a programmable scalebar

# * check size/100x scale with gitter problem on vive
# * check mass culling of everything not really close to see what framerate does
# * centreline nodes drawn or not tickbox

# * xcchangesequence technology applied to tubes (check using the 20 second delay)

# * How is it going to work from planview?
#   -- this can be done from the plan view too, 
#   -- plot with front-culling so as to see inside the shapes, and plot with image textures on

# * highlight nodes under pointer system so it's global and simplifies colouring code (active node to be an overlay)
# * RTC version to work (and would use webXR)

# * XCdrawing shell pickable and changable material
# * Finish debugging planview and centreline nodes (which should often be visible)
# * centreline nodes to have label highlighted only when pointed at


# * godot docs.  assert returns null from the function it's in when you ignore it
# * check out HDR example https://godotengine.org/asset-library/asset/110

# * pointertargettypes should be an enum for itself

# https://developer.oculus.com/learn/hands-design-interactions/
# https://developer.oculus.com/learn/hands-design-ui/
# https://learn.unity.com/tutorial/unit-5-hand-presence-and-interaction?uv=2018.4&courseId=5d955b5dedbc2a319caab9a0#5d96924dedbc2a6236bc1191
# https://www.youtube.com/watch?v=gpQePH-Ffbw

# * VR leads@skydeas1  and @brainonsilicon in Leeds (can do a trip there)

# * systematically do the updatetubelinkpaths and updatetubelinkpaths recursion properly 

# * Bring in XCdrawings that are hooked to the centreline that will highlight when they get it
# * these cross sections are tied to the centrelinenodes and not the floor, and are prepopulated with the cross sections dimensions and tubes
# * Load and move the floor on load

# * clear up the laser pointer logic and materials

# * Need to ask to improve the documentation on https://docs.godotengine.org/en/latest/classes/class_meshinstance.html#class-meshinstance-method-set-surface-material
# *   See also https://godotengine.org/qa/3488/how-to-generate-a-mesh-with-multiple-materials
# *   And explain how meshes can have their own materials, that are copied into material/0, and the material reappears if material/0 set to null
# * CSG mesh with multiple materials group should have material0, material1 etc

# use this to sniff out waiting for godot performances https://www.concordtheatricals.co.uk/p/7476/waiting-for-godot
	
var hostipnumber: String = ""
export var hostportnumber: int = 4546
export var enablevr: = true
export var usewebsockets: = false
export var planviewonly: = false

var perform_runtime_config = true
var ovr_init_config = null
var ovr_performance = null
var ovr_hand_tracking = null

onready var playerMe = $Players/PlayerMe

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

func setnetworkidnamecolour(player, networkID):
	player.networkID = networkID
	player.set_network_master(networkID)
	player.set_name("NetworkedPlayer"+String(networkID))
	
func _ready():
	print("  Available Interfaces are %s: " % str(ARVRServer.get_interfaces()));
	print("Initializing VR" if enablevr else "VR disabled");

	if OS.has_feature("Server"):
		print("On server mode, autostart server connection")
		$GuiSystem/GUIPanel3D.call_deferred("networkstartasserver", false)
		# export Linux/X11 runable, go into directory and run
		# ../../Godot_v3.2.3-stable_linux_server.64 --main-pack linuxserverversion.pck	
		# Using Ubuntu App on Windows to get the command line
		playerMe.playerplatform = "Server"
		
	elif checkloadinterface("OVRMobile"):  # ignores enablevr flag on quest platform
		print("found quest, initializing")
		ovr_init_config = load("res://addons/godot_ovrmobile/OvrInitConfig.gdns").new()
		ovr_performance = load("res://addons/godot_ovrmobile/OvrPerformance.gdns").new()
		ovr_hand_tracking = load("res://addons/godot_ovrmobile/OvrHandTracking.gdns").new();
		perform_runtime_config = false
		ovr_init_config.set_render_target_size_multiplier(1)
		if Tglobal.arvrinterface.initialize():
			get_viewport().arvr = true
			Engine.target_fps = 72
			Engine.iterations_per_second = 72
			print("  Success initializing Quest Interface.")
		else:
			Tglobal.arvrinterface = null
		playerMe.playerplatform = "Quest"

	elif enablevr and checkloadinterface("Oculus"):
		print("  Found Oculus Interface.");
		if Tglobal.arvrinterface.initialize():
			get_viewport().arvr = true;
			Engine.target_fps = 80 # TODO: this is headset dependent (RiftS == 80)=> figure out how to get this info at runtime
			Engine.iterations_per_second = 80
			OS.vsync_enabled = false;
			print("  Success initializing Oculus Interface.");
			# C:/Users/henry/Appdata/Local/Android/Sdk/platform-tools/adb.exe logcat -s VrApi
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
	
	$PlanViewSystem.transferintorealviewport((not enablevr) and planviewonly)
	playerMe.initplayerappearance_me()
	
	Tglobal.VRoperating = (Tglobal.arvrinterfacename != "none")
	if Tglobal.VRoperating:
		#$BodyObjects/Locomotion_WalkInPlace.initjogdetectionsystem(playerMe.get_node("HeadCam"))
		if Tglobal.arvrinterfacename == "OVRMobile":
			playerMe.initquesthandtrackingnow(ovr_hand_tracking)
			$WorldEnvironment/DirectionalLight.shadow_enabled = false
			$BodyObjects/PlayerDirections.initquesthandcontrollersignalconnections()
		else:
			playerMe.initnormalvrtrackingnow()
			$BodyObjects/PlayerDirections.initcontrollersignalconnections()
			
	else:
		playerMe.initkeyboardcontroltrackingnow()
		print("*** VR not operating")
		
	print("*-*-*-*  requesting permissions: ", OS.request_permissions())
	# this relates to Android permissions: 	change_wifi_multicast_state, internet, 
	#										read_external_storage, write_external_storage, 
	#										capture_audio_output
	var perm = OS.get_granted_permissions()
	print("Granted permissions: ", perm)

	if false:
		#var centrelinefile = "res://surveyscans/dukest1resurvey2009json.res"
		#var centrelinefile = "res://surveyscans/Ireby/Ireby2/Ireby2.json"
		var centrelinefile = "res://surveyscans/LambTrap1.json"
		var xcdatalist = Centrelinedata.xcdatalistfromcentreline(centrelinefile)
		Tglobal.printxcdrawingfromdatamessages = false
		$SketchSystem.actsketchchange(xcdatalist)
		Tglobal.printxcdrawingfromdatamessages = true
		
	elif true:
		$SketchSystem.loadsketchsystemL("res://surveyscans/smallirebysave.res")
	else:
		pass
	playerMe.global_transform.origin.y += 5
	setmsaa()
	$GuiSystem/GUIPanel3D.updateplayerlist()


func nextplayernetworkidinringskippingdoppelganger(deletedid):
	for i in range($Players.get_child_count()):
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
		var playerOther = load("res://nodescenes/PlayerPuppet.tscn").instance()
		setnetworkidnamecolour(playerOther, id)
		playerOther.visible = false
		$Players.add_child(playerOther)
		
	$GuiSystem/GUIPanel3D.updateplayerlist()
	playerMe.bouncetestnetworkID = nextplayernetworkidinringskippingdoppelganger(0)
	Tglobal.morethanoneplayer = $Players.get_child_count() >= 2
	print(" playerMe networkID ", playerMe.networkID, " ", get_tree().get_network_unique_id())
	assert(playerMe.networkID != 0)
	playerMe.rpc_id(id, "initplayerappearance", playerMe.playerplatform, playerMe.get_node("HeadCam/csgheadmesh/skullcomponent").material.albedo_color)
	players_connected_list.push_back(id)
	$GuiSystem/GUIPanel3D/Viewport/GUI/Panel/Label.text = "player "+String(id)+" connected"
	if not Tglobal.controlslocked:
		$GuiSystem/GUIPanel3D.toggleguipanelvisibility(null)

	if playerMe.networkID == 1:
		print("Converting sketchsystemtodict")
		var sketchdatadict = $SketchSystem.sketchsystemtodict()
		assert(playerMe.networkID != 0)
		print("Generating sketchdicttochunks")
		var xcdatachunks = $SketchSystem.sketchdicttochunks(sketchdatadict)
		print("Generated ", len(xcdatachunks), " chunks")
		for xcdatachunk in xcdatachunks:
			$SketchSystem.rpc_id(id, "actsketchchangeL", xcdatachunk)
			yield(get_tree().create_timer(0.2), "timeout")
	
	
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
		playerOther.queue_free()
	$GuiSystem/GUIPanel3D.updateplayerlist()
	playerMe.bouncetestnetworkID = nextplayernetworkidinringskippingdoppelganger(id)
	$GuiSystem/GUIPanel3D/Viewport/GUI/Panel/Label.text = "player "+String(id)+" disconnected"
		
func _connected_to_server():
	print("_connected_to_server")
	var newnetworkID = get_tree().get_network_unique_id()
	if playerMe.networkID != newnetworkID:
		print("setting the newnetworkID: ", newnetworkID)
		setnetworkidnamecolour(playerMe, newnetworkID)
	$GuiSystem/GUIPanel3D/Viewport/GUI/Panel/Label.text = "connected as "+String(playerMe.networkID)

	print("SETTING connectiontoserveractive true now")
	Tglobal.connectiontoserveractive = true
	assert(playerMe.networkID != 0)
	playerMe.rpc("initplayerappearance", playerMe.playerplatform, playerMe.get_node("HeadCam/csgheadmesh/skullcomponent").material.albedo_color)

	while len(deferred_player_connected_list) != 0:
		var id = deferred_player_connected_list.pop_front()
		print("Now calling deferred _player_connected on id ", id)
		call_deferred("_player_connected", id)
	
func setmsaa():
	var msaaval = $GuiSystem/GUIPanel3D/Viewport/GUI/Panel/MSAAstatus.get_selected_id()
	if msaaval == 0:
		get_node("/root").msaa = Viewport.MSAA_DISABLED
	elif msaaval == 1:
		get_node("/root").msaa = Viewport.MSAA_2X
	elif msaaval == 2:
		get_node("/root").msaa = Viewport.MSAA_4X

func _process(_delta):
	if !perform_runtime_config:
		ovr_performance.set_clock_levels(1, 1)
		ovr_performance.set_extra_latency_mode(1)
		perform_runtime_config = true
		set_process(false)
				
func clearallprocessactivityforreload():
	$LabelGenerator.workingxcnodename = null
	$LabelGenerator.remainingxcnodenames.clear()
	$ImageSystem.fetcheddrawing = null
	$ImageSystem.paperdrawinglist.clear()

	if playerMe != null:
		var pointersystem = playerMe.get_node("pointersystem")
		pointersystem.clearactivetargetnode()  # clear all the objects before they are freed
		#pointersystem.clearpointertargetmaterial()
		pointersystem.clearpointertarget()
		pointersystem.setactivetargetwall(null)


