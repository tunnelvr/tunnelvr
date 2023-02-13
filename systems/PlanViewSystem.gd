extends Spatial

var planviewactive = false
var drawingtype = DRAWING_TYPE.DT_PLANVIEW
onready var ImageSystem = get_node("/root/Spatial/ImageSystem")
onready var sketchsystem = get_node("/root/Spatial/SketchSystem")
onready var selfSpatial = get_node("/root/Spatial")
onready var GithubAPI = get_node("/root/Spatial/ImageSystem/GithubAPI")
	
var activetargetfloor = null
var activetargetfloortransformpos = null
var activetargetfloorimgtrim = null

var buttonidxtoitem = { }
var buttonidxloaded = [ ]

onready var fileviewtree = $PlanView/Viewport/PlanGUI/PlanViewControls/FileviewTree
onready var planviewcontrols = $PlanView/Viewport/PlanGUI/PlanViewControls
onready var plancamera = $PlanView/Viewport/PlanGUI/Camera

var imgregex = RegEx.new()
var listsvnregex = RegEx.new()
var f3dregex = RegEx.new()
var listhttpregex = RegEx.new()

var installbuttontex = null
var fetchbuttontex = null
var clearcachebuttontex = null
var f3dbuttontex = null

var filetreeresourcename = null
var materialsettobackfacecullcartoon = 0
var backfacecartoonValid = true

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
		if floorstyleid == DRAWING_TYPE.FS_GHOSTLY:
			newdrawingcode |= DRAWING_TYPE.VIZ_XCD_FLOOR_GHOSTLY_B
		#elif floorstyleid == DRAWING_TYPE.FS_UNSHADED:
		#	newdrawingcode |= DRAWING_TYPE.VIZ_XCD_FLOOR_NOSHADE_B
		elif floorstyleid == DRAWING_TYPE.FS_PHOTO:
			newdrawingcode |= (DRAWING_TYPE.VIZ_XCD_FLOOR_NOSHADE_B | DRAWING_TYPE.VIZ_XCD_FLOOR_GHOSTLY_B)
		elif floorstyleid == DRAWING_TYPE.FS_HIDE:
			newdrawingcode = DRAWING_TYPE.VIZ_XCD_FLOOR_HIDDEN
		elif floorstyleid == DRAWING_TYPE.FS_DELETE:
			newdrawingcode = DRAWING_TYPE.VIZ_XCD_FLOOR_DELETED
			
		var floorviz = { "prevxcvizstates":{ activetargetfloor.get_name():activetargetfloor.drawingvisiblecode  }, 
						 "xcvizstates":{ activetargetfloor.get_name():newdrawingcode } }
		sketchsystem.actsketchchange([floorviz])

func fetchselectedcaddyfilepath():
	var itemselected = fileviewtree.get_selected()
	if itemselected != null and filetreeresourcename != null:
		var path = itemselected.get_tooltip(0)
		if path != "**clear-cache**" :
			return path
	return ""

var photolayerimport = 0
func fetchbuttonpressed(item, column, idx):
	if item == null:
		item = buttonidxtoitem.get(idx)
		print("fetchbuttonpressed item is null problem")
	elif idx == -1:
		for lidx in buttonidxtoitem:
			if buttonidxtoitem[lidx] == item:
				idx = lidx
				break
	print("iii ", idx, " ", item, " ", item.get_text(0), " ", column, "  ", filetreeresourcename)
	Tglobal.soundsystem.quicksound("MenuClick", raycastcollisionpointC)
	var url = item.get_tooltip(0)
	if url == "**clear-cache**":
		print("Clearing image and webpage caches")
		ImageSystem.clearcachedir(ImageSystem.imgdir)
		ImageSystem.clearcachedir(ImageSystem.nonimagedir)
		if GithubAPI.riattributes.has("filetreesel"):
			var guipanel3d = get_node("/root/Spatial/GuiSystem/GUIPanel3D")
			guipanel3d.ApplyToFiletree(GithubAPI.riattributes["filetreesel"])
		planviewcontrols.get_node("CheckBoxFileTree").pressed = false
		return
		
	var fname = item.get_text(0)
	var filetreeresource = null
	if filetreeresourcename != null:
		filetreeresource = GithubAPI.riattributes["resourcedefs"].get(filetreeresourcename)
		var path = item.get_tooltip(0)
		if filetreeresource.get("type") == "githubapi":
			if path.ends_with("/"):
				url = "https://%s/repos/%s/%s/contents/%s" % [ filetreeresource["apiurl"], filetreeresource["owner"], filetreeresource["repo"], path.lstrip("/").rstrip("/") ]
			else:
				assert (filetreeresource["apiurl"] == "api.github.com")
				url = "https://raw.githubusercontent.com/%s/%s/main/%s" % [ filetreeresource["owner"], filetreeresource["repo"], path.lstrip("/") ]
		elif filetreeresource.get("type") == "caddyfiles":
			url = filetreeresource.get("url") + path.lstrip("/")
		elif filetreeresource.get("type") == "svnfiles":
			url = filetreeresource.get("url") + path.lstrip("/")
		elif filetreeresource.get("type") == "httpfiles":
			url = filetreeresource.get("url") + path.lstrip("/")
		
	print("url to fetch: ", url)
	if imgregex.search(fname):
		var transformpos = Transform(Vector3(1,0,0), Vector3(0,0,-1), Vector3(0,1,0), selfSpatial.playerMe.transform.origin + Vector3(0, 0.1, 0))
		if planviewcontrols.get_node("ImportPhotoMode").pressed:
			var MotionVectorPreview = selfSpatial.get_node("BodyObjects/PlayerMotion/MotionVectorPreview")
			var controllertrans = MotionVectorPreview.global_transform if MotionVectorPreview.visible else selfSpatial.playerMe.get_node("HeadCam").global_transform 
			var paneltrans = Transform()
			var paneldistance = 5.6 if Tglobal.VRoperating else 3.8
			paneltrans.origin = controllertrans.origin - paneldistance*ARVRServer.world_scale*(controllertrans.basis.z)
			var lookatpos = controllertrans.origin - 2*paneldistance*ARVRServer.world_scale*(controllertrans.basis.z)
			paneltrans = paneltrans.looking_at(lookatpos, Vector3(0, 1, 0))
			paneltrans = Transform(paneltrans.basis.scaled(Vector3(ARVRServer.world_scale, ARVRServer.world_scale, ARVRServer.world_scale)), paneltrans.origin)
			transformpos = paneltrans
		var sname = sketchsystem.uniqueXCdrawingPapername(url)
		var defaultimgtrim = { "imgwidth":10*0.2, 
							   "imgtrimleftdown":Vector2(-5, -5)*0.2,
							   "imgtrimrightup":Vector2(5, 5)*0.2 }
		activetargetfloorimgtrim = { "name":sname, 
									 "drawingtype":DRAWING_TYPE.DT_FLOORTEXTURE,
									 "xcresource":url,
									 "imgtrim":defaultimgtrim,
									 "transformpos":transformpos
								   }



		var floorviz = getactivetargetfloorViz(sname)
		if planviewcontrols.get_node("ImportPhotoMode").pressed:
			floorviz["xcvizstates"][sname] = (DRAWING_TYPE.VIZ_XCD_FLOOR_NORMAL | DRAWING_TYPE.VIZ_XCD_FLOOR_NOSHADE_B | DRAWING_TYPE.VIZ_XCD_FLOOR_GHOSTLY_B)
		sketchsystem.actsketchchange([activetargetfloorimgtrim, floorviz])
		
	elif f3dregex.search(fname):
		print("\n\n\n\n***\n\n 3dfile to load ", url)
		if not planviewcontrols.get_node("CheckBoxCentrelinesVisible").pressed:
			planviewcontrols.get_node("CheckBoxCentrelinesVisible").pressed = true
			checkcentrelinesvisible_pressed()
		get_node("/root/Spatial/ExecutingFeatures").parse3ddmpcentreline_networked(url)

	elif not buttonidxloaded.has(idx):
		item.set_button_disabled(column, idx, true)
		item.erase_button(column, idx)
		buttonidxloaded.push_back(idx) 
		#item.erase_button(column, idx)
		#buttonidxtoitem.erase(idx)
		item.set_custom_bg_color(0, Color("#ff0099"))
		if filetreeresource != null:
			filetreeresource["idx_failunload"] = idx
			ImageSystem.fetchunrolltree(fileviewtree, item, url, filetreeresource)
		else:
			ImageSystem.fetchunrolltree(fileviewtree, item, url, null)

	else:
		print("Suppressing button ", fname, " which should be disabled because it is already loaded")

