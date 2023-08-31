extends Spatial

const XCdrawing = preload("res://nodescenes/XCdrawing.tscn")
const XCtube = preload("res://nodescenes/XCtube.tscn")
const RopeHang = preload("res://nodescenes/RopeHang.tscn")


const linewidth = 0.05
var sketchname = "unnamedsketch"
const fileheading = "__tunnelvr__ "
const savesketchasjsonlines = true

var actsketchchangeundostack = [ ]

var pointersystem = null
onready var waterlevelsystem = get_node("/root/Spatial/WaterLevelSystem")
onready var planviewsystem = get_node("/root/Spatial/PlanViewSystem")
var allflagtrails = [ ]

func _ready():
	return

func findxctube(xcname0, xcname1):
	var xcdrawing0 = get_node("XCdrawings").get_node_or_null(xcname0)
	if xcdrawing0 != null:
		for xctube in xcdrawing0.xctubesconn:
			if xctube.xcname1 == xcname1 and xctube.xcname0 == xcname0:
				return xctube
			if xctube.xcname0 == xcname1 and xctube.xcname1 == xcname0:
				return xctube
	return null
	
func setnewtubename(xctdata):
	assert (not xctdata.has("tubename") or xctdata["tubename"] == "**notset")
	var xcdrawing0 = get_node("XCdrawings").get_node_or_null(xctdata["xcname0"])
	var xcdrawing1 = get_node("XCdrawings").get_node_or_null(xctdata["xcname1"])
	var tubenameprefix = "Unknown_"
	if xcdrawing0 == null or xcdrawing1 == null or xcdrawing0.drawingtype == DRAWING_TYPE.DT_XCDRAWING:
		tubenameprefix = "XCtube_"
	elif xcdrawing0.drawingtype == DRAWING_TYPE.DT_CENTRELINE:
		if xcdrawing1.drawingtype == DRAWING_TYPE.DT_FLOORTEXTURE:
			tubenameprefix = "Floorpos_"
		elif xcdrawing1.drawingtype == DRAWING_TYPE.DT_CENTRELINE:
			tubenameprefix = "CAssoc_"
	xctdata["tubename"] = tubenameprefix+xctdata["xcname0"]+"_"+xctdata["xcname1"]
	if Tglobal.notisloadingcavechunks:
		print("new tube name ", xctdata["tubename"])
		
	
func sketchsystemtodict(stripruntimedataforsaving):
	var xcdrawingsData = [ ]
	for xcdrawing in $XCdrawings.get_children():
		if xcdrawing.drawingtype == DRAWING_TYPE.DT_XCDRAWING and len(xcdrawing.nodepoints) == 0 and stripruntimedataforsaving:
			print("Discarding empty xcdrawing on save ", xcdrawing.get_name())
		elif xcdrawing.drawingtype == DRAWING_TYPE.DT_FLOORTEXTURE and xcdrawing.drawingvisiblecode == DRAWING_TYPE.VIZ_XCD_FLOOR_DELETED:
			print("Discarding hidden floortexture on save ", xcdrawing.get_name())
		elif xcdrawing.drawingtype == DRAWING_TYPE.DT_ROPEHANG and len(xcdrawing.nodepoints) == 0 and stripruntimedataforsaving:
			print("Discarding empty ropehang on save ", xcdrawing.get_name())
		elif xcdrawing.drawingtype == DRAWING_TYPE.DT_CENTRELINE and len(xcdrawing.nodepoints) == 0 and stripruntimedataforsaving:
			print("Discarding empty centreline on save ", xcdrawing.get_name())
		else:
			xcdrawingsData.append(xcdrawing.exportxcrpcdata(stripruntimedataforsaving))
	var xctubesData = [ ]
	for xctube in $XCtubes.get_children():
		xctubesData.append(xctube.exportxctrpcdata(stripruntimedataforsaving))
	var sketchdatadict = { "sketchname":sketchname,
						   "xcdrawings":xcdrawingsData,
						   "xctubes":xctubesData
						 }
	var playerMe = get_node("/root/Spatial").playerMe
	sketchdatadict["playerMe"] = { "playerplatform":playerMe.playerplatform,
								   "playername":playerMe.playerhumanname,
								   "tunnelvrversion":Tglobal.tunnelvrversion, 
								   "datetime":OS.get_datetime(),
								   "transformpos":playerMe.global_transform, 
								   "headtrans":playerMe.get_node("HeadCam").global_transform }
	return sketchdatadict
	

