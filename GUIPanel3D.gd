extends StaticBody


var collision_point := Vector3(0, 0, 0)
var current_viewport_mousedown = false
var viewport_point = Vector2(0, 0)

onready var sketchsystem = get_node("/root/Spatial/SketchSystem")
onready var playerMe = get_node("/root/Spatial/Players/PlayerMe")
onready var selfSpatial = get_node("/root/Spatial")
onready var virtualkeyboard = get_node("/root/Spatial/GuiSystem/KeyboardPanel")

var regexacceptableprojectname = RegEx.new()
var regexjsontripleflattener = RegEx.new()


# ln -s /home/julian/data/NorthernEngland/PeakDistrict/tunnelvrdata/cavefiles /home/julian/.local/share/godot/app_userdata/tunnelvr_v0.6/cavefiles
var cavefilesdir = "user://cavefiles/"

func _on_buttonload_pressed():
	var savegamefileid = $Viewport/GUI/Panel/Savegamefilename.get_selected_id()
	var savegamefilestring = $Viewport/GUI/Panel/Savegamefilename.get_item_text(savegamefileid)
	if savegamefilestring == "--clearcave":
		sketchsystem.loadsketchsystemL("clearcave")
		setpanellabeltext("Clearing cave")
		return
	var savegamefilestringL = savegamefilestring.split(":")
	var savegamefilename = savegamefilestringL[-1].strip_edges().lstrip("*#")
	var GithubAPI = get_node("/root/Spatial/ImageSystem/GithubAPI")
	var giattributesname = savegamefilestringL[0].strip_edges() if len(savegamefilestringL) == 2 else GithubAPI.ghattributes.get("name")
	var lghattributes = GithubAPI.riattributes.get("resourcedefs", {}).get(giattributesname, {})
	if lghattributes.get("type"):
		Tglobal.soundsystem.quicksound("MenuClick", collision_point)
		setpanellabeltext("Fetching file")
		if lghattributes["type"] != "localfiles" and GithubAPI.ghattributes["name"] != lghattributes["name"]:
			setpanellabeltext("ghattributes must match prefix")
		elif yield(GithubAPI.Yloadcavefile(lghattributes, savegamefilename), "completed"):
			setguipanelhide()
		else:
			setpanellabeltext("Fetch failed: "+lghattributes.get("name", ""))
		Yupdatecavefilelist()
		
	else:
		setpanellabeltext("Cannot do")
	
remote func setpanellabeltext(ltext):
	print("setpanellabeltext: ", ltext)
	$Viewport/GUI/Panel/Label.text = ltext
			
remote func setsavegamefilename(cfile):
	print(" setsavegamefilename ", cfile)
	if cfile == "recgithubfile":
		return
	sketchsystem.sketchname = cfile
	var snames = $Viewport/GUI/Panel/Savegamefilename
	for i in range(snames.get_item_count()):
		var savegamefilestring = snames.get_item_text(i)
		var savegamefilename = savegamefilestring.split(":", true, 1)[-1].strip_edges().lstrip("*#")
		if cfile == savegamefilename:
			snames.select(i)
			return
	var GithubAPI = get_node("/root/Spatial/ImageSystem/GithubAPI")
	snames.add_item(GithubAPI.ghattributes["name"]+": *"+cfile)
	snames.select(snames.get_item_count() - 1)
	
func _on_buttonsave_pressed():
	var GithubAPI = get_node("/root/Spatial/ImageSystem/GithubAPI")
	var snames = $Viewport/GUI/Panel/Savegamefilename
	var savegamefileid = snames.get_selected_id()
	var savegamefilestring = snames.get_item_text(savegamefileid)
	if savegamefilestring == "--clearcave":
		setpanellabeltext("Cannot oversave clearcave")
		return
	var savegamefilenameL = savegamefilestring.split(":", true, 1)
	var savegamefileresource = savegamefilenameL[0].strip_edges() if len(savegamefilenameL) == 2 else GithubAPI.ghattributes["name"]
	var savegamefilename = savegamefilenameL[-1].strip_edges()
	var bfileisnew = savegamefilename[0] == "*"
	savegamefilename = savegamefilename.lstrip("*#")
	if GithubAPI.ghattributes["name"] == savegamefileresource:
		setpanellabeltext("Saving file")
		var ltext = yield(GithubAPI.Ysavecavefile(savegamefilename, bfileisnew), "completed")
		setpanellabeltext(ltext)
		Yupdatecavefilelist()
	else:
		setpanellabeltext("Cannot do")
	Tglobal.soundsystem.quicksound("MenuClick", collision_point)
	

func _on_buttonplanview_pressed():
	var button_pressed = $Viewport/GUI/Panel/ButtonPlanView.pressed
	var planviewsystem = get_node("/root/Spatial/PlanViewSystem")
	if button_pressed:
		var pvchange = planviewsystem.planviewtodict()
		pvchange["visible"] = true
		pvchange["planviewactive"] = true
		var guidpaneltransform = global_transform
		var guidpanelsize = $Quad.mesh.size
		setguipanelhide()
		if not Tglobal.controlslocked:
			guidpaneltransform = null
		pvchange["transformpos"] = planviewsystem.planviewtransformpos(guidpaneltransform, guidpanelsize)
		planviewsystem.actplanviewdict(pvchange)
		$Viewport/GUI/Panel/Label.text = "Planview on"
	else:
		planviewsystem.buttonclose_pressed()
		$Viewport/GUI/Panel/Label.text = "Planview off"

	Tglobal.soundsystem.quicksound("MenuClick", collision_point)
	setguipanelhide()
	
func _on_buttonheadtorch_toggled(button_pressed):
	playerMe.setheadtorchlight(button_pressed)
	$Viewport/GUI/Panel/Label.text = "Headtorch on" if button_pressed else "Headtorch off"
	setguipanelhide()

func _on_buttondoppelganger_toggled(button_pressed):
	playerMe.setdoppelganger(button_pressed)
	$Viewport/GUI/Panel/Label.text = "Doppelganger on" if button_pressed else "Doppelganger off"
	setguipanelhide()

func _on_playerscale_selected(index):
	var splayerscale = $Viewport/GUI/Panel/WorldScale.get_item_text(index)
	var newplayerscale = float(splayerscale)
	var oldplayerscale = playerMe.playerscale
	print("transorig ", playerMe.get_node("HeadCam").transform.origin)
	var headcamvec = playerMe.get_node("HeadCam").transform.origin
	var newplayermetransformheadfixed = playerMe.transform.origin + headcamvec - headcamvec*newplayerscale/oldplayerscale
	ARVRServer.world_scale = newplayerscale
	playerMe.playerscale = newplayerscale
	playerMe.get_node("HandLeft").setcontrollerhandtransform(playerMe.playerscale)
	playerMe.get_node("HandRight").setcontrollerhandtransform(playerMe.playerscale)
	var PlayerDirections = get_node("/root/Spatial/BodyObjects/PlayerDirections")
	var PlayerMotion = get_node("/root/Spatial/BodyObjects/PlayerMotion")
	var pscavec = Vector3(playerMe.playerscale, playerMe.playerscale, playerMe.playerscale)
	PlayerMotion.get_node("PlayerKinematicBody").scale = pscavec
	PlayerMotion.get_node("PlayerEnlargedKinematicBody").scale = pscavec
	PlayerMotion.get_node("PlayerHeadKinematicBody").scale = pscavec
	playerMe.playerghostphysics = (splayerscale.count("ghost") != 0)
	if playerMe.playerscale == 1.0:
		playerMe.transform.origin = newplayermetransformheadfixed + Vector3(0,2,0)
		PlayerDirections.forceontogroundtimedown = 0.75
		PlayerDirections.floorprojectdistance = 50
		playerMe.playerflyscale = 1.0
		playerMe.playerwalkscale = 1.0

	elif playerMe.playerscale < 1.0:
		playerMe.transform.origin = newplayermetransformheadfixed
		PlayerDirections.forceontogroundtimedown = 0.75
		PlayerDirections.floorprojectdistance = 5
		playerMe.playerflyscale = (playerMe.playerscale+1.0)*0.5
		playerMe.playerwalkscale = (playerMe.playerscale*2+1.0)/3

	else:
		playerMe.transform.origin = newplayermetransformheadfixed
		if playerMe.playerscale >= 10:
			playerMe.playerflyscale = playerMe.playerscale*0.2
		else:
			playerMe.playerflyscale = playerMe.playerscale*0.75
		playerMe.playerwalkscale = 1.0
	setguipanelhide()




func objsinglesurface(joff, fout, sname, mesh, transform, materialsystem, materialdict, xcmaterialname):
	if not materialdict.has(xcmaterialname):
		 materialdict[xcmaterialname] = materialsystem.tubematerial(xcmaterialname, false)
	var uvscale = materialdict[xcmaterialname].uv1_scale
	var sarrays = mesh.surface_get_arrays(0)
	if len(sarrays) == 0:
		return joff
	fout.store_line(sname)
	for p in sarrays[0]:
		var tp = transform.xform(p)
		fout.store_line("v %f %f %f"%[tp.x, tp.y, tp.z])
	for n in sarrays[4]:
		fout.store_line("vt %f %f"%[n.x*uvscale.x, n.y*uvscale.y])
	fout.store_line("usemtl %s"%xcmaterialname)
	fout.store_line("s off")
	for j in range(0, len(sarrays[0]), 3):
		fout.store_line("f %d/%d %d/%d %d/%d"%[j+joff,j+joff,  j+joff+1,j+joff+1,  j+joff+2,j+joff+2])
	joff += len(sarrays[0])
	return joff


