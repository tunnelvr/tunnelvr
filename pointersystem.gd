extends Node

onready var sketchsystem = get_node("/root/Spatial/SketchSystem")
onready var planviewsystem = get_node("/root/Spatial/PlanViewSystem")
onready var materialsystem = get_node("/root/Spatial/MaterialSystem")
onready var gripmenu = get_node("/root/Spatial/GuiSystem/GripMenu")

onready var playerMe = get_parent()
onready var headcam = playerMe.get_node('HeadCam')
onready var handright = playerMe.get_node("HandRight")
onready var handrightcontroller = playerMe.get_node("HandRightController")
onready var guipanel3d = get_node("/root/Spatial/GuiSystem/GUIPanel3D")

onready var LaserOrient = get_node("/root/Spatial/BodyObjects/LaserOrient") 
onready var LaserSelectLine = get_node("/root/Spatial/BodyObjects/LaserSelectLine") 

var viewport_point = null

onready var activelaserroot = LaserOrient
var pointerplanviewtarget = null
var pointertarget = null
var pointertargettype = "none"
var pointertargetwall = null
var pointertargetpoint = Vector3(0, 0, 0)
var gripbuttonpressused = false
var laserselectlinelogicallyvisible = false

var activetargetnode = null
var activetargetnodewall = null
var activetargetwall = null
var activetargettube = null
var activetargettubesectorindex = -1
var activetargetxcflatshell = null
var prevactivetargettubetohideonsecondselect = null
var activetargetnodetriggerpulling = false

var activetargetwallgrabbed = null
var activetargetwallgrabbedtransform = null
var activetargetwallgrabbedorgtransform = null
var activetargetwallgrabbeddispvector = null
var activetargetwallgrabbedpoint = null
var activetargetwallgrabbedpointoffset = null
var activetargetwallgrabbedlocalpoint = null
var activetargetwallgrabbedlaserroottrans = null

var intermediatepointplanetubename = ""
var intermediatepointplanesectorindex = -1
var intermediatepointplanelambda = -1.0
var intermediatepointpicked = null

const handflickmotiongestureposition_normal = 0
const handflickmotiongestureposition_shortpos = 1
const handflickmotiongestureposition_shortpos_length = 0.25
const handflickmotiongestureposition_gone = 2

func clearpointertargetmaterial():
	if pointertargettype == "XCnode" and pointertarget != null:
		if pointertargetwall != null and pointertargetwall.drawingtype == DRAWING_TYPE.DT_CENTRELINE:
			var pointertargetnonplan = pointertargetwall.get_node("XCnodes").get_node(pointertarget.get_name())
			var pointertargetplanview = pointertargetwall.get_node("XCnodes_PlanView").get_node(pointertarget.get_name())
			pointertargetnonplan.get_node("CollisionShape/MeshInstance").set_surface_material(0, materialsystem.nodematerial("selected" if pointertarget == activetargetnode else "station"))
			if pointertarget != activetargetnode:
				pointertargetnonplan.get_node("StationLabel").visible = false
			pointertargetplanview.get_node("CollisionShape/MeshInstance").set_surface_material(0, materialsystem.nodematerial("selected" if pointertarget == activetargetnode else "station"))
		else:
			pointertarget.get_node("CollisionShape/MeshInstance").set_surface_material(0, materialsystem.nodematerial("selected" if pointertarget == activetargetnode else clearednodematerialtype(pointertarget, pointertargetwall == activetargetwall)))
	if pointertargettype == "IntermediateNode":
		pointertarget.get_node("CollisionShape/MeshInstance").set_surface_material(0, materialsystem.nodematerial("nodeintermediate"))
	if pointertargettype == "IntermediatePointView":
		pointertarget.get_node("CollisionShape/MeshInstance").set_surface_material(0, materialsystem.xcdrawingmaterial("intermediateplane"))

	if (pointertargettype == "XCdrawing" or pointertargettype == "XCnode") and pointertargetwall.drawingtype == DRAWING_TYPE.DT_XCDRAWING:
		if pointertargetwall == activetargetwall:
			pointertargetwall.get_node("XCdrawingplane/CollisionShape/MeshInstance").set_surface_material(0, materialsystem.xcdrawingmaterial("active"))
			pointertargetwall.updateformetresquaresscaletexture()
		else:
			pointertargetwall.get_node("XCdrawingplane/CollisionShape/MeshInstance").set_surface_material(0, materialsystem.xcdrawingmaterial("normal"))
	if pointertargettype == "GripMenuItem":
		gripmenu.cleargripmenupointer(pointertarget)

			
func setpointertargetmaterial():
	if pointertargettype == "XCnode":
		if pointertargetwall != null and pointertargetwall.drawingtype == DRAWING_TYPE.DT_CENTRELINE:
			var pointertargetnonplan = pointertargetwall.get_node("XCnodes").get_node(pointertarget.get_name())
			var pointertargetplanview = pointertargetwall.get_node("XCnodes_PlanView").get_node(pointertarget.get_name())
			pointertargetnonplan.get_node("CollisionShape/MeshInstance").set_surface_material(0, materialsystem.nodematerial("selected_highlight" if pointertarget == activetargetnode else "highlight"))
			pointertargetnonplan.get_node("StationLabel").visible = true
			pointertargetplanview.get_node("CollisionShape/MeshInstance").set_surface_material(0, materialsystem.nodematerial("selected_highlight" if pointertarget == activetargetnode else "highlight"))
		else:
			pointertarget.get_node("CollisionShape/MeshInstance").set_surface_material(0, materialsystem.nodematerial("selected_highlight" if pointertarget == activetargetnode else "highlight"))

	if pointertargettype == "IntermediateNode":
		pointertarget.get_node("CollisionShape/MeshInstance").set_surface_material(0, materialsystem.nodematerial("highlight"))
			
	if pointertargettype == "IntermediatePointView":
		pointertarget.get_node("CollisionShape/MeshInstance").set_surface_material(0, materialsystem.xcdrawingmaterial("intermediateplanehighlight"))
	
	if (pointertargettype == "XCdrawing" or pointertargettype == "XCnode") and pointertargetwall.drawingtype == DRAWING_TYPE.DT_XCDRAWING:
		pointertargetwall.get_node("XCdrawingplane/CollisionShape/MeshInstance").set_surface_material(0, materialsystem.xcdrawingmaterial("highlight"))
		pointertargetwall.updateformetresquaresscaletexture()
	if pointertargettype == "GripMenuItem":
		gripmenu.setgripmenupointer(pointertarget)


func clearednodematerialtype(xcn, bwallactive):
	var ch = xcn.get_name()[0]
	if bwallactive:
		if ch == "r":
			return "nodepthtesthole"
		elif ch == "a" or ch == "k":
			return "nodepthtestknot"
		else:
			return "nodepthtest"
	if ch == "r":
		return "normalhole"
	elif ch == "a" or ch == "k":
		return "normalknot"
	else:
		return "normal"

func clearactivetargetnode():
	if activetargetnode != null:
		if activetargetnodewall != null and activetargetnodewall.drawingtype == DRAWING_TYPE.DT_CENTRELINE:
			var activetargetnodenonplan = activetargetnodewall.get_node("XCnodes").get_node(activetargetnode.get_name())
			var activetargetnodeplanview = activetargetnodewall.get_node("XCnodes_PlanView").get_node(activetargetnode.get_name())
			activetargetnodenonplan.get_node("CollisionShape/MeshInstance").set_surface_material(0, materialsystem.nodematerial("station"))
			activetargetnodeplanview.get_node("CollisionShape/MeshInstance").set_surface_material(0, materialsystem.nodematerial("station"))
			activetargetnodenonplan.get_node("StationLabel").visible = false
		else:
			activetargetnode.get_node("CollisionShape/MeshInstance").set_surface_material(0, materialsystem.nodematerial(clearednodematerialtype(activetargetnode, activetargetnodewall == activetargetwall)))
	activetargetnode = null
	activetargetnodewall = null
	activelaserroot.get_node("LaserSpot").set_surface_material(0, materialsystem.lasermaterialN((1 if activetargetnode != null else 0) + (2 if pointertarget == null else 0)))

	
func setactivetargetnode(newactivetargetnode):
	clearactivetargetnode()
	activetargetnode = newactivetargetnode
	assert (targettype(activetargetnode) == "XCnode")
	activetargetnodewall = targetwall(activetargetnode, "XCnode")
	if activetargetnode != pointertarget:
		activetargetnode.get_node("CollisionShape/MeshInstance").set_surface_material(0, materialsystem.nodematerial("selected"))
	activelaserroot.get_node("LaserSpot").set_surface_material(0, materialsystem.lasermaterialN((1 if activetargetnode != null else 0) + (2 if pointertarget == null else 0)))
	setpointertargetmaterial()

func raynormalcollisionmask():
	if planviewsystem.planviewcontrols.get_node("CheckBoxCentrelinesVisible").pressed:
		return CollisionLayer.CLV_MainRayAll
	else:
		return CollisionLayer.CLV_MainRayAllNoCentreline

func setactivetargetwall(newactivetargetwall):
	if activetargetwall != null and activetargetwall.drawingtype == DRAWING_TYPE.DT_XCDRAWING:
		activetargetwall.get_node("XCdrawingplane/CollisionShape/MeshInstance").set_surface_material(0, materialsystem.xcdrawingmaterial("normal"))
		activetargetwall.get_node("PathLines").set_surface_material(0, materialsystem.pathlinematerial("normal"))
		for xcnode in activetargetwall.get_node("XCnodes").get_children():
			xcnode.get_node("CollisionShape/MeshInstance").set_surface_material(0, materialsystem.nodematerial("selected" if xcnode == activetargetnode else clearednodematerialtype(xcnode, false)))
	
	activetargetwall = newactivetargetwall
	activetargetwallgrabbedtransform = null
	if (activetargetwall == get_node("/root/Spatial/PlanViewSystem")):
		print("Waaat")

	if activetargetwall != null and activetargetwall.drawingtype == DRAWING_TYPE.DT_XCDRAWING:
		print("newactivetargetwall ", activetargetwall, " nodes ", activetargetwall.get_node("XCnodes").get_child_count())
	else:
		print("newactivetargetwall notdrawing ", activetargetwall)
	
	LaserOrient.get_node("RayCast").collision_mask = raynormalcollisionmask()
	if activetargetwall != null and activetargetwall.drawingtype == DRAWING_TYPE.DT_XCDRAWING:
		if not activetargetwall.get_node("XCdrawingplane").visible:
			sketchsystem.actsketchchange([{"xcvizstates":{activetargetwall.get_name():DRAWING_TYPE.VIZ_XCD_PLANE_AND_NODES_VISIBLE}}])
		activetargetwall.get_node("XCdrawingplane/CollisionShape/MeshInstance").set_surface_material(0, materialsystem.xcdrawingmaterial("active"))
		activetargetwall.get_node("PathLines").set_surface_material(0, materialsystem.pathlinematerial("nodepthtest"))
		for xcnode in activetargetwall.get_node("XCnodes").get_children():
			if xcnode != activetargetnode:
				xcnode.get_node("CollisionShape/MeshInstance").set_surface_material(0, materialsystem.nodematerial(clearednodematerialtype(xcnode, true)))
		if len(activetargetwall.nodepoints) != 0:
			LaserOrient.get_node("RayCast").collision_mask = CollisionLayer.CLV_MainRayXC

	if activetargetwall != null and activetargetwall.drawingtype == DRAWING_TYPE.DT_FLOORTEXTURE:
		assert (false)
		
