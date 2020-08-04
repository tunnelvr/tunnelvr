extends Spatial

# this has a pointer sphere added JGT
# (and a lot of other hacking)

# variables set by the Spatial.gd
var sketchsystem = null
var centrelinesystem =null
var nodeorientationpreview = null

var guipanel3d = null
var _is_activating_gui = false
var viewport_point = null

enum Buttons { VR_TRIGGER = 15, VR_PAD=14, VR_BUTTON_BY=1, VR_GRIP=2 }
onready var controller = get_parent()
onready var arvrcamera = get_node("../../ARVRCamera")
var distance = 50
var floordrawing = null

const XCdrawing = preload("res://nodescenes/XCdrawing.tscn")
const XCnode = preload("res://nodescenes/XCnode.tscn")
const XCcursor = preload("res://nodescenes/XCcursor.tscn")
				
var pointinghighlightmaterial = preload("res://guimaterials/XCnode_highlight.material")
var selectedhighlightmaterial = preload("res://guimaterials/XCnode_selected.material")
var selectedpointerhighlightmaterial = preload("res://guimaterials/XCnode_selectedhighlight.material")

var pointertarget = null
var pointertargettype = "none"
var pointertargetwall = "none"
var pointertargetpoint = Vector3(0, 0, 0)
var selectedtarget = null
var selectedtargettype = "none"
var selectedtargetwall = null
var gripbuttonpressused = false
var nodeorientationpreviewheldtransform = null
var activetargetwall = null

func clearpointertargetmaterial():
	if pointertargettype == "OnePathNode" or pointertargettype == "DrawnStationNode" or pointertargettype == "StationNode":
		pointertarget.get_node("CollisionShape/MeshInstance").set_surface_material(0, selectedhighlightmaterial if pointertarget == selectedtarget else null)
	if pointertargettype == "XCnode":
		pointertarget.get_node("CollisionShape/MeshInstance").set_surface_material(0, selectedhighlightmaterial if pointertarget == selectedtarget else (preload("res://guimaterials/XCnode_nodepthtest.material") if pointertargetwall == activetargetwall else preload("res://guimaterials/XCnode.material")))
	if pointertargettype == "XCdrawing" or pointertargettype == "XCnode":
		pointertargetwall.get_node("XCdrawingplane/CollisionShape/MeshInstance").set_surface_material(0, preload("res://guimaterials/XCdrawing_active.material") if pointertargetwall == activetargetwall else preload("res://guimaterials/XCdrawing.material"))
		
func setpointertargetmaterial():
	if pointertargettype == "OnePathNode" or pointertargettype == "XCnode" or pointertargettype == "DrawnStationNode" or pointertargettype == "StationNode":
		pointertarget.get_node("CollisionShape/MeshInstance").set_surface_material(0, selectedpointerhighlightmaterial if pointertarget == selectedtarget else pointinghighlightmaterial)
	if pointertargettype == "XCdrawing" or pointertargettype == "XCnode":
		pointertargetwall.get_node("XCdrawingplane/CollisionShape/MeshInstance").set_surface_material(0, preload("res://guimaterials/XCdrawing_highlight.material"))
	
func setselectedtarget(newselectedtarget):
	settextpanel(null, null)
	if selectedtargettype == "OnePathNode" or selectedtargettype == "DrawnStationNode" or selectedtargettype == "StationNode":
		selectedtarget.get_node("CollisionShape/MeshInstance").set_surface_material(0, null)
	if selectedtargettype == "XCnode":
		selectedtarget.get_node("CollisionShape/MeshInstance").set_surface_material(0, preload("res://guimaterials/XCnode_nodepthtest.material") if selectedtargetwall == activetargetwall else preload("res://guimaterials/XCnode.material"))
		
	LaserSpot.material_override = null
	selectedtarget = newselectedtarget
	selectedtargettype = targettype(newselectedtarget)
	selectedtargetwall = targetwall(selectedtarget, selectedtargettype)
	if selectedtarget != pointertarget and (selectedtargettype == "OnePathNode" or selectedtargettype == "XCnode" or selectedtargettype == "DrawnStationNode" or selectedtargettype == "StationNode"):
		selectedtarget.get_node("CollisionShape/MeshInstance").set_surface_material(0, selectedhighlightmaterial)
	setpointertargetmaterial()

