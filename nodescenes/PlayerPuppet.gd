extends Spatial

var networkID = 0
var playerplatform = ""

var puppetpositionstack = [ ]         # [ { "timestamp", "Ltimestamp", "playertransform", "headcamtransform" } ] 
var puppetpointerpositionstack = [ ]  # [ { "timestamp", "Ltimestamp", "orient", "length", "spotvisible" } ] 

remote func initplayerappearance(lplayerplatform, headcolour):
	playerplatform = lplayerplatform
	get_node("HeadCam/csgheadmesh/skullcomponent").material.albedo_color = headcolour
	#if playerplatform == "PC":
	#	get_node("HeadCam/csgheadmesh").mesh.size.x = 0.15
	if playerplatform == "Quest":
		get_node("HeadCam/visorline").visible = true
		get_node("HeadCam/visorline").get_surface_material(0).albedo_color = headcolour
	elif playerplatform == "Vive":
		get_node("HeadCam/visorline").visible = true
		get_node("HeadCam/visorline").get_surface_material(0).albedo_color = Color(0, 0, 0.3)
	else:
		get_node("HeadCam/visorline").visible = false
	
# reltime is localtime - remotetime.  More delay means message sent earlier, means bigger number. Find smallest filtering any outliers
var relativetimeminmax = 0
var remotetimegapmaxmin = 0
var firstrelativetimenotset = true
var prevremotetime = 0
var reltimebatchcount = 0
var remotetimegapmin = 0
var relativetimemax = 0
var remotetimegap_dtmax = 0.8  # copied from PlayerMotion.gd
const maxstacklength = 80
var playerscale = 1.0
onready var guipanel3d = get_node("/root/Spatial/GuiSystem/GUIPanel3D")


remote func setavatarposition(positiondict):
	$AnimationPlayer_setavatarposition_flash.stop()
	$AnimationPlayer_setavatarposition_flash.play("setavatarposition_flash")
	print("received setavatarposition ", get_name(), positiondict.keys())
	if not visible:
		if "puppetbody" in positiondict:
			global_transform = positiondict["puppetbody"]["playertransform"]
			$HeadCam.transform = positiondict["puppetbody"]["headcamtransform"]
			$headlocator.transform.origin = $HeadCam.transform.origin
			visible = true
			Tglobal.soundsystem.quicksound("PlayerArrive", global_transform.origin)
	if guipanel3d.visible and guipanel3d.netlinkstatstimer < 0.0 and guipanel3d.selectedplayernetworkid == networkID:
		guipanel3d.get_node("Viewport/GUI/Panel/PlayerInfo").text = "setavatarposition:%.3f"%positiondict["timestamp"]
	
	var t0 = OS.get_ticks_msec()*0.001
	var reltime = t0 - positiondict["timestamp"]
	if reltimebatchcount == 0 or reltime > relativetimemax:
		relativetimemax = reltime
	if reltimebatchcount > 0:
		var remotetimegap = positiondict["timestamp"] - prevremotetime
		if reltimebatchcount == 1 or remotetimegap < remotetimegapmin:
			remotetimegapmin = remotetimegap
	reltimebatchcount += 1
	prevremotetime = positiondict["timestamp"]
	if reltimebatchcount == 10:
		if firstrelativetimenotset or relativetimemax < relativetimeminmax:
			relativetimeminmax = relativetimemax
		if firstrelativetimenotset or remotetimegapmin > remotetimegapmaxmin:
			remotetimegapmaxmin = remotetimegapmin
		reltimebatchcount = 0
		if firstrelativetimenotset:
			print("relativetimeminmax ", relativetimeminmax, "  ", remotetimegapmaxmin)
			firstrelativetimenotset = false

	var dt = reltime   # pipe through directly and then buffer
	if not firstrelativetimenotset:
		dt = relativetimeminmax + remotetimegap_dtmax + 0.05  # was remotetimegapmaxmin, but only gets smooth when it gets to that value
	
	var Ltimestamp = positiondict["timestamp"] + dt
	if positiondict.has("playerscale"):
		if playerscale != positiondict["playerscale"]:
			playerscale = positiondict["playerscale"]
			get_node("HandLeft").setcontrollerhandtransform(playerscale)
			get_node("HandRight").setcontrollerhandtransform(playerscale)
		
	if positiondict.has("puppetbody"):
		var puppetbody = positiondict["puppetbody"]
		puppetbody["timestamp"] = positiondict["timestamp"]
		puppetbody["Ltimestamp"] = Ltimestamp
		while len(puppetpositionstack) > maxstacklength:
			puppetpositionstack.pop_front()
		puppetpositionstack.push_back(puppetbody)
		print(" ", get_name(), " stacksize ", len(puppetpositionstack))
		
	if positiondict.has("laserpointer"):
		var puppetpointerposition = positiondict["laserpointer"]
		puppetpointerposition["timestamp"] = positiondict["timestamp"]
		puppetpointerposition["Ltimestamp"] = Ltimestamp
		while len(puppetpointerpositionstack) > maxstacklength:
			puppetpointerpositionstack.pop_front()
		puppetpointerpositionstack.push_back(puppetpointerposition)

	if positiondict.has("handleft"):
		var handleftposition = positiondict["handleft"]
		handleftposition["Ltimestamp"] = Ltimestamp
		while len($HandLeft.handpositionstack) > maxstacklength:
			$HandLeft.handpositionstack.pop_front()
		$HandLeft.handpositionstack.push_back(handleftposition)

	if positiondict.has("handright"):
		var handrightposition = positiondict["handright"]
		handrightposition["Ltimestamp"] = Ltimestamp
		while len($HandRight.handpositionstack) > maxstacklength:
			$HandRight.handpositionstack.pop_front()
		$HandRight.handpositionstack.push_back(handrightposition)