func actunrolltree(f, fetchednonimagedataobject):
	var htmltext = f.get_as_text()
	f.close()
	if htmltext == "" and fetchednonimagedataobject.has("filetreeresource") and fetchednonimagedataobject["filetreeresource"].has("idx_failunload"):
		buttonidxloaded.erase(fetchednonimagedataobject["filetreeresource"]["idx_failunload"])

	var llinks = [ ]
	if fetchednonimagedataobject.has("filetreeresource"):
		if fetchednonimagedataobject["filetreeresource"].get("type") == "caddyfiles":
			var jres = parse_json(htmltext)
			if jres != null:
				for jr in jres:
					llinks.push_back(jr["name"] + ("/" if jr.get("is_dir") else ""))
		elif fetchednonimagedataobject["filetreeresource"].get("type") == "githubapi":
			var jres = parse_json(htmltext)
			if jres != null:
				for jr in jres:
					llinks.push_back(jr["name"] + ("/" if jr.get("type") == "dir" else ""))
		elif fetchednonimagedataobject["filetreeresource"].get("type") == "svnfiles":
			for m in listsvnregex.search_all(htmltext):
				var lk = m.get_string(1)
				if not lk.begins_with("."):
					lk = lk.replace("&amp;", "&")
					llinks.push_back(lk)
		elif fetchednonimagedataobject["filetreeresource"].get("type") == "httpfiles":
			for m in listhttpregex.search_all(htmltext):
				var lk = m.get_string(1)
				if not lk.begins_with("."):
					lk = lk.replace("&amp;", "&")
					llinks.push_back(lk)

	else:
		for m in listsvnregex.search_all(htmltext):   # svnfiles type bydefault
			var lk = m.get_string(1)
			if not lk.begins_with("."):
				lk = lk.replace("&amp;", "&")
				llinks.push_back(lk)
	openlinklistpage(fetchednonimagedataobject["item"], llinks)




func itemselected():
	var itemclicked = fileviewtree.get_selected()
	print(" filetree_itemselected ", itemclicked, " ", fileviewtree.get_scroll())

func scrolltree(bdown):
	var itemselected = fileviewtree.get_selected()
	if itemselected == null:
		itemselected = fileviewtree.get_root()
	var nextitem = null
	if bdown:
		if not itemselected.collapsed:
			var item0 = itemselected.get_children()
			if item0 != null:
				nextitem = item0
		if nextitem == null:
			nextitem = itemselected.get_next()
		if nextitem == null:
			var itemt = itemselected
			while true:
				itemt = itemt.get_parent()
				if itemt == null:
					break
				var itempn = itemt.get_next()
				if itempn != null:
					nextitem = itempn
					break 
	else:
		nextitem = itemselected.get_prev()
		if nextitem != null:
			while not nextitem.collapsed:
				var item0 = nextitem.get_children()
				if item0 != null:
					while true:
						var item1 = item0.get_next()
						if item1 == null:
							break
						item0 = item1
					nextitem = item0
				else:
					break
		else:
			nextitem = itemselected.get_parent()
	if nextitem != null:
		nextitem.select(0)
		fileviewtree.scroll_to_item(nextitem)
	
func _input(event):
	if fileviewtree.visible:
		if event is InputEventKey and event.pressed:
			if event.scancode == KEY_J:
				scrolltree(true)
			if event.scancode == KEY_U:
				scrolltree(false)
			if event.scancode == KEY_7:
				var itemselected = fileviewtree.get_selected()
				if itemselected != null:
					fetchbuttonpressed(itemselected, 0, -1)
				
				


func addsubitem(upperitem, fname, url):
	var item = fileviewtree.create_item(upperitem)
	item.set_text(0, fname)
	item.set_tooltip(0, url)
	var tex = null
	if imgregex.search(fname):
		tex = installbuttontex.duplicate()
	elif f3dregex.search(fname):
		tex = f3dbuttontex.duplicate()
	elif url.ends_with("/"):
		tex = fetchbuttontex.duplicate()
	else:
		print("unknown file ignored: ", fname)
		return
	#var idx = item.get_button_count(0)
	var idx = len(buttonidxtoitem)
	item.add_button(0, tex, idx)
	buttonidxtoitem[idx] = item

func openlinklistpage(item, llinks):
	item.clear_custom_bg_color(0)
	var dirurl = item.get_tooltip(0).rstrip("/") + "/"
	for lk in llinks:
		addsubitem(item, lk.replace("%20", " "), dirurl + lk)

func transferintorealviewport():
	if $PlanView.has_node("ViewportReal") and Tglobal.phoneoverlay == null:
		var fplangui = $PlanView/Viewport/PlanGUI
		$PlanView/Viewport.remove_child(fplangui)
		$PlanView/ViewportReal.add_child(fplangui)
		$PlanView/Viewport.set_name("ViewportFake")
		$PlanView/ViewportReal.set_name("Viewport")
		$PlanView/ProjectionScreen.get_surface_material(0).albedo_texture = $PlanView/Viewport.get_texture()
	else:
		$PlanView/Viewport.visible = false
		$PlanView.visible = false
		$RealPlanCamera.visible = false