func _ready():
	handrightcontroller.connect("button_pressed", self, "_on_button_pressed")
	handrightcontroller.connect("button_release", self, "_on_button_release")

func targettype(target):
	if not is_instance_valid(target):
		return "none"
	var targetname = target.get_name()
	if targetname == "GUIPanel3D":
		return "GUIPanel3D"
	if targetname == "PlanView":
		return "PlanView"
	if targetname == "XCflatshell":
		return "XCflatshell"
	var targetparent = target.get_parent()
	if targetname == "XCdrawingplane":
		assert (targetparent.drawingtype != DRAWING_TYPE.DT_CENTRELINE)
		return "XCdrawing"
	if targetparent.get_name() == "XCtubesectors":
		return "XCtubesector"
	if targetparent.get_name() == "XCnodes":
		return "XCnode"
	if targetparent.get_name() == "XCnodes_PlanView":
		return "XCnode"
	if targetparent.get_parent().get_name() == "GripMenu":
		return "GripMenuItem"
	if targetparent.get_name() == "IntermediatePointView":
		return "IntermediatePointView"
	if targetparent.get_name() == "PathLines" and activetargetnode == null:
		return "IntermediateNode"
	return "unknown"
		
func targetwall(target, targettype):
	if targettype == "XCdrawing" or targettype == "Papersheet":
		return target.get_parent()
	if targettype == "XCnode":
		return target.get_parent().get_parent()
	if targettype == "XCtubesector":
		return target.get_parent().get_parent()
	if targettype == "XCflatshell":
		return target.get_parent()
	if targettype == "PlanView":
		return target.get_parent()
	if targettype == "IntermediateNode":
		return target.get_parent().get_parent()
	return null
			
func clearpointertarget():
	if pointertarget == guipanel3d:
		guipanel3d.guipanelreleasemouse()
	clearpointertargetmaterial()
	pointertarget = null
	pointertargettype = "none"
	pointertargetwall = null

func set_handflickmotiongestureposition(lhandflickmotiongestureposition):
	Tglobal.handflickmotiongestureposition = lhandflickmotiongestureposition
	if Tglobal.handflickmotiongestureposition == 0:
		activelaserroot.get_node("LaserSpot").visible = false
	elif Tglobal.handflickmotiongestureposition == 1:
		activelaserroot.get_node("LaserSpot").set_surface_material(0, materialsystem.lasermaterialN((1 if activetargetnode != null else 0) + 2))

func setpointertarget(laserroot, raycast, pointertargetshortdistance):
	var newpointertarget = raycast.get_collider() if raycast != null else null
	if newpointertarget != null:
		if newpointertarget.is_queued_for_deletion():
			newpointertarget = null
		elif newpointertarget.get_parent().is_queued_for_deletion():
			newpointertarget = null
		elif newpointertarget.get_parent().get_parent().is_queued_for_deletion():
			newpointertarget = null
	var newpointertargetpoint = null
	if newpointertarget != null:
		newpointertargetpoint = raycast.get_collision_point()
		if pointertargetshortdistance != -1.0:
			var pointertargetvector = newpointertargetpoint - raycast.global_transform.origin
			var pointertargetdistance = (-raycast.global_transform.basis.z).dot(pointertargetvector)
			if pointertargetdistance > pointertargetshortdistance:
				newpointertargetpoint = raycast.global_transform.origin + (-raycast.global_transform.basis.z)*pointertargetshortdistance
				newpointertarget = null
				
	elif pointertargetshortdistance != -1.0:
		newpointertargetpoint = raycast.global_transform.origin + (-raycast.global_transform.basis.z)*pointertargetshortdistance

	if newpointertarget != pointertarget:
		if pointertarget == guipanel3d:
			guipanel3d.guipanelreleasemouse()
		clearpointertargetmaterial()
		pointertarget = newpointertarget
		pointertargettype = targettype(pointertarget)
		pointertargetwall = targetwall(pointertarget, pointertargettype)
		setpointertargetmaterial()
		
		if activetargetwall == null and pointertargettype == "XCdrawing" and pointertargetwall.drawingtype == DRAWING_TYPE.DT_XCDRAWING and len(pointertargetwall.nodepoints) == 0 and activetargetnode == null:
			print("setting blank wall active")
			setactivetargetwall(pointertargetwall)
		
		laserroot.get_node("LaserSpot").visible = (pointertargettype == "XCdrawing") or \
												  (pointertargettype == "XCtubesector") or \
												  (pointertargettype == "XCflatshell") or \
												  (pointertargettype == "IntermediatePointView") or \
												  (pointertargettype == "none" and pointertargetshortdistance != -1.0)
		laserroot.get_node("LaserSpot").set_surface_material(0, materialsystem.lasermaterialN((1 if activetargetnode != null else 0) + (2 if pointertarget == null else 0)))
			
		if activetargetnode != null and pointertargetwall != null:
			laserselectlinelogicallyvisible = false
			if activetargetnodewall.drawingtype == DRAWING_TYPE.DT_CENTRELINE:
				laserselectlinelogicallyvisible = pointertargetwall != null and pointertargettype == "XCdrawing" and pointertargetwall.drawingtype == DRAWING_TYPE.DT_FLOORTEXTURE
			elif activetargetnodewall.drawingtype == DRAWING_TYPE.DT_XCDRAWING:
				if pointertargettype == "XCnode":
					laserselectlinelogicallyvisible = (pointertargetwall.drawingtype == DRAWING_TYPE.DT_XCDRAWING) and (pointertarget != activetargetnode)
				elif pointertargettype == "XCdrawing" and pointertargetwall == activetargetnodewall:
					laserselectlinelogicallyvisible = true
			elif activetargetnodewall.drawingtype == DRAWING_TYPE.DT_ROPEHANG:
				if pointertargettype == "XCnode":
					laserselectlinelogicallyvisible = (pointertargetwall.drawingtype == DRAWING_TYPE.DT_ROPEHANG) and (pointertarget != activetargetnode)
				elif pointertargettype == "XCdrawing":
					laserselectlinelogicallyvisible = false
				elif Tglobal.handflickmotiongestureposition == 1:
					laserselectlinelogicallyvisible = (pointertargettype == "none" or pointertargettype == "XCtubesector")
		elif pointertargettype == "IntermediatePointView":
			laserselectlinelogicallyvisible = true
		elif activetargetnodewall != null and activetargetnodewall.drawingtype == DRAWING_TYPE.DT_ROPEHANG:
			laserselectlinelogicallyvisible = (pointertargettype == "none" and Tglobal.handflickmotiongestureposition == 1)
		LaserSelectLine.visible = laserselectlinelogicallyvisible
		
	pointertargetpoint = newpointertargetpoint
	if is_instance_valid(pointertarget) and pointertarget == guipanel3d:
		guipanel3d.guipanelsendmousemotion(pointertargetpoint, LaserOrient.global_transform, (handrightcontroller.is_button_pressed(BUTTONS.HT_PINCH_INDEX_FINGER) if Tglobal.questhandtrackingactive else handrightcontroller.is_button_pressed(BUTTONS.VR_TRIGGER)) or Input.is_mouse_button_pressed(BUTTON_LEFT))

	if pointertargetpoint != null:
		laserroot.get_node("LaserSpot").global_transform.origin = pointertargetpoint
		laserroot.get_node("Length").scale.z = -laserroot.get_node("LaserSpot").translation.z
	else:
		laserroot.get_node("Length").scale.z = -laserroot.get_node("RayCast").cast_to.z
		
	if laserroot == LaserOrient:
		var FloorLaserSpot = get_node("/root/Spatial/BodyObjects/FloorLaserSpot")
		if FloorLaserSpot.visible:
			if pointertargetpoint != null and not (pointertargettype == "XCdrawing" and pointertargetwall.drawingtype == DRAWING_TYPE.DT_FLOORTEXTURE) and (pointertarget != guipanel3d) and (pointertargettype != "PlanView"):
				FloorLaserSpot.get_node("RayCast").transform.origin = pointertargetpoint
				FloorLaserSpot.get_node("RayCast").force_raycast_update()
				if FloorLaserSpot.get_node("RayCast").is_colliding():
					FloorLaserSpot.get_node("FloorSpot").transform.origin = FloorLaserSpot.get_node("RayCast").get_collision_point()
					FloorLaserSpot.get_node("FloorSpot").visible = true
				else:
					FloorLaserSpot.get_node("FloorSpot").visible = false
			else:
				FloorLaserSpot.get_node("FloorSpot").visible = false

	if activetargetnodetriggerpulling:
		# solve activetargetnode.global_transform.origin + a*activetargetnode.global_transform.basis.z = LaserOrient.transform.origin - b*LaserOrient.transform.basis.z
		var gp = LaserOrient.transform.origin - activetargetnode.global_transform.origin
		# solve gp = a*activetargetnode.global_transform.basis.z + b*LaserOrient.transform.basis.z
		#gp . activetargetnode.global_transform.basis.z = a + b*LaserOrient.transform.basis.z . activetargetnode.global_transform.basis.z
		#gp . LaserOrient.transform.basis.z = a*activetargetnode.global_transform.basis.z . LaserOrient.transform.basis.z + b
		var ldots = activetargetnode.global_transform.basis.z.dot(LaserOrient.transform.basis.z)
		var gpdnd = gp.dot(activetargetnode.global_transform.basis.z)
		var gpdlz = gp.dot(LaserOrient.transform.basis.z)
		# gpdnd = a + b*ldots; gpdlz = a*ldots + b
		# gpdnd = a + gpdlz*ldots - a*ldots*ldots
		# a*(1 - ldots*ldots) = gpdnd - gpdlz*ldots
		var aden = 1 - ldots*ldots
		if abs(aden) > 0.01:
			var a = (gpdnd - gpdlz*ldots)/aden
			var b = gpdlz - a*ldots
			var av = activetargetnode.global_transform.origin + a*activetargetnode.global_transform.basis.z
			var bv = LaserOrient.transform.origin - b*LaserOrient.transform.basis.z
			var skewdist = av.distance_to(bv)
			LaserSelectLine.transform = activetargetnode.global_transform
			LaserSelectLine.get_node("Scale").scale.z = -a
			LaserSelectLine.visible = (skewdist < 0.1)
		else:
			LaserSelectLine.visible = false
		
	elif laserselectlinelogicallyvisible:
		LaserSelectLine.visible = not activetargetnodetriggerpulling
		var lslfrom = null
		if pointertarget != null and activetargetnode != null:
			lslfrom = activetargetnode.global_transform.origin
		elif pointertargettype == "IntermediatePointView":
			lslfrom = get_node("/root/Spatial/BodyObjects/IntermediatePointView/IntermediatePointPlaneStartingMarker").transform.origin
		elif activetargetnode != null and pointertargettype == "none" and Tglobal.handflickmotiongestureposition == 1:
			lslfrom = activetargetnode.global_transform.origin
		else:
			LaserSelectLine.visible = false
		if lslfrom != null:
			LaserSelectLine.global_transform.origin = pointertargetpoint
			LaserSelectLine.get_node("Scale").scale.z = pointertargetpoint.distance_to(lslfrom)
			LaserSelectLine.global_transform = laserroot.get_node("LaserSpot").global_transform.looking_at(lslfrom, Vector3(0,1,0))