func _ready():
	$HandLeft/LaserPointer.visible = false
	$HandRight/LaserPointer.visible = false
	call_deferred("copyfakeguisystem")

func copyfakeguisystem():
	var realgripmenu = get_node("/root/Spatial/GuiSystem/GripMenu")
	for wordbutton in realgripmenu.get_node("WordButtons").get_children():
		var fakestaticbody = Spatial.new()
		fakestaticbody.transform = wordbutton.transform
		fakestaticbody.set_name(wordbutton.get_name())
		var wordmesh = wordbutton.get_node("MeshInstance")
		var fakewordmesh = wordmesh.duplicate()
		fakewordmesh.visible = true
		fakestaticbody.add_child(fakewordmesh)
		$FakeGuiSystem/GripMenu/WordButtons.add_child(fakestaticbody)
	puppetenablegripmenus(null, null)

remote func puppetenablegripmenus(gmlist, gmtransform):
	if gmlist != null:
		$FakeGuiSystem/GripMenu.transform = gmtransform
		for g in gmlist:
			if g == "materials":
				pass
				#for s in $MaterialButtons.get_children():
				#	s.get_node("MeshInstance").visible = true
			elif g != "":
				$FakeGuiSystem/GripMenu/WordButtons.get_node(g).get_node("MeshInstance").visible = true
	else:
		for s in $FakeGuiSystem/GripMenu/WordButtons.get_children():
			s.get_node("MeshInstance").visible = false

remote func puppetenableguipanel(guitransform):
	if guitransform != null:
		$FakeGuiSystem/GUIPanel3D.transform = guitransform
		$FakeGuiSystem/GUIPanel3D.visible = true
	else:
		$FakeGuiSystem/GUIPanel3D.visible = false

remote func puppetsetheadtorchlight(torchon):
	$HeadCam/headtorchcone/headtorchon.visible = torchon
	$HeadCam/headtorchcone/headtorchon/SpotLight.visible = (Tglobal.arvrinterfacename != "OVRMobile")
	
func _process(delta):
	process_puppetpositionstack(delta)
	process_puppetpointerpositionstack(delta)
	# process_handpositionstack done per hand because system is also used to make gestures from controllers

var prevfootstepcount = 0
func process_puppetpositionstack(delta):
	var t = OS.get_ticks_msec()*0.001
	while len(puppetpositionstack) >= 2 and puppetpositionstack[1]["Ltimestamp"] <= t:
		puppetpositionstack.pop_front()
	if len(puppetpositionstack) == 0 or t < puppetpositionstack[0]["Ltimestamp"]:
		return
	var pp = puppetpositionstack[0]
	if len(puppetpositionstack) == 1:
		if pp.has("playertransform"):
			global_transform = pp["playertransform"]
		if pp.has("headcamtransform"):
			$HeadCam.transform = Transform(pp["headcamtransform"].basis.scaled(Vector3(playerscale, playerscale, playerscale)), pp["headcamtransform"].origin)
			$headlocator.transform.origin = $HeadCam.transform.origin
		puppetpositionstack.pop_front()
		
	else:
		var pp1 = puppetpositionstack[1]
		var lam = inverse_lerp(pp["Ltimestamp"], pp1["Ltimestamp"], t)
		var Dx = ""
		if pp.has("playertransform") and pp1.has("playertransform"):
			Dx = var2str(pp["playertransform"].basis)
			global_transform = Transform(pp["playertransform"].basis.slerp(pp1["playertransform"].basis, lam), 
										 lerp(pp["playertransform"].origin, pp1["playertransform"].origin, lam))
			if Quat(pp["playertransform"].basis) == Quat(0,0,0,1):
				print("Baaad ", Dx)
		if pp.has("headcamtransform") and pp1.has("headcamtransform"):
			Dx = var2str(pp["headcamtransform"].basis)
			$HeadCam.transform = Transform(pp["headcamtransform"].basis.slerp(pp1["headcamtransform"].basis, lam).scaled(Vector3(playerscale, playerscale, playerscale)), 
										   lerp(pp["headcamtransform"].origin, pp1["headcamtransform"].origin, lam))
			$headlocator.transform.origin = $HeadCam.transform.origin
		if pp1.has("footstepcount") and pp1["footstepcount"] != prevfootstepcount:
			Tglobal.soundsystem.quicksound("TapSound", $HeadCam.global_transform.origin - Vector3(0, 1.5, 0))
			prevfootstepcount = pp1["footstepcount"]
			if (prevfootstepcount%100) == 101:
				print(Dx)
				
