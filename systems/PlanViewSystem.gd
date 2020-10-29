extends Spatial

var planviewactive = false
var drawingtype = DRAWING_TYPE.DT_PLANVIEW
onready var ImageSystem = get_node("/root/Spatial/ImageSystem")
var activetargetfloor = null
var activetargetfloortransformpos = null
var activetargetfloorimgtrim = null

var buttonidxtoitem = { }
onready var tree = $PlanView/Viewport/PlanGUI/PlanViewControls/Tree
onready var planviewcontrols = $PlanView/Viewport/PlanGUI/PlanViewControls
var imgregex = RegEx.new()
var listregex = RegEx.new()

var installbuttontex = null
var fetchbuttontex = null

func getactivetargetfloorViz(newactivetargetfloorname: String):
	var xcviz = { "prevxcvizstates":{ }, "xcvizstates":{ } }
	if activetargetfloor != null and newactivetargetfloorname != activetargetfloor.get_name():
		xcviz["prevxcvizstates"][activetargetfloor.get_name()] = DRAWING_TYPE.VIZ_XCD_FLOOR_ACTIVE
		xcviz["xcvizstates"][activetargetfloor.get_name()] = DRAWING_TYPE.VIZ_XCD_FLOOR_NORMAL
	if newactivetargetfloorname != "":
		if activetargetfloor != null and newactivetargetfloorname == activetargetfloor.get_name():
			xcviz["prevxcvizstates"][newactivetargetfloorname] = DRAWING_TYPE.VIZ_XCD_FLOOR_ACTIVE
		else:
			xcviz["prevxcvizstates"][newactivetargetfloorname] = DRAWING_TYPE.VIZ_XCD_FLOOR_NORMAL
		xcviz["xcvizstates"][newactivetargetfloorname] = DRAWING_TYPE.VIZ_XCD_FLOOR_ACTIVE
	return xcviz

func defaultimgtrim():
	return { "imgwidth":20, 
			 "imgtrimleftdown":Vector2(-10, -10),
			 "imgtrimrightup":Vector2(10, 10) }

func fetchbuttonpressed(item, column, idx):
	var sketchsystem = get_node("/root/Spatial/SketchSystem")
	print("iii ", item, " ", column, "  ", idx)
	if item == null:
		print("fetchbuttonpressed item is null problem")
		item = buttonidxtoitem.get(idx)
	var url = item.get_tooltip(0)
	var name = item.get_text(0)
	print("url to fetch: ", url)
	if imgregex.search(name):
		var pt0 = $RealPlanCamera.global_transform.origin - Vector3(0,100,0)
		for xcdrawing in sketchsystem.get_node("XCdrawings").get_children():
			if xcdrawing.drawingtype == DRAWING_TYPE.DT_FLOORTEXTURE:
				var floory = xcdrawing.global_transform.origin.y
				if pt0.y <= floory:
					pt0.y = floory + 0.1
					
		var sname = sketchsystem.uniqueXCdrawingPapername(url)
		activetargetfloorimgtrim = { "name":sname, 
									 "drawingtype":DRAWING_TYPE.DT_FLOORTEXTURE,
									 "xcresource":url,
									 "imgtrim":defaultimgtrim(),
									 "transformpos":Transform(Vector3(1,0,0), Vector3(0,0,-1), Vector3(0,1,0), pt0)
								   }
		var floorviz = getactivetargetfloorViz(sname)
		sketchsystem.actsketchchange([activetargetfloorimgtrim, floorviz])
		
	else:
		item.set_button_disabled(column, idx, true)
		#item.erase_button(column, idx)
		#buttonidxtoitem.erase(idx)
		item.set_custom_bg_color(0, Color("#ff0099"))
		ImageSystem.fetchunrolltree(tree, item, item.get_tooltip(0))

func addsubitem(upperitem, name, url):
	var item = tree.create_item(upperitem)
	item.set_text(0, name)
	item.set_tooltip(0, url)
	var tex = null
	if imgregex.search(name):
		tex = installbuttontex.duplicate()
	elif url.ends_with("/"):
		tex = fetchbuttontex.duplicate()
	else:
		print("unknown file ignored: ", name)
		return
	#var idx = item.get_button_count(0)
	var idx = len(buttonidxtoitem)
	item.add_button(0, tex, idx)
	buttonidxtoitem[idx] = item

