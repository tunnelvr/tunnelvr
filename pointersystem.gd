extends Node

onready var sketchsystem = get_node("/root/Spatial/SketchSystem")
onready var planviewsystem = get_node("/root/Spatial/PlanViewSystem")
onready var materialsystem = get_node("/root/Spatial/MaterialSystem")
onready var gripmenu = get_node("/root/Spatial/GuiSystem/GripMenu")

onready var playerMe = get_parent()
onready var headcam = playerMe.get_node('HeadCam')
onready var handleft = playerMe.get_node("HandLeft")
onready var handright = playerMe.get_node("HandRight")
onready var guipanel3d = get_node("/root/Spatial/GuiSystem/GUIPanel3D")

onready var LaserOrient = handright.get_node("LaserOrient") 
onready var LaserShadow = handright.get_node("LaserShadow") 
onready var LaserSelectLine = handright.get_node("LaserSelectLine") 

var viewport_point = null

const XCdrawig = preload("res://nodescenes/XCdrawing.tscn")
const XCnode = preload("res://nodescenes/XCnode.tscn")
				
var pointinghighlightmaterial = preload("res://guimaterials/XCnode_highlight.material")
var selectedhighlightmaterial = preload("res://guimaterials/XCnode_selected.material")
var selectedpointerhighlightmaterial = preload("res://guimaterials/XCnode_selectedhighlight.material")

var laserspothighlightmaterial = preload("res://guimaterials/laserspot_selected.material"); 


onready var ARVRworld_scale = ARVRServer.world_scale
var mousecontrollervec = Vector3(0.2, -0.1, -0.5)

onready var activelaserroot = handright.get_node("LaserOrient")
var pointerplanviewtarget = null
var pointertarget = null
var pointertargettype = "none"
var pointertargetwall = null
var pointertargetpoint = Vector3(0, 0, 0)
var gripbuttonpressused = false


#var selectedtarget = null
#var selectedtargettype = "none"  # only ever XCnode
#var selectedtargetwall = null

var activetargetnode = null
var activetargetnodewall = null


var activetargetwall = null
var activetargetwallgrabbed = null
var activetargetwallgrabbedtransform = null
var activetargetwallgrabbedpoint = null
var activetargetwallgrabbedpointoffset = null
var activetargetwallgrabbedlocalpoint = null

var activetargettube = null

var xcdrawingactivematerial = preload("res://guimaterials/XCdrawing_active.material")
var xcdrawingmaterial = preload("res://guimaterials/XCdrawing.material")
var xcdrawinghighlightmaterial = preload("res://guimaterials/XCdrawing_highlight.material")

func clearpointertargetmaterial():
	if pointertargettype == "XCnode":
		pointertarget.get_node("CollisionShape/MeshInstance").set_surface_material(0, selectedhighlightmaterial if pointertarget == activetargetnode else (preload("res://guimaterials/XCnode_nodepthtest.material") if pointertargetwall == activetargetwall else preload("res://guimaterials/XCnode.material")))
	if (pointertargettype == "XCdrawing" or pointertargettype == "XCnode") and pointertargetwall.drawingtype == DRAWING_TYPE.DT_XCDRAWING:
		if pointertargetwall == activetargetwall:
			xcdrawingactivematerial.uv1_scale = pointertargetwall.get_node("XCdrawingplane").get_scale()
			xcdrawingactivematerial.uv1_offset = -xcdrawingactivematerial.uv1_scale/2
		pointertargetwall.get_node("XCdrawingplane/CollisionShape/MeshInstance").set_surface_material(0, xcdrawingactivematerial if pointertargetwall == activetargetwall else xcdrawingmaterial)
	if pointertargettype == "GripMenuItem":
		pointertarget.get_node("MeshInstance").get_surface_material(0).albedo_color = Color("#E8D619")

	handright.get_node("csghandright").setpartcolor(2, "#FFFFFF")
			
func setpointertargetmaterial():
	if pointertargettype == "XCnode":
		pointertarget.get_node("CollisionShape/MeshInstance").set_surface_material(0, selectedpointerhighlightmaterial if pointertarget == activetargetnode else pointinghighlightmaterial)
		handright.get_node("csghandright").setpartcolor(2, "#FFFF60")
	if (pointertargettype == "XCdrawing" or pointertargettype == "XCnode") and pointertargetwall.drawingtype == DRAWING_TYPE.DT_XCDRAWING:
		xcdrawinghighlightmaterial.uv1_scale = pointertargetwall.get_node("XCdrawingplane").get_scale()
		xcdrawinghighlightmaterial.uv1_offset = -xcdrawinghighlightmaterial.uv1_scale/2
		pointertargetwall.get_node("XCdrawingplane/CollisionShape/MeshInstance").set_surface_material(0, xcdrawinghighlightmaterial)
		handright.get_node("csghandright").setpartcolor(2, "#FFFF60")
	if pointertargettype == "GripMenuItem":
		pointertarget.get_node("MeshInstance").get_surface_material(0).albedo_color = Color("#FFCCCC")


