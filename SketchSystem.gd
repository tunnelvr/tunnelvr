extends Spatial

const XCdrawing = preload("res://nodescenes/XCdrawing.tscn")
const XCtube = preload("res://nodescenes/XCtube.tscn")

const linewidth = 0.05

var actsketchchangeundostack = [ ]

#const defaultfloordrawing = "http://cave-registry.org.uk/svn/NorthernEngland/ThreeCountiesArea/rawscans/Ireby/DukeStResurvey-drawnup-p3.jpg"
const defaultfloordrawing = "http://cave-registry.org.uk/svn/NorthernEngland/rawscans/LambTrap/LambTrap-drawnup-1.png"

func _ready():
	var floordrawingimg = defaultfloordrawing
	#floordrawingimg = "res://surveyscans/greenland/ushapedcave.png"
	floordrawingimg = defaultfloordrawing
	var sname = uniqueXCdrawingPapername(floordrawingimg)
	var floordrawing = newXCuniquedrawingPaperN(floordrawingimg, sname, DRAWING_TYPE.DT_FLOORTEXTURE)
	floordrawing.transform = Transform(Vector3(1,0,0), Vector3(0,0,-1), Vector3(0,1,0), Vector3(0,0,0))
	floordrawing.imgwidth = 50
	floordrawing.imgtrimleftdown = Vector2(-25, -25)
	floordrawing.imgtrimrightup = Vector2(25, 25)
	#floordrawing.get_node("XCdrawingplane").scale = Vector3(50, 50, 1)
	get_node("/root/Spatial/ImageSystem").fetchpaperdrawing(floordrawing)
		

func findxctube(xcname0, xcname1):
	var xcdrawing0 = get_node("XCdrawings").get_node(xcname0)	
	for xctube in xcdrawing0.xctubesconn:
		assert (xctube.xcname0 == xcname0 or xctube.xcname1 == xcname0)
		if xctube.xcname1 == xcname1:
			return xctube
		if xctube.xcname0 == xcname1:
			return xctube
	return null
	
func xctubefromdata(xctdata):
	var xctube = findxctube(xctdata["xcname0"], xctdata["xcname1"])
	if xctube == null:
		var xcdrawing0 = get_node("XCdrawings").get_node(xctdata["xcname0"])
		var xcdrawing1 = get_node("XCdrawings").get_node(xctdata["xcname1"])
		xctdata["m0"] = 1 if xcdrawing1.drawingtype == DRAWING_TYPE.DT_CENTRELINE else 0
		if xctdata["m0"] == 0:
			xctube = newXCtube(xcdrawing0, xcdrawing1)
		else:
			xctube = newXCtube(xcdrawing1, xcdrawing0)
		xctube.makeplaneintersectionaxisvec(xcdrawing0, xcdrawing1)
	else:
		xctdata["m0"] = 1 if xctube.xcname0 == xctdata["xcname1"] else 0
	xctube.mergexctrpcdata(xctdata)
	return xctube

func updateworkingshell():
	for xctube in $XCtubes.get_children():
		if not xctube.positioningtube:
			xctube.updatetubeshell($XCdrawings, Tglobal.tubeshellsvisible)
	for xcdrawing in $XCdrawings.get_children():
		if xcdrawing.drawingtype == DRAWING_TYPE.DT_XCDRAWING:
			xcdrawing.updatexctubeshell($XCdrawings, Tglobal.tubeshellsvisible)

func updatecentrelinevisibility():
	get_tree().call_group("gpnoncentrelinegeo", "xcdfullsetvisibilitycollision", not Tglobal.centrelineonly)
	get_tree().call_group("gpcentrelinegeo", "xcdfullsetvisibilitycollision", Tglobal.centrelinevisible)
	if Tglobal.centrelinevisible:
		var playerMe = get_node("/root/Spatial").playerMe
		get_node("/root/Spatial/LabelGenerator").restartlabelmakingprocess(playerMe.get_node("HeadCam").global_transform.origin)
	
func changetubedxcsvizmode(xcdrawings=null):
	if xcdrawings == null:
		xcdrawings = $XCdrawings.get_children()
	for xcdrawing in xcdrawings:
		if xcdrawing.drawingtype == DRAWING_TYPE.DT_XCDRAWING:
			assert (xcdrawing.get_node("XCdrawingplane").visible != xcdrawing.get_node("XCdrawingplane/CollisionShape").disabled)
			var xcsvisible = xcdrawing.get_node("XCdrawingplane").visible or Tglobal.tubedxcsvisible or len(xcdrawing.xctubesconn) == 0
			xcdrawing.get_node("XCnodes").visible = xcsvisible
			xcdrawing.get_node("PathLines").visible = xcsvisible

