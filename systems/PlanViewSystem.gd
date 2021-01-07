extends Spatial

var planviewactive = false
var drawingtype = DRAWING_TYPE.DT_PLANVIEW
onready var ImageSystem = get_node("/root/Spatial/ImageSystem")
onready var sketchsystem = get_node("/root/Spatial/SketchSystem")
var activetargetfloor = null
var activetargetfloortransformpos = null
var activetargetfloorimgtrim = null

var buttonidxtoitem = { }
onready var fileviewtree = $PlanView/Viewport/PlanGUI/PlanViewControls/FileviewTree
onready var planviewcontrols = $PlanView/Viewport/PlanGUI/PlanViewControls
var imgregex = RegEx.new()
var listregex = RegEx.new()

var installbuttontex = null
var fetchbuttontex = null
var clearcachebuttontex = null

func getactivetargetfloorViz(newactivetargetfloorname: String):
	var xcviz = { "prevxcvizstates":{ }, "xcvizstates":{ } }
	if activetargetfloor != null and newactivetargetfloorname != activetargetfloor.get_name():
		xcviz["prevxcvizstates"][activetargetfloor.get_name()] = activetargetfloor.drawingvisiblecode
		xcviz["xcvizstates"][activetargetfloor.get_name()] = activetargetfloor.drawingvisiblecode & \
															 (DRAWING_TYPE.VIZ_XCD_FLOOR_NORMAL | DRAWING_TYPE.VIZ_XCD_FLOOR_NOSHADE_B | DRAWING_TYPE.VIZ_XCD_FLOOR_GHOSTLY_B)
	if newactivetargetfloorname != "":
		var newactivetargetfloor = sketchsystem.get_node("XCdrawings").get_node_or_null(newactivetargetfloorname)
		xcviz["xcvizstates"][newactivetargetfloorname] = DRAWING_TYPE.VIZ_XCD_FLOOR_ACTIVE_B | \
				(newactivetargetfloor.drawingvisiblecode if newactivetargetfloor != null else DRAWING_TYPE.VIZ_XCD_FLOOR_NORMAL)
														  
	return xcviz


func floorstyle_itemselected(floorstyleid):
	if activetargetfloor != null:
		var newdrawingcode = DRAWING_TYPE.VIZ_XCD_FLOOR_NORMAL
		if (activetargetfloor.drawingvisiblecode & DRAWING_TYPE.VIZ_XCD_FLOOR_ACTIVE_B) != 0:
			newdrawingcode |= DRAWING_TYPE.VIZ_XCD_FLOOR_ACTIVE_B
		if floorstyleid == 2:
			newdrawingcode |= DRAWING_TYPE.VIZ_XCD_FLOOR_GHOSTLY_B
		elif floorstyleid == 1:
			newdrawingcode |= DRAWING_TYPE.VIZ_XCD_FLOOR_NOSHADE_B
		var floorviz = { "prevxcvizstates":{ activetargetfloor.get_name():activetargetfloor.drawingvisiblecode  }, 
						 "xcvizstates":{ activetargetfloor.get_name():newdrawingcode } }
		sketchsystem.actsketchchange([floorviz])
			

func buttondelpaper_pressed():
	sketchsystem.actsketchchange([{ "xcvizstates":{ activetargetfloor.get_name():DRAWING_TYPE.VIZ_XCD_FLOOR_DELETED}} ])

func defaultimgtrim():
	return { "imgwidth":20, 
			 "imgtrimleftdown":Vector2(-10, -10),
			 "imgtrimrightup":Vector2(10, 10) }

func fetchbuttonpressed(item, column, idx):
	print("iii ", item, " ", column, "  ", idx)
	if item == null:
		print("fetchbuttonpressed item is null problem")
		item = buttonidxtoitem.get(idx)
	var url = item.get_tooltip(0)
	if url == "**clear-cache**":
		print("Clearing image and webpage caches")
		ImageSystem.clearcachedir(ImageSystem.imgdir)
		ImageSystem.clearcachedir(ImageSystem.nonimagedir)
		return
	var fname = item.get_text(0)
	print("url to fetch: ", url)
	if imgregex.search(fname):
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
		ImageSystem.fetchunrolltree(fileviewtree, item, item.get_tooltip(0))