func clearactivetargetnode():
	if activetargetnode != null:
		activetargetnode.get_node("CollisionShape/MeshInstance").set_surface_material(0, preload("res://guimaterials/XCnode_nodepthtest.material") if activetargetnodewall == activetargetwall else preload("res://guimaterials/XCnode.material"))
	activetargetnode = null
	activetargetnodewall = null
	activelaserroot.get_node("LaserSpot").material_override = null
	
func setactivetargetnode(newactivetargetnode):
	clearactivetargetnode()
	activetargetnode = newactivetargetnode
	assert (targettype(activetargetnode) == "XCnode")
	activetargetnodewall = targetwall(activetargetnode, "XCnode")
	if activetargetnode != pointertarget:
		activetargetnode.get_node("CollisionShape/MeshInstance").set_surface_material(0, selectedhighlightmaterial)
	activelaserroot.get_node("LaserSpot").material_override = preload("res://guimaterials/laserspot_selected.material")
	setpointertargetmaterial()

func setactivetargetwall(newactivetargetwall):
	if activetargetwall != null and activetargetwall.drawingtype == DRAWING_TYPE.DT_XCDRAWING:
		activetargetwall.get_node("XCdrawingplane/CollisionShape/MeshInstance").set_surface_material(0, preload("res://guimaterials/XCdrawing.material"))
		activetargetwall.get_node("PathLines").set_surface_material(0, preload("res://guimaterials/XCdrawingPathlines.material"))
		for xcnode in activetargetwall.get_node("XCnodes").get_children():
			xcnode.get_node("CollisionShape/MeshInstance").set_surface_material(0, preload("res://guimaterials/XCnode_selected.material") if xcnode == activetargetnode else preload("res://guimaterials/XCnode.material"))
		for xctube in activetargetwall.xctubesconn:
			if not xctube.positioningtube:
				xctube.updatetubeshell(sketchsystem.get_node("XCdrawings"), sketchsystem.tubeshellsvisible)
		activetargetwall.updatexctubeshell(sketchsystem.get_node("XCdrawings"), sketchsystem.tubeshellsvisible)
	if activetargetwall != null and activetargetwall.drawingtype == DRAWING_TYPE.DT_PAPERTEXTURE:
		activetargetwall.get_node("XCdrawingplane/CollisionShape/MeshInstance").get_surface_material(0).albedo_color = Color("#FEF4D5")
	
	activetargetwall = newactivetargetwall
	
	if activetargetwall != null and activetargetwall.drawingtype == DRAWING_TYPE.DT_XCDRAWING:
		activetargetwall.get_node("XCdrawingplane/CollisionShape/MeshInstance").set_surface_material(0, preload("res://guimaterials/XCdrawing_active.material"))
		activetargetwall.get_node("PathLines").set_surface_material(0, preload("res://guimaterials/XCdrawingPathlines_nodepthtest.material"))
		for xcnode in activetargetwall.get_node("XCnodes").get_children():
			if xcnode != activetargetnode:
				xcnode.get_node("CollisionShape/MeshInstance").set_surface_material(0, preload("res://guimaterials/XCnode_nodepthtest.material"))
		LaserOrient.get_node("RayCast").collision_mask = CollisionLayer.CL_Pointer | CollisionLayer.CL_PointerFloor 
	else:
		LaserOrient.get_node("RayCast").collision_mask = CollisionLayer.CL_Pointer | CollisionLayer.CL_PointerFloor | CollisionLayer.CL_CaveWall
	if activetargetwall != null and activetargetwall.drawingtype == DRAWING_TYPE.DT_PAPERTEXTURE:
		activetargetwall.get_node("XCdrawingplane/CollisionShape/MeshInstance").get_surface_material(0).albedo_color = Color("#DDFFCC")

func setactivetargettubesector(advancesector):
	if advancesector != 0:
		activetargettube.get_node("XCtubeshell/MeshInstance").set_surface_material(activetargettube.activesector, materialsystem.tubematerialfromnumber(activetargettube.xcsectormaterials[activetargettube.activesector], false))
	if advancesector != -2:
		var nsectors = activetargettube.get_node("XCtubeshell/MeshInstance").get_surface_material_count()
		activetargettube.activesector = (activetargettube.activesector + advancesector + nsectors)%nsectors
		activetargettube.get_node("XCtubeshell/MeshInstance").set_surface_material(activetargettube.activesector, materialsystem.tubematerialfromnumber(activetargettube.xcsectormaterials[activetargettube.activesector], true))

func setactivetargettube(newactivetargettube):
	setactivetargetwall(null)
	if activetargettube != null:
		setactivetargettubesector(-2)
	activetargettube = newactivetargettube
	if activetargettube != null:
		setactivetargettubesector(0)

func _ready():
	handright.connect("button_pressed", self, "_on_button_pressed")
	handright.connect("button_release", self, "_on_button_release")
	print("in the pointer onready")

func targettype(target):
	if not is_instance_valid(target):
		return "none"
	var targetname = target.get_name()
	if targetname == "GUIPanel3D":
		return "GUIPanel3D"
	if targetname == "PlanView":
		return "PlanView"
	if targetname == "XCtubeshell":
		return "XCtube"
	if targetname == "XCflatshell":
		return "XCflatshell"
	var targetparent = target.get_parent()
	if targetname == "XCdrawingplane":
		assert (targetparent.drawingtype != DRAWING_TYPE.DT_CENTRELINE)
		if targetparent.drawingtype == DRAWING_TYPE.DT_PAPERTEXTURE:
			return "Papersheet"
		return "XCdrawing"
	if targetparent.get_name() == "XCnodes":
		return "XCnode"
	if targetparent.get_name() == "GripMenu":
		return "GripMenuItem"
	return "unknown"
		