func exportOBJ():
	if not Directory.new().dir_exists("user://objexport"):
		Directory.new().make_dir("user://objexport")
	var fobjname = "user://objexport/cave.obj"
	var fmtlname = "user://objexport/cave.mtl"
	var fout = File.new()
	fout.open(fobjname, File.WRITE)
	fout.store_line("mtllib cave.mtl")
	var materialsystem = get_node("/root/Spatial/MaterialSystem")
	var materialdict = { }
	var joff = 1
	for xctube in sketchsystem.get_node("XCtubes").get_children():
		for i in range(xctube.get_node("XCtubesectors").get_child_count()):
			var xctubesector = xctube.get_node("XCtubesectors").get_child(i)
			var xcmaterialname = xctube.xcsectormaterials[i]
			var mesh = xctubesector.get_node("MeshInstance").mesh
			var sname = "o %s_%d"%[xctube.get_name(), i]
			if xcmaterialname != "hole":
				joff = objsinglesurface(joff, fout, sname, mesh, Transform(), materialsystem, materialdict, xcmaterialname)

	materialdict["rope"] = materialsystem.pathlinematerial("rope")
	for xcdrawing in sketchsystem.get_node("XCdrawings").get_children():
		if xcdrawing.has_node("XCflatshell") and (xcdrawing.drawingtype == DRAWING_TYPE.DT_ROPEHANG or xcdrawing.drawingtype == DRAWING_TYPE.DT_XCDRAWING):
			var mesh = xcdrawing.get_node("XCflatshell/MeshInstance").mesh
			var sname = "o %s"%[xcdrawing.get_name()]
			if xcdrawing.xcflatshellmaterial != "hole":
				joff = objsinglesurface(joff, fout, sname, mesh, xcdrawing.transform, materialsystem, materialdict, xcdrawing.xcflatshellmaterial)

		elif xcdrawing.drawingtype == DRAWING_TYPE.DT_ROPEHANG:
			var uvscale = materialdict["rope"].uv1_scale
			fout.store_line("o %s"%[xcdrawing.get_name()])
			var mesh = xcdrawing.get_node("RopeHang/RopeMesh").mesh
			if mesh != null:
				var sarrays = mesh.surface_get_arrays(0)
				for p in sarrays[0]:
					fout.store_line("v %f %f %f"%[p.x, p.y, p.z])
				for n in sarrays[4]:
					fout.store_line("vt %f %f"%[n.x*uvscale.x, n.y*uvscale.y])
				fout.store_line("usemtl %s"%"rope")
				for j in range(0, len(sarrays[8]), 3):
					fout.store_line("f %d/%d %d/%d %d/%d"%[sarrays[8][j]+joff,sarrays[8][j]+joff,  sarrays[8][j+1]+joff,sarrays[8][j+1]+joff,  sarrays[8][j+2]+joff,sarrays[8][j+2]+joff])
				joff += len(sarrays[0])
				

			
	fout.close()
	print("exported to ", OS.get_user_data_dir(), "/objexport")

	var fmtl = File.new()
	fmtl.open(fmtlname, File.WRITE)
	var textureroot = "res://lightweighttextures/"
	for materialname in materialdict:
		var mat = materialdict[materialname]
		fmtl.store_line("newmtl %s"%materialname)
		fmtl.store_line("  Ka %f %f %f"%[mat.albedo_color.r, mat.albedo_color.g, mat.albedo_color.b])
		fmtl.store_line("  Kd %f %f %f"%[mat.albedo_color.r, mat.albedo_color.g, mat.albedo_color.b])
		fmtl.store_line("  Ks %f %f %f"%[mat.metallic, mat.metallic, mat.metallic])
		fmtl.store_line("  Ns %f"%101)
		if mat.albedo_texture:
			if mat.albedo_texture.resource_path.begins_with(textureroot):
				fmtl.store_line("  map_Kd %s"%mat.albedo_texture.resource_path.replace(textureroot, ""))
		fmtl.store_line("  illum 2")
		fmtl.store_line("")
	fmtl.close()
	

func exportSTL():
	var fname = "user://export.stl"
	var vfaces = [ ]
	var vmathashs = [ ]
	var nfaces = 0
	for xctube in sketchsystem.get_node("XCtubes").get_children():
		for i in range(xctube.get_node("XCtubesectors").get_child_count()):
			var xctubesector = xctube.get_node("XCtubesectors").get_child(i)
			var xcmaterial = xctube.xcsectormaterials[i]
			if xcmaterial != "hole":
				var xcmathash = hash(xcmaterial)
				var mesh = xctubesector.get_node("MeshInstance").mesh
				var g = mesh.get_surface_count()
				var x = mesh.surface_get_arrays(0)
				if i == 0:
					print(x, g)
				var faces = mesh.get_faces()
				vfaces.append(faces)
				vmathashs.append(xcmathash)
				nfaces += int(len(faces)/3)

	var fout = File.new()
	fout.open(fname, File.WRITE)
	var header = "TunnelVR out".to_utf8()
	while len(header) < 80:
		header.append(0x20)
	fout.store_buffer(header)
	fout.store_32(nfaces)
	for faces in vfaces:
		for i in range(0, len(faces), 3):
			var n = Vector3(0,0,1)
			fout.store_float(n.x); fout.store_float(-n.z); fout.store_float(n.y)
			fout.store_float(faces[i].x); fout.store_float(-faces[i].z); fout.store_float(faces[i].y)
			fout.store_float(faces[i+1].x); fout.store_float(-faces[i+1].z); fout.store_float(faces[i+1].y)
			fout.store_float(faces[i+2].x); fout.store_float(-faces[i+2].z); fout.store_float(faces[i+2].y)
			fout.store_16(vmathashs[int(i/3)]%65536)
	fout.close()
	print("saved ", fname, " in C:/Users/ViveOne/AppData/Roaming/Godot/app_userdata/tunnelvr")
	$Viewport/GUI/Panel/Label.text = "Cave exported"