func sketchsystemtodict():
	var xcdrawingsData = [ ]
	for xcdrawing in $XCdrawings.get_children():
		if xcdrawing.drawingtype == DRAWING_TYPE.DT_XCDRAWING and len(xcdrawing.nodepoints) == 0:
			print("Discarding xcdrawing on save ", xcdrawing.get_name())
		else:
			xcdrawingsData.append(xcdrawing.exportxcrpcdata())
	var xctubesData = [ ]
	for xctube in $XCtubes.get_children():
		xctubesData.append(xctube.exportxctrpcdata())
	var sketchdatadict = { "xcdrawings":xcdrawingsData,
						   "xctubes":xctubesData
						 }
	var playerMe = get_node("/root/Spatial").playerMe
	sketchdatadict["playerMe"] = { "transformpos":playerMe.global_transform, "headtrans":playerMe.get_node("HeadCam").global_transform }
	return sketchdatadict
	
remote func savesketchsystem(fname):
	var sketchdatadict = sketchsystemtodict()
	var sketchdatafile = File.new()
	var fnamewriting = fname + "_WRITING"
	sketchdatafile.open(fnamewriting, File.WRITE)
	sketchdatafile.store_var(sketchdatadict)
	sketchdatafile.close()
	Directory.new().rename(fnamewriting, fname)
	print("saved ", fname, " in C:/Users/ViveOne/AppData/Roaming/Godot/app_userdata/tunnelvr")


func combinabletransformposchange(xcdatalist):
	if len(actsketchchangeundostack) > 0 and len(actsketchchangeundostack[-1]) == 1 and len(xcdatalist) == 1:
		var xcdataprev = actsketchchangeundostack[-1][0]
		var xcdata = xcdatalist[0]
		if ("transformpos" in xcdataprev and "transformpos" in xcdata) or ("imgtrim" in xcdataprev and "imgtrim" in xcdata):
			if xcdataprev.get("name", "*1") == xcdata.get("name", "*2"):
				return true
	return false
	
var prevcombinabletransformposchangetimestamp = 0
const sendrpctransformthinningdelta = 0.25
func actsketchchange(xcdatalist):
	var playerMe = get_node("/root/Spatial").playerMe
	xcdatalist[0]["networkIDsource"] = playerMe.networkID
	xcdatalist[0]["datetime"] = OS.get_datetime()

	if xcdatalist[0].get("rpcoptional", 0) == 1:
		if combinabletransformposchange(xcdatalist):  # made from targetwalltransformpos()
			if xcdatalist[0].get("timestamp", 0) - prevcombinabletransformposchangetimestamp > sendrpctransformthinningdelta:
				xcdatalist[0]["rpcoptional"] = 0
				prevcombinabletransformposchangetimestamp = xcdatalist[0].get("timestamp", 0)

	actsketchchangeL(xcdatalist)  # <--- the main function you want to step into
	if Tglobal.connectiontoserveractive and not (xcdatalist[0].get("rpcoptional", 0) == 1):
		assert(playerMe.networkID != 0)
		#print("Delaying transmission by 20 seconds to simulate bad connections")
		#yield(get_tree().create_timer(20), "timeout")
		rpc("actsketchchangeL", xcdatalist)

func clearentirecaveworld():
	get_node("/root/Spatial").clearallprocessactivityforreload()
	var xcdrawings_old = $XCdrawings
	xcdrawings_old.set_name("XCdrawings_old")
	for x in xcdrawings_old.get_children():
		x.queue_free()   # because it's not transitive (should file a ticket)
	xcdrawings_old.queue_free()
	var xcdrawings_new = Spatial.new()
	xcdrawings_new.set_name("XCdrawings")
	add_child(xcdrawings_new)
	var xctubes_old = $XCtubes
	xctubes_old.set_name("XCtubes_old")
	for x in xctubes_old.get_children():
		x.queue_free()
	xctubes_old.queue_free()
	var xctubes_new = Spatial.new()
	xctubes_new.set_name("XCtubes")
	add_child(xctubes_new)

