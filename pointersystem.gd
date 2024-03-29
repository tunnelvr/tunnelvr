extends Node

onready var sketchsystem = get_node("/root/Spatial/SketchSystem")
onready var planviewsystem = get_node("/root/Spatial/PlanViewSystem")
onready var materialsystem = get_node("/root/Spatial/MaterialSystem")
onready var gripmenu = get_node("/root/Spatial/GuiSystem/GripMenu")
onready var potreeexperiments = get_node("/root/Spatial/PotreeExperiments")
		
onready var playerMe = get_parent()
onready var headcam = playerMe.get_node('HeadCam')
onready var handright = playerMe.get_node("HandRight")
onready var handrightcontroller = playerMe.get_node("HandRightController")
onready var handrighthandtrackingposecontroller = playerMe.get_node("ARVRController4")
onready var guipanel3d = get_node("/root/Spatial/GuiSystem/GUIPanel3D")
onready var keyboardpanel = get_node("/root/Spatial/GuiSystem/KeyboardPanel")

onready var LaserOrient = get_node("/root/Spatial/BodyObjects/LaserOrient") 
onready var LaserSelectLine = get_node("/root/Spatial/BodyObjects/LaserSelectLine") 
onready var FloorLaserSpot = get_node("/root/Spatial/BodyObjects/FloorLaserSpot")
onready var GripLaserSpot = get_node("/root/Spatial/BodyObjects/GripLaserSpot")

onready var LaseSelectLinegoodcolour = LaserSelectLine.get_node("Scale/Mesh").get_surface_material(0).albedo_color
onready var LaseSelectLinebadcolour = Color(0.30, 0.08, 0.08, 0.4)
onready var LaseSelectLinedistoxcolour = Color(0.08, 0.40, 0.08, 0.7)
var viewport_point = null

onready var activelaserroot = LaserOrient
var pointerplanviewtarget = null
var pointertarget = null
var pointertargettype = "none"
var pointertargetwall = null
var pointertargetpoint = Vector3(0, 0, 0)
var gripbuttonpressused = false
var laserselectlinelogicalvisibilitystate = 0
var joyposcumulative = Vector2(0, 0)
var pointertargetofstartofropehang = null

var activetargetnode = null
var activetargetnodewall = null
var activetargetwall = null
var activetargettube = null
var activetargettubesectorindex = -1
var activetargetxcflatshell = null
var prevactivetargettubetohideonsecondselect = null
var activetargetnodetriggerpulling = false
var nodetriggerpullinglimit = 1.0
var nodetriggerpullingmind = 0.2
var nodetriggerpullingminduration = 0.8
var nodetriggerpulledmaxd = 0.0
var nodetriggerpulledtimestamp = 0.0
var activetargetnodetriggerpulledz = 0.0

var activetargetwallgrabbed = null
var activetargetwallgrabbedtransform = null
var activetargetwallgrabbedmotion = DRAWING_TYPE.GRABMOTION_ROTATION_ADDITIVE
var activetargetwallgrabbedorgtransform = null
var activetargetwallgrabbeddispvector = null
var activetargetwallgrabbedpoint = null
var activetargetwallgrabbedlength = 0
var activetargetwalljoyposcumulative = Vector2(0, 0)
var activetargetwallgrabbedpointoffset = null
var activetargetwallgrabbedlocalpoint = null
var activetargetwallgrabbedlaserroottrans = null

var intermediatepointplanetubename = ""
var intermediatepointplanesectorindex = -1
var intermediatepointplanelambda = -1.0
var intermediatepointpicked = null

const handflickmotiongestureposition_NORMAL = 0
const handflickmotiongestureposition_SHORTPOS = 1
const handflickmotiongestureposition_GONE = 2
const splineamplificationfactor = 10.0
var handflickmotiongestureposition_shortpos_length = 0.25

var selectlinefatness = 4.0

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
			pointertarget.get_node("CollisionShape/MeshInstance").set_surface_material(0, materialsystem.nodematerial("selected" if pointertarget == activetargetnode else clearednodematerialtype(pointertarget, (pointertargetwall == activetargetwall), pointertargetwall.drawingtype, pointertargetwall.nodepointvalence1s)))
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
	if pointertargettype == "GripMenuItem" or pointertargettype == "MaterialButton":
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
	if pointertargettype == "GripMenuItem" or pointertargettype == "MaterialButton":
		gripmenu.setgripmenupointer(pointertarget)


func clearednodematerialtype(xcn, bwallactive, walldrawingtype, nodepointvalence1s):
	var xcnname = xcn.get_name()
	var ch = xcnname[0]
	if bwallactive and walldrawingtype == DRAWING_TYPE.DT_FLOORTEXTURE:
		if ch == "r":
			return "nodepthtesthole"
		elif ch == "a" or ch == "k":
			return "nodepthtestknot"
		elif nodepointvalence1s.has(xcnname):
			return "nodepthtestend"
		else:
			return "nodepthtest"
	if walldrawingtype == DRAWING_TYPE.DT_FLOORTEXTURE:
		return "normalfloorpos"
	elif ch == "r":
		return "normalhole"
	elif walldrawingtype == DRAWING_TYPE.DT_ROPEHANG:
		if ch == "a":
			return "normalknotwall"
		elif nodepointvalence1s.has(xcnname):
			return "normalknotend"
		else:
			return "normalknot"
	elif nodepointvalence1s.has(xcnname):
		return "normalend"
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
			activetargetnode.get_node("CollisionShape/MeshInstance").set_surface_material(0, materialsystem.nodematerial(clearednodematerialtype(activetargetnode, (activetargetnodewall == activetargetwall), activetargetnodewall.drawingtype, activetargetnodewall.nodepointvalence1s)))
	activetargetnode = null
	activetargetnodewall = null
	activetargetnodetriggerpulling = false
	activelaserroot.get_node("LaserSpot").set_surface_material(0, materialsystem.lasermaterialN((1 if activetargetnode != null else 0) + (2 if pointertarget == null else 0)))

func cleardeletedtargets(prevnodepoints, nextnodepoints):
	for xcnodename in prevnodepoints:
		if nextnodepoints == null or not nextnodepoints.has(xcnodename):
			if activetargetnode != null and activetargetnode.get_name() == xcnodename:
				clearactivetargetnode()
			if pointertargettype == "XCnode" and pointertarget != null and pointertarget.get_name() == xcnodename:
				clearpointertarget()

	
func setactivetargetnode(newactivetargetnode):
	clearactivetargetnode()
	activetargetnode = newactivetargetnode
	assert (targettype(activetargetnode) == "XCnode")
	activetargetnodewall = targetwall(activetargetnode, "XCnode")
	if activetargetnode != pointertarget:
		activetargetnode.get_node("CollisionShape/MeshInstance").set_surface_material(0, materialsystem.nodematerial("selected"))
	activelaserroot.get_node("LaserSpot").set_surface_material(0, materialsystem.lasermaterialN((1 if activetargetnode != null else 0) + (2 if pointertarget == null else 0)))
	setpointertargetmaterial()
	if guipanel3d.visible:
		guipanel3d.getflagsignofnodeselected()
		var viewport = guipanel3d.get_node("Viewport")
		viewport.render_target_update_mode = Viewport.UPDATE_WHEN_VISIBLE


func raynormalcollisionmask():
	if planviewsystem.planviewcontrols.get_node("CheckBoxCentrelinesVisible").pressed:
		return CollisionLayer.CLV_MainRayAll
	else:
		return CollisionLayer.CLV_MainRayAllNoCentreline

func setactivetargetwall(newactivetargetwall):
	print("setactivetargetwall ", newactivetargetwall.get_name() if newactivetargetwall != null else "null")
	if activetargetwall != null and activetargetwall.drawingtype == DRAWING_TYPE.DT_XCDRAWING:
		activetargetwall.get_node("XCdrawingplane/CollisionShape/MeshInstance").set_surface_material(0, materialsystem.xcdrawingmaterial("normal"))
		if activetargetwall.get_node("PathLines").get_surface_material_count() != 0: 
			activetargetwall.get_node("PathLines").set_surface_material(0, materialsystem.pathlinematerial("normal"))
		for xcnode in activetargetwall.get_node("XCnodes").get_children():
			xcnode.get_node("CollisionShape/MeshInstance").set_surface_material(0, materialsystem.nodematerial("selected" if xcnode == activetargetnode else clearednodematerialtype(xcnode, false, DRAWING_TYPE.DT_XCDRAWING, activetargetwall.nodepointvalence1s)))
	
	activetargetwall = newactivetargetwall
	pointertargetofstartofropehang = null
	activetargetwallgrabbedtransform = null
	if activetargetwall == planviewsystem:
		print("Waaat")

	if activetargetwall != null and activetargetwall.drawingtype == DRAWING_TYPE.DT_XCDRAWING:
		print("newactivetargetwall ", activetargetwall, " nodes ", activetargetwall.get_node("XCnodes").get_child_count())
		potreeexperiments.sethighlightplaneZone(activetargetwall.transform, 0.15 if Tglobal.housahedronmode else 0.5, false)
	else:
		potreeexperiments.sethighlightplaneZone(null, 0.0, false)
		print("newactivetargetwall notdrawing ", activetargetwall)
	
	LaserOrient.get_node("RayCast").collision_mask = raynormalcollisionmask()
	if activetargetwall != null and activetargetwall.drawingtype == DRAWING_TYPE.DT_XCDRAWING:
		if not activetargetwall.get_node("XCdrawingplane").visible:
			sketchsystem.actsketchchange([{"xcvizstates":{activetargetwall.get_name():DRAWING_TYPE.VIZ_XCD_PLANE_AND_NODES_VISIBLE}}])
		activetargetwall.get_node("XCdrawingplane/CollisionShape/MeshInstance").set_surface_material(0, materialsystem.xcdrawingmaterial("active"))
		if activetargetwall.get_node("PathLines").get_surface_material_count() != 0:
			activetargetwall.get_node("PathLines").set_surface_material(0, materialsystem.pathlinematerial("nodepthtest"))
		else:
			print("PathLines missing surface material")
		for xcnode in activetargetwall.get_node("XCnodes").get_children():
			if xcnode != activetargetnode:
				xcnode.get_node("CollisionShape/MeshInstance").set_surface_material(0, materialsystem.nodematerial(clearednodematerialtype(xcnode, true, DRAWING_TYPE.DT_XCDRAWING, activetargetwall.nodepointvalence1s)))
		if len(activetargetwall.nodepoints) != 0:
			LaserOrient.get_node("RayCast").collision_mask = CollisionLayer.CLV_MainRayXC

	if activetargetwall != null and activetargetwall.drawingtype == DRAWING_TYPE.DT_FLOORTEXTURE:
		assert (false)
		
func _ready():
	handrightcontroller.connect("button_pressed", self, "_on_button_pressed")
	handrightcontroller.connect("button_release", self, "_on_button_release")
	handrighthandtrackingposecontroller.connect("button_pressed", self, "_on_button_pressed")
	handrighthandtrackingposecontroller.connect("button_release", self, "_on_button_release")
	$CubeCornerRayCast.set_as_toplevel(true)

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
	if targetparent.get_name() == "MaterialButtons":
		return "MaterialButton"
	if targetparent.get_parent().get_name() == "GripMenu":
		return "GripMenuItem"
	if targetparent.get_name() == "IntermediatePointView":
		return "IntermediatePointView"
	if targetparent.get_name() == "PathLines" and activetargetnode == null:
		return "IntermediateNode"
	return "unknown"
		
func targetwall(target, targettype):
	if targettype == "XCdrawing":
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
		panelsendreleasemousemotiontopointertarget()
	elif pointertarget == keyboardpanel:
		panelsendreleasemousemotiontopointertarget()
	clearpointertargetmaterial()
	pointertarget = null
	pointertargettype = "none"
	pointertargetwall = null

var prevnotificationtorusvisible = false
func set_handflickmotiongestureposition(lhandflickmotiongestureposition):
	Tglobal.handflickmotiongestureposition = lhandflickmotiongestureposition
	if Tglobal.handflickmotiongestureposition == handflickmotiongestureposition_SHORTPOS:
		activelaserroot.get_node("LaserSpot").set_surface_material(0, materialsystem.lasermaterialN((1 if activetargetnode != null else 0) + 2))
		LaserOrient.get_node("Length/Laser").set_surface_material(0, materialsystem.lasermaterial("laserinair"))
		setpointertarget(activelaserroot, activelaserroot.get_node("RayCast"), handflickmotiongestureposition_shortpos_length)
		activelaserroot.get_node("LaserSpot").visible = true
		prevnotificationtorusvisible = LaserOrient.get_node("NotificationTorus").visible
	else:
		LaserOrient.get_node("Length/Laser").set_surface_material(0, materialsystem.lasermaterial("laser"))
		activelaserroot.get_node("LaserSpot").visible = false
		setpointertarget(activelaserroot, null, -1.0)
		if prevnotificationtorusvisible and LaserOrient.get_node("NotificationTorus").visible:
			LaserOrient.get_node("NotificationTorus").visible = false
			prevnotificationtorusvisible = false
			