func _on_button_pressed(p_button):
	var gripbuttonheld = handright.gripbuttonheld
	#print("pppp ", pointertargetpoint, " ", [activetargetnode, pointertargettype, " pbutton", p_button])
	if Tglobal.questhandtrackingactive:
		gripbuttonheld = handrightcontroller.is_button_pressed(BUTTONS.HT_PINCH_MIDDLE_FINGER)
		if p_button == BUTTONS.HT_PINCH_RING_FINGER:
			if handrightcontroller.is_button_pressed(BUTTONS.HT_PINCH_PINKY):
				buttonpressed_vrby(false)
		elif p_button == BUTTONS.HT_PINCH_PINKY:
			if handrightcontroller.is_button_pressed(BUTTONS.HT_PINCH_RING_FINGER):
				buttonpressed_vrby(false)
		elif Tglobal.controlslocked:
			print("Controls locked")	
		elif p_button == BUTTONS.HT_PINCH_INDEX_FINGER:
			buttonpressed_vrtrigger(gripbuttonheld)
		elif p_button == BUTTONS.HT_PINCH_MIDDLE_FINGER:
			buttonpressed_vrgrip()
	else:
		if p_button == BUTTONS.VR_BUTTON_BY:
			buttonpressed_vrby(gripbuttonheld)
		elif Tglobal.controlslocked:
			print("Controls locked")	
		elif p_button == BUTTONS.VR_GRIP:
			buttonpressed_vrgrip()
		elif p_button == BUTTONS.VR_TRIGGER:
			buttonpressed_vrtrigger(gripbuttonheld)
		elif p_button == BUTTONS.VR_PAD:
			buttonpressed_vrpad(gripbuttonheld, handright.joypos)

func _on_button_release(p_button):
	if Tglobal.controlslocked:
		print("Controls locked")
	elif Tglobal.questhandtrackingactive:
		if p_button == BUTTONS.HT_PINCH_MIDDLE_FINGER:
			buttonreleased_vrgrip()
		elif p_button == BUTTONS.HT_PINCH_INDEX_FINGER:
			buttonreleased_vrtrigger()

	else:
		if p_button == BUTTONS.VR_GRIP:
			buttonreleased_vrgrip()
		elif p_button == BUTTONS.VR_TRIGGER:
			buttonreleased_vrtrigger()
		elif p_button == BUTTONS.VR_BUTTON_BY:
			buttonreleased_vrby()


	
func buttonreleased_vrby():
	if playerMe.ovr_guardian_system != null:
		playerMe.ovr_guardian_system.request_boundary_visible(false)

func buttonpressed_vrby(gripbuttonheld):
	#if playerMe.ovr_guardian_system != null:
	#	print(" ovr_guardian_system.get_boundary_geometry() == " + str(playerMe.ovr_guardian_system.get_boundary_geometry()));
	#	print(" ovr_guardian_system.get_boundary_visible() == " + str(playerMe.ovr_guardian_system.get_boundary_visible()));
	#	playerMe.ovr_guardian_system.request_boundary_visible(true)
	#	print(" ovr_guardian_system.get_boundary_oriented_bounding_box() == " + str(playerMe.ovr_guardian_system.get_boundary_oriented_bounding_box()));


	if Tglobal.controlslocked:
		if not guipanel3d.visible:
			guipanel3d.toggleguipanelvisibility(LaserOrient.global_transform)
		else:
			print("controls locked")
	elif planviewsystem.visible and (pointerplanviewtarget != null or pointertargettype == "PlanView"):
		sketchsystem.actsketchchange([{"planview": { "visible":true, "planviewactive":not planviewsystem.planviewactive }} ])
	else:
		guipanel3d.toggleguipanelvisibility(LaserOrient.global_transform)

func buttonpressed_vrgrip():
	gripbuttonpressused = false
	if pointertargettype == "XCtubesector":
		activetargettube = pointertargetwall
		activetargettubesectorindex = pointertarget.get_index()
		if activetargettubesectorindex < len(activetargettube.xcsectormaterials):
			var tubesectormaterialname = activetargettube.xcsectormaterials[activetargettubesectorindex]
			materialsystem.updatetubesectormaterial(activetargettube.get_node("XCtubesectors").get_child(activetargettubesectorindex), tubesectormaterialname, true)
			if activetargettube.get_node("PathLines").mesh == null:
				activetargettube.updatetubelinkpaths(sketchsystem)
			activetargettube.get_node("PathLines").visible = true
			activetargettube.get_node("PathLines").set_surface_material(0, materialsystem.pathlinematerial("nodepthtest"))
			if Tglobal.hidecavewallstoseefloors:
				if prevactivetargettubetohideonsecondselect != null:
					prevactivetargettubetohideonsecondselect.visible = false
				pointertarget.visible = true
				prevactivetargettubetohideonsecondselect = pointertarget
				
		else:
			print("Wrong: sector index not match sectors in tubedata")

	elif pointertargettype == "XCflatshell":
		activetargetxcflatshell = pointertargetwall
		var xcflatshellmaterialname = activetargetxcflatshell.xcflatshellmaterial
		materialsystem.updatetubesectormaterial(activetargetxcflatshell.get_node("XCflatshell"), xcflatshellmaterialname, true)

	gripmenu.gripmenuon(LaserOrient.global_transform, pointertargetpoint, pointertargetwall, pointertargettype, activetargettube, activetargettubesectorindex, activetargetwall, activetargetnode)
	