func targetwall(target, targettype):
	if targettype == "XCdrawing" or targettype == "Papersheet":
		return target.get_parent()
	if targettype == "XCnode":
		return target.get_parent().get_parent()
	if targettype == "XCtube":
		return target.get_parent()
	if targettype == "PlanView":
		return target.get_parent()
	return null
	
func setopnpos(opn, p):
	opn.global_transform.origin = p
		
func onpointing(laserroot):
	var newpointertarget = laserroot.get_node("RayCast").get_collider()
	if newpointertarget != null:
		if newpointertarget.is_queued_for_deletion():
			newpointertarget = null
		elif newpointertarget.get_parent().is_queued_for_deletion():
			newpointertarget = null
		elif newpointertarget.get_parent().get_parent().is_queued_for_deletion():
			newpointertarget = null
	var newpointertargetpoint = laserroot.get_node("RayCast").get_collision_point() if newpointertarget != null else null
	if newpointertarget != pointertarget:
		if pointertarget == guipanel3d:
			guipanel3d.guipanelreleasemouse()
		
		clearpointertargetmaterial()
		pointertarget = newpointertarget
		pointertargettype = targettype(pointertarget)
		pointertargetwall = targetwall(pointertarget, pointertargettype)
		setpointertargetmaterial()
		
		print("ppp  ", activetargetnode, " ", pointertargettype)
		if pointertargettype == "XCnode":
			laserroot.get_node("LaserSpot").visible = false
			LaserShadow.visible = true
		elif pointertargettype == "GUIPanel3D" or pointertargettype == "Papersheet":
			laserroot.get_node("LaserSpot").visible = false
			LaserShadow.visible = false
		elif pointertargettype == "XCdrawing":
			laserroot.get_node("LaserSpot").visible = true
			LaserShadow.visible = (pointertargetwall.drawingtype == DRAWING_TYPE.DT_XCDRAWING)
		elif pointertargettype == "XCtube":
			laserroot.get_node("LaserSpot").visible = true
			LaserShadow.visible = false
		else:
			laserroot.get_node("LaserSpot").visible = false
			LaserShadow.visible = false
			
		# work out the logic for the LaserSelectLine here
		if handright.is_button_pressed(BUTTONS.VR_GRIP):
			pass
		elif pointertargettype == "XCdrawing":
			LaserSelectLine.visible = (activetargetnode != null)
		elif pointertargettype == "XCnode":
			LaserSelectLine.visible = (activetargetnode != null)
		else:
			LaserSelectLine.visible = false
			
	pointertargetpoint = newpointertargetpoint
	if is_instance_valid(pointertarget) and pointertarget == guipanel3d:
		guipanel3d.guipanelsendmousemotion(pointertargetpoint, handright.global_transform, handright.is_button_pressed(BUTTONS.VR_TRIGGER) or Input.is_mouse_button_pressed(BUTTON_LEFT))

	if pointertargetpoint != null:
		laserroot.get_node("LaserSpot").global_transform.origin = pointertargetpoint
		laserroot.get_node("Length").scale.z = -laserroot.get_node("LaserSpot").translation.z
	else:
		laserroot.get_node("Length").scale.z = -laserroot.get_node("RayCast").cast_to.z
		
	if LaserSelectLine.visible:
		if pointertarget != null and activetargetnode != null:
			LaserSelectLine.global_transform.origin = pointertargetpoint
			LaserSelectLine.get_node("Scale").scale.z = LaserSelectLine.global_transform.origin.distance_to(activetargetnode.global_transform.origin)
			LaserSelectLine.global_transform = laserroot.get_node("LaserSpot").global_transform.looking_at(activetargetnode.global_transform.origin, Vector3(0,1,0))
		else:
			LaserSelectLine.visible = false
		
	if LaserShadow.visible and pointertargetpoint != null:
		LaserShadow.global_transform = Transform(Basis(), Vector3(pointertargetpoint.x, sketchsystem.getactivefloordrawing().global_transform.origin.y, pointertargetpoint.z))

func _on_button_pressed(p_button):
	var gripbuttonheld = handright.is_button_pressed(BUTTONS.VR_GRIP)
	print("pppp ", pointertargetpoint, " ", [activetargetnode, pointertargettype])
	if p_button == BUTTONS.VR_BUTTON_BY:
		buttonpressed_vrby(gripbuttonheld)
	elif p_button == BUTTONS.VR_GRIP:
		buttonpressed_vrgrip()
	elif p_button == BUTTONS.VR_TRIGGER:
		buttonpressed_vrtrigger(gripbuttonheld)
	elif p_button == BUTTONS.VR_PAD:
		buttonpressed_vrpad(gripbuttonheld, Vector2(handright.get_joystick_axis(0), handright.get_joystick_axis(1)))
	
