extends StaticBody


var collision_point := Vector3(0, 0, 0)
var current_viewport_mousedown = false
var viewport_point = Vector2(0, 0)

onready var sketchsystem = get_node("/root/Spatial/SketchSystem")
onready var playerMe = get_node("/root/Spatial/Players/PlayerMe")
onready var selfSpatial = get_node("/root/Spatial")
	
func _on_buttonload_pressed():
	var savegamefileid = $Viewport/GUI/Panel/Savegamefilename.get_selected_id()
	var savegamefilename = $Viewport/GUI/Panel/Savegamefilename.get_item_text(savegamefileid)
	if savegamefilename == "cleargame":
		sketchsystem.loadsketchsystemL("cleargame")
		$Viewport/GUI/Panel/Label.text = "Clearing game"
	elif savegamefilename.begins_with("server/"):
		savegamefilename = savegamefilename.replace("server/", "")
		if Tglobal.connectiontoserveractive and playerMe.networkID != 1:
			sketchsystem.rpc_id(1, "loadsketchsystemL", "user://"+savegamefilename)
			$Viewport/GUI/Panel/Label.text = "Loading server sketch"
		else:
			$Viewport/GUI/Panel/Label.text = "*server not connected"
	else:
		var savegamefilenameU = "user://"+savegamefilename
		if File.new().file_exists(savegamefilenameU):
			sketchsystem.loadsketchsystemL(savegamefilenameU)
			$Viewport/GUI/Panel/Label.text = "Sketch Loaded"
		else:
			$Viewport/GUI/Panel/Label.text = "*" + savegamefilename + " does not exist"
					
	if not $Viewport/GUI/Panel/Label.text.begins_with("*") and not Tglobal.controlslocked:
		toggleguipanelvisibility(null)
	Tglobal.soundsystem.quicksound("MenuClick", collision_point)
	
func _on_buttonsave_pressed():
	var savegamefileid = $Viewport/GUI/Panel/Savegamefilename.get_selected_id()
	var savegamefilename = $Viewport/GUI/Panel/Savegamefilename.get_item_text(savegamefileid)
	if savegamefilename == "cleargame":
		$Viewport/GUI/Panel/Label.text = "Cannot oversave cleargame"
	elif savegamefilename.begins_with("server/"):
		savegamefilename = savegamefilename.replace("server/", "")
		if Tglobal.connectiontoserveractive and playerMe.networkID != 1:
			sketchsystem.rpc_id(1, "savesketchsystem", "user://"+savegamefilename)
			$Viewport/GUI/Panel/Label.text = "Saving server sketch"
	else:
		var savegamefilenameU = "user://"+savegamefilename
		sketchsystem.savesketchsystem(savegamefilenameU)
		$Viewport/GUI/Panel/Label.text = "Sketch Saved"
	Tglobal.soundsystem.quicksound("MenuClick", collision_point)
	

func _on_buttonplanview_pressed():
	var button_pressed = $Viewport/GUI/Panel/ButtonPlanView.pressed  # using toggled signal causes updates when programatically set
	var planviewsystem = get_node("/root/Spatial/PlanViewSystem")
	if button_pressed:
		var pvchange = planviewsystem.planviewtodict()
		pvchange["visible"] = true
		pvchange["planviewactive"] = true
		var guidpaneltransform = global_transform
		var guidpanelsize = $Quad.mesh.size
		if not Tglobal.controlslocked:
			toggleguipanelvisibility(null)
			guidpaneltransform = null
		pvchange["transformpos"] = planviewsystem.planviewtransformpos(guidpaneltransform, guidpanelsize)
		sketchsystem.actsketchchange([{"planview":pvchange}])
		$Viewport/GUI/Panel/Label.text = "Planview on"
	else:
		planviewsystem.buttonclose_pressed()
		$Viewport/GUI/Panel/Label.text = "Planview off"

	Tglobal.soundsystem.quicksound("MenuClick", collision_point)
	if not Tglobal.controlslocked:
		toggleguipanelvisibility(null)
	
func _on_buttonheadtorch_toggled(button_pressed):
	playerMe.setheadtorchlight(button_pressed)
	$Viewport/GUI/Panel/Label.text = "Headtorch on" if button_pressed else "Headtorch off"
	if not Tglobal.controlslocked:
		toggleguipanelvisibility(null)

func _on_buttondoppelganger_toggled(button_pressed):
	playerMe.setdoppelganger(button_pressed)
	$Viewport/GUI/Panel/Label.text = "Doppelganger on" if button_pressed else "Doppelganger off"
	if not Tglobal.controlslocked:
		toggleguipanelvisibility(null)