var prevnssel = "normal"
func _on_switchtest(index):
	var SwitchTest = $Viewport/GUI/Panel/SwitchTest
	var nssel = SwitchTest.get_item_text(index)
	print(" _on_switchtest ", nssel, " ", index)

	if prevnssel == "choke":
		makechoke(false)
	elif prevnssel == "lock controls":
		Tglobal.controlslocked = false
		Tglobal.soundsystem.quicksound("MenuClick", collision_point)
		
	if nssel == "export STL":
		exportSTL()
		$Viewport/GUI/Panel/Label.text = "STL exported"
		SwitchTest.selected = 0

	elif nssel == "export OBJ":
		exportOBJ()
		$Viewport/GUI/Panel/Label.text = "OBJ exported"
		SwitchTest.selected = 0
		
	elif nssel == "CL_common_root":
		for xcdrawingcentreline in get_tree().get_nodes_in_group("gpcentrelinegeo"):
			if xcdrawingcentreline.additionalproperties == null:
				xcdrawingcentreline.additionalproperties = { "stationnamecommonroot":Centrelinedata.findcommonroot(xcdrawingcentreline.nodepoints) }
		SwitchTest.selected = 0

	elif nssel == "toggle guardian":
		var guardianpolyvisible = not playerMe.get_node("GuardianPoly").visible
		setguardianstate(guardianpolyvisible)
		if Tglobal.connectiontoserveractive:
			rpc("setguardianstate", guardianpolyvisible)
		SwitchTest.selected = 0
		
	elif nssel == "choke":
		$Viewport/GUI/Panel/Label.text = "Boulder choke!"
		makechoke(true)
		setguipanelhide()

	elif nssel == "toggle gltf":
		$Viewport/GUI/Panel/Label.text = "toggle gltf"
		togglegltf()
		setguipanelhide()


	elif nssel == "swap controllers":
		playerMe.swapcontrollers()
		$Viewport/GUI/Panel/Label.text = "Controllers swapped"
		Tglobal.soundsystem.quicksound("MenuClick", collision_point)
		setguipanelhide()
		SwitchTest.selected = 0
		
	elif nssel == "lock controls":
		Tglobal.controlslocked = true
		Tglobal.soundsystem.quicksound("MenuClick", collision_point)		
		
	elif nssel == "Hide XCs":
		Tglobal.soundsystem.quicksound("MenuClick", collision_point)
		var xcvizstates = { }
		for xcdrawing in sketchsystem.get_node("XCdrawings").get_children():
			if xcdrawing.drawingtype == DRAWING_TYPE.DT_XCDRAWING:
				if xcdrawing.xcconnectstoshell():
					if xcdrawing.drawingvisiblecode != DRAWING_TYPE.VIZ_XCD_HIDE:
						xcvizstates[xcdrawing.get_name()] = DRAWING_TYPE.VIZ_XCD_HIDE
				else:
					if xcdrawing.drawingvisiblecode == DRAWING_TYPE.VIZ_XCD_HIDE:
						xcvizstates[xcdrawing.get_name()] = DRAWING_TYPE.VIZ_XCD_NODES_VISIBLE
		sketchsystem.actsketchchange([{ "xcvizstates":xcvizstates }])
		setguipanelhide()
		SwitchTest.selected = 0
		
	elif nssel == "Toggle Fog":
		playerMe.togglefog()
		SwitchTest.selected = 0

	elif nssel == "Huge Spiral":
		var xcrad = 1.5
		var Nxcnodes = 23
		var spiralrad = 8.0
		var spiralradshrink = 2.0
		var spiralangstep = 11.0
		var spiralzfac = 2.5/360
		var Nxcplanes = 373

		xcrad = 0.3
		spiralrad = 1.5
		spiralradshrink = 1.0
		spiralangstep = 11.0
		spiralzfac = 0.35/360


		var conepathpairs = [ ]
		var cnodepoints = { }
		for i in range(Nxcnodes):
			var d = 360.0*i/Nxcnodes
			cnodepoints["n%d" % i] = Vector3(cos(deg2rad(d))*xcrad, sin(deg2rad(d))*xcrad, 0.0)
			conepathpairs.push_back("n%d" % i)
			conepathpairs.push_back("n%d" % ((i+1)%Nxcnodes))
		var tubemats = [ "pebbles", "simpledirt", "bluewater", "calcite" ]
		var tnewdrawinglinks = [ ]
		var tubesectorstep = 5
		for i in range(0, Nxcnodes, tubesectorstep):
			tnewdrawinglinks.append_array([ "n%d"%i, "n%d"%i, tubemats[(i/tubesectorstep)%len(tubemats)], null ])

		var prevxcname = null
		for j in range(Nxcplanes):
			var ang = j*spiralangstep
			var lspiralrad = spiralrad - spiralradshrink*j/Nxcplanes
			var pt0 = playerMe.get_node("HeadCam").global_transform.origin + Vector3(cos(deg2rad(ang))*lspiralrad, ang*spiralzfac + xcrad + 0.2, sin(deg2rad(ang))*lspiralrad)
			var xcdata = { "name":sketchsystem.uniqueXCname("s"), 
						   "drawingtype":DRAWING_TYPE.DT_XCDRAWING,
						   "drawingvisiblecode":DRAWING_TYPE.VIZ_XCD_PLANE_AND_NODES_VISIBLE,
						   "transformpos":Transform(Basis().rotated(Vector3(0,-1,0), deg2rad(ang)), pt0), 
						   "nodepoints":cnodepoints, 
						   "onepathpairs":conepathpairs }

			var xcviz = { "xcvizstates": { xcdata["name"]:DRAWING_TYPE.VIZ_XCD_PLANE_AND_NODES_VISIBLE } }
			sketchsystem.actsketchchange([ xcdata, xcviz ])
			if prevxcname != null:
				var xctdata = { "tubename":"**notset", 
								 "xcname0":prevxcname,
								 "xcname1":xcdata["name"],
								 "prevdrawinglinks":[], 
								 "newdrawinglinks":tnewdrawinglinks.duplicate() }
				sketchsystem.setnewtubename(xctdata)
				#var finishedplanedrawingtype =  DRAWING_TYPE.VIZ_XCD_HIDE
				var finishedplanedrawingtype =  DRAWING_TYPE.VIZ_XCD_NODES_VISIBLE
				#var finishedplanedrawingtype = DRAWING_TYPE.VIZ_XCD_PLANE_AND_NODES_VISIBLE
				var xctdataviz = { "xcvizstates":{ prevxcname:finishedplanedrawingtype }, 
								   "updatetubeshells":[
									{ "tubename":xctdata["tubename"], "xcname0":xctdata["xcname0"], "xcname1":xctdata["xcname1"] } 
								] }
								
				sketchsystem.actsketchchange([ xctdata, xctdataviz ])
				
				var matrot0 = tnewdrawinglinks[2]
				for i in range(2, len(tnewdrawinglinks)-4, 4):
					tnewdrawinglinks[i] = tnewdrawinglinks[i+4]
				tnewdrawinglinks[-2] = matrot0
				
			prevxcname = xcdata["name"]
			yield(get_tree().create_timer(0.04), "timeout")
			
		SwitchTest.selected = 0
		
	elif prevnssel.begins_with("opt:") or nssel.begins_with("opt:"):
		var materialsystem = get_node("/root/Spatial/MaterialSystem")
		var n = 0
		var showall = (nssel == "normal")
		if nssel != "opt: tunnelx":
			for xcdrawing in sketchsystem.get_node("XCdrawings").get_children():
				if xcdrawing.drawingtype == DRAWING_TYPE.DT_FLOORTEXTURE:
					if true or (xcdrawing.drawingvisiblecode & DRAWING_TYPE.VIZ_XCD_FLOOR_GHOSTLY_B) != 0:
						xcdrawing.get_node("XCdrawingplane").visible = showall
						n += 1
			print("Number of floor textures hidden: ", n)
		if nssel == "opt: all grey":
			for xctube in sketchsystem.get_node("XCtubes").get_children():
				for xctubesector in xctube.get_node("XCtubesectors").get_children():
					materialsystem.updatetubesectormaterial(xctubesector, "flatgrey", false)
		if nssel == "opt: hide xc":
			sketchsystem.get_node("XCdrawings").visible = false
		elif nssel == "normal":
			sketchsystem.get_node("XCdrawings").visible = true
	
		if nssel == "opt: tunnelx":
			var tunnelxoutline = sketchsystem.get_node("tunnelxoutline")
			var unifiedclosedmesh = Polynets.unifiedclosedmeshwithnormals(sketchsystem.get_node("XCtubes").get_children(), sketchsystem.get_node("XCdrawings").get_children())
			var blackoutline = tunnelxoutline.get_node("blackoutline")
			var whiteinfill = tunnelxoutline.get_node("whiteinfill")
			var plancamera = get_node("/root/Spatial/PlanViewSystem/PlanView/Viewport/PlanGUI/Camera")

			blackoutline.mesh = unifiedclosedmesh
			whiteinfill.mesh = unifiedclosedmesh
			get_node("/root/Spatial/PlanViewSystem").settunnelxoutlineshadervalues()
			tunnelxoutline.visible = true
			sketchsystem.get_node("XCtubes").visible = false
			for xcdrawing in sketchsystem.get_node("XCdrawings").get_children():
				if xcdrawing.drawingtype == DRAWING_TYPE.DT_XCDRAWING and xcdrawing.has_node("XCflatshell") and xcdrawing.xcflatshellmaterial != "hole":
					xcdrawing.get_node("XCflatshell").visible = false
				
		elif prevnssel == "opt: tunnelx":
			sketchsystem.get_node("tunnelxoutline").visible = false
			sketchsystem.get_node("XCtubes").visible = true
			for xcdrawing in sketchsystem.get_node("XCdrawings").get_children():
				if xcdrawing.drawingtype == DRAWING_TYPE.DT_XCDRAWING and xcdrawing.has_node("XCflatshell") and xcdrawing.xcflatshellmaterial != "hole":
					xcdrawing.get_node("XCflatshell").visible = true
			get_node("/root/Spatial/VerletRopeSystem").update_hangingroperad(sketchsystem, -1.0)

		setguipanelhide()
				
	prevnssel = nssel


func _on_buttonrecord_down():
	$Viewport/GUI/Panel/Label.text = "Recording ***"
	Tglobal.soundsystem.startmyvoicerecording()

func _on_buttonrecord_up():
	var rleng = Tglobal.soundsystem.stopmyvoicerecording()
	$Viewport/GUI/Panel/Label.text = "Recorded  %.0fKb" % (rleng/1000)

func _on_buttonplay_pressed():
	Tglobal.soundsystem.playmyvoicerecording()
	$Viewport/GUI/Panel/Label.text = "Play voice"
	
func togglegltf():
	var lidarmodel = get_node("/root/Spatial/Lidarmodel")
	lidarmodel.visible = not lidarmodel.visible
	if lidarmodel.visible and lidarmodel.get_child_count() == 0:
		var dirname = "res://assets/iphonelidarmodels"
		var dir = Directory.new()
		var glbfiles = [ ]
		if dir.open(dirname) == OK:
			dir.list_dir_begin()
			while true:
				var file_name = dir.get_next()
				if file_name == "":  break
				if not dir.current_is_dir() and file_name.ends_with(".glb"):
					glbfiles.push_back(dirname+"/"+file_name)
		if len(glbfiles) != 0:
			print(glbfiles)
			glbfiles.sort()
			lidarmodel.add_child(load(glbfiles[0]).instance())


func makechoke(pressed):
	var Nboulders = 50
	var boulderclutter = get_node("/root/Spatial/BoulderClutter")
	if pressed:
		var HandRight = playerMe.get_node("HandRight")
		for i in range(Nboulders):
			yield(get_tree().create_timer(0.1), "timeout")
			if HandRight.pointervalid:
				var markernode = null
				if ((i%5) == 10):
					markernode = preload("res://assets/objectscenes/log.tscn").instance()
				else:
					markernode = preload("res://assets/objectscenes/boulder.tscn").instance()
					if ((i%2) == 0):
						markernode.scale = Vector3(0.5, 0.5, 0.5)
				var handrightpointertrans = playerMe.global_transform*HandRight.pointerposearvrorigin
				markernode.global_transform.origin = handrightpointertrans.origin - 0.9*handrightpointertrans.basis.z
				markernode.linear_velocity = -5.1*handrightpointertrans.basis.z
				boulderclutter.add_child(markernode)
	else:
		for markernode in boulderclutter.get_children():
			markernode.queue_free()

func _on_textedit_focus_entered():
	print("text edit focus entered")
	virtualkeyboard.visible = true
	Tglobal.virtualkeyboardactive = true
	virtualkeyboard.viewportforvirtualkeyboard = $Viewport

	virtualkeyboard.get_node("CollisionShape").disabled = not virtualkeyboard.visible
	#$Viewport.render_target_update_mode = Viewport.UPDATE_ALWAYS

func _on_textedit_focus_exited():
	print("text edit focus exited")
	virtualkeyboard.visible = false
	Tglobal.virtualkeyboardactive = false
	virtualkeyboard.get_node("CollisionShape").disabled = not virtualkeyboard.visible
	virtualkeyboard._toggle_symbols(false)
	virtualkeyboard._toggle_case(false)
	yield(get_tree().create_timer(0.1), "timeout")

const clientips = [ "Local-network",
					#"192.168.43.193 JulianS9",
					#"10.0.32.206",
					#"127.0.0.1",
					"godot.doesliverpool.xyz" ]