func checkboxplantubesvisible_pressed():
	var pvchange = planviewtodict()
	pvchange["plantubesvisible"] = planviewcontrols.get_node("CheckBoxPlanTubesVisible").pressed 
	actplanviewdict(pvchange) 

func checkboxrealtubesvisible_pressed():
	var pvchange = planviewtodict()
	pvchange["realtubesvisible"] = planviewcontrols.get_node("CheckBoxRealTubesVisible").pressed
	actplanviewdict(pvchange) 




func optionsbackfacecull_selected(backfacecull_index):
	var pvchange = planviewtodict()
	pvchange["backfacecull"] = backfacecull_index
	actplanviewdict(pvchange)
	
func buttontransmitview_pressed():
	if planviewcontrols.get_node("ButtonTransmitView").pressed:
		var pvchange = planviewtodict()
		sketchsystem.actsketchchange([{"planview":pvchange}]) 

func checkcentrelinesvisible_pressed():
	var pvchange = planviewtodict()
	pvchange["centrelinesvisible"] = planviewcontrols.get_node("CheckBoxCentrelinesVisible").pressed 
	actplanviewdict(pvchange) 


		
func _ready():
	imgregex.compile('(?i)\\.(png|jpg|jpeg)$')
	f3dregex.compile('(?i)\\.(3d)$')
	listsvnregex.compile('<li><a href="([^"]*)">')
	listhttpregex.compile('<td><a href="([^"]*)">')
	installbuttontex = get_node("/root/Spatial/MaterialSystem/buttonmaterials/InstallButton").get_surface_material(0).albedo_texture
	fetchbuttontex = get_node("/root/Spatial/MaterialSystem/buttonmaterials/FetchButton").get_surface_material(0).albedo_texture
	clearcachebuttontex = get_node("/root/Spatial/MaterialSystem/buttonmaterials/ClearCacheButton").get_surface_material(0).albedo_texture
	f3dbuttontex = get_node("/root/Spatial/MaterialSystem/buttonmaterials/f3dButton").get_surface_material(0).albedo_texture

	$RealPlanCamera.set_as_toplevel(true)
	planviewcontrols.get_node("ZoomView/ButtonCentre").connect("pressed", self, "buttoncentre_pressed")
	planviewcontrols.get_node("ViewSlide/ButtonFollow").connect("toggled", self, "buttonfollow_toggled")
	planviewcontrols.get_node("ViewSlide/ButtonElev").connect("toggled", self, "buttonelev_toggled")
	planviewcontrols.get_node("ButtonClosePlanView").connect("pressed", self, "buttonclose_pressed")
	planviewcontrols.get_node("CheckBoxPlanTubesVisible").connect("pressed", self, "checkboxplantubesvisible_pressed")
	planviewcontrols.get_node("CheckBoxRealTubesVisible").connect("pressed", self, "checkboxrealtubesvisible_pressed")
	planviewcontrols.get_node("CheckBoxCentrelinesVisible").connect("pressed", self, "checkcentrelinesvisible_pressed")
	planviewcontrols.get_node("OptionsBackfaceCull").connect("item_selected", self, "optionsbackfacecull_selected")
	planviewcontrols.get_node("ButtonTransmitView").connect("pressed", self, "buttontransmitview_pressed")
	planviewcontrols.get_node("FloorMove/FloorStyle").connect("item_selected", self, "floorstyle_itemselected")
	planviewcontrols.get_node("CheckBoxFileTree").connect("toggled", self, "checkboxfiletree_toggled")
	var PlayerDirections = get_node("/root/Spatial/BodyObjects/PlayerDirections")
	planviewcontrols.get_node("PathFollow/HSliderTrailpos").connect("value_changed", PlayerDirections, "hslidertrailpos_valuechanged")

	planviewcontrols.get_node("CentrelineActivity/OptionsCentreline").connect("item_selected", self, "centrelineactivityoptions_selected")
	planviewcontrols.get_node("CentrelineActivity/CentrelineList").connect("item_selected", self, "centrelineactivitylist_selected")

	set_process(visible)
	assert (planviewcontrols.get_node("CheckBoxPlanTubesVisible").pressed == (($PlanView/Viewport/PlanGUI/Camera.cull_mask & CollisionLayer.VL_xcshells) != 0))

	fileviewtree.connect("button_pressed", self, "fetchbuttonpressed")
	fileviewtree.connect("item_selected", self, "itemselected")

func clearsetupfileviewtree(filetreerootpath, turl):
	fileviewtree.clear()
	buttonidxtoitem.clear()
	buttonidxloaded.clear() 
		
	var root = fileviewtree.create_item()
	root.set_text(0, "dir: " + turl)
	root.set_tooltip(0, "**clear-cache**")
	if filetreeresourcename != null:
		addsubitem(root, filetreerootpath, filetreerootpath)
	else:
		addsubitem(root, "NorthernEngland", filetreerootpath)
	var idx = len(buttonidxtoitem)
	root.add_button(0, clearcachebuttontex, idx)
	buttonidxtoitem[idx] = root
	
			
func planviewtodict():
	return { "visible":visible,
			 "planviewactive":planviewactive, 
			 "plantubesvisible":(($PlanView/Viewport/PlanGUI/Camera.cull_mask & CollisionLayer.VL_xcshells) != 0),
			 "realtubesvisible":(not Tglobal.hidecavewallstoseefloors),
			 "centrelinesvisible":(($PlanView/Viewport/PlanGUI/Camera.cull_mask & CollisionLayer.VL_centrelinestationsplanview) != 0),
			 "transformpos":$PlanView.global_transform,
			 "plancamerapos":plancamera.translation,
			 "plancameraelevrotpoint":elevrotpoint,
			 "plancameraelevcameradist":elevcameradist,
			 "plancamerafogdepthbegin":plancamera.environment.fog_depth_begin, 
			 "plancamerafogdepthend":plancamera.environment.fog_depth_end, 
			 "plancamerarotation":plancamera.rotation_degrees,
			 "plancamerasize":plancamera.size,
			 "backfacecull":materialsettobackfacecullcartoon,
			}

func planviewcameratodict():
	return { "visible":visible,
			 "plancameratrans":plancamera.transform,
			 "plancamerasize":plancamera.size
			}