func panelsendmousemotiontopointertarget():
	var guipanel = pointertarget
	var controller_trigger = (handrighthandtrackingposecontroller.is_button_pressed(BUTTONS.HT_PINCH_INDEX_FINGER) if Tglobal.questhandtrackingactive else handrightcontroller.is_button_pressed(BUTTONS.VR_TRIGGER)) or Input.is_mouse_button_pressed(BUTTON_LEFT)
	var controller_global_transform = LaserOrient.global_transform
	var collision_point = pointertargetpoint
	guipanel.collision_point = collision_point
	var collider_transform = guipanel.global_transform
	var viewport = guipanel.get_node("Viewport")
	if viewport.has_method("set_update_mode"):
		viewport.set_update_mode(Viewport.UPDATE_WHEN_VISIBLE)
	if collider_transform.xform_inv(controller_global_transform.origin).z < 0:
		return
	var shape_size = guipanel.get_node("CollisionShape").shape.extents * 2
	var collider_scale = collider_transform.basis.get_scale()
	var local_point = collider_transform.xform_inv(collision_point)

	local_point /= (collider_scale * collider_scale)  # this rescaling because of no xform_affine_inv.  https://github.com/godotengine/godot/issues/39433
	local_point /= shape_size
	local_point += Vector3(0.5, -0.5, 0) # X is about 0 to 1, Y is about 0 to -1.
	guipanel.viewport_point = Vector2(local_point.x, -local_point.y) * viewport.size
	
	var event = InputEventMouseMotion.new()
	event.position = guipanel.viewport_point
	viewport.input(event)
	
	var distance = controller_global_transform.origin.distance_to(collision_point)/ARVRServer.world_scale
	var viewport_mousedown = distance < 0.1 or controller_trigger
	if viewport_mousedown != guipanel.current_viewport_mousedown:
		event = InputEventMouseButton.new()
		event.pressed = viewport_mousedown
		event.button_index = BUTTON_LEFT
		event.position = guipanel.viewport_point
		#print("vvvv viewport_point ", guipanel.viewport_point)
		viewport.input(event)
		guipanel.current_viewport_mousedown = viewport_mousedown

func panelsendreleasemousemotiontopointertarget():
	var guipanel = pointertarget
	var viewport = guipanel.get_node("Viewport")
	if guipanel.current_viewport_mousedown:
		var event = InputEventMouseButton.new()
		event.button_index = 1
		event.position = guipanel.viewport_point
		viewport.input(event)
		guipanel.current_viewport_mousedown = false
	var mevent = InputEventMouseMotion.new()
	mevent.position = Vector2(0, 0)
	viewport.input(mevent)
	if not keyboardpanel.visible:
		viewport.render_target_update_mode = Viewport.UPDATE_ONCE
	
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

	var laserspot = laserroot.get_node("LaserSpot")
	if newpointertarget != pointertarget:
		#print("NN ", newpointertarget, " ", raycast.get_collision_point())
		if pointertarget == guipanel3d or pointertarget == keyboardpanel:
			panelsendreleasemousemotiontopointertarget()
		clearpointertargetmaterial()
		pointertarget = newpointertarget
		pointertargettype = targettype(pointertarget)
		pointertargetwall = targetwall(pointertarget, pointertargettype)
		setpointertargetmaterial()
		
		if pointertargettype == "XCnode" or pointertargettype == "IntermediateNode":
			Tglobal.soundsystem.quicksound("PopSound", newpointertargetpoint)
			Tglobal.soundsystem.shortvibrate(false, 0.03, 1.0)
		
		#if activetargetwall == null and pointertargettype == "XCdrawing" and pointertargetwall.drawingtype == DRAWING_TYPE.DT_XCDRAWING and len(pointertargetwall.nodepoints) == 0 and activetargetnode == null:
		#	print("setting blank wall active")
		#	setactivetargetwall(pointertargetwall)

		laserspot.visible = (pointertargettype == "XCdrawing") or \
							(pointertargettype == "XCtubesector") or \
							(pointertargettype == "XCflatshell") or \
							(pointertargettype == "IntermediatePointView") or \
							(pointertargettype == "none" and pointertargetshortdistance != -1.0)
		laserspot.set_surface_material(0, materialsystem.lasermaterialN((1 if activetargetnode != null else 0) + (2 if pointertarget == null else 0)))
		
		var llaserselectlinelogicalvisibilitystate = 0
		if activetargetnodewall != null and activetargetnodewall.drawingtype == DRAWING_TYPE.DT_CENTRELINE:
			var clconnectcode = activetargetnodewall.xccentrelineconnectstofloor(sketchsystem.get_node("XCdrawings"))
			print("clconnectcode ", clconnectcode)
			if pointertargetwall != null:
				if pointertargettype == "XCdrawing" and pointertargetwall.drawingtype == DRAWING_TYPE.DT_FLOORTEXTURE and clconnectcode != 2:
					llaserselectlinelogicalvisibilitystate = 1
				elif pointertargettype == "XCnode" and pointertargetwall.drawingtype == DRAWING_TYPE.DT_CENTRELINE and clconnectcode != 1:
					llaserselectlinelogicalvisibilitystate = 1
				else:
					llaserselectlinelogicalvisibilitystate = 2
			elif Tglobal.handflickmotiongestureposition == handflickmotiongestureposition_SHORTPOS:
				llaserselectlinelogicalvisibilitystate = 1 if clconnectcode == 0 else 2
			
		elif activetargetnode != null and pointertargetwall != null:
			llaserselectlinelogicalvisibilitystate = 0

			if activetargetnodewall.drawingtype == DRAWING_TYPE.DT_XCDRAWING:
				if pointertargettype == "XCnode":
					if pointertarget != activetargetnode:
						llaserselectlinelogicalvisibilitystate = 1 if (pointertargetwall.drawingtype == DRAWING_TYPE.DT_XCDRAWING) else 2
				elif pointertargettype == "XCdrawing":
					if activetargetnodewall == pointertargetwall:
						llaserselectlinelogicalvisibilitystate = 1
					else:
						llaserselectlinelogicalvisibilitystate = 2

			elif activetargetnodewall.drawingtype == DRAWING_TYPE.DT_ROPEHANG:
				if pointertargettype == "XCnode":
					if pointertarget != activetargetnode:
						llaserselectlinelogicalvisibilitystate = 1 if (pointertargetwall == activetargetwall) else 2
				elif pointertargettype == "XCdrawing":
					llaserselectlinelogicalvisibilitystate = 2
				elif Tglobal.handflickmotiongestureposition == handflickmotiongestureposition_SHORTPOS:
					llaserselectlinelogicalvisibilitystate = 1 if (pointertargettype == "none" or pointertargettype == "XCtubesector" or pointertargettype == "XCflatshell") else 2

			elif activetargetnodewall.drawingtype == DRAWING_TYPE.DT_FLOORTEXTURE:
				llaserselectlinelogicalvisibilitystate = 1 if (pointertargettype == "XCdrawing" and pointertargetwall.drawingtype == DRAWING_TYPE.DT_FLOORTEXTURE) else 2
			
		elif pointertargettype == "IntermediatePointView":
			llaserselectlinelogicalvisibilitystate = 1
		elif activetargetnodewall != null and activetargetnodewall.drawingtype == DRAWING_TYPE.DT_ROPEHANG:
			llaserselectlinelogicalvisibilitystate = 1 if ((pointertargettype == "none" and Tglobal.handflickmotiongestureposition == handflickmotiongestureposition_SHORTPOS)) else 2
			
		laserselectlinelogicalvisibilitystate = llaserselectlinelogicalvisibilitystate
		LaserSelectLine.visible = (llaserselectlinelogicalvisibilitystate != 0)
		LaserSelectLine.get_node("Scale/Mesh").get_surface_material(0).albedo_color = LaseSelectLinegoodcolour if laserselectlinelogicalvisibilitystate == 1 else LaseSelectLinebadcolour
		
	pointertargetpoint = newpointertargetpoint
	if is_instance_valid(pointertarget) and pointertarget == guipanel3d and Tglobal.phoneoverlay == null:
		panelsendmousemotiontopointertarget()
	if is_instance_valid(pointertarget) and pointertarget == keyboardpanel and Tglobal.phoneoverlay == null:
		panelsendmousemotiontopointertarget()

	if pointertargetpoint != null:
		laserroot.get_node("LaserSpot").global_transform.origin = pointertargetpoint
		if laserspot.visible:
			if laserroot == LaserOrient:
				var LaserContactDisc = laserspot.get_node("LaserContactDisc")
				if newpointertarget != null and not (pointertargettype == "XCdrawing" and pointertargetwall.drawingtype == DRAWING_TYPE.DT_FLOORTEXTURE):
					var surfaceawayvec = raycast.get_collision_normal()
					if abs(surfaceawayvec.x) < 0.01 and abs(surfaceawayvec.z) < 0.01:
						surfaceawayvec = -LaserOrient.transform.basis.z; 
					LaserContactDisc.global_transform = laserspot.global_transform.looking_at(laserspot.global_transform.origin + surfaceawayvec*10, Vector3(0,1,0))
					LaserContactDisc.visible = true
				else:
					LaserContactDisc.visible = false
		laserroot.get_node("Length").scale.z = -laserroot.get_node("LaserSpot").translation.z
	else:
		laserroot.get_node("Length").scale.z = -laserroot.get_node("RayCast").cast_to.z
		
	if laserroot == LaserOrient:
		if FloorLaserSpot.visible:
			var lfloorspotvisible = false
			if pointertargetpoint != null \
							and not (pointertargettype == "XCdrawing" and pointertargetwall.drawingtype == DRAWING_TYPE.DT_FLOORTEXTURE) \
							and not (pointertargettype == "XCnode" and pointertargetwall.drawingtype == DRAWING_TYPE.DT_ROPEHANG) \
							and (pointertarget != guipanel3d) \
							and (pointertargettype != "PlanView") \
							and (pointertargettype != "GripMenuItem") \
							and (Tglobal.handflickmotiongestureposition == handflickmotiongestureposition_NORMAL):
				FloorLaserSpot.get_node("RayCast").transform.origin = pointertargetpoint
				FloorLaserSpot.get_node("RayCast").force_raycast_update()
				if FloorLaserSpot.get_node("RayCast").is_colliding() and FloorLaserSpot.visible:
					var floorspotpt = FloorLaserSpot.get_node("RayCast").get_collision_point()
					FloorLaserSpot.get_node("FloorSpot").transform = Transform(laserspot.get_node("LaserContactDisc").global_transform.basis, floorspotpt)
					lfloorspotvisible = (pointertargetpoint - floorspotpt).length() > 0.2
			FloorLaserSpot.get_node("FloorSpot").visible = lfloorspotvisible

		
	if activetargetnodetriggerpulling:
		# solve tpnodepoint + a*activetargetnodewall.transform.basis.z = LaserOrient.transform.origin - b*LaserOrient.transform.basis.z
		var tpnodepoint = activetargetnodewall.nodepoints[activetargetnode.get_name()]
		var nodezerozposition = activetargetnodewall.transform.xform(Vector3(tpnodepoint.x, tpnodepoint.y, 0))
		var gp = LaserOrient.transform.origin - nodezerozposition
		# solve gp = a*activetargetnodewall.transform.basis.z + b*LaserOrient.transform.basis.z
		#gp . activetargetnodewall.transform.basis.z = a + b*LaserOrient.transform.basis.z . activetargetnodewall.transform.basis.z
		#gp . LaserOrient.transform.basis.z = a*activetargetnodewall.transform.basis.z . LaserOrient.transform.basis.z + b
		var ldots = activetargetnodewall.transform.basis.z.dot(LaserOrient.transform.basis.z)
		var gpdnd = gp.dot(activetargetnodewall.transform.basis.z)
		var gpdlz = gp.dot(LaserOrient.transform.basis.z)
		# gpdnd = a + b*ldots; gpdlz = a*ldots + b
		# gpdnd = a + gpdlz*ldots - a*ldots*ldots
		# a*(1 - ldots*ldots) = gpdnd - gpdlz*ldots
		var aden = 1 - ldots*ldots
		if abs(aden) > 0.01:
			var a = (gpdnd - gpdlz*ldots)/aden
			var b = gpdlz - a*ldots
			var av = nodezerozposition + a*activetargetnodewall.transform.basis.z
			var bv = LaserOrient.transform.origin - b*LaserOrient.transform.basis.z
			var skewdist = av.distance_to(bv)
			LaserSelectLine.transform = Transform(activetargetnodewall.transform.basis, nodezerozposition)
			LaserSelectLine.get_node("Scale").scale = Vector3(selectlinefatness, selectlinefatness, -a)
			nodetriggerpulledmaxd = max(nodetriggerpulledmaxd, abs(activetargetnodetriggerpulledz - tpnodepoint.z))
			LaserSelectLine.visible = (skewdist < 0.1) and (abs(a) < nodetriggerpullinglimit) and \
					(nodetriggerpulledmaxd > nodetriggerpullingmind) and (OS.get_ticks_msec()*0.001 - nodetriggerpulledtimestamp > nodetriggerpullingminduration) and \
					not activetargetnodewall.get_name().begins_with("Hole;")
			activetargetnodetriggerpulledz = a
		else:
			LaserSelectLine.visible = false
		
	elif laserselectlinelogicalvisibilitystate != 0:
		LaserSelectLine.visible = not activetargetnodetriggerpulling
		var lslfrom = null
		if pointertarget != null and activetargetnode != null:
			lslfrom = activetargetnode.global_transform.origin
		elif pointertargettype == "IntermediatePointView":
			lslfrom = get_node("/root/Spatial/BodyObjects/IntermediatePointView/IntermediatePointPlaneStartingMarker").transform.origin
		elif activetargetnode != null and pointertargettype == "none" and Tglobal.handflickmotiongestureposition == handflickmotiongestureposition_SHORTPOS:
			lslfrom = activetargetnode.global_transform.origin
		else:
			LaserSelectLine.visible = false
		if lslfrom != null:
			LaserSelectLine.transform.origin = GripLaserSpot.transform.origin if GripLaserSpot.visible else pointertargetpoint
			var d = LaserSelectLine.transform.origin.distance_to(lslfrom)
			LaserSelectLine.get_node("Scale").scale = Vector3(selectlinefatness, selectlinefatness, max(0.01, d))
			if not is_zero_approx(d):
				LaserSelectLine.transform = LaserSelectLine.transform.looking_at(lslfrom, Vector3(0,1,0))