func process_puppetpointerpositionstack(delta):
	var t = OS.get_ticks_msec()*0.001
	while len(puppetpointerpositionstack) >= 2 and puppetpointerpositionstack[1]["Ltimestamp"] <= t:
		puppetpointerpositionstack.pop_front()
	if len(puppetpointerpositionstack) == 0 or t < puppetpointerpositionstack[0]["Ltimestamp"]:
		return
	var pp = puppetpointerpositionstack[0]
	if len(puppetpointerpositionstack) == 1:
		$LaserOrient.transform = pp["orient"]
		$LaserOrient/Length.scale.z = pp["length"]
		if "laserselectline" in pp:
			$LaserSelectLine.global_transform = pp["laserselectline"]["global_transform"]
			$LaserSelectLine/Scale.scale.z = pp["laserselectline"]["scalez"]
			$LaserSelectLine.visible = true
		else:
			$LaserSelectLine.visible = false
		puppetpointerpositionstack.pop_front()
		
		if "planviewlaser" in pp:
			$PlanViewLaser.global_transform = pp["planviewlaser"]["global_transform"]
			$PlanViewLaser/Length.scale.z = pp["planviewlaser"]["length"]
			$PlanViewLaser.visible = true
		else:
			$PlanViewLaser.visible = false
		
	else:
		var pp1 = puppetpointerpositionstack[1]
		var lam = inverse_lerp(pp["Ltimestamp"], pp1["Ltimestamp"], t)
		$LaserOrient.transform = Transform(pp["orient"].basis.slerp(pp1["orient"].basis, lam), 
										   lerp(pp["orient"].origin, pp1["orient"].origin, lam)) 
		$LaserOrient/Length.scale.z = lerp(pp["length"], pp1["length"], lam)

		if "laserselectline" in pp and "laserselectline" in pp1:
			$LaserSelectLine.global_transform = Transform(pp["laserselectline"]["global_transform"].basis.slerp(pp1["laserselectline"]["global_transform"].basis, lam), 
														  lerp(pp["laserselectline"]["global_transform"].origin, pp1["laserselectline"]["global_transform"].origin, lam)) 
			$LaserSelectLine/Scale.scale.z = lerp(pp["laserselectline"]["scalez"], pp1["laserselectline"]["scalez"], lam)
			$LaserSelectLine.visible = true
		else:
			$LaserSelectLine.visible = false

		if "planviewlaser" in pp and "planviewlaser" in pp1:
			$PlanViewLaser.global_transform = Transform(pp["planviewlaser"]["global_transform"].basis.slerp(pp1["planviewlaser"]["global_transform"].basis, lam), 
														lerp(pp["planviewlaser"]["global_transform"].origin, pp1["planviewlaser"]["global_transform"].origin, lam)) 
			$PlanViewLaser/Length.scale.z = lerp(pp["planviewlaser"]["length"], pp1["planviewlaser"]["length"], lam)
			$PlanViewLaser.visible = true
		else:
			$PlanViewLaser.visible = false



puppet func bouncedoppelgangerposition(bouncebackID, positiondict):
	get_parent().get_parent().playerMe.rpc_unreliable_id(bouncebackID, "setdoppelgangerposition", positiondict)

puppet func setdoppelgangerposition(positiondict):
	var doppelganger = get_parent().get_parent().playerMe.doppelganger
	if is_instance_valid(doppelganger):
		doppelganger.setavatarposition(positiondict)

remote func playvoicerecording(wavrecording):
	print("playing recording ", wavrecording.size()) 
	var stream = AudioStreamSample.new()
	stream.format = AudioStreamSample.FORMAT_16_BITS
	stream.data = wavrecording
	stream.mix_rate = 44100
	stream.stereo = true
	$HandRight/AudioStreamPlayer3D.stream = stream
	$HandRight/AudioStreamPlayer3D.play()