remote func savesketchsystem(fname):
	var sketchdatadict = sketchsystemtodict(true)
	var sketchdatafile = File.new()
	var fnamewriting = fname + "_WRITING"
	sketchdatafile.open(fnamewriting, File.WRITE)
	if savesketchasjsonlines:
		sketchdatafile.store_line("%s%s" % [fileheading, sketchdatadict["sketchname"]])
		var pm = sketchdatadict["playerMe"]
		pm["stransformpos"] = var2str(pm["transformpos"])
		pm.erase("transformpos")
		pm["sheadtrans"] = var2str(pm["headtrans"])
		pm.erase("headtrans")
		pm["Nxcdrawings"] = len(sketchdatadict["xcdrawings"])
		pm["Nxctubes"] = len(sketchdatadict["xctubes"])
		sketchdatafile.store_line(to_json(pm))

		for xcdrawingDat in sketchdatadict["xcdrawings"]:
			xcdrawingDat["stransformpos"] = var2str(xcdrawingDat["transformpos"])
			xcdrawingDat.erase("transformpos")
			xcdrawingDat["snodepoints"] = { }
			for node in xcdrawingDat["nodepoints"]:
				var p = xcdrawingDat["nodepoints"][node]
				xcdrawingDat["snodepoints"][node] = [p.x, p.y, p.z]
			xcdrawingDat.erase("nodepoints")
			if "imgtrim" in xcdrawingDat:
				xcdrawingDat["imgtrim"]["simgtrimleftdown"] = var2str(xcdrawingDat["imgtrim"]["imgtrimleftdown"])
				xcdrawingDat["imgtrim"].erase("imgtrimleftdown")
				xcdrawingDat["imgtrim"]["simgtrimrightup"] = var2str(xcdrawingDat["imgtrim"]["imgtrimrightup"])
				xcdrawingDat["imgtrim"].erase("imgtrimrightup")
			sketchdatafile.store_line(to_json(xcdrawingDat))

		for xctubeDat in sketchdatadict["xctubes"]:
			if "xclinkintermediatenodes" in xctubeDat:
				xctubeDat["sxclinkintermediatenodes"] = [ ]
				for xci in xctubeDat["xclinkintermediatenodes"]:
					var sxci = [ ]
					for p in xci:
						sxci.push_back([p.x, p.y, p.z])
					xctubeDat["sxclinkintermediatenodes"].push_back(sxci)
				xctubeDat.erase("xclinkintermediatenodes")
			sketchdatafile.store_line(to_json(xctubeDat))
	else:
		sketchdatafile.store_var(sketchdatadict)

	sketchdatafile.close()
	Directory.new().rename(fnamewriting, fname)
	print("saved ", fname, " in ", OS.get_user_data_dir())

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

	################## # VVV--- the main function you want to step into
	actsketchchangeL(xcdatalist)  
	################## #
	
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
		guipanel3d.websocketclient.disconnect_from_host()
	if guipanel3d.networkedmultiplayerenetclient != null:
		guipanel3d.networkedmultiplayerenetclient.close_connection()
	return null
	