func _on_buttonlockcontrols_toggled(button_pressed):
	Tglobal.controlslocked = button_pressed
	$Viewport/GUI/Panel/Label.text = "Controls locked" if button_pressed else "Controls unlocked"
	if not Tglobal.controlslocked:
		toggleguipanelvisibility(null)
	Tglobal.soundsystem.quicksound("MenuClick", collision_point)

func _on_buttonflywalkreversed_toggled(button_pressed):
	get_node("/root/Spatial/BodyObjects/PlayerDirections").flywalkreversed = button_pressed
	$Viewport/GUI/Panel/Label.text = "Fly/Walk reversed" if button_pressed else "Fly/Walk normal"
	if not Tglobal.controlslocked:
		toggleguipanelvisibility(null)


func _on_playerscale_selected(index):
	var newplayerscale = float($Viewport/GUI/Panel/WorldScale.get_item_text(index))
	var oldplayerscale = playerMe.playerscale
	print("transorig ", playerMe.get_node("HeadCam").transform.origin)
	var headcamvec = playerMe.get_node("HeadCam").transform.origin
	var newplayermetransformheadfixed = playerMe.transform.origin + headcamvec - headcamvec*newplayerscale/oldplayerscale
	ARVRServer.world_scale = newplayerscale
	playerMe.playerscale = newplayerscale
	playerMe.get_node("HandLeft").setcontrollerhandtransform(playerMe.playerscale)
	playerMe.get_node("HandRight").setcontrollerhandtransform(playerMe.playerscale)
	var PlayerDirections = get_node("/root/Spatial/BodyObjects/PlayerDirections")
	var PlayerMotion = get_node("/root/Spatial/BodyObjects/PlayerMotion")
	var pscavec = Vector3(playerMe.playerscale, playerMe.playerscale, playerMe.playerscale)
	PlayerMotion.get_node("PlayerKinematicBody").scale = pscavec
	PlayerMotion.get_node("PlayerEnlargedKinematicBody").scale = pscavec
	PlayerMotion.get_node("PlayerHeadKinematicBody").scale = pscavec
	if playerMe.playerscale == 1.0:
		playerMe.transform.origin = newplayermetransformheadfixed + Vector3(0,2,0)
		PlayerDirections.forceontogroundtimedown = 0.75
		PlayerDirections.floorprojectdistance = 50
		playerMe.playerflyscale = 1.0
		playerMe.playerwalkscale = 1.0

	elif playerMe.playerscale < 1.0:
		playerMe.transform.origin = newplayermetransformheadfixed
		PlayerDirections.forceontogroundtimedown = 0.75
		PlayerDirections.floorprojectdistance = 5
		playerMe.playerflyscale = (playerMe.playerscale+1.0)*0.5
		playerMe.playerwalkscale = (playerMe.playerscale*2+1.0)/3

	else:
		playerMe.transform.origin = newplayermetransformheadfixed
		if playerMe.playerscale >= 10:
			playerMe.playerflyscale = playerMe.playerscale*0.2
		else:
			playerMe.playerflyscale = playerMe.playerscale*0.75
		playerMe.playerwalkscale = 1.0
	toggleguipanelvisibility(null)
	selfSpatial.mqttsystem.mqttpublish("playerscale", String(newplayerscale))