func spawnplayerme(playerMeD):
	var playerMe = get_node("/root/Spatial").playerMe
	if "headtrans" in playerMeD:
		var playerlam = (playerMe.networkID%10000)/10000.0
		var headtrans = playerMeD["headtrans"]
		var vecahead = Vector3(headtrans.basis.z.x, 0, headtrans.basis.z.z).normalized()
		if playerMe.networkID > 1:
			headtrans = Transform(headtrans.basis.rotated(Vector3(0,1,0), deg2rad(180)), headtrans.origin - 3.5*vecahead + Vector3(vecahead.z, 0, -vecahead.x)*(playerlam-0.5)*2)
		#  Solve: headtrans = playerMe.global_transform * playerMe.get_node("HeadCam").transform 
		var backrelorigintrans = headtrans * playerMe.get_node("HeadCam").transform.inverse()
		var angvec = Vector2(playerMe.global_transform.basis.x.dot(backrelorigintrans.basis.x), playerMe.global_transform.basis.z.dot(backrelorigintrans.basis.x))
		var relang = angvec.angle()
		playerMe.global_transform = Transform(playerMe.global_transform.basis.rotated(Vector3(0,1,0), -relang), backrelorigintrans.origin + Vector3(0,2,0))
	else:
		playerMe.global_transform = playerMeD["transformpos"]

var caveworldchunkI = -1
var caveworldchunking_networkIDsource = -1
var xcdatalistReceivedDuringChunking = null
func caveworldreceivechunkingfailed(msg):
	print("caveworldreceivechunkingfailed ", msg, " ", caveworldchunking_networkIDsource)
	caveworldchunkI = -1
	caveworldchunking_networkIDsource = -1
	xcdatalistReceivedDuringChunking = null
	var guipanel3d = get_node("/root/Spatial/GuiSystem/GUIPanel3D")
	if guipanel3d.websocketclient != null:
		guipanel3d.websocketclient. disconnect_from_host()
	if guipanel3d.networkedmultiplayerenet != null:
		guipanel3d.networkedmultiplayerenet.close_connection()
	return null
	