remote func actsketchchangeL(xcdatalist):
	var playerMe = get_node("/root/Spatial").playerMe
	var fromremotecall = ("networkIDsource" in xcdatalist[0]) and xcdatalist[0]["networkIDsource"] != playerMe.networkID
	var planviewtype = false
	if "caveworldchunk" in xcdatalist[0]:
		if xcdatalist[0]["caveworldchunk"] == 0:
			var PlayerDirections = get_node("/root/Spatial/BodyObjects/PlayerDirections")
			Tglobal.notisloadingcavechunks = false
			Tglobal.housahedronmode = false
			get_node("tunnelxoutline").visible = false
			planviewsystem.backfacecartoonValid = false
			if xcdatalist[0]["sketchname"] != "importing_the_centreline__do_not_clear":
				clearentirecaveworld()
			else:
				print("** not clearing due to sketchname being importing_the_centreline__do_not_clear")
				PlayerDirections.forceontogroundtimedown = 0.75
			if "playerMe" in xcdatalist[0]:
				spawnplayerme(xcdatalist[0]["playerMe"])
				var playerserver = get_node_or_null("/root/Spatial/Players/NetworkedPlayer1")
				if fromremotecall and playerserver != null and playerserver != playerMe:
					PlayerDirections.setasaudienceofpuppet(xcdatalist[0]["playerMe"]["headtrans"], 30)
				else:
					PlayerDirections.setatheadtrans(xcdatalist[0]["playerMe"]["headtrans"], 30)
			caveworldchunking_networkIDsource = xcdatalist[0]["networkIDsource"]
			xcdatalistReceivedDuringChunking = [ ]
			get_node("/root/Spatial/BodyObjects/LaserOrient/NotificationCylinder").visible = true
		elif xcdatalist[0]["networkIDsource"] != caveworldchunking_networkIDsource:
			return caveworldreceivechunkingfailed("mismatch in world chunk id source")
		elif xcdatalist[0]["caveworldchunk"] != caveworldchunkI + 1:
			return caveworldreceivechunkingfailed("mismatch in world chunk sequence")
		caveworldchunkI = xcdatalist[0]["caveworldchunk"]
		print("Loading caveworldchunk ", caveworldchunkI, " of ",  xcdatalist[0]["caveworldchunkLast"], " size ", len(xcdatalist))
		get_node("/root/Spatial/BodyObjects/LaserOrient/NotificationCylinder").scale.y = (xcdatalist[0]["caveworldchunkLast"] - caveworldchunkI) + 1

	elif len(xcdatalist) == 1 and "planview" in xcdatalist[0]:
		planviewtype = true
		
	elif caveworldchunkI != -1:
		if xcdatalist[0]["networkIDsource"] == caveworldchunking_networkIDsource:
			return caveworldreceivechunkingfailed("non world chunk xcdata received from chunking source")
		elif xcdatalist[0]["networkIDsource"] == playerMe.networkID:
			return caveworldreceivechunkingfailed("player making edits during incomplete chunking")
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
				if "overridingxcdrawing" in xcdatalist[0] or "overridingxctube" in xcdatalist[0]:
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

	if "sketchname" in xcdatalist[0]:
		if sketchname != "importing_the_centreline__do_not_clear":
			sketchname = xcdatalist[0]["sketchname"]
			if xcdatalist[0].has("ghcurrentsha"):
				var GithubAPI = get_node("/root/Spatial/ImageSystem/GithubAPI")
				GithubAPI.ghcurrentname = sketchname+".res"
				GithubAPI.ghcurrentsha = xcdatalist[0]["ghcurrentsha"]
			if sketchname == "importing_the_centreline__do_not_clear":
				sketchname = "--centrelinesketch"
				if xcdatalist[1].get("drawingtype", 0) == DRAWING_TYPE.DT_CENTRELINE:
					var f3durl = xcdatalist[1].get("xcresource", "")
					if f3durl.ends_with(".3d"):
						sketchname = f3durl.split("/")[-1].split(".")[0]
			get_node("/root/Spatial/GuiSystem/GUIPanel3D").setsavegamefilename(sketchname)
		
	var xcdrawingstoupdate = { }
	var xcdrawingstoupdatevisiblecodes = { }
	var xctubestoupdate = { }
	var xcdrawingsrejected = [ ]
	var xctubesrejected = [ ]
	for i in range(len(xcdatalist)):
		var xcdata = xcdatalist[i]
		if "caveworldchunk" in xcdata:
			pass
		elif "tubename" in xcdata:
			if Tglobal.notisloadingcavechunks:
				print("update tube ", xcdata["tubename"])
			assert (xcdata.has("tubename") and xcdata["tubename"] != "**notset")
			var xctube = findxctube(xcdata["xcname0"], xcdata["xcname1"])
			if xctube == null:
				var xcdrawing0 = get_node("XCdrawings").get_node(xcdata["xcname0"])
				var xcdrawing1 = get_node("XCdrawings").get_node(xcdata["xcname1"])
				if xcdrawing0 == null or xcdrawing1 == null:
					print("bad tube  ", (xcdata["xcname0"] if xcdrawing0 == null else ""), " ", (xcdata["xcname1"] if xcdrawing1 == null else ""))
					continue
				assert (not (xcdrawing0.drawingtype != DRAWING_TYPE.DT_CENTRELINE and xcdrawing1.drawingtype == DRAWING_TYPE.DT_CENTRELINE))
				xcdata["m0"] = 0
				xctube = newXCtube(xcdata["tubename"], xcdrawing0, xcdrawing1)
				if xcdrawing0.drawingtype == DRAWING_TYPE.DT_XCDRAWING:
					xctube.makeplaneintersectionaxisvec(xcdrawing0, xcdrawing1)
			else:
				xcdata["m0"] = 0 if xctube.xcname0 == xcdata["xcname0"] else 1

			if "overridingxctube" in xcdata:
				assert(fromremotecall)
				print("overridingxctube ", xcdata.get("tubename"), " hereseq:", xctube.xctchangesequence, " remoteseq:", xcdata["overridingxctube"])
				xctube.xctchangesequence = -1
			xctube.xctchangesequence += 1
			if not fromremotecall:
				xcdata["xctchangesequence"] = xctube.xctchangesequence
			elif "xctchangesequence" in xcdata and xcdata["xctchangesequence"] != xctube.xctchangesequence:
				if xctube.xctchangesequence == 0:
					xctube.xctchangesequence = xcdata["xctchangesequence"]
				else:
					print("Mismatch change sequence in xctube ", xcdata["tubename"], " remote ", xcdata["xctchangesequence"], " here ", xctube.xctchangesequence)
					xctube = null
			if xctube != null:
				xctube.mergexctrpcdata(xcdata)
				if len(xctube.xcdrawinglink) == 0 and len(xctube.xcsectormaterials) == 0:
					print("*** removing empty tube problem")
					removeXCtube(xctube)
					xctube.queue_free() 
				else:
					xctubestoupdate[xctube.get_name()] = xctube
					if "materialsectorschanged" in xcdata:
						for j in xcdata["materialsectorschanged"]:
							if j < len(xctube.xcsectormaterials) and j < xctube.get_node("XCtubesectors").get_child_count():
								get_node("/root/Spatial/MaterialSystem").updatetubesectormaterial(xctube.get_node("XCtubesectors").get_child(j), xctube.xcsectormaterials[j], false)
			else:
				xctubesrejected.append({"tubename":xcdata["tubename"], "xcname0":xcdata["xcname0"], "xcname1":xcdata["xcname1"]})
				print("rejecting XC tube from data", xcdata)
							
		elif "planview" in xcdata:
			planviewsystem.actplanviewdict(xcdata["planview"], false)
														
		elif "xcvizstates" in xcdata:
			if Tglobal.notisloadingcavechunks:
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

					elif xcdrawing.drawingtype == DRAWING_TYPE.DT_ROPEHANG:
						xcdrawing.setdrawingvisiblecode(xcdata["xcvizstates"][xcdrawingname])

						
			if "updatetubeshells" in xcdata:
				for xct in xcdata["updatetubeshells"]:
					var xctube = findxctube(xct["xcname0"], xct["xcname1"])
					if xctube != null:
						if xctube.xcname0 != xctube.xcname1:
							xctube.updatetubeshell($XCdrawings)
							waterlevelsystem.checkupdatewaterlevelintube(xctube.get_name())
						else:
							xctube.updatetunnelxareas($XCdrawings)
			if "updatexcshells" in xcdata:
				for xcdrawingname in xcdata["updatexcshells"]:
					var xcdrawing = $XCdrawings.get_node_or_null(xcdrawingname)
					if xcdrawing != null and xcdrawing.drawingtype == DRAWING_TYPE.DT_XCDRAWING:
						xcdrawing.updatexcshellmesh(xcdrawing.makexcflatshell($XCdrawings))
						
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
					print("overridingxcdrawing ", xcdata.get("name"), " hereseq:", xcd.xcchangesequence, " remoteseq:", xcdata["overridingxcdrawing"])
					xcd.xcchangesequence = -1
			var xcdrawing = xcdrawingfromdata(xcdata, fromremotecall)
			if xcdrawing == null:
				xcdrawingsrejected.append(xcdata["name"])
				print("rejecting XC drawing from data", xcdata)

			#elif xcdrawing.drawingtype == DRAWING_TYPE.DT_CENTRELINE and len(xcdrawing.nodepoints) == 0 and len(xcdata.get("prevnodepoints", [])) != 0:
			#	print("immediate deletion of centreline xcdrawing case; not waiting for file save")
			#	xcdrawing.queue_free()

			elif "nodepoints" in xcdata or "nextnodepoints" in xcdata or "onepathpairs" in xcdata or "newonepathpairs" in xcdata:
				if xcdata.has("drawingvisiblecode") and xcdrawing.drawingtype == DRAWING_TYPE.DT_ROPEHANG:
					xcdrawing.drawingvisiblecode = xcdata["drawingvisiblecode"]
				xcdrawingstoupdate[xcdrawing.get_name()] = xcdrawing
				
				if len(xcdata.get("prevnodepoints", [])) != 0:
					for xctube in xcdrawing.xctubesconn:
						xctubestoupdate[xctube.get_name()] = xctube
				if len(xcdata.get("nextnodepoints", [])) == 1 and xcdrawing.drawingtype == DRAWING_TYPE.DT_XCDRAWING:
					for xcnname in xcdata["nextnodepoints"]:
						var xcn = xcdrawing.get_node("XCnodes").get_node_or_null(xcnname)
						if xcn != null and xcdrawing.drawingtype == DRAWING_TYPE.DT_XCDRAWING:
							xcdrawing.expandxcdrawingscale(xcn.global_transform.origin)
								
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
			elif xcdata.has("drawingvisiblecode") and xcdrawing != null:
				xcdrawingstoupdatevisiblecodes[xcdrawing.get_name()] = xcdata["drawingvisiblecode"]
				
	for xcdrawing in xcdrawingstoupdate.values():
		if xcdrawing.drawingtype == DRAWING_TYPE.DT_ROPEHANG:
			#if xcdrawing.drawingvisiblecode != DRAWING_TYPE.VIZ_XCD_HIDE:
			#	xcdrawing.updatelinearropepaths()
			xcdrawing.setdrawingvisiblecode(xcdrawing.drawingvisiblecode)
		elif xcdrawing.drawingtype == DRAWING_TYPE.DT_CENTRELINE:
			xcdrawing.updatexcpaths_centreline(xcdrawing.get_node("PathLines"), xcdrawing.linewidth)
			if planviewsystem.planviewactive:
				xcdrawing.updatexcpaths_centreline(xcdrawing.get_node("PathLines_PlanView"), 0.05*planviewsystem.nodesca)
		else:
			xcdrawing.updatexcpaths()

	var badtubeswithnoconnections = [ ]
	for xctube in xctubestoupdate.values():
		if $XCdrawings.get_node(xctube.xcname0).drawingtype == DRAWING_TYPE.DT_CENTRELINE:
			if xctube.xcname1 == xctube.xcname0:
				print("updating tubelink paths on tunnelx self-connecting tube")
				xctube.updatetunnelxsketchlinkpaths(self)
			elif $XCdrawings.get_node(xctube.xcname1).drawingtype == DRAWING_TYPE.DT_CENTRELINE:
				xctube.updatecentrelineassociationlinks(self)
			else:
				xctube.updatefloorcentrelinepositionlinks(self)
		else:
			if not xctube.updatetubelinkpaths(self):
				badtubeswithnoconnections.push_back(xctube)
		xctube.setxctubepathlinevisibility(self)
	for xctube in badtubeswithnoconnections:
		print("*** removing unexplained bad tube found with no connecting lines ", xctube.xcname0, "-", xctube.xcname1)
		xctubestoupdate.erase(xctube.get_name())
		removeXCtube(xctube)
		xctube.queue_free() 

	if caveworldchunkI != -1 and not planviewtype:
		for xcdrawing in xcdrawingstoupdate.values():
			if xcdrawing.drawingtype == DRAWING_TYPE.DT_XCDRAWING:
				if xcdrawingstoupdatevisiblecodes.has(xcdrawing.get_name()):
					xcdrawing.setdrawingvisiblecode(xcdrawingstoupdatevisiblecodes[xcdrawing.get_name()])
				else:
					xcdrawing.setdrawingvisiblecode(xcdrawingstoupdatevisiblecodes.get(xcdrawing.get_name(), DRAWING_TYPE.VIZ_XCD_NODES_VISIBLE if len(xcdrawing.xctubesconn) == 0 else DRAWING_TYPE.VIZ_XCD_HIDE))
			elif xcdrawing.drawingtype == DRAWING_TYPE.DT_FLOORTEXTURE:
				if xcdrawingstoupdatevisiblecodes.has(xcdrawing.get_name()):
					xcdrawing.setdrawingvisiblecode(xcdrawingstoupdatevisiblecodes[xcdrawing.get_name()])
			#elif xcdrawing.drawingtype == DRAWING_TYPE.DT_ROPEHANG:
			#	xcdrawing.setdrawingvisiblecode(DRAWING_TYPE.VIZ_XCD_HIDE)
		for xctube in xctubestoupdate.values():
			xctube.updatetubeshell($XCdrawings)
			xctube.setxctubepathlinevisibility(self)
				
		if xcdatalist[0]["caveworldchunk"] == xcdatalist[0]["caveworldchunkLast"]:
			for xcdrawing in $XCdrawings.get_children():
				if xcdrawing.drawingtype == DRAWING_TYPE.DT_XCDRAWING:
					var ptubeshellmesh = xcdrawing.makexcflatshell($XCdrawings)
					xcdrawing.updatexcshellmesh(ptubeshellmesh)
			caveworldchunkI = -1
			caveworldchunking_networkIDsource = -1
			var xcdatalistReceivedDuringChunkingL = xcdatalistReceivedDuringChunking
			xcdatalistReceivedDuringChunking = null
			Tglobal.notisloadingcavechunks = true
			var PlayerDirections = get_node("/root/Spatial/BodyObjects/PlayerDirections")
			get_node("/root/Spatial/BodyObjects/LaserOrient/NotificationCylinder").visible = false
			if PlayerDirections.forceontogroundtimedown > 0:
				PlayerDirections.forceontogroundtimedown = 0.25
				
			if len(xcdatalistReceivedDuringChunkingL) != 0:
				print("Now processing ", len(xcdatalistReceivedDuringChunkingL), " received during chunking")
				for xcdatalistR in xcdatalistReceivedDuringChunkingL:
					actsketchchangeL(xcdatalistR)
			get_node("/root/Spatial/MQTTExperiment").mqttupdatenetstatus()

	if len(xcdrawingsrejected) != 0:
		print("The following drawings have bad change sequences and need to be requested from the server", xcdrawingsrejected)
		if playerMe.networkID == 1:
			sendoverridingxcdrawingsdata(xcdrawingsrejected, xcdatalist[0]["networkIDsource"])
		else:
			rpc_id(1, "sendoverridingxcdrawingsdata", xcdrawingsrejected, playerMe.networkID)
	if len(xctubesrejected) != 0:
		print("The following tubes have bad change sequences and need to be requested from the server", xctubesrejected)
		if playerMe.networkID == 1:
			sendoverridingxctubesdata(xctubesrejected, xcdatalist[0]["networkIDsource"])
		else:
			rpc_id(1, "sendoverridingxctubesdata", xctubesrejected, playerMe.networkID)
	
	return null
		
