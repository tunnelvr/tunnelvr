extends Spatial

#var d = "/home/julian/data/pointclouds/potreetests/outdir/"
# PotreeConverter --source xxx.laz --outdir outdir --attributes position_cartesian --method poisson

var potreethreadmutex = Mutex.new()
var potreethreadsemaphore = Semaphore.new()
var potreethread = null # Thread.new()
var threadtoexit = false
var nodestoload = [ ]
var nodestopointload = [ ]
var nodespointloaded = [ ]
var rootnode = null

onready var ImageSystem = get_node("/root/Spatial/ImageSystem")

func potreethread_function(userdata):
	print("potreethread_function started")
	while not threadtoexit:
		potreethreadsemaphore.wait()
		potreethreadmutex.lock()
		#var lverropropehang = verropropehang_in
		#verropropehang_in = null
		var lthreadtoexit = threadtoexit
		potreethreadmutex.unlock()
		if lthreadtoexit:
			break
		potreethreadmutex.lock()
		#verropropehang_out = lverropropehang
		potreethreadmutex.unlock()
	print("potreethread_function stopped")

func _exit_tree():
	if potreethread != null:
		potreethreadmutex.lock()
		threadtoexit = true
		potreethreadmutex.unlock()
		potreethreadsemaphore.post()
		potreethread.wait_to_finish()
		threadtoexit = false

func sethighlightplane(planetransform):
	if rootnode != null:
		rootnode.sethighlightplane(planetransform.basis.z, 
								   planetransform.basis.z.dot(planetransform.origin))

func killpotree():
	if rootnode != null:
		rootnode.processingnode = null
		remove_child(rootnode)
		rootnode.queue_free()
		rootnode = null


func potreeactivatebuttonpressed(buttondown):
	if buttondown:
		var primarycameraorigin = Vector3(0, 0, 0)
		var primarycamera = instance_from_id(Tglobal.primarycamera_instanceid)
		if primarycamera != null:
			primarycameraorigin = primarycamera.get_camera_transform().origin

		if rootnode == null:
			rootnode = MeshInstance.new()
			rootnode.set_script(load("res://potreework/Onode_root.gd"))
			rootnode.name = "hroot"
			rootnode.visibleincamera = true
			rootnode.visible = false
			rootnode.cast_shadow = GeometryInstance.SHADOW_CASTING_SETTING_OFF
			rootnode.primarycameraorigin = primarycameraorigin
			add_child(rootnode)

			var selfSpatial = get_node("/root/Spatial")
			var potreeipnumber = selfSpatial.hostipnumber if selfSpatial.hostipnumber != "" else "192.168.8.111"
			var potreesubdirectory = "potreewookey"
			var urlotreedir = "http://%s:%d/%s/" % [potreeipnumber, selfSpatial.potreeportnumber, potreesubdirectory]
			if selfSpatial.hostipnumber == "" and selfSpatial.playerMe.playerplatform == "PC":
				if selfSpatial.playerMe.playeroperatingsystem == "Windows":
					urlotreedir = "D:/potreetests/outdir/"
					urlotreedir = "D:/potreetests/outdircombined/"
				elif selfSpatial.playerMe.playeroperatingsystem in ["Linux", "X11"]:
					urlotreedir = "/home/julian/.local/share/godot/app_userdata/tunnelvr_v0.7/caddywebserver/potreewookey/"
				else:
					print("unknown operating system: ", selfSpatial.playerMe.playeroperatingsystem)
					
			rootnode.commenceloadotree(urlotreedir)	
				
		else:
			rootnode.primarycameraorigin = primarycameraorigin
			rootnode.commenceocellprocessing()