remote func actsketchchangeL(xcdatalist):
	var playerMe = get_node("/root/Spatial").playerMe
	var fromremotecall = ("networkIDsource" in xcdatalist[0]) and xcdatalist[0]["networkIDsource"] != playerMe.networkID
	if "caveworldchunk" in xcdatalist[0]:
		if xcdatalist[0]["caveworldchunk"] == 0:
			Tglobal.printxcdrawingfromdatamessages = false
			clearentirecaveworld()
			if "playerMe" in xcdatalist[0]:
				spawnplayerme(xcdatalist[0]["playerMe"])
			caveworldchunking_networkIDsource = xcdatalist[0]["networkIDsource"]
			xcdatalistReceivedDuringChunking = [ ]
			get_node("/root/Spatial/BodyObjects/PlayerDirections").flywalkreversed = true
		elif xcdatalist[0]["networkIDsource"] != caveworldchunking_networkIDsource:
			return caveworldreceivechunkingfailed("mismatch in world chunk id source")
		elif xcdatalist[0]["caveworldchunk"] != caveworldchunkI + 1:
			return caveworldreceivechunkingfailed("mismatch in world chunk sequence")
		caveworldchunkI = xcdatalist[0]["caveworldchunk"]
		print("Loading caveworldchunk ", caveworldchunkI, " of ",  xcdatalist[0]["caveworldchunkLast"], " size ", len(xcdatalist))

	elif caveworldchunkI != -1:
		if xcdatalist[0]["networkIDsource"] == caveworldchunking_networkIDsource:
			return caveworldreceivechunkingfailed("non world chunk xcdata received from chunking source")
		xcdatalistReceivedDuringChunking.push_back(xcdatalist)	
		return

	elif "undoact" in xcdatalist[0]:
		if len(actsketchchangeundostack) != 0:
			# not done check this undo matches
			actsketchchangeundostack.pop_back()
			
	else:
		if fromremotecall:
			var playerOther = get_node("/root/Spatial/Players").get_node_or_null("NetworkedPlayer"+String(xcdatalist[0]["networkIDsource"]))
			if playerOther != null:
				if "overridingxcdrawing" in xcdatalist[0]:
					print("overridingxcdrawing ", xcdatalist[0].get("name"))
					playerOther.get_node("AnimationPlayer_actsketchchange_fixbad").play("actsketchchange_flash")
				else:
					playerOther.get_node("AnimationPlayer_actsketchchange").play("actsketchchange_flash")
		elif playerMe.doppelganger != null:
			playerMe.doppelganger.get_node("AnimationPlayer_actsketchchange").play("actsketchchange_flash")
		if combinabletransformposchange(xcdatalist):
			actsketchchangeundostack[-1][0].erase("rpcoptional")
			if "transformpos" in xcdatalist[0]:
				actsketchchangeundostack[-1][0]["transformpos"] = xcdatalist[0]["transformpos"]
			if "imgtrim" in xcdatalist[0]:
				actsketchchangeundostack[-1][0]["imgtrim"] = xcdatalist[0]["imgtrim"]
		else:
			while len(actsketchchangeundostack) >= 10:
				actsketchchangeundostack.pop_front()
			actsketchchangeundostack.push_back(xcdatalist)
			
	var xcdrawingstoupdate = { }
	var xctubestoupdate = { }
	var xcdrawingsrejected = [ ]
	for i in range(len(xcdatalist)):
		var xcdata = xcdatalist[i]
		if "caveworldchunk" in xcdata:
			pass
		elif "tubename" in xcdata:
			if Tglobal.printxcdrawingfromdatamessages:
				print("update tube ", xcdata["tubename"])
			if xcdata["tubename"] == "**notset":
				xcdata["tubename"] = "XCtube_"+xcdata["xcname0"]+"_"+xcdata["xcname1"]
			var xctube = xctubefromdata(xcdata)  # inline this in order to implement xcchangesequence logic
			if len(xctube.xcdrawinglink) == 0 and len(xctube.xcsectormaterials) == 0:
				removeXCtube(xctube)
				xctube.queue_free() 
				#Tglobal.soundsystem.quicksound("BlipSound", xcdrawing.global_transform*tpos)
			else:
				xctubestoupdate[xctube.get_name()] = xctube
				if "materialsectorschanged" in xcdata:
					for j in xcdata["materialsectorschanged"]:
						if j < len(xctube.xcsectormaterials) and j < xctube.get_node("XCtubesectors").get_child_count():
							get_node("/root/Spatial/MaterialSystem").updatetubesectormaterial(xctube.get_node("XCtubesectors").get_child(j), xctube.xcsectormaterials[j], false)
			
		elif "planview" in xcdata:
			var planviewsystem = get_node("/root/Spatial/PlanViewSystem")
			var plancamera = planviewsystem.get_node("PlanView/Viewport/PlanGUI/Camera")			
			if "plancamerapos" in xcdata["planview"]:
				plancamera.translation = xcdata["planview"]["plancamerapos"]
			if "plancamerasize" in xcdata["planview"]:
				plancamera.size = xcdata["planview"]["plancamerasize"]
				planviewsystem.get_node("RealPlanCamera/RealCameraBox").scale = Vector3(plancamera.size, 1.0, plancamera.size)
			if "transformpos" in xcdata["planview"]:
				planviewsystem.get_node("PlanView").global_transform = xcdata["planview"]["transformpos"]
			if "visible" in xcdata["planview"]:
				planviewsystem.actplanviewvisibleactive(xcdata["planview"]["visible"], 
														xcdata["planview"].get("planviewactive", true), 
														xcdata["planview"].get("tubesvisible", planviewsystem.planviewcontrols.get_node("CheckBoxTubesVisible").pressed))
														
		elif "xcvizstates" in xcdata:
			if Tglobal.printxcdrawingfromdatamessages:
				print("update vizstate ")
			for xcdrawingname in xcdata["xcvizstates"]:
				var xcdrawing = $XCdrawings.get_node_or_null(xcdrawingname)
				if xcdrawing != null:
					if not ("prevxcvizstates" in xcdata):
						xcdata["prevxcvizstates"] = { }
					xcdata["prevxcvizstates"][xcdrawingname] = xcdrawing.drawingvisiblecode
					if xcdrawing.drawingtype == DRAWING_TYPE.DT_XCDRAWING:
						xcdrawing.setdrawingvisiblecode(xcdata["xcvizstates"][xcdrawingname])
						for xctube in xcdrawing.xctubesconn:
							xctube.setxctubepathlinevisibility(self)

					elif xcdrawing.drawingtype == DRAWING_TYPE.DT_CENTRELINE:
						xcdata["prevxcvizstates"][xcdrawingname] = { xcdrawingname:DRAWING_TYPE.VIZ_XCD_HIDE }
						xcdrawing.setdrawingvisiblecode(xcdata["xcvizstates"][xcdrawingname])

					elif xcdrawing.drawingtype == DRAWING_TYPE.DT_FLOORTEXTURE:
						xcdrawing.setdrawingvisiblecode(xcdata["xcvizstates"][xcdrawingname])
						
			if "updatetubeshells" in xcdata:
				for xct in xcdata["updatetubeshells"]:
					var xctube = findxctube(xct["xcname0"], xct["xcname1"])
					#var xctube = $XCtubes.get_node_or_null(xct["xctubename"])
					if xctube != null:
						xctube.updatetubeshell($XCdrawings, Tglobal.tubeshellsvisible)
			if "updatexcshells" in xcdata:
				for xcdrawingname in xcdata["updatexcshells"]:
					var xcdrawing = $XCdrawings.get_node_or_null(xcdrawingname)
					if xcdrawing != null:
						xcdrawing.updatexctubeshell($XCdrawings, Tglobal.tubeshellsvisible)
						
		else:  # xcdrawing
			assert ("name" in xcdata)
			if "transformpos" in xcdata and not ("prevtransformpos" in xcdata) and not fromremotecall:
				var lxcdrawing = $XCdrawings.get_node_or_null(xcdata["name"])
				if lxcdrawing != null:
					xcdata["prevtransformpos"] = lxcdrawing.transform
			if "overridingxcdrawing" in xcdata:
				assert(fromremotecall)
				var xcd = $XCdrawings.get_node_or_null(xcdata["name"])
				if xcd != null:
					xcd.xcchangesequence = -1
			var xcdrawing = xcdrawingfromdata(xcdata, fromremotecall)
			if xcdrawing == null:
				xcdrawingsrejected.append(xcdata["name"])
				print("rejecting XC drawing from data", xcdata)
			elif "nodepoints" in xcdata or "nextnodepoints" in xcdata or "onepathpairs" in xcdata or "newonepathpairs" in xcdata:
				xcdrawingstoupdate[xcdrawing.get_name()] = xcdrawing
				if len(xcdata.get("prevnodepoints", [])) != 0:
					for xctube in xcdrawing.xctubesconn:
						xctubestoupdate[xctube.get_name()] = xctube
			elif "transformpos" in xcdata and len(xcdrawing.xctubesconn) != 0:
				for xctube in xcdrawing.xctubesconn:
					xctubestoupdate[xctube.get_name()] = xctube
					
			if caveworldchunkI == -1 and xcdrawing != null:
				var tpos = null
				var xcname = null
				var sname = "ClickSound"
				if len(xcdata.get("nextnodepoints", [])) != 0:
					tpos = xcdata["nextnodepoints"].values()[0]
				elif len(xcdata.get("prevnodepoints", [])) != 0:
					tpos = xcdata["prevnodepoints"].values()[0]
					sname = "BlipSound"
				elif len(xcdata.get("newonepathpairs", [])) != 0:
					xcname = xcdata["newonepathpairs"][0]
				elif len(xcdata.get("prevonepathpairs", [])) != 0:
					xcname = xcdata["prevonepathpairs"][0]
				if xcname != null:
					var xcn = xcdrawing.get_node("XCnodes").get_node_or_null(xcname)
					if xcn != null:
						tpos = xcn.translation
				if tpos != null:
					Tglobal.soundsystem.quicksound(sname, xcdrawing.global_transform*tpos)

	for xcdrawing in xcdrawingstoupdate.values():
		xcdrawing.updatexcpaths()
	for xctube in xctubestoupdate.values():
		xctube.updatetubelinkpaths(self)

	if caveworldchunkI != -1:
		changetubedxcsvizmode(xcdrawingstoupdate.values())
		for xctube in xctubestoupdate.values():
			if not xctube.positioningtube:
				xctube.updatetubeshell($XCdrawings, Tglobal.tubeshellsvisible)
				xctube.setxctubepathlinevisibility(self)
		for xcdrawing in xcdrawingstoupdate.values():
			if xcdrawing.drawingtype == DRAWING_TYPE.DT_XCDRAWING:
				xcdrawing.updatexctubeshell($XCdrawings, Tglobal.tubeshellsvisible)
				
		if xcdatalist[0]["caveworldchunk"] == xcdatalist[0]["caveworldchunkLast"]:
			caveworldchunkI = -1
			caveworldchunking_networkIDsource = -1
			var xcdatalistReceivedDuringChunkingL = xcdatalistReceivedDuringChunking
			xcdatalistReceivedDuringChunking = null
			Tglobal.printxcdrawingfromdatamessages = true
			updatecentrelinevisibility()
			var flywalkreversed = get_node("/root/Spatial/GuiSystem/GUIPanel3D/Viewport/GUI/Panel/FlyWalkReversed").pressed
			get_node("/root/Spatial/BodyObjects/PlayerDirections").flywalkreversed = flywalkreversed
			if not flywalkreversed:
				get_node("/root/Spatial/BodyObjects/PlayerDirections").forceontogroundtimedown = 0.25
			if len(xcdatalistReceivedDuringChunkingL) != 0:
				print("Now processing ", len(xcdatalistReceivedDuringChunkingL), " received during chunking")
				for xcdatalistR in xcdatalistReceivedDuringChunkingL:
					actsketchchangeL(xcdatalistR)

	if len(xcdrawingsrejected) != 0:
		print("The following drawings have bad change sequences and need to be requested from the server", xcdrawingsrejected)
		if playerMe.networkID == 1:
			sendoverridingxcdrawingsdata(xcdrawingsrejected, xcdatalist[0]["networkIDsource"])
		else:
			rpc_id(1, "sendoverridingxcdrawingsdata", xcdrawingsrejected, playerMe.networkID)
			
	return null
		