remote func sendoverridingxcdrawingsdata(xcdrawingsrejected, playeridtoupdate):
	var playerMe = get_node("/root/Spatial").playerMe
	assert (playerMe.networkID == 1)
	var xcdatalist = [ ]
	for xcdrawingname in xcdrawingsrejected:
		var xcdrawing = $XCdrawings.get_node_or_null(xcdrawingname)
		if xcdrawingname != null:
			var xcdata = xcdrawing.exportxcrpcdata(false)
			xcdata["overridingxcdrawing"] = 1
			#xcdata["xcchangesequence"] = xcdrawing.xcchangesequence
			xcdata["networkIDsource"] = playerMe.networkID
			xcdatalist.push_back(xcdata)
	rpc_id(playeridtoupdate, "actsketchchangeL", xcdatalist)
		
remote func sendoverridingxctubesdata(xctubesrejected, playeridtoupdate):
	var playerMe = get_node("/root/Spatial").playerMe
	assert (playerMe.networkID == 1)
	var xcdatalist = [ ]
	var updatetubeshells = [ ]
	for xct in xctubesrejected:
		print(" sendoverridingxctubesdata ", xct["tubename"], " to ", playeridtoupdate)
		var xctube = findxctube(xct["xcname0"], xct["xcname1"])
		if xctube != null:
			var xcdata = xctube.exportxctrpcdata(false)
			xcdata["overridingxctube"] = 1
			#xcdata["xctchangesequence"] = xctube.xctchangesequence
			xcdata["networkIDsource"] = playerMe.networkID
			xcdatalist.push_back(xcdata)
			updatetubeshells.push_back({"tubename":xcdata.get("tubename"), "xcname0":xct["xcname0"], "xcname1":xct["xcname1"] })
	xcdatalist.push_back({ "xcvizstates":{ }, "updatetubeshells":updatetubeshells } )
	rpc_id(playeridtoupdate, "actsketchchangeL", xcdatalist)
	