func _on_button_pressed(p_button):
	var gripbuttonheld = handright.gripbuttonheld
	print("pppp ", pointertargetpoint, " ", [activetargetnode, pointertargettype, " pbutton", p_button])
	if Tglobal.questhandtrackingactive:
		gripbuttonheld = handrighthandtrackingposecontroller.is_button_pressed(BUTTONS.HT_PINCH_MIDDLE_FINGER)
		if p_button == BUTTONS.HT_PINCH_RING_FINGER:
			if handrighthandtrackingposecontroller.is_button_pressed(BUTTONS.HT_PINCH_PINKY):
				buttonpressed_vrby()
		elif p_button == BUTTONS.HT_PINCH_PINKY:
			if handrighthandtrackingposecontroller.is_button_pressed(BUTTONS.HT_PINCH_RING_FINGER):
				buttonpressed_vrby()
		elif Tglobal.controlslocked:
			print("Controls locked")
		elif p_button == BUTTONS.HT_PINCH_INDEX_FINGER:
			buttonpressed_vrtrigger(gripbuttonheld)
		elif p_button == BUTTONS.HT_PINCH_MIDDLE_FINGER:
			buttonpressed_vrgrip()
	else:
		if p_button == BUTTONS.VR_BUTTON_BY:
			buttonpressed_vrby()
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

func buttonpressed_vrby():
	if Tglobal.controlslocked:
		if not guipanel3d.visible:
			guipanel3d.setguipanelvisible(LaserOrient.global_transform)
		else:
			print("controls locked")
	elif planviewsystem.visible and (pointerplanviewtarget != null or pointertargettype == "PlanView"):
		planviewsystem.actplanviewdict({ "visible":true, "planviewactive":not planviewsystem.planviewactive })
	elif guipanel3d.visible:
		guipanel3d.setguipanelhide()
	else:
		guipanel3d.setguipanelvisible(LaserOrient.global_transform)

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
		materialsystem.updateflatshellmaterial(activetargetxcflatshell, "all")

	gripmenu.gripmenuon(LaserOrient.global_transform, pointertargetpoint, pointertargetwall, pointertargettype, pointertarget, activetargettube, activetargettubesectorindex, activetargetwall, activetargetnode, activetargetnodewall, pointertargetofstartofropehang)
	
func ropepointtargetUV():
	var pointertargettube = pointertargetwall
	var ipbasis = pointertargettube.intermedpointplanebasis(pointertargetpoint)
	var xcdrawing0 = sketchsystem.get_node("XCdrawings").get_node(pointertargettube.xcname0)
	var xcdrawing1 = sketchsystem.get_node("XCdrawings").get_node(pointertargettube.xcname1)
	var xcdrawing0nodes = xcdrawing0.get_node("XCnodes")
	var xcdrawing1nodes = xcdrawing1.get_node("XCnodes")
	var aroundsegment = pointertarget.get_index()
	var jA = aroundsegment*2
	var p0 = xcdrawing0nodes.get_node(pointertargettube.xcdrawinglink[jA]).global_transform.origin
	var p1 = xcdrawing1nodes.get_node(pointertargettube.xcdrawinglink[jA+1]).global_transform.origin
	var ropepointlamda = inverse_lerp(ipbasis.z.dot(p0), ipbasis.z.dot(p1), ipbasis.z.dot(pointertargetpoint))
	var pc = lerp(p0, p1, ropepointlamda)
	
	var jB = (jA + 2) % len(pointertargettube.xcdrawinglink)
	var p0B = xcdrawing0nodes.get_node(pointertargettube.xcdrawinglink[jB]).global_transform.origin
	var p1B = xcdrawing1nodes.get_node(pointertargettube.xcdrawinglink[jB+1]).global_transform.origin
	var ropepointlamdaB = inverse_lerp(ipbasis.z.dot(p0B), ipbasis.z.dot(p1B), ipbasis.z.dot(pointertargetpoint))
	var pcB = lerp(p0B, p1B, ropepointlamdaB)
	var pcvec = pcB - pc
	var pcveclen = pcvec.length_squared()
	var lambdaCalong = pcvec.dot(pointertargetpoint - pc)/(pcveclen if pcveclen != 0 else 1.0)
	print("ropepointUV ", pointertargettube.get_name(), [ropepointlamda, ropepointlamdaB], [aroundsegment, lambdaCalong])
	var usec = int(pointertargettube.get_name().split("_")[1])
	return Vector3((usec + ropepointlamda)/Tglobal.wingmeshuvudivisions, (aroundsegment + lambdaCalong)/Tglobal.wingmeshuvvdivisions, 0)

		