remote func sendoverridingxcdrawingsdata(xcdrawingsrejected, playeridtoupdate):
	var playerMe = get_node("/root/Spatial").playerMe
	assert (playerMe.networkID == 1)
	var xcdatalist = [ ]
	for xcdrawingname in xcdrawingsrejected:
		var xcdrawing = $XCdrawings.get_node_or_null(xcdrawingname)
		if xcdrawingname != null:
			var xcdata = xcdrawing.exportxcrpcdata()
			xcdata["overridingxcdrawing"] = 1
			xcdata["xcchangesequence"] = xcdrawing.xcchangesequence
			xcdata["networkIDsource"] = playerMe.networkID
			xcdatalist.push_back(xcdata)
	rpc_id(playeridtoupdate, "actsketchchangeL", xcdatalist)
		
	
func xcdrawingfromdata(xcdata, fromremotecall):
	var xcdrawing = $XCdrawings.get_node_or_null(xcdata["name"])
	if xcdrawing == null:
		if Tglobal.printxcdrawingfromdatamessages:
			print("New xcdrawing ", xcdata.get("name"), " type: ", xcdata.get("drawingtype"))
		if not ("drawingtype" in xcdata):
			print("BAD new xcdrawingfromdata missing drawingtype ", xcdata)
			assert(false)
			return null
		elif xcdata["drawingtype"] == DRAWING_TYPE.DT_FLOORTEXTURE or xcdata["drawingtype"] == DRAWING_TYPE.DT_PAPERTEXTURE:
			xcdrawing = newXCuniquedrawingPaperN(xcdata["xcresource"], xcdata["name"], xcdata["drawingtype"])
		else:
			xcdrawing = newXCuniquedrawing(xcdata["drawingtype"], xcdata["name"])
	
	elif Tglobal.printxcdrawingfromdatamessages and not (xcdata.get("rpcoptional", 0) == 1):
		print("update xcdrawing ", xcdata.get("name"), " ", xcdrawing.xcchangesequence)

	if not (xcdata.get("rpcoptional", 0) == 1):
		xcdrawing.xcchangesequence += 1
	if not fromremotecall:
		xcdata["xcchangesequence"] = xcdrawing.xcchangesequence
	elif "xcchangesequence" in xcdata and xcdata["xcchangesequence"] != xcdrawing.xcchangesequence:
		if xcdrawing.xcchangesequence == 0:
			xcdrawing.xcchangesequence = xcdata["xcchangesequence"]
		else:
			print("Mismatch change sequence in drawing ", xcdata["name"], " remote ", xcdata["xcchangesequence"], " here ", xcdrawing.xcchangesequence)
			return null
		  
	var t0 = OS.get_ticks_msec()
	xcdrawing.mergexcrpcdata(xcdata)
	var dt = OS.get_ticks_msec() - t0
	if dt > 100:
		print("    Warning: long mergexcrpcdata operation happened for ", xcdata["name"], " of ", dt, " msecs", " nodes ", len(xcdrawing.nodepoints))
		
	if xcdrawing.drawingtype == DRAWING_TYPE.DT_FLOORTEXTURE or xcdrawing.drawingtype == DRAWING_TYPE.DT_PAPERTEXTURE:
		if "xcresource" in xcdata:
			get_node("/root/Spatial/ImageSystem").fetchpaperdrawing(xcdrawing)
	if xcdrawing.drawingtype == DRAWING_TYPE.DT_CENTRELINE:
		#assert (false)   # shouldn't happen, not to be updated!
		var LabelGenerator = get_node("/root/Spatial/LabelGenerator")
		LabelGenerator.addnodestolabeltaskN(xcdrawing)
		if Tglobal.centrelinevisible:
			var playerMe = get_node("/root/Spatial").playerMe
			LabelGenerator.restartlabelmakingprocess(playerMe.get_node("HeadCam").global_transform.origin)
	return xcdrawing