var uniqueinstancestring = ""
func toplevelcalled_ready():
	uniqueinstancestring = OS.get_unique_id().replace("{", "").split("-")[0].to_upper()+"_"+str(randi())
	regexacceptableprojectname.compile('(?i)^([a-z0-9.\\-_]+)\\s*$')
	regexjsontripleflattener.compile('\\[\\s*([^,]+),\\s*([^,]+),\\s*(\\S+)\\s*]')
	if has_node("ViewportReal") and Tglobal.phoneoverlay == null:
		var fgui = $Viewport/GUI
		$Viewport.remove_child(fgui)
		$ViewportReal.add_child(fgui)
		$Viewport.set_name("ViewportFake")
		$ViewportReal.set_name("Viewport")
		$Quad.get_surface_material(0).albedo_texture = $Viewport.get_texture()
		$Viewport.render_target_update_mode = Viewport.UPDATE_DISABLED
		
	for clientip in clientips:
		$Viewport/GUI/Panel/Networkstate.add_item(clientip)
	
	$Viewport/GUI/Panel/ButtonLoad.connect("pressed", self, "_on_buttonload_pressed")
	$Viewport/GUI/Panel/ButtonSave.connect("pressed", self, "_on_buttonsave_pressed")
	$Viewport/GUI/Panel/ButtonPlanView.connect("pressed", self, "_on_buttonplanview_pressed")
	$Viewport/GUI/Panel/ButtonHeadtorch.connect("toggled", self, "_on_buttonheadtorch_toggled")
	$Viewport/GUI/Panel/ButtonDoppelganger.connect("toggled", self, "_on_buttondoppelganger_toggled")
	#$Viewport/GUI/Panel/ButtonSwapControllers.connect("pressed", self, "_on_buttonswapcontrollers_pressed")
	#$Viewport/GUI/Panel/ButtonLockControls.connect("toggled", self, "_on_buttonlockcontrols_toggled")
	#$Viewport/GUI/Panel/ButtonRecord.connect("button_down", self, "_on_buttonrecord_down")
	#$Viewport/GUI/Panel/ButtonRecord.connect("button_up", self, "_on_buttonrecord_up")
	#$Viewport/GUI/Panel/ButtonPlay.connect("pressed", self, "_on_buttonplay_pressed")
	#$Viewport/GUI/Panel/ButtonChoke.connect("toggled", self, "_on_buttonload_choke")
	$Viewport/GUI/Panel/EditColorRect/TextEdit.connect("focus_entered", self, "_on_textedit_focus_entered")
	$Viewport/GUI/Panel/EditColorRect/TextEdit.connect("focus_exited", self, "_on_textedit_focus_exited")

	
	$Viewport/GUI/Panel/SwitchTest.connect("item_selected", self, "_on_switchtest")
	$Viewport/GUI/Panel/PlayerList.connect("item_selected", self, "_on_playerlist_selected")
	$Viewport/GUI/Panel/ButtonGoto.connect("pressed", self, "_on_buttongoto_pressed")
	$Viewport/GUI/Panel/WorldScale.connect("item_selected", self, "_on_playerscale_selected")
	$Viewport/GUI/Panel/Networkstate.connect("item_selected", self, "_on_networkstate_selected")
	$Viewport/GUI/Panel/ResourceOptions.connect("item_selected", self, "_on_resourceoptions_selected")
	$Viewport/GUI/Panel/ResourceOptions.connect("button_down", self, "_on_resourceoptions_buttondown_setavailablefunctions")

	if $Viewport/GUI/Panel/Networkstate.selected != 0:  # could record saved settings on disk
		call_deferred("_on_networkstate_selected", $Viewport/GUI/Panel/Networkstate.selected)

	resources_readycall()

func cavesfilelist():
	var cfiles = [ ]
	var dir = Directory.new()
	if not dir.dir_exists(cavefilesdir):
		var err = Directory.new().make_dir(cavefilesdir)
		print("Making directory ", cavefilesdir, " err code: ", err)
	var e = dir.open(cavefilesdir)
	if e != OK:
		print("list dir error ", e)
		return cfiles
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name != "." and file_name != "..":
			assert (not dir.current_is_dir())
			if file_name.ends_with(".res"):
				var cname = file_name.substr(0, len(file_name)-4)
				cfiles.push_back(cname)
		file_name = dir.get_next()
	return cfiles

remote func servercavesfilelist(scfiles):
	pass # to abolish

remote func setguardianstate(guardianpolyvisible):
	for player in get_node("/root/Spatial/Players").get_children():
		player.get_node("GuardianPoly").visible = guardianpolyvisible

func clickbuttonheadtorch():
	$Viewport/GUI/Panel/ButtonHeadtorch.pressed = not $Viewport/GUI/Panel/ButtonHeadtorch.pressed
	_on_buttonheadtorch_toggled($Viewport/GUI/Panel/ButtonHeadtorch.pressed)

remote func playerjumpgoto(puppetplayerid, lforcetogroundtimedown):
	var puppetplayername = "NetworkedPlayer"+String(puppetplayerid)
	var playerpuppet = get_node("/root/Spatial/Players").get_node_or_null(puppetplayername)
	if playerpuppet != null:
		get_node("/root/Spatial/BodyObjects/PlayerDirections").setasaudienceofpuppet(playerpuppet, playerpuppet.get_node("HeadCam").global_transform, 0.5)
	else:
		print("Not able to playerjumpto ", puppetplayername)

func _on_buttongoto_pressed():
	if selectedplayernetworkid == playerMe.networkID:
		if playerMe.networkID != 1 and Tglobal.connectiontoserveractive:
			rpc_id(1, "playerjumpgoto", playerMe.networkID, 0.5)
	elif selectedplayernetworkid != -1:
		playerjumpgoto(selectedplayernetworkid, 0.5)
	setguipanelhide()

remote func copyacrosstextedit(text):
	if not visible:
		setguipanelvisible(sketchsystem.pointersystem.LaserOrient.global_transform)
	$Viewport/GUI/Panel/EditColorRect/TextEdit.text = text
	$Viewport/GUI/Panel/EditColorRect/TextEdit.grab_focus()
	print("render_target_update_mode ", $Viewport.render_target_update_mode, " ", Viewport.UPDATE_DISABLED)
	$Viewport.render_target_update_mode = Viewport.UPDATE_WHEN_VISIBLE

func buttonflagsign_pressed():
	if sketchsystem.pointersystem.activetargetnode != null and sketchsystem.pointersystem.activetargetnodewall != null and \
			sketchsystem.pointersystem.activetargetnodewall.drawingtype == DRAWING_TYPE.DT_ROPEHANG:
		var xcdrawing = sketchsystem.pointersystem.activetargetnodewall
		var newadditionalproperties = xcdrawing.additionalproperties
		if newadditionalproperties == null:
			newadditionalproperties = { }
		if not newadditionalproperties.has("flagsignlabels"):
			newadditionalproperties["flagsignlabels"] = { }
		var nodename = sketchsystem.pointersystem.activetargetnode.get_name()
		var mtext = $Viewport/GUI/Panel/EditColorRect/TextEdit.text
		newadditionalproperties["flagsignlabels"][nodename] = mtext
		var xcdata = { "name":xcdrawing.get_name(), 
					   "additionalproperties":newadditionalproperties, 
					   "drawingvisiblecode":DRAWING_TYPE.VIZ_XCD_HIDE
					 }
		sketchsystem.actsketchchange([xcdata])
		sketchsystem.pointersystem.clearactivetargetnode()
		print("additionalproperties: ", xcdrawing.additionalproperties)
		setguipanelhide()
		Tglobal.soundsystem.quicksound("MenuClick", collision_point)
				
func getflagsignofnodeselected():
	if sketchsystem.pointersystem.activetargetnodewall != null and sketchsystem.pointersystem.activetargetnodewall.drawingtype == DRAWING_TYPE.DT_ROPEHANG and sketchsystem.pointersystem.activetargetnode != null:
		var xcdrawing = sketchsystem.pointersystem.activetargetnodewall
		var nodename = sketchsystem.pointersystem.activetargetnode.get_name()
		var additionalproperties = xcdrawing.additionalproperties if xcdrawing.additionalproperties != null else {}
		print("additionalproperties ", additionalproperties)
		$Viewport/GUI/Panel/EditColorRect/TextEdit.text = additionalproperties.get("flagsignlabels", {}).get(nodename, "")
	
				
var selectedplayernetworkid = 0
var selectedplayerplatform = ""
func _on_playerlist_selected(index):
	var player = get_node("/root/Spatial/Players").get_child(index)
	if player != null:
		selectedplayernetworkid = player.networkID
		selectedplayerplatform = player.playerplatform
		$Viewport/GUI/Panel/PlayerInfo.text = "%s:%d" % [selectedplayerplatform, selectedplayernetworkid]
		netlinkstatstimer = -3.0
		networkmetricsreceived = null
		$Viewport/GUI/Panel/ButtonGoto.disabled = selectedplayernetworkid == playerMe.networkID and playerMe.networkID == 1

	else:
		selectedplayernetworkid = -1
		selectedplayerplatform = ""
		$Viewport/GUI/Panel/PlayerInfo.text = String("updating")
		updateplayerlist()
		$Viewport/GUI/Panel/ButtonGoto.disabled = true
		
	
func updateplayerlist():
	var selectedplayerindex = 0
	$Viewport/GUI/Panel/PlayerList.clear()
	for player in get_node("/root/Spatial/Players").get_children():
		var playername
		if player == playerMe:
			playername = "me"
		elif player == playerMe.doppelganger:
			playername = "doppel"
		elif player.networkID == 1:
			playername = "server"
		else:
			playername = "player%d" % player.get_index()
		$Viewport/GUI/Panel/PlayerList.add_item(playername)
		
		if player.networkID == selectedplayernetworkid:
			selectedplayerindex = player.get_index()

	$Viewport/GUI/Panel/PlayerList.select(selectedplayerindex)
	

func setguipanelvisible(controller_global_transform):
	if controller_global_transform != null:
		var paneltrans = Transform()
		var controllertrans = controller_global_transform
		var paneldistance = 0.6 if Tglobal.VRoperating else 0.2
		paneltrans.origin = controllertrans.origin - paneldistance*ARVRServer.world_scale*(controllertrans.basis.z)
		var lookatpos = controllertrans.origin - 1.6*ARVRServer.world_scale*(controllertrans.basis.z)
		paneltrans = paneltrans.looking_at(lookatpos, Vector3(0, 1, 0))
		paneltrans = Transform(paneltrans.basis.scaled(Vector3(ARVRServer.world_scale, ARVRServer.world_scale, ARVRServer.world_scale)), paneltrans.origin)
		global_transform = paneltrans

		var kpaneltrans = paneltrans
		kpaneltrans.origin = paneltrans.origin - paneltrans.basis.y*($Quad.mesh.size.y/2) - Vector3(0, virtualkeyboard.get_node("Quad").mesh.size.y/2, 0)
		var klookatpos = 2*kpaneltrans.origin - controllertrans.origin + 0*ARVRServer.world_scale*(controllertrans.basis.z)
		print(klookatpos)
		klookatpos += -1.1*ARVRServer.world_scale*(controllertrans.basis.z)
		print(klookatpos)
		kpaneltrans = kpaneltrans.looking_at(klookatpos, Vector3(0, 1, 0))
		kpaneltrans = Transform(kpaneltrans.basis.scaled(Vector3(ARVRServer.world_scale, ARVRServer.world_scale, ARVRServer.world_scale)), kpaneltrans.origin)
		virtualkeyboard.global_transform = kpaneltrans
	
	$Viewport/GUI/Panel/Label.text = ""
	$Viewport/GUI/Panel/ResourceOptions.selected = 0

	if Tglobal.phoneoverlay == null:
		visible = true
		$CollisionShape.disabled = not visible
	else:
		$Viewport.visible = true
	Tglobal.soundsystem.quicksound("ShowGui", global_transform.origin)

	if Tglobal.connectiontoserveractive:
		selfSpatial.playerMe.rpc("puppetenableguipanel", transform)
	if is_instance_valid(selfSpatial.playerMe.doppelganger):
		selfSpatial.playerMe.doppelganger.puppetenableguipanel(transform)

	getflagsignofnodeselected()
		
