extends Node

onready var sketchsystem = get_node("/root/Spatial/SketchSystem")
onready var centrelinesystem = sketchsystem.get_node("Centreline")
onready var nodeorientationpreview = sketchsystem.get_node("NodeOrientationPreview")
onready var floordrawing = sketchsystem.get_node("floordrawing")

#onready var arvrorigin = get_node("../..")
#onready var controller = get_parent()
#onready var arvrcamera = arvrorigin.get_node("HeadCam")
#onready var guipanel3d = arvrorigin.get_node("GUIPanel3D")

onready var playernode = get_parent()
onready var headcam = playernode.get_node('HeadCam')
onready var handleft = playernode.get_node("HandLeft")
onready var handright = playernode.get_node("HandRight")
onready var guipanel3d = playernode.get_node("GUIPanel3D")

onready var Laser = handright.get_node("LaserOrient/Length/Laser") 
onready var LaserRayCast = handright.get_node("LaserOrient/RayCast") 
onready var LaserSpot = handright.get_node("LaserOrient/LaserSpot") 
onready var LaserShadow = handright.get_node("LaserShadow") 
onready var LaserSelectLine = handright.get_node("LaserSelectLine") 

var viewport_point = null

enum Buttons { VR_TRIGGER = 15, VR_PAD=14, VR_BUTTON_BY=1, VR_GRIP=2 }
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
var nodeorientationpreviewheldtransform = null
var activetargetwall = null

var xcdrawingactivematerial = preload("res://guimaterials/XCdrawing_active.material")
var xcdrawingmaterial = preload("res://guimaterials/XCdrawing.material")
var xcdrawinghighlightmaterial = preload("res://guimaterials/XCdrawing_highlight.material")

func clearpointertargetmaterial():
	if pointertargettype == "OnePathNode" or pointertargettype == "DrawnStationNode" or pointertargettype == "StationNode":
		pointertarget.get_node("CollisionShape/MeshInstance").set_surface_material(0, selectedhighlightmaterial if pointertarget == selectedtarget else null)
	if pointertargettype == "XCnode":
		pointertarget.get_node("CollisionShape/MeshInstance").set_surface_material(0, selectedhighlightmaterial if pointertarget == selectedtarget else (preload("res://guimaterials/XCnode_nodepthtest.material") if pointertargetwall == activetargetwall else preload("res://guimaterials/XCnode.material")))
	if pointertargettype == "XCdrawing" or pointertargettype == "XCnode":
		if pointertargetwall == activetargetwall:
			xcdrawingactivematerial.uv1_scale = pointertargetwall.get_node("XCdrawingplane").get_scale()
			xcdrawingactivematerial.uv1_offset = -xcdrawingactivematerial.uv1_scale/2
		pointertargetwall.get_node("XCdrawingplane/CollisionShape/MeshInstance").set_surface_material(0, xcdrawingactivematerial if pointertargetwall == activetargetwall else xcdrawingmaterial)
	handright.get_node("csghandright").setpartcolor(2, "#FFFFFF")
			
func setpointertargetmaterial():
	if pointertargettype == "OnePathNode" or pointertargettype == "XCnode" or pointertargettype == "DrawnStationNode" or pointertargettype == "StationNode":
		pointertarget.get_node("CollisionShape/MeshInstance").set_surface_material(0, selectedpointerhighlightmaterial if pointertarget == selectedtarget else pointinghighlightmaterial)
		handright.get_node("csghandright").setpartcolor(2, "#FFFF60")
	if pointertargettype == "XCdrawing" or pointertargettype == "XCnode":
		xcdrawinghighlightmaterial.uv1_scale = pointertargetwall.get_node("XCdrawingplane").get_scale()
		xcdrawinghighlightmaterial.uv1_offset = -xcdrawinghighlightmaterial.uv1_scale/2
		pointertargetwall.get_node("XCdrawingplane/CollisionShape/MeshInstance").set_surface_material(0, xcdrawinghighlightmaterial)
		handright.get_node("csghandright").setpartcolor(2, "#FFFF60")
	