func xcdrawingfromdata(xcdata, fromremotecall):
	var xcdrawing = $XCdrawings.get_node_or_null(xcdata["name"])
	if xcdrawing == null:
		if Tglobal.notisloadingcavechunks:
			print("New xcdrawing ", xcdata.get("name"), " type: ", xcdata.get("drawingtype"))
		if not ("drawingtype" in xcdata):
			print("BAD new xcdrawingfromdata missing drawingtype ", xcdata)
			assert(false)
			return null
		elif xcdata["drawingtype"] == DRAWING_TYPE.DT_FLOORTEXTURE:
			xcdrawing = newXCuniquedrawingPaperN(xcdata["xcresource"], xcdata["name"], xcdata["drawingtype"])
		else:
			xcdrawing = newXCuniquedrawing(xcdata["drawingtype"], xcdata["name"])
			if xcdata["drawingtype"] == DRAWING_TYPE.DT_CENTRELINE and xcdata.has("xcresource"):
				xcdrawing.xcresource = xcdata["xcresource"]
				
	elif Tglobal.notisloadingcavechunks and not (xcdata.get("rpcoptional", 0) == 1):
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
		  
	if "prevnodepoints" in xcdata:
		pointersystem.cleardeletedtargets(xcdata.get("prevnodepoints"), xcdata.get("nextnodepoints"))
		
	var t0 = OS.get_ticks_msec()
	xcdrawing.mergexcrpcdata(xcdata)
	var dt = OS.get_ticks_msec() - t0
	if dt > 100:
		print("    Warning: long mergexcrpcdata operation happened for ", xcdata["name"], " of ", dt, " msecs", " nodes ", len(xcdrawing.nodepoints))
		
	if xcdrawing.drawingtype == DRAWING_TYPE.DT_FLOORTEXTURE:
		if "xcresource" in xcdata and xcdrawing.drawingvisiblecode != DRAWING_TYPE.VIZ_XCD_FLOOR_HIDDEN and xcdrawing.drawingvisiblecode != DRAWING_TYPE.VIZ_XCD_FLOOR_DELETED:
			get_node("/root/Spatial/ImageSystem").fetchpaperdrawing(xcdrawing)

	if xcdrawing.drawingtype == DRAWING_TYPE.DT_XCDRAWING and xcdrawing == pointersystem.activetargetwall and "transformpos" in xcdata:
		pointersystem.potreeexperiments.sethighlightplaneZone(xcdrawing.transform, 0.15 if Tglobal.housahedronmode else 0.5, false)

	return xcdrawing