func setguipanelhide():
	if not Tglobal.controlslocked:
		#if virtualkeyboard.visible:
		#	_on_textedit_focus_exited()
		visible = false
		if $Viewport.has_method("set_update_mode"):
			$Viewport.set_update_mode(Viewport.UPDATE_DISABLED)
		else:
			$Viewport.visible = false
			
		$CollisionShape.disabled = not visible
		if $Viewport/GUI/Panel/EditColorRect/TextEdit.has_focus():
			$Viewport/GUI/Panel/EditColorRect/TextEdit.release_focus()

		if Tglobal.connectiontoserveractive:
			selfSpatial.playerMe.rpc("puppetenableguipanel", null)
		if is_instance_valid(selfSpatial.playerMe.doppelganger):
			selfSpatial.playerMe.doppelganger.puppetenableguipanel(null)

func _input(event):
	if event is InputEventKey:
		if event.scancode == KEY_ESCAPE:
			return
		elif virtualkeyboard.visible:
			if event.scancode == KEY_TAB:
				var textedit = $Viewport/GUI.get_focus_owner()
				if textedit != null:
					if event.shift and textedit.focus_previous != "":
						get_node(textedit.focus_previous).grab_focus()
					elif textedit.focus_next != "":
						get_node(textedit.focus_next).grab_focus()
					else:
						textedit.release_focus()
			elif Tglobal.phoneoverlay == null:
				$Viewport.input(event)
			get_tree().set_input_as_handled()
		elif event.scancode == KEY_TAB and Tglobal.phoneoverlay == null:
			$Viewport.input(event)
		elif event.pressed:
			if event.scancode == KEY_L:
				$Viewport/GUI/Panel/Savegamefilename.selected = 7
				print("auto loading ", $Viewport/GUI/Panel/Savegamefilename.get_item_text(7))
				_on_buttonload_pressed()
			elif event.scancode == KEY_G:
				$Viewport/GUI/Panel/ButtonDoppelganger.pressed = not $Viewport/GUI/Panel/ButtonDoppelganger.pressed
				_on_buttondoppelganger_toggled($Viewport/GUI/Panel/ButtonDoppelganger.pressed)	
			elif event.scancode == KEY_O:
				playerMe.swapcontrollers()
				Tglobal.soundsystem.quicksound("MenuClick", collision_point)
			elif event.scancode == KEY_B:
				call_deferred("_on_networkstate_selected", 3)
			elif event.scancode == KEY_P:
				$Viewport/GUI/Panel/ButtonPlanView.pressed = not $Viewport/GUI/Panel/ButtonPlanView.pressed
				_on_buttonplanview_pressed()





var resourceoptionlookup = { }
func resources_readycall():
	$Viewport/GUI/Panel/Savegamefilename.clear()
	$Viewport/GUI/Panel/Savegamefilename.add_item("--clearcave")
	for cfile in cavesfilelist():
		$Viewport/GUI/Panel/Savegamefilename.add_item(cfile)
	for idx in range($Viewport/GUI/Panel/ResourceOptions.get_item_count()):
		resourceoptionlookup[$Viewport/GUI/Panel/ResourceOptions.get_item_text(idx)] = idx
	var GithubAPI = get_node("/root/Spatial/ImageSystem/GithubAPI")
	GithubAPI.resources_readycallloadinfo()
	updateresourceselector("")
	var resourcesel = ""
	var resourcetype = ""
	var disablegithubdefault = OS.has_feature("pc")
	for k in GithubAPI.riattributes["resourcedefs"].values():
		if (k["type"] == "localfiles" and resourcetype == "") or \
				(not disablegithubdefault and k["type"] == "githubapi" and k.get("token")):
			resourcesel = k["name"]
			resourcetype = k["type"]
	updateresourceselector(resourcesel)
	ApplyToCaveSave()
	
func updateresourceselector(seltext):
	$Viewport/GUI/Panel/ResourceSelector.clear()
	var GithubAPI = get_node("/root/Spatial/ImageSystem/GithubAPI")
	for k in GithubAPI.riattributes["resourcedefs"]:
		$Viewport/GUI/Panel/ResourceSelector.add_item(k)
		if k == seltext:
			$Viewport/GUI/Panel/ResourceSelector.selected = $Viewport/GUI/Panel/ResourceSelector.get_item_count() - 1

var prevnrosel = ""
var centrelineselected_forresourcefunction = null
var xcselecteddrawing_forrsourcefunctions = null
func _on_resourceoptions_buttondown_setavailablefunctions():
	print("_on_resourceoptions_buttondown_setavailablefunctions")
	var idxselected = $Viewport/GUI/Panel/ResourceOptions.selected
	var nrosel = $Viewport/GUI/Panel/ResourceOptions.get_item_text(idxselected)
	if not (nrosel in ["--resources"]):
		$Viewport/GUI/Panel/ResourceOptions.selected = 0

	var xcdrawingcentrelines = get_tree().get_nodes_in_group("gpcentrelinegeo")
	if sketchsystem.pointersystem.activetargetnodewall != null:
		xcselecteddrawing_forrsourcefunctions = sketchsystem.pointersystem.activetargetnodewall
	elif sketchsystem.pointersystem.activetargetwall != null:
		xcselecteddrawing_forrsourcefunctions = sketchsystem.pointersystem.activetargetwall
	else:
		var planviewsystem = get_node("/root/Spatial/PlanViewSystem")
		if planviewsystem.planviewactive and planviewsystem.activetargetfloor != null:
			xcselecteddrawing_forrsourcefunctions = planviewsystem.activetargetfloor
		elif len(xcdrawingcentrelines) == 1:
			xcselecteddrawing_forrsourcefunctions = xcdrawingcentrelines[0]
		else:
			xcselecteddrawing_forrsourcefunctions = null
	var printxcpropertiesid = resourceoptionlookup["Print XCproperties"]
	var setxcpropertiesid = resourceoptionlookup["Set XCproperties"]
	print("xcselecteddrawing_forrsourcefunctions ", xcselecteddrawing_forrsourcefunctions)
	if xcselecteddrawing_forrsourcefunctions != null and xcselecteddrawing_forrsourcefunctions.drawingtype == DRAWING_TYPE.DT_CENTRELINE:
		$Viewport/GUI/Panel/ResourceOptions.set_item_text(printxcpropertiesid, "Print Centreline")
		$Viewport/GUI/Panel/ResourceOptions.set_item_text(setxcpropertiesid, "Set Centreline")
	else:
		$Viewport/GUI/Panel/ResourceOptions.set_item_text(printxcpropertiesid, "Print XCproperties")
		$Viewport/GUI/Panel/ResourceOptions.set_item_text(setxcpropertiesid, "Set XCproperties")
	$Viewport/GUI/Panel/ResourceOptions.set_item_disabled(printxcpropertiesid, (xcselecteddrawing_forrsourcefunctions == null))
	$Viewport/GUI/Panel/ResourceOptions.set_item_disabled(setxcpropertiesid, (xcselecteddrawing_forrsourcefunctions == null))

	var bcentrelinedistortenable = false
	if xcselecteddrawing_forrsourcefunctions != null and xcselecteddrawing_forrsourcefunctions.drawingtype == DRAWING_TYPE.DT_CENTRELINE:
		centrelineselected_forresourcefunction = xcselecteddrawing_forrsourcefunctions
		var clconnectnode = centrelineselected_forresourcefunction.xccentrelineconnectstofloor(sketchsystem.get_node("XCdrawings"))
		if clconnectnode == 2:
			if len(centrelineselected_forresourcefunction.xctubesconn) + 1 == len(xcdrawingcentrelines):
				bcentrelinedistortenable = true
	elif len(xcdrawingcentrelines) == 1:
		centrelineselected_forresourcefunction = xcdrawingcentrelines[0]
	else:
		centrelineselected_forresourcefunction = null
	$Viewport/GUI/Panel/ResourceOptions.set_item_disabled(resourceoptionlookup["Centreline distort"], not bcentrelinedistortenable)

	var mtext = $Viewport/GUI/Panel/EditColorRect/TextEdit.text.strip_edges()
	var potreeexperiments = selfSpatial.get_node("PotreeExperiments")
	var showhigloadpotreeid = resourceoptionlookup["Show/Hide/Load Potree"]
	if potreeexperiments.rootnode == null:
		$Viewport/GUI/Panel/ResourceOptions.set_item_text(showhigloadpotreeid, "Load Potree")
		$Viewport/GUI/Panel/ResourceOptions.set_item_disabled(showhigloadpotreeid, (centrelineselected_forresourcefunction == null or centrelineselected_forresourcefunction.additionalproperties == null or centrelineselected_forresourcefunction.additionalproperties.get("potreeurlmetadata") == null))
	elif not potreeexperiments.visible:
		$Viewport/GUI/Panel/ResourceOptions.set_item_text(showhigloadpotreeid, "Show Potree")
	elif centrelineselected_forresourcefunction == null or centrelineselected_forresourcefunction.additionalproperties == null or centrelineselected_forresourcefunction.additionalproperties.get("potreeurlmetadata") != potreeexperiments.potreeurlmetadata:
		$Viewport/GUI/Panel/ResourceOptions.set_item_text(showhigloadpotreeid, "Remove Potree")
	else:
		$Viewport/GUI/Panel/ResourceOptions.set_item_text(showhigloadpotreeid, "Hide Potree")

	$Viewport/GUI/Panel/ResourceOptions.set_item_disabled(resourceoptionlookup["Set new file"], regexacceptableprojectname.search(mtext) == null)
	$Viewport/GUI/Panel/ResourceOptions.set_item_disabled(resourceoptionlookup["Send message"], not Tglobal.connectiontoserveractive)
	$Viewport/GUI/Panel/ResourceOptions.set_item_disabled(resourceoptionlookup["Apply to flagsign"], not (sketchsystem.pointersystem.activetargetnode != null and sketchsystem.pointersystem.activetargetnodewall != null and sketchsystem.pointersystem.activetargetnodewall.drawingtype == DRAWING_TYPE.DT_ROPEHANG))