var initialsequencenodename = null
var initialsequencenodenameP = null
var vrtrigger_prevbuttontime_forxcdrawinggrabmotion = 0
const vrtrigger_prevbuttontime_forxcdrawinggrabmotion_doubleclicktime = 700
func buttonpressed_vrtrigger(gripbuttonheld):
	initialsequencenodenameP = initialsequencenodename
	initialsequencenodename = null

	if Tglobal.handflickmotiongestureposition == handflickmotiongestureposition_SHORTPOS and activetargetnodewall != null and activetargetnodewall.drawingtype == DRAWING_TYPE.DT_ROPEHANG and \
			(pointertargettype == "none" or pointertargettype == "XCtubesector" or pointertargettype == "XCflatshell"):
		var newnodepoint = activetargetnodewall.global_transform.xform_inv(pointertargetpoint)
		var xcdata = null
		var newactivetargetnodeinfo = null
		if gripbuttonheld:
			if true or activetargetnode.get_name()[0] == ("k" if pointertargettype == "none" else "a"):
				xcdata = { "name":activetargetnodewall.get_name(), 
						   "prevnodepoints":{ activetargetnode.get_name():activetargetnode.translation }, 
						   "nextnodepoints":{ activetargetnode.get_name():newnodepoint } 
						 }
				clearactivetargetnode()
		else:
			var newnodename = activetargetnodewall.newuniquexcnodename("k" if pointertargettype == "none" else "a")
			xcdata = { "name":activetargetnodewall.get_name(), 
					   "prevnodepoints":{ }, 
					   "nextnodepoints":{ newnodename:newnodepoint } 
					 }
			xcdata["prevonepathpairs"] = [ ]
			xcdata["newonepathpairs"] = [ activetargetnode.get_name(), newnodename]
			newactivetargetnodeinfo = [activetargetnodewall, newnodename]

		if xcdata != null:
			var xcdatalist = [ xcdata ]
			sketchsystem.actsketchchange(xcdatalist)
			if newactivetargetnodeinfo != null:
				setactivetargetnode(newactivetargetnodeinfo[0].get_node("XCnodes").get_node(newactivetargetnodeinfo[1]))

	elif activetargetnodewall != null and activetargetnodewall.drawingtype == DRAWING_TYPE.DT_CENTRELINE \
			and activetargetnodewall.xccentrelineconnectstofloor(sketchsystem.get_node("XCdrawings")) != 1 \
			and gripbuttonheld and Tglobal.handflickmotiongestureposition == handflickmotiongestureposition_SHORTPOS:

		var tvec = pointertargetpoint - activetargetnode.global_transform.origin
		var transformpos = activetargetnodewall.transform
		transformpos.origin += tvec
		var txcdata = { "name":activetargetnodewall.get_name(), 
						"prevtransformpos":activetargetnodewall.transform,
						"transformpos":transformpos }
		sketchsystem.actsketchchange([txcdata])
		clearactivetargetnode()
				
	elif not is_instance_valid(pointertarget):
		if activetargetwall != null:
			activetargetwall.expandxcdrawingscaletoray(activelaserroot.get_node("RayCast"), null)
		
	elif pointertarget == guipanel3d:
		pass  # done in _process()

	elif pointertarget.has_method("jump_up"):
		pointertarget.jump_up()

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

		if activetargetnodewall.drawingtype == DRAWING_TYPE.DT_FLOORTEXTURE:
			var xctubec = null
			var xcdrawingc = null
			for xctube in activetargetnodewall.xctubesconn:
				var xcdrawingcname = (xctube.xcname1 if xctube.xcname0 == activetargetnodewall.get_name() else xctube.xcname0)
				xcdrawingc = sketchsystem.get_node("XCdrawings").get_node(xcdrawingcname)
				if xcdrawingc.drawingtype == DRAWING_TYPE.DT_CENTRELINE:
					xctubec = xctube
			if xctubec != null:
				var floormovedata = xctubec.centrelineconnectionfloortransformpos(sketchsystem)
				if len(floormovedata) != 0:
					sketchsystem.actsketchchange(floormovedata)

		clearactivetargetnode()
		
	elif gripbuttonheld and activetargetnode != null and pointertarget == activetargetnode \
			and (activetargetnodewall.drawingtype != DRAWING_TYPE.DT_CENTRELINE) \
			and (not activetargetnodewall.get_name().begins_with("Hole;")):
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


		#clearactivetargetnode()
		#clearpointertarget()
		sketchsystem.actsketchchange(xcdatalist)
		if Tglobal.handflickmotiongestureposition == handflickmotiongestureposition_SHORTPOS:
			activelaserroot.get_node("LaserSpot").visible = true
		
	#elif Tglobal.handflickmotiongestureposition == handflickmotiongestureposition_SHORTPOS:
	#	activelaserroot.get_node("LaserSpot").set_surface_material(0, materialsystem.lasermaterialN((1 if activetargetnode != null else 0) + 2))
	#	activelaserroot.get_node("LaserSpot").visible = true

		#Tglobal.soundsystem.quicksound("BlipSound", pointertargetpoint)

	elif activetargetnode != null and pointertarget == activetargetnode:
		clearactivetargetnode()

	elif activetargetnode == null and activetargetnodewall == null and Tglobal.handflickmotiongestureposition == handflickmotiongestureposition_SHORTPOS and (pointertargettype == "XCtubesector" or pointertargettype == "XCflatshell"):
		pointertargetofstartofropehang = pointertargetwall
		var xcdata = { "name":sketchsystem.uniqueXCname("r"), 
					   "drawingtype":DRAWING_TYPE.DT_ROPEHANG,
					   "transformpos":Transform(),
					   "prevnodepoints":{ },
					   "nextnodepoints":{"a0":pointertargetpoint} }
		sketchsystem.actsketchchange([xcdata, { "xcvizstates":{ xcdata["name"]:DRAWING_TYPE.VIZ_XCD_NODES_VISIBLE }}])
		var xcrope = sketchsystem.get_node("XCdrawings").get_node(xcdata["name"])
		setactivetargetnode(xcrope.get_node("XCnodes").get_node("a0"))

	elif activetargetnode == null and activetargetnodewall == null and Tglobal.handflickmotiongestureposition == handflickmotiongestureposition_NORMAL and pointertargettype == "XCtubesector" and pointertargetwall.get_node("PathLines").visible:
		var pointertargettube = pointertargetwall
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

				var olddiscrad = IntermediatePointView.get_node("IntermediatePointPlane/CollisionShape").shape.radius
				var mindiscrad = ceil(Vector2(intermediatepointpicked.x, intermediatepointpicked.y).length() + 0.05)
				if mindiscrad > olddiscrad:
					IntermediatePointView.get_node("IntermediatePointPlane/CollisionShape").shape.radius = mindiscrad
					IntermediatePointView.get_node("IntermediatePointPlane/CollisionShape/MeshInstance").mesh.top_radius = mindiscrad
					IntermediatePointView.get_node("IntermediatePointPlane/CollisionShape/MeshInstance").mesh.bottom_radius = mindiscrad
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
			var newintermediatepoint = null
			if not gripbuttonheld:
				newintermediatepoint = Vector3(dvd.x, dvd.y, intermediatepointplanelambda)
			if (intermediatepointpicked != null) or (newintermediatepoint != null):
				var xctdata = { "tubename":intermediatepointplanetubename,
								"xcname0":splinepointplanetube.xcname0,
								"xcname1":splinepointplanetube.xcname1,
								"prevdrawinglinks":[ nodename0, nodename1, null, (null if (intermediatepointpicked == null) else [ intermediatepointpicked ]) ], 
								"newdrawinglinks":[ nodename0, nodename1, null, (null if (newintermediatepoint == null) else [ newintermediatepoint ]) ] 
							  }
				var xctuberedraw = {"xcvizstates":{ }, "updatetubeshells":[{"tubename":intermediatepointplanetubename, "xcname0":splinepointplanetube.xcname0, "xcname1":splinepointplanetube.xcname1 }] }
				sketchsystem.actsketchchange([xctdata, xctuberedraw])
				var xcdatashellholes = findconstructtubeshellholes([splinepointplanetube])
				if xcdatashellholes != null:
					sketchsystem.actsketchchange(xcdatashellholes)
				
			clearintermediatepointplaneview()
				
	elif pointertargettype == "PlanView":
		clearactivetargetnode()
		var alaserspot = activelaserroot.get_node("LaserSpot")
		alaserspot.global_transform.origin = pointertargetpoint
		activetargetwallgrabbed = pointertargetwall.get_node("PlanView")

		if gripbuttonheld:
			activetargetwallgrabbedtransform = alaserspot.global_transform.affine_inverse() * activetargetwallgrabbed.global_transform
			activetargetwallgrabbedpoint = alaserspot.global_transform.origin
			activetargetwallgrabbedlength = alaserspot.transform.origin.z
			activetargetwalljoyposcumulative = joyposcumulative
			activetargetwallgrabbedlocalpoint = activetargetwallgrabbed.global_transform.affine_inverse() * alaserspot.global_transform.origin
			activetargetwallgrabbedpointoffset = alaserspot.global_transform.origin - activetargetwallgrabbed.global_transform.origin
		else:
			activetargetwallgrabbedtransform = alaserspot.global_transform.affine_inverse() * activetargetwallgrabbed.global_transform
			activetargetwallgrabbedpoint = null
			activetargetwallgrabbedlength = 0
		activetargetwallgrabbedmotion = DRAWING_TYPE.GRABMOTION_ROTATION_ADDITIVE
			
	elif pointertargettype == "XCdrawing" and pointertargetwall.drawingtype == DRAWING_TYPE.DT_XCDRAWING:
		if pointertargetwall != activetargetwall:
			setactivetargetwall(pointertargetwall)
			
		if gripbuttonheld:
			pointertargetwall.expandxcdrawingscale(pointertargetpoint)
			if len(pointertargetwall.nodepoints) == 0:
				activetargetwallgrabbedmotion = DRAWING_TYPE.GRABMOTION_PRIMARILY_LOCKED_VERTICAL
			elif OS.get_ticks_msec() - vrtrigger_prevbuttontime_forxcdrawinggrabmotion < vrtrigger_prevbuttontime_forxcdrawinggrabmotion_doubleclicktime:
				activetargetwallgrabbedmotion = DRAWING_TYPE.GRABMOTION_PRIMARILY_LOCKED_VERTICAL_ROTATION_ONLY
			else:
				activetargetwallgrabbedmotion = DRAWING_TYPE.GRABMOTION_NONE
				vrtrigger_prevbuttontime_forxcdrawinggrabmotion = OS.get_ticks_msec()

			if activetargetwallgrabbedmotion != DRAWING_TYPE.GRABMOTION_NONE:
				clearactivetargetnode()
				var alaserspot = activelaserroot.get_node("LaserSpot")
				alaserspot.global_transform.origin = pointertargetpoint
				activetargetwallgrabbed = activetargetwall
				activetargetwallgrabbedlaserroottrans = activelaserroot.global_transform
				activetargetwallgrabbedtransform = alaserspot.global_transform.affine_inverse() * activetargetwallgrabbed.global_transform
				activetargetwallgrabbedorgtransform = activetargetwallgrabbed.global_transform
				activetargetwallgrabbeddispvector = alaserspot.global_transform.origin - activelaserroot.global_transform.origin
				activetargetwallgrabbedpoint = alaserspot.global_transform.origin
				activetargetwallgrabbedlength = alaserspot.transform.origin.z
				activetargetwalljoyposcumulative = joyposcumulative
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
				var pathlines = pointertargetwall.get_node("PathLines")
				if pathlines.get_surface_material_count() != 0:
					pathlines.set_surface_material(0, materialsystem.pathlinematerial("nodepthtest"))
				pointertargetwall.expandxcdrawingscale(pointertargetpoint)
				activetargetnodetriggerpulling = true
				nodetriggerpulledmaxd = 0.0
				nodetriggerpulledtimestamp = OS.get_ticks_msec()*0.001
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
			sketchsystem.setnewtubename(xctdata)
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
		var xctupdate = { "xcvizstates":{ }, "updatetubeshells":[{"tubename":xctdata["tubename"], "xcname0":xcname0_centreline, "xcname1":xcname1_floor }] }
		sketchsystem.actsketchchange([xcndata, xctdata, xctupdate])
		if xctube == null:
			xctube = sketchsystem.findxctube(xcname0_centreline, xcname1_floor)
		if len(xctube.xcdrawinglink) != 0:
			var floormovedata = xctube.centrelineconnectionfloortransformpos(sketchsystem)
			if len(floormovedata) != 0:
				sketchsystem.actsketchchange(floormovedata)
		clearactivetargetnode()

	elif activetargetnode != null and activetargetnodewall.drawingtype == DRAWING_TYPE.DT_CENTRELINE \
			and pointertargettype == "XCnode" and pointertargetwall.drawingtype == DRAWING_TYPE.DT_CENTRELINE and activetargetnodewall != pointertargetwall \
			and activetargetnodewall.xccentrelineconnectstofloor(sketchsystem.get_node("XCdrawings")) != 1 and pointertargetwall.xccentrelineconnectstofloor(sketchsystem.get_node("XCdrawings")) != 2:

		var xcname0_centreline = activetargetnodewall.get_name()
		var nodename0_station = activetargetnode.get_name()
		var xcname1_centreline = pointertargetwall.get_name()
		var nodename1_station = pointertarget.get_name()
		var xctube = sketchsystem.findxctube(xcname0_centreline, xcname1_centreline)
		var xctdata = { "xcname0": xcname0_centreline, "xcname1":xcname1_centreline }
		xctdata["newdrawinglinks"] = [ nodename0_station, nodename1_station, "centrelinenodemapping", null ]
		xctdata["prevdrawinglinks"] = [ ]
		if xctube != null:
			xctdata["tubename"] = xctube.get_name()
			var j = xctube.linkspresentindex(nodename0_station, null)
			if j != -1:
				var repcentrenodename = xctube.xcdrawinglink[j*2+1]
				xctdata["prevdrawinglinks"] = [ nodename0_station, repcentrenodename, xctube.xcsectormaterials[j], null ]
				if nodename1_station == repcentrenodename:
					xctdata["newdrawinglinks"] = [ ]
		else:
			xctdata["tubename"] = "**notset"
			sketchsystem.setnewtubename(xctdata)

		var xctupdate = { "xcvizstates":{ }, "updatetubeshells":[{"tubename":xctdata["tubename"], "xcname0":xcname0_centreline, "xcname1":xcname1_centreline }] }
		sketchsystem.actsketchchange([xctdata, xctupdate])
			
		clearactivetargetnode()


	elif pointertargettype == "XCdrawing" and pointertargetwall.drawingtype == DRAWING_TYPE.DT_FLOORTEXTURE:
		if planviewsystem.planviewactive:
			if gripbuttonheld and planviewsystem.activetargetfloor == pointertargetwall:
				sketchsystem.actsketchchange([planviewsystem.getactivetargetfloorViz("")])
			else:
				sketchsystem.actsketchchange([planviewsystem.getactivetargetfloorViz(pointertargetwall.get_name())])

		elif (pointertargetwall.drawingvisiblecode & DRAWING_TYPE.VIZ_XCD_FLOOR_NOSHADE_B) != 0 and gripbuttonheld: 
			clearactivetargetnode()
			var alaserspot = activelaserroot.get_node("LaserSpot")
			alaserspot.global_transform.origin = pointertargetpoint
			activetargetwallgrabbed = pointertargetwall
			activetargetwallgrabbedlaserroottrans = activelaserroot.global_transform
			activetargetwallgrabbedtransform = alaserspot.global_transform.affine_inverse() * activetargetwallgrabbed.global_transform
			activetargetwallgrabbedorgtransform = activetargetwallgrabbed.global_transform
			activetargetwallgrabbeddispvector = alaserspot.global_transform.origin - activelaserroot.global_transform.origin
			activetargetwallgrabbedpoint = alaserspot.global_transform.origin
			activetargetwallgrabbedlength = alaserspot.transform.origin.z
			activetargetwalljoyposcumulative = joyposcumulative
			activetargetwallgrabbedlocalpoint = activetargetwallgrabbed.global_transform.affine_inverse() * alaserspot.global_transform.origin
			activetargetwallgrabbedpointoffset = alaserspot.global_transform.origin - activetargetwallgrabbed.global_transform.origin
			
			#activetargetwallgrabbedmotion = DRAWING_TYPE.GRABMOTION_ROTATION_ADDITIVE
			activetargetwallgrabbedmotion = DRAWING_TYPE.GRABMOTION_DIRECTIONAL_DRAGGING
			if Input.is_key_pressed(KEY_CONTROL) or handrightcontroller.is_button_pressed(BUTTONS.VR_BUTTON_AX):
				activetargetwallgrabbedmotion = DRAWING_TYPE.GRABMOTION_ROTATION_ADDITIVE

		else:
			if not (activetargetwall != null and activetargetwall.expandxcdrawingscaletoray(activelaserroot.get_node("RayCast"), pointertargetpoint)):
				var imagesystem = get_node("/root/Spatial/ImageSystem")
				imagesystem.shuffleimagetotopoflist(pointertargetwall)

	elif gripbuttonheld and pointertargettype == "XCflatshell" and pointertargetwall.drawingtype == DRAWING_TYPE.DT_ROPEHANG and pointertargetwall.ropehangdetectedtype == DRAWING_TYPE.RH_BOULDER:
		clearactivetargetnode()
		var alaserspot = activelaserroot.get_node("LaserSpot")
		alaserspot.global_transform.origin = pointertargetpoint
		activetargetwallgrabbed = pointertargetwall
		activetargetwallgrabbedlaserroottrans = activelaserroot.global_transform
		activetargetwallgrabbedtransform = alaserspot.global_transform.affine_inverse() * activetargetwallgrabbed.global_transform
		activetargetwallgrabbedorgtransform = activetargetwallgrabbed.global_transform
		activetargetwallgrabbeddispvector = alaserspot.global_transform.origin - activelaserroot.global_transform.origin
		activetargetwallgrabbedpoint = alaserspot.global_transform.origin
		activetargetwallgrabbedlength = alaserspot.transform.origin.z
		activetargetwalljoyposcumulative = joyposcumulative
		activetargetwallgrabbedlocalpoint = activetargetwallgrabbed.global_transform.affine_inverse() * alaserspot.global_transform.origin
		activetargetwallgrabbedpointoffset = alaserspot.global_transform.origin - activetargetwallgrabbed.global_transform.origin
		activetargetwallgrabbedmotion = DRAWING_TYPE.GRABMOTION_DIRECTIONAL_DRAGGING
		if Input.is_key_pressed(KEY_CONTROL) or handrightcontroller.is_button_pressed(BUTTONS.VR_BUTTON_AX):
			activetargetwallgrabbedmotion = DRAWING_TYPE.GRABMOTION_ROTATION_ADDITIVE

			
	elif activetargetnode != null and pointertargettype == "XCnode" and (pointertargetwall.drawingtype == DRAWING_TYPE.DT_XCDRAWING or pointertargetwall.drawingtype == DRAWING_TYPE.DT_ROPEHANG):
		if activetargetnodewall == pointertargetwall and (activetargetnodewall.drawingtype == DRAWING_TYPE.DT_XCDRAWING or activetargetnodewall.drawingtype == DRAWING_TYPE.DT_ROPEHANG) \
				and (not activetargetnodewall.get_name().begins_with("Hole;")):
			var xcdata = { "name":pointertargetwall.get_name() }
			var i0 = activetargetnode.get_name()
			var i1 = pointertarget.get_name()
			if pointertargetwall.pairpresentindex(i0, i1) != -1:
				xcdata["prevonepathpairs"] = [i0, i1]
				xcdata["newonepathpairs"] = [ ]
			else:
				if initialsequencenodenameP != null and initialsequencenodenameP != activetargetnode.get_name() and pointertargetwall.drawingtype == DRAWING_TYPE.DT_XCDRAWING:
					xcdata["prevonepathpairs"] = [ initialsequencenodenameP, pointertarget.get_name() ]
				else:   # ^^ rejoin and delete straight line
					xcdata["prevonepathpairs"] = [ ]
				xcdata["newonepathpairs"] = [i0, i1]
			var xcdatalist = [ xcdata ]
			if pointertargetwall.drawingvisiblecode != DRAWING_TYPE.VIZ_XCD_PLANE_AND_NODES_VISIBLE:
				xcdatalist.push_back({"xcvizstates":{ pointertargetwall.get_name():DRAWING_TYPE.VIZ_XCD_PLANE_AND_NODES_VISIBLE } })
			sketchsystem.actsketchchange(xcdatalist)
			
		elif activetargetnodewall != pointertargetwall:
			var applytubeconnection = activetargetnodewall.drawingtype == DRAWING_TYPE.DT_XCDRAWING and pointertargetwall.drawingtype == DRAWING_TYPE.DT_XCDRAWING
			if applytubeconnection:
				var xcname0 = activetargetnodewall.get_name()
				var nodename0 = activetargetnode.get_name()
				var xcname1 = pointertargetwall.get_name()
				var nodename1 = pointertarget.get_name()
				var xctube = sketchsystem.findxctube(xcname0, xcname1)
				var xctdata = { "xcname0": xcname0, "xcname1":xcname1 }
				if xctube == null:
					xctdata["tubename"] = "**notset"
					sketchsystem.setnewtubename(xctdata)
					xctdata["prevdrawinglinks"] = [ ]
					xctdata["newdrawinglinks"] = [ nodename0, nodename1, "simpledirt", null ]
				else:
					xctdata["tubename"] = xctube.get_name()
					var j = xctube.linkspresentindex(nodename0, nodename1) if xctube.xcname0 == xcname0 else xctube.linkspresentindex(nodename1, nodename0)
					
					if j == -1:
						xctdata["prevdrawinglinks"] = [ ]
						xctdata["newdrawinglinks"] = [ nodename0, nodename1, "simpledirt", null ]
					else:
						var tubeshellholeindexes = xctube.gettubeshellholes(sketchsystem)
						if tubeshellholeindexes != null:
							for k in range(1, len(tubeshellholeindexes)):
								var jh = tubeshellholeindexes[k]
								if j == jh or j == ((jh + 1) % len(xctube.xcsectormaterials)):
									print("suppressing deletion of tubelink connected to a HoleXC")
									applytubeconnection = false
						xctdata["prevdrawinglinks"] = [ nodename0, nodename1, xctube.xcsectormaterials[j], (xctube.xclinkintermediatenodes[j] if xctube.xclinkintermediatenodes != null else null) ]
						xctdata["newdrawinglinks"] = [ ]
						
				if applytubeconnection:
					var xctdatalist = [ xctdata ]
					#if pointertargetwall.drawingvisiblecode != DRAWING_TYPE.VIZ_XCD_PLANE_AND_NODES_VISIBLE and activetargetnodewall.drawingvisiblecode != DRAWING_TYPE.VIZ_XCD_PLANE_AND_NODES_VISIBLE:
					xctdatalist.push_back({ "xcvizstates":{ }, "updatetubeshells":[{"tubename":xctdata["tubename"], "xcname0": xcname0, "xcname1":xcname1 }] })
					sketchsystem.actsketchchange(xctdatalist)

			else:
				print("Cannot make xcdrawiing to ropehang tube connection")
		clearactivetargetnode()
											
	elif activetargetnode == null and pointertargettype == "XCnode":
		if pointertargetwall.drawingtype == DRAWING_TYPE.DT_XCDRAWING:
			if pointertargetwall != activetargetwall:
				setactivetargetwall(pointertargetwall if not pointertargetwall.get_name().begins_with("Hole;") else null)
			setactivetargetnode(pointertarget)
			activetargetnodetriggerpulling = true
			nodetriggerpulledmaxd = 0.0
			nodetriggerpulledtimestamp = OS.get_ticks_msec()*0.001
		else:
			if pointertargetwall.drawingtype == DRAWING_TYPE.DT_ROPEHANG:
				if pointertargetwall.drawingvisiblecode == DRAWING_TYPE.VIZ_XCD_HIDE:
					sketchsystem.actsketchchange([{"xcvizstates":{pointertargetwall.get_name():DRAWING_TYPE.VIZ_XCD_NODES_VISIBLE}}])
			setactivetargetnode(pointertarget)
		initialsequencenodename = pointertarget.get_name()

	elif activetargetwall != null:
		activetargetwall.expandxcdrawingscaletoray(activelaserroot.get_node("RayCast"), pointertargetpoint)
		
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
				
	elif pointertargettype == "PlanView" or pointerplanviewtarget != null:
		if planviewsystem.planviewactive:
			if planviewsystem.fileviewtree.visible:
				var itemselected = planviewsystem.fileviewtree.get_selected()
				if itemselected != null:
					planviewsystem.fetchbuttonpressed(itemselected, 0, -1)
			