var playeroriginXCSorter = Vector3(0, 0, 0)
func xcsorterfunc(a, b):
	if (b.drawingtype == DRAWING_TYPE.DT_CENTRELINE) != (a.drawingtype == DRAWING_TYPE.DT_CENTRELINE):
		return b.drawingtype == DRAWING_TYPE.DT_CENTRELINE
	return playeroriginXCSorter.distance_to(a.transformpos.origin) < playeroriginXCSorter.distance_to(b.transformpos.origin)
	
func subdictarray(d, a):
	var r = { }
	for x in a:
		r[x] = d[x]
	return r

func sketchdicttochunks(sketchdatadict):
	var xcdatachunkL = [ { "caveworldchunk":0, "sketchname":sketchdatadict.get("sketchname", "unnamedsketch") } ]
	if sketchdatadict.has("ghcurrentsha"):
		xcdatachunkL[0]["ghcurrentsha"] = sketchdatadict["ghcurrentsha"]
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
		var Dp = xcdrawingD["transformpos"].origin
		if is_nan(Dp.x) or is_nan(Dp.y) or is_nan(Dp.z):
			print("Resetting transformpos drawing because of nans", xcdrawingD)
			xcdrawingD["transformpos"] = Transform()
		if (len(xcdatachunkL) > 50  and j < len(xcdrawingsD) - 10) or nnodesL > 180:
			xcdatachunkL = [ { "caveworldchunk":len(xcdatachunks) } ]
			xcdatachunks.push_back(xcdatachunkL)
			nnodesL = 0
		if nnodesL + len(xcdrawingD["nodepoints"]) > 350:
			var Dnodepointstotal = len(xcdrawingD["nodepoints"])
			var SxcdrawingD = xcdrawingD.duplicate()
			var nodepointsdict = xcdrawingD["nodepoints"]
			var remainingnodepoints = nodepointsdict.keys()
			SxcdrawingD["nodepoints"] = subdictarray(xcdrawingD["nodepoints"], remainingnodepoints.slice(0, 301-nnodesL))
			SxcdrawingD["onepathpairs"] = [ ]
			xcdatachunkL.push_back(SxcdrawingD)
			Dnodepointstotal -= len(SxcdrawingD["nodepoints"])
			xcdatachunkL = [ { "caveworldchunk":len(xcdatachunks) } ]
			xcdatachunks.push_back(xcdatachunkL)
			remainingnodepoints = remainingnodepoints.slice(len(SxcdrawingD["nodepoints"]), len(xcdrawingD["nodepoints"]))
			while len(remainingnodepoints) > 300:
				SxcdrawingD = { "name":xcdrawingD["name"], 
								"prevnodepoints":[], 
								"nextnodepoints":subdictarray(xcdrawingD["nodepoints"], remainingnodepoints.slice(0, 300)), 
								"partialxcchunk":"yes" }
				xcdatachunkL.push_back(SxcdrawingD)
				Dnodepointstotal -= len(SxcdrawingD["nextnodepoints"])
				xcdatachunkL = [ { "caveworldchunk":len(xcdatachunks) } ]
				xcdatachunks.push_back(xcdatachunkL)
				remainingnodepoints = remainingnodepoints.slice(len(SxcdrawingD["nextnodepoints"]), len(remainingnodepoints))

			SxcdrawingD = { "name":xcdrawingD["name"], 
							"prevnodepoints":[], 
							"nextnodepoints":subdictarray(xcdrawingD["nodepoints"], remainingnodepoints), 
							"prevonepathpairs":[],
							"newonepathpairs":xcdrawingD["onepathpairs"] }
			xcdatachunkL.push_back(SxcdrawingD)
			Dnodepointstotal -= len(SxcdrawingD["nextnodepoints"])
			assert (Dnodepointstotal == 0)
			while len(SxcdrawingD["newonepathpairs"]) > 2000:
				var keepnewonwpathpairs = SxcdrawingD["newonepathpairs"].slice(0, 1799)
				var remainingnewonepathpairs = SxcdrawingD["newonepathpairs"].slice(len(keepnewonwpathpairs), len(SxcdrawingD["newonepathpairs"]))
				SxcdrawingD["newonepathpairs"] = keepnewonwpathpairs  # changing member already in list
				SxcdrawingD["partialxcchunk"] = "yes"
				xcdatachunkL = [ { "caveworldchunk":len(xcdatachunks) } ]
				SxcdrawingD = { "name":xcdrawingD["name"], 
								"prevonepathpairs":[],
								"newonepathpairs":remainingnewonepathpairs }
				xcdatachunkL.push_back(SxcdrawingD)
				xcdatachunks.push_back(xcdatachunkL)
			nnodesL = 400
				
		else:
			xcdatachunkL.push_back(xcdrawingD)
			nnodesL += len(xcdrawingD["nodepoints"])
			
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

	if len(xctubesDmaphalfstaged) != 0:
		print("tubes with missing xcdrawings during chunking ", xctubesDmaphalfstaged)
	var playerMe = get_node("/root/Spatial").playerMe
	for i in range(len(xcdatachunks)):
		xcdatachunks[i][0]["caveworldchunkLast"] = xcdatachunks[-1][0]["caveworldchunk"]
		xcdatachunks[i][0]["networkIDsource"] = playerMe.networkID
	return xcdatachunks
	
