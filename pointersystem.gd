extends Node

onready var sketchsystem = get_node("/root/Spatial/SketchSystem")
onready var centrelinesystem = sketchsystem.get_node("Centreline")

onready var playernode = get_parent()
onready var headcam = playernode.get_node('HeadCam')
onready var handleft = playernode.get_node("HandLeft")
onready var handright = playernode.get_node("HandRight")
onready var guipanel3d = playernode.get_node("GUIPanel3D")

onready var LaserLength = handright.get_node("LaserOrient/Length") 
onready var LaserRayCast = handright.get_node("LaserOrient/RayCast") 
onready var LaserSpot = handright.get_node("LaserOrient/LaserSpot") 
onready var LaserShadow = handright.get_node("LaserShadow") 
onready var LaserSelectLine = handright.get_node("LaserSelectLine") 

var viewport_point = null

enum Buttons { VR_TRIGGER = 15, VR_PAD=14, VR_BUTTON_BY=1, VR_GRIP=2 }
enum DRAWING_TYPE { DT_XCDRAWING = 0, DT_FLOORTEXTURE = 1, DT_CENTRELINE = 2 }


var distance = 50

const XCdrawing = preload("res://nodescenes/XCdrawing.tscn")
const XCnode = preload("res://nodescenes/XCnode.tscn")
				
var pointinghighlightmaterial = preload("res://guimaterials/XCnode_highlight.material")
var selectedhighlightmaterial = preload("res://guimaterials/XCnode_selected.material")
var selectedpointerhighlightmaterial = preload("res://guimaterials/XCnode_selectedhighlight.material")

var laserspothighlightmaterial = preload("res://guimaterials/laserspot_selected.material"); 


#var laser_y = -0.05

onready var ARVRworld_scale = ARVRServer.world_scale


var pointertarget = null
var pointertargettype = "none"
var pointertargetwall = "none"
var pointertargetpoint = Vector3(0, 0, 0)
var selectedtarget = null
var selectedtargettype = "none"
var selectedtargetwall = null
var gripbuttonpressused = false
var activetargetwall = null

var xcdrawingactivematerial = preload("res://guimaterials/XCdrawing_active.material")
var xcdrawingmaterial = preload("res://guimaterials/XCdrawing.material")
var xcdrawinghighlightmaterial = preload("res://guimaterials/XCdrawing_highlight.material")

func clearpointertargetmaterial():
	if pointertargettype == "XCnode":
		pointertarget.get_node("CollisionShape/MeshInstance").set_surface_material(0, selectedhighlightmaterial if pointertarget == selectedtarget else (preload("res://guimaterials/XCnode_nodepthtest.material") if pointertargetwall == activetargetwall else preload("res://guimaterials/XCnode.material")))
	if pointertargettype == "XCdrawing" or pointertargettype == "XCnode":
		if pointertargetwall == activetargetwall:
			xcdrawingactivematerial.uv1_scale = pointertargetwall.get_node("XCdrawingplane").get_scale()
			xcdrawingactivematerial.uv1_offset = -xcdrawingactivematerial.uv1_scale/2
		pointertargetwall.get_node("XCdrawingplane/CollisionShape/MeshInstance").set_surface_material(0, xcdrawingactivematerial if pointertargetwall == activetargetwall else xcdrawingmaterial)
	handright.get_node("csghandright").setpartcolor(2, "#FFFFFF")
			
func setpointertargetmaterial():
	if pointertargettype == "XCnode":
		pointertarget.get_node("CollisionShape/MeshInstance").set_surface_material(0, selectedpointerhighlightmaterial if pointertarget == selectedtarget else pointinghighlightmaterial)
		handright.get_node("csghandright").setpartcolor(2, "#FFFF60")
	if pointertargettype == "XCdrawing" or pointertargettype == "XCnode":
		xcdrawinghighlightmaterial.uv1_scale = pointertargetwall.get_node("XCdrawingplane").get_scale()
		xcdrawinghighlightmaterial.uv1_offset = -xcdrawinghighlightmaterial.uv1_scale/2
		pointertargetwall.get_node("XCdrawingplane/CollisionShape/MeshInstance").set_surface_material(0, xcdrawinghighlightmaterial)
		handright.get_node("csghandright").setpartcolor(2, "#FFFF60")
	