func setcameracullmasks(bcentrelinesvisible, bplantubesvisible):
	var plancameracullmask
	var plancameraraycollisionmask
	var playermeheadcam = selfSpatial.playerMe.get_node("HeadCam")
	if bcentrelinesvisible:
		playermeheadcam.cull_mask = CollisionLayer.VLCM_PlayerCamera
		get_node("/root/Spatial/BodyObjects/LaserOrient/RayCast").collision_mask = CollisionLayer.CLV_MainRayAll
		plancameracullmask = CollisionLayer.VLCM_PlanViewCamera
		plancameraraycollisionmask = CollisionLayer.CLV_PlanRayAll
		prevcamerasizeforupdateplanviewentitysizes = -1
		var labelgenerator = get_node("/root/Spatial/LabelGenerator")
		if not labelgenerator.is_processing():
			labelgenerator.restartlabelmakingprocess(playermeheadcam.global_transform.origin)
	else:
		playermeheadcam.cull_mask = CollisionLayer.VLCM_PlayerCameraNoCentreline
		get_node("/root/Spatial/BodyObjects/LaserOrient/RayCast").collision_mask = CollisionLayer.CLV_MainRayAllNoCentreline
		plancameraraycollisionmask = CollisionLayer.CLV_PlanRayNoCentreline
		plancameracullmask = CollisionLayer.VLCM_PlanViewCameraNoCentreline
	
	if not bplantubesvisible:
		plancameracullmask &= CollisionLayer.VLCM_PlanViewCameraNoTube
		plancameraraycollisionmask &= CollisionLayer.CLV_PlanRayNoTube
	get_node("PlanView/Viewport/PlanGUI/Camera").cull_mask = plancameracullmask
	get_node("RealPlanCamera/LaserScope/LaserOrient/RayCast").collision_mask = plancameraraycollisionmask

func settunnelxoutlineshadervalues():
	var tunnelxoutline = sketchsystem.get_node("tunnelxoutline")
	var blackoutline = tunnelxoutline.get_node("blackoutline")
	var whiteinfill = tunnelxoutline.get_node("whiteinfill")
	var camerafar = plancamera.far*0.9
	var cameranear = plancamera.near + min(1, camerafar/10)
	var wounddistancefactor = 1.0/(cameranear/camerafar)
	whiteinfill.material_override.set_shader_param("camerafar", camerafar)
	whiteinfill.material_override.set_shader_param("fogcolor", plancamera.environment.background_color)
	whiteinfill.material_override.set_shader_param("wounddistancefactor", wounddistancefactor)
	blackoutline.material_override.set_shader_param("camerafar", camerafar)
	blackoutline.material_override.set_shader_param("wounddistancefactor", wounddistancefactor)
	blackoutline.material_override.set_shader_param("fogcolor", plancamera.environment.background_color)

func actplanviewdict(pvchange, resettransmitbutton=true):
	if resettransmitbutton:
		planviewcontrols.get_node("ButtonTransmitView").pressed = false
	if "plancamerapos" in pvchange:
		plancamera.translation = pvchange["plancamerapos"]
	if "plancamerarotation" in pvchange:
		plancamera.rotation_degrees = pvchange["plancamerarotation"]
	if "plancameraelevrotpoint" in pvchange and "plancameraelevcameradist" in pvchange:
		elevrotpoint = pvchange["plancameraelevrotpoint"]
		elevcameradist = pvchange["plancameraelevcameradist"]
	if "plancamerafogdepthbegin" in pvchange and "plancamerafogdepthend" in pvchange:
		plancamera.environment.fog_depth_begin = pvchange["plancamerafogdepthbegin"]	
		plancamera.environment.fog_depth_end = pvchange["plancamerafogdepthend"]
		plancamera.environment.fog_color = plancamera.environment.background_color
		plancamera.far = plancamera.environment.fog_depth_end
		settunnelxoutlineshadervalues()
	if "plancamerasize" in pvchange:
		$PlanView/Viewport/PlanGUI/Camera.size = pvchange["plancamerasize"]
		$RealPlanCamera/RealCameraBox.scale = Vector3($PlanView/Viewport/PlanGUI/Camera.size, 1.0, $PlanView/Viewport/PlanGUI/Camera.size)
		var planscreensize = $PlanView/Viewport.size if Tglobal.phoneoverlay == null else get_node("/root").size
		var pixmetres = planscreensize.x/$PlanView/Viewport/PlanGUI/Camera.size
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
			var playerMe = get_node("/root/Spatial").playerMe
			get_node("/root/Spatial/LabelGenerator").restartlabelmakingprocess(playerMe.get_node("HeadCam").global_transform.origin)
			get_node("/root/Spatial/WorldEnvironment/DirectionalLight").visible = true
			if Tglobal.phoneoverlay != null:
				$PlanView/Viewport/PlanGUI/Camera.current = true
				$PlanView/Viewport.visible = true
				#Tglobal.phoneoverlay.get_node("ThumbLeft").visible = false
				Tglobal.phoneoverlay.get_node("ThumbRight").visible = false
			else:
				get_node("PlanView/CollisionShape").disabled = false

		else:
			$PlanView/CollisionShape.disabled = true
			$PlanView/Viewport/PlanGUI/PlanViewControls/ColorRectURL.visible = false
			get_node("/root/Spatial/WorldEnvironment/DirectionalLight").visible = not get_node("/root/Spatial/GuiSystem/GUIPanel3D/Viewport/GUI/Panel/ButtonHeadtorch").pressed
			if Tglobal.phoneoverlay != null:
				$PlanView/Viewport/PlanGUI/Camera.current = false
				$PlanView/Viewport.visible = false
				Tglobal.phoneoverlay.get_node("ThumbLeft").visible = true
				Tglobal.phoneoverlay.get_node("ThumbRight").visible = true
			if activetargetfloor != null:
				sketchsystem.actsketchchange([ getactivetargetfloorViz("") ])
			
	var guipanel3d = get_node("/root/Spatial/GuiSystem/GUIPanel3D")
	guipanel3d.get_node("Viewport/GUI/Panel/ButtonPlanView").pressed = visible

	if "planviewactive" in pvchange and (visiblechange or planviewactive != pvchange["planviewactive"]):
		planviewactive = pvchange["planviewactive"]
		if planviewactive:
			$PlanView/ProjectionScreen/ImageFrame.mesh.surface_get_material(0).emission_enabled = true
			prevcamerasizeforupdateplanviewentitysizes = -1
			set_process(true)
		else:
			$PlanView/ProjectionScreen/ImageFrame.mesh.surface_get_material(0).emission_enabled = false
			set_process(false)

	if "centrelinesvisible" in pvchange:
		planviewcontrols.get_node("CheckBoxCentrelinesVisible").pressed = pvchange["centrelinesvisible"]
		planviewcontrols.get_node("CheckBoxPlanTubesVisible").pressed = pvchange["plantubesvisible"]
		setcameracullmasks(pvchange["centrelinesvisible"], pvchange["plantubesvisible"])
			
	if "backfacecull" in pvchange and (materialsettobackfacecullcartoon != pvchange["backfacecull"] or not backfacecartoonValid):
		var materialsystem = get_node("/root/Spatial/MaterialSystem")
		planviewcontrols.get_node("OptionsBackfaceCull").selected = pvchange["backfacecull"]
		if pvchange["backfacecull"] == 2:
			var tunnelxoutline = sketchsystem.get_node("tunnelxoutline")
			var unifiedclosedmesh = Polynets.unifiedclosedmeshwithnormals(sketchsystem.get_node("XCtubes").get_children(), sketchsystem.get_node("XCdrawings").get_children())
			var blackoutline = tunnelxoutline.get_node("blackoutline")
			var whiteinfill = tunnelxoutline.get_node("whiteinfill")

			blackoutline.mesh = unifiedclosedmesh
			whiteinfill.mesh = unifiedclosedmesh
			settunnelxoutlineshadervalues()
			tunnelxoutline.visible = true
			sketchsystem.get_node("XCtubes").visible = false
			for xcdrawing in sketchsystem.get_node("XCdrawings").get_children():
				if xcdrawing.drawingtype == DRAWING_TYPE.DT_XCDRAWING and xcdrawing.has_node("XCflatshell") and xcdrawing.xcflatshellmaterial != "hole":
					xcdrawing.get_node("XCflatshell").visible = false
				
		else:
			if materialsettobackfacecullcartoon == 2:
				sketchsystem.get_node("tunnelxoutline").visible = false
				sketchsystem.get_node("XCtubes").visible = true
				for xcdrawing in sketchsystem.get_node("XCdrawings").get_children():
					if xcdrawing.drawingtype == DRAWING_TYPE.DT_XCDRAWING and xcdrawing.has_node("XCflatshell") and xcdrawing.xcflatshellmaterial != "hole":
						xcdrawing.get_node("XCflatshell").visible = true
				get_node("/root/Spatial/VerletRopeSystem").update_hangingroperad(sketchsystem, -1.0)

			if pvchange["backfacecull"] == 0:
				materialsystem.setallbackfacecull(SpatialMaterial.CULL_DISABLED)
			if pvchange["backfacecull"] == 1:
				materialsystem.setallbackfacecull(SpatialMaterial.CULL_BACK)
		materialsettobackfacecullcartoon = pvchange["backfacecull"]
		backfacecartoonValid = true
		

	if "realtubesvisible" in pvchange and Tglobal.hidecavewallstoseefloors != (not pvchange["realtubesvisible"]):
		planviewcontrols.get_node("CheckBoxRealTubesVisible").pressed = pvchange["realtubesvisible"]
		Tglobal.hidecavewallstoseefloors = (not pvchange["realtubesvisible"])
		if Tglobal.hidecavewallstoseefloors:
			for xcdrawing in sketchsystem.get_node("XCdrawings").get_children():
				if xcdrawing.drawingtype == DRAWING_TYPE.DT_XCDRAWING:
					xcdrawing.get_node("PathLines").visible = true
					if xcdrawing.has_node("XCflatshell"):
						xcdrawing.get_node("XCflatshell").visible = false
					if xcdrawing.drawingvisiblecode == DRAWING_TYPE.VIZ_XCD_HIDE:
						if not xcdrawing.xcconnectstoshell():
							xcdrawing.setxcdrawingvisiblehideL(false)
				 
			for xctube in sketchsystem.get_node("XCtubes").get_children():
				for xctubesector in xctube.get_node("XCtubesectors").get_children():
					xctubesector.visible = false
				xctube.get_node("PathLines").visible = true
	
		else:
			for xcdrawing in sketchsystem.get_node("XCdrawings").get_children():
				if xcdrawing.drawingtype == DRAWING_TYPE.DT_XCDRAWING:
					xcdrawing.setdrawingvisiblecode(xcdrawing.drawingvisiblecode)
					if xcdrawing.has_node("XCflatshell"):
						xcdrawing.get_node("XCflatshell").visible = true
			for xctube in sketchsystem.get_node("XCtubes").get_children():
				for xctubesector in xctube.get_node("XCtubesectors").get_children():
					xctubesector.visible = true
				xctube.setxctubepathlinevisibility(sketchsystem)