var initialsequencenodename = null
var initialsequencenodenameP = null
func buttonpressed_vrtrigger(gripbuttonheld):
	initialsequencenodenameP = initialsequencenodename
	initialsequencenodename = null

	if Tglobal.handflickmotiongestureposition == 1 and activetargetnodewall != null and activetargetnodewall.drawingtype == DRAWING_TYPE.DT_ROPEHANG and \
			(pointertargettype == "none" or pointertargettype == "XCtubesector" or pointertargettype == "XCflatshell"):
		var newnodepoint = activetargetnodewall.global_transform.xform_inv(pointertargetpoint)
		if gripbuttonheld:
			if activetargetnode.get_name()[0] == ("k" if pointertargettype == "none" else "a"):
				var movetopoint = activetargetnodewall.global_transform.xform_inv(pointertargetpoint)				
				sketchsystem.actsketchchange([{
					"name":activetargetnodewall.get_name(), 
					"prevnodepoints":{ activetargetnode.get_name():activetargetnode.translation }, 
					"nextnodepoints":{ activetargetnode.get_name():newnodepoint } 
				}])
				clearactivetargetnode()
		else:
			var newnodename = activetargetnodewall.newuniquexcnodename("k" if pointertargettype == "none" else "a")
			var xcdata = { "name":activetargetnodewall.get_name(), 
						   "prevnodepoints":{ }, 
						   "nextnodepoints":{ newnodename:newnodepoint } 
						 }
			xcdata["prevonepathpairs"] = [ ]
			xcdata["newonepathpairs"] = [ activetargetnode.get_name(), newnodename]
			sketchsystem.actsketchchange([xcdata])
			if newnodename[0] == "k":
				setactivetargetnode(activetargetnodewall.get_node("XCnodes").get_node(newnodename))
			else:
				clearactivetargetnode()
	elif not is_instance_valid(pointertarget):
		pass
		
	elif pointertarget == guipanel3d:
		pass  # done in _process()

	elif pointertarget.has_method("jump_up"):
		pointertarget.jump_up()

	# grip click moves node on xcwall
	elif gripbuttonheld and activetargetnode != null and pointertargettype == "XCdrawing" and pointertargetwall == activetargetnodewall:
		var movetopoint = activetargetnodewall.global_transform.xform_inv(pointertargetpoint)
		movetopoint.z = 0.0
		sketchsystem.actsketchchange([{
					"name":activetargetnodewall.get_name(), 
					"prevnodepoints":{ activetargetnode.get_name():activetargetnode.translation }, 
					"nextnodepoints":{ activetargetnode.get_name():movetopoint } 
				}])
		if activetargetnodewall.drawingtype == DRAWING_TYPE.DT_XCDRAWING:
			activetargetnodewall.expandxcdrawingscale(pointertargetpoint)
		clearactivetargetnode()
		
	# reselection when selected on grip deletes the node		
	elif gripbuttonheld and activetargetnode != null and pointertarget == activetargetnode and (activetargetnodewall.drawingtype != DRAWING_TYPE.DT_CENTRELINE):
		if len(activetargetnodewall.nodepoints) == 1:
			LaserOrient.get_node("RayCast").collision_mask = raynormalcollisionmask()
		var xcname = activetargetnodewall.get_name()
		var nodename = activetargetnode.get_name()
		var xcdata = { "name":xcname, 
					   "prevnodepoints":{ nodename:activetargetnode.translation }, 
					   "nextnodepoints":{ } 
					 }
		var prevonepathpairs = [ ]
		for j in range(0, len(activetargetnodewall.onepathpairs), 2):
			if (activetargetnodewall.onepathpairs[j] == nodename) or (activetargetnodewall.onepathpairs[j+1] == nodename):
				prevonepathpairs.push_back(activetargetnodewall.onepathpairs[j])
				prevonepathpairs.push_back(activetargetnodewall.onepathpairs[j+1])
		if len(prevonepathpairs) != 0:
			xcdata["prevonepathpairs"] = prevonepathpairs
			xcdata["newonepathpairs"] = [ ]
		var xcdatalist = [ xcdata ]
		
		for xctube in activetargetnodewall.xctubesconn:
			var prevdrawinglinks = [ ]
			var m = 0 if xcname == xctube.xcname0 else 1
			for j in range(0, len(xctube.xcdrawinglink), 2):
				if xctube.xcdrawinglink[j+m] == nodename:
					prevdrawinglinks.push_back(xctube.xcdrawinglink[j])
					prevdrawinglinks.push_back(xctube.xcdrawinglink[j+1])
					prevdrawinglinks.push_back(xctube.xcsectormaterials[j/2])
					prevdrawinglinks.push_back(xctube.xclinkintermediatenodes[j/2] if xctube.xclinkintermediatenodes != null else null)
			if len(prevdrawinglinks) != 0:
				var xctdata = { "tubename":xctube.get_name(), 
								"xcname0":xctube.xcname0, 
								"xcname1":xctube.xcname1,
								"prevdrawinglinks":prevdrawinglinks,
								"newdrawinglinks":[ ] 
							  }
				xcdatalist.push_back(xctdata)

		clearactivetargetnode()
		clearpointertarget()
		activelaserroot.get_node("LaserSpot").visible = false
		sketchsystem.actsketchchange(xcdatalist)
		#Tglobal.soundsystem.quicksound("BlipSound", pointertargetpoint)

	elif activetargetnode != null and pointertarget == activetargetnode:
		clearactivetargetnode()

	elif activetargetnode == null and activetargetnodewall == null and pointertargettype == "XCtubesector":
		var pointertargettube = pointertargetwall
		if Tglobal.handflickmotiongestureposition == 1:
			var xcdata = { "name":sketchsystem.uniqueXCname("r"), 
						   "drawingtype":DRAWING_TYPE.DT_ROPEHANG,
						   "transformpos":Transform(),
						   "prevnodepoints":{ },
						   "nextnodepoints":{"a0":pointertargetpoint} }
			sketchsystem.actsketchchange([xcdata])
			var xcrope = sketchsystem.get_node("XCdrawings").get_node(xcdata["name"])
			setactivetargetnode(xcrope.get_node("XCnodes").get_node("a0"))

		elif pointertargettube.get_node("PathLines").visible:
			var ipbasis = pointertargettube.intermedpointplanebasis(pointertargetpoint)
			var xcdrawing0 = sketchsystem.get_node("XCdrawings").get_node(pointertargettube.xcname0)
			var xcdrawing1 = sketchsystem.get_node("XCdrawings").get_node(pointertargettube.xcname1)
			var xcdrawing0nodes = xcdrawing0.get_node("XCnodes")
			var xcdrawing1nodes = xcdrawing1.get_node("XCnodes")
			intermediatepointplanesectorindex = pointertarget.get_index()
			var jA = intermediatepointplanesectorindex*2
			if jA < len(pointertargettube.xcdrawinglink):
				var p0 = xcdrawing0nodes.get_node(pointertargettube.xcdrawinglink[jA]).global_transform.origin
				var p1 = xcdrawing1nodes.get_node(pointertargettube.xcdrawinglink[jA+1]).global_transform.origin
				intermediatepointplanelambda = inverse_lerp(ipbasis.z.dot(p0), ipbasis.z.dot(p1), ipbasis.z.dot(pointertargetpoint))
				var dv = pointertargettube.intermediatenodelerp(intermediatepointplanesectorindex, intermediatepointplanelambda)
				var pc = pointertargettube.intermedpointpos(p0, p1, dv)

				var jB = (jA + 2) % len(pointertargettube.xcdrawinglink)
				var intermediatepointplanesectorindexB = int(jB/2)
				var p0B = xcdrawing0nodes.get_node(pointertargettube.xcdrawinglink[jB]).global_transform.origin
				var p1B = xcdrawing1nodes.get_node(pointertargettube.xcdrawinglink[jB+1]).global_transform.origin
				var intermediatepointplanelambdaB = inverse_lerp(ipbasis.z.dot(p0), ipbasis.z.dot(p1), ipbasis.z.dot(pointertargetpoint))
				var dvB = pointertargettube.intermediatenodelerp(intermediatepointplanesectorindexB, intermediatepointplanelambdaB)
				var pcB = pointertargettube.intermedpointpos(p0B, p1B, dvB)
				
				if jB != jA and pointertargetpoint.distance_to(pcB) < pointertargetpoint.distance_to(pc):
					intermediatepointplanesectorindex = intermediatepointplanesectorindexB
					p0 = p0B
					p1 = p1B
					dv = dvB
					pc = pcB

				var p = lerp(p0, p1, intermediatepointplanelambda)
				intermediatepointpicked = null
				if 0.01 < intermediatepointplanelambda and intermediatepointplanelambda < 0.99:
					var IntermediatePointView = get_node("/root/Spatial/BodyObjects/IntermediatePointView")
					IntermediatePointView.get_node("IntermediatePointPlane").transform = Transform(ipbasis, p)
					IntermediatePointView.visible = true
					IntermediatePointView.get_node("IntermediatePointPlane/CollisionShape").disabled = false
					IntermediatePointView.get_node("IntermediatePointPlaneStartingMarker").transform.origin = pc
					intermediatepointplanetubename = pointertargettube.get_name()

	
	elif pointertargettype == "IntermediateNode":
		var pointertargettube = pointertargetwall
		intermediatepointplanesectorindex = pointertargettube.decodeintermediatenodenamelinkindex(pointertarget.get_name())
		var j = intermediatepointplanesectorindex*2
		if j < len(pointertargettube.xcdrawinglink):
			var inodeindex = pointertargettube.decodeintermediatenodenamenodeindex(pointertarget.get_name())
			if inodeindex < len(pointertargettube.xclinkintermediatenodes[intermediatepointplanesectorindex]):
				intermediatepointpicked = pointertargettube.xclinkintermediatenodes[intermediatepointplanesectorindex][inodeindex]
				intermediatepointplanelambda = intermediatepointpicked.z
				var IntermediatePointView = get_node("/root/Spatial/BodyObjects/IntermediatePointView")
				var xcdrawing0 = sketchsystem.get_node("XCdrawings").get_node(pointertargettube.xcname0)
				var xcdrawing1 = sketchsystem.get_node("XCdrawings").get_node(pointertargettube.xcname1)
				var xcdrawing0nodes = xcdrawing0.get_node("XCnodes")
				var xcdrawing1nodes = xcdrawing1.get_node("XCnodes")
				var p0 = xcdrawing0nodes.get_node(pointertargettube.xcdrawinglink[j]).global_transform.origin
				var p1 = xcdrawing1nodes.get_node(pointertargettube.xcdrawinglink[j+1]).global_transform.origin
				var p = lerp(p0, p1, intermediatepointplanelambda)
				var ipbasis = pointertargettube.intermedpointplanebasis(p)
				IntermediatePointView.get_node("IntermediatePointPlane").transform = Transform(ipbasis, p)
				IntermediatePointView.visible = true
				IntermediatePointView.get_node("IntermediatePointPlane/CollisionShape").disabled = false
				IntermediatePointView.get_node("IntermediatePointPlaneStartingMarker").transform.origin = pointertargettube.intermedpointpos(p0, p1, intermediatepointpicked)
				intermediatepointplanetubename = pointertargettube.get_name()
			else:
				print("intermediate node ", pointertarget.get_name(), " on link with only ", len(pointertargettube.xclinkintermediatenodes[intermediatepointplanesectorindex]), " elements")
		else:
			print("intermediate node ", pointertarget.get_name(), " when there are only ", len(pointertargettube.xclinkintermediatenodes), " links")
	
	elif pointertargettype == "IntermediatePointView":
		var splinepointplanetube = sketchsystem.get_node("XCtubes").get_node_or_null(intermediatepointplanetubename)
		if splinepointplanetube != null:
			var IntermediatePointView = get_node("/root/Spatial/BodyObjects/IntermediatePointView")
			var dvd = IntermediatePointView.get_node("IntermediatePointPlane").transform.xform_inv(pointertargetpoint)
			print("dvd ", dvd, "  ", intermediatepointplanelambda) # assert(is_zero_approx(dvd.z)) -- thickness of the disk till we use a plane instead
			var nodename0 = splinepointplanetube["xcdrawinglink"][intermediatepointplanesectorindex*2]
			var nodename1 = splinepointplanetube["xcdrawinglink"][intermediatepointplanesectorindex*2+1]
			var newintermediatepoint = Vector3(dvd.x, dvd.y, intermediatepointplanelambda) if not gripbuttonheld else null
			if intermediatepointpicked != null or newintermediatepoint != null:
				var xctdata = { "tubename":intermediatepointplanetubename,
								"xcname0":splinepointplanetube.xcname0,
								"xcname1":splinepointplanetube.xcname1,
								"prevdrawinglinks":[ nodename0, nodename1, null, (null if intermediatepointpicked == null else [ intermediatepointpicked ]) ], 
								"newdrawinglinks":[ nodename0, nodename1, null, (null if newintermediatepoint == null else [ newintermediatepoint ]) ] 
							  }
				var xctuberedraw = {"xcvizstates":{ }, "updatetubeshells":[{"tubename":intermediatepointplanetubename, "xcname0":splinepointplanetube.xcname0, "xcname1":splinepointplanetube.xcname1 }] }
				sketchsystem.actsketchchange([xctdata, xctuberedraw])
				var xcdatashellholes = findconstructtubeshellholes([splinepointplanetube])
				if xcdatashellholes != null:
					sketchsystem.actsketchchange(xcdatashellholes)
				
			clearintermediatepointplaneview()
				
	elif pointertargettype == "Papersheet" or pointertargettype == "PlanView":
		clearactivetargetnode()
		var alaserspot = activelaserroot.get_node("LaserSpot")
		alaserspot.global_transform.origin = pointertargetpoint
		
		if pointertargettype == "PlanView":
			activetargetwallgrabbed = pointertargetwall.get_node("PlanView")
		else:
			activetargetwallgrabbed = pointertargetwall
			setactivetargetwall(pointertargetwall)
		assert(activetargetwallgrabbed == (pointertargetwall if pointertargettype == "Papersheet" else pointertargetwall.get_node("PlanView")))

		if gripbuttonheld:
			activetargetwallgrabbedtransform = alaserspot.global_transform.affine_inverse() * activetargetwallgrabbed.global_transform
			activetargetwallgrabbedpoint = alaserspot.global_transform.origin
			activetargetwallgrabbedlocalpoint = activetargetwallgrabbed.global_transform.affine_inverse() * alaserspot.global_transform.origin
			activetargetwallgrabbedpointoffset = alaserspot.global_transform.origin - activetargetwallgrabbed.global_transform.origin
		else:
			activetargetwallgrabbedtransform = alaserspot.global_transform.affine_inverse() * activetargetwallgrabbed.global_transform
			activetargetwallgrabbedpoint = null

			
	elif pointertargettype == "XCdrawing" and pointertargetwall.drawingtype == DRAWING_TYPE.DT_XCDRAWING:
		if pointertargetwall != activetargetwall:
			setactivetargetwall(pointertargetwall)
			
		if gripbuttonheld:
			pointertargetwall.expandxcdrawingscale(pointertargetpoint)
			if true or len(pointertargetwall.nodepoints) == 0:
				clearactivetargetnode()
				var alaserspot = activelaserroot.get_node("LaserSpot")
				alaserspot.global_transform.origin = pointertargetpoint
				activetargetwallgrabbed = activetargetwall
				activetargetwallgrabbedlaserroottrans = activelaserroot.global_transform
				activetargetwallgrabbedtransform = alaserspot.global_transform.affine_inverse() * activetargetwallgrabbed.global_transform
				activetargetwallgrabbedorgtransform = activetargetwallgrabbed.global_transform
				activetargetwallgrabbeddispvector = alaserspot.global_transform.origin - activelaserroot.global_transform.origin
				activetargetwallgrabbedpoint = alaserspot.global_transform.origin
				activetargetwallgrabbedlocalpoint = activetargetwallgrabbed.global_transform.affine_inverse() * alaserspot.global_transform.origin
				activetargetwallgrabbedpointoffset = alaserspot.global_transform.origin - activetargetwallgrabbed.global_transform.origin

		elif (activetargetnode != null and activetargetnodewall == pointertargetwall) or len(pointertargetwall.nodepoints) == 0:
			if len(pointertargetwall.nodepoints) == 0:
				LaserOrient.get_node("RayCast").collision_mask = CollisionLayer.CLV_MainRayXC 
				
			var newnodename = pointertargetwall.newuniquexcnodename("p")
			var newnodepoint = pointertargetwall.global_transform.xform_inv(pointertargetpoint)
			newnodepoint.z = 0.0
			var xcdata = { "name":pointertargetwall.get_name(), 
						   "prevnodepoints":{ }, 
						   "nextnodepoints":{ newnodename:newnodepoint } 
						 }
			if activetargetnode != null and activetargetnodewall == pointertargetwall:
				xcdata["prevonepathpairs"] = [ ]
				xcdata["newonepathpairs"] = [ activetargetnode.get_name(), newnodename]
			sketchsystem.actsketchchange([xcdata])
			setactivetargetnode(pointertargetwall.get_node("XCnodes").get_node(newnodename))
			if pointertargetwall.drawingtype == DRAWING_TYPE.DT_XCDRAWING:
				pointertargetwall.expandxcdrawingscale(pointertargetpoint)
				activetargetnodetriggerpulling = true
			#Tglobal.soundsystem.quicksound("ClickSound", pointertargetpoint)
			initialsequencenodename = initialsequencenodenameP
	
		else:
			pointertargetwall.expandxcdrawingscale(pointertargetpoint)

									
	elif activetargetnode != null and activetargetnodewall.drawingtype == DRAWING_TYPE.DT_CENTRELINE \
			and pointertargettype == "XCdrawing" and pointertargetwall.drawingtype == DRAWING_TYPE.DT_FLOORTEXTURE:

		var newnodename = pointertargetwall.newuniquexcnodename("p")
		var newnodepoint = pointertargetwall.global_transform.xform_inv(pointertargetpoint)
		newnodepoint.z = 0.0
		var xcndata = { "name":pointertargetwall.get_name(), 
						"prevnodepoints":{ }, 
						"nextnodepoints":{ newnodename:newnodepoint } 
					  }

		var xcname0_centreline = activetargetnodewall.get_name()
		var nodename0_station = activetargetnode.get_name()
		var xcname1_floor = pointertargetwall.get_name()
		var xctube = sketchsystem.findxctube(xcname0_centreline, xcname1_floor)
		var xctdata = { "xcname0": xcname0_centreline, "xcname1":xcname1_floor }
		if xctube == null:
			xctdata["tubename"] = "**notset"
			xctdata["prevdrawinglinks"] = [ ]
			xctdata["newdrawinglinks"] = [ nodename0_station, newnodename, "floorcentrelineposition", null ]
		else:
			xctdata["tubename"] = xctube.get_name()
			xctdata["newdrawinglinks"] = [ nodename0_station, newnodename, "floorcentrelineposition", null ]
			var j = xctube.linkspresentindex(nodename0_station, null)
			if j != -1:
				var reppapernodename = xctube.xcdrawinglink[j*2+1]
				xcndata["prevnodepoints"][reppapernodename] = pointertargetwall.nodepoints[reppapernodename]
				xctdata["prevdrawinglinks"] = [ nodename0_station, reppapernodename, xctube.xcsectormaterials[j], null ]
			else:
				xctdata["prevdrawinglinks"] = [ ]
		sketchsystem.actsketchchange([xcndata, xctdata])
		if xctube == null:
			xctube = sketchsystem.findxctube(xcname0_centreline, xcname1_floor)
		if len(xctube.xcdrawinglink) != 0:
			var floormovedata = xctube.centrelineconnectionfloortransformpos(sketchsystem)
			if floormovedata != null:
				sketchsystem.actsketchchange(floormovedata)
		clearactivetargetnode()

	elif pointertargettype == "XCdrawing" and pointertargetwall.drawingtype == DRAWING_TYPE.DT_FLOORTEXTURE and \
					planviewsystem.planviewactive: 
		if gripbuttonheld and planviewsystem.activetargetfloor == pointertargetwall:
			sketchsystem.actsketchchange([planviewsystem.getactivetargetfloorViz("")])
		else:
			sketchsystem.actsketchchange([planviewsystem.getactivetargetfloorViz(pointertargetwall.get_name())])


	elif activetargetnode != null and pointertargettype == "XCnode" and (pointertargetwall.drawingtype == DRAWING_TYPE.DT_XCDRAWING or pointertargetwall.drawingtype == DRAWING_TYPE.DT_ROPEHANG):
		if activetargetnodewall == pointertargetwall and (activetargetnodewall.drawingtype == DRAWING_TYPE.DT_XCDRAWING or activetargetnodewall.drawingtype == DRAWING_TYPE.DT_ROPEHANG):
			var xcdata = { "name":pointertargetwall.get_name() }
			var i0 = activetargetnode.get_name()
			var i1 = pointertarget.get_name()
			if pointertargetwall.pairpresentindex(i0, i1) != -1:  # add line
				xcdata["prevonepathpairs"] = [i0, i1]
				xcdata["newonepathpairs"] = [ ]
			else:   # delete line
				xcdata["newonepathpairs"] = [i0, i1]
				if initialsequencenodenameP != null and initialsequencenodenameP != activetargetnode.get_name() and pointertargetwall.drawingtype == DRAWING_TYPE.DT_XCDRAWING:
					xcdata["prevonepathpairs"] = [ initialsequencenodenameP, pointertarget.get_name() ]
				else:   # ^^ rejoin and delete straight line
					xcdata["prevonepathpairs"] = [ ]
			var xcdatalist = [xcdata]
			if pointertargetwall.drawingvisiblecode != DRAWING_TYPE.VIZ_XCD_PLANE_AND_NODES_VISIBLE:
				xcdatalist.push_back({"xcvizstates":{ pointertargetwall.get_name():DRAWING_TYPE.VIZ_XCD_PLANE_AND_NODES_VISIBLE } })
			sketchsystem.actsketchchange(xcdatalist)

		elif activetargetnodewall != pointertargetwall and activetargetnodewall.drawingtype == DRAWING_TYPE.DT_ROPEHANG and pointertargetwall.drawingtype == DRAWING_TYPE.DT_ROPEHANG:
			print("tube or merge two ropehang things here")

		elif activetargetnodewall != pointertargetwall and activetargetnodewall.drawingtype == DRAWING_TYPE.DT_XCDRAWING and pointertargetwall.drawingtype == DRAWING_TYPE.DT_XCDRAWING:
			var xcname0 = activetargetnodewall.get_name()
			var nodename0 = activetargetnode.get_name()
			var xcname1 = pointertargetwall.get_name()
			var nodename1 = pointertarget.get_name()
			var xctube = sketchsystem.findxctube(xcname0, xcname1)
			var xctdata = { "xcname0": xcname0, "xcname1":xcname1 }
			if xctube == null:
				xctdata["tubename"] = "**notset"
				xctdata["prevdrawinglinks"] = [ ]
				xctdata["newdrawinglinks"] = [ nodename0, nodename1, "simpledirt", null ]
			else:
				xctdata["tubename"] = xctube.get_name()
				var j = xctube.linkspresentindex(nodename0, nodename1) if xctube.xcname0 == xcname0 else xctube.linkspresentindex(nodename1, nodename0)
				if j == -1:
					xctdata["prevdrawinglinks"] = [ ]
					xctdata["newdrawinglinks"] = [ nodename0, nodename1, "simpledirt", null ]
				else:
					xctdata["prevdrawinglinks"] = [ nodename0, nodename1, xctube.xcsectormaterials[j], (xctube.xclinkintermediatenodes[j] if xctube.xclinkintermediatenodes != null else null) ]
					xctdata["newdrawinglinks"] = [ ]
					
			var xctdatalist = [xctdata]
			#if pointertargetwall.drawingvisiblecode != DRAWING_TYPE.VIZ_XCD_PLANE_AND_NODES_VISIBLE and activetargetnodewall.drawingvisiblecode != DRAWING_TYPE.VIZ_XCD_PLANE_AND_NODES_VISIBLE:
			xctdatalist.push_back({ "xcvizstates":{ }, "updatetubeshells":[{"tubename":xctube.get_name() if xctube != null else "**notset", "xcname0": xcname0, "xcname1":xcname1 }] })
			sketchsystem.actsketchchange(xctdatalist)
		clearactivetargetnode()
											
	elif activetargetnode == null and pointertargettype == "XCnode":
		if pointertargetwall.drawingtype == DRAWING_TYPE.DT_XCDRAWING:
			if pointertargetwall != activetargetwall:
				setactivetargetwall(pointertargetwall)
				activetargetnodetriggerpulling = true
		elif pointertargetwall.drawingtype == DRAWING_TYPE.DT_ROPEHANG:
			if pointertargetwall.drawingvisiblecode == DRAWING_TYPE.VIZ_XCD_HIDE:
				sketchsystem.actsketchchange([{"xcvizstates":{pointertargetwall.get_name():DRAWING_TYPE.VIZ_XCD_NODES_VISIBLE}}])
		setactivetargetnode(pointertarget)
		initialsequencenodename = pointertarget.get_name()

		
	if gripbuttonheld:
		gripbuttonpressused = true
		gripmenu.disableallgripmenus()

				