func buttonpressed_vrby(gripbuttonheld):
	var cameracontrollervec = handright.global_transform.origin - headcam.global_transform.origin
	var ccaxvec = headcam.global_transform.basis.x.dot(handright.global_transform.basis.z)
	var pswitchpos = headcam.global_transform.origin + headcam.global_transform.basis.x*0.15 + headcam.global_transform.basis.y*0.1
	var pswitchdist = handright.global_transform.origin.distance_to(pswitchpos)
	if pointerplanviewtarget != null:
		pointerplanviewtarget.toggleplanviewactive()
	elif ccaxvec > 0.85 and pswitchdist < 0.1:
		guipanel3d.clickbuttonheadtorch()
	else:
		guipanel3d.toggleguipanelvisibility(handright.get_node("LaserOrient").global_transform)

func buttonpressed_vrgrip():
	gripbuttonpressused = false
	handright.get_node("csghandright").setpartcolor(4, "#00CC00")
	gripmenu.gripmenuon(handright.get_node("LaserOrient").global_transform, pointertargetwall, pointertargettype, activetargettube)
	
func buttonpressed_vrtrigger(gripbuttonheld):
	var dontdisablegripmenus = false
	
	if not is_instance_valid(pointertarget):
		pass
		
	elif pointertarget == guipanel3d:
		pass  # done in _process()

	elif pointertarget.has_method("jump_up"):
		pointertarget.jump_up()

	# grip click moves node on xcwall
	elif gripbuttonheld and activetargetnode != null and pointertargettype == "XCdrawing" and pointertargetwall == activetargetnodewall:
		activetargetnodewall.movexcnode(activetargetnode, pointertargetpoint, sketchsystem)

	# reselection when selected on grip deletes the node		
	elif gripbuttonheld and activetargetnode != null and pointertarget == activetargetnode and (activetargetnodewall.drawingtype != DRAWING_TYPE.DT_CENTRELINE):
		var recselectedtarget = activetargetnode
		var recselectedtargetwall = activetargetnodewall
		clearactivetargetnode()
		pointertarget = null
		pointertargettype = "none"
		pointertargetwall = null
		activelaserroot.get_node("LaserSpot").visible = false
		LaserShadow.visible = false
		recselectedtargetwall.removexcnode(recselectedtarget, false, sketchsystem)
		sketchsystem.get_node("SoundPos2").global_transform.origin = pointertargetpoint
		sketchsystem.get_node("SoundPos2").play()
	
			
	elif pointertargettype == "XCtube":
		if activetargettube == pointertargetwall:
			if gripbuttonheld:
				activetargettube.xcsectormaterials[activetargettube.activesector] = int(activetargettube.xcsectormaterials[activetargettube.activesector] + 1)%materialsystem.tubematerialcount()
				setactivetargettubesector(0)
			else:
				setactivetargettubesector(+1)
		else:
			if activetargettube != null:
				setactivetargettubesector(-2)
			activetargettube = pointertargetwall
			setactivetargettubesector(0)

	elif pointertargettype == "Papersheet" or pointertargettype == "PlanView":
		clearactivetargetnode()
		var alaserspot = activelaserroot.get_node("LaserSpot")
		alaserspot.global_transform.origin = pointertargetpoint
		setactivetargetwall(pointertargetwall)
		activetargetwallgrabbed = activetargetwall if pointertargettype == "Papersheet" else activetargetwall.get_node("PlanView")
		if gripbuttonheld:
			activetargetwallgrabbedtransform = alaserspot.global_transform.affine_inverse() * activetargetwallgrabbed.global_transform
			activetargetwallgrabbedpoint = alaserspot.global_transform.origin
			activetargetwallgrabbedlocalpoint = activetargetwallgrabbed.global_transform.affine_inverse() * alaserspot.global_transform.origin
			activetargetwallgrabbedpointoffset = alaserspot.global_transform.origin - activetargetwallgrabbed.global_transform.origin
		else:
			activetargetwallgrabbedtransform = alaserspot.global_transform.affine_inverse() * activetargetwallgrabbed.global_transform
			activetargetwallgrabbedpoint = null
			
	# grab and rotate XCdrawing in place (if empty)
	elif pointertargettype == "XCdrawing" and gripbuttonheld and activetargetnode == null and len(pointertargetwall.nodepoints) == 0:
		var alaserspot = activelaserroot.get_node("LaserSpot")
		activetargetwallgrabbed = pointertargetwall
		activetargetwallgrabbedtransform = alaserspot.global_transform.affine_inverse() * pointertargetwall.global_transform
		activetargetwallgrabbedpoint = alaserspot.global_transform.origin
		activetargetwallgrabbedlocalpoint = pointertargetwall.global_transform.affine_inverse() * alaserspot.global_transform.origin
		activetargetwallgrabbedpointoffset = alaserspot.global_transform.origin - pointertargetwall.global_transform.origin
		
	# make new point onto wall, connected if necessary
	elif pointertargettype == "XCdrawing":
		var newpointertarget = pointertargetwall.newxcnode()
		newpointertarget.global_transform.origin = pointertargetpoint
		pointertargetwall.copyxcntootnode(newpointertarget)
		sketchsystem.get_node("SoundPos1").global_transform.origin = pointertargetpoint
		sketchsystem.get_node("SoundPos1").play()
		if activetargetnode != null:
			if activetargetnodewall == pointertargetwall:
				sketchsystem.xcapplyonepath(activetargetnode, newpointertarget)
		sketchsystem.rpc("xcdrawingfromdata", pointertargetwall.exportxcrpcdata())
		setactivetargetnode(newpointertarget)
	
									
	# reselection clears selection
	elif activetargetnode != null and pointertarget == activetargetnode:
		clearactivetargetnode()

	# connecting lines between xctype nodes
	elif activetargetnode != null and pointertargettype == "XCnode":
		if not ((activetargetnodewall.drawingtype == DRAWING_TYPE.DT_CENTRELINE and pointertargetwall.drawingtype == DRAWING_TYPE.DT_XCDRAWING) or (activetargetnodewall.drawingtype == DRAWING_TYPE.DT_XCDRAWING and pointertargetwall.drawingtype == DRAWING_TYPE.DT_CENTRELINE)):
			sketchsystem.xcapplyonepath(activetargetnode, pointertarget)
			if activetargetnodewall == pointertargetwall:
				sketchsystem.rpc("xcdrawingfromdata", activetargetnodewall.exportxcrpcdata())
			sketchsystem.get_node("SoundPos1").global_transform.origin = pointertargetpoint
			sketchsystem.get_node("SoundPos1").play()
			clearactivetargetnode()
											
	elif pointertargettype == "XCnode":
		if pointertargetwall.drawingtype == DRAWING_TYPE.DT_XCDRAWING:
			pointertargetwall.rpc("setxcdrawingvisibility", true)
			if pointertargetwall != activetargetwall:
				setactivetargetwall(pointertargetwall)
		setactivetargetnode(pointertarget)

	elif pointertargettype == "GripMenuItem" and pointertarget.get_name() == "NewSlice" and gripbuttonheld and is_instance_valid(activetargettube):
		var xcdrawing = sketchsystem.newXCuniquedrawing(DRAWING_TYPE.DT_XCDRAWING, sketchsystem.uniqueXCname())
		var xcdrawing0 = sketchsystem.get_node("XCdrawings").get_node(activetargettube.xcname0)
		var xcdrawing1 = sketchsystem.get_node("XCdrawings").get_node(activetargettube.xcname1)
		xcdrawing.get_node("XCdrawingplane").set_scale(gripmenu.gripmenupointertargetwall.get_node("XCdrawingplane").scale)
		
		var sliceinitpoint = lerp(gripmenu.gripmenupointertargetwall.global_transform.origin, playerMe.get_node("HeadCam").global_transform.origin, 0.5)
		var v0c = sliceinitpoint - xcdrawing0.global_transform.origin
		var v1c = sliceinitpoint - xcdrawing1.global_transform.origin
		v0c.y = 0
		v1c.y = 0
		var h0c = abs(xcdrawing0.global_transform.basis.z.dot(v0c))
		var h1c = abs(xcdrawing1.global_transform.basis.z.dot(v1c))
		var lam = h0c/(h0c+h1c)
		print(" dd ", v0c, h0c, v1c, h1c, "  ", lam)
		if 0.05 < lam and lam < 0.95:
			var va0c = Vector2(xcdrawing0.global_transform.basis.x.x, xcdrawing0.global_transform.basis.x.z)
			var va1c = Vector2(xcdrawing1.global_transform.basis.x.x, xcdrawing1.global_transform.basis.x.z)
			if va1c.dot(va0c) < 0:
				va1c = -va1c
			var vang = lerp_angle(va0c.angle(), va1c.angle(), lam)
			var vwallmid = lerp(xcdrawing0.global_transform.origin, xcdrawing1.global_transform.origin, lam)
			xcdrawing.setxcpositionangle(vang)
			xcdrawing.setxcpositionorigin(vwallmid)
			sketchsystem.rpc("xcdrawingfromdata", xcdrawing.exportxcrpcdata())
			setactivetargetwall(xcdrawing)
			clearactivetargetnode()
		gripmenu.get_node("NewSlice").get_node("MeshInstance").visible = false
		gripmenu.get_node("NewSlice").get_node("CollisionShape").disabled = true
		gripmenu.get_node("DoSlice").get_node("MeshInstance").visible = true
		gripmenu.get_node("DoSlice").get_node("CollisionShape").disabled = false
		dontdisablegripmenus = true
		
	if gripbuttonheld and not dontdisablegripmenus:
		gripbuttonpressused = true
		gripmenu.disableallgripmenus()

				