func openlinklistpage(item, htmltext):
	item.clear_custom_bg_color(0)
	var dirurl = item.get_tooltip(0)
	if not dirurl.ends_with("/"):
		dirurl += "/"
	for m in listregex.search_all(htmltext):
		var lk = m.get_string(1)
		if not lk.begins_with("."):
			lk = lk.replace("&amp;", "&")
			addsubitem(item, lk, dirurl + lk)

func transferintorealviewport(setascurrentcamera):
	if setascurrentcamera:
		$PlanView/Viewport/PlanGUI/Camera.current = true
		$PlanView/Viewport/PlanGUI.remove_child(planviewcontrols)
		get_node("/root/Spatial").add_child(planviewcontrols)
		planviewcontrols.rect_position.y = 0

	elif $PlanView.has_node("ViewportReal"):
		var fplangui = $PlanView/Viewport/PlanGUI
		$PlanView/Viewport.remove_child(fplangui)
		$PlanView/ViewportReal.add_child(fplangui)
		$PlanView/Viewport.set_name("ViewportFake")
		$PlanView/ViewportReal.set_name("Viewport")
		$PlanView/ProjectionScreen.get_surface_material(0).albedo_texture = $PlanView/Viewport.get_texture()
		
func _ready():
	listregex.compile('<li><a href="([^"]*)">')
	imgregex.compile('(?i)\\.(png|jpg|jpeg)$')
	installbuttontex = get_node("/root/Spatial/MaterialSystem/buttonmaterials/InstallButton").get_surface_material(0).albedo_texture
	fetchbuttontex = get_node("/root/Spatial/MaterialSystem/buttonmaterials/FetchButton").get_surface_material(0).albedo_texture
	$RealPlanCamera.set_as_toplevel(true)
	planviewcontrols.get_node("ZoomView/ButtonCentre").connect("pressed", self, "buttoncentre_pressed")
	call_deferred("readydeferred")
	set_process(visible)
		
func readydeferred():
	tree.connect("button_pressed", self, "fetchbuttonpressed")
	var root = tree.create_item()
	root.set_text(0, "Root of treee")
	#addsubitem(root, "Ireby", "http://cave-registry.org.uk/svn/NorthernEngland/ThreeCountiesArea/rawscans/Ireby/")
	addsubitem(root, "rawscans", "http://cave-registry.org.uk/svn/NorthernEngland/ThreeCountiesArea/rawscans/")
	
func toggleplanviewactive():
	planviewactive = not planviewactive
	if planviewactive:
		$PlanView/ProjectionScreen/ImageFrame.mesh.surface_get_material(0).emission_enabled = true
		set_process(true)
	else:
		$PlanView/ProjectionScreen/ImageFrame.mesh.surface_get_material(0).emission_enabled = false
		set_process(false)
		if activetargetfloor != null:
			var sketchsystem = get_node("/root/Spatial/SketchSystem")
			sketchsystem.actsketchchange([getactivetargetfloorViz("")])

func setplanviewvisible(planviewvisible, guidpaneltransform, guidpanelsize):
	var sketchsystem = get_node("/root/Spatial/SketchSystem")
	if planviewvisible:
		var paneltrans = $PlanView.global_transform
		paneltrans.origin = guidpaneltransform.origin + guidpaneltransform.basis.y*(guidpanelsize.y/2) + Vector3(0,$PlanView/ProjectionScreen/ImageFrame.mesh.size.y/2,0)
		var eyepos = get_node("/root/Spatial").playerMe.get_node("HeadCam").global_transform.origin
		paneltrans = paneltrans.looking_at(eyepos + 2*(paneltrans.origin-eyepos), Vector3(0, 1, 0))
		sketchsystem.actsketchchange([{ "planview":{ "transformpos":paneltrans, "visible":true } } ])
	else:
		sketchsystem.actsketchchange([{"planview": { "visible":false}} ])