func planviewtransformpos(guidpaneltransform, guidpanelsize):
	var paneltrans = $PlanView.global_transform
	if guidpaneltransform != null:
		paneltrans.origin = guidpaneltransform.origin + guidpaneltransform.basis.y*(guidpanelsize.y/2) + Vector3(0,$PlanView/ProjectionScreen/ImageFrame.mesh.size.y/2,0)
		var eyepos = get_node("/root/Spatial").playerMe.get_node("HeadCam").global_transform.origin
		paneltrans = paneltrans.looking_at(eyepos + 2*(paneltrans.origin-eyepos), Vector3(0, 1, 0))
	else:
		var controllertrans = get_node("/root/Spatial/BodyObjects/LaserOrient").global_transform
		var paneldistance = 1.2 if Tglobal.VRoperating else 0.6
		paneltrans.origin = controllertrans.origin - paneldistance*ARVRServer.world_scale*(controllertrans.basis.z)
		var lookatpos = controllertrans.origin - 1.6*ARVRServer.world_scale*(controllertrans.basis.z)
		paneltrans = paneltrans.looking_at(lookatpos, Vector3(0, 1, 0))
	return paneltrans


func updateplanviewlocatorlines():
	var nodesca = plancamera.size/70.0*3.0
	var labelsca = nodesca*2.0
	sketchsystem.pointersystem.selectlinefatness = nodesca*8.0
	for player in selfSpatial.get_node("Players").get_children():
		var planviewlocatorline = player.get_node("headlocator/planviewlocatorline")
		planviewlocatorline.scale = Vector3(nodesca*3.0, 1, nodesca*3.0)
		if plancamera.rotation_degrees.x == 0.0:
			planviewlocatorline.translation.y = 3.0 + planviewlocatorline.mesh.size.y/2
		else:
			planviewlocatorline.translation.y = max(3.0 + planviewlocatorline.mesh.size.y/2, plancamera.translation.y - 5.0 + planviewlocatorline.mesh.size.y/2 - player.get_node("headlocator").global_transform.origin.y)