func exportOBJ():
	if not Directory.new().dir_exists("user://objexport"):
		Directory.new().make_dir("user://objexport")
	var fobjname = "user://objexport/cave.obj"
	var fmtlname = "user://objexport/cave.mtl"
	var fout = File.new()
	fout.open(fobjname, File.WRITE)
	fout.store_line("mtllib cave.mtl")
	var materialsystem = get_node("/root/Spatial/MaterialSystem")
	var materialdict = { }
	var joff = 1
	for xctube in sketchsystem.get_node("XCtubes").get_children():
		for i in range(xctube.get_node("XCtubesectors").get_child_count()):
			var xctubesector = xctube.get_node("XCtubesectors").get_child(i)
			var xcmaterialname = xctube.xcsectormaterials[i]
			if xcmaterialname == "hole":
				continue
			if not materialdict.has(xcmaterialname):
				 materialdict[xcmaterialname] = materialsystem.tubematerial(xcmaterialname, false)
			var uvscale = materialdict[xcmaterialname].uv1_scale
			fout.store_line("o %s_%d"%[xctube.get_name(), i])
			var mesh = xctubesector.get_node("MeshInstance").mesh
			var sarrays = mesh.surface_get_arrays(0)
			for p in sarrays[0]:
				fout.store_line("v %f %f %f"%[p.x, p.y, p.z])
			for n in sarrays[4]:
				fout.store_line("vt %f %f"%[n.x*uvscale.x, n.y*uvscale.y])
			fout.store_line("usemtl %s"%xcmaterialname)
			fout.store_line("s off")
			for j in range(0, len(sarrays[0]), 3):
				fout.store_line("f %d/%d %d/%d %d/%d"%[j+joff,j+joff,  j+joff+1,j+joff+1,  j+joff+2,j+joff+2])
			joff += len(sarrays[0])

	materialdict["rope"] = materialsystem.pathlinematerial("rope")
	for xcdrawing in sketchsystem.get_node("XCdrawings").get_children():
		if xcdrawing.drawingtype == DRAWING_TYPE.DT_ROPEHANG:
			var uvscale = materialdict["rope"].uv1_scale
			fout.store_line("o %s"%[xcdrawing.get_name()])
			var mesh = xcdrawing.get_node("RopeHang/RopeMesh").mesh
			if mesh != null:
				var sarrays = mesh.surface_get_arrays(0)
				for p in sarrays[0]:
					fout.store_line("v %f %f %f"%[p.x, p.y, p.z])
				for n in sarrays[4]:
					fout.store_line("vt %f %f"%[n.x*uvscale.x, n.y*uvscale.y])
				fout.store_line("usemtl %s"%"rope")
				for j in range(0, len(sarrays[8]), 3):
					fout.store_line("f %d/%d %d/%d %d/%d"%[sarrays[8][j]+joff,sarrays[8][j]+joff,  sarrays[8][j+1]+joff,sarrays[8][j+1]+joff,  sarrays[8][j+2]+joff,sarrays[8][j+2]+joff])
				joff += len(sarrays[0])
			
	fout.close()
	print("exported to C:/Users/ViveOne/AppData/Roaming/Godot/app_userdata/tunnelvr/objexport")
	$Viewport/GUI/Panel/Label.text = "Cave exported"

	var fmtl = File.new()
	fmtl.open(fmtlname, File.WRITE)
	var textureroot = "res://lightweighttextures/"
	for materialname in materialdict:
		var mat = materialdict[materialname]
		fmtl.store_line("newmtl %s"%materialname)
		fmtl.store_line("  Ka %f %f %f"%[mat.albedo_color.r, mat.albedo_color.g, mat.albedo_color.b])
		fmtl.store_line("  Kd %f %f %f"%[mat.albedo_color.r, mat.albedo_color.g, mat.albedo_color.b])
		fmtl.store_line("  Ks %f %f %f"%[mat.metallic, mat.metallic, mat.metallic])
		fmtl.store_line("  Ns %f"%101)
		if mat.albedo_texture:
			if mat.albedo_texture.resource_path.begins_with(textureroot):
				fmtl.store_line("  map_Kd %s"%mat.albedo_texture.resource_path.replace(textureroot, ""))
		fmtl.store_line("  illum 2")
		fmtl.store_line("")
	fmtl.close()
	

func exportSTL():
	var fname = "user://export.stl"
	var vfaces = [ ]
	var vmathashs = [ ]
	var nfaces = 0
	for xctube in sketchsystem.get_node("XCtubes").get_children():
		for i in range(xctube.get_node("XCtubesectors").get_child_count()):
			var xctubesector = xctube.get_node("XCtubesectors").get_child(i)
			var xcmaterial = xctube.xcsectormaterials[i]
			if xcmaterial != "hole":
				var xcmathash = hash(xcmaterial)
				var mesh = xctubesector.get_node("MeshInstance").mesh
				var g = mesh.get_surface_count()
				var x = mesh.surface_get_arrays(0)
				if i == 0:
					print(x, g)
				var faces = mesh.get_faces()
				vfaces.append(faces)
				vmathashs.append(xcmathash)
				nfaces += int(len(faces)/3)

	var fout = File.new()
	fout.open(fname, File.WRITE)
	var header = "TunnelVR out".to_utf8()
	while len(header) < 80:
		header.append(0x20)
	fout.store_buffer(header)
	fout.store_32(nfaces)
	for faces in vfaces:
		for i in range(0, len(faces), 3):
			var n = Vector3(0,0,1)
			fout.store_float(n.x); fout.store_float(-n.z); fout.store_float(n.y)
			fout.store_float(faces[i].x); fout.store_float(-faces[i].z); fout.store_float(faces[i].y)
			fout.store_float(faces[i+1].x); fout.store_float(-faces[i+1].z); fout.store_float(faces[i+1].y)
			fout.store_float(faces[i+2].x); fout.store_float(-faces[i+2].z); fout.store_float(faces[i+2].y)
			fout.store_16(vmathashs[int(i/3)]%65536)
	fout.close()
	print("saved ", fname, " in C:/Users/ViveOne/AppData/Roaming/Godot/app_userdata/tunnelvr")
	$Viewport/GUI/Panel/Label.text = "Cave exported"