func addsubitem(upperitem, fname, url):
	var item = fileviewtree.create_item(upperitem)
	item.set_text(0, fname)
	item.set_tooltip(0, url)
	var tex = null
	if imgregex.search(fname):
		tex = installbuttontex.duplicate()
	elif url.ends_with("/"):
		tex = fetchbuttontex.duplicate()
	else:
		print("unknown file ignored: ", fname)
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
			addsubitem(item, lk.replace("%20", " "), dirurl + lk)

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


func checkboxtubesvisible_pressed():
	var pvchange = planviewtodict()
	pvchange["tubesvisible"] = planviewcontrols.get_node("CheckBoxTubesVisible").pressed 
	sketchsystem.actsketchchange([{"planview":pvchange}]) 

func checkcentrelinesvisible_pressed():
	var pvchange = planviewtodict()
	pvchange["centrelinesvisible"] = planviewcontrols.get_node("CheckBoxCentrelinesVisible").pressed 
	sketchsystem.actsketchchange([{"planview":pvchange}]) 

		
func _ready():
	listregex.compile('<li><a href="([^"]*)">')
	imgregex.compile('(?i)\\.(png|jpg|jpeg)$')
	installbuttontex = get_node("/root/Spatial/MaterialSystem/buttonmaterials/InstallButton").get_surface_material(0).albedo_texture
	fetchbuttontex = get_node("/root/Spatial/MaterialSystem/buttonmaterials/FetchButton").get_surface_material(0).albedo_texture
	clearcachebuttontex = get_node("/root/Spatial/MaterialSystem/buttonmaterials/ClearCacheButton").get_surface_material(0).albedo_texture

	$RealPlanCamera.set_as_toplevel(true)
	planviewcontrols.get_node("ZoomView/ButtonCentre").connect("pressed", self, "buttoncentre_pressed")
	planviewcontrols.get_node("ButtonClosePlanView").connect("pressed", self, "buttonclose_pressed")
	planviewcontrols.get_node("FloorMove/ButtonDelPaper").connect("pressed", self, "buttondelpaper_pressed")
	planviewcontrols.get_node("CheckBoxTubesVisible").connect("pressed", self, "checkboxtubesvisible_pressed")
	planviewcontrols.get_node("CheckBoxCentrelinesVisible").connect("pressed", self, "checkcentrelinesvisible_pressed")
	planviewcontrols.get_node("FloorMove/FloorStyle").connect("item_selected", self, "floorstyle_itemselected")
	planviewcontrols.get_node("CheckBoxFileTree").connect("toggled", self, "checkboxfiletree_toggled")
	call_deferred("readydeferred")
	set_process(visible)
		
func readydeferred():
	fileviewtree.connect("button_pressed", self, "fetchbuttonpressed")
	var root = fileviewtree.create_item()
	root.set_text(0, "Root of tree")
	root.set_tooltip(0, "**clear-cache**")
	#addsubitem(root, "Ireby", "http://cave-registry.org.uk/svn/NorthernEngland/ThreeCountiesArea/rawscans/Ireby/")
	#addsubitem(root, "rawscans", "http://cave-registry.org.uk/svn/NorthernEngland/ThreeCountiesArea/rawscans/")
	addsubitem(root, "rawscans", "http://cave-registry.org.uk/svn/NorthernEngland/ThreeCountiesArea/")
	var idx = len(buttonidxtoitem)
	root.add_button(0, clearcachebuttontex, idx)
	buttonidxtoitem[idx] = root
	
			
func planviewtodict():
	return { "visible":visible,
			 "planviewactive":planviewactive, 
			 "tubesvisible":(($PlanView/Viewport/PlanGUI/Camera.cull_mask & CollisionLayer.VL_xcshells) != 0),
			 "centrelinesvisible":(($PlanView/Viewport/PlanGUI/Camera.cull_mask & CollisionLayer.VL_centrelinestationsplanview) != 0),
			 "transformpos":$PlanView.global_transform,
			 "plancamerapos":$PlanView/Viewport/PlanGUI/Camera.translation,
			 "plancamerasize":$PlanView/Viewport/PlanGUI/Camera.size
			}