var updateplanviewentitysizes_working = false
func updateplanviewentitysizes():
	var Dt0 = OS.get_ticks_msec()
	var nodesca = plancamera.size/70.0*3.0
	var labelsca = nodesca*2.0
	var vertexyinvert = -1.0 if Tglobal.phoneoverlay != null else 1.0
		
	var tunnelxoutline = sketchsystem.get_node("tunnelxoutline")
	if tunnelxoutline.visible:
		var screensize = get_node("/root").size
		var plancameraxvec = plancamera.project_position(screensize/2 + Vector2(1, 0), elevcameradist) - plancamera.project_position(screensize/2, elevcameradist)
		print("plancamera size xvec comparison ", plancameraxvec, " ", plancamera.size, "  ", plancameraxvec/plancamera.size)
		sketchsystem.get_node("tunnelxoutline/blackoutline").material_override.set_shader_param("normaloffsetdistance", nodesca*0.2)
		get_node("/root/Spatial/VerletRopeSystem").update_hangingroperad(sketchsystem, nodesca*0.05)

	get_node("/root/Spatial/LabelGenerator").currentplannodesca = nodesca
	get_node("/root/Spatial/LabelGenerator").currentplanlabelsca = labelsca
	var labelrects = [ ]
	var rectrecttests = 0
	var rectrecttestt0 = OS.get_ticks_msec()
	for xcdrawingcentreline in get_tree().get_nodes_in_group("gpcentrelinegeo"):
		xcdrawingcentreline.updatexcpaths_centreline(xcdrawingcentreline.get_node("PathLines_PlanView"), 0.05*nodesca)
		for xcn in xcdrawingcentreline.get_node("XCnodes_PlanView").get_children():
			xcn.get_node("CollisionShape").scale = Vector3(nodesca, nodesca, nodesca)
			var stationlabel = xcn.get_node("StationLabel")
			stationlabel.get_surface_material(0).set_shader_param("vertex_scale", labelsca)
			stationlabel.get_surface_material(0).set_shader_param("vertexyinvert", vertexyinvert)
			var xcnrect = Rect2(-(xcn.transform.origin.x + 0.15), -xcn.transform.origin.z, stationlabel.mesh.size.x*labelsca, stationlabel.mesh.size.y*labelsca)
			var xcnrect_overlapping = false
			for r in labelrects:
				if xcnrect.intersects(r):
					xcnrect_overlapping = true
					break
				rectrecttests += 1
			xcn.visible = not xcnrect_overlapping
			#xcn.get_node("StationLabel").visible = not xcnrect_overlapping
			#print(xcn.get_name(), " overlapping ", xcnrect_overlapping, " ", xcnrect)
			if not xcnrect_overlapping:
				labelrects.push_back(xcnrect)
			if rectrecttests > 10000:
				print("rectrecttests ", rectrecttests, " ms:", OS.get_ticks_msec() - rectrecttestt0)
				yield(get_tree().create_timer(0.2), "timeout")
				rectrecttests = 0
				rectrecttestt0 = OS.get_ticks_msec()
	print("rectrecttests final ", rectrecttests, " ms:", OS.get_ticks_msec() - rectrecttestt0)
	updateplanviewentitysizes_working = false
	print("updateplanviewent ", OS.get_ticks_msec() - Dt0)


var slowviewportframeratecountdown = 1
var slowviewupdatecentrelinesizeupdaterate = 1.5
var slowviewportframerateenabled = false
var prevcamerasizeforupdateplanviewentitysizes = 0
var lastoptionaltxcdata = { }
func _process(delta):
	if slowviewportframerateenabled and visible:
		slowviewportframeratecountdown -= delta
		if slowviewportframeratecountdown < 0:
			slowviewportframeratecountdown = 1
			$PlanView/Viewport.render_target_update_mode = Viewport.UPDATE_ONCE

	if visible:
		slowviewupdatecentrelinesizeupdaterate -= delta
		if slowviewupdatecentrelinesizeupdaterate < 0 or prevcamerasizeforupdateplanviewentitysizes == -1:
			updateplanviewlocatorlines()
			if prevcamerasizeforupdateplanviewentitysizes != $PlanView/Viewport/PlanGUI/Camera.size and not updateplanviewentitysizes_working:
				prevcamerasizeforupdateplanviewentitysizes = $PlanView/Viewport/PlanGUI/Camera.size
				updateplanviewentitysizes_working = true
				call_deferred("updateplanviewentitysizes")
			slowviewupdatecentrelinesizeupdaterate = 1.6
	
	var planviewpositiondict = { }
	var viewslide = planviewcontrols.get_node("ViewSlide")
	var joypos = Vector3((-1 if viewslide.get_node("ButtonSlideLeft").is_pressed() else 0) + (1 if viewslide.get_node("ButtonSlideRight").is_pressed() else 0), 
						 (-1 if viewslide.get_node("ButtonSlideDown").is_pressed() else 0) + (1 if viewslide.get_node("ButtonSlideUp").is_pressed() else 0),
						 (-1 if viewslide.get_node("ButtonZoomDown").is_pressed() else 0) + (1 if viewslide.get_node("ButtonZoomUp").is_pressed() else 0))
	if joypos != Vector3(0, 0, 0):
		planviewpositiondict["plancamerapos"] = plancamera.translation + delta*(\
					plancamera.transform.basis.x*joypos.x*plancamera.size/2 + \
					plancamera.transform.basis.y*joypos.y*plancamera.size/2 + \
					plancamera.transform.basis.z*joypos.z*5)
	var zoomview = planviewcontrols.get_node("ZoomView")
	var bzoomin = zoomview.get_node("ButtonZoomIn").is_pressed()
	var bzoomout = zoomview.get_node("ButtonZoomOut").is_pressed()
	if bzoomin or bzoomout:
		var zoomfac = 1/(1 + 0.5*delta) if bzoomin else 1 + 0.5*delta
		planviewpositiondict["plancamerasize"] = plancamera.size * zoomfac

	var brotleft = viewslide.get_node("ButtonRotLeft").is_pressed()
	var brotright = viewslide.get_node("ButtonRotRight").is_pressed()
	if brotleft or brotright:
		var droty = (-1 if brotleft else 1)*delta*60
		planviewpositiondict["plancamerarotation"] = plancamera.rotation_degrees + Vector3(0, droty, 0.0)
		if plancamera.rotation_degrees.x == 0.0:
			planviewpositiondict["plancamerapos"] = planviewpositiondict.get("plancamerapos",  plancamera.translation) + \
													(1 - cos(droty))*plancamera.transform.basis.z + \
													sin(droty)*plancamera.transform.basis.x 

	if planviewcontrols.get_node("ViewSlide/ButtonFollow").is_pressed():
		if planviewpositiondict.empty():
			var headcam = selfSpatial.playerMe.get_node("HeadCam")
			var lelevrotpoint = headcam.global_transform.origin
			lelevrotpoint -= plancamera.transform.basis.y*(plancamera.size*cameracentreyposfraction)
			var cameradistvec = plancamera.translation - lelevrotpoint
			var lelevcameradist = plancamera.transform.basis.z.dot(cameradistvec)
			lelevcameradist = clamp(5, 60, lelevcameradist)
			planviewpositiondict["plancamerapos"] = lelevrotpoint + plancamera.transform.basis.z*lelevcameradist
			if plancamera.rotation_degrees.x == 0.0:
				var PlayerDirections = get_node("/root/Spatial/BodyObjects/PlayerDirections")
				if PlayerDirections.colocatedflagtrail != null:
					var plancamerarotationdegreesy = plancamera.rotation_degrees.y
					var ftpindex = PlayerDirections.colocatedflagtrail["ftpindex"]
					var vtvec = PlayerDirections.colocatedflagtrail["flagtrailpoints"][ftpindex+1] - PlayerDirections.colocatedflagtrail["flagtrailpoints"][ftpindex]
					var vtvec2 = Vector2(vtvec.x, vtvec.z)
					if vtvec2.length() > 0.5:
						var a = plancamerarotationdegreesy - (floor(plancamerarotationdegreesy/360)*360)
						var x = rad2deg(vtvec2.angle())
						if x > 180:
							x -= 180
						if abs(x + 360 - a) < abs(x + 180 - a):
							x += 360
						if abs(x + 180 - a) < abs(x - a):
							x += 180
						var da = delta*10
						if abs(x - a) > da*1.1:
							a += da if x > a else -da
						else:
							a = x
						plancamerarotationdegreesy = a
						var plancamerabasisy = Vector3(-sin(deg2rad(plancamerarotationdegreesy)), 0.0, -cos(deg2rad(plancamerarotationdegreesy)))
						planviewpositiondict["plancamerapos"] = lelevrotpoint - plancamerabasisy*elevcameradist
						planviewpositiondict["plancamerarotation"] = Vector3(0, plancamerarotationdegreesy, 0)
			planviewpositiondict["plancameraelevrotpoint"] = lelevrotpoint 

	if not planviewpositiondict.empty():
		actplanviewdict(planviewpositiondict) 

	if activetargetfloor != null:
		var floortrim = planviewcontrols.get_node("FloorTrim")
		var joypostrimld = Vector2((-1 if floortrim.get_node("ButtonTrimLeftLeft").is_pressed() else 0) + (1 if floortrim.get_node("ButtonTrimLeftRight").is_pressed() else 0), 
								   (-1 if floortrim.get_node("ButtonTrimDownDown").is_pressed() else 0) + (1 if floortrim.get_node("ButtonTrimDownUp").is_pressed() else 0))
		var joypostrimru = Vector2((-1 if floortrim.get_node("ButtonTrimRightLeft").is_pressed() else 0) + (1 if floortrim.get_node("ButtonTrimRightRight").is_pressed() else 0), 
								   (-1 if floortrim.get_node("ButtonTrimUpDown").is_pressed() else 0) + (1 if floortrim.get_node("ButtonTrimUpUp").is_pressed() else 0))
		var floormove = planviewcontrols.get_node("FloorMove")
		var joyposmove = Vector3((-1 if floormove.get_node("ButtonMoveLeft").is_pressed() else 0) + (1 if floormove.get_node("ButtonMoveRight").is_pressed() else 0), 
								 0.5*(-1 if floormove.get_node("ButtonMoveFall").is_pressed() else 0) + (1 if floormove.get_node("ButtonMoveRise").is_pressed() else 0),
								 (1 if floormove.get_node("ButtonMoveDown").is_pressed() else 0) + (-1 if floormove.get_node("ButtonMoveUp").is_pressed() else 0))
		var joygrow = (-1 if floormove.get_node("ButtonShrink").is_pressed() else 0) + (1 if floormove.get_node("ButtonGrow").is_pressed() else 0)
		if len(activetargetfloor.nodepoints) != 0:
			joyposmove.x = 0
			joyposmove.z = 0
			joygrow = 0
		if joypostrimld != Vector2(0,0) or joypostrimru != Vector2(0,0) or joyposmove != Vector3(0,0,0) or joygrow != 0:
			if "name" in lastoptionaltxcdata and lastoptionaltxcdata["name"] != activetargetfloor.get_name():
				sketchsystem.actsketchchange([lastoptionaltxcdata])
				lastoptionaltxcdata.clear()
			var txcdata = { "name":activetargetfloor.get_name(), 
							"rpcoptional":1,
							"timestamp":OS.get_ticks_msec()*0.001 }
			lastoptionaltxcdata["name"] = txcdata["name"]
			lastoptionaltxcdata["timestamp"] = txcdata["timestamp"]

			var d = activetargetfloor
			var sfac = delta*8
			if joyposmove != Vector3(0,0,0):
				txcdata["prevtransformpos"] = d.transform
				txcdata["transformpos"] = Transform(d.transform.basis, d.transform.origin + Basis()*joyposmove*delta*8)
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
								
			sketchsystem.actsketchchange([txcdata])
		elif "name" in lastoptionaltxcdata:
			print("sending lastoptionaltxcdata ", lastoptionaltxcdata["name"])
			sketchsystem.actsketchchange([lastoptionaltxcdata])
			lastoptionaltxcdata.clear()