func exchdictptrs(xcdata, e0, e1):
	if e0 in xcdata:
		var e0d = xcdata[e0]
		xcdata[e0] = xcdata[e1]
		xcdata[e1] = e0d

func buttonreleased_vrgrip():
	var wasactivetargettube = activetargettube
	if activetargettube != null:
		activetargettube.setxctubepathlinevisibility(sketchsystem)
		if pointertargettype == "MaterialButton":
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

	if pointertargettype == "MaterialButton" and gripmenu.gripmenupointertargettype == "XCnode" and gripmenu.gripmenupointertargetwall != null:
		var newflatshellmaterialname = pointertarget.get_name()
		var newadditionalproperties = gripmenu.gripmenupointertargetwall.additionalproperties
		if newadditionalproperties == null:
			newadditionalproperties = { }
		if not newadditionalproperties.has("shellfacematerials"):
			newadditionalproperties["shellfacematerials"] = { }
		var nodename = gripmenu.gripmenupointertarget.get_name()
		newadditionalproperties["shellfacematerials"][nodename] = newflatshellmaterialname
		var xcdata = { "name":gripmenu.gripmenupointertargetwall.get_name(), 
					   "additionalproperties":newadditionalproperties 
					 }
		var xctupdate = {"xcvizstates":{ }, "updatexcshells":[ gripmenu.gripmenupointertargetwall.get_name() ] }
		sketchsystem.actsketchchange([xcdata, xctupdate])
		gripmenu.disableallgripmenus()
		return

	if activetargetxcflatshell != null:
		if pointertargettype == "MaterialButton":
			assert (gripmenu.gripmenupointertargettype == "XCflatshell") 
			var newflatshellmaterialname = pointertarget.get_name()
			var aflatshellname = activetargetxcflatshell.get_name()
			sketchsystem.actsketchchange([{ "name":aflatshellname, 
											"prevxcflatshellmaterial":activetargetxcflatshell.xcflatshellmaterial,
											"nextxcflatshellmaterial":newflatshellmaterialname
										 }])
			gripmenu.disableallgripmenus()

			if Tglobal.housahedronmode:
				print("aflatshellname", aflatshellname)
				var xcdrawingM = sketchsystem.get_node("XCdrawings").get_node(aflatshellname)
				var MQTT = get_node_or_null("/root/Spatial/MQTTExperiment/MQTT")
				if MQTT and MQTT.is_connected_to_server():
					var xcflatshell = xcdrawingM.get_node_or_null("XCflatshell/MeshInstance")
					var xctubeshellmesh = xcflatshell.mesh if xcflatshell else null
					var tfaces = xctubeshellmesh.get_faces() if xctubeshellmesh else null
					if tfaces:
						var minx = tfaces[0].x
						var maxx = tfaces[0].x
						var trianglearea = 0.0
						for i in range(len(tfaces)):
							minx = min(minx, tfaces[i].x)
							maxx = max(maxx, tfaces[i].x)
							if (i%3) == 2:
								trianglearea += 0.5*(tfaces[i] - tfaces[i-2]).cross(tfaces[i] - tfaces[i-1]).length()
						var payload = { "source":"tunnelvr", 
										"name":aflatshellname, 
										"xcflatshellmaterial":xcdrawingM.xcflatshellmaterial, 
										"width":(maxx-minx), 
										"area":trianglearea,
										"orientationvec":[xcdrawingM.transform.basis.z.x, xcdrawingM.transform.basis.z.y, xcdrawingM.transform.basis.z.z]
									  }
						MQTT.publish("sapjs/vr1/json", to_json(payload))

			return
		materialsystem.updateflatshellmaterial(activetargetxcflatshell, "")
		activetargetxcflatshell = null

	if activetargetwallgrabbedtransform != null:
		sketchsystem.actsketchchange([ targetwalltransformpos(2) ])
		activetargetwallgrabbedtransform = null
		assert (gripbuttonpressused)
	
	if gripbuttonpressused:
		pass  # the trigger was pulled during the grip operation
	

	elif pointertargettype == "GripMenuItem":
		if pointertarget.get_name() == "NewXC" and (Tglobal.handflickmotiongestureposition == 1) and Tglobal.housahedronmode and potreeexperiments.visible:
			var potreeplanefittrans = potreeexperiments.laserplanfitting(gripmenu.gripmenulaserorient, 50.0, true, potreeexperiments.rootnode.highlightdist)
			if potreeplanefittrans != null:
				var xcdata = { "name":sketchsystem.uniqueXCname("c"), 
							   "drawingtype":DRAWING_TYPE.DT_ROPEHANG,
							   "transformpos":Transform(Basis(), potreeplanefittrans.origin),
							   "prevnodepoints":{ },
							   "nextnodepoints":{ "a0":potreeplanefittrans.basis.x, 
												  "a1":-potreeplanefittrans.basis.x },
							   "prevonepathpairs":[ ],
							   "newonepathpairs": [ "a0", "a1" ]
							 }
				var xcviz = { "xcvizstates": { xcdata["name"]:DRAWING_TYPE.VIZ_XCD_NODES_VISIBLE } }
				sketchsystem.actsketchchange([xcdata, xcviz])
				var xcwallrope = sketchsystem.get_node("XCdrawings").get_node(xcdata["name"])
				setactivetargetnode(xcwallrope.get_node("XCnodes").get_node("a0"))

		elif pointertarget.get_name() == "NewXC":
			var pt0 = gripmenu.gripmenupointertargetpoint
			var eyept0vec = pt0 - headcam.global_transform.origin
			var newxcvertplane = true

			var potreeplanefittrans = null
			if Tglobal.housahedronmode:
				if potreeexperiments.visible:
					var laserlength = gripmenu.gripmenulaserorient.origin.distance_to(gripmenu.gripmenupointertargetpoint)
					var Glaserlength = min(15.0, laserlength if not is_zero_approx(laserlength) else 50.0)
					potreeplanefittrans = potreeexperiments.laserplanfitting(gripmenu.gripmenulaserorient, Glaserlength, false, 0.15)

			if potreeplanefittrans != null:
				pt0 = potreeplanefittrans.origin
				eyept0vec = -potreeplanefittrans.basis.z
				if eyept0vec.x == 0 and eyept0vec.z == 0:
					newxcvertplane = false
			elif gripmenu.gripmenupointertargettype == "XCtubesector":
				var xcdrawing0 = sketchsystem.get_node("XCdrawings").get_node(gripmenu.gripmenupointertargetwall.xcname0)
				var xcdrawing1 = sketchsystem.get_node("XCdrawings").get_node(gripmenu.gripmenupointertargetwall.xcname1)
				var tubevec = xcdrawing1.global_transform.origin - xcdrawing0.global_transform.origin
				eyept0vec = tubevec if eyept0vec.dot(tubevec) > 0 else -tubevec
				if abs(xcdrawing0.global_transform.basis.z.y) > 0.3 and abs(xcdrawing1.global_transform.basis.z.y) > 0.3:
					newxcvertplane = false
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
				var eyeptpitchangle = rad2deg(atan2(eyept0vec.y, Vector2(eyept0vec.x, eyept0vec.z).length()))
				print("eyeptpitchangle ", eyeptpitchangle)
				newxcvertplane = (abs(eyeptpitchangle) <= 75)
			elif gripmenu.gripmenupointertargettype == "XCflatshell":
				pt0 += -eyept0vec/2
			else:
				print(gripmenu.gripmenupointertargettype)
				assert (gripmenu.gripmenupointertargettype == "none" or gripmenu.gripmenupointertargettype == "unknown")
				eyept0vec = gripmenu.gripmenulaservector
				pt0 = headcam.global_transform.origin + eyept0vec.normalized()*2.9
				
			if pt0 != null:
				var transformpos
				if newxcvertplane:
					var drawingwallangle = Vector2(eyept0vec.x, eyept0vec.z).angle() + deg2rad(90)
					transformpos = Transform(Basis().rotated(Vector3(0,-1,0), drawingwallangle), pt0)
				else:
					transformpos = Transform(Vector3(1,0,0), Vector3(0,0,-1), Vector3(0,1,0), pt0) if eyept0vec.y < 0.0 else Transform(Vector3(1,0,0), Vector3(0,0,1), Vector3(0,-1,0), pt0)
				var xcdata = { "name":sketchsystem.uniqueXCname("s"), 
							   "drawingtype":DRAWING_TYPE.DT_XCDRAWING,
							   "transformpos":transformpos }
					
				if Tglobal.housahedronmode:
					xcdata["xcflatshellmaterial"] = "ceiling" if xcdata["transformpos"].basis.z.y < -0.8 else "floor" if xcdata["transformpos"].basis.z.y > 0.8 else "specwall" 
					
				var xcviz = { "xcvizstates": { xcdata["name"]:DRAWING_TYPE.VIZ_XCD_PLANE_AND_NODES_VISIBLE } }
				sketchsystem.actsketchchange([xcdata, xcviz])
				clearactivetargetnode()
				var xcdrawing = sketchsystem.get_node("XCdrawings").get_node(xcdata["name"])
				setactivetargetwall(xcdrawing)
				if gripmenu.gripmenupointertargettype == "XCtubesector":
					var xcdrawing0 = sketchsystem.get_node("XCdrawings").get_node(gripmenu.gripmenupointertargetwall.xcname0)
					var xcdrawing1 = sketchsystem.get_node("XCdrawings").get_node(gripmenu.gripmenupointertargetwall.xcname1)
					xcdrawing.expandxcdrawingfitprojectedfromxcdrawingnodes(xcdrawing0)
					xcdrawing.expandxcdrawingfitprojectedfromxcdrawingnodes(xcdrawing1)
				if newxcvertplane:
					xcdrawing.expandxcdrawingscale(Vector3(pt0.x, headcam.global_transform.origin.y, pt0.z))

		elif pointertarget.get_name() == "toPaper":
			if gripmenu.gripmenupointertargettype == "XCdrawing" and gripmenu.gripmenupointertargetwall.drawingtype == DRAWING_TYPE.DT_FLOORTEXTURE:
				materialsystem.setfloormaptexture(gripmenu.gripmenupointertargetwall.get_name())
				if Tglobal.connectiontoserveractive:
					materialsystem.rpc("setfloormaptexture", gripmenu.gripmenupointertargetwall.get_name())
			
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

		elif pointertarget.get_name() == "SpLine":
			var ropexc = activetargetnodewall
			var ropexcnode = activetargetnode
			if ropexc == null and gripmenu.gripmenupointertargettype == "XCnode":
				ropexc = gripmenu.gripmenupointertargetwall
				ropexcnode = gripmenu.gripmenupointertarget
			if ropexc != null and ropexcnode != null and ropexc.drawingtype == DRAWING_TYPE.DT_ROPEHANG:
				var ropeseqs = Polynets.makeropenodesequences(ropexc.nodepoints, ropexc.onepathpairs, null, null, true)
				var ropeseqstospline = [ ]
				for ropeseq in ropeseqs:
					if ropeseq.find(ropexcnode.get_name()) != -1 and len(ropeseq) > 2:
						ropeseqstospline.push_back(ropeseq)
				var prevnodepoints = {  }
				var nextnodepoints = {  }
				for ropeseq in ropeseqstospline:
					var a = ropexc.nodepoints[ropeseq[0]]
					var b = ropexc.nodepoints[ropeseq[-1]]
					var pre_a = a - (ropexc.nodepoints[ropeseq[1]] - a)*splineamplificationfactor
					var post_b = b + (b - ropexc.nodepoints[ropeseq[-2]])*splineamplificationfactor
					for i in range(1, len(ropeseq) - 1):
						var weight = i/(len(ropeseq) - 1.0)
						var nodename = ropeseq[i]
						prevnodepoints[nodename] = ropexc.nodepoints[nodename]
						nextnodepoints[nodename] = a.cubic_interpolate(b, pre_a, post_b, weight)
				var xcdata = { "name":ropexc.get_name(), 
							   "prevnodepoints":prevnodepoints,
							   "nextnodepoints":nextnodepoints
							 }
				if len(ropeseqstospline) == 1:
					var prevonepathpairs = [ ]
					var e0 = ropeseqstospline[0][0]
					var e1 = ropeseqstospline[0][-1]
					for j in range(0, len(ropexc.onepathpairs), 2):
						if (ropexc.onepathpairs[j] == e0 and ropexc.onepathpairs[j+1] == e1) or (ropexc.onepathpairs[j] == e1 and ropexc.onepathpairs[j+1] == e0):
							prevonepathpairs.push_back(ropexc.onepathpairs[j])
							prevonepathpairs.push_back(ropexc.onepathpairs[j+1])
					if len(prevonepathpairs) == 2:
						xcdata["prevonepathpairs"] = prevonepathpairs
						xcdata["newonepathpairs"] = [ ]

				sketchsystem.actsketchchange([xcdata])
				clearactivetargetnode()

		elif activetargetnode != null and activetargetnodewall.drawingtype == DRAWING_TYPE.DT_ROPEHANG:
			var ropexcnode = activetargetnode if (pointertargetofstartofropehang == null or len(activetargetnodewall.nodepoints) != 1) else null
			var ropexc = activetargetnodewall if ropexcnode != null else pointertargetofstartofropehang
			var dragvec = gripmenu.gripmenupointertargetpoint - activetargetnode.global_transform.origin
			var ropeseqs = Polynets.makeropenodesequences(ropexc.nodepoints, ropexc.onepathpairs, null, null, true)
			var dragvecL = ropexc.transform.basis.xform_inv(dragvec)
							
			var xcdatalist = [ ]
			if pointertarget.get_name() == "DragXC":
				xcdatalist.push_back({ "name":ropexc.get_name(), 
									   "prevtransformpos":ropexc.transform,
									   "transformpos":ropexc.transform.translated(dragvecL)
									})
			elif pointertarget.get_name() == "SelectXC" and pointertargetofstartofropehang != null:
				sketchsystem.actsketchchange([{"xcvizstates":{ pointertargetofstartofropehang.get_name():DRAWING_TYPE.VIZ_XCD_PLANE_AND_NODES_VISIBLE } }])
				
			elif pointertarget.get_name() == "DistortXC" and ropexcnode != null:
				var ropexcnodename = ropexcnode.get_name()
				var ropeseqsselected = Polynets.ropeseqsfindsplitatnode(ropeseqs, ropexcnodename)
				var prevnodepoints = { ropexcnodename:activetargetnodewall.nodepoints[ropexcnodename] }
				var nextnodepoints = { ropexcnodename:ropexc.transform.xform_inv(gripmenu.gripmenupointertargetpoint) }
				for ropeseq in ropeseqsselected:
					for i in range(1, len(ropeseq) - 1):
						var nodename = ropeseq[i]
						prevnodepoints[nodename] = ropexc.nodepoints[nodename]
						nextnodepoints[nodename] = prevnodepoints[nodename] + dragvecL*(1.0 - i*1.0/(len(ropeseq) - 1))
				xcdatalist.push_back({ "name":ropexc.get_name(), 
									   "prevnodepoints":prevnodepoints,
									   "nextnodepoints":nextnodepoints
									})
				
			elif pointertarget.get_name() == "ProjectXC" or pointertarget.get_name() == "DistortXC":
				var nodestoproject = { }
				if ropexcnode != null:
					for j in range(len(ropeseqs)):
						var ropeseq = ropeseqs[j]
						var i = ropeseq.find(ropexcnode.get_name())
						if i > 0 and i < len(ropeseq) - 1:
							for nodename in ropeseq:
								nodestoproject[nodename] = 1
				else:
					var cuboidfacs = Polynets.cuboidfromropenodesequences(ropexc.nodepoints, ropeseqs, false)
					if cuboidfacs != null:
						var targetpointL = ropexc.transform.xform_inv(activetargetnode.global_transform.origin)
						var cuboidfac = Polynets.findclosestcuboidshellface(targetpointL, dragvecL, ropexc.nodepoints, cuboidfacs)
						for ropeseq in cuboidfac:
							for nodename in ropeseq:
								nodestoproject[nodename] = 1
							
				var projectmode = pointertarget.get_name() == "ProjectXC"
				if len(nodestoproject) != 0:
					var prevnodepoints = { }
					var nextnodepoints = { } 
					var raycast = $CubeCornerRayCast
					raycast.clear_exceptions()
					raycast.collision_mask = CollisionLayer.CLV_MainRayNoNodes
					var dragvecunit = dragvec.normalized()
					var dragvecback = dragvecunit*0.1
					if ropexc.has_node("XCflatshell"):
						raycast.add_exception(ropexc.get_node("XCflatshell"))
					for nodename in nodestoproject:
						var orgnodepoint = ropexc.transform.xform(ropexc.nodepoints[nodename])
						var dprojnodepoint = orgnodepoint + dragvec
						if projectmode:
							raycast.transform.origin = orgnodepoint - dragvecback
							raycast.cast_to = dprojnodepoint + dragvecunit*handflickmotiongestureposition_shortpos_length - raycast.transform.origin
							raycast.force_raycast_update()
							if raycast.is_colliding():
								dprojnodepoint = raycast.get_collision_point()
								print(raycast.get_collider().get_name())
						prevnodepoints[nodename] = ropexc.nodepoints[nodename]
						nextnodepoints[nodename] = ropexc.transform.xform_inv(dprojnodepoint)

					for ropeseq in ropeseqs:
						if prevnodepoints.has(ropeseq[0]) or prevnodepoints.has(ropeseq[-1]):
							var dagvecL0 = nextnodepoints[ropeseq[0]] - prevnodepoints[ropeseq[0]] if prevnodepoints.has(ropeseq[0]) else Vector3(0,0,0)
							var dagvecL1 = nextnodepoints[ropeseq[-1]] - prevnodepoints[ropeseq[-1]] if prevnodepoints.has(ropeseq[-1]) else Vector3(0,0,0)
							for i in range(1, len(ropeseq) - 1):
								var nodename = ropeseq[i]
								if not prevnodepoints.has(nodename):
									prevnodepoints[nodename] = ropexc.nodepoints[nodename]
									nextnodepoints[nodename] = prevnodepoints[nodename] + lerp(dagvecL0, dagvecL1, i*1.0/(len(ropeseq) - 1))

					xcdatalist.push_back({ "name":ropexc.get_name(), 
										   "prevnodepoints":prevnodepoints,
										   "nextnodepoints":nextnodepoints
										})
			elif pointertarget.get_name() == "CopyRock" and ropexcnode != null:
				var ropexcnodename = ropexcnode.get_name()
				var ropeseqsselected = [ ]
				for ropeseq in ropeseqs:
					if ropeseq.find(ropexcnodename)	!= -1:
						ropeseqsselected.push_back(ropeseq)
				var newropexcnodename = null
				if len(ropeseqsselected) == 1:
					var nextnodepoints = { }
					var newonepathpairs = [ ]
					var ropeseq = ropeseqsselected[0]
					var prevnewnodename = null
					for i in range(len(ropeseq) - (1 if ropeseq[0] == ropeseq[-1] else 0)):
						var nodename = ropeseq[i]
						var newnodename = ropexc.newuniquexcnodename("k")
						if nodename == ropexcnodename:
							newropexcnodename = newnodename
						nextnodepoints[newnodename] = ropexc.nodepoints[nodename] + dragvecL
						if i != 0:
							newonepathpairs.push_back(prevnewnodename)
							newonepathpairs.push_back(newnodename)
						if i == 0 or i == len(ropeseq) - 1:
							newonepathpairs.push_back(nodename)
							newonepathpairs.push_back(newnodename)
						prevnewnodename = newnodename
					if ropeseq[0] == ropeseq[-1]:
						newonepathpairs.push_back(newonepathpairs[-1])
						newonepathpairs.push_back(newonepathpairs[1])
						if newropexcnodename != null and newonepathpairs[0] != ropexcnodename:
							newonepathpairs.push_back(ropexcnodename)
							newonepathpairs.push_back(newropexcnodename)

					xcdatalist.push_back({ "name":ropexc.get_name(), 
										   "prevnodepoints":{ },
										   "nextnodepoints":nextnodepoints,
										   "prevonepathpairs":[ ],
										   "newonepathpairs":newonepathpairs
										})
				

			if len(xcdatalist) != 0:
				if ropexcnode == null:
					xcdatalist.push_back({ "name":activetargetnodewall.get_name(), 
										   "prevnodepoints":activetargetnodewall.nodepoints.duplicate(), 
										   "nextnodepoints":{}
										})
				sketchsystem.actsketchchange(xcdatalist)
				clearactivetargetnode()


				
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
					sketchsystem.actsketchchange([{ "xcvizstates":{ gripmenu.gripmenupointertargetwall.xcname0:DRAWING_TYPE.VIZ_XCD_HIDE, 
																	gripmenu.gripmenupointertargetwall.xcname1:DRAWING_TYPE.VIZ_XCD_HIDE } } ])
					var xcdrawing0 = sketchsystem.get_node("XCdrawings").get_node(gripmenu.gripmenupointertargetwall.xcname0)
					var xcdrawing1 = sketchsystem.get_node("XCdrawings").get_node(gripmenu.gripmenupointertargetwall.xcname1)
					if xcdrawing0 == activetargetwall:
						setactivetargetwall(null)
					if xcdrawing1 == activetargetwall:
						setactivetargetwall(null)
				elif gripmenu.gripmenupointertargettype == "XCdrawing" and gripmenu.gripmenupointertargetwall.drawingtype == DRAWING_TYPE.DT_XCDRAWING and len(gripmenu.gripmenupointertargetwall.nodepoints) != 0:
					var xcdrawing = gripmenu.gripmenupointertargetwall
					sketchsystem.actsketchchange([{ "xcvizstates":{ gripmenu.gripmenupointertargetwall.get_name():DRAWING_TYPE.VIZ_XCD_HIDE if xcdrawing.xcconnectstoshell() else DRAWING_TYPE.VIZ_XCD_NODES_VISIBLE}} ])
					if xcdrawing == activetargetwall:
						setactivetargetwall(null)


			elif pointertarget.get_name() == "ShowFloor":
				var xcdrawing = gripmenu.gripmenupointertargetwall
				sketchsystem.actsketchchange([{ "xcvizstates":{xcdrawing.get_name():DRAWING_TYPE.VIZ_XCD_FLOOR_NORMAL}} ])

			elif pointertarget.get_name() == "DelXC":
				var xcdrawing = gripmenu.gripmenupointertargetwall
				if (xcdrawing.drawingtype == DRAWING_TYPE.DT_XCDRAWING) or (xcdrawing.drawingtype == DRAWING_TYPE.DT_ROPEHANG) or (xcdrawing.drawingtype == DRAWING_TYPE.DT_CENTRELINE):
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
						var xcv = { "xcvizstates":{ xcname:DRAWING_TYPE.VIZ_XCD_HIDE }, 
									"updatexcshells":[xcname] }
						sketchsystem.actsketchchange([xcdata, xcv])
						setactivetargetwall(null)
					else:
						print("not deleted xc nodes due to connecting tubes")
				
				
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

			elif pointertarget.get_name() == "DragXC" and activetargetnode != null and activetargetnodewall.drawingtype == DRAWING_TYPE.DT_XCDRAWING:
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
				clearactivetargetnode()
				
			elif pointertarget.get_name() == "ProjectXC" and activetargetnodewall != null and \
					activetargetnodewall.drawingtype == DRAWING_TYPE.DT_XCDRAWING and \
					gripmenu.gripmenupointertargetwall != null and \
					gripmenu.gripmenupointertargetwall.drawingtype == DRAWING_TYPE.DT_XCDRAWING:
				var sourcexc = activetargetnodewall
				var destxc = gripmenu.gripmenupointertargetwall
				var sourcesurfacetype = "ceiling" if sourcexc.transform.basis.z.y < -0.8 else "floor" if sourcexc.transform.basis.z.y > 0.8 else "wall" 
				var destsurfacetype = "ceiling" if destxc.transform.basis.z.y < -0.8 else "floor" if destxc.transform.basis.z.y > 0.8 else "wall"
				if len(destxc.nodepoints) == 0 and ((sourcesurfacetype == "wall") == (destsurfacetype == "wall")):
					var nextnodepoints = { }
					for nodename in sourcexc.nodepoints:
						var pt = sourcexc.transform.xform(activetargetnodewall.nodepoints[nodename])
						var pto = pt - destxc.transform.origin
						var ptox = destxc.transform.basis.x.dot(pto)
						var ptoy = destxc.transform.basis.y.dot(pto)
						nextnodepoints[nodename] = Vector3(ptox, ptoy, 0.0)
					var xcdatalist = [{ "name":destxc.get_name(), 
										"prevnodepoints":{ },
										"nextnodepoints":nextnodepoints, 
										"prevonepathpairs":[ ], 
										"newonepathpairs":sourcexc.onepathpairs.duplicate()
									 }]
					var xcv = { "xcvizstates":{ destxc.get_name():DRAWING_TYPE.VIZ_XCD_HIDE }, "updatexcshells":[ destxc.get_name() ] }
					xcv["xcvizstates"][sourcexc.get_name()] = DRAWING_TYPE.VIZ_XCD_HIDE
					if (sourcesurfacetype != "wall") and (destsurfacetype != "wall"):
						if sourcesurfacetype == destsurfacetype:
							if sourcexc.notubeconnections_so_delxcable():
								xcdatalist.push_back({ "name":activetargetnodewall.get_name(), 
													   "prevnodepoints":sourcexc.nodepoints.duplicate(),
													   "nextnodepoints":{ }, 
													   "prevonepathpairs":sourcexc.onepathpairs.duplicate(),
													   "newonepathpairs": [ ]
													 })
						elif Tglobal.housahedronmode:
							var sourcepolys = Polynets.makexcdpolys(sourcexc.nodepoints, sourcexc.onepathpairs)
							if len(sourcepolys) == 2:
								var sourcepoly = sourcepolys[-1]
								for i in range(len(sourcepoly)):
									var nl = sourcepoly[i]
									var nr = sourcepoly[(i+1)%len(sourcepoly)]
									var pttl = sourcexc.transform.xform(sourcexc.nodepoints[nl])
									var pttr = sourcexc.transform.xform(sourcexc.nodepoints[nr])
									var ptbl = destxc.transform.xform(nextnodepoints[nl])
									var ptbr = destxc.transform.xform(nextnodepoints[nr])
									var ptcen = (pttl + pttr + ptbl + ptbr)*0.25
									var drawingwallangle = Vector2(pttr.x-pttl.x, pttr.z-pttl.z).angle()
									var walltrans = Transform(Basis().rotated(Vector3(0,-1,0), drawingwallangle), ptcen)
									var wallnodepoints = { "tl":walltrans.xform_inv(pttl), 
														   "tr":walltrans.xform_inv(pttr), 
														   "bl":walltrans.xform_inv(ptbl), 
														   "br":walltrans.xform_inv(ptbr) 
														 }
									var wallonepathpairs = [ "tl", "tr", "tr", "br", "br", "bl", "bl", "tl"]
									print("must fix flaw with uniqueXCname so it keeps track properly")
									var xcdatawall = { "name":sketchsystem.uniqueXCname("u%duu"%i), 
													   "drawingtype":DRAWING_TYPE.DT_XCDRAWING,
													   "transformpos":walltrans, 
													   "nodepoints":wallnodepoints,
													   "onepathpairs":wallonepathpairs, 
													   "xcflatshellmaterial":"specwall" 
													 }
									xcdatalist.push_back(xcdatawall)
									xcv["xcvizstates"][xcdatawall["name"]] = DRAWING_TYPE.VIZ_XCD_HIDE
									xcv["updatexcshells"].push_back(xcdatawall["name"])
					xcdatalist.push_back(xcv)
					clearactivetargetnode()
					
					sketchsystem.actsketchchange(xcdatalist)

					
				else:
					print("not projecting to xcdrawing that isn't empty")

				
				
			elif pointertarget.get_name() == "HoleXC":
				var xcsectormaterial = gripmenu.gripmenupointertargetwall.xcsectormaterials[gripmenu.gripmenuactivetargettubesectorindex]
				if xcsectormaterial == "hole":
					var xcdata = gripmenu.gripmenupointertargetwall.ConstructHoleXC(gripmenu.gripmenuactivetargettubesectorindex, sketchsystem)
					if xcdata != null:
						sketchsystem.actsketchchange([xcdata, 
								{"xcvizstates":{ gripmenu.gripmenupointertargetwall.xcname0:DRAWING_TYPE.VIZ_XCD_HIDE, 
												 gripmenu.gripmenupointertargetwall.xcname1:DRAWING_TYPE.VIZ_XCD_HIDE,
												 xcdata["name"]:DRAWING_TYPE.VIZ_XCD_NODES_VISIBLE }}])
						clearpointertarget()
						#setactivetargetwall(sketchsystem.get_node("XCdrawings").get_node(xcdata["name"]))
				elif xcsectormaterial == "holegap":
					var xcdata = gripmenu.gripmenupointertargetwall.CopyHoleGapShape(gripmenu.gripmenuactivetargettubesectorindex, sketchsystem)
					if xcdata != null:
						sketchsystem.actsketchchange([xcdata, 
								{ "xcvizstates":{ }, 
								  "updatetubeshells":[ 
									{ "tubename":gripmenu.gripmenupointertargetwall.get_name(), "xcname0":gripmenu.gripmenupointertargetwall.xcname0, "xcname1":gripmenu.gripmenupointertargetwall.xcname1 }
													 ] } ] )
													
			elif pointertarget.get_name() == "DoSlice" and is_instance_valid(wasactivetargettube):
				print("doslice ", wasactivetargettube)
				if is_instance_valid(activetargetwall) and len(activetargetwall.nodepoints) == 0:
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
					sketchsystem.setnewtubename(xctdata0)
					var xctdata1 = { "tubename":"**notset", 
									 "xcname0":xcdrawing.get_name(),
									 "xcname1":wasactivetargettube.xcname1,
									 "prevdrawinglinks":[], "newdrawinglinks":[] }
					sketchsystem.setnewtubename(xctdata1)
					if wasactivetargettube.slicetubetoxcdrawing(xcdrawing, xcdata, xctdatadel, xctdata0, xctdata1) and wasactivetargettube.gettubeshellholes(sketchsystem) == null:
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

				elif activetargetnode != null and activetargetnodewall != null and len(activetargetnodewall.nodepoints) == 1:
					var xcdrawing = activetargetnodewall
					var xctube = wasactivetargettube
					var xcdrawing0 = sketchsystem.get_node("XCdrawings").get_node(xctube.xcname0)
					var xcdrawing1 = sketchsystem.get_node("XCdrawings").get_node(xctube.xcname1)
					var npmean0 = xcdrawing0.transform.xform(xcdrawing0.nodepointmean)
					var npmean1 = xcdrawing1.transform.xform(xcdrawing1.nodepointmean)
					var npmean = xcdrawing.transform.xform(activetargetnode.transform.origin)
					var npmean0dot = xcdrawing.transform.basis.z.dot(npmean0 - npmean)
					var npmean1dot = xcdrawing.transform.basis.z.dot(npmean1 - npmean)
					if (npmean0dot < 0) == (npmean1dot < 0):
						var xcdrawingE = xcdrawing0  if abs(npmean0dot) < abs(npmean1dot)  else xcdrawing1
						var xcdata = { "name":xcdrawing.get_name(), 
									   "prevnodepoints":activetargetnodewall.nodepoints.duplicate(), 
									   "nextnodepoints":xcdrawingE.nodepoints.duplicate(), 
									   "prevonepathpairs":[ ], 
									   "newonepathpairs":xcdrawingE.onepathpairs.duplicate() }
						if npmean0dot < 0:
							xcdata["prevtransformpos"] = xcdrawing.transform
							xcdata["transformpos"] = Transform(xcdrawing.transform.basis.rotated(Vector3(0,1,0), deg2rad(180)), xcdrawing.transform.origin)
						var newdrawinglinks = [ ]
						var jE = 0 if xcdrawingE.get_name() == xctube.xcname0 else 1
						for j in range(0, len(xctube.xcdrawinglink), 2):
							if len(newdrawinglinks) == 0 or xctube.xcdrawinglink[j+jE] != newdrawinglinks[-4]:
								newdrawinglinks.push_back(xctube.xcdrawinglink[j+jE])
								newdrawinglinks.push_back(xctube.xcdrawinglink[j+jE])
								newdrawinglinks.push_back(xctube.xcsectormaterials[j/2])
								newdrawinglinks.push_back(null)
						var xctdata = { "tubename":"**notset", 
										"xcname0":xcdrawingE.get_name(),
										"xcname1":xcdrawing.get_name(),
										"prevdrawinglinks":[], 
										"newdrawinglinks":newdrawinglinks }
						sketchsystem.setnewtubename(xctdata)
						clearactivetargetnode()
						clearpointertarget()
						var xctdataviz = {"xcvizstates":{ xcdrawing.get_name():DRAWING_TYPE.VIZ_XCD_PLANE_AND_NODES_VISIBLE }, 
							"updatetubeshells":[
								{ "tubename":xctdata["tubename"], "xcname0":xctdata["xcname0"], "xcname1":xctdata["xcname1"] },
							]}
						sketchsystem.actsketchchange([xcdata, xctdata, xctdataviz])
						setactivetargetwall(xcdrawing)
						wasactivetargettube = null
						activelaserroot.get_node("LaserSpot").visible = false


			elif pointertarget.get_name() == "FixHoleXC" and is_instance_valid(wasactivetargettube):
				print("FixHoleXC ", wasactivetargettube)
				var xcdatalist = wasactivetargettube.FixtubeholeXCs(sketchsystem)
				if xcdatalist != null:
					clearactivetargetnode()
					clearpointertarget()
					sketchsystem.actsketchchange(xcdatalist)

			elif pointertarget.get_name() == "CopyRock":
				var xcdrawing = gripmenu.gripmenupointertargetwall
				if xcdrawing.drawingtype == DRAWING_TYPE.DT_ROPEHANG and xcdrawing.ropehangdetectedtype == DRAWING_TYPE.RH_BOULDER:
					var xcdata = xcdrawing.exportxcrpcdata(true)
					xcdata["nodepoints"] = xcdata["nodepoints"].duplicate()
					xcdata["onepathpairs"] = xcdata["onepathpairs"].duplicate()
					xcdata["name"] = sketchsystem.uniqueXCname("rc")
					xcdata["xcresource"] = xcdrawing.get_name()
					xcdata["transformpos"].origin += Vector3(0,1.1,0)
					sketchsystem.actsketchchange([xcdata])
		
	elif pointertargettype == "GUIPanel3D":
		guipanel3d.setguipanelhide()

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
		
	elif pointertargettype == "XCnode" and gripmenu.gripmenupointertargettype == "XCnode" and (pointertargetwall.drawingtype == DRAWING_TYPE.DT_XCDRAWING or pointertargetwall.drawingtype == DRAWING_TYPE.DT_ROPEHANG):
		var updatexcshells = [ pointertargetwall.get_name() ]
		var updatetubeshells = pointertargetwall.updatetubeshellsconn()
		sketchsystem.actsketchchange([{ "xcvizstates":{}, "updatetubeshells":updatetubeshells, "updatexcshells":updatexcshells }])
		var ds = DRAWING_TYPE.VIZ_XCD_HIDE  if (pointertargetwall.drawingtype == DRAWING_TYPE.DT_ROPEHANG or pointertargetwall.xcconnectstoshell()) else DRAWING_TYPE.VIZ_XCD_NODES_VISIBLE
		sketchsystem.actsketchchange([{ "xcvizstates":{ pointertargetwall.get_name():ds }}])
		if pointertargetwall == activetargetwall:
			setactivetargetwall(null)
		if ds == DRAWING_TYPE.VIZ_XCD_HIDE:
			clearactivetargetnode()

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
			var drawingholeforconnupdate = tubeshellholeindexes[0]
			var xcvizstates = { }
			for j in range(1, len(tubeshellholeindexes)):
				var i = tubeshellholeindexes[j]
				var xcdatashell = xctube.ConstructHoleXC(i, sketchsystem)
				if xcdatashell != null:
					if xcdatashellholes == null:
						xcdatashellholes = [ ]
					xcdatashellholes.push_back(xcdatashell)
					var xcholeforvisible = sketchsystem.get_node("XCdrawings").get_node_or_null(xcdatashell["name"])
					if xcholeforvisible != null:
						xcvizstates[xcdatashell["name"]] = xcholeforvisible.drawingvisiblecode
			var updatetubeshells = drawingholeforconnupdate.updatetubeshellsconn()
			if xcdatashellholes != null and len(updatetubeshells) != 0:
				xcdatashellholes.push_back({"xcvizstates":xcvizstates, "updatetubeshells":updatetubeshells})
	return xcdatashellholes