func _on_switchtest(index):
	var nssel = $Viewport/GUI/Panel/SwitchTest.get_item_text(index)
	print(" _on_switchtest ", nssel, " ", index)
	if nssel == "export STL":
		exportSTL()
		return
	if nssel == "export OBJ":
		exportOBJ()
		return

	if nssel == "toggle guardian":
		var guardianpolyvisible = not playerMe.get_node("GuardianPoly").visible
		for player in get_node("/root/Spatial/Players").get_children():
			player.get_node("GuardianPoly").visible = guardianpolyvisible
		return
		

	var n = 0
	for xcdrawing in sketchsystem.get_node("XCdrawings").get_children():
		if xcdrawing.drawingtype == DRAWING_TYPE.DT_FLOORTEXTURE:
			if true or (xcdrawing.drawingvisiblecode & DRAWING_TYPE.VIZ_XCD_FLOOR_GHOSTLY_B) != 0:
				xcdrawing.get_node("XCdrawingplane").visible = (index == 0)
				n += 1
	print(("hiding " if index == 1 else "showing "), n, " ghostly drawings")
	if nssel == "all grey":
		var materialsystem = get_node("/root/Spatial/MaterialSystem")
		for xctube in sketchsystem.get_node("XCtubes").get_children():
			for xctubesector in xctube.get_node("XCtubesectors").get_children():
				materialsystem.updatetubesectormaterial(xctubesector, "flatgrey", false)
	if nssel == "hide xc":
		sketchsystem.get_node("XCdrawings").visible = false
	elif nssel == "normal":
		sketchsystem.get_node("XCdrawings").visible = true
	

		
func _on_buttonswapcontrollers_pressed():
	playerMe.swapcontrollers()
	$Viewport/GUI/Panel/Label.text = "Controllers swapped"
	Tglobal.soundsystem.quicksound("MenuClick", collision_point)

func _on_buttonrecord_down():
	$Viewport/GUI/Panel/Label.text = "Recording ***"
	Tglobal.soundsystem.startmyvoicerecording()

func _on_buttonrecord_up():
	var rleng = Tglobal.soundsystem.stopmyvoicerecording()
	$Viewport/GUI/Panel/Label.text = "Recorded  %.0fKb" % (rleng/1000)

func _on_buttonplay_pressed():
	Tglobal.soundsystem.playmyvoicerecording()
	$Viewport/GUI/Panel/Label.text = "Play voice"
	
func _on_buttonload_choke(pressed):
	$Viewport/GUI/Panel/Label.text = "Boulder choke!"
	toggleguipanelvisibility(null)
	var Nboulders = 50
	var boulderclutter = get_node("/root/Spatial/BoulderClutter")
	if pressed:
		var HandRight = playerMe.get_node("HandRight")
		for i in range(Nboulders):
			yield(get_tree().create_timer(0.1), "timeout")
			if HandRight.pointervalid:
				var markernode = null
				if ((i%5) == 1):
					markernode = preload("res://assets/objectscenes/log.tscn").instance()
				else:
					markernode = preload("res://assets/objectscenes/boulder.tscn").instance()
					if ((i%2) == 0):
						markernode.scale = Vector3(0.5, 0.5, 0.5)
				var handrightpointertrans = playerMe.global_transform*HandRight.pointerposearvrorigin
				markernode.global_transform.origin = handrightpointertrans.origin - 0.9*handrightpointertrans.basis.z
				markernode.linear_velocity = -5.1*handrightpointertrans.basis.z
				boulderclutter.add_child(markernode)
	else:
		for markernode in boulderclutter.get_children():
			markernode.queue_free()


	

const clientips = [ "144.76.167.54 Alex",  # alex server
					"192.168.8.104 Quest2",  # home wifi
					"192.168.8.101 JGT",     # home wifi
					"192.168.43.186 Quest2S9" ]