remote func loadsketchsystemL(fname):
	var sketchdatafile = File.new()
	var sketchdatadict = null
	if fname == "clearcave":
		sketchdatadict = { "sketchname":"unnamedsketch", "xcdrawings":[], "xctubes":[] }
		if $XCdrawings.get_child_count() != 1:
			for xcdrawing in $XCdrawings.get_children():
				if xcdrawing.drawingtype == DRAWING_TYPE.DT_FLOORTEXTURE:
					if (xcdrawing.drawingvisiblecode & DRAWING_TYPE.VIZ_XCD_FLOOR_GHOSTLY_B) == 0:
						sketchdatadict["xcdrawings"].append(xcdrawing.exportxcrpcdata(true))
						sketchdatadict["xcdrawings"][0]["nodepoints"].clear()
						break
	elif sketchdatafile.file_exists(fname):
		print("Loading sketchsystemtodict from ", fname)
		sketchdatafile.open(fname, File.READ)
		var firstline = sketchdatafile.get_buffer(20).get_string_from_ascii()
		sketchdatafile.seek(0)
		var GithubAPI = get_node("/root/Spatial/ImageSystem/GithubAPI")
		if firstline.begins_with(fileheading):
			firstline = sketchdatafile.get_line()
			var headerdata = firstline.split(" ")
			sketchdatadict = { "sketchname":headerdata[1].percent_decode(), "xcdrawings": [ ], "xctubes": [ ] }
			if GithubAPI.ghcurrentname == sketchdatadict["sketchname"]+".res":
				sketchdatadict["ghcurrentsha"] = GithubAPI.ghcurrentsha
			while true:
				var jline = sketchdatafile.get_line()
				if jline == null or jline == "":
					break
				var jdat = parse_json(jline)
				if jdat != null:
					if "playerplatform" in jdat:
						jdat["transformpos"] = str2var(jdat["stransformpos"])
						jdat.erase("stransformpos")
						jdat["headtrans"] = str2var(jdat["sheadtrans"])
						jdat.erase("sheadtrans")
						sketchdatadict["playerMe"] = jdat
					elif "drawingtype" in jdat:
						jdat["transformpos"] = str2var(jdat["stransformpos"])
						jdat.erase("stransformpos")
						jdat["nodepoints"] = { }
						for node in jdat["snodepoints"]:
							var p = jdat["snodepoints"][node]
							jdat["nodepoints"][node] = Vector3(p[0], p[1], p[2])
						jdat.erase("snodepoints")
						if "imgtrim" in jdat:
							jdat["imgtrim"]["imgtrimleftdown"] = str2var(jdat["imgtrim"]["simgtrimleftdown"])
							jdat["imgtrim"].erase("simgtrimleftdown")
							jdat["imgtrim"]["imgtrimrightup"] = str2var(jdat["imgtrim"]["simgtrimrightup"])
							jdat["imgtrim"].erase("simgtrimrightup")
						jdat["drawingtype"] = int(jdat["drawingtype"])
						jdat["drawingvisiblecode"] = int(jdat["drawingvisiblecode"])
						sketchdatadict["xcdrawings"].push_back(jdat)
						
					elif "tubename" in jdat:
						if "sxclinkintermediatenodes" in jdat:
							jdat["xclinkintermediatenodes"] = [ ]
							for sxci in jdat["sxclinkintermediatenodes"]:
								var xci = [ ]
								for p in sxci:
									xci.push_back(Vector3(p[0], p[1], p[2]))
								jdat["xclinkintermediatenodes"].push_back(xci)
							jdat.erase("sxclinkintermediatenodes")
						sketchdatadict["xctubes"].push_back(jdat)
					else:
						print("Unrecognized jline: ", jdat)
				else:
					print("Bad jline: ", jline.substr(0, 30))
		else:
			sketchdatadict = sketchdatafile.get_var()
		sketchdatafile.close()
		print("items loaded: ", len(sketchdatadict["xcdrawings"]), " drawings,  ", len(sketchdatadict["xctubes"]), " tubes.")
		var fsketchname = fname.split("/")[-1].split(".")[0]
		if sketchdatadict.get("sketchname", "unnamedsketch") != fsketchname and fname != GithubAPI.ghfetcheddatafile:
			print("resetting sketchname from ", sketchdatadict.get("sketchname", "unnamedsketch"), " to ", fsketchname, " on load")
			sketchdatadict["sketchname"] = fsketchname
	else:
		return
		
	print("Generating sketchdicttochunks")
	var xcdatachunks = sketchdicttochunks(sketchdatadict)
	print("Generated ", len(xcdatachunks), " chunks")
	for xcdatachunk in xcdatachunks:
		#print("sending caveworldchunk ", xcdatachunk[0].caveworldchunk, " size ", len(var2bytes(xcdatachunk)))
		actsketchchange(xcdatachunk)
		yield(get_tree().create_timer(0.2), "timeout")
	actsketchchange([{"planview":planviewsystem.planviewtodict()}]) 
				