func buttonpressed_vrpad(gripbuttonheld, joypos):
	if pointertargettype == "XCdrawing" and pointertargetwall.drawingtype == DRAWING_TYPE.DT_XCDRAWING:
		if abs(joypos.y) < 0.5 and abs(joypos.x) > 0.1:
			var dy = (1 if joypos.x > 0 else -1)*(1.0 if abs(joypos.x) < 0.8 else 0.1)
			pointertargetwall.get_node("XCdrawingplane").scale.x = max(1, pointertargetwall.get_node("XCdrawingplane").scale.x + dy)
			pointertargetwall.get_node("XCdrawingplane").scale.y = max(1, pointertargetwall.get_node("XCdrawingplane").scale.y + dy)
			pointertargetwall.updateformetresquaresscaletexture()
				
	elif pointertargettype == "Papersheet":
		if abs(joypos.y) > 0.5:
			var dd = (1 if joypos.x > 0 else -1)*(0.2 if activelaserroot.get_node("Length").scale.z < 1.5 else 1.0)
			if activelaserroot.get_node("Length").scale.z + dd > 0.1:
				pointertargetwall.global_transform.origin += -dd*LaserOrient.global_transform.basis.z
		elif abs(joypos.x) > 0.1:
			var fs = (0.5 if abs(joypos.x) < 0.8 else 0.9)
			if joypos.x > 0:
				fs = 1/fs
			pointertargetwall.get_node("XCdrawingplane").scale.x *= fs
			pointertargetwall.get_node("XCdrawingplane").scale.y *= fs

	elif pointertargettype == "XCnode":
		if pointertargetwall.drawingtype == DRAWING_TYPE.DT_ROPEHANG and pointertargetwall.drawingvisiblecode == DRAWING_TYPE.VIZ_XCD_HIDE: 
			pointertargetwall.get_node("RopeHang").iteratehangingrope_Verlet()
			
func exchdictptrs(xcdata, e0, e1):
	if e0 in xcdata:
		var e0d = xcdata[e0]
		xcdata[e0] = xcdata[e1]
		xcdata[e1] = e0d