func buttonpressed_vrpad(gripbuttonheld, joypos):
	if pointertargettype == "XCdrawing" and pointertargetwall.drawingtype == DRAWING_TYPE.DT_XCDRAWING:
		if abs(joypos.y) < 0.5 and abs(joypos.x) > 0.1:
			var dy = (1 if joypos.x > 0 else -1)*(1.0 if abs(joypos.x) < 0.8 else 0.1)
			pointertargetwall.get_node("XCdrawingplane").scale.x = max(1, pointertargetwall.get_node("XCdrawingplane").scale.x + dy)
			pointertargetwall.get_node("XCdrawingplane").scale.y = max(1, pointertargetwall.get_node("XCdrawingplane").scale.y + dy)
			xcdrawinghighlightmaterial.uv1_scale = pointertargetwall.get_node("XCdrawingplane").get_scale()
			xcdrawinghighlightmaterial.uv1_offset = -xcdrawinghighlightmaterial.uv1_scale/2
				
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

	elif pointertargettype == "XCtube" and activetargettube != null and pointertargetwall == activetargettube:
		if abs(joypos.x) > 0.65:
			var nsectors = activetargettube.get_node("XCtubeshell/MeshInstance").get_surface_material_count()
			setactivetargettubesector(1 if joypos.x > 0 else -1)
		elif abs(joypos.y) > 0.65:
			activetargettube.xcsectormaterials[activetargettube.activesector] = int(activetargettube.xcsectormaterials[activetargettube.activesector] + (1 if joypos.y > 0 else materialsystem.tubematerialcount() - 1))%materialsystem.tubematerialcount()
			setactivetargettubesector(0)
			
	#elif pointertargettype == "PlanView":
	elif pointerplanviewtarget != null and not pointerplanviewtarget.planviewactive:
		if abs(joypos.x) > 0.65:
			pointerplanviewtarget.camerascalechange(1.5 if joypos.x < 0 else 0.6667)
		elif abs(joypos.x) < 0.2 and abs(joypos.y) < 0.2:
			pointerplanviewtarget.cameraresetcentre(headcam)
		