var nupdatepotreeprioritiesSingleConcurrentOperations = 0
var Cpointsizevisibilitycutoff = 15.0
const maxvisiblepoints = 300000
const minvisiblepoints = 150000
const pointsizefactor = 150.0
const updatepotreeprioritiesworkingtimeout = 4.0
signal updatepotreepriorities_fetchsignal(f)
func updatepotreepriorities():
	if rootnode == null:
		return
	nupdatepotreeprioritiesSingleConcurrentOperations += 1
	if nupdatepotreeprioritiesSingleConcurrentOperations != 1:
		nupdatepotreeprioritiesSingleConcurrentOperations -= 1
		print("drop out from updatepotreepriorities as not idle")
		return
	yield(get_tree(), "idle_frame")

	var primarycameraorigin = Vector3(0, 0, 0)
	var primarycamera = instance_from_id(Tglobal.primarycamera_instanceid)
	if primarycamera != null:
		primarycameraorigin = primarycamera.get_camera_transform().origin
	var res = yield(updatepotreeprioritiesfromcamera(primarycameraorigin, pointsizefactor, Cpointsizevisibilitycutoff), "completed")
	while res["sweptvisiblepointcount"] < minvisiblepoints and len(res["pointsizes"]) != 0 and res["pointsizes"].min() < Cpointsizevisibilitycutoff:
		Cpointsizevisibilitycutoff *= 0.5
		var Dsweptvisiblepointcount = res["sweptvisiblepointcount"]
		res = yield(updatepotreeprioritiesfromcamera(primarycameraorigin, pointsizefactor, Cpointsizevisibilitycutoff), "completed")
		print("scaling down Cpointsizevisibilitycutoff ", Cpointsizevisibilitycutoff, "  prevcount: ", Dsweptvisiblepointcount, " newcount: ", res["sweptvisiblepointcount"])
	while res["sweptvisiblepointcount"] > maxvisiblepoints and len(res["pointsizes"]) != 0 and res["pointsizes"].max() > Cpointsizevisibilitycutoff:
		Cpointsizevisibilitycutoff *= 2.0
		var Dsweptvisiblepointcount = res["sweptvisiblepointcount"]
		res = yield(updatepotreeprioritiesfromcamera(primarycameraorigin, pointsizefactor, Cpointsizevisibilitycutoff), "completed")
		print("scaling up Cpointsizevisibilitycutoff ", Cpointsizevisibilitycutoff, "  prevcount: ", Dsweptvisiblepointcount, " newcount: ", res["sweptvisiblepointcount"])

	print("hierarchynodestoload ", len(res["hierarchynodestoload"]),  
		  "   pointcloudnodestoshow  ", len(res["pointcloudnodestoshow"]),
		  "   pointcloudnodestohide  ", len(res["pointcloudnodestohide"]),
		  "  sweptvisiblepointcount ", res["sweptvisiblepointcount"],
		  "  nscannednodes ", res["nscannednodes"], 
		  " pointsizes: ", res["pointsizes"].min(), " ", res["pointsizes"].max())

	var t0 = OS.get_ticks_msec()*0.001
	while len(res["hierarchynodestoload"]):
		var hnode = res["hierarchynodestoload"].pop_front()
		var nonimagedataobject = { "url":rootnode.urlhierarchy, "callbackobject":self, 
								   "callbacksignal":"updatepotreepriorities_fetchsignal", 
								   "byteOffset":hnode.hierarchybyteOffset, 
								   "byteSize":hnode.hierarchybyteSize }
		ImageSystem.fetchrequesturl(nonimagedataobject)
		var fhierarchyF = yield(self, "updatepotreepriorities_fetchsignal")
		# assert ((urlhierarchy.substr(0, 4) != "http") or (fhierarchyF.get_len() == processingnode.hierarchybyteSize))
		var nodesh = hnode.loadhierarchychunk(fhierarchyF, rootnode.get_parent().global_transform.inverse())
		for node in nodesh:
			if node.name[0] != "h":
				rootnode.otreecellscount += 1
		if OS.get_ticks_msec()*0.001 - t0 > updatepotreeprioritiesworkingtimeout:
			print("breakout from updatepotreepriorities in hierarchynodestoload")
			break
			
	for nnode in res["pointcloudnodestohide"]:
		if nnode.visible:
			rootnode.uppernodevisibilitymask(nnode, false)
			
	for nnode in res["pointcloudnodestoshow"]:
		if not nnode.visible:
			if nnode.pointmaterial == null:
				var nonimagedataobject = { "url":rootnode.urloctree, "callbackobject":self, 
										   "callbacksignal":"updatepotreepriorities_fetchsignal", 
										   "byteOffset":nnode.byteOffset, 
										   "byteSize":nnode.byteSize }
				ImageSystem.fetchrequesturl(nonimagedataobject)
				var foctreeF = yield(self, "updatepotreepriorities_fetchsignal")
				if rootnode.urloctree.substr(0, 4) != "http" or foctreeF.get_len() == nnode.byteSize:
					var roottransforminverse = rootnode.get_parent().global_transform.inverse()
					var tp0 = OS.get_ticks_msec()
					nnode.loadoctcellpoints(foctreeF, rootnode.mdscale, rootnode.mdoffset, pointsizefactor, roottransforminverse, rootnode.highlightplaneperp, rootnode.highlightplanedot)
					var dt = OS.get_ticks_msec() - tp0
					if dt > 100:
						print("    Warning: long loadoctcellpoints ", nnode.get_path(), " of ", dt, " msecs", " numPoints:", nnode.numPoints, " carrieddown:", nnode.numPointsCarriedDown)
			if not nnode.visible:
				rootnode.uppernodevisibilitymask(nnode, true)
		
		if OS.get_ticks_msec()*0.001 - t0 > updatepotreeprioritiesworkingtimeout:
			print("breakout from updatepotreepriorities in showed nodesnodestoload")
			break
			
	print("DONEDONE updatepotreepriorities")
	nupdatepotreeprioritiesSingleConcurrentOperations -= 1