func setselectedtarget(newselectedtarget):
	setbillboardlabel(null, null)
	if selectedtargettype == "XCnode":
		selectedtarget.get_node("CollisionShape/MeshInstance").set_surface_material(0, preload("res://guimaterials/XCnode_nodepthtest.material") if selectedtargetwall == activetargetwall else preload("res://guimaterials/XCnode.material"))
		
	selectedtarget = newselectedtarget
	selectedtargettype = targettype(newselectedtarget)
	selectedtargetwall = targetwall(selectedtarget, selectedtargettype)
	if selectedtargetwall != null and selectedtargetwall.drawingtype == DRAWING_TYPE.DT_CENTRELINE:
		setbillboardlabel(selectedtarget.get_name(), selectedtarget.global_transform.origin)
	if selectedtarget != pointertarget and selectedtargettype == "XCnode":
		selectedtarget.get_node("CollisionShape/MeshInstance").set_surface_material(0, selectedhighlightmaterial)
	LaserSpot.material_override = preload("res://guimaterials/laserspot_selected.material") if selectedtarget != null else null
	setpointertargetmaterial()

func setactivetargetwall(newactivetargetwall):
	if activetargetwall != null:
		activetargetwall.get_node("XCdrawingplane/CollisionShape/MeshInstance").set_surface_material(0, preload("res://guimaterials/XCdrawing.material"))
		activetargetwall.get_node("PathLines").set_surface_material(0, preload("res://guimaterials/XCdrawingPathlines.material"))
		for xcnode in activetargetwall.get_node("XCnodes").get_children():
			xcnode.get_node("CollisionShape/MeshInstance").set_surface_material(0, preload("res://guimaterials/XCnode_selected.material") if xcnode == selectedtarget else preload("res://guimaterials/XCnode.material"))
		if activetargetwall.drawingtype == DRAWING_TYPE.DT_XCDRAWING:
			for xctube in activetargetwall.xctubesconn:
				if not xctube.positioningtube:
					xctube.updatetubeshell(sketchsystem.get_node("XCdrawings"), sketchsystem.tubeshellsvisible)
	
	activetargetwall = newactivetargetwall
	if activetargetwall != null:
		activetargetwall.get_node("XCdrawingplane/CollisionShape/MeshInstance").set_surface_material(0, preload("res://guimaterials/XCdrawing_active.material"))
		activetargetwall.get_node("PathLines").set_surface_material(0, preload("res://guimaterials/XCdrawingPathlines_nodepthtest.material"))
		for xcnode in activetargetwall.get_node("XCnodes").get_children():
			if xcnode != selectedtarget:
				xcnode.get_node("CollisionShape/MeshInstance").set_surface_material(0, preload("res://guimaterials/XCnode_nodepthtest.material"))
	LaserRayCast.collision_mask = 8 + 16 + (32 if activetargetwall == null else 0)  # pointer, floor, cavewall(tube)=bit5


func settextpanel(ltext, pos):
	var textpanel = sketchsystem.get_node("Centreline/TextPanel")
	if ltext != null:
		textpanel.get_node("Viewport/Label").text = ltext
		textpanel.global_transform.origin = pos + Vector3(0, 0.3, 0)
		textpanel.visible = true
	else:
		textpanel.visible = false

func setbillboardlabel(ltext, pos):
	var textpanel = sketchsystem.get_node("BillboardLabel")
	if ltext != null:
		textpanel.get_node("Viewport/Label").text = ltext
		textpanel.global_transform.origin = pos + Vector3(0, 0.3, 0)
		textpanel.visible = true
	else:
		textpanel.visible = false


func _ready():
	handright.connect("button_pressed", self, "_on_button_pressed")
	handright.connect("button_release", self, "_on_button_release")
	print("in the pointer onready")