func _on_button_release(p_button):
	if p_button == BUTTONS.VR_GRIP:
		buttonreleased_vrgrip()
	elif p_button == BUTTONS.VR_TRIGGER:
		buttonreleased_vrtrigger()

func buttonreleased_vrgrip():
	handright.get_node("csghandright").setpartcolor(4, "#FFFFFF")
	
	if gripbuttonpressused:
		pass  # the trigger was pulled during the grip operation
	
	elif pointertargettype == "GripMenuItem":
		if is_instance_valid(gripmenu.gripmenupointertargetwall):
			print("executing ", pointertarget.get_name(), " on ", gripmenu.gripmenupointertargetwall.get_name())
			if pointertarget.get_name() == "Up5":
				gripmenu.gripmenupointertargetwall.global_transform.origin.y += 1
				playerMe.global_transform.origin.y = max(playerMe.global_transform.origin.y, gripmenu.gripmenupointertargetwall.global_transform.origin.y)
			elif pointertarget.get_name() == "Down5":
				gripmenu.gripmenupointertargetwall.global_transform.origin.y -= 1
				gripmenu.gripmenupointertargetwall.global_transform.origin.y = max(gripmenu.gripmenupointertargetwall.global_transform.origin.y, get_node("/root/Spatial/underfloor").global_transform.origin.y + 0.5)
			elif pointertarget.get_name() == "toPaper":
				gripmenu.gripmenupointertargetwall.drawingtype = DRAWING_TYPE.DT_PAPERTEXTURE
				gripmenu.gripmenupointertargetwall.get_node("XCdrawingplane").collision_layer = CollisionLayer.CL_Pointer

			elif pointertarget.get_name() == "toFloor" or pointertarget.get_name() == "toBig":
				if pointertarget.get_name() == "toBig":
					var fs = max(1.1, 50/gripmenu.gripmenupointertargetwall.get_node("XCdrawingplane").scale.x)
					gripmenu.gripmenupointertargetwall.get_node("XCdrawingplane").scale.x *= fs
					gripmenu.gripmenupointertargetwall.get_node("XCdrawingplane").scale.y *= fs
				gripmenu.gripmenupointertargetwall.rotation_degrees.x = -90
				gripmenu.gripmenupointertargetwall.rotation_degrees.z = 0
				playerMe.global_transform.origin.y += 1
				gripmenu.gripmenupointertargetwall.global_transform.origin.y = playerMe.global_transform.origin.y
				gripmenu.gripmenupointertargetwall.drawingtype = DRAWING_TYPE.DT_FLOORTEXTURE
				gripmenu.gripmenupointertargetwall.get_node("XCdrawingplane").collision_layer = CollisionLayer.CL_Environment | CollisionLayer.CL_PointerFloor
		
			elif pointertarget.get_name() == "SelectXC":
				var xcdrawing0 = sketchsystem.get_node("XCdrawings").get_node(gripmenu.gripmenupointertargetwall.xcname0)
				var xcdrawing1 = sketchsystem.get_node("XCdrawings").get_node(gripmenu.gripmenupointertargetwall.xcname1)
				if xcdrawing0.drawingtype == DRAWING_TYPE.DT_XCDRAWING:
					xcdrawing0.rpc("setxcdrawingvisibility", true)
					xcdrawing1.rpc("setxcdrawingvisibility", true)
					if xcdrawing0 != activetargetwall:
						setactivetargetwall(xcdrawing0)
					elif xcdrawing1 != activetargetwall:
						setactivetargetwall(xcdrawing1)

			elif pointertarget.get_name() == "DelXC":
				print("Not implemented") 				
				
			elif pointertarget.get_name() == "ghost":
				print("Not implemented")
				if activetargettube != null:
					 activetargettube.get_node("XCtubeshell/MeshInstance").set_surface_material(activetargettube.activesector, materialsystem.tubematerialtransparent(false))

			elif pointertarget.get_name() == "NewSlice" and is_instance_valid(activetargettube):
				print("Press trigger to action")
				
			elif pointertarget.get_name() == "DoSlice" and is_instance_valid(activetargettube) and len(activetargetwall.nodepoints) == 0:
				print(activetargettube, " ", len(activetargetwall.nodepoints))
				var xcdrawing = activetargetwall
				var vang = Vector2(xcdrawing.global_transform.basis.x.x, xcdrawing.global_transform.basis.x.z).angle()
				xcdrawing.setxcpositionangle(vang)
				var xcdrawinglink0 = [ ]
				var xcdrawinglink1 = [ ]
				activetargettube.slicetubetoxcdrawing(xcdrawing, xcdrawinglink0, xcdrawinglink1)
				xcdrawing.updatexcpaths()
				sketchsystem.rpc("xcdrawingfromdata", xcdrawing.exportxcrpcdata())
				setactivetargetwall(xcdrawing)
				clearactivetargetnode()
				var xcdrawing0 = sketchsystem.get_node("XCdrawings").get_node(activetargettube.xcname0)
				var xcdrawing1 = sketchsystem.get_node("XCdrawings").get_node(activetargettube.xcname1)
				xcdrawing0.xctubesconn.remove(xcdrawing0.xctubesconn.find(activetargettube))
				xcdrawing1.xctubesconn.remove(xcdrawing1.xctubesconn.find(activetargettube))

				var xctube0 = sketchsystem.newXCtube(xcdrawing0, xcdrawing)
				xctube0.xcdrawinglink = xcdrawinglink0
				xctube0.xcsectormaterials = activetargettube.xcsectormaterials.duplicate()
				xctube0.updatetubelinkpaths(sketchsystem)
				sketchsystem.rpc("xctubefromdata", xctube0.exportxctrpcdata())
				xctube0.updatetubeshell(sketchsystem.get_node("XCdrawings"), sketchsystem.tubeshellsvisible)
			
				var xctube1 = sketchsystem.newXCtube(xcdrawing, xcdrawing1)
				xctube1.xcdrawinglink = xcdrawinglink1
				xctube1.updatetubelinkpaths(sketchsystem)
				xctube1.xcsectormaterials = activetargettube.xcsectormaterials.duplicate()
				
				#xctube1.xcsectormaterials.push_front(xctube1.xcsectormaterials.pop_back())
				#xctube1.xcsectormaterials.push_front(xctube1.xcsectormaterials.pop_back())

				sketchsystem.rpc("xctubefromdata", xctube0.exportxctrpcdata())
				xctube1.updatetubeshell(sketchsystem.get_node("XCdrawings"), sketchsystem.tubeshellsvisible)

				xcdrawing.updatexctubeshell(sketchsystem.get_node("XCdrawings"), sketchsystem.tubeshellsvisible)  # not strictly necessary as there won't be any shells in a sliced tube xc

				pointertargettype = "none"
				pointertarget = null
				activetargettube.queue_free()  # must remove from xctubesconn
				activetargettube = null
				activelaserroot.get_node("LaserSpot").visible = false
				LaserShadow.visible = false

		
	elif pointertargettype == "GUIPanel3D":
		if guipanel3d.visible:
			guipanel3d.toggleguipanelvisibility(null)

	elif pointertargettype == "XCdrawing" and pointertargetwall.drawingtype == DRAWING_TYPE.DT_XCDRAWING:
		clearpointertargetmaterial()
		pointertargetwall.rpc("setxcdrawingvisibility", false)
		sketchsystem.rpc("xcdrawingfromdata", pointertargetwall.exportxcrpcdata())
		setactivetargetwall(null)
		pointertarget = null
		pointertargettype = "none"
		pointertargetwall = null
		activelaserroot.get_node("LaserSpot").visible = false
		LaserShadow.visible = false

	elif pointertargettype == "XCtube":
		if activetargettube != null:
			setactivetargettubesector(-2)
			activetargettube = null

	elif activetargetnode != null:
		clearactivetargetnode()
		

	gripmenu.disableallgripmenus()

		