var targetwallvertplanesticky = true
var prevactivetargetwallgrabbedorgtransform = null

func targetwalltransformpos(optionalrevertcode):
	if activetargetwallgrabbedmotion == DRAWING_TYPE.GRABMOTION_ROTATION_ADDITIVE or activetargetwallgrabbedmotion == DRAWING_TYPE.GRABMOTION_DIRECTIONAL_DRAGGING:
		var targetisplanview = (activetargetwallgrabbed.get_name() == "PlanView")
		var targetisscalablepicture = (not targetisplanview and (activetargetwallgrabbed.drawingtype == DRAWING_TYPE.DT_FLOORTEXTURE) and (activetargetwallgrabbed.drawingvisiblecode & DRAWING_TYPE.VIZ_XCD_FLOOR_NOSHADE_B) != 0)
		var newtrans = null
		var laserspottransform = activelaserroot.get_node("LaserSpot").global_transform
		var reljoyposcumulative = joyposcumulative - activetargetwalljoyposcumulative
		if activetargetwallgrabbedlength != 0:
			if targetisscalablepicture and activetargetwallgrabbedmotion == DRAWING_TYPE.GRABMOTION_DIRECTIONAL_DRAGGING:
				var relscale = clamp(3*reljoyposcumulative.x + 1, 0.2, 5)
				laserspottransform = laserspottransform.scaled(Vector3(relscale, relscale, relscale))
			var reticulelength = min(-0.1, activetargetwallgrabbedlength - 5*reljoyposcumulative.y)
			laserspottransform.origin = activelaserroot.global_transform.origin + reticulelength*activelaserroot.global_transform.basis.z
		if activetargetwallgrabbedmotion == DRAWING_TYPE.GRABMOTION_DIRECTIONAL_DRAGGING:
			newtrans = laserspottransform * activetargetwallgrabbedtransform
		elif activetargetwallgrabbedpoint != null:
			newtrans = laserspottransform * activetargetwallgrabbedtransform
			newtrans.origin += activetargetwallgrabbedpoint - newtrans * activetargetwallgrabbedlocalpoint
		else:
			newtrans = laserspottransform * activetargetwallgrabbedtransform

			
		if targetisplanview:
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
	
	#assert (activetargetwallgrabbed.drawingtype == DRAWING_TYPE.DT_XCDRAWING)	
	var primarilylocked = (activetargetwallgrabbedmotion == DRAWING_TYPE.GRABMOTION_PRIMARILY_LOCKED_VERTICAL_ROTATION_ONLY)
			
	var txcdata = { "name":activetargetwallgrabbed.get_name(), 
					"rpcoptional":(0 if optionalrevertcode else 1),
					"timestamp":OS.get_ticks_msec()*0.001,
					"prevtransformpos":activetargetwallgrabbed.transform, }

	if prevactivetargetwallgrabbedorgtransform == null or prevactivetargetwallgrabbedorgtransform != activetargetwallgrabbedorgtransform:
		targetwallvertplanesticky = abs(activetargetwallgrabbedorgtransform.basis.z.y) < 0.3
		prevactivetargetwallgrabbedorgtransform = activetargetwallgrabbedorgtransform

	var laserrelvec = activelaserroot.global_transform.basis.xform_inv(activetargetwallgrabbedlaserroottrans.basis.z)
	var angh = rad2deg(asin(activelaserroot.global_transform.basis.z.y))
	if primarilylocked:
		pass
	elif targetwallvertplanesticky and abs(angh) > 60:
		targetwallvertplanesticky = false
	elif (not targetwallvertplanesticky) and abs(angh) < 20:
		targetwallvertplanesticky = true