func actplanviewdict(pvchange):
	if "plancamerapos" in pvchange:
		$PlanView/Viewport/PlanGUI/Camera.translation = pvchange["plancamerapos"]
	if "plancamerasize" in pvchange:
		$PlanView/Viewport/PlanGUI/Camera.size = pvchange["plancamerasize"]
		$RealPlanCamera/RealCameraBox.scale = Vector3($PlanView/Viewport/PlanGUI/Camera.size, 1.0, $PlanView/Viewport/PlanGUI/Camera.size)
		var pixmetres = $PlanView/Viewport.size.x/$PlanView/Viewport/PlanGUI/Camera.size
		var metres10 = 1
		while pixmetres*metres10 < 30 and metres10 < 1000:
			metres10 *= 10
		$PlanView/Viewport/PlanGUI/PlanViewControls/Scalebar/scalelabel.text = "Scale: %dm" % metres10
		$PlanView/Viewport/PlanGUI/PlanViewControls/Scalebar/scalerect.rect_size.x = pixmetres*metres10

	if "transformpos" in pvchange:
		$PlanView.global_transform = pvchange["transformpos"]

	var visiblechange = ("visible" in pvchange and visible != pvchange["visible"])
	if visiblechange:
		visible = pvchange["visible"]
		if visible:
			get_node("PlanView/CollisionShape").disabled = false
			var playerMe = get_node("/root/Spatial").playerMe
			get_node("/root/Spatial/LabelGenerator").restartlabelmakingprocess(playerMe.get_node("HeadCam").global_transform.origin)
			get_node("/root/Spatial/WorldEnvironment/DirectionalLight").visible = true
		else:
			get_node("PlanView/CollisionShape").disabled = true
			get_node("/root/Spatial/WorldEnvironment/DirectionalLight").visible = not get_node("/root/Spatial/GuiSystem/GUIPanel3D/Viewport/GUI/Panel/ButtonHeadtorch").pressed
	var guipanel3d = get_node("/root/Spatial/GuiSystem/GUIPanel3D")
	guipanel3d.get_node("Viewport/GUI/Panel/ButtonPlanView").pressed = visible

	if "planviewactive" in pvchange and (visiblechange or planviewactive != pvchange["planviewactive"]):
		planviewactive = pvchange["planviewactive"]
		if planviewactive:
			$PlanView/ProjectionScreen/ImageFrame.mesh.surface_get_material(0).emission_enabled = true
			prevcamerasize = -1
			set_process(true)
		else:
			$PlanView/ProjectionScreen/ImageFrame.mesh.surface_get_material(0).emission_enabled = false
			set_process(false)

	if "centrelinesvisible" in pvchange:
		planviewcontrols.get_node("CheckBoxCentrelinesVisible").pressed = pvchange["centrelinesvisible"]
		planviewcontrols.get_node("CheckBoxTubesVisible").pressed = pvchange["tubesvisible"]

		var plancameracullmask
		var plancameraraycollisionmask
		var playermeheadcam = get_node("/root/Spatial").playerMe.get_node("HeadCam")
		if pvchange["centrelinesvisible"]:
			playermeheadcam.cull_mask = CollisionLayer.VLCM_PlayerCamera
			get_node("/root/Spatial/BodyObjects/LaserOrient/RayCast").collision_mask = CollisionLayer.CLV_MainRayAll
			plancameracullmask = CollisionLayer.VLCM_PlanViewCamera
			plancameraraycollisionmask = CollisionLayer.CLV_PlanRayAll
			var labelgenerator = get_node("/root/Spatial/LabelGenerator")
			if not labelgenerator.is_processing():
				labelgenerator.restartlabelmakingprocess(playermeheadcam.global_transform.origin)
		else:
			playermeheadcam.cull_mask = CollisionLayer.VLCM_PlayerCameraNoCentreline
			get_node("/root/Spatial/BodyObjects/LaserOrient/RayCast").collision_mask = CollisionLayer.CLV_MainRayAll
			plancameraraycollisionmask = CollisionLayer.CLV_PlanRayNoCentreline
			plancameracullmask = CollisionLayer.VLCM_PlanViewCameraNoCentreline
		
		if not pvchange["tubesvisible"]:
			plancameracullmask &= CollisionLayer.VLCM_PlanViewCameraNoTube
			plancameraraycollisionmask &= CollisionLayer.CLV_PlanRayNoTube
		get_node("PlanView/Viewport/PlanGUI/Camera").cull_mask = plancameracullmask
		get_node("RealPlanCamera/LaserScope/LaserOrient/RayCast").collision_mask = plancameraraycollisionmask