func setfloortrimmode(floorstyleid, floorlabel):
	var pvisible = (floorstyleid != -1)
	planviewcontrols.get_node("FloorMove/FloorStyle").selected = max(0, floorstyleid)
	planviewcontrols.get_node("ColorRectURL/LabelXCresource").text = floorlabel
	planviewcontrols.get_node("ColorRectURL").visible = pvisible
	planviewcontrols.get_node("FloorTrim").visible = pvisible
	planviewcontrols.get_node("FloorMove").visible = pvisible
	planviewcontrols.get_node("PathFollow").visible = not pvisible

	
func buttonfollow_toggled(button_pressed):
	planviewcontrols.get_node("ViewSlide/ButtonSlideDown").disabled = button_pressed
	planviewcontrols.get_node("ViewSlide/ButtonSlideLeft").disabled = button_pressed
	planviewcontrols.get_node("ViewSlide/ButtonSlideRight").disabled = button_pressed
	planviewcontrols.get_node("ViewSlide/ButtonSlideUp").disabled = button_pressed

const cameracentreyposfraction = 0.06	
func buttoncentre_pressed():
	var headcam = get_node("/root/Spatial").playerMe.get_node("HeadCam")
	var lelevrotpoint = headcam.global_transform.origin
	lelevrotpoint -= plancamera.transform.basis.y*(plancamera.size*cameracentreyposfraction)
	var cameradistvec = plancamera.translation - lelevrotpoint
	var lelevcameradist = plancamera.transform.basis.z.dot(cameradistvec)
	lelevcameradist = clamp(5, 60, lelevcameradist)
	
	var planviewpositiondict = { "plancamerapos":lelevrotpoint + plancamera.transform.basis.z*lelevcameradist, 
								 "plancameraelevrotpoint":lelevrotpoint, 
								 "plancameraelevcameradist":lelevcameradist,
								 "plancamerafogdepthbegin":lelevcameradist*2, 
								 "plancamerafogdepthend":lelevcameradist*4 
							   }
	actplanviewdict(planviewpositiondict) 