func setactivetargetwall(newactivetargetwall):
	if activetargetwall != null:
		activetargetwall.get_node("XCdrawingplane/CollisionShape/MeshInstance").set_surface_material(0, preload("res://guimaterials/XCdrawing.material"))
		activetargetwall.get_node("PathLines").set_surface_material(0, preload("res://guimaterials/XCdrawingPathlines.material"))
		for xcnode in activetargetwall.get_node("XCnodes").get_children():
			xcnode.get_node("CollisionShape/MeshInstance").set_surface_material(0, preload("res://guimaterials/XCnode_selected.material") if xcnode == selectedtarget else preload("res://guimaterials/XCnode.material"))
	activetargetwall = newactivetargetwall
	if activetargetwall != null:
		activetargetwall.get_node("XCdrawingplane/CollisionShape/MeshInstance").set_surface_material(0, preload("res://guimaterials/XCdrawing_active.material"))
		activetargetwall.get_node("PathLines").set_surface_material(0, preload("res://guimaterials/XCdrawingPathlines_nodepthtest.material"))
		for xcnode in activetargetwall.get_node("XCnodes").get_children():
			if xcnode != selectedtarget:
				xcnode.get_node("CollisionShape/MeshInstance").set_surface_material(0, preload("res://guimaterials/XCnode_nodepthtest.material"))

onready var LaserSpot = get_node("LaserSpot") 
onready var LaserSpike = get_node("LaserSpot/LaserSpike") 
onready var LaserSelectLine = get_node("LaserSelectLine") 
onready var LaserShadow = get_node("LaserShadow") 
var laserspothighlightmaterial = null; 

var laser_y = -0.05

onready var ARVRworld_scale = ARVRServer.world_scale

func settextpanel(ltext, pos):
	var textpanel = sketchsystem.get_node("Centreline/TextPanel")
	if ltext != null:
		textpanel.get_node("Viewport/Label").text = ltext
		textpanel.global_transform.origin = pos + Vector3(0, 0.3, 0)
		textpanel.visible = true
	else:
		textpanel.visible = false

func _ready():
	get_parent().connect("button_pressed", self, "_on_button_pressed")
	get_parent().connect("button_release", self, "_on_button_release")
	
	laserspothighlightmaterial = LaserSpot.material_override
	LaserSpot.material_override = null
	
	# apply our world scale to our laser position
	$Laser.translation.y = laser_y * ARVRworld_scale
	
	# init our state
	print("in the pointer onready")
	$Laser.mesh.size.z = distance
	$Laser.translation.z = distance * -0.5
	$Laser/RayCast.translation.z = distance * 0.5
	$Laser/RayCast.cast_to.z = -distance

func targettype(target):
	if not is_instance_valid(target):
		return "none"
	var targetname = target.get_name()
	if targetname == "GUIPanel3D":
		return targetname
	if targetname == "XCtubeshell":    # shell inside an XCtube
		return "XCtube"
	if targetname == "XCdrawingplane": # shell inside an XCdrawing
		var targetparentname = target.get_parent().get_name()
		return "floordrawing" if targetparentname == "floordrawing" else "XCdrawing"
	if targetname == "XCcursor":  # unique wart added to an XCdrawing
		return "XCcursor"
	var targetparent = target.get_parent()
	var targetparentname = targetparent.get_name()
	if  targetparentname == "StationNodes":
		return "StationNode"          # centreline component
	if  targetparentname == "DrawnStationNodes":
		return "DrawnStationNode"     # centreline component
	if targetparentname == "XCnodes":  # containers inside of a drawing
		var targetgrandparentname = targetparent.get_parent().get_name()
		return "OnePathNode"  if targetgrandparentname == "floordrawing"  else "XCnode"
	return "unknown"
		