func buttonreleased_vrgrip():
	var wasactivetargettube = activetargettube
	if activetargettube != null:
		activetargettube.setxctubepathlinevisibility(sketchsystem)
		if pointertargettype == "GripMenuItem" and pointertarget.get_parent().get_name() == "MaterialButtons":
			assert (gripmenu.gripmenupointertargettype == "XCtubesector") 
			var sectormaterialname = pointertarget.get_name()
			if activetargettubesectorindex < len(activetargettube.xcsectormaterials):
				var nodename0 = activetargettube.xcdrawinglink[activetargettubesectorindex*2]
				var nodename1 = activetargettube.xcdrawinglink[activetargettubesectorindex*2+1]
				sketchsystem.actsketchchange([{ "tubename":activetargettube.get_name(), 
												"xcname0":activetargettube.xcname0, 
												"xcname1":activetargettube.xcname1,
												"prevdrawinglinks":[nodename0, nodename1, activetargettube.xcsectormaterials[activetargettubesectorindex], null],
												"newdrawinglinks":[nodename0, nodename1, sectormaterialname, null]
											 }])
				gripmenu.disableallgripmenus()
			else:
				materialsystem.updatetubesectormaterial(activetargettube.get_node("XCtubesectors").get_child(activetargettubesectorindex), activetargettube.xcsectormaterials[activetargettubesectorindex], false)
			activetargettube = null
			return

		if activetargettubesectorindex < len(activetargettube.xcsectormaterials):
			materialsystem.updatetubesectormaterial(activetargettube.get_node("XCtubesectors").get_child(activetargettubesectorindex), activetargettube.xcsectormaterials[activetargettubesectorindex], false)
		else:
			print("Wrong: activetargettubesectorindex >= activetargettube.xcsectormaterials ")
		activetargettube.get_node("PathLines").set_surface_material(0, materialsystem.pathlinematerial("normal"))
		activetargettube = null

	if activetargetxcflatshell != null:
		if pointertargettype == "GripMenuItem" and pointertarget.get_parent().get_name() == "MaterialButtons":
			assert (gripmenu.gripmenupointertargettype == "XCflatshell") 
			var newflatshellmaterialname = pointertarget.get_name()
			sketchsystem.actsketchchange([{ "name":activetargetxcflatshell.get_name(), 
											"prevxcflatshellmaterial":activetargetxcflatshell.xcflatshellmaterial,
											"nextxcflatshellmaterial":newflatshellmaterialname
										 }])
			gripmenu.disableallgripmenus()
			return
		materialsystem.updatetubesectormaterial(activetargetxcflatshell.get_node("XCflatshell"), activetargetxcflatshell.xcflatshellmaterial, false)
		activetargetxcflatshell = null

	if activetargetwallgrabbedtransform != null:
		sketchsystem.actsketchchange([ targetwalltransformpos(2) ])
		activetargetwallgrabbedtransform = null
		assert (gripbuttonpressused)
	
	if gripbuttonpressused:
		pass  # the trigger was pulled during the grip operation
	
	elif pointertargettype == "GripMenuItem":
				
		if pointertarget.get_name() == "NewXC":
			var pt0 = gripmenu.gripmenupointertargetpoint
			var eyept0vec = pt0 - headcam.global_transform.origin
			var newxcvertplane = true
			if gripmenu.gripmenupointertargettype == "XCtubesector":
				var xcdrawing0 = sketchsystem.get_node("XCdrawings").get_node(gripmenu.gripmenupointertargetwall.xcname0)
				var xcdrawing1 = sketchsystem.get_node("XCdrawings").get_node(gripmenu.gripmenupointertargetwall.xcname1)
				var tubevec = xcdrawing1.global_transform.origin - xcdrawing0.global_transform.origin
				eyept0vec = tubevec if eyept0vec.dot(tubevec) > 0 else -tubevec
				if abs(xcdrawing0.global_transform.basis.z.y) > 0.3 and abs(xcdrawing1.global_transform.basis.z.y) > 0.3:
					newxcvertplane = false
			elif gripmenu.gripmenupointertargettype == "Papersheet":
				pass
			elif gripmenu.gripmenupointertargettype == "XCnode":
				if gripmenu.gripmenupointertargetwall.drawingtype == DRAWING_TYPE.DT_XCDRAWING:
					pt0 += -eyept0vec/2
				eyept0vec = gripmenu.gripmenulaservector
				if abs(gripmenu.gripmenupointertargetwall.global_transform.basis.z.y) > 0.3:
					newxcvertplane = false
			elif gripmenu.gripmenupointertargettype == "PlanView":
				pt0 = null
			elif gripmenu.gripmenupointertargettype == "XCdrawing" and gripmenu.gripmenupointertargetwall.drawingtype == DRAWING_TYPE.DT_XCDRAWING:
				pt0 += -eyept0vec/2
				if abs(gripmenu.gripmenupointertargetwall.global_transform.basis.z.y) > 0.3:
					newxcvertplane = false
			elif gripmenu.gripmenupointertargettype == "XCdrawing" and gripmenu.gripmenupointertargetwall.drawingtype == DRAWING_TYPE.DT_FLOORTEXTURE:
				pass
			elif gripmenu.gripmenupointertargettype == "XCflatshell":
				pt0 += -eyept0vec/2
			else:
				print(gripmenu.gripmenupointertargettype)
				assert (gripmenu.gripmenupointertargettype == "none" or gripmenu.gripmenupointertargettype == "unknown")
				eyept0vec = gripmenu.gripmenulaservector
				pt0 = headcam.global_transform.origin + eyept0vec.normalized()*2.9
			if pt0 != null:
				var drawingwallangle = Vector2(eyept0vec.x, eyept0vec.z).angle() + deg2rad(90)					
				var xcdata = { "name":sketchsystem.uniqueXCname("s"), 
							   "drawingtype":DRAWING_TYPE.DT_XCDRAWING,
							   "transformpos":Transform(Basis().rotated(Vector3(0,-1,0), drawingwallangle), pt0) }
				if not newxcvertplane:
					xcdata["transformpos"] = Transform(Vector3(1,0,0), Vector3(0,0,-1), Vector3(0,1,0), pt0)
				var xcviz = { "xcvizstates": { xcdata["name"]:DRAWING_TYPE.VIZ_XCD_PLANE_AND_NODES_VISIBLE } }
				sketchsystem.actsketchchange([xcdata, xcviz])
				clearactivetargetnode()
				var xcdrawing = sketchsystem.get_node("XCdrawings").get_node(xcdata["name"])
				setactivetargetwall(xcdrawing)
				if gripmenu.gripmenupointertargettype == "XCtubesector":
					var xcdrawing0 = sketchsystem.get_node("XCdrawings").get_node(gripmenu.gripmenupointertargetwall.xcname0)
					var xcdrawing1 = sketchsystem.get_node("XCdrawings").get_node(gripmenu.gripmenupointertargetwall.xcname1)
					xcdrawing.expandxcdrawingfitxcdrawing(xcdrawing0)
					xcdrawing.expandxcdrawingfitxcdrawing(xcdrawing1)

		elif pointertarget.get_name() == "Undo":
			if len(sketchsystem.actsketchchangeundostack) != 0:
				var xcdatalist = sketchsystem.actsketchchangeundostack[-1].duplicate()
				xcdatalist.invert()  # should keep the vizstates at the end
				for xcdata in xcdatalist:
					exchdictptrs(xcdata, "prevnodepoints", "nextnodepoints")
					exchdictptrs(xcdata, "prevonepathpairs", "newonepathpairs")
					exchdictptrs(xcdata, "prevtransformpos", "transformpos")
					exchdictptrs(xcdata, "previmgtrim", "imgtrim")
					exchdictptrs(xcdata, "prevdrawinglinks", "newdrawinglinks")
					exchdictptrs(xcdata, "prevxcvizstates", "xcvizstates")
				xcdatalist[0]["undoact"] = 1
				sketchsystem.actsketchchange(xcdatalist)

		elif is_instance_valid(gripmenu.gripmenupointertargetwall):
			print("executing ", pointertarget.get_name(), " on ", gripmenu.gripmenupointertargetwall.get_name())
			if pointertarget.get_name() == "SelectXC":
				if gripmenu.gripmenupointertargettype == "XCtubesector":
					sketchsystem.actsketchchange([{"xcvizstates":{gripmenu.gripmenupointertargetwall.xcname0:DRAWING_TYPE.VIZ_XCD_PLANE_AND_NODES_VISIBLE, 
																  gripmenu.gripmenupointertargetwall.xcname1:DRAWING_TYPE.VIZ_XCD_PLANE_AND_NODES_VISIBLE}}])
					var xcdrawing0 = sketchsystem.get_node("XCdrawings").get_node(gripmenu.gripmenupointertargetwall.xcname0)
					var xcdrawing1 = sketchsystem.get_node("XCdrawings").get_node(gripmenu.gripmenupointertargetwall.xcname1)
					if xcdrawing0 != activetargetwall:
						setactivetargetwall(xcdrawing0)
					elif xcdrawing1 != activetargetwall:
						setactivetargetwall(xcdrawing1)

				if gripmenu.gripmenupointertargettype == "XCflatshell":
					sketchsystem.actsketchchange([{"xcvizstates":{gripmenu.gripmenupointertargetwall.get_name():DRAWING_TYPE.VIZ_XCD_PLANE_AND_NODES_VISIBLE}}])
					if gripmenu.gripmenupointertargetwall != activetargetwall:
						setactivetargetwall(gripmenu.gripmenupointertargetwall)
						
			elif pointertarget.get_name() == "HideXC":
				if gripmenu.gripmenupointertargettype == "XCnode" or gripmenu.gripmenupointertargettype == "XCflatshell":
					if gripmenu.gripmenupointertargetwall.drawingtype == DRAWING_TYPE.DT_ROPEHANG or gripmenu.gripmenupointertargetwall.xcconnectstoshell():
						var updatexcshells = [ gripmenu.gripmenupointertargetwall.get_name() ]
						var updatetubeshells = gripmenu.gripmenupointertargetwall.updatetubeshellsconn()
						sketchsystem.actsketchchange([{ "xcvizstates":{ gripmenu.gripmenupointertargetwall.get_name():DRAWING_TYPE.VIZ_XCD_HIDE }, "updatetubeshells":updatetubeshells, "updatexcshells":updatexcshells }])
					if gripmenu.gripmenupointertargetwall == activetargetwall:
						setactivetargetwall(null)
				elif gripmenu.gripmenupointertargettype == "XCtubesector":
					print(gripmenu.gripmenupointertargettype)
					sketchsystem.actsketchchange([{ "xcvizstates":{gripmenu.gripmenupointertargetwall.xcname0:DRAWING_TYPE.VIZ_XCD_HIDE, 
																   gripmenu.gripmenupointertargetwall.xcname1:DRAWING_TYPE.VIZ_XCD_HIDE}} ])
					var xcdrawing0 = sketchsystem.get_node("XCdrawings").get_node(gripmenu.gripmenupointertargetwall.xcname0)
					var xcdrawing1 = sketchsystem.get_node("XCdrawings").get_node(gripmenu.gripmenupointertargetwall.xcname1)
					if xcdrawing0 == activetargetwall:
						setactivetargetwall(null)
					if xcdrawing1 == activetargetwall:
						setactivetargetwall(null)

			elif pointertarget.get_name() == "HideFloor":
				var xcdrawing = gripmenu.gripmenupointertargetwall
				sketchsystem.actsketchchange([{ "xcvizstates":{xcdrawing.get_name():DRAWING_TYPE.VIZ_XCD_FLOOR_HIDDEN}} ])

			elif pointertarget.get_name() == "DelXC":
				var xcdrawing = gripmenu.gripmenupointertargetwall
				if (xcdrawing.drawingtype == DRAWING_TYPE.DT_XCDRAWING) or (xcdrawing.drawingtype == DRAWING_TYPE.DT_ROPEHANG):
					if xcdrawing.notubeconnections_so_delxcable():
						if activetargetnodewall == xcdrawing:
							clearactivetargetnode()
						var xcname = xcdrawing.get_name()
						var xcdata = { "name":xcname, 
									   "prevnodepoints":xcdrawing.nodepoints.duplicate(),
									   "nextnodepoints":{ }, 
									   "prevonepathpairs":xcdrawing.onepathpairs.duplicate(),
									   "newonepathpairs": [ ]
									 }
						var xcv = { "xcvizstates":{ xcname:DRAWING_TYPE.VIZ_XCD_PLANE_VISIBLE if xcdrawing.get_name().begins_with("Hole") else \
															 DRAWING_TYPE.VIZ_XCD_HIDE }, 
									"updatexcshells":[xcname] }
						sketchsystem.actsketchchange([xcdata, xcv])
					else:
						print("not deleted xc nodes")
				
				
			elif pointertarget.get_name() == "DelTube":
				if gripmenu.gripmenupointertargettype == "XCtubesector":
					var xctube = gripmenu.gripmenupointertargetwall
					var xcv = { "xcvizstates":{ xctube.xcname0:DRAWING_TYPE.VIZ_XCD_PLANE_AND_NODES_VISIBLE, xctube.xcname1:DRAWING_TYPE.VIZ_XCD_PLANE_AND_NODES_VISIBLE } }
					var prevdrawinglinks = [ ]
					for j in range(0, len(xctube.xcdrawinglink), 2):
						prevdrawinglinks.push_back(xctube.xcdrawinglink[j])
						prevdrawinglinks.push_back(xctube.xcdrawinglink[j+1])
						prevdrawinglinks.push_back(xctube.xcsectormaterials[j/2])
						prevdrawinglinks.push_back(xctube.xclinkintermediatenodes[j/2] if xctube.xclinkintermediatenodes != null else null)
					var xctdata = { "tubename":xctube.get_name(), 
									"xcname0":xctube.xcname0, 
									"xcname1":xctube.xcname1,
									"prevdrawinglinks":prevdrawinglinks,
									"newdrawinglinks":[ ] 
								  }
					sketchsystem.actsketchchange([xcv, xctdata])

			elif pointertarget.get_name() == "DragXC" and is_instance_valid(activetargetnode):
				var dragvec = activetargetnodewall.global_transform.xform_inv(gripmenu.gripmenupointertargetpoint) - activetargetnode.translation
				dragvec.z = 0.0
				var prevnodepoints = { }
				var nextnodepoints = { }
				#activetargetnodewall.dragxcnodes(dragvec, sketchsystem)
				for nodename in activetargetnodewall.nodepoints:
					prevnodepoints[nodename] = activetargetnodewall.nodepoints[nodename]
					nextnodepoints[nodename] = activetargetnodewall.nodepoints[nodename] + dragvec
				sketchsystem.actsketchchange([{ "name":activetargetnodewall.get_name(), 
												"prevnodepoints":prevnodepoints,
												"nextnodepoints":nextnodepoints
											}])

			elif pointertarget.get_name() == "HoleXC":
				var xcsectormaterial = gripmenu.gripmenupointertargetwall.xcsectormaterials[gripmenu.gripmenuactivetargettubesectorindex]
				if xcsectormaterial == "hole":
					var xcdata = gripmenu.gripmenupointertargetwall.ConstructHoleXC(gripmenu.gripmenuactivetargettubesectorindex, sketchsystem)
					if xcdata != null:
						sketchsystem.actsketchchange([xcdata, 
								{"xcvizstates":{ gripmenu.gripmenupointertargetwall.xcname0:DRAWING_TYPE.VIZ_XCD_HIDE, 
												 gripmenu.gripmenupointertargetwall.xcname1:DRAWING_TYPE.VIZ_XCD_HIDE,
												 xcdata["name"]:DRAWING_TYPE.VIZ_XCD_NODES_VISIBLE }}])
						setactivetargetwall(sketchsystem.get_node("XCdrawings").get_node(xcdata["name"]))
				elif xcsectormaterial == "holegap":
					var xcdata = gripmenu.gripmenupointertargetwall.CopyHoleGapShape(gripmenu.gripmenuactivetargettubesectorindex, sketchsystem)
					if xcdata != null:
						sketchsystem.actsketchchange([xcdata, 
								{ "xcvizstates":{ }, 
								  "updatetubeshells":[ 
									{ "tubename":gripmenu.gripmenupointertargetwall.get_name(), "xcname0":gripmenu.gripmenupointertargetwall.xcname0, "xcname1":gripmenu.gripmenupointertargetwall.xcname1 }
													 ] } ] )
													
			elif pointertarget.get_name() == "DoSlice" and is_instance_valid(wasactivetargettube) and is_instance_valid(activetargetwall) and len(activetargetwall.nodepoints) == 0:
				print("doslice ", wasactivetargettube, " ", len(activetargetwall.nodepoints))
				var xcdrawing = activetargetwall
				var xcdata = { "name":xcdrawing.get_name(), "prevnodepoints":{}, "nextnodepoints":{}, "prevonepathpairs":[], "newonepathpairs":[] }
				var xctdatadel = { "tubename":wasactivetargettube.get_name(), 
								   "xcname0":wasactivetargettube.xcname0,
								   "xcname1":wasactivetargettube.xcname1,
								   "prevdrawinglinks":[], "newdrawinglinks":[] }
				var xctdata0 = { "tubename":"**notset", 
								 "xcname0":wasactivetargettube.xcname0,
								 "xcname1":xcdrawing.get_name(),
								 "prevdrawinglinks":[], "newdrawinglinks":[] }
				var xctdata1 = { "tubename":"**notset", 
								 "xcname0":xcdrawing.get_name(),
								 "xcname1":wasactivetargettube.xcname1,
								 "prevdrawinglinks":[], "newdrawinglinks":[] }
				if wasactivetargettube.slicetubetoxcdrawing(xcdrawing, xcdata, xctdatadel, xctdata0, xctdata1):
					clearactivetargetnode()
					clearpointertarget()
					var xctdataviz = {"xcvizstates":{ xcdrawing.get_name():DRAWING_TYPE.VIZ_XCD_PLANE_AND_NODES_VISIBLE }, 
						"updatetubeshells":[
							{ "tubename":xctdatadel["tubename"], "xcname0":xctdatadel["xcname0"], "xcname1":xctdatadel["xcname1"] },
							{ "tubename":xctdata0["tubename"], "xcname0":xctdata0["xcname0"], "xcname1":xctdata0["xcname1"] },
							{ "tubename":xctdata1["tubename"], "xcname0":xctdata1["xcname0"], "xcname1":xctdata1["xcname1"] } 
						]}
					sketchsystem.actsketchchange([xcdata, xctdatadel, xctdata0, xctdata1, xctdataviz])
					setactivetargetwall(xcdrawing)
					wasactivetargettube = null
					activelaserroot.get_node("LaserSpot").visible = false

		
	elif pointertargettype == "GUIPanel3D":
		if guipanel3d.visible:
			guipanel3d.toggleguipanelvisibility(null)

	elif pointertargettype == "XCdrawing" and pointertargetwall.drawingtype == DRAWING_TYPE.DT_XCDRAWING and len(pointertargetwall.nodepoints) != 0:
		clearpointertargetmaterial()
		var updatexcshells = [ pointertargetwall.get_name() ]
		var updatetubeshells = pointertargetwall.updatetubeshellsconn()
		sketchsystem.actsketchchange([{"xcvizstates":{ pointertargetwall.get_name():DRAWING_TYPE.VIZ_XCD_NODES_VISIBLE }, "updatetubeshells":updatetubeshells, "updatexcshells":updatexcshells }])
		var xcdatashellholes = findconstructtubeshellholes(pointertargetwall.xctubesconn)
		if xcdatashellholes != null:
			sketchsystem.actsketchchange(xcdatashellholes)
		setactivetargetwall(null)
		clearpointertarget()
		activelaserroot.get_node("LaserSpot").visible = false

	elif planviewsystem.planviewactive and pointertargettype == "XCdrawing" and pointertargetwall.drawingtype == DRAWING_TYPE.DT_FLOORTEXTURE and \
			planviewsystem.activetargetfloor != null and pointertargetwall == planviewsystem.activetargetfloor and pointertargetwall == gripmenu.gripmenupointertargetwall:
		sketchsystem.actsketchchange([planviewsystem.getactivetargetfloorViz("")])
		
	elif activetargetwall != null and activetargetwall.drawingtype == DRAWING_TYPE.DT_XCDRAWING:
		var updatexcshells = [ activetargetwall.get_name() ]
		var updatetubeshells = activetargetwall.updatetubeshellsconn()
		sketchsystem.actsketchchange([{"xcvizstates":{ }, "updatetubeshells":updatetubeshells, "updatexcshells":updatexcshells }])
		setactivetargetwall(null)

	elif activetargetnode != null:
		clearactivetargetnode()

	elif intermediatepointplanetubename != "":
		clearintermediatepointplaneview()

	gripmenu.disableallgripmenus()