func _ready():
	if has_node("ViewportReal"):
		var fgui = $Viewport/GUI
		$Viewport.remove_child(fgui)
		$ViewportReal.add_child(fgui)
		$Viewport.set_name("ViewportFake")
		$ViewportReal.set_name("Viewport")
		$Quad.get_surface_material(0).albedo_texture = $Viewport.get_texture()
		
	$Viewport.render_target_update_mode = Viewport.UPDATE_DISABLED
	for clientip in clientips:
		$Viewport/GUI/Panel/Networkstate.add_item("Client->"+clientip)
	
	$Viewport/GUI/Panel/ButtonLoad.connect("pressed", self, "_on_buttonload_pressed")
	$Viewport/GUI/Panel/ButtonSave.connect("pressed", self, "_on_buttonsave_pressed")
	$Viewport/GUI/Panel/ButtonPlanView.connect("pressed", self, "_on_buttonplanview_pressed")
	$Viewport/GUI/Panel/ButtonHeadtorch.connect("toggled", self, "_on_buttonheadtorch_toggled")
	$Viewport/GUI/Panel/ButtonDoppelganger.connect("toggled", self, "_on_buttondoppelganger_toggled")
	$Viewport/GUI/Panel/ButtonSwapControllers.connect("pressed", self, "_on_buttonswapcontrollers_pressed")
	$Viewport/GUI/Panel/ButtonLockControls.connect("toggled", self, "_on_buttonlockcontrols_toggled")
	$Viewport/GUI/Panel/FlyWalkReversed.connect("toggled", self, "_on_buttonflywalkreversed_toggled")
	#$Viewport/GUI/Panel/ButtonRecord.connect("button_down", self, "_on_buttonrecord_down")
	#$Viewport/GUI/Panel/ButtonRecord.connect("button_up", self, "_on_buttonrecord_up")
	#$Viewport/GUI/Panel/ButtonPlay.connect("pressed", self, "_on_buttonplay_pressed")
	$Viewport/GUI/Panel/ButtonChoke.connect("toggled", self, "_on_buttonload_choke")
	
	$Viewport/GUI/Panel/SwitchTest.connect("item_selected", self, "_on_switchtest")
	$Viewport/GUI/Panel/PlayerList.connect("item_selected", self, "_on_playerlist_selected")
	$Viewport/GUI/Panel/ButtonGoto.connect("pressed", self, "_on_buttongoto_pressed")
	$Viewport/GUI/Panel/WorldScale.connect("item_selected", self, "_on_playerscale_selected")
	$Viewport/GUI/Panel/Networkstate.connect("item_selected", self, "_on_networkstate_selected")

	if $Viewport/GUI/Panel/Networkstate.selected != 0:  # could record saved settings on disk
		call_deferred("_on_networkstate_selected", $Viewport/GUI/Panel/Networkstate.selected)

func clickbuttonheadtorch():
	$Viewport/GUI/Panel/ButtonHeadtorch.pressed = not $Viewport/GUI/Panel/ButtonHeadtorch.pressed
	_on_buttonheadtorch_toggled($Viewport/GUI/Panel/ButtonHeadtorch.pressed)

remote func playerjumpgoto(puppetplayerid, lforcetogroundtimedown):
	var puppetplayername = "NetworkedPlayer"+String(puppetplayerid)
	var playerpuppet = get_node("/root/Spatial/Players").get_node_or_null(puppetplayername)
	if playerpuppet != null:
		get_node("/root/Spatial/BodyObjects/PlayerDirections").setasaudienceofpuppet(playerpuppet, playerpuppet.get_node("HeadCam").global_transform, 0.5)
	else:
		print("Not able to playerjumpto ", puppetplayername)

func _on_buttongoto_pressed():
	if selectedplayernetworkid == playerMe.networkID:
		if playerMe.networkID != 1 and Tglobal.connectiontoserveractive:
			rpc_id(1, "playerjumpgoto", playerMe.networkID, 0.5)
	elif selectedplayernetworkid != -1:
		playerjumpgoto(selectedplayernetworkid, 0.5)
	toggleguipanelvisibility(null)

var selectedplayernetworkid = 0
var selectedplayerplatform = ""
func _on_playerlist_selected(index):
	var player = get_node("/root/Spatial/Players").get_child(index)
	if player != null:
		selectedplayernetworkid = player.networkID
		selectedplayerplatform = player.playerplatform
		$Viewport/GUI/Panel/PlayerInfo.text = "%s:%d" % [selectedplayerplatform, selectedplayernetworkid]
		netlinkstatstimer = -3.0
		networkmetricsreceived = null
		$Viewport/GUI/Panel/ButtonGoto.disabled = selectedplayernetworkid == playerMe.networkID and playerMe.networkID == 1

	else:
		selectedplayernetworkid = -1
		selectedplayerplatform = ""
		$Viewport/GUI/Panel/PlayerInfo.text = String("updating")
		updateplayerlist()
		$Viewport/GUI/Panel/ButtonGoto.disabled = true
		
	
func updateplayerlist():
	var selectedplayerindex = 0
	$Viewport/GUI/Panel/PlayerList.clear()
	for player in get_node("/root/Spatial/Players").get_children():
		var playername
		if player == playerMe:
			playername = "me"
		elif player == playerMe.doppelganger:
			playername = "doppel"
		elif player.networkID == 1:
			playername = "server"
		else:
			playername = "player%d" % player.get_index()
		$Viewport/GUI/Panel/PlayerList.add_item(playername)
		
		if player.networkID == selectedplayernetworkid:
			selectedplayerindex = player.get_index()

	$Viewport/GUI/Panel/PlayerList.select(selectedplayerindex)
	