var slowviewportframeratecountdown = 1
func _process(delta):
	if Tglobal.arvrinterfacename == "OVRMobile":
		slowviewportframeratecountdown -= delta
		if slowviewportframeratecountdown < 0:
			slowviewportframeratecountdown = 1
			$PlanView/Viewport.render_target_update_mode = Viewport.UPDATE_ONCE
	
	var viewslide = planviewcontrols.get_node("ViewSlide")
	var joypos = Vector2((-1 if viewslide.get_node("ButtonSlideLeft").is_pressed() else 0) + (1 if viewslide.get_node("ButtonSlideRight").is_pressed() else 0), 
						 (-1 if viewslide.get_node("ButtonSlideDown").is_pressed() else 0) + (1 if viewslide.get_node("ButtonSlideUp").is_pressed() else 0))

	var planviewpositiondict = { }
	if joypos != Vector2(0, 0):
		var plancamera = $PlanView/Viewport/PlanGUI/Camera
		planviewpositiondict["plancamerapos"] = plancamera.translation + Vector3(joypos.x, 0, -joypos.y)*plancamera.size/2*delta
	var zoomview = planviewcontrols.get_node("ZoomView")
	var bzoomin = zoomview.get_node("ButtonZoomIn").is_pressed()
	var bzoomout = zoomview.get_node("ButtonZoomOut").is_pressed()
	if bzoomin or bzoomout:
		var zoomfac = 1/(1 + 0.5*delta) if bzoomin else 1 + 0.5*delta
		var plancamera = $PlanView/Viewport/PlanGUI/Camera
		planviewpositiondict["plancamerasize"] = plancamera.size * zoomfac
	if not planviewpositiondict.empty():
		var sketchsystem = get_node("/root/Spatial/SketchSystem")
		sketchsystem.actsketchchange([{"planview":planviewpositiondict}])

	if activetargetfloor != null:
		var floortrim = planviewcontrols.get_node("FloorTrim")
		var joypostrimld = Vector2((-1 if floortrim.get_node("ButtonTrimLeftLeft").is_pressed() else 0) + (1 if floortrim.get_node("ButtonTrimLeftRight").is_pressed() else 0), 
								   (-1 if floortrim.get_node("ButtonTrimDownDown").is_pressed() else 0) + (1 if floortrim.get_node("ButtonTrimDownUp").is_pressed() else 0))
		var joypostrimru = Vector2((-1 if floortrim.get_node("ButtonTrimRightLeft").is_pressed() else 0) + (1 if floortrim.get_node("ButtonTrimRightRight").is_pressed() else 0), 
								   (-1 if floortrim.get_node("ButtonTrimUpDown").is_pressed() else 0) + (1 if floortrim.get_node("ButtonTrimUpUp").is_pressed() else 0))
		var floormove = planviewcontrols.get_node("FloorMove")
		var joyposmove = Vector3((-1 if floormove.get_node("ButtonMoveLeft").is_pressed() else 0) + (1 if floormove.get_node("ButtonMoveRight").is_pressed() else 0), 
								 (-1 if floormove.get_node("ButtonMoveDown").is_pressed() else 0) + (1 if floormove.get_node("ButtonMoveUp").is_pressed() else 0), 
								 (-0.5 if floormove.get_node("ButtonMoveFall").is_pressed() else 0) + (0.5 if floormove.get_node("ButtonMoveRise").is_pressed() else 0))
		var joygrow = (-1 if floormove.get_node("ButtonShrink").is_pressed() else 0) + (1 if floormove.get_node("ButtonGrow").is_pressed() else 0)
		if len(activetargetfloor.nodepoints) != 0:
			joyposmove.x = 0
			joyposmove.y = 0
			joygrow = 0
		if joypostrimld != Vector2(0,0) or joypostrimru != Vector2(0,0) or joyposmove != Vector3(0,0,0) or joygrow != 0:
			var txcdata = { "name":activetargetfloor.get_name(), 
							"rpcoptional":1,
							"timestamp":OS.get_ticks_msec()*0.001 }
			var d = activetargetfloor
			var drawingplane = d.get_node("XCdrawingplane")
			var sfac = delta*8
			if joyposmove != Vector3(0,0,0):
				txcdata["prevtransformpos"] = d.transform
				txcdata["transformpos"] = Transform(d.transform.basis, d.transform.origin + d.transform.basis*joyposmove*delta*8)

			if joypostrimld != Vector2(0,0) or joypostrimru != Vector2(0,0) or joygrow != 0:
				txcdata["previmgtrim"] = { "imgwidth":d.imgwidth, "imgtrimleftdown":d.imgtrimleftdown, "imgtrimrightup":d.imgtrimrightup }
				var gfac = 1 + joygrow*delta*0.2
				var imgtrim = { "imgwidth":d.imgwidth*gfac, "imgtrimleftdown":d.imgtrimleftdown*gfac, "imgtrimrightup":d.imgtrimrightup*gfac }
				txcdata["imgtrim"] = imgtrim
				var imgheight = imgtrim["imgwidth"]*d.imgheightwidthratio
				imgtrim["imgtrimleftdown"] = Vector2(clamp(imgtrim["imgtrimleftdown"].x + joypostrimld.x*sfac, -imgtrim["imgwidth"]*0.5, imgtrim["imgtrimrightup"].x-0.1), 
													 clamp(imgtrim["imgtrimleftdown"].y + joypostrimld.y*sfac, -imgheight*0.5, imgtrim["imgtrimrightup"].y-0.1))
				imgtrim["imgtrimrightup"] = Vector2(clamp(imgtrim["imgtrimrightup"].x + joypostrimru.x*sfac, imgtrim["imgtrimleftdown"].x+0.1, imgtrim["imgwidth"]*0.5), 
													clamp(imgtrim["imgtrimrightup"].y + joypostrimru.y*sfac, imgtrim["imgtrimleftdown"].y+0.1, imgheight*0.5))
			var sketchsystem = get_node("/root/Spatial/SketchSystem")
			sketchsystem.actsketchchange([txcdata])
	