func targettype(target):
	if not is_instance_valid(target):
		return "none"
	var targetname = target.get_name()
	if targetname == "GUIPanel3D":
		return targetname
	if targetname == "XCtubeshell":    # shell inside an XCtube
		return "XCtube"
	var targetparent = target.get_parent()
	var targetparentname = targetparent.get_name()
	if targetname == "XCdrawingplane": # shell inside an XCdrawing
		return "XCdrawing"
	if targetparentname == "XCnodes":  # containers inside of a drawing
		return "XCnode"
	return "unknown"
		
func targetwall(target, targettype):
	if targettype == "XCdrawing":
		return target.get_parent()
	if targettype == "XCnode":
		return target.get_parent().get_parent()
	if targettype == "XCtube":
		return target.get_parent()
	return null
	
func setopnpos(opn, p):
	opn.global_transform.origin = p
		
func onpointing(newpointertarget, newpointertargetpoint):
	if newpointertarget != pointertarget:
		if is_instance_valid(pointertarget) and pointertarget == guipanel3d:
			guipanel3d.guipanelreleasemouse()
		
		clearpointertargetmaterial()
		pointertarget = newpointertarget
		pointertargettype = targettype(pointertarget)
		pointertargetwall = targetwall(pointertarget, pointertargettype)
		setpointertargetmaterial()
		
		if is_instance_valid(pointertarget):
			print("ppp  ", selectedtargettype, " ", pointertargettype)
			if pointertargettype == "XCnode":
				LaserSpot.visible = false
				LaserShadow.visible = true
			elif pointertarget == guipanel3d:
				LaserSpot.visible = false
				LaserShadow.visible = false
			else:
				LaserSpot.visible = true
				LaserShadow.visible = (pointertargettype == "XCdrawing")
				
			# work out the logic for the LaserSelectLine here
			if handright.is_button_pressed(Buttons.VR_GRIP):
				pass # do this LaserSelectLine.visible = ((pointertargettype == "floordrawing") and ((selectedtargettype == "OnePathNode")))
			elif pointertargettype == "XCdrawing":
				LaserSelectLine.visible = ((selectedtargettype == "XCnode"))
			elif pointertargettype == "XCnode":
				LaserSelectLine.visible = ((selectedtargettype == "XCnode"))
			else:
				LaserSelectLine.visible = false
			
		else:
			LaserSpot.visible = false
			LaserShadow.visible = false
			LaserSelectLine.visible = false
			
	pointertargetpoint = newpointertargetpoint
	if is_instance_valid(pointertarget) and pointertarget == guipanel3d:
		guipanel3d.guipanelsendmousemotion(pointertargetpoint, handright.global_transform, handright.is_button_pressed(Buttons.VR_TRIGGER))

	if pointertargetpoint != null:
		LaserSpot.global_transform.origin = pointertargetpoint
		LaserLength.scale.z = -LaserSpot.translation.z
	else:
		LaserLength.scale.z = -LaserRayCast.cast_to.z
		
	if LaserSelectLine.visible:
		if pointertarget != null and selectedtarget != null:
			LaserSelectLine.global_transform.origin = pointertargetpoint
			LaserSelectLine.get_node("Scale").scale.z = LaserSelectLine.global_transform.origin.distance_to(selectedtarget.global_transform.origin)
			LaserSelectLine.global_transform = LaserSpot.global_transform.looking_at(selectedtarget.global_transform.origin, Vector3(0,1,0))
		else:
			LaserSelectLine.visible = false
		
	if LaserShadow.visible and pointertargetpoint != null:
		LaserShadow.global_transform = Transform(Basis(), Vector3(pointertargetpoint.x, sketchsystem.get_node("XCdrawings/floordrawing").global_transform.origin.y, pointertargetpoint.z))