func _on_resourceoptions_selected(index):
	if $Viewport/GUI/Panel/ResourceOptions.selected != index:
		$Viewport/GUI/Panel/ResourceOptions.selected = index
	var nrosel = $Viewport/GUI/Panel/ResourceOptions.get_item_text(index)
	print("Select resourceoption: ", nrosel)
	if (nrosel == "Print XCproperties" or nrosel == "Print Centreline") and is_instance_valid(xcselecteddrawing_forrsourcefunctions):
		var xcproperties = xcselecteddrawing_forrsourcefunctions.additionalproperties.duplicate() if xcselecteddrawing_forrsourcefunctions.additionalproperties != null else {}
		xcproperties["xcname"] = xcselecteddrawing_forrsourcefunctions.get_name()
		if xcselecteddrawing_forrsourcefunctions["xcresource"]:
			xcproperties["xcresource"] = xcselecteddrawing_forrsourcefunctions["xcresource"]
		if sketchsystem.pointersystem.activetargetnode != null:
			xcproperties["snodename"] = sketchsystem.pointersystem.activetargetnode.get_name()
		var xcpos = xcselecteddrawing_forrsourcefunctions.translation
		var xcrot = xcselecteddrawing_forrsourcefunctions.rotation_degrees
		xcproperties["position"] = [xcpos.x, xcpos.y, xcpos.z]
		xcproperties["rotation"] = [xcrot.x, xcrot.y, xcrot.z]
		var xcdrawingtype = xcselecteddrawing_forrsourcefunctions.drawingtype
		if xcdrawingtype != DRAWING_TYPE.DT_XCDRAWING:
			xcproperties["drawingtype"] = "CENTRELINE" if xcdrawingtype == DRAWING_TYPE.DT_CENTRELINE else ("TEXTURE" if xcdrawingtype == DRAWING_TYPE.DT_FLOORTEXTURE else "ROPEHANG")
		if xcdrawingtype == DRAWING_TYPE.DT_CENTRELINE:
			var clconnectcode = xcselecteddrawing_forrsourcefunctions.xccentrelineconnectstofloor(sketchsystem.get_node("XCdrawings"))
			xcproperties["centrelineconnection"] = "anchored" if clconnectcode == 1 else ("incoming for mapping" if clconnectcode == 2 else "free") 
			if not xcproperties.has("potreeurlmetadata"):
				xcproperties["potreeurlmetadata"] = ""
			if not xcproperties.has("geometrymode"):
				xcproperties["geometrymode"] = "tunnelvr"
			if not xcproperties.has("splaystationnoderegex"):
				xcproperties["splaystationnoderegex"] = ".*[^\\d]$"
		var sxcproperties = JSON.print(xcproperties, "  ", true)
		sxcproperties = regexjsontripleflattener.sub(sxcproperties, "[$1, $2, $3]", true)
		$Viewport/GUI/Panel/EditColorRect/TextEdit.text = sxcproperties
			
	if (nrosel == "Set XCproperties" or nrosel == "Set Centreline"):
		var jresource = parse_json($Viewport/GUI/Panel/EditColorRect/TextEdit.text)
		var labeltext = ""
		if jresource != null and jresource.has("xcname"):
			xcselecteddrawing_forrsourcefunctions = sketchsystem.get_node("XCdrawings").get_node_or_null(jresource["xcname"])
			jresource.erase("xcname")
		var bcreatingnewcentreline = false
		if is_instance_valid(xcselecteddrawing_forrsourcefunctions):
			var xcdrawingtype = xcselecteddrawing_forrsourcefunctions.drawingtype
			if jresource != null:
				if jresource.has("xcresource"):
					xcselecteddrawing_forrsourcefunctions.xcresource = jresource["xcresource"]
					jresource.erase("xcresource")
				if jresource.has("snodename"):
					jresource.erase("snodename")
				if jresource.has("centrelineconnection"):
					jresource.erase("centrelineconnection")
				if jresource.has("potreeurlmetadata") and jresource["potreeurlmetadata"] == "":
					jresource.erase("potreeurlmetadata")
				if jresource.has("geometrymode") and jresource["geometrymode"] == "tunnelvr":
					jresource.erase("geometrymode")
				if jresource.has("drawingtype"):
					var ldrawingtype = "CENTRELINE" if xcdrawingtype == DRAWING_TYPE.DT_CENTRELINE else ("TEXTURE" if xcdrawingtype == DRAWING_TYPE.DT_FLOORTEXTURE else "ROPEHANG")
					if (jresource["drawingtype"] == "CENTRELINE" or jresource["drawingtype"] == "CENTERLINE") and ldrawingtype == "ROPEHANG":
						if len(get_tree().get_nodes_in_group("gpcentrelinegeo")) == 0:
							labeltext = "Creating centreline from ropehang"
							bcreatingnewcentreline = true
						else:
							labeltext = "Already have a centreline"
							jresource = null
					elif jresource["drawingtype"] != ldrawingtype:
						labeltext = "Cannot change drawing type"
						jresource = null
					else:
						jresource.erase("drawingtype")
				elif xcdrawingtype != DRAWING_TYPE.DT_XCDRAWING:
					labeltext = "Cannot change drawing type"
					jresource = null
				else:
					jresource.erase("drawingtype")
			else:
				labeltext = "Bad JSON format"
			if jresource != null:
				var dnode = Spatial.new()
				dnode.transform = xcselecteddrawing_forrsourcefunctions.transform
				if jresource.has("position") and typeof(jresource["position"]) == TYPE_ARRAY and len(jresource["position"]) == 3:
					dnode.translation = Vector3(float(jresource["position"][0]), float(jresource["position"][1]), float(jresource["position"][2]))
					jresource.erase("position")
				if jresource.has("rotation") and typeof(jresource["rotation"]) == TYPE_ARRAY and len(jresource["rotation"]) == 3:
					dnode.rotation_degrees = Vector3(float(jresource["rotation"][0]), float(jresource["rotation"][1]), float(jresource["rotation"][2]))
					jresource.erase("rotation")
				var xcdata = { "name":xcselecteddrawing_forrsourcefunctions.get_name(), 
							   "prevtransformpos":xcselecteddrawing_forrsourcefunctions.transform,
							   "transformpos":dnode.transform
							 }
				if bcreatingnewcentreline:
					xcdata["drawingtype"] = DRAWING_TYPE.DT_CENTRELINE
					xcdata["name"] = xcselecteddrawing_forrsourcefunctions.get_name() + "_centreline"
					xcdata["nodepoints"] = xcselecteddrawing_forrsourcefunctions.nodepoints.duplicate()
					xcdata["onepathpairs"] = xcselecteddrawing_forrsourcefunctions.onepathpairs.duplicate()
				if len(jresource) != 0:
					xcdata["additionalproperties"] = jresource
				sketchsystem.actsketchchange([xcdata])
				sketchsystem.pointersystem.clearactivetargetnode()
				if labeltext == "":
					labeltext = "XCdrawing properties updated"
		else:
			labeltext = "No XCdrawing selected"
		setpanellabeltext(labeltext)

	elif nrosel.count("Potree"):
		var potreeexperiments = selfSpatial.get_node("PotreeExperiments")
		var labeltext = ""
		if nrosel == "Load Potree":
			potreeexperiments.visible = true
			if potreeexperiments.rootnode == null:
				potreeexperiments.LoadPotree()
				labeltext = "Potree started"
			else:
				labeltext = "Potree already there"
		elif nrosel == "Remove Potree":
			potreeexperiments.visible = false
			if potreeexperiments.rootnode != null:
				labeltext = "Removing Potree"
				potreeexperiments.queuekillpotree = true
			else:
				labeltext = "Potree not there"
		elif nrosel == "Show Potree":
			if potreeexperiments.rootnode != null:
				potreeexperiments.visible = true
				labeltext = "Potree shown"
			else:
				labeltext = "Potree not there"
		elif nrosel == "Hide Potree":
			potreeexperiments.visible = false
			labeltext = "Potree hidden"
		setpanellabeltext(labeltext)
		if labeltext == "Potree started" or labeltext == "Potree hidden":
			setguipanelhide()
	
	elif nrosel == "Print resource":
		var resourcename = $Viewport/GUI/Panel/ResourceSelector.get_item_text($Viewport/GUI/Panel/ResourceSelector.selected)
		var GithubAPI = get_node("/root/Spatial/ImageSystem/GithubAPI")
		var lresourceselected = GithubAPI.riattributes["resourcedefs"].get(resourcename).duplicate()
		if lresourceselected != null:
			assert (lresourceselected["name"] == resourcename)
			if lresourceselected.get("type") == "localfiles":
				lresourceselected["unique_id"] = OS.get_unique_id()
			$Viewport/GUI/Panel/EditColorRect/TextEdit.text = JSON.print(lresourceselected, "  ", true)

	elif nrosel == "Set resource":
		var jresource = parse_json($Viewport/GUI/Panel/EditColorRect/TextEdit.text)
		if jresource != null and jresource.has("name"):
			var GithubAPI = get_node("/root/Spatial/ImageSystem/GithubAPI")
			var ltext = "Resource file saved"
			if jresource["name"] == "local":
				if jresource.get("delete"):
					ltext = "Err: cannot delete local"
				elif jresource.get("type") != "localfiles":
					ltext = "Err: must be type localfiles"
				elif not jresource.get("playername"):
					ltext = "Err: must have playername"
				elif jresource.get("unique_id") and jresource["unique_id"] != OS.get_unique_id():
					ltext = "Err: unique_id mismatch"
				else:
					GithubAPI.riattributes["resourcedefs"][jresource["name"]] = jresource
			elif jresource.get("type") == "erase" or jresource.get("type") == "delete":
				GithubAPI.riattributes["resourcedefs"].erase(jresource["name"])
				ltext = "resource deleted"
			elif jresource.get("type") in ["githubapi", "svnfiles", "caddyfiles"]:
				GithubAPI.riattributes["resourcedefs"][jresource["name"]] = jresource
			else:
				ltext = "Err: unknown type"
			if ltext[0] != "E":
				GithubAPI.saveresourcesinformationfile()
				updateresourceselector(jresource["name"])
			setpanellabeltext(ltext)
		else:
			setpanellabeltext("Resource definition not valid")

	elif nrosel == "Apply to Filetree":
		var GithubAPI = get_node("/root/Spatial/ImageSystem/GithubAPI")
		var planviewsystem = get_node("/root/Spatial/PlanViewSystem")
		var resourcename = $Viewport/GUI/Panel/ResourceSelector.get_item_text($Viewport/GUI/Panel/ResourceSelector.selected)
		var resourcedef = GithubAPI.riattributes["resourcedefs"][resourcename]
		if resourcedef.get("type") in ["svnfiles", "caddyfiles", "githubapi"]:
			planviewsystem.filetreeresourcename = resourcename
			var filetreerootpath = resourcedef.get("path", "")
			filetreerootpath = filetreerootpath.rstrip("/") + "/"
			planviewsystem.clearsetupfileviewtree(false, filetreerootpath)
			setpanellabeltext("Applied resource to filetree")
		else:
			setpanellabeltext("Cannot apply to resource type")
					
	elif nrosel == "Apply to Cavesave":
		ApplyToCaveSave()
		
	elif nrosel == "Set new file":
		var mtext = $Viewport/GUI/Panel/EditColorRect/TextEdit.text.strip_edges()
		var mmtext = regexacceptableprojectname.search(mtext)
		if mmtext != null:
			setsavegamefilename(mmtext.get_string(0))

	elif nrosel == "Send message":
		if Tglobal.connectiontoserveractive:
			rpc("copyacrosstextedit", $Viewport/GUI/Panel/EditColorRect/TextEdit.text)
			setpanellabeltext("message sent")

	elif nrosel == "Apply to flagsign":
		buttonflagsign_pressed()
		
	elif nrosel == "Centreline distort":
		var xcdatalist = Centrelinedata.centrelinepassagedistort(centrelineselected_forresourcefunction, sketchsystem)
		sketchsystem.pointersystem.clearactivetargetnode()
		sketchsystem.actsketchchange(xcdatalist)
		var floormovedata = [ ]
		for xctubec in centrelineselected_forresourcefunction.xctubesconn:
			var xcdrawingFloor = sketchsystem.get_node("XCdrawings").get_node(xctubec.xcname1)
			if len(xctubec.xcdrawinglink) != 0 and xcdrawingFloor.drawingtype == DRAWING_TYPE.DT_FLOORTEXTURE:
				floormovedata.append_array(xctubec.centrelineconnectionfloortransformpos(sketchsystem))
		if len(floormovedata) != 0:
			sketchsystem.actsketchchange(floormovedata)
		setguipanelhide()
				
	Tglobal.soundsystem.quicksound("MenuClick", collision_point)
	prevnrosel = nrosel