var playeroriginXCSorter = Vector3(0, 0, 0)
func xcsorterfunc(a, b):
	return playeroriginXCSorter.distance_to(a.transformpos.origin) < playeroriginXCSorter.distance_to(b.transformpos.origin)
	
func sketchdicttochunks(sketchdatadict):
	var xcdatachunkL = [ { "caveworldchunk":0 } ]
	playeroriginXCSorter = Vector3(0, 0, 0)
	if "playerMe" in sketchdatadict:
		xcdatachunkL[0]["playerMe"] = sketchdatadict["playerMe"]
		playeroriginXCSorter = sketchdatadict["playerMe"]["headtrans"].origin
	var xcdrawingsD = sketchdatadict["xcdrawings"]
	xcdrawingsD.sort_custom(self, "xcsorterfunc")
	var xctubesarrayD = sketchdatadict["xctubes"]
	var xcdrawingnamemapItubes = { }
	for i in range(len(xctubesarrayD)):
		var xctubeD = xctubesarrayD[i]

		# (I think the file was corrupted by incompletely writing)
		if xctubeD == null:
			print("Null tube in array at ", i, " of ", len(xctubesarrayD))
			continue
		if "xcdrawinglink" in xctubeD:
			if not ("xcsectormaterials" in xctubeD):
				print("Bad tube in array at ", i, " of ", len(xctubesarrayD))
				continue
			
		if not (xctubeD.xcname0 in xcdrawingnamemapItubes):
			xcdrawingnamemapItubes[xctubeD.xcname0] = [ ]
		xcdrawingnamemapItubes[xctubeD.xcname0].push_back(i)
		if not (xctubeD.xcname1 in xcdrawingnamemapItubes):
			xcdrawingnamemapItubes[xctubeD.xcname1] = [ ]
		xcdrawingnamemapItubes[xctubeD.xcname1].push_back(i)

	var xcdatachunks = [ xcdatachunkL ]
	var nnodesL = 0
	var xctubesDmaphalfstaged = { }
	for j in range(len(xcdrawingsD)):
		var xcdrawingD = xcdrawingsD[j]
		if len(xcdatachunkL) > 50 or nnodesL > 400 and j < len(xcdrawingsD) - 10:
			xcdatachunkL = [ { "caveworldchunk":len(xcdatachunks) } ]
			xcdatachunks.push_back(xcdatachunkL)
			nnodesL = 0
		#if xcdrawingD["drawingtype"] == DRAWING_TYPE.DT_XCDRAWING and len(xcdrawingD.nodepoints) == 0:
		#	print("Discarding xcdrawing ", xcdrawingD["name"])
			continue
		xcdatachunkL.push_back(xcdrawingD)
		nnodesL += len(xcdrawingD.nodepoints)
		for i in xcdrawingnamemapItubes.get(xcdrawingD["name"], []):
			var xctubeD = xctubesDmaphalfstaged.get(i)
			if xctubeD != null:
				if "name" in xctubeD:
					xctubeD["tubename"] = xctubeD["name"]
					xctubeD.erase("name")
				xcdatachunkL.push_back(xctubeD)
				xctubesDmaphalfstaged.erase(i)
			if xctubesarrayD[i] != null:
				assert (xctubesDmaphalfstaged.get(i) == null)
				xctubesDmaphalfstaged[i] = xctubesarrayD[i]
				xctubesarrayD[i] = null

	var playerMe = get_node("/root/Spatial").playerMe				
	for i in range(len(xcdatachunks)):
		xcdatachunks[i][0]["caveworldchunkLast"] = xcdatachunks[-1][0]["caveworldchunk"]
		xcdatachunks[i][0]["networkIDsource"] = playerMe.networkID
	return xcdatachunks
	