func _on_button_pressed(p_button):
	var gripbuttonheld = handright.is_button_pressed(Buttons.VR_GRIP)
	print("pppp ", pointertargetpoint, " ", [selectedtargettype, pointertargettype])
	#$SoundPointer.play()
	
	if p_button == Buttons.VR_BUTTON_BY:
		var cameracontrollervec = handright.global_transform.origin - headcam.global_transform.origin
		var ccaxvec = headcam.global_transform.basis.x.dot(handright.global_transform.basis.z)
		var pswitchpos = headcam.global_transform.origin + headcam.global_transform.basis.x*0.15 + headcam.global_transform.basis.y*0.1
		var pswitchdist = handright.global_transform.origin.distance_to(pswitchpos)
		if ccaxvec > 0.85 and pswitchdist < 0.1:
			guipanel3d.clickbuttonheadtorch()
		else:
			guipanel3d.togglevisibility(handright.get_node("LaserOrient").global_transform)

	if p_button == Buttons.VR_GRIP:
		gripbuttonpressused = false
		handright.get_node("csghandright").setpartcolor(4, "#00CC00")
				
	if p_button == Buttons.VR_TRIGGER and is_instance_valid(pointertarget):
		print("clclc ", pointertarget, "--", pointertarget.get_name(), "  filename:", pointertarget.get_filename(), " p:", pointertarget.get_parent())
		if gripbuttonheld:
			gripbuttonpressused = true
						
		if pointertarget == guipanel3d:
			pass  #this is processed elsewhere

		elif pointertarget.has_method("jump_up"):
			pointertarget.jump_up()

		# grip click moves node on xcwall
		elif gripbuttonheld and selectedtargettype == "XCnode" and pointertargettype == "XCdrawing" and pointertargetwall == selectedtargetwall:
			selectedtargetwall.movexcnode(selectedtarget, pointertargetpoint, sketchsystem)

		# reselection when selected on grip deletes the node		
		elif gripbuttonheld and selectedtargettype == "XCnode" and pointertarget == selectedtarget:
			var recselectedtarget = selectedtarget
			var recselectedtargetwall = selectedtargetwall
			setselectedtarget(null)
			pointertarget = null
			pointertargettype = "none"
			pointertargetwall = null
			recselectedtargetwall.removexcnode(recselectedtarget, false, sketchsystem)
			sketchsystem.get_node("SoundPos2").global_transform.origin = pointertargetpoint
			sketchsystem.get_node("SoundPos2").play()

		# duplication of XCdrawing (in special cases)
		elif gripbuttonheld and selectedtargetwall != null and selectedtargettype == "XCnode" and selectedtargetwall.drawingtype == DRAWING_TYPE.DT_FLOORTEXTURE and pointertargettype == "XCnode" and selectedtargetwall == pointertargetwall:
			var xcdrawingtocopy = null
			var xcdrawingtocopynodelink = null
			var btargetclear = true
			for xctube in selectedtargetwall.xctubesconn:
				if sketchsystem.get_node("XCdrawings").get_node(xctube.xcname1).drawingtype == DRAWING_TYPE.DT_XCDRAWING:
					if xctube.xcdrawinglink.slice(0, len(xctube.xcdrawinglink), 2).has(pointertarget.get_name()):
						btargetclear = false
					for i in range(0, len(xctube.xcdrawinglink), 2):
						#if xctube.xcdrawinglink.slice(1, len(xctube.xcdrawinglink), 2).has(selectedtarget.get_name()):
						if xctube.xcdrawinglink[i] == selectedtarget.get_name():
							xcdrawingtocopy = sketchsystem.get_node("XCdrawings").get_node(xctube.xcname1)
							xcdrawingtocopynodelink = xctube.xcdrawinglink[i+1]
							break
			if btargetclear and xcdrawingtocopy != null:
				print("making new copied drawing¬!!!!")
				var xcdrawing = xcdrawingtocopy.duplicatexcdrawing(sketchsystem)
				var vline = pointertargetpoint - selectedtarget.global_transform.origin
				var drawingwallangle = Vector2(vline.z, -vline.x).angle()
				if vline.dot(xcdrawing.global_transform.basis.z) < 0:
					drawingwallangle = Vector2(-vline.z, vline.x).angle()
				xcdrawing.setxcpositionangle(drawingwallangle)
				xcdrawing.setxcpositionorigin(pointertargetpoint)
				sketchsystem.xcapplyonepath(xcdrawing.get_node("XCnodes").get_node(xcdrawingtocopynodelink), pointertarget)
				sketchsystem.xcapplyonepath(xcdrawingtocopy.get_node("XCnodes").get_node(xcdrawingtocopynodelink), xcdrawing.get_node("XCnodes").get_node(xcdrawingtocopynodelink))
				setactivetargetwall(xcdrawing)
			setselectedtarget(pointertarget)
		
		# new XCintersecting in tube case
		elif gripbuttonheld and selectedtargettype == "XCnode" and pointertargettype == "XCtube" and (selectedtargetwall.get_name() == pointertargetwall.xcname0 or selectedtargetwall.get_name() == pointertargetwall.xcname1):
			var xcdrawing0 = sketchsystem.get_node("XCdrawings").get_node(pointertargetwall.xcname0)
			var xcdrawing1 = sketchsystem.get_node("XCdrawings").get_node(pointertargetwall.xcname1)
			var v0c = pointertargetpoint - xcdrawing0.global_transform.origin
			var v1c = pointertargetpoint - xcdrawing1.global_transform.origin
			v0c.y = 0
			v1c.y = 0
			var h0c = abs(xcdrawing0.global_transform.basis.z.dot(v0c))
			var h1c = abs(xcdrawing1.global_transform.basis.z.dot(v1c))
			var lam = h0c/(h0c+h1c)
			print(" dd ", v0c, h0c, v1c, h1c, "  ", lam)
			if 0.1 < lam and lam < 0.9:
				var va0c = Vector2(xcdrawing0.global_transform.basis.x.x, xcdrawing0.global_transform.basis.x.z)
				var va1c = Vector2(xcdrawing1.global_transform.basis.x.x, xcdrawing1.global_transform.basis.x.z)
				if va1c.dot(va0c) < 0:
					va1c = -va1c
				var vang = lerp_angle(va0c.angle(), va1c.angle(), lam)				
				var vwallmid = lerp(xcdrawing0.global_transform.origin, xcdrawing1.global_transform.origin, lam)
				
				var xcdrawing = sketchsystem.newXCuniquedrawing()
				xcdrawing.setxcpositionangle(vang)
				xcdrawing.setxcpositionorigin(vwallmid)
				var xcdrawinglink0 = [ ]
				var xcdrawinglink1 = [ ]
				pointertargetwall.slicetubetoxcdrawing(xcdrawing, xcdrawinglink0, xcdrawinglink1, lam)
				xcdrawing.updatexcpaths()
				setactivetargetwall(xcdrawing)
				setselectedtarget(null)
				xcdrawing0.xctubesconn.remove(xcdrawing0.xctubesconn.find(pointertargetwall))
				xcdrawing1.xctubesconn.remove(xcdrawing1.xctubesconn.find(pointertargetwall))

				var xctube0 = sketchsystem.newXCtube(xcdrawing0, xcdrawing)
				xctube0.xcdrawinglink = xcdrawinglink0
				xctube0.updatetubelinkpaths(sketchsystem)
				xctube0.updatetubeshell(sketchsystem.get_node("XCdrawings"), sketchsystem.tubeshellsvisible)
				
				var xctube1 = sketchsystem.newXCtube(xcdrawing1, xcdrawing)
				xctube1.xcdrawinglink = xcdrawinglink1
				xctube1.updatetubelinkpaths(sketchsystem)
				xctube1.updatetubeshell(sketchsystem.get_node("XCdrawings"), sketchsystem.tubeshellsvisible)

				pointertargettype = "none"
				pointertarget = null
				pointertargetwall.queue_free()
				pointertargetwall = null
				
		# grip condition is ignored (assumed off) her on
		#elif gripbuttonheld:
		#	pass

		# make new point onto wall, connected if necessary
		elif pointertargettype == "XCdrawing":
			var newpointertarget = pointertargetwall.newxcnode()
			newpointertarget.global_transform.origin = pointertargetpoint
			pointertargetwall.copyxcntootnode(newpointertarget)
			sketchsystem.get_node("SoundPos1").global_transform.origin = pointertargetpoint
			sketchsystem.get_node("SoundPos1").play()
			if selectedtargettype == "XCnode":
				if selectedtargetwall == pointertargetwall:
					sketchsystem.xcapplyonepath(selectedtarget, newpointertarget)
			setselectedtarget(newpointertarget)
									
		# reselection clears selection
		elif selectedtargettype == "XCnode" and pointertarget == selectedtarget:
			setselectedtarget(null)

		# connecting lines between xctype nodes
		elif selectedtargettype == "XCnode" and pointertargettype == "XCnode":
			if not ((selectedtargetwall.drawingtype == DRAWING_TYPE.DT_CENTRELINE and selectedtargetwall.drawingtype == DRAWING_TYPE.DT_XCDRAWING) or (selectedtargetwall.drawingtype == DRAWING_TYPE.DT_XCDRAWING and selectedtargetwall.drawingtype == DRAWING_TYPE.DT_FLOORTEXTURE)):
				sketchsystem.xcapplyonepath(selectedtarget, pointertarget)
				setselectedtarget(pointertarget)
												
		elif pointertargettype == "XCnode":
			if pointertargetwall.drawingtype == DRAWING_TYPE.DT_XCDRAWING:
				pointertargetwall.setxcdrawingvisibility(true)
				if pointertargetwall != activetargetwall:
					setactivetargetwall(pointertargetwall)
			setselectedtarget(pointertarget)

				
	# change height of pointer target
	if p_button == Buttons.VR_PAD:
		var left_right = handright.get_joystick_axis(0)
		var up_down = handright.get_joystick_axis(1)
		if abs(up_down) < 0.5 and abs(left_right) > 0.1 and is_instance_valid(pointertarget):
			var dy = (1 if left_right > 0 else -1)*(1.0 if abs(left_right) < 0.8 else 0.1)

			if pointertargettype == "XCdrawing":
				pointertargetwall.get_node("XCdrawingplane").scale.x = max(1, pointertargetwall.get_node("XCdrawingplane").scale.x + dy)
				pointertargetwall.get_node("XCdrawingplane").scale.y = max(1, pointertargetwall.get_node("XCdrawingplane").scale.y + dy)
				xcdrawinghighlightmaterial.uv1_scale = pointertargetwall.get_node("XCdrawingplane").get_scale()
				xcdrawinghighlightmaterial.uv1_offset = -xcdrawinghighlightmaterial.uv1_scale/2
				