func buttoncentre_pressed():
	var headcam = get_node("/root/Spatial").playerMe.get_node("HeadCam")
	var planviewpositiondict = { "plancamerapos":Vector3(headcam.global_transform.origin.x, $PlanView/Viewport/PlanGUI/Camera.translation.y, headcam.global_transform.origin.z) }
	var sketchsystem = get_node("/root/Spatial/SketchSystem")		
	sketchsystem.actsketchchange([{"planview":planviewpositiondict}])

func checkplanviewinfront(handrightcontroller):
	var planviewsystem = self
	var collider_transform = planviewsystem.get_node("PlanView").global_transform
	return collider_transform.xform_inv(handrightcontroller.global_transform.origin).z > 0

var viewport_mousedown = false
var viewport_point = Vector2(0,0)
func processplanviewpointing(raycastcollisionpoint, controller_trigger):
	var planviewsystem = self
	var plancamera = planviewsystem.get_node("PlanView/Viewport/PlanGUI/Camera")
	var collider_transform = planviewsystem.get_node("PlanView").global_transform
	var shape_size = planviewsystem.get_node("PlanView/CollisionShape").shape.extents * 2
	var collider_scale = collider_transform.basis.get_scale()
	var local_point = collider_transform.xform_inv(raycastcollisionpoint)
	local_point /= (collider_scale * collider_scale)
	local_point /= shape_size
	local_point += Vector3(0.5, -0.5, 0) # X is about 0 to 1, Y is about 0 to -1.
	viewport_point = Vector2(local_point.x, -local_point.y) * $PlanView/Viewport.size

	var rectrel = viewport_point - planviewcontrols.rect_position
	var inguipanel = (rectrel.x > 0 and rectrel.y > 0 and rectrel.x < planviewcontrols.rect_size.x and rectrel.y < planviewcontrols.rect_size.y)
	if inguipanel:
		var event = InputEventMouseMotion.new()
		event.position = viewport_point
		$PlanView/Viewport.input(event)
		if controller_trigger != viewport_mousedown:
			viewport_mousedown = controller_trigger
			event = InputEventMouseButton.new()
			event.pressed = viewport_mousedown
			event.button_index = BUTTON_LEFT
			event.position = viewport_point
			$PlanView/Viewport.input(event)
	else:
		if viewport_mousedown:
			planviewguipanelreleasemouse()
		var laspt = plancamera.project_position(viewport_point, 0)
		planviewsystem.get_node("RealPlanCamera/LaserScope").global_transform.origin = laspt
		planviewsystem.get_node("RealPlanCamera/LaserScope").visible = true
		planviewsystem.get_node("RealPlanCamera/LaserScope/LaserOrient/RayCast").force_raycast_update()
	return inguipanel
	
func planviewguipanelreleasemouse():
	assert (viewport_mousedown)
	var event = InputEventMouseButton.new()
	event.button_index = 1
	event.position = viewport_point
	$PlanView/Viewport.input(event)
	viewport_mousedown = false

func updatecentrelinesizes():
	var sca = 1
	if Tglobal.centrelineonly:
		sca = $PlanView/Viewport/PlanGUI/Camera.size/70.0*2.5
	for xcdrawing in get_tree().get_nodes_in_group("gpcentrelinegeo"):
		for xcn in xcdrawing.get_node("XCnodes").get_children():
			xcn.get_node("StationLabel").get_surface_material(0).set_shader_param("vertex_scale", sca)
			xcn.get_node("CollisionShape").scale = Vector3(sca*2, sca*2, sca*2)
		xcdrawing.linewidth = 0.035*sca
		xcdrawing.updatexcpaths()