func targetwall(target, targettype):
	if targettype == "XCdrawing":
		return target.get_parent()
	if targettype == "floordrawing":
		return target.get_parent()
	if targettype == "XCnode" or targettype == "OnePathNode":  # OnePathNode is a node in the floor drawing
		return target.get_parent().get_parent()
	if targettype == "XCtube":
		return target.get_parent()
	if targettype == "XCcursor":
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
			#var selectedtargettype = selectedtarget.get_parent().get_name() if selectedtarget != null else null
			#var pointertargettype = pointertarget.get_parent().get_name() if pointertarget.has_method("set_materialoverride") else pointertarget.get_name()
			print("ppp  ", selectedtargettype, " ", pointertargettype)
			if pointertargettype == "OnePathNode" or pointertargettype == "XCnode" or pointertargettype == "DrawnStationNode" or pointertargettype == "StationNode":
				LaserSpot.visible = false
				LaserShadow.visible = true
			elif pointertargettype == "XCcursor":
				pointertarget.get_node("CollisionShape/MeshInstance/MeshInstance").material_override = pointinghighlightmaterial
				LaserSpot.visible = false
				LaserShadow.visible = true
			elif pointertarget == guipanel3d:
				LaserSpot.visible = false
				LaserShadow.visible = false
			else:
				LaserSpot.visible = true
				LaserShadow.visible = (pointertargettype == "XCdrawing")
				
			# work out the logic for the LaserSelectLine here
			if controller.is_button_pressed(Buttons.VR_GRIP):
				LaserSelectLine.visible = ((pointertargettype == "floordrawing") and ((selectedtargettype == "OnePathNode") or (selectedtargettype == "DrawnStationNode")))
			elif pointertargettype == "floordrawing":
				LaserSelectLine.visible = ((selectedtargettype == "OnePathNode") or (selectedtargettype == "StationNode"))
			elif pointertargettype == "XCdrawing":
				LaserSelectLine.visible = ((selectedtargettype == "XCnode"))
			elif pointertargettype == "XCnode":
				LaserSelectLine.visible = ((selectedtargettype == "XCnode") or (selectedtargettype == "OnePathNode"))
			elif pointertargettype == "OnePathNode":
				LaserSelectLine.visible = ((selectedtargettype == "XCnode") or (selectedtargettype == "OnePathNode"))
			else:
				LaserSelectLine.visible = false
			
		else:
			LaserSpot.visible = false
			LaserShadow.visible = false
			LaserSelectLine.visible = false
			
	pointertargetpoint = newpointertargetpoint
	if is_instance_valid(pointertarget) and pointertarget == guipanel3d:
		guipanel3d.guipanelsendmousemotion(pointertargetpoint, controller.global_transform, controller.is_button_pressed(Buttons.VR_TRIGGER))

	if LaserSpot.visible:
		LaserSpot.global_transform.origin = pointertargetpoint
	if LaserSelectLine.visible:
		if pointertarget != null and selectedtarget != null:
			LaserSelectLine.global_transform.origin = pointertargetpoint
			LaserSelectLine.get_node("Scale").scale.z = LaserSelectLine.global_transform.origin.distance_to(selectedtarget.global_transform.origin)
			LaserSelectLine.global_transform = LaserSpot.global_transform.looking_at(selectedtarget.global_transform.origin, Vector3(0,1,0))
		else:
			LaserSelectLine.visible = false
		
	if LaserShadow.visible:
		LaserShadow.global_transform = Transform(Basis(), Vector3(pointertargetpoint.x, floordrawing.global_transform.origin.y, pointertargetpoint.z))