func _on_button_release(p_button):
	# cancel selection by squeezing and then releasing grip without doing anything in between
	if p_button == Buttons.VR_GRIP:
		handright.get_node("csghandright").setpartcolor(4, "#FFFFFF")
		if gripbuttonpressused:
			pass
		
		elif pointertargettype == "GUIPanel3D":
			if guipanel3d.visible:
				guipanel3d.togglevisibility(handright.get_node("LaserOrient").global_transform)

		elif pointertargettype == "XCdrawing" and pointertargetwall.drawingtype == DRAWING_TYPE.DT_XCDRAWING:
			clearpointertargetmaterial()
			pointertargetwall.setxcdrawingvisibility(false)
			setactivetargetwall(null)
			pointertarget = null
			pointertargettype = "none"
			pointertargetwall = null

		elif selectedtargettype == "XCnode":
			setselectedtarget(null)
			
		elif pointertargettype == "XCtube":
			pointertargetwall.togglematerialcycle()
		
	# new drawing wall position made
	elif p_button == Buttons.VR_TRIGGER and (pointertargettype == "XCnode" and pointertargetwall.drawingtype == DRAWING_TYPE.DT_FLOORTEXTURE) and (selectedtargettype == "XCnode" and selectedtargetwall.drawingtype == DRAWING_TYPE.DT_FLOORTEXTURE) and pointertarget != selectedtarget:
		print("makingxcplane")
		var xcdrawing = sketchsystem.newXCuniquedrawing()
		var vx = pointertarget.global_transform.origin - selectedtarget.global_transform.origin
		xcdrawing.setxcpositionangle(Vector2(vx.x, vx.z).angle())
		var vwallmid = (pointertarget.global_transform.origin + selectedtarget.global_transform.origin)/2
		xcdrawing.setxcpositionorigin(vwallmid)
		setselectedtarget(null)
		setactivetargetwall(xcdrawing)
		
						
func _physics_process(_delta):
	if !is_inside_tree():
		return
	if LaserRayCast.is_colliding():
		onpointing(LaserRayCast.get_collider(), LaserRayCast.get_collision_point())
	else:
		onpointing(null, null)
	