remote func loadsketchsystemL(fname):
	var sketchdatafile = File.new()
	if sketchdatafile.file_exists(fname):
		print("Loading sketchsystemtodict from ", fname)
		sketchdatafile.open(fname, File.READ)
		var sketchdatadict = sketchdatafile.get_var()
		sketchdatafile.close()
		print("Generating sketchdicttochunks")
		var xcdatachunks = sketchdicttochunks(sketchdatadict)
		print("Generated ", len(xcdatachunks), " chunks")
		for xcdatachunk in xcdatachunks:
			actsketchchange(xcdatachunk)
			yield(get_tree().create_timer(0.2), "timeout")
			
func uniqueXCname():
	var largestxcdrawingnumber = 0
	for xcdrawing in get_node("XCdrawings").get_children():
		var xcname = xcdrawing.get_name()
		var ns = xcname.find_last("s")
		if ns != -1:
			largestxcdrawingnumber = max(largestxcdrawingnumber, int(xcname.right(ns + 1)))
	var sname = "s%d" % (largestxcdrawingnumber+1)
	return sname
	
func newXCuniquedrawing(drawingtype, sname):
	var xcdrawing = XCdrawing.instance()
	xcdrawing.drawingtype = drawingtype
	xcdrawing.set_name(sname)
	get_node("XCdrawings").add_child(xcdrawing)
	assert (sname == xcdrawing.get_name())
	if drawingtype == DRAWING_TYPE.DT_XCDRAWING:
		xcdrawing.add_to_group("gpnoncentrelinegeo")
		xcdrawing.linewidth = 0.05
		xcdrawing.drawingvisiblecode = DRAWING_TYPE.VIZ_XCD_PLANE_AND_NODES_VISIBLE
		
	elif drawingtype == DRAWING_TYPE.DT_CENTRELINE:
		var xcnodesplanview = Spatial.new()
		xcnodesplanview.set_name("XCnodes_PlanView")
		xcdrawing.add_child(xcnodesplanview)
		xcdrawing.add_to_group("gpcentrelinegeo")
		xcdrawing.linewidth = 0.035
		xcdrawing.drawingvisiblecode = DRAWING_TYPE.VIZ_XCD_HIDE
		xcdrawing.get_node("PathLines").visible = true
		xcdrawing.get_node("PathLines").layers = CollisionLayer.VL_centrelinedrawinglines
		xcdrawing.get_node("XCnodes").visible = true
	
	else:
		assert (false)
	return xcdrawing
	