func buttonreleased_vrtrigger():
	if activetargetwallgrabbedtransform != null:
		#setactivetargetwall(null)
		activetargetwallgrabbedtransform = null
	
	if (pointertargettype == "XCnode" and pointertargetwall.drawingtype == DRAWING_TYPE.DT_FLOORTEXTURE) and (activetargetnode != null and activetargetnodewall.drawingtype == DRAWING_TYPE.DT_FLOORTEXTURE) and pointertarget != activetargetnode:
		print("makingxcplane")
		var xcdrawing = sketchsystem.newXCuniquedrawing(DRAWING_TYPE.DT_XCDRAWING, sketchsystem.uniqueXCname())
		var vx = pointertarget.global_transform.origin - activetargetnode.global_transform.origin
		xcdrawing.setxcpositionangle(Vector2(vx.x, vx.z).angle())
		var vwallmid = (pointertarget.global_transform.origin + activetargetnode.global_transform.origin)/2
		xcdrawing.setxcpositionorigin(vwallmid)
		clearactivetargetnode()
		setactivetargetwall(xcdrawing)
		sketchsystem.rpc("xcdrawingfromdata", xcdrawing.exportxcrpcdata())
						
func _physics_process(_delta):
	if playerMe.arvrinterface == null:
		var mvec = headcam.global_transform.basis.xform(mousecontrollervec)
		handright.global_transform.origin = headcam.global_transform.origin + mvec
		handright.look_at(handright.global_transform.origin + 1.0*mvec + 0.0*headcam.global_transform.basis.z, Vector3(0,1,0))
		handright.global_transform.origin.y -= 0.3
		
	if playerMe.VRstatus != "quest":
		var firstlasertarget = LaserOrient.get_node("RayCast").get_collider() if LaserOrient.get_node("RayCast").is_colliding() and not LaserOrient.get_node("RayCast").get_collider().is_queued_for_deletion() else null
		pointerplanviewtarget = planviewsystem if firstlasertarget != null and firstlasertarget.get_name() == "PlanView" and planviewsystem.checkplanviewinfront(handright) else null
		if pointerplanviewtarget != null:
			pointerplanviewtarget.processplanviewsliding(handright, _delta)
		if pointerplanviewtarget != null and pointerplanviewtarget.planviewactive:
			var planviewcontactpoint = LaserOrient.get_node("RayCast").get_collision_point()
			LaserOrient.get_node("LaserSpot").global_transform.origin = planviewcontactpoint
			LaserOrient.get_node("Length").scale.z = -LaserOrient.get_node("LaserSpot").translation.z
			LaserOrient.get_node("LaserSpot").visible = false
			pointerplanviewtarget.processplanviewpointing(planviewcontactpoint)
			activelaserroot = planviewsystem.get_node("RealPlanCamera/LaserScope/LaserOrient")
			activelaserroot.get_node("LaserSpot").global_transform.basis = LaserOrient.global_transform.basis
		else:
			planviewsystem.get_node("RealPlanCamera/LaserScope").visible = false
			activelaserroot = LaserOrient
		if activetargetwall != null and pointertargetwall == activetargetwall and len(activetargetwall.nodepoints) == 0 and handright.get_is_active() and handright.is_button_pressed(BUTTONS.VR_GRIP):
			var joypos = Vector2(handright.get_joystick_axis(0), handright.get_joystick_axis(1))
			if abs(joypos.x) > 0.3:
				activetargetwall.rotation_degrees.y += joypos.x*30*_delta
			if abs(joypos.y) > 0.3:
				var p0 = gripmenu.gripmenupointertargetwall.global_transform.origin
				var p1 = handright.global_transform.origin
				var pm = activetargetwall.global_transform.origin
				var vp = p1 - p0
				var lam = vp.dot(pm - p0)/vp.dot(vp)
				if (lam > 0.1 and joypos.y > 0) or (lam < 0.9 and joypos.y < 0):
					activetargetwall.global_transform.origin += -vp.normalized()*2*_delta*sign(joypos.y)

		onpointing(activelaserroot)
		
	if activetargetwallgrabbedtransform != null:
		if activetargetwallgrabbedpoint != null:
			activetargetwallgrabbed.global_transform = activelaserroot.get_node("LaserSpot").global_transform * activetargetwallgrabbedtransform
			activetargetwallgrabbed.global_transform.origin += activetargetwallgrabbedpoint - activetargetwallgrabbed.global_transform * activetargetwallgrabbedlocalpoint
		else:
			activetargetwallgrabbed.global_transform = activelaserroot.get_node("LaserSpot").global_transform * activetargetwallgrabbedtransform
		activetargetwallgrabbed.rpc_unreliable("setxcdrawingposition", activetargetwallgrabbed.global_transform)