func planviewtransformpos(guidpaneltransform, guidpanelsize):
	if guidpaneltransform != null:
		var paneltrans = $PlanView.global_transform
		paneltrans.origin = guidpaneltransform.origin + guidpaneltransform.basis.y*(guidpanelsize.y/2) + Vector3(0,$PlanView/ProjectionScreen/ImageFrame.mesh.size.y/2,0)
		var eyepos = get_node("/root/Spatial").playerMe.get_node("HeadCam").global_transform.origin
		paneltrans = paneltrans.looking_at(eyepos + 2*(paneltrans.origin-eyepos), Vector3(0, 1, 0))
		return paneltrans
	else:
		var paneltrans = $PlanView.global_transform
		var controllertrans = get_node("/root/Spatial/BodyObjects/LaserOrient").global_transform
		var paneldistance = 1.2 if Tglobal.VRoperating else 0.6
		paneltrans.origin = controllertrans.origin - paneldistance*ARVRServer.world_scale*(controllertrans.basis.z)
		var lookatpos = controllertrans.origin - 1.6*ARVRServer.world_scale*(controllertrans.basis.z)
		paneltrans = paneltrans.looking_at(lookatpos, Vector3(0, 1, 0))
		return paneltrans


var updateplanviewentitysizes_working = false
func updateplanviewentitysizes():
	prevcamerasize = $PlanView/Viewport/PlanGUI/Camera.size
	var nodesca = $PlanView/Viewport/PlanGUI/Camera.size/70.0*5
	var labelsca = nodesca*1.2
	var labelrects = [ ]
	var rectrecttests = 0
	var rectrecttestt0 = OS.get_ticks_msec()
	for xcdrawingcentreline in get_tree().get_nodes_in_group("gpcentrelinegeo"):
		xcdrawingcentreline.updatexcpaths_part(xcdrawingcentreline.get_node("PathLines_PlanView"), 0.035*nodesca)
		for xcn in xcdrawingcentreline.get_node("XCnodes_PlanView").get_children():
			xcn.get_node("CollisionShape").scale = Vector3(nodesca, nodesca, nodesca)
			var stationlabel = xcn.get_node("StationLabel")
			stationlabel.get_surface_material(0).set_shader_param("vertex_scale", labelsca)
			var labelcentre = stationlabel.global_transform.origin + stationlabel.get_surface_material(0).get_shader_param("vertex_offset")
			var xcnrect = Rect2(-(xcn.transform.origin.x + 0.15), xcn.transform.origin.y, stationlabel.mesh.size.x*nodesca, stationlabel.mesh.size.y*nodesca)
			var xcnrect_overlapping = false
			for r in labelrects:
				if xcnrect.intersects(r):
					xcnrect_overlapping = true
					break
				rectrecttests += 1
			xcn.visible = not xcnrect_overlapping
			if not xcnrect_overlapping:
				labelrects.push_back(xcnrect)
			if rectrecttests > 10000:
				print("rectrecttests ", rectrecttests, OS.get_ticks_msec() - rectrecttestt0)
				yield(get_tree().create_timer(0.2), "timeout")
				rectrecttests = 0
				rectrecttestt0 = OS.get_ticks_msec()
	updateplanviewentitysizes_working = false