func setselectedtarget(newselectedtarget):
	settextpanel(null, null)
	if selectedtargettype == "OnePathNode" or selectedtargettype == "DrawnStationNode" or selectedtargettype == "StationNode":
		selectedtarget.get_node("CollisionShape/MeshInstance").set_surface_material(0, null)
	if selectedtargettype == "XCnode":
		selectedtarget.get_node("CollisionShape/MeshInstance").set_surface_material(0, preload("res://guimaterials/XCnode_nodepthtest.material") if selectedtargetwall == activetargetwall else preload("res://guimaterials/XCnode.material"))
		
	selectedtarget = newselectedtarget
	selectedtargettype = targettype(newselectedtarget)
	selectedtargetwall = targetwall(selectedtarget, selectedtargettype)
	if selectedtarget != pointertarget and (selectedtargettype == "OnePathNode" or selectedtargettype == "XCnode" or selectedtargettype == "DrawnStationNode" or selectedtargettype == "StationNode"):
		selectedtarget.get_node("CollisionShape/MeshInstance").set_surface_material(0, selectedhighlightmaterial)
	LaserSpot.material_override = preload("res://guimaterials/laserspot_selected.material") if selectedtarget != null else null
	setpointertargetmaterial()

func setactivetargetwall(newactivetargetwall):
	if activetargetwall != null:
		activetargetwall.get_node("XCdrawingplane/CollisionShape/MeshInstance").set_surface_material(0, preload("res://guimaterials/XCdrawing.material"))
		activetargetwall.get_node("PathLines").set_surface_material(0, preload("res://guimaterials/XCdrawingPathlines.material"))
		for xcnode in activetargetwall.get_node("XCnodes").get_children():
			xcnode.get_node("CollisionShape/MeshInstance").set_surface_material(0, preload("res://guimaterials/XCnode_selected.material") if xcnode == selectedtarget else preload("res://guimaterials/XCnode.material"))
		if not activetargetwall.floortype:
			for xctube in activetargetwall.xctubesconn:
				if xctube.otxcdIndex1 != -1:
					xctube.updatetubeshell(sketchsystem.get_node("floordrawing"), sketchsystem.tubeshellsvisible)
	
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