func Yupdatecavefilelist():
	var savegamefilenameoptionbutton = $Viewport/GUI/Panel/Savegamefilename
	var savegamefileid = savegamefilenameoptionbutton.get_selected_id()
	var savegamefilestring = savegamefilenameoptionbutton.get_item_text(savegamefileid)
	var savegamefilename = savegamefilestring.split(":", true, 1)[-1].strip_edges().lstrip("*#")

	var GithubAPI = get_node("/root/Spatial/ImageSystem/GithubAPI")
	var cfiles = yield(GithubAPI.Ylistdircavefilelist(), "completed")
	if cfiles.size() == 1 and cfiles[0].begins_with("Err:"):
		setpanellabeltext(cfiles[0])
	else:
		savegamefilenameoptionbutton.clear()
		savegamefilenameoptionbutton.add_item("--clearcave")
		for cfile in cfiles:
			savegamefilenameoptionbutton.add_item(cfile)
		if savegamefilename != "--clearcave":
			setsavegamefilename(savegamefilename)
		
func ApplyToCaveSave():
	var GithubAPI = get_node("/root/Spatial/ImageSystem/GithubAPI")
	var resourcename = $Viewport/GUI/Panel/ResourceSelector.get_item_text($Viewport/GUI/Panel/ResourceSelector.selected)
	var resourcedef = GithubAPI.riattributes["resourcedefs"][resourcename]
	setpanellabeltext("set cave save to: "+resourcename)
	if resourcedef.get("type") == "localfiles":
		GithubAPI.ghattributes = resourcedef
	elif resourcedef.get("type") == "githubapi":
		GithubAPI.ghattributes = resourcedef
	else:
		setpanellabeltext("Cannot apply to cavesave")
		return
	GithubAPI.httpghapi.poll()
	if GithubAPI.httpghapi.get_status() == HTTPClient.STATUS_CONNECTED:
		GithubAPI.httpghapi.close()
		GithubAPI.httpghapi = HTTPClient.new()
	Yupdatecavefilelist()



###############################
#-------------networking system
var websocketserver = null
var websocketclient = null
var networkedmultiplayerenetserver = null
var networkedmultiplayerenetclient = null
var udpdiscoveryreceivingserver = null
var networksignalsalreadyconnected = false

func _on_networkstate_selected(index):
	print("_on_networkstate_selected: ", index, " ", OS.get_ticks_msec())
	if $Viewport/GUI/Panel/Networkstate.selected != index:
		$Viewport/GUI/Panel/Networkstate.selected = index
	var nssel = $Viewport/GUI/Panel/Networkstate.get_item_text(index)
	print("Select networkstate: ", nssel, " ", OS.get_ticks_msec())
	if not nssel.begins_with("Local-network") and udpdiscoveryreceivingserver != null:
		udpdiscoveryreceivingserver.stop()
		udpdiscoveryreceivingserver = null

	if nssel == "Check IPnum":
		print("IP local interfaces: ")
		$Viewport/GUI/Panel/Label.text = ""
		for k in IP.get_local_interfaces():
			var ipnum = ""
			for l in k["addresses"]:
				if l.find(".") != -1:
					ipnum = l
			var kf = k["friendly"] + ": " + ipnum
			print(kf)
			if k["friendly"] == "Wi-Fi" or k["friendly"].begins_with("wlan") or k["friendly"].begins_with("wlp2s"):
				$Viewport/GUI/Panel/Label.text = kf
			elif k["friendly"] == "Ethernet" and $Viewport/GUI/Panel/Label.text == "":
				$Viewport/GUI/Panel/Label.text = kf
		websocketclient = null
		
	else:   # put the network completely off
		print("Network off")
		if websocketserver != null:
			websocketserver.close()
			# Note: To achieve a clean close, you will need to keep polling until either WebSocketClient.connection_closed or WebSocketServer.client_disconnected is received.
			# Note: The HTML5 export might not support all status codes. Please refer to browser-specific documentation for more details.
			websocketserver = null
		if websocketclient != null:
			websocketclient.disconnect_from_host()
			#websocketclient = null
		if networkedmultiplayerenetclient != null:
			networkedmultiplayerenetclient.close_connection()
			networkedmultiplayerenetclient = null
			setpanellabeltext("enet client closed")
		if networkedmultiplayerenetserver != null:
			networkedmultiplayerenetserver.close_connection()
			networkedmultiplayerenetserver = null
			setpanellabeltext("enet server closed")
		if udpdiscoveryreceivingserver != null:
			udpdiscoveryreceivingserver.stop()
			udpdiscoveryreceivingserver = null

		removeallplayersdisconnection()
		selfSpatial.setconnectiontoserveractive(false)
		get_tree().set_network_peer(null)

		selfSpatial.get_node("ExecutingFeatures").stopcaddywebserver()

	if nssel == "Check IPnum" or nssel == "Network Off":
		return

	if not networksignalsalreadyconnected:
		get_tree().connect("network_peer_connected", selfSpatial, "_player_connected")
		get_tree().connect("network_peer_disconnected", selfSpatial, "_player_disconnected")
		get_tree().connect("connected_to_server", selfSpatial, "_connected_to_server")
		get_tree().connect("connection_failed", self, "_connection_failed")
		get_tree().connect("server_disconnected", self, "_server_disconnected")
		networksignalsalreadyconnected = true
		
	if nssel.begins_with("As Server"):
		networkstartasserver(true)
		if selfSpatial.playerMe.networkID == 0:
			setpanellabeltext("server failed to start")
		else:
			setpanellabeltext("networkID: "+str(selfSpatial.playerMe.networkID))

	elif nssel.begins_with("Local-network"):
		udpdiscoveryreceivingserver = UDPServer.new()
		var udperr = udpdiscoveryreceivingserver.listen(selfSpatial.udpserverdiscoveryport)
		print("UDP err ", udperr)
		setpanellabeltext("Local server discovery")

	else:
		selfSpatial.hostipnumber = nssel.replace("Client->", "")
		if selfSpatial.hostipnumber.find(" ") != -1:
			selfSpatial.hostipnumber = selfSpatial.hostipnumber.left(selfSpatial.hostipnumber.find(" "))
		print(nssel, "    ", selfSpatial.hostipnumber, "  ", selfSpatial.hostipnumber.is_valid_ip_address())
		
		selfSpatial.setconnectiontoserveractive(false)
		selfSpatial.get_node("BodyObjects/LaserOrient/NotificationCylinder").visible = true
		selfSpatial.get_node("BodyObjects/LaserOrient/NotificationCylinder").scale.y = 20
		selfSpatial.playerMe.global_transform.origin += 3*Vector3(selfSpatial.playerMe.get_node("HeadCam").global_transform.basis.z.x, 0, selfSpatial.playerMe.get_node("HeadCam").global_transform.basis.z.z).normalized()
		if selfSpatial.usewebsockets:
			websocketclient = WebSocketClient.new();
			var url = "ws://"+selfSpatial.hostipnumber+":" + str(selfSpatial.hostportnumber)
			var e = websocketclient.connect_to_url(url, PoolStringArray(), true)
			print("Websocketclient connect to: ", url, " ", e, " <<----ERROR " if e != 0 else "")
			get_tree().set_network_peer(websocketclient)
			
		else:
			networkedmultiplayerenetclient = NetworkedMultiplayerENet.new()
			var inbandwidth = 0
			var outbandwidth = 0
			var e = networkedmultiplayerenetclient.create_client(selfSpatial.hostipnumber, selfSpatial.hostportnumber, inbandwidth, outbandwidth)
			print("networkedmultiplayerenet createclient: ", ("Error:" if e != 0 else ""), e, " ", selfSpatial.hostipnumber)
			get_tree().set_network_peer(networkedmultiplayerenetclient)
		$Viewport/GUI/Panel/Label.text = "connecting "+("websocket" if selfSpatial.usewebsockets else "ENET")
		#setguipanelhide()
	