var slowviewportframeratecountdown = 1
var slowviewupdatecentrelinesizeupdaterate = 1.5
var prevcamerasize = 0
var lastoptionaltxcdata = { }
func _process(delta):
	if Tglobal.arvrinterfacename == "OVRMobile" and visible:
		slowviewportframeratecountdown -= delta
		if slowviewportframeratecountdown < 0:
			slowviewportframeratecountdown = 1
			$PlanView/Viewport.render_target_update_mode = Viewport.UPDATE_ONCE

	if visible:
		slowviewupdatecentrelinesizeupdaterate -= delta
		if slowviewupdatecentrelinesizeupdaterate < 0:
			if prevcamerasize != $PlanView/Viewport/PlanGUI/Camera.size and not updateplanviewentitysizes_working:
				updateplanviewentitysizes_working = true
				call_deferred("updateplanviewentitysizes")
			slowviewupdatecentrelinesizeupdaterate = 1.6
	
	var planviewpositiondict = { }
	var viewslide = planviewcontrols.get_node("ViewSlide")
	var joypos = Vector3((-1 if viewslide.get_node("ButtonSlideLeft").is_pressed() else 0) + (1 if viewslide.get_node("ButtonSlideRight").is_pressed() else 0), 
						 (-1 if viewslide.get_node("ButtonSlideDown").is_pressed() else 0) + (1 if viewslide.get_node("ButtonSlideUp").is_pressed() else 0),
						 (-1 if viewslide.get_node("ButtonZoomDown").is_pressed() else 0) + (1 if viewslide.get_node("ButtonZoomUp").is_pressed() else 0))
	if joypos != Vector3(0, 0, 0):
		var plancamera = $PlanView/Viewport/PlanGUI/Camera
		planviewpositiondict["plancamerapos"] = plancamera.translation + Vector3(joypos.x*plancamera.size/2, joypos.z*5, -joypos.y*plancamera.size/2)*delta
	var zoomview = planviewcontrols.get_node("ZoomView")
	var bzoomin = zoomview.get_node("ButtonZoomIn").is_pressed()
	var bzoomout = zoomview.get_node("ButtonZoomOut").is_pressed()
	if bzoomin or bzoomout:
		var zoomfac = 1/(1 + 0.5*delta) if bzoomin else 1 + 0.5*delta
		var plancamera = $PlanView/Viewport/PlanGUI/Camera
		planviewpositiondict["plancamerasize"] = plancamera.size * zoomfac
	if not planviewpositiondict.empty():
		sketchsystem.actsketchchange([{"planview":planviewpositiondict}])

	if activetargetfloor != null:
		var floortrim = planviewcontrols.get_node("FloorTrim")
		var joypostrimld = Vector2((-1 if floortrim.get_node("ButtonTrimLeftLeft").is_pressed() else 0) + (1 if floortrim.get_node("ButtonTrimLeftRight").is_pressed() else 0), 
								   (-1 if floortrim.get_node("ButtonTrimDownDown").is_pressed() else 0) + (1 if floortrim.get_node("ButtonTrimDownUp").is_pressed() else 0))
		var joypostrimru = Vector2((-1 if floortrim.get_node("ButtonTrimRightLeft").is_pressed() else 0) + (1 if floortrim.get_node("ButtonTrimRightRight").is_pressed() else 0), 
								   (-1 if floortrim.get_node("ButtonTrimUpDown").is_pressed() else 0) + (1 if floortrim.get_node("ButtonTrimUpUp").is_pressed() else 0))
		var floormove = planviewcontrols.get_node("FloorMove")
		var joyposmove = Vector3((-1 if floormove.get_node("ButtonMoveLeft").is_pressed() else 0) + (1 if floormove.get_node("ButtonMoveRight").is_pressed() else 0), 
								 0.5*(-1 if floormove.get_node("ButtonMoveFall").is_pressed() else 0) + (1 if floormove.get_node("ButtonMoveRise").is_pressed() else 0),
								 (-1 if floormove.get_node("ButtonMoveDown").is_pressed() else 0) + (1 if floormove.get_node("ButtonMoveUp").is_pressed() else 0))
		var joygrow = (-1 if floormove.get_node("ButtonShrink").is_pressed() else 0) + (1 if floormove.get_node("ButtonGrow").is_pressed() else 0)
		var joyrot = Vector2((-1 if floormove.get_node("ButtonRotR").is_pressed() else 0) + (1 if floormove.get_node("ButtonRotL").is_pressed() else 0), 
							 (-1 if floormove.get_node("ButtonTiltFore").is_pressed() else 0) + (1 if floormove.get_node("ButtonTiltBack").is_pressed() else 0))
		if len(activetargetfloor.nodepoints) != 0:
			joyposmove.x = 0
			joyposmove.z = 0
			joygrow = 0
			joyrot = Vector2(0, 0)
		if joypostrimld != Vector2(0,0) or joypostrimru != Vector2(0,0) or joyposmove != Vector3(0,0,0) or joygrow != 0 or joyrot != Vector2(0, 0):
			if "name" in lastoptionaltxcdata and lastoptionaltxcdata["name"] != activetargetfloor.get_name():
				sketchsystem.actsketchchange([lastoptionaltxcdata])
				lastoptionaltxcdata.clear()
			var txcdata = { "name":activetargetfloor.get_name(), 
							"rpcoptional":1,
							"timestamp":OS.get_ticks_msec()*0.001 }
			lastoptionaltxcdata["name"] = txcdata["name"]
			lastoptionaltxcdata["timestamp"] = txcdata["timestamp"]

			var d = activetargetfloor
			var drawingplane = d.get_node("XCdrawingplane")
			var sfac = delta*8
			if joyposmove != Vector3(0,0,0) or joyrot != Vector2(0, 0):
				txcdata["prevtransformpos"] = d.transform
				var tb = d.transform.basis
				if joyrot != Vector2(0, 0):
					tb = Basis(tb.get_euler() + Vector3(joyrot.y*delta, joyrot.x*delta, 0))
				txcdata["transformpos"] = Transform(tb, d.transform.origin + Basis()*joyposmove*delta*8)
				lastoptionaltxcdata["prevtransformpos"] = txcdata["prevtransformpos"]
				lastoptionaltxcdata["transformpos"] = txcdata["transformpos"]

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
				lastoptionaltxcdata["previmgtrim"] = txcdata["previmgtrim"]
				lastoptionaltxcdata["imgtrim"] = txcdata["imgtrim"]
				lastoptionaltxcdata["imgtrimleftdown"] = txcdata["imgtrimleftdown"]
				lastoptionaltxcdata["imgtrimrightup"] = txcdata["imgtrimrightup"]
								
			sketchsystem.actsketchchange([txcdata])
		elif "name" in lastoptionaltxcdata:
			print("sending lastoptionaltxcdata ", lastoptionaltxcdata["name"])
			sketchsystem.actsketchchange([lastoptionaltxcdata])
			lastoptionaltxcdata.clear()

	