func updatepotreeprioritiesfromcamera(primarycameraorigin, pointsizefactor, pointsizevisibilitycutoff):
	var hierarchynodestoload = [ ]
	var pointcloudnodestoshow = [ ]
	var pointcloudnodestohide = [ ]
	var pointsizes = [ ]
	var visibleincameratimehorizon = OS.get_ticks_msec()*0.001 - 5.0
	var sweptvisiblepointcount = 0
	var nscannednodes = 0

	var scanningnode = rootnode
	yield(get_tree(), "idle_frame")
	while scanningnode != null:
		nscannednodes += 1
		if (nscannednodes % 50) == 0:
			yield(get_tree(), "idle_frame")
		if scanningnode.name[0] == "h":
			hierarchynodestoload.push_back(scanningnode)
			scanningnode = rootnode.successornode(scanningnode, true)
		else:
			var boxcentre = scanningnode.global_transform.origin
			var boxradius = (scanningnode.ocellsize/2).length()
			var cd = boxcentre.distance_to(primarycameraorigin)
			var scanningnodetoshow = true
			if cd > boxradius + 0.1:
				var pointsize = pointsizefactor*rootnode.spacing*scanningnode.powdiv2/(cd-boxradius)
				scanningnodetoshow = (pointsize > pointsizevisibilitycutoff)
				pointsizes.push_back(pointsize)
			if not scanningnode.visibleincamera and scanningnode.visibleincameratimestamp < visibleincameratimehorizon:
				scanningnodetoshow = false
			if scanningnodetoshow:
				sweptvisiblepointcount += scanningnode.numPoints
				pointcloudnodestoshow.push_back(scanningnode)
			else:
				pointcloudnodestohide.push_back(scanningnode)
			scanningnode = rootnode.successornode(scanningnode, not scanningnodetoshow)

	return { "hierarchynodestoload":hierarchynodestoload, 
			 "pointcloudnodestoshow":pointcloudnodestoshow,
			 "pointcloudnodestohide":pointcloudnodestohide,
			 "pointsizes":pointsizes,
			 "sweptvisiblepointcount":sweptvisiblepointcount,
			 "nscannednodes":nscannednodes }

func _input(event):
	if event is InputEventKey and event.scancode == KEY_7:
		potreeactivatebuttonpressed(event.pressed)
	if event is InputEventKey and event.pressed and event.scancode == KEY_6:
		if rootnode != null and rootnode.processingnode == null:
			rootnode.garbagecollectionsweep()
	if event is InputEventKey and event.pressed and event.scancode == KEY_5:
		#updatepotreepriorities()
		if $Timer.is_stopped():
			$Timer.start()
		else:
			$Timer.stop()