func findconstructtubeshellholes(xctubes):
	var xcdatashellholes = null
	for xctube in xctubes:
		var tubeshellholeindexes = xctube.gettubeshellholes(sketchsystem)
		if tubeshellholeindexes != null:
			var drawinghole = tubeshellholeindexes[0]
			for j in range(1, len(tubeshellholeindexes)):
				var i = tubeshellholeindexes[j]
				var xcdatashell = xctube.ConstructHoleXC(i, sketchsystem)
				if xcdatashell != null:
					if xcdatashellholes == null:
						xcdatashellholes = [ ]
					xcdatashellholes.push_back(xcdatashell)
			var updatetubeshells = drawinghole.updatetubeshellsconn()
			if len(updatetubeshells) != 0:
				xcdatashellholes.push_back({"xcvizstates":{ }, "updatetubeshells":updatetubeshells})
	return xcdatashellholes

var targetwallvertplane = true
var prevactivetargetwallgrabbedorgtransform = null
func targetwalltransformpos(optionalrevertcode):
	if activetargetwallgrabbed.get_name() == "PlanView" or activetargetwallgrabbed.drawingtype != DRAWING_TYPE.DT_XCDRAWING:
		var newtrans = null
		if activetargetwallgrabbedpoint != null:
			newtrans = activelaserroot.get_node("LaserSpot").global_transform * activetargetwallgrabbedtransform
			newtrans.origin += activetargetwallgrabbedpoint - newtrans * activetargetwallgrabbedlocalpoint
		else:
			newtrans = activelaserroot.get_node("LaserSpot").global_transform * activetargetwallgrabbedtransform
			
		if activetargetwallgrabbed.get_name() == "PlanView":
			var txcdata = { "planview":{ "transformpos":newtrans },
							"rpcoptional":(0 if optionalrevertcode else 1),
							"timestamp":OS.get_ticks_msec()*0.001,
						  }
			return txcdata
		elif activetargetwallgrabbed.drawingtype != DRAWING_TYPE.DT_XCDRAWING:
			var txcdata = { "name":activetargetwallgrabbed.get_name(), 
							"rpcoptional":(0 if optionalrevertcode else 1),
							"timestamp":OS.get_ticks_msec()*0.001,
							"prevtransformpos":activetargetwallgrabbed.transform,
							"transformpos":newtrans }
			return txcdata
	
	assert (activetargetwallgrabbed.drawingtype == DRAWING_TYPE.DT_XCDRAWING)	
	var rotateonly = (len(activetargetwallgrabbed.nodepoints) != 0)
	var txcdata = { "name":activetargetwallgrabbed.get_name(), 
					"rpcoptional":(0 if optionalrevertcode else 1),
					"timestamp":OS.get_ticks_msec()*0.001,
					"prevtransformpos":activetargetwallgrabbed.transform, }
	if prevactivetargetwallgrabbedorgtransform == null or prevactivetargetwallgrabbedorgtransform != activetargetwallgrabbedorgtransform:
		targetwallvertplane = abs(activetargetwallgrabbedorgtransform.basis.z.y) < 0.3
		prevactivetargetwallgrabbedorgtransform = activetargetwallgrabbedorgtransform

	var laserrelvec = activelaserroot.global_transform.basis.xform_inv(activetargetwallgrabbedlaserroottrans.basis.z)
	var angh = asin(activelaserroot.global_transform.basis.z.y)
	if rotateonly:
		pass
	elif targetwallvertplane and abs(angh) > deg2rad(60):
		targetwallvertplane = false
	elif (not targetwallvertplane) and abs(angh) < deg2rad(20):
		targetwallvertplane = true
	
	if optionalrevertcode == 2:
		txcdata["transformpos"] = activetargetwallgrabbedorgtransform
	elif targetwallvertplane:
		var angy = -Vector2(laserrelvec.z, laserrelvec.x).angle()
		if abs(activetargetwallgrabbedorgtransform.basis.z.y) < 0.3:  # should be 0 or 1 for vertical or horiz
			txcdata["transformpos"] = activetargetwallgrabbedorgtransform.rotated(Vector3(0,1,0), angy)
			var angpush = 0 if rotateonly else -(activetargetwallgrabbedlaserroottrans.origin.y - activelaserroot.global_transform.origin.y)
			var activetargetwallgrabbedpointmoved = activetargetwallgrabbedpoint + 20*angpush*activetargetwallgrabbeddispvector.normalized()
			txcdata["transformpos"].origin += activetargetwallgrabbedpointmoved - txcdata["transformpos"]*activetargetwallgrabbedlocalpoint
		else:
			var angt = Vector2(activetargetwallgrabbeddispvector.x, activetargetwallgrabbeddispvector.z).angle() + deg2rad(90) - angy
			txcdata["transformpos"] = Transform(Basis().rotated(Vector3(0,-1,0), angt), activetargetwallgrabbedorgtransform.origin)
			var angpush = 0 if rotateonly else -(activetargetwallgrabbedlaserroottrans.origin.y - activelaserroot.global_transform.origin.y)
			var activetargetwallgrabbedpointmoved = activetargetwallgrabbedpoint + 20*angpush*Vector3(activetargetwallgrabbeddispvector.x, 0, activetargetwallgrabbeddispvector.z).normalized()
			txcdata["transformpos"].origin += activetargetwallgrabbedpointmoved - txcdata["transformpos"]*activetargetwallgrabbedlocalpoint
	else:
		var angy = -Vector2(laserrelvec.z, laserrelvec.x).angle()
		#txcdata["transformpos"] = Transform().rotated(Vector3(1,0,0), deg2rad(-90)).rotated(Vector3(0,1,0), angy)
		txcdata["transformpos"] = Transform(Vector3(1,0,0), Vector3(0,0,-1), Vector3(0,1,0), Vector3(0,0,0)) # .rotated(Vector3(0,1,0), angy)
		var angpush = 0 if rotateonly else -(activetargetwallgrabbedlaserroottrans.origin.y - activelaserroot.global_transform.origin.y)
		txcdata["transformpos"].origin = activetargetwallgrabbedpoint + Vector3(0, 20*angpush, 0)
	return txcdata