# Can't tell what conditions are changing it and 
# how to maintain the same porientation when we drag bits

	var grabbedtargetwallvertplane = (abs(activetargetwallgrabbedorgtransform.basis.z.y) < 0.3)	
	if optionalrevertcode == 2:
		txcdata["transformpos"] = activetargetwallgrabbedorgtransform
	elif targetwallvertplanesticky:
		var angy = -Vector2(laserrelvec.z, laserrelvec.x).angle()
		if grabbedtargetwallvertplane:
			txcdata["transformpos"] = activetargetwallgrabbedorgtransform.rotated(Vector3(0,1,0), angy)
			var angpush = 0 if primarilylocked else -(activetargetwallgrabbedlaserroottrans.origin.y - activelaserroot.global_transform.origin.y)
			var activetargetwallgrabbedpointmoved = activetargetwallgrabbedpoint + 20*angpush*activetargetwallgrabbeddispvector.normalized()
			txcdata["transformpos"].origin += activetargetwallgrabbedpointmoved - txcdata["transformpos"]*activetargetwallgrabbedlocalpoint
		else:
			var angt = Vector2(activetargetwallgrabbeddispvector.x, activetargetwallgrabbeddispvector.z).angle() + deg2rad(90) - angy
			txcdata["transformpos"] = Transform(Basis().rotated(Vector3(0,-1,0), angt), activetargetwallgrabbedorgtransform.origin)
			var angpush = 0 if primarilylocked else -(activetargetwallgrabbedlaserroottrans.origin.y - activelaserroot.global_transform.origin.y)
			var activetargetwallgrabbedpointmoved = activetargetwallgrabbedpoint + 20*angpush*Vector3(activetargetwallgrabbeddispvector.x, 0, activetargetwallgrabbeddispvector.z).normalized()
			txcdata["transformpos"].origin += activetargetwallgrabbedpointmoved - txcdata["transformpos"]*activetargetwallgrabbedlocalpoint
	elif primarilylocked and not grabbedtargetwallvertplane:
		if activetargetwallgrabbed.transform.basis.z.y > 0:
			txcdata["transformpos"] = Transform(Vector3(1,0,0), Vector3(0,0,-1), Vector3(0,1,0), Vector3(0,0,0))
		else:
			txcdata["transformpos"] = Transform(Vector3(1,0,0), Vector3(0,0,1), Vector3(0,-1,0), Vector3(0,0,0))
		var angpush = -(activetargetwallgrabbedlaserroottrans.origin.y - activelaserroot.global_transform.origin.y)
		txcdata["transformpos"].origin = activetargetwallgrabbedorgtransform.origin + Vector3(0, 2*angpush, 0)

	else:
		if activetargetwallgrabbed.transform.basis.z.y > 0:
			txcdata["transformpos"] = Transform(Vector3(1,0,0), Vector3(0,0,-1), Vector3(0,1,0), Vector3(0,0,0))
		else:
			txcdata["transformpos"] = Transform(Vector3(1,0,0), Vector3(0,0,1), Vector3(0,-1,0), Vector3(0,0,0))
		var angpush = -(activetargetwallgrabbedlaserroottrans.origin.y - activelaserroot.global_transform.origin.y)
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
		if LaserSelectLine.visible:
			sketchsystem.actsketchchange([{
						"name":activetargetnodewall.get_name(), 
						"prevnodepoints":{ activetargetnode.get_name():activetargetnode.translation }, 
						"nextnodepoints":{ activetargetnode.get_name():Vector3(activetargetnode.translation.x, activetargetnode.translation.y, activetargetnodetriggerpulledz) } 
					}])
			clearactivetargetnode()
		LaserSelectLine.visible = false
		activetargetnodetriggerpulling = false
		LaserSelectLine.get_node("Scale").scale = Vector3(1, 1, 1)