func toggleguipanelvisibility(controller_global_transform):
	if not visible and controller_global_transform != null:
		var paneltrans = Transform()
		var controllertrans = controller_global_transform
		var paneldistance = 0.6 if Tglobal.VRoperating else 0.2
		paneltrans.origin = controllertrans.origin - paneldistance*ARVRServer.world_scale*(controllertrans.basis.z)
		var lookatpos = controllertrans.origin - 1.6*ARVRServer.world_scale*(controllertrans.basis.z)
		paneltrans = paneltrans.looking_at(lookatpos, Vector3(0, 1, 0))
		paneltrans = Transform(paneltrans.basis.scaled(Vector3(ARVRServer.world_scale, ARVRServer.world_scale, ARVRServer.world_scale)), paneltrans.origin)		
		global_transform = paneltrans
		
		$Viewport/GUI/Panel/Label.text = ""
		var MQTTExperiment = get_node_or_null("/root/Spatial/MQTTExperiment")
		if MQTTExperiment != null and MQTTExperiment.msg != "":
			$Viewport/GUI/Panel/Label.text = MQTTExperiment.msg
		elif Tglobal.connectiontoserveractive:
			Tglobal.connectiontoserveractive

		visible = true
		$CollisionShape.disabled = false
		Tglobal.soundsystem.quicksound("ShowGui", global_transform.origin)
		$Viewport.render_target_update_mode = Viewport.UPDATE_WHEN_VISIBLE
		
	else:
		visible = false	
		$Viewport.render_target_update_mode = Viewport.UPDATE_DISABLED
		$CollisionShape.disabled = true
		var MQTTExperiment = get_node_or_null("/root/Spatial/MQTTExperiment")
		if MQTTExperiment != null and MQTTExperiment.msg != "":
			$Viewport/GUI/Panel/Label.text = MQTTExperiment.msg

	if Tglobal.connectiontoserveractive:
		print("nnnnn ", get_tree().get_network_unique_id())
		assert(selfSpatial.playerMe.networkID != 0)
		selfSpatial.playerMe.rpc("puppetenableguipanel", transform if visible else null)

		if visible and $Viewport/GUI/Panel/Label.text == "":
			var msg = "NetIDs "+str(selfSpatial.playerMe.networkID)+":"
			for id in selfSpatial.players_connected_list:
				msg += " "+str(id)
			print(msg)
			$Viewport/GUI/Panel/Label.text = msg
			
	if is_instance_valid(selfSpatial.playerMe.doppelganger):
		selfSpatial.playerMe.doppelganger.puppetenableguipanel(transform if visible else null)

	
		
func _input(event):
	if event is InputEventKey and event.pressed:
		if event.scancode == KEY_L:
			_on_buttonload_pressed()
		elif event.scancode == KEY_G:
			$Viewport/GUI/Panel/ButtonDoppelganger.pressed = not $Viewport/GUI/Panel/ButtonDoppelganger.pressed
			_on_buttondoppelganger_toggled($Viewport/GUI/Panel/ButtonDoppelganger.pressed)	
		elif event.scancode == KEY_O:
			_on_buttonswapcontrollers_pressed()
		elif event.scancode == KEY_B:
			call_deferred("_on_networkstate_selected", 3)

#-------------networking system
var websocketserver = null
var websocketclient = null
var networkedmultiplayerenet = null