func _ready():
	handright.connect("button_pressed", self, "_on_button_pressed")
	handright.connect("button_release", self, "_on_button_release")
	#Laser.translation.y = laser_y * ARVRworld_scale
	
	# init our state
	print("in the pointer onready")
	#Laser.mesh.size.z = distance
	#Laser.translation.z = distance * -0.5
	#LaserRayCast.translation.z = distance * 0.5
	#LaserRayCast.cast_to.z = -distance

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
			elif pointertarget == guipanel3d:
				LaserSpot.visible = false
				LaserShadow.visible = false
			else:
				LaserSpot.visible = true
				LaserShadow.visible = (pointertargettype == "XCdrawing")
				
			# work out the logic for the LaserSelectLine here
			if handright.is_button_pressed(Buttons.VR_GRIP):
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
		guipanel3d.guipanelsendmousemotion(pointertargetpoint, handright.global_transform, handright.is_button_pressed(Buttons.VR_TRIGGER))

	if pointertargetpoint != null:
		LaserSpot.global_transform.origin = pointertargetpoint
		LaserSpot.get_node("../Length").scale.z = -LaserSpot.translation.z
	else:
		LaserSpot.get_node("../Length").scale.z = -LaserRayCast.cast_to.z
		
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
			
	if p_button == Buttons.VR_TRIGGER and is_instance_valid(pointertarget):
		print("clclc ", pointertarget, "--", pointertarget.get_name(), "  filename:", pointertarget.get_filename(), " p:", pointertarget.get_parent())
		if gripbuttonheld:
			gripbuttonpressused = true
						
		if pointertarget == guipanel3d:
			pass  #this is processed elsewhere

		elif pointertarget.has_method("jump_up"):
			pointertarget.jump_up()
	 
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

		# duplication of XCdrawing (in special cases)
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
				var xcdrawing = xcdrawingtocopy.duplicatexcdrawing(sketchsystem)
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
		
		# new XCintersecting in tube case
		elif gripbuttonheld and selectedtargettype == "XCnode" and pointertargettype == "XCtube" and (selectedtargetwall.otxcdIndex == pointertargetwall.otxcdIndex0 or selectedtargetwall.otxcdIndex == pointertargetwall.otxcdIndex1):
			var xcdrawing0 = sketchsystem.get_node("XCdrawings").get_child(pointertargetwall.otxcdIndex0)
			var xcdrawing1 = sketchsystem.get_node("XCdrawings").get_child(pointertargetwall.otxcdIndex1)
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
				var xcdrawing = XCdrawing.instance()
				var otxcdIndex = sketchsystem.get_node("XCdrawings").get_child_count()
				xcdrawing.set_name("XCdrawing"+String(otxcdIndex))
				xcdrawing.otxcdIndex = otxcdIndex   # could use the name in the list to avoid the index number
				sketchsystem.get_node("XCdrawings").add_child(xcdrawing)
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

				var xctube0 = preload("res://nodescenes/XCtube.tscn").instance()
				xctube0.get_node("XCtubeshell/CollisionShape").shape = ConcavePolygonShape.new()   # bug.  this fails to get cloned
				xctube0.otxcdIndex0 = pointertargetwall.otxcdIndex0
				xctube0.otxcdIndex1 = xcdrawing.otxcdIndex
				xcdrawing0.xctubesconn.append(xctube0)
				xcdrawing.xctubesconn.append(xctube0)
				xctube0.set_name("XCtube0"+String(xctube0.otxcdIndex0)+"_"+String(xctube0.otxcdIndex1))
				sketchsystem.get_node("XCtubes").add_child(xctube0)
				xctube0.xcdrawinglink = xcdrawinglink0
				xctube0.updatetubelinkpaths(sketchsystem.get_node("XCdrawings"), sketchsystem)
				xctube0.updatetubeshell(sketchsystem.get_node("floordrawing"), sketchsystem.tubeshellsvisible)
				
				var xctube1 = preload("res://nodescenes/XCtube.tscn").instance()
				xctube1.get_node("XCtubeshell/CollisionShape").shape = ConcavePolygonShape.new()   # bug.  this fails to get cloned
				xctube1.otxcdIndex0 = pointertargetwall.otxcdIndex1
				xctube1.otxcdIndex1 = xcdrawing.otxcdIndex  # keep order
				xcdrawing1.xctubesconn.append(xctube1)
				xcdrawing.xctubesconn.append(xctube1)
				xctube1.set_name("XCtube0"+String(xctube1.otxcdIndex0)+"_"+String(xctube1.otxcdIndex1))
				sketchsystem.get_node("XCtubes").add_child(xctube1)
				xctube1.xcdrawinglink = xcdrawinglink1
				xctube1.updatetubelinkpaths(sketchsystem.get_node("XCdrawings"), sketchsystem)
				xctube1.updatetubeshell(sketchsystem.get_node("floordrawing"), sketchsystem.tubeshellsvisible)


				pointertargettype = "none"
				pointertarget = null
				pointertargetwall.queue_free()
				pointertargetwall = null
				
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
			#if pointertargettype == "OnePathNodes":
			#	pointertarget.global_transform.origin.y = max(0.1, pointertarget.global_transform.origin.y + dy)
			#	pointertarget.scale.y = pointertarget.global_transform.origin.y
			#	sketchsystem.ot.copyopntootnode(pointertarget)
			#	nodeorientationpreview.global_transform.origin = pointertarget.global_transform.origin

			if pointertargettype == "XCdrawing":
				pointertargetwall.get_node("XCdrawingplane").scale.x = max(1, pointertargetwall.get_node("XCdrawingplane").scale.x + dy)
				pointertargetwall.get_node("XCdrawingplane").scale.y = max(1, pointertargetwall.get_node("XCdrawingplane").scale.y + dy)
				xcdrawinghighlightmaterial.uv1_scale = pointertargetwall.get_node("XCdrawingplane").get_scale()
				xcdrawinghighlightmaterial.uv1_offset = -xcdrawinghighlightmaterial.uv1_scale/2
				
			# raise the whole drawn floor case!
			if pointertargettype == "DrawnStationNode":
				floordrawing.global_transform.origin.y = floordrawing.global_transform.origin.y + dy
				centrelinesystem.get_node("DrawnStationNodes").global_transform.origin.y = floordrawing.global_transform.origin.y
			
func _on_button_release(p_button):
	# cancel selection by squeezing and then releasing grip without doing anything in between
	if p_button == Buttons.VR_GRIP and not gripbuttonpressused:
		if pointertargettype == "GUIPanel3D":
			if guipanel3d.visible:
				guipanel3d.togglevisibility(handright.get_node("LaserOrient").global_transform)

		elif pointertargettype == "XCdrawing":
			clearpointertargetmaterial()
			pointertargetwall.setxcdrawingvisibility(false)
			setactivetargetwall(null)
			pointertarget = null
			pointertargettype = "none"
			pointertargetwall = null

		elif selectedtargettype == "OnePathNode" or selectedtargettype == "XCnode" or selectedtargettype == "DrawnStationNode" or selectedtargettype == "StationNode":
			setselectedtarget(null)
			
		elif pointertargettype == "XCtube":
			pointertargetwall.togglematerialcycle()
		
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
		setselectedtarget(null)
		setactivetargetwall(xcdrawing)
		
						
func _physics_process(_delta):
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
	elif LaserRayCast.is_colliding():
		onpointing(LaserRayCast.get_collider(), LaserRayCast.get_collision_point())
	else:
		onpointing(null, null)
	