func uniqueXCname(ch):
	var largestxcdrawingnumber = 0
	for xcdrawing in get_node("XCdrawings").get_children():
		var xcname = xcdrawing.get_name()
		var ns = xcname.find_last(ch)
		if ns != -1:
			largestxcdrawingnumber = max(largestxcdrawingnumber, int(xcname.right(ns + 1)))
	var sname = "%s%d" % [ch, largestxcdrawingnumber+1]
	return sname
	
func newXCuniquedrawing(drawingtype, sname):
	var xcdrawing = XCdrawing.instance()
	xcdrawing.drawingtype = drawingtype
	xcdrawing.set_name(sname)
	get_node("XCdrawings").add_child(xcdrawing)
	assert (sname == xcdrawing.get_name())
	if drawingtype == DRAWING_TYPE.DT_XCDRAWING:
		xcdrawing.linewidth = 0.05
		xcdrawing.drawingvisiblecode = DRAWING_TYPE.VIZ_XCD_PLANE_AND_NODES_VISIBLE
		xcdrawing.get_node("XCnodes").visible = false
		xcdrawing.get_node("XCdrawingplane").visible = false
		xcdrawing.get_node("XCdrawingplane/CollisionShape").disabled = true
		
	elif drawingtype == DRAWING_TYPE.DT_ROPEHANG:
		xcdrawing.linewidth = 0.02
		xcdrawing.drawingvisiblecode = DRAWING_TYPE.VIZ_XCD_NODES_VISIBLE
		xcdrawing.get_node("XCnodes").visible = true
		xcdrawing.get_node("XCdrawingplane").visible = false
		xcdrawing.get_node("XCdrawingplane/CollisionShape").disabled = true
		xcdrawing.add_child(RopeHang.instance())
		xcdrawing.get_node("RopeHang").setropematerialcolour(xcdrawing.get_name())

	elif drawingtype == DRAWING_TYPE.DT_CENTRELINE:
		var xcnodesplanview = Spatial.new()
		xcnodesplanview.set_name("XCnodes_PlanView")
		xcdrawing.add_child(xcnodesplanview)
		var pathlinesplanview = MeshInstance.new()
		pathlinesplanview.set_name("PathLines_PlanView")
		xcdrawing.add_child(pathlinesplanview)

		xcdrawing.add_to_group("gpcentrelinegeo")
		xcdrawing.linewidth = 0.035
		xcdrawing.drawingvisiblecode = DRAWING_TYPE.VIZ_XCD_HIDE
		xcdrawing.get_node("PathLines").visible = true
		xcdrawing.get_node("PathLines").layers = CollisionLayer.VL_centrelinedrawinglines
		xcdrawing.get_node("PathLines_PlanView").visible = true
		xcdrawing.get_node("PathLines_PlanView").layers = CollisionLayer.VL_centrelinedrawinglinesplanview
		xcdrawing.get_node("XCnodes").visible = true
		planviewsystem.updatecentrelineactivityui()
	
	else:
		assert (false)
	return xcdrawing
	

func uniqueXCdrawingPapername(xcresource):
	var fname = get_node("/root/Spatial/ImageSystem").getshortimagename(xcresource, false, 12)
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

func newXCtube(tubename, xcdrawing0, xcdrawing1):
	assert ((xcdrawing0.drawingtype == DRAWING_TYPE.DT_XCDRAWING and xcdrawing1.drawingtype == DRAWING_TYPE.DT_XCDRAWING) or \
			# (xcdrawing0.drawingtype == DRAWING_TYPE.DT_FLOORTEXTURE and xcdrawing1.drawingtype == DRAWING_TYPE.DT_XCDRAWING) or # What's this case for??? \
			(xcdrawing0.drawingtype == DRAWING_TYPE.DT_CENTRELINE and xcdrawing1.drawingtype == DRAWING_TYPE.DT_FLOORTEXTURE) or \
			(xcdrawing0.drawingtype == DRAWING_TYPE.DT_CENTRELINE and xcdrawing1.drawingtype == DRAWING_TYPE.DT_CENTRELINE))
		
	var xctube = XCtube.instance()
	xctube.xcname0 = xcdrawing0.get_name()
	xctube.xcname1 = xcdrawing1.get_name()
	xctube.set_name(tubename)
	xcdrawing0.xctubesconn.append(xctube)
	xcdrawing1.xctubesconn.append(xctube)
	assert (not $XCtubes.has_node(xctube.get_name()))
	$XCtubes.add_child(xctube)
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


func updateflagtrails(xcname, flagsigns):
	var bflagtrailsupdate = false
	for i in range(len(allflagtrails)-1, -1, -1):
		if allflagtrails[i]["xcname"] == xcname:
			allflagtrails.pop_at(i)
			bflagtrailsupdate = true
	for flagsign in flagsigns:
		if flagsign.get("flagtrail"):
			var flagopttext = "-"+flagsign["flagmsg"]
			if len(flagopttext)>10:
				flagopttext = flagopttext.substr(0,8)+"..."
			allflagtrails.push_back({ "xcname":xcname, 
									  "flagmsg":flagsign["flagmsg"], 
									  "flagtrail":flagsign["flagtrail"], 
									  "flagopttext":flagopttext })
			bflagtrailsupdate = true
	if bflagtrailsupdate:
		var guipanel3d = get_node("/root/Spatial/GuiSystem/GUIPanel3D")
		guipanel3d.updateplayerlist()