var joyposyscrollcountdown = 0 
func _physics_process(delta):
	joyposcumulative += handright.joypos*delta
	#joyposcumulative.x += ((-1 if Input.is_key_pressed(KEY_1) else 0) + (1 if Input.is_key_pressed(KEY_2) else 0))*delta
	if playerMe.handflickmotiongesture != 0:
		if playerMe.handflickmotiongesture == handflickmotiongestureposition_SHORTPOS:
			set_handflickmotiongestureposition(min(Tglobal.handflickmotiongestureposition+1, handflickmotiongestureposition_GONE))
		else:
			set_handflickmotiongestureposition(handflickmotiongestureposition_NORMAL)
		playerMe.get_node("HandRight/PalmLight").visible = (Tglobal.handflickmotiongestureposition == handflickmotiongestureposition_GONE)
		playerMe.handflickmotiongesture = 0

	var joyscrolldir = 0
	if abs(handright.joypos.y) < 0.4:
		joyposyscrollcountdown = 0
	if abs(handright.joypos.y) > (0.7 if handright.vrpadbuttonheld else 0.9):
		joyposyscrollcountdown -= delta
		if joyposyscrollcountdown <= 0:
			joyscrolldir = -1 if handright.joypos.y < 0 else 1
			joyposyscrollcountdown = 0.3333

	if handright.pointervalid:  
		var firstlasertarget = LaserOrient.get_node("RayCast").get_collider()
		if firstlasertarget != null and firstlasertarget.is_queued_for_deletion():
			firstlasertarget = null

		if Tglobal.phoneoverlay != null and planviewsystem.planviewactive:
			planviewsystem.get_node("RealPlanCamera/LaserScope").global_transform.origin = LaserOrient.global_transform.origin
			planviewsystem.get_node("RealPlanCamera/LaserScope").visible = true
			activelaserroot = planviewsystem.get_node("RealPlanCamera/LaserScope/LaserOrient")
			activelaserroot.get_node("LaserSpot").global_transform.basis = LaserOrient.global_transform.basis
			activelaserroot.get_node("RayCast").force_raycast_update()
			setpointertarget(activelaserroot, activelaserroot.get_node("RayCast"), -1.0)
			
		elif firstlasertarget == guipanel3d or firstlasertarget == keyboardpanel:
			LaserOrient.visible = true
			activelaserroot = LaserOrient
			setpointertarget(activelaserroot, activelaserroot.get_node("RayCast"), -1.0)
			pointerplanviewtarget = null
			var textedit = guipanel3d.get_node("Viewport/GUI/Panel/EditColorRect/TextEdit")
			if joyscrolldir != 0:
				if textedit.has_focus() or Rect2(textedit.rect_global_position, textedit.rect_size).has_point(guipanel3d.viewport_point):
					textedit.scroll_vertical += -joyscrolldir
					joyscrolldir = 0
			
		elif Tglobal.handflickmotiongestureposition == handflickmotiongestureposition_GONE or Tglobal.controlslocked:
			LaserOrient.visible = false
			pointerplanviewtarget = null
		elif Tglobal.handflickmotiongestureposition == handflickmotiongestureposition_SHORTPOS and not (firstlasertarget != null and firstlasertarget.get_parent().get_parent().get_name() == "GripMenu"):
			LaserOrient.visible = true
			activelaserroot = LaserOrient
			pointerplanviewtarget = null
			if joyscrolldir == -1 and handflickmotiongestureposition_shortpos_length >= 0.3:
				handflickmotiongestureposition_shortpos_length -= (0.25 if handflickmotiongestureposition_shortpos_length < 1.1 else (1.0 if handflickmotiongestureposition_shortpos_length < 8.1 else 2.0))
			if joyscrolldir == 1 and handflickmotiongestureposition_shortpos_length <= 28.1:
				handflickmotiongestureposition_shortpos_length += (0.25 if handflickmotiongestureposition_shortpos_length < 0.9 else (1.0 if handflickmotiongestureposition_shortpos_length < 7.9 else 2.0))
			setpointertarget(activelaserroot, activelaserroot.get_node("RayCast"), handflickmotiongestureposition_shortpos_length)
			#if pointertarget == null and activetargetwall == null:
			#if not (activetargetwall != null and activetargetwall.drawingtype == DRAWING_TYPE.DT_XCDRAWING):
			if not gripmenu.GripLaserSpot.visible:
				potreeexperiments.sethighlightplaneZone(activelaserroot.global_transform, handflickmotiongestureposition_shortpos_length*0.4, true)

		elif firstlasertarget != null and firstlasertarget.get_name() == "PlanView" and planviewsystem.checkplanviewinfront(LaserOrient) and planviewsystem.planviewactive:
			pointerplanviewtarget = planviewsystem
			LaserOrient.visible = true
			var planviewcontactpoint = LaserOrient.get_node("RayCast").get_collision_point()
			LaserOrient.get_node("LaserSpot").global_transform.origin = planviewcontactpoint
			LaserOrient.get_node("Length").scale.z = -LaserOrient.get_node("LaserSpot").translation.z
			LaserOrient.get_node("LaserSpot").visible = false
			FloorLaserSpot.get_node("FloorSpot").visible = false
			if planviewsystem.planviewactive and Tglobal.phoneoverlay == null:
				var inguipanelsection = pointerplanviewtarget.processplanviewpointing(planviewcontactpoint, (handrightcontroller.is_button_pressed(BUTTONS.HT_PINCH_INDEX_FINGER) if Tglobal.questhandtrackingactive else handrightcontroller.is_button_pressed(BUTTONS.VR_TRIGGER)) or Input.is_mouse_button_pressed(BUTTON_LEFT))
				activelaserroot = planviewsystem.get_node("RealPlanCamera/LaserScope/LaserOrient")
				activelaserroot.get_node("LaserSpot").global_transform.basis = LaserOrient.global_transform.basis
				if inguipanelsection:
					setpointertarget(activelaserroot, null, -1.0)
					if planviewsystem.fileviewtree.visible and joyscrolldir != 0:
						planviewsystem.scrolltree(joyscrolldir == -1)
						joyscrolldir = 0
				else:
					activelaserroot.get_node("RayCast").force_raycast_update()
					setpointertarget(activelaserroot, activelaserroot.get_node("RayCast"), -1.0)

		else:
			LaserOrient.visible = true
			activelaserroot = LaserOrient
			pointerplanviewtarget = null
			setpointertarget(activelaserroot, activelaserroot.get_node("RayCast"), -1.0)

	if joyscrolldir != 0 and pointertargettype == "IntermediatePointView":
		var IntermediatePointView = get_node("/root/Spatial/BodyObjects/IntermediatePointView")
		var olddiscrad = IntermediatePointView.get_node("IntermediatePointPlane/CollisionShape").shape.radius
		var newdiscrad = clamp(olddiscrad + joyscrolldir*1.0, 1.0, 5.0)
		IntermediatePointView.get_node("IntermediatePointPlane/CollisionShape").shape.radius = newdiscrad
		IntermediatePointView.get_node("IntermediatePointPlane/CollisionShape/MeshInstance").mesh.top_radius = newdiscrad
		IntermediatePointView.get_node("IntermediatePointPlane/CollisionShape/MeshInstance").mesh.bottom_radius = newdiscrad
	if pointerplanviewtarget == null or not planviewsystem.planviewactive:
		planviewsystem.get_node("RealPlanCamera/LaserScope").visible = false
		if Tglobal.phoneoverlay == null:
			planviewsystem.planviewguipanelreleasemouse()
	
	if activetargetwallgrabbedtransform != null:
		sketchsystem.actsketchchange([ targetwalltransformpos(0) ])

	if Tglobal.phoneoverlay != null and (activetargetnodewall != null) and (activetargetnodewall.drawingtype == DRAWING_TYPE.DT_CENTRELINE) and \
	   (activetargetnode != null) and (laserselectlinelogicalvisibilitystate == 0):
		if OS.get_ticks_msec() < Tglobal.phoneoverlay.quatsettime + 2000:
			LaserSelectLine.transform = Transform(Basis(Tglobal.phoneoverlay.distoxquat), activetargetnodewall.transform.xform(activetargetnode.transform.origin))
			var lselectlinefatness = planviewsystem.nodesca*8.0
			LaserSelectLine.get_node("Scale").scale = Vector3(lselectlinefatness, lselectlinefatness, -max(0.2, Tglobal.phoneoverlay.distoxlength))
			LaserSelectLine.get_node("Scale/Mesh").get_surface_material(0).albedo_color = LaseSelectLinedistoxcolour
			LaserSelectLine.visible = true
		else:
			LaserSelectLine.visible = false
		
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
				buttonpressed_vrby()	
		if event.pressed and event.scancode == KEY_H:
			set_handflickmotiongestureposition(handflickmotiongestureposition_SHORTPOS if Tglobal.handflickmotiongestureposition == handflickmotiongestureposition_NORMAL else handflickmotiongestureposition_NORMAL)

		if event.scancode == KEY_COMMA:
			if event.pressed:
				buttonpressed_vrpad(false, handright.joypos)

	elif Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
		pass

	elif event is InputEventMouseMotion:
		if not Tglobal.VRoperating and Tglobal.phoneoverlay == null:
			handright.process_keyboardcontroltracking(headcam, event.relative*0.005, playerMe.playerscale)
			
	elif event is InputEventMouseButton:
		if event.button_index == BUTTON_RIGHT:
			rightmousebuttonheld = event.pressed
		
		if event.button_index == BUTTON_LEFT:
			if event.pressed:
				buttonpressed_vrtrigger(rightmousebuttonheld)
			else:
				buttonreleased_vrtrigger()
			if not Tglobal.VRoperating and Tglobal.phoneoverlay == null:
				handright.triggerbuttonheld = event.pressed
				handright.process_handgesturefromcontrol()
		if event.button_index == BUTTON_RIGHT:
			if event.pressed:
				buttonpressed_vrgrip()
			else:
				buttonreleased_vrgrip()
			if not Tglobal.VRoperating and Tglobal.phoneoverlay == null:
				handright.gripbuttonheld = event.pressed
				handright.process_handgesturefromcontrol()
				
		if event.button_index == BUTTON_WHEEL_UP or event.button_index == BUTTON_WHEEL_DOWN:
			if event.is_pressed():
				handright.joypos.y = 1.0 if event.button_index == BUTTON_WHEEL_UP else -1.0
				#print("handright.joypos.y ", handright.joypos.y)
			else:
				yield(get_tree(), "physics_frame") 
				yield(get_tree(), "physics_frame") 
				handright.joypos.y = 0.0
				#print("handright.joypos.y ", handright.joypos.y)