var rightmousebuttonheld = false
func _input(event):
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		if playerMe.arvrinterface == null or playerMe.arvrinterface.get_tracking_status() == ARVRInterface.ARVR_NOT_TRACKING:
			var rhvec = mousecontrollervec + Vector3(event.relative.x, -event.relative.y, 0)*0.002
			rhvec.x = clamp(rhvec.x, -0.4, 0.4)
			rhvec.y = clamp(rhvec.y, -0.3, 0.6)
			mousecontrollervec = rhvec.normalized()*0.8
			
	elif event is InputEventMouseButton:
		if event.button_index == BUTTON_RIGHT:
			rightmousebuttonheld = event.pressed
		
		if event.button_index == BUTTON_LEFT:
			if event.pressed:
				buttonpressed_vrtrigger(rightmousebuttonheld)
			else:
				buttonreleased_vrtrigger()
		if event.button_index == BUTTON_RIGHT:
			if event.pressed:
				buttonpressed_vrgrip()
			else:
				buttonreleased_vrgrip()

	elif event is InputEventMouseButton and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		var gripbuttonheld = false
		if event.button_index == BUTTON_LEFT:
			if event.pressed:
				buttonpressed_vrtrigger(gripbuttonheld)
			else:
				buttonreleased_vrtrigger()
				
	elif event is InputEventKey and event.pressed and event.scancode == KEY_M:
		buttonpressed_vrby(false)	
	

func _on_HeelHotspot_body_entered(body):
	print("_on_HeelHotspot_body_entered ", body)

func _on_HeelHotspot_body_exited(body):
	print("_on_HeelHotspot_body_exited ", body)