func clearintermediatepointplaneview():
	var IntermediatePointView = get_node("/root/Spatial/BodyObjects/IntermediatePointView")
	IntermediatePointView.visible = false
	IntermediatePointView.get_node("IntermediatePointPlane/CollisionShape").disabled = true
	intermediatepointplanetubename = ""
	LaserOrient.get_node("RayCast").collision_mask = raynormalcollisionmask()
	


func buttonreleased_vrtrigger():
	if activetargetwallgrabbedtransform != null:
		sketchsystem.actsketchchange([ targetwalltransformpos(1) ])
		activetargetwallgrabbedtransform = null
	if intermediatepointplanetubename != "":
		if pointertargettype != "IntermediatePointView":
			clearintermediatepointplaneview()
		else:
			LaserOrient.get_node("RayCast").collision_mask = CollisionLayer.CL_IntermediatePlane
	if activetargetnodetriggerpulling:
		activetargetnodetriggerpulling = false
		LaserSelectLine.visible = false

func _physics_process(delta):
	if playerMe.handflickmotiongesture != 0:
		if playerMe.handflickmotiongesture == 1:
			set_handflickmotiongestureposition(min(Tglobal.handflickmotiongestureposition+1, handflickmotiongestureposition_gone))
		else:
			set_handflickmotiongestureposition(0)
		playerMe.get_node("HandRight/PalmLight").visible = (Tglobal.handflickmotiongestureposition == handflickmotiongestureposition_gone)
		playerMe.handflickmotiongesture = 0
		
	if playerMe.get_node("HandRight").pointervalid:
		var firstlasertarget = LaserOrient.get_node("RayCast").get_collider()
		if firstlasertarget != null and firstlasertarget.is_queued_for_deletion():
			firstlasertarget = null
		if firstlasertarget == guipanel3d:
			LaserOrient.visible = true
			activelaserroot = LaserOrient
			setpointertarget(activelaserroot, activelaserroot.get_node("RayCast"), -1.0)
			pointerplanviewtarget = null
		elif Tglobal.handflickmotiongestureposition == handflickmotiongestureposition_gone or Tglobal.controlslocked:
			LaserOrient.visible = false
			pointerplanviewtarget = null
		elif Tglobal.handflickmotiongestureposition == handflickmotiongestureposition_shortpos and not (firstlasertarget != null and firstlasertarget.get_parent().get_parent().get_name() == "GripMenu"):
			LaserOrient.visible = true
			activelaserroot = LaserOrient
			pointerplanviewtarget = null
			setpointertarget(activelaserroot, activelaserroot.get_node("RayCast"), handflickmotiongestureposition_shortpos_length)
		elif firstlasertarget != null and firstlasertarget.get_name() == "PlanView" and planviewsystem.checkplanviewinfront(LaserOrient) and planviewsystem.planviewactive:
			pointerplanviewtarget = planviewsystem
			LaserOrient.visible = true
			var planviewcontactpoint = LaserOrient.get_node("RayCast").get_collision_point()
			LaserOrient.get_node("LaserSpot").global_transform.origin = planviewcontactpoint
			LaserOrient.get_node("Length").scale.z = -LaserOrient.get_node("LaserSpot").translation.z
			LaserOrient.get_node("LaserSpot").visible = false
			get_node("/root/Spatial/BodyObjects/FloorLaserSpot/FloorSpot").visible = false
			if planviewsystem.planviewactive:
				var inguipanelsection = pointerplanviewtarget.processplanviewpointing(planviewcontactpoint, (handrightcontroller.is_button_pressed(BUTTONS.HT_PINCH_INDEX_FINGER) if Tglobal.questhandtrackingactive else handrightcontroller.is_button_pressed(BUTTONS.VR_TRIGGER)) or Input.is_mouse_button_pressed(BUTTON_LEFT))
				activelaserroot = planviewsystem.get_node("RealPlanCamera/LaserScope/LaserOrient")
				activelaserroot.get_node("LaserSpot").global_transform.basis = LaserOrient.global_transform.basis
				if inguipanelsection:
					setpointertarget(activelaserroot, null, -1.0)
				else:
					activelaserroot.get_node("RayCast").force_raycast_update()
					setpointertarget(activelaserroot, activelaserroot.get_node("RayCast"), -1.0)
		else:
			LaserOrient.visible = true
			activelaserroot = LaserOrient
			pointerplanviewtarget = null
			setpointertarget(activelaserroot, activelaserroot.get_node("RayCast"), -1.0)

	if pointerplanviewtarget == null or not planviewsystem.planviewactive:
		planviewsystem.get_node("RealPlanCamera/LaserScope").visible = false
		if planviewsystem.viewport_mousedown:
			planviewsystem.planviewguipanelreleasemouse()
	
	if activetargetwallgrabbedtransform != null:
		sketchsystem.actsketchchange([ targetwalltransformpos(0) ])

		
var rightmousebuttonheld = false
func _input(event):
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_mousecapture"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	elif event is InputEventKey:
		if event.scancode == KEY_M:
			if not Tglobal.VRoperating:
				handright.vrbybuttonheld = event.pressed
			if event.pressed:
				buttonpressed_vrby(false)	
		if event.pressed and event.scancode == KEY_H:
			set_handflickmotiongestureposition(handflickmotiongestureposition_shortpos if Tglobal.handflickmotiongestureposition == handflickmotiongestureposition_normal else handflickmotiongestureposition_normal)

	elif Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
		pass

	elif event is InputEventMouseMotion:
		if not Tglobal.VRoperating: # or playerMe.arvrinterface.get_tracking_status() == ARVRInterface.ARVR_NOT_TRACKING:
			handright.process_keyboardcontroltracking(headcam, event.relative*0.005, playerMe.playerscale)
			
	elif event is InputEventMouseButton:
		if event.button_index == BUTTON_RIGHT:
			rightmousebuttonheld = event.pressed
		
		if event.button_index == BUTTON_LEFT:
			if event.pressed:
				buttonpressed_vrtrigger(rightmousebuttonheld)
			else:
				buttonreleased_vrtrigger()
			if not Tglobal.VRoperating:
				handright.triggerbuttonheld = event.pressed
				handright.process_handgesturefromcontrol()
		if event.button_index == BUTTON_RIGHT:
			if event.pressed:
				buttonpressed_vrgrip()
			else:
				buttonreleased_vrgrip()
			if not Tglobal.VRoperating:
				handright.gripbuttonheld = event.pressed
				handright.process_handgesturefromcontrol()
				
	