func _on_button_pressed(p_button):
	var gripbuttonheld = controller.is_button_pressed(Buttons.VR_GRIP)
	print("pppp ", pointertargetpoint, " ", [selectedtargettype, pointertargettype])
	#$SoundPointer.play()
	
	if p_button == Buttons.VR_BUTTON_BY:
		var cameracontrollervec = controller.global_transform.origin - arvrcamera.global_transform.origin
		var ccaxvec = arvrcamera.global_transform.basis.x.dot(controller.global_transform.basis.z)
		var pswitchpos = arvrcamera.global_transform.origin + arvrcamera.global_transform.basis.x*0.15 + arvrcamera.global_transform.basis.y*0.1
		var pswitchdist = controller.global_transform.origin.distance_to(pswitchpos)
		if ccaxvec > 0.85 and pswitchdist < 0.1:
			guipanel3d.clickbuttonheadtorch()
		else:
			guipanel3d.togglevisibility(controller.get_node("pointersystem").global_transform)

	if p_button == Buttons.VR_GRIP:
		gripbuttonpressused = false
			
	if p_button == Buttons.VR_TRIGGER and is_instance_valid(pointertarget):
		print("clclc ", pointertarget, "--", pointertarget.get_name(), "  filename:", pointertarget.get_filename(), " p:", pointertarget.get_parent())
		if gripbuttonheld:
			gripbuttonpressused = true
						
		if pointertarget == guipanel3d:
			pass  #this is processed elsewhere

		elif pointertarget.has_method("jump_up"):
			pointertarget.jump_up()

		elif gripbuttonheld and selectedtargettype == "none" and pointertargettype == "XCdrawing":
			var xccursor = pointertargetwall.get_node("XCcursor")
			if xccursor == null:
				xccursor = XCcursor.instance()
				pointertargetwall.add_child(xccursor)
			xccursor.global_transform.origin = pointertargetpoint
			print("xccursorpos ", xccursor.global_transform.origin, xccursor.translation)

		elif gripbuttonheld and pointertargettype == "XCcursor":
			var sidedot = pointertarget.global_transform.basis.x.dot(pointertargetpoint - pointertarget.global_transform.origin)
			var sfac = 1.5 if sidedot <= 0.0 else 1/1.5
			pointertarget.scale.x *= sfac
			pointertarget.scale.y *= sfac

		elif pointertargettype == "XCcursor":
			var vtarget = pointertargetpoint - pointertarget.global_transform.origin
			var sidedot = 2*pointertarget.global_transform.basis.x.dot(vtarget)/pointertarget.global_transform.basis.x.length_squared()
			var updot = 2*pointertarget.global_transform.basis.y.dot(vtarget)/pointertarget.global_transform.basis.x.length_squared()
			print("XCcursor ", updot, " ", sidedot)
			if abs(updot) < 0.5 and abs(sidedot) > 0.2:
				var sfac = 0.25 if sidedot <= 0.0 else -0.25
				var radx = pointertarget.scale.x/4
				pointertargetwall.distortnodesaroundcursor(radx, sfac, pointertarget.translation, sketchsystem)
			elif abs(updot) > 0.5:
				if updot > 0.0:
					pointertargetwall.makeextrapoints(sketchsystem)
				#else:
				#	pointertargetwall.removeextrapoints(sketchsystem)
	 
		elif pointertarget == nodeorientationpreview:
			nodeorientationpreviewheldtransform = get_parent().global_transform.inverse()

		elif selectedtargettype == "StationNode" and pointertargettype == "floordrawing":
			pointertarget = centrelinesystem.newdrawnstationnode()
			setopnpos(pointertarget, pointertargetpoint)
			pointertarget.stationname = selectedtarget.stationname
			setselectedtarget(null)

		# grip click moves stationnode
		elif gripbuttonheld and selectedtargettype == "DrawnStationNode" and pointertargettype == "floordrawing":
			setopnpos(selectedtarget, pointertargetpoint)

		# grip click moves node on floor
		elif gripbuttonheld and selectedtargettype == "OnePathNode" and pointertargettype == "floordrawing":
			selectedtargetwall.movexcnode(selectedtarget, pointertargetpoint, sketchsystem)

		# grip click moves node on xcwall
		elif gripbuttonheld and selectedtargettype == "XCnode" and pointertargettype == "XCdrawing" and pointertargetwall == selectedtargetwall:
			selectedtargetwall.movexcnode(selectedtarget, pointertargetpoint, sketchsystem)

		# reselection when selected on grip deletes the node		
		elif gripbuttonheld and selectedtargettype == "DrawnStationNode" and pointertarget == selectedtarget:
			var recselectedtarget = selectedtarget
			setselectedtarget(null)
			recselectedtarget.queue_free()
			sketchsystem.get_node("SoundPos2").global_transform.origin = pointertargetpoint
			sketchsystem.get_node("SoundPos2").play()

		# reselection when selected on grip deletes the node		
		elif gripbuttonheld and (selectedtargettype == "OnePathNode" or selectedtargettype == "XCnode") and pointertarget == selectedtarget:
			var recselectedtarget = selectedtarget
			var recselectedtargetwall = selectedtargetwall
			setselectedtarget(null)
			pointertarget = null
			pointertargettype = "none"
			pointertargetwall = null
			recselectedtargetwall.removexcnode(recselectedtarget, false, sketchsystem)
			sketchsystem.get_node("SoundPos2").global_transform.origin = pointertargetpoint
			sketchsystem.get_node("SoundPos2").play()

		# reselection when selected on grip deletes the node		
		elif gripbuttonheld and selectedtargettype == "none" and pointertargettype == "XCnode" and pointertargetwall.get_node("XCcursor") != null:
			pointertargetwall.removexcnode(pointertarget, true, sketchsystem)
			sketchsystem.get_node("SoundPos2").global_transform.origin = pointertargetpoint
			sketchsystem.get_node("SoundPos2").play()

		# duplication of XCdrawing 
		elif gripbuttonheld and selectedtargettype == "OnePathNode" and pointertargettype == "OnePathNode":
			var xcdrawingtocopy = null
			var xcdrawingtocopynodelink = null
			var btargetclear = true
			for xctube in sketchsystem.get_node("XCtubes").get_children():
				if xctube.otxcdIndex1 == -1:
					if xctube.xcdrawinglink.slice(1, len(xctube.xcdrawinglink), 2).has(pointertarget.otIndex):
						btargetclear = false
					for i in range(0, len(xctube.xcdrawinglink), 2):
						#if xctube.xcdrawinglink.slice(1, len(xctube.xcdrawinglink), 2).has(selectedtarget.otIndex):
						if xctube.xcdrawinglink[i+1] == selectedtarget.otIndex:
							xcdrawingtocopy = sketchsystem.get_node("XCdrawings").get_child(xctube.otxcdIndex0)
							xcdrawingtocopynodelink = xctube.xcdrawinglink[i]
							break
			if btargetclear and xcdrawingtocopy != null:
				print("making new copiued drawing¬!!!!")
				var xcdrawing = xcdrawingtocopy.duplicatexcdrawing()
				var vline = pointertargetpoint - selectedtarget.global_transform.origin
				var drawingwallangle = Vector2(vline.z, -vline.x).angle()
				if vline.dot(xcdrawing.global_transform.basis.z) < 0:
					drawingwallangle = Vector2(-vline.z, vline.x).angle()
				xcdrawing.setxcpositionangle(drawingwallangle)
				xcdrawing.setxcpositionorigin(pointertargetpoint)
				sketchsystem.xcapplyonepath(xcdrawing.get_node("XCnodes").get_child(xcdrawingtocopynodelink), pointertarget)
				sketchsystem.xcapplyonepath(xcdrawingtocopy.get_node("XCnodes").get_child(xcdrawingtocopynodelink), xcdrawing.get_node("XCnodes").get_child(xcdrawingtocopynodelink))
				setactivetargetwall(xcdrawing)
			setselectedtarget(pointertarget)
		
		# grip condition is ignored (assumed off) her on
		#elif gripbuttonheld:
		#	pass

		# make new point onto wall, connected if necessary
		elif pointertargettype == "XCdrawing" or pointertargettype == "floordrawing":
			var newpointertarget = pointertargetwall.newxcnode(-1)
			newpointertarget.global_transform.origin = pointertargetpoint
			pointertargetwall.copyxcntootnode(newpointertarget)
			sketchsystem.get_node("SoundPos1").global_transform.origin = pointertargetpoint
			sketchsystem.get_node("SoundPos1").play()
			if (selectedtargettype == "OnePathNode" or selectedtargettype == "XCnode"):
				if selectedtargetwall == pointertargetwall:
					sketchsystem.xcapplyonepath(selectedtarget, newpointertarget)
			setselectedtarget(newpointertarget)
			LaserSpot.material_override = laserspothighlightmaterial		
									
		# reselection clears selection
		elif (selectedtargettype == "StationNode" or selectedtargettype == "DrawnStationNode" or selectedtargettype == "OnePathNode" or selectedtargettype == "XCnode") and pointertarget == selectedtarget:
			setselectedtarget(null)

		# connecting lines between xctype nodes
		elif (selectedtargettype == "OnePathNode") and (pointertargettype == "XCnode"):
			sketchsystem.xcapplyonepath(pointertarget, selectedtarget)   # note reversed case
			setselectedtarget(pointertarget)

		# connecting lines between xctype nodes
		elif (selectedtargettype == "XCnode" or selectedtargettype == "OnePathNode") and (pointertargettype == "XCnode" or pointertargettype == "OnePathNode"):
			sketchsystem.xcapplyonepath(selectedtarget, pointertarget)
			setselectedtarget(pointertarget)
								
		# just select new node (ignoring current selection)
		elif pointertargettype == "StationNode":
			setselectedtarget(pointertarget)
			settextpanel(selectedtarget.stationname, selectedtarget.global_transform.origin)

		elif pointertargettype == "DrawnStationNode":
			setselectedtarget(pointertarget)
			settextpanel(selectedtarget.stationname, centrelinesystem.stationnodemap[selectedtarget.stationname].global_transform.origin)
				
		elif pointertargettype == "OnePathNode":
			setselectedtarget(pointertarget)

		elif pointertargettype == "XCnode":
			pointertargetwall.get_node("XCdrawingplane").visible = true
			pointertargetwall.get_node("XCdrawingplane/CollisionShape").disabled = false
			setactivetargetwall(pointertargetwall)
			setselectedtarget(pointertarget)

				
	# change height of pointer target
	if p_button == Buttons.VR_PAD:
		var left_right = controller.get_joystick_axis(0)
		var up_down = controller.get_joystick_axis(1)
		if abs(up_down) < 0.5 and abs(left_right) > 0.1 and is_instance_valid(pointertarget):
			var dy = (1 if left_right > 0 else -1)*(1.0 if abs(left_right) < 0.8 else 0.1)
			#if pointertargettype == "OnePathNodes":
			#	pointertarget.global_transform.origin.y = max(0.1, pointertarget.global_transform.origin.y + dy)
			#	pointertarget.scale.y = pointertarget.global_transform.origin.y
			#	sketchsystem.ot.copyopntootnode(pointertarget)
			#	nodeorientationpreview.global_transform.origin = pointertarget.global_transform.origin

			if pointertargettype == "XCdrawing":
				pointertarget.scale.y = max(0.1, pointertarget.scale.y + dy)
				pointertarget.scale.x = max(0.1, pointertarget.scale.x + dy)
				
			# raise the whole drawn floor case!
			if pointertargettype == "DrawnStationNode":
				floordrawing.global_transform.origin.y = floordrawing.global_transform.origin.y + dy
				centrelinesystem.get_node("DrawnStationNodes").global_transform.origin.y = floordrawing.global_transform.origin.y
			