func networkstartasserver(fromgui):
	if not fromgui:
		yield(get_tree().create_timer(2.0), "timeout")
	print("Starting as server, ipnumber list:")
	selfSpatial.hostipnumber = ""
	for k in IP.get_local_interfaces():
		var ipnum = ""
		for l in k["addresses"]:
			if l.find(".") != -1:
				ipnum = l
		print(k["friendly"] + ": " + ipnum)
		if k["friendly"] == "Wi-Fi" or k["friendly"].begins_with("wlan"):
			selfSpatial.hostipnumber = ipnum
		elif selfSpatial.hostipnumber == "":
			selfSpatial.hostipnumber = ipnum
	
	if selfSpatial.usewebsockets:
		websocketserver = WebSocketServer.new();
		var e = websocketserver.listen(selfSpatial.hostportnumber, PoolStringArray(), true)
		print("Websocketserverclient listen: ", e)
		get_tree().set_network_peer(websocketserver)
		selfSpatial.setconnectiontoserveractive(true)
	else:
		networkedmultiplayerenetserver = NetworkedMultiplayerENet.new()
		var e = networkedmultiplayerenetserver.create_server(selfSpatial.hostportnumber, 32)
		if e == 0:
			get_tree().set_network_peer(networkedmultiplayerenetserver)
			selfSpatial.setconnectiontoserveractive(true)
		else:
			print("networkedmultiplayerenet createserver Error: ", {ERR_CANT_CREATE:"ERR_CANT_CREATE"}.get(e, e))
			print("*** is there a server running on this port already? ", selfSpatial.hostportnumber)
			networkedmultiplayerenetserver = null
			$Viewport/GUI/Panel/Networkstate.selected = 0

	var lnetworkID = get_tree().get_network_unique_id()
	selfSpatial.setnetworkidname(selfSpatial.playerMe, lnetworkID)
	print("server networkID: ", selfSpatial.playerMe.networkID)
	selfSpatial.get_node("BodyObjects/LaserOrient/NotificationTorus").visible = false

	if selfSpatial.playerMe.executingfeaturesavailable.has("caddy"):
		selfSpatial.get_node("ExecutingFeatures").startcaddywebserver()
	get_node("/root/Spatial/MQTTExperiment").mqttupdatenetstatus()


func _connection_failed():
	print("_connection_failed ", Tglobal.connectiontoserveractive, " ", websocketclient, " ", selfSpatial.players_connected_list)
	selfSpatial.get_node("BodyObjects/LaserOrient/NotificationTorus").visible = true
	selfSpatial.get_node("BodyObjects/LaserOrient/NotificationCylinder").visible = false
	websocketclient = null
	if Tglobal.connectiontoserveractive:
		_server_disconnected()
	else:
		assert (len(selfSpatial.deferred_player_connected_list) == 0)
		assert (len(selfSpatial.players_connected_list) == 0)
	$Viewport/GUI/Panel/Label.text = "connection_failed"

func removeallplayersdisconnection():
	selfSpatial.deferred_player_connected_list.clear()
	for id in selfSpatial.players_connected_list.duplicate():
		print("server_disconnected, calling _player_disconnected on ", id)
		selfSpatial.call_deferred("_player_disconnected", id)
	get_node("/root/Spatial/MQTTExperiment").mqttupdatenetstatus()
	
func _server_disconnected():
	print("\n\n***_server_disconnected ", websocketclient, "\n\n")
	websocketclient = null
	networkedmultiplayerenetclient = null
	selfSpatial.setconnectiontoserveractive(false)
	removeallplayersdisconnection()
	selfSpatial.get_node("BodyObjects/LaserOrient/NotificationTorus").visible = true
	selfSpatial.get_node("BodyObjects/LaserOrient/NotificationCylinder").visible = false
	if $Viewport/GUI/Panel/Networkstate.selected != 0:
		$Viewport/GUI/Panel/Networkstate.selected = 0

	
var networkmetricsreceived = null
remote func recordnetworkmetrics(lnetworkmetricsreceived):
	lnetworkmetricsreceived["ticksback"] = OS.get_ticks_msec()
	networkmetricsreceived = lnetworkmetricsreceived
	var bouncetimems = networkmetricsreceived["ticksback"] - networkmetricsreceived["ticksout"]
	#print("recordnetworkmetrics ", networkmetricsreceived)
	selfSpatial.get_node("MQTTExperiment").fpsbounce("%d %d" % [Performance.get_monitor(Performance.TIME_FPS), bouncetimems])
		
remote func sendbacknetworkmetrics(lnetworkmetrics, networkIDsource):
	var playerOthername = "NetworkedPlayer"+String(networkIDsource) if networkIDsource != -11 else "Doppelganger"
	var playerOther = get_node("/root/Spatial/Players").get_node_or_null(playerOthername)
	if playerOther != null and len(playerOther.puppetpositionstack) != 0:
		lnetworkmetrics["stackduration"] = playerOther.puppetpositionstack[-1]["Ltimestamp"] - OS.get_ticks_msec()*0.001
		#print(playerOthername, " stackduration is ", lnetworkmetrics["stackduration"])
	elif playerOther == null:
		print("Did not find ", playerOthername)
		lnetworkmetrics["stackduration"] = -1.0
	else:
		print(playerOthername, " stack empty")
		lnetworkmetrics["stackduration"] = 0.0
	lnetworkmetrics["unixtime"] = OS.get_unix_time()
	if networkIDsource >= 0:
		rpc_id(networkIDsource, "recordnetworkmetrics", lnetworkmetrics)
	elif networkIDsource == -11:
		call_deferred("recordnetworkmetrics", lnetworkmetrics)

				
const netlinkstatstimeinterval = 1.1
var netlinkstatstimer = 0.0
var maxdelta = 0.0
var sumdelta = 0.0
var countframes = 0
var broadcastudpipnum = "255.255.255.255"


const udpdiscoverybroadcasterperiod = 2.0
var udpdiscoverybroadcasterperiodtimer = udpdiscoverybroadcasterperiod

func _process(delta):
	if websocketserver != null:
		if websocketserver.is_listening():
			websocketserver.poll()
	if websocketclient != null:
		websocketclient.poll()
	if Tglobal.connectiontoserveractive and not OS.has_feature("Server"):
		if visible and netlinkstatstimer < 0.0 and netlinkstatstimer + delta >= 0:
			$Viewport/GUI/Panel/PlayerInfo.text = "%s:%d" % [selectedplayerplatform, selectedplayernetworkid]
		netlinkstatstimer += delta
		maxdelta = max(delta, maxdelta)
		sumdelta += delta
		countframes += 1
		if netlinkstatstimer > netlinkstatstimeinterval:
			if networkmetricsreceived != null:
				var stacktime = networkmetricsreceived["stackduration"]
				var bouncetime = (networkmetricsreceived["ticksback"] - networkmetricsreceived["ticksout"])*0.001
				$Viewport/GUI/Panel/PlayerInfo.text = "bounce:%.3f stack:%.3f" % [bouncetime, stacktime]
				networkmetricsreceived = null
			elif selectedplayernetworkid == 0 or selectedplayernetworkid == playerMe.networkID:
				if countframes != 0:
					if visible:
						$Viewport/GUI/Panel/PlayerInfo.text = "frame max:%.3f avg:%.3f" % [maxdelta, sumdelta/countframes]
					maxdelta = 0.0
					sumdelta = 0.0
					countframes = 0

			if selectedplayernetworkid >= 0:
				rpc_id(selectedplayernetworkid, "sendbacknetworkmetrics", { "ticksout":OS.get_ticks_msec() }, playerMe.networkID)
			elif selectedplayernetworkid == -10:
				call_deferred("sendbacknetworkmetrics", { "ticksout":OS.get_ticks_msec() }, -11)
			netlinkstatstimer = 0.0

	if networkedmultiplayerenetserver != null and not OS.has_feature("Server") and selfSpatial.udpserverdiscoveryport != 0:
		udpdiscoverybroadcasterperiodtimer -= delta
		if udpdiscoverybroadcasterperiodtimer < 0:
			udpdiscoverybroadcasterperiodtimer = udpdiscoverybroadcasterperiod
			var udpdiscoverybroadcaster = PacketPeerUDP.new()
			udpdiscoverybroadcaster.set_broadcast_enabled(true)
			var err0 = udpdiscoverybroadcaster.set_dest_address(broadcastudpipnum, selfSpatial.udpserverdiscoveryport)
			var err1 = udpdiscoverybroadcaster.put_packet(("TunnelVRserver-here! "+uniqueinstancestring).to_utf8())
			print("put UDP onto ", broadcastudpipnum, ":", selfSpatial.udpserverdiscoveryport, " errs:", err0, " ", err1)
			if err0 != 0:
				print("udpdiscoverybroadcaster")
			udpdiscoverybroadcaster.close()

	if udpdiscoveryreceivingserver != null and playerMe.networkID == 0:
		udpdiscoveryreceivingserver.poll()
		if udpdiscoveryreceivingserver.is_connection_available():
			var peer = udpdiscoveryreceivingserver.take_connection()
			var pkt = peer.get_packet()
			var spkt = pkt.get_string_from_utf8().split(" ")
			print("Received: ", spkt, " from ", peer.get_packet_ip())
			if spkt[0] == "TunnelVRserver-here!":
				var serverIPnumber = peer.get_packet_ip()
				var lastitem = $Viewport/GUI/Panel/Networkstate.get_item_text($Viewport/GUI/Panel/Networkstate.get_item_count()-1)
				if lastitem != serverIPnumber:
					$Viewport/GUI/Panel/Networkstate.add_item(serverIPnumber)
				udpdiscoveryreceivingserver.stop()
				udpdiscoveryreceivingserver = null
				_on_networkstate_selected($Viewport/GUI/Panel/Networkstate.get_item_count()-1)