var elevrotpoint = Vector3(0,0,0)
var elevcameradist = 50.0
func buttonelev_toggled(makeelevmode):
	print("buttonelev_toggled ", makeelevmode)
	var headcam = get_node("/root/Spatial").playerMe.get_node("HeadCam")
	var screensize = get_node("/root").size
	var plancamerabasisy = Vector3(-sin(deg2rad(plancamera.rotation_degrees.y)), 0.0, -cos(deg2rad(plancamera.rotation_degrees.y)))
	if makeelevmode:
		var elevrotpointy = elevrotpoint.y if elevrotpoint != null else headcam.global_transform.origin.y
		var lelevrotpoint = plancamera.project_position(screensize/2, 0.0)
		lelevrotpoint.y = elevrotpointy
		var pagebottompos = plancamera.project_position(Vector2(screensize.x/2, screensize.y), 0.0)
		var vpagebottom = pagebottompos - plancamera.global_transform.origin
		var lelevcameradist = -plancamera.global_transform.basis.y.dot(vpagebottom)
		#print("bb should be same ", plancamera.global_transform.basis.y, plancamerabasisy)
		var planviewpositiondict = { "plancamerapos":elevrotpoint - plancamerabasisy*elevcameradist, 
									 "plancamerarotation":Vector3(0, plancamera.rotation_degrees.y, 0),
									 "plancameraelevrotpoint":lelevrotpoint, 
									 "plancameraelevcameradist":lelevcameradist,
									 "plancamerafogdepthbegin":lelevcameradist, 
									 "plancamerafogdepthend":lelevcameradist*2, 
								   }
		actplanviewdict(planviewpositiondict) 

	else:
		var lelevrotpoint = plancamera.translation + plancamerabasisy*elevcameradist
		var pagetoppos = plancamera.project_position(Vector2(screensize.x/2, 0.0), 0.0)
		var lelevcameradist = pagetoppos.y - elevrotpoint.y
		var planviewpositiondict = { "plancamerapos":Vector3(elevrotpoint.x, pagetoppos.y, elevrotpoint.z), 
									 "plancamerarotation":Vector3(-90, plancamera.rotation_degrees.y, 0), 
									 "plancameraelevrotpoint":lelevrotpoint, 
									 "plancameraelevcameradist":lelevcameradist,
									 "plancamerafogdepthbegin":lelevcameradist*2, 
									 "plancamerafogdepthend":lelevcameradist*4, 
								 }
		actplanviewdict(planviewpositiondict) 

	
func buttonclose_pressed():
	if planviewcontrols.get_node("ButtonTransmitView").pressed:
		sketchsystem.actsketchchange([ {"planview":{"visible":false, "planviewactive":false}} ])
	else:
		actplanviewdict({"visible":false, "planviewactive":false}) 


func checkplanviewinfront(handrightcontroller):
	var planviewsystem = self
	var collider_transform = planviewsystem.get_node("PlanView").global_transform
	return collider_transform.xform_inv(handrightcontroller.global_transform.origin).z > 0

func checkinguipanel(lviewport_point):
	var rectrel = lviewport_point - planviewcontrols.rect_position
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
var raycastcollisionpointC = Vector3(0,0,0)
func processplanviewpointing(raycastcollisionpoint, controller_trigger):
	var planviewsystem = self
	var collider_transform = planviewsystem.get_node("PlanView").global_transform
	var shape_size = planviewsystem.get_node("PlanView/CollisionShape").shape.extents * 2
	var collider_scale = collider_transform.basis.get_scale()
	raycastcollisionpointC = raycastcollisionpoint
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
			print("pg mouse down ", event.pressed)
	else:
		planviewguipanelreleasemouse()
		var laspt = plancamera.project_position(viewport_point, 0.0)
		planviewsystem.get_node("RealPlanCamera/LaserScope").global_transform.origin = laspt
		planviewsystem.get_node("RealPlanCamera/LaserScope").visible = true
		planviewsystem.get_node("RealPlanCamera/LaserScope/LaserOrient/RayCast").force_raycast_update()
	return inguipanel
	
func planviewguipanelreleasemouse():
	if viewport_mousedown:
		var event = InputEventMouseButton.new()
		event.button_index = BUTTON_LEFT
		event.position = viewport_point
		event.pressed = false
		$PlanView/Viewport.input(event)
		viewport_mousedown = false
	var event = InputEventMouseMotion.new()
	event.position = Vector2(0,0)
	$PlanView/Viewport.input(event)

# this should be transmitted with planview transmit stuff
var activecentrelinexcname = ""
func updatecentrelineactivityui():
	var CentrelineList = $PlanView/Viewport/PlanGUI/PlanViewControls/CentrelineActivity/CentrelineList
	var selectedcentrelinexcname = CentrelineList.get_item_text(CentrelineList.selected) if CentrelineList.selected != -1 else ""
	CentrelineList.clear()
	CentrelineList.add_item("--none--")
	var selectedcentrelinexcnameIndex = 0
	for lxcdrawingcentreline in get_tree().get_nodes_in_group("gpcentrelinegeo"):
		CentrelineList.add_item(lxcdrawingcentreline.get_name())
		if lxcdrawingcentreline.get_name() == selectedcentrelinexcname or lxcdrawingcentreline.get_name() == activecentrelinexcname:
			selectedcentrelinexcnameIndex = CentrelineList.get_item_count()-1
	CentrelineList.select(selectedcentrelinexcnameIndex)

func centrelineactivityoptions_selected(index):
	var CentrelineList = $PlanView/Viewport/PlanGUI/PlanViewControls/CentrelineActivity/CentrelineList
	var selectedcentrelinexcname = CentrelineList.get_item_text(CentrelineList.selected) if CentrelineList.selected != -1 else ""
	if index == 1:
		activecentrelinexcname = selectedcentrelinexcname if selectedcentrelinexcname != "--none--" else ""
	elif index == 0 and activecentrelinexcname == selectedcentrelinexcname:
		activecentrelinexcname = ""
	elif index == 2:
		var rotzminus90 = Basis(Vector3(1,0,0), Vector3(0,0,-1), Vector3(0,1,0))
		var bbcenvec = Vector3()
		var centrelinetransformpos = Transform(rotzminus90, -rotzminus90.xform(bbcenvec))
		var xcdata = { "name":sketchsystem.uniqueXCname("plansketch"), 
					   "drawingtype":DRAWING_TYPE.DT_CENTRELINE,
					   "drawingvisiblecode":DRAWING_TYPE.VIZ_XCD_PLANE_AND_NODES_VISIBLE,
					   "transformpos":centrelinetransformpos, 
					   "nodepoints":{}, 
					   "onepathpairs":[]
					 }
		activecentrelinexcname = xcdata["name"]
		sketchsystem.actsketchchange([ xcdata ])
		centrelineactivitylist_selected(CentrelineList.selected)
	
func centrelineactivitylist_selected(index):
	var CentrelineList = $PlanView/Viewport/PlanGUI/PlanViewControls/CentrelineActivity/CentrelineList
	var selectedcentrelinexcname = CentrelineList.get_item_text(CentrelineList.selected) if CentrelineList.selected != -1 else ""
	var OptionsCentreline = $PlanView/Viewport/PlanGUI/PlanViewControls/CentrelineActivity/OptionsCentreline
	OptionsCentreline.select(1 if selectedcentrelinexcname == activecentrelinexcname else 0)


# * keyboard to work on phone overlay mode
# * root of tree should give URL of the tree
# * flag when the root of tree is localhost
# * create/delete/clear directory from the menu controls when the FileTree is open
# * Selected cleared directory in mode to allow (or continue) upload
# * upload locally and through ENET, using ab and seek values
# * When laz file is done, option to process into images using python laspy
# * images will then be imported as a batch

func applyfilecommand(localfname, filecommand):
	# file/dirname : newcave/newdir/cleardir/deletedir/upload/rename	
	print("FILECOMMAND: ", filecommand, " ", localfname)
	


	