func _on_button_release(p_button):
	# cancel selection by squeezing and then releasing grip without doing anything in between
	if p_button == Buttons.VR_GRIP and not gripbuttonpressused:
		if pointertargettype == "GUIPanel3D":
			if guipanel3d.visible:
				guipanel3d.togglevisibility(controller.get_node("pointersystem").global_transform)

		elif pointertargettype == "XCdrawing":
			clearpointertargetmaterial()
			pointertarget.visible = false
			pointertarget.get_node("CollisionShape").disabled = true
			setactivetargetwall(null)
			pointertarget = null
			pointertargettype = "none"
			pointertargetwall = null

		elif pointertargettype == "XCcursor":
			pointertarget.queue_free()
			pointertarget = null

		elif selectedtargettype == "OnePathNode" or selectedtargettype == "XCnode" or selectedtargettype == "DrawnStationNode" or selectedtargettype == "StationNode":
			setselectedtarget(null)
			
		elif pointertargettype == "XCtube":
			pointertarget.get_parent().togglematerialcycle()
		
	elif p_button == Buttons.VR_TRIGGER and (nodeorientationpreviewheldtransform != null):
		print("dosomethingwith nodeorientationpreview ", nodeorientationpreviewheldtransform)
		nodeorientationpreviewheldtransform = null

	# new drawing wall position made
	elif p_button == Buttons.VR_TRIGGER and pointertargettype == "OnePathNode" and selectedtargettype == "OnePathNode" and pointertarget != selectedtarget:
		print("makingxcplane")
		var xcdrawing = XCdrawing.instance()
		var otxcdIndex = sketchsystem.get_node("XCdrawings").get_child_count()
		xcdrawing.set_name("XCdrawing"+String(otxcdIndex))
		xcdrawing.otxcdIndex = otxcdIndex   # could use the name in the list to avoid the index number
		sketchsystem.get_node("XCdrawings").add_child(xcdrawing)
		var vx = pointertarget.global_transform.origin - selectedtarget.global_transform.origin
		xcdrawing.setxcpositionangle(Vector2(vx.x, vx.z).angle())
		var vwallmid = (pointertarget.global_transform.origin + selectedtarget.global_transform.origin)/2
		xcdrawing.setxcpositionorigin(vwallmid)
		setactivetargetwall(xcdrawing)
						
func _process(_delta):
	if !is_inside_tree():
		return
	if nodeorientationpreviewheldtransform != null:
		var oiv = Vector3(0,1,0)   # direction of orientation preview we are dragging from
		var iv = get_parent().global_transform.basis.xform(nodeorientationpreviewheldtransform.basis.xform(oiv))
		var iv0 = iv.cross(Vector3(0, 0, 1)).normalized()
		if iv0.length_squared() == 0:
			iv0 = iv.cross(Vector3(1, 0, 0))
		var iv1 = iv0.cross(iv)
		# here could add the 3D push pull motions too
		nodeorientationpreview.global_transform = Transform(Basis(iv0, iv, iv1), sketchsystem.ot.nodepoints[selectedtarget.otIndex])
	elif $Laser/RayCast.is_colliding():
		onpointing($Laser/RayCast.get_collider(), $Laser/RayCast.get_collision_point())
	else:
		onpointing(null, null)
	