func _on_networkstate_selected(index):
	var nssel = $Viewport/GUI/Panel/Networkstate.get_item_text(index)
	print("Select networkstate: ", nssel)
	if nssel == "Check IPnum":
		print("IP local interfaces: ")
		$Viewport/GUI/Panel/Label.text = ""
		for k in IP.get_local_interfaces():
			var ipnum = ""
			for l in k["addresses"]:
				if l.find(".") != -1:
					ipnum = l
			var kf = k["friendly"] + ": " + ipnum
			print(kf)
			if k["friendly"] == "Wi-Fi" or k["friendly"].begins_with("wlan"):
				$Viewport/GUI/Panel/Label.text = kf
			elif k["friendly"] == "Ethernet" and $Viewport/GUI/Panel/Label.text == "":
				$Viewport/GUI/Panel/Label.text = kf
		websocketclient = null
		
	if nssel.begins_with("Network Off"):
		if websocketserver != null:
			websocketserver.close()
			# Note: To achieve a clean close, you will need to keep polling until either WebSocketClient.connection_closed or WebSocketServer.client_disconnected is received.
			# Note: The HTML5 export might not support all status codes. Please refer to browser-specific documentation for more details.
			websocketserver = null
		if websocketclient != null:
			websocketclient.disconnect_from_host()
			#websocketclient = null
		if networkedmultiplayerenet != null:
			networkedmultiplayerenet.close_connection()
			networkedmultiplayerenet = null
		selfSpatial.setconnectiontoserveractive(false)
		get_tree().set_network_peer(null)
		
	if nssel.begins_with("As Server"):
		networkstartasserver(true)
		if selfSpatial.playerMe.networkID == 0:
			$Viewport/GUI/Panel/Label.text = "server failed to start"
		else:
			$Viewport/GUI/Panel/Label.text = "networkID: "+str(selfSpatial.playerMe.networkID)
				
	if nssel.begins_with("Client->"):
		selfSpatial.hostipnumber = nssel.replace("Client->", "")
		if selfSpatial.hostipnumber.find(" "):
			selfSpatial.hostipnumber = selfSpatial.hostipnumber.left(selfSpatial.hostipnumber.find(" "))
		print(selfSpatial.hostipnumber.is_valid_ip_address())
		
		get_tree().connect("network_peer_connected", selfSpatial, "_player_connected")
		get_tree().connect("network_peer_disconnected", selfSpatial, "_player_disconnected")
		selfSpatial.setconnectiontoserveractive(false)
		get_tree().connect("connected_to_server", selfSpatial, "_connected_to_server")
		get_tree().connect("connection_failed", self, "_connection_failed")
		get_tree().connect("server_disconnected", self, "_server_disconnected")
		selfSpatial.playerMe.global_transform.origin += 3*Vector3(selfSpatial.playerMe.get_node("HeadCam").global_transform.basis.z.x, 0, selfSpatial.playerMe.get_node("HeadCam").global_transform.basis.z.z).normalized()
		if selfSpatial.usewebsockets:
			websocketclient = WebSocketClient.new();
			var url = "ws://"+selfSpatial.hostipnumber+":" + str(selfSpatial.hostportnumber)
			var e = websocketclient.connect_to_url(url, PoolStringArray(), true)
			print("Websocketclient connect to: ", url, " ", e, " <<----ERROR " if e != 0 else "")
			get_tree().set_network_peer(websocketclient)
			
		else:
			networkedmultiplayerenet = NetworkedMultiplayerENet.new()
			var inbandwidth = 0
			var outbandwidth = 0
			var e = networkedmultiplayerenet.create_client(selfSpatial.hostipnumber, selfSpatial.hostportnumber, inbandwidth, outbandwidth)
			print("networkedmultiplayerenet createclient: ", e)
			get_tree().set_network_peer(networkedmultiplayerenet)
		$Viewport/GUI/Panel/Label.text = "connecting "+("websocket" if selfSpatial.usewebsockets else "ENET")

func networkstartasserver(fromgui):
	if not fromgui:
		yield(get_tree().create_timer(2.0), "timeout")		
	print("Starting as server, ipnumber list:")
	for k in IP.get_local_interfaces():
		var ipnum = ""
		for l in k["addresses"]:
			if l.find(".") != -1:
				ipnum = l
		print(k["friendly"] + ": " + ipnum)
	
	get_tree().connect("network_peer_connected", selfSpatial, "_player_connected")
	get_tree().connect("network_peer_disconnected", selfSpatial, "_player_disconnected")
	if selfSpatial.usewebsockets:
		websocketserver = WebSocketServer.new();
		var e = websocketserver.listen(selfSpatial.hostportnumber, PoolStringArray(), true)
		print("Websocketserverclient listen: ", e)
		get_tree().set_network_peer(websocketserver)
		selfSpatial.setconnectiontoserveractive(true)
	else:
		networkedmultiplayerenet = NetworkedMultiplayerENet.new()
		var e = networkedmultiplayerenet.create_server(selfSpatial.hostportnumber, 32)
		if e == 0:
			get_tree().set_network_peer(networkedmultiplayerenet)
			selfSpatial.setconnectiontoserveractive(true)
		else:
			print("networkedmultiplayerenet createserver Error: ", {ERR_CANT_CREATE:"ERR_CANT_CREATE"}.get(e, e))
			print("*** is there a server running on this port already? ", selfSpatial.hostportnumber)
			$Viewport/GUI/Panel/Networkstate.selected = 0

	var lnetworkID = get_tree().get_network_unique_id()
	selfSpatial.setnetworkidnamecolour(selfSpatial.playerMe, lnetworkID)
	print("server networkID: ", selfSpatial.playerMe.networkID)
	selfSpatial.mqttsystem.mqttpublish("startasserver", String(selfSpatial.playerMe.networkID))
		
func _connection_failed():
	print("_connection_failed ", Tglobal.connectiontoserveractive, " ", websocketclient, " ", selfSpatial.players_connected_list)
	selfSpatial.mqttsystem.mqttpublish("connectionfailed", String(playerMe.networkID))
	websocketclient = null
	if Tglobal.connectiontoserveractive:
		_server_disconnected()
	else:
		assert (len(selfSpatial.deferred_player_connected_list) == 0)
		assert (len(selfSpatial.players_connected_list) == 0)
	$Viewport/GUI/Panel/Label.text = "connection_failed"
	