func uniqueXCdrawingPapername(xcresource):
	var fname = get_node("/root/Spatial/ImageSystem").getshortimagename(xcresource, false, 6)
	var sname = fname+","
	for i in range($XCdrawings.get_child_count()+1):
		sname = fname+","+String(i)
		if not $XCdrawings.has_node(sname):
			break
	return sname

func newXCuniquedrawingPaperN(xcresource, sname, drawingtype):
	var xcdrawing = XCdrawing.instance()
	xcdrawing.drawingtype = drawingtype
	xcdrawing.drawingvisiblecode = DRAWING_TYPE.VIZ_XCD_FLOOR_NORMAL
	xcdrawing.xcresource = xcresource
	xcdrawing.set_name(sname)
	$XCdrawings.add_child(xcdrawing)
	assert (sname == xcdrawing.get_name())
	
	if xcdrawing.drawingtype == DRAWING_TYPE.DT_FLOORTEXTURE:
		xcdrawing.get_node("XCdrawingplane").collision_layer = CollisionLayer.CL_Environment | CollisionLayer.CL_PointerFloor
	else:
		xcdrawing.get_node("XCdrawingplane").collision_layer = CollisionLayer.CL_Pointer
	
	xcdrawing.get_node("XCdrawingplane").visible = true
	xcdrawing.get_node("XCdrawingplane/CollisionShape").disabled = false
	#var m = preload("res://surveyscans/scanimagefloor.material").duplicate()
	#m.albedo_texture = ImageTexture.new()
	var m = get_node("/root/Spatial/MaterialSystem").get_node("xcdrawingmaterials/floorbordered").get_surface_material(0).duplicate()
	#m.set_shader_param("texture_albedo", ImageTexture.new())
	xcdrawing.get_node("XCdrawingplane/CollisionShape/MeshInstance").set_surface_material(0, m)

	return xcdrawing

func newXCtube(xcdrawing0, xcdrawing1):
	assert ((xcdrawing0.drawingtype == DRAWING_TYPE.DT_XCDRAWING and xcdrawing1.drawingtype == DRAWING_TYPE.DT_XCDRAWING) or
			(xcdrawing0.drawingtype == DRAWING_TYPE.DT_FLOORTEXTURE and xcdrawing1.drawingtype == DRAWING_TYPE.DT_XCDRAWING) or
			(xcdrawing0.drawingtype == DRAWING_TYPE.DT_CENTRELINE and xcdrawing1.drawingtype == DRAWING_TYPE.DT_FLOORTEXTURE))

	var xctube = XCtube.instance()
	xctube.xcname0 = xcdrawing0.get_name()
	xctube.xcname1 = xcdrawing1.get_name()
	xctube.positioningtube = xcdrawing0.drawingtype != DRAWING_TYPE.DT_XCDRAWING or xcdrawing1.drawingtype != DRAWING_TYPE.DT_XCDRAWING
	xctube.set_name("XCtube_"+xctube.xcname0+"_"+xctube.xcname1)
	xcdrawing0.xctubesconn.append(xctube)
	xcdrawing1.xctubesconn.append(xctube)
	assert (not $XCtubes.has_node(xctube.get_name()))
	$XCtubes.add_child(xctube)
	xctube.add_to_group("gpnoncentrelinegeo")
	return xctube
	
func removeXCtube(xctube):
	var xcdrawing0 = $XCdrawings.get_node_or_null(xctube.xcname0)
	var xcdrawing1 = $XCdrawings.get_node_or_null(xctube.xcname1)
	if xcdrawing0 != null:
		var i = xcdrawing0.xctubesconn.find(xctube)
		if i != -1:
			xcdrawing0.xctubesconn.remove(i)
	if xcdrawing1 != null:
		var i = xcdrawing1.xctubesconn.find(xctube)
		if i != -1:
			xcdrawing1.xctubesconn.remove(i)