func buttoncentre_pressed():
	var headcam = get_node("/root/Spatial").playerMe.get_node("HeadCam")
	var planviewpositiondict = { "plancamerapos":Vector3(headcam.global_transform.origin.x, $PlanView/Viewport/PlanGUI/Camera.translation.y, headcam.global_transform.origin.z) }
	sketchsystem.actsketchchange([{"planview":planviewpositiondict}])

func buttonclose_pressed():
	sketchsystem.actsketchchange([ {"planview":{"visible":false, "planviewactive":false}}, 
								   getactivetargetfloorViz("") 
								 ])

func checkplanviewinfront(handrightcontroller):
	var planviewsystem = self
	var collider_transform = planviewsystem.get_node("PlanView").global_transform
	return collider_transform.xform_inv(handrightcontroller.global_transform.origin).z > 0

func checkinguipanel(viewport_point):
	var rectrel = viewport_point - planviewcontrols.rect_position
	if rectrel.x > 0 and rectrel.y > 0 and rectrel.x < planviewcontrols.rect_size.x and rectrel.y < planviewcontrols.rect_size.y:
		return true
	if fileviewtree.visible:
		var rectrelt = rectrel - fileviewtree.rect_position
		if  rectrelt.x > 0 and  rectrelt.y > 0 and  rectrelt.x < fileviewtree.rect_size.x and rectrelt.y < fileviewtree.rect_size.y:
			return true
	return false

func checkboxfiletree_toggled(button_pressed):
	fileviewtree.visible = button_pressed

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

	var inguipanel = checkinguipanel(viewport_point)
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