func _server_disconnected():
	print("\n\n***_server_disconnected ", websocketclient, "\n\n")
	websocketclient = null
	networkedmultiplayerenet = null
	selfSpatial.setconnectiontoserveractive(false)
	selfSpatial.mqttsystem.mqttpublish("serverdisconnected", String(playerMe.networkID))
	selfSpatial.deferred_player_connected_list.clear()
	$Viewport/GUI/Panel/Label.text = "server_disconnected"
	for id in selfSpatial.players_connected_list:
		print("server_disconnected, calling _player_disconnected on ", id)
		selfSpatial.call_deferred("_player_disconnected", id)
	if $Viewport/GUI/Panel/Networkstate.selected != 0:
		$Viewport/GUI/Panel/Networkstate.selected = 0
	
var networkmetricsreceived = null
remote func recordnetworkmetrics(lnetworkmetricsreceived):
	lnetworkmetricsreceived["ticksback"] = OS.get_ticks_msec()
	networkmetricsreceived = lnetworkmetricsreceived
	var bouncetimems = networkmetricsreceived["ticksback"] - networkmetricsreceived["ticksout"]
	#print("recordnetworkmetrics ", networkmetricsreceived)
	selfSpatial.mqttsystem.mqttpublish("fpsbounce", "%d %d" % [Performance.get_monitor(Performance.TIME_FPS), bouncetimems])

		
remote func sendbacknetworkmetrics(lnetworkmetrics, networkIDsource):
	var playerOthername = "NetworkedPlayer"+String(networkIDsource) if networkIDsource != -11 else "Doppelganger"
	var playerOther = get_node("/root/Spatial/Players").get_node_or_null(playerOthername)
	if playerOther != null and len(playerOther.puppetpositionstack) != 0:
		lnetworkmetrics["stackduration"] = playerOther.puppetpositionstack[-1]["Ltimestamp"] - OS.get_ticks_msec()*0.001
		print(playerOthername, " stackduration is ", lnetworkmetrics["stackduration"])
	elif playerOther == null:
		print("Did not find ", playerOthername)
		lnetworkmetrics["stackduration"] = -1.0
	else:
		print(playerOthername, " stack empty")
		lnetworkmetrics["stackduration"] = 0.0
	lnetworkmetrics["unixtime"] = OS.get_unix_time()
	if networkIDsource >= 0:
		rpc_id(networkIDsource, "recordnetworkmetrics", lnetworkmetrics)
	elif networkIDsource == -11:
		call_deferred("recordnetworkmetrics", lnetworkmetrics)

				
const netlinkstatstimeinterval = 1.1
var netlinkstatstimer = 0.0
var maxdelta = 0.0
var sumdelta = 0.0
var countframes = 0
func _process(delta):
	if websocketserver != null:
		if websocketserver.is_listening():
			websocketserver.poll()
	if websocketclient != null:
		websocketclient.poll()
	if Tglobal.connectiontoserveractive and not OS.has_feature("Server"):
		if visible and netlinkstatstimer < 0.0 and netlinkstatstimer + delta >= 0:
			$Viewport/GUI/Panel/PlayerInfo.text = "%s:%d" % [selectedplayerplatform, selectedplayernetworkid]
		netlinkstatstimer += delta
		maxdelta = max(delta, maxdelta)
		sumdelta += delta
		countframes += 1
		if netlinkstatstimer > netlinkstatstimeinterval:
			if networkmetricsreceived != null:
				var stacktime = networkmetricsreceived["stackduration"]
				var bouncetime = (networkmetricsreceived["ticksback"] - networkmetricsreceived["ticksout"])*0.001
				$Viewport/GUI/Panel/PlayerInfo.text = "bounce:%.3f stack:%.3f" % [bouncetime, stacktime]
				networkmetricsreceived = null
			elif selectedplayernetworkid == 0 or selectedplayernetworkid == playerMe.networkID:
				if countframes != 0:
					if visible:
						$Viewport/GUI/Panel/PlayerInfo.text = "frame max:%.3f avg:%.3f" % [maxdelta, sumdelta/countframes]
					maxdelta = 0.0
					sumdelta = 0.0
					countframes = 0

			if selectedplayernetworkid >= 0:
				rpc_id(selectedplayernetworkid, "sendbacknetworkmetrics", { "ticksout":OS.get_ticks_msec() }, playerMe.networkID)
			elif selectedplayernetworkid == -10:
				call_deferred("sendbacknetworkmetrics", { "ticksout":OS.get_ticks_msec() }, -11)
			netlinkstatstimer = 0.0
