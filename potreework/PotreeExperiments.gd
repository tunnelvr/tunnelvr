extends Spatial

#var d = "/home/julian/data/pointclouds/potreetests/outdir/"
# PotreeConverter --source xxx.laz --outdir outdir --attributes position_cartesian --method poisson

# nix-shell -p wine64  # 64 bit error means to need to delete ~/.wine
# wine64 executables-impure/PotreeConverter_2.1_x64_windows/PotreeConverter.exe --source Downloads/aidancloud.laz --outdir junk/aidan/ --attributes position_cartesian --method poisson

# May need to load and export from CloudCompare (can be tricky)
# Then need to be uploaded to godot.doesliverpool.xyz 
# Files will need to be put in: 
#   /var/lib/private/tunnelvr/.local/share/godot/app_userdata/tunnelvr_v0.7/caddywebserver/

#nix-shell -p wine64
  # 64 bit error means to need to delete ~/.wine
#The laz file bounding boxes from the app are bad.  Need to load and save into cloud compare.
#Load and save back to a copy using CloudCompare (Optimal resolution option okay)
# wine64 ~/executables-impure/PotreeConverter_2.1_x64_windows/PotreeConverter.exe --source point_cloud_may17cc.laz --outdir potreeconverted --attributes position_cartesian --method poisson
#increases size by 50% to have colour:
# wine64 ~/executables-impure/PotreeConverter_2.1_x64_windows/PotreeConverter.exe --source point_cloud_may17cc.laz --outdir potreeconverted --attributes position_cartesian --attributes rgb --method poisson
# nix-shell -p caddy
# caddy file-server -browse -root /home/julian/data/3dmodels/aidanhouse/potreeconverted -listen 0.0.0.0:8000



var potreethreadmutex = Mutex.new()
var potreethreadsemaphore = Semaphore.new()
var potreethread = null
var threadtoexit = false
var nodestoload = [ ]
var nodestopointload = [ ]
var nodespointloaded = [ ]

var rootnode = null
var potreeurlmetadata = null

onready var ImageSystem = get_node("/root/Spatial/ImageSystem")

func _ready():
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_POINTS)
	for i in range(4):
		for j in range(4):
			for k in range(4):
				st.add_vertex((Vector3(i,j,k)*0.333333-Vector3(0.5,0.5,0.5))*2)
	var pointmesh = Mesh.new()
	st.commit(pointmesh)
	$PointSample.mesh = pointmesh	
	var pointmaterial =	$PointSample.get_surface_material(0)
	yield(get_tree().create_timer(5.0), "timeout")
			
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
		rootnode.sethighlightplane(planetransform.basis.z, planetransform.basis.z.dot(planetransform.origin))

func getpotreeurl():
	var selfSpatial = get_node("/root/Spatial")
	var potreeipnumber = selfSpatial.hostipnumber if selfSpatial.hostipnumber != "" else "godot.doesliverpool.xyz"
	var potreesubdirectory = "potreewookey"
	potreesubdirectory = "janet"
	var urlotreedir = "http://%s:%d/%s/" % [potreeipnumber, selfSpatial.potreeportnumber, potreesubdirectory]
	if false and selfSpatial.hostipnumber == "" and selfSpatial.playerMe.playerplatform == "PC":
		if selfSpatial.playerMe.playeroperatingsystem == "Windows":
			urlotreedir = "C:/Users/Julian/data/potreewookey/"
		elif selfSpatial.playerMe.playeroperatingsystem in ["Linux", "X11"]:
			urlotreedir = "/home/julian/.local/share/godot/app_userdata/tunnelvr_v0.7/caddywebserver/potreewookey/"
			#urlotreedir = "/home/julian/data/madphilpointclouds/janet/"
		else:
			print("unknown operating system: ", selfSpatial.playerMe.playeroperatingsystem)
	return urlotreedir



var Cpointsizevisibilitycutoff = 15.0
var maxvisiblepoints = 500000
var minvisiblepoints = 200000
var pointsizefactor = 150.0
const updatepotreeprioritiesworkingtimeout = 4.0
signal updatepotreepriorities_fetchsignal(f)


const timems_fornextupdatepriorities = 3500


var queuekillpotree = false

onready var matloadingcube = $LoadingCube.get_surface_material(0)

const colhierarchyfetching = Color("#901fe51f")
const colhierarchyloading = Color("#361fe51f")
const coloctcellpointsfetching = Color("#80e418e6")
const coloctcellpointsloading = Color("#36e418e6")

func LoadPotree():
	assert (rootnode == null)
	var xcdrawingcentreline = null
	for lxcdrawingcentreline in get_tree().get_nodes_in_group("gpcentrelinegeo"):
		if lxcdrawingcentreline.additionalproperties != null and lxcdrawingcentreline.additionalproperties.has("potreeurlmetadata"):
			xcdrawingcentreline = lxcdrawingcentreline
			potreeurlmetadata = xcdrawingcentreline.additionalproperties["potreeurlmetadata"]
	if potreeurlmetadata == null:
		print("No potree url found")
		return
	print("Loading ", potreeurlmetadata)
	
	var nonimagedataobject = { "url":potreeurlmetadata, "callbackobject":self, "callbacksignal":"updatepotreepriorities_fetchsignal" }
	ImageSystem.fetchrequesturl(nonimagedataobject)
	var fmetadataF = yield(self, "updatepotreepriorities_fetchsignal")
	if fmetadataF == null:
		return
	var smetadata = fmetadataF.get_as_text()
	var metadata = parse_json(smetadata)
	if metadata == null:
		print("json bad ", smetadata)
		return
	rootnode = MeshInstance.new()
	rootnode.set_script(load("res://potreework/Onode_root.gd"))
	rootnode.name = "hroot"
	var bboffseta = xcdrawingcentreline.additionalproperties["svxp0"]  if xcdrawingcentreline != null and xcdrawingcentreline.additionalproperties != null and xcdrawingcentreline.additionalproperties.has("svxp0")  else [0,0,0]
	var bboffset = Vector3(bboffseta[0], bboffseta[1], bboffseta[2])
	rootnode.constructpotreerootnode(metadata, potreeurlmetadata, bboffset)
	if rootnode.attributes_rgb_prebytes != -1:
		pointsizefactor = 400
	if xcdrawingcentreline != null:
		transform = xcdrawingcentreline.transform
	add_child(rootnode)
	queuekillpotree = false
	call_deferred("updatepotreeprioritiesLoop")

func Yupdatepotreeprioritiesfromcamera(primarycameraorigin, pointsizefactor, pointsizevisibilitycutoff):
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

func Yupdatepotreeprioritiesfull():
	var primarycameraorigin = Vector3(0, 0, 0)
	var primarycamera = instance_from_id(Tglobal.primarycamera_instanceid)
	if primarycamera != null:
		primarycameraorigin = primarycamera.get_camera_transform().origin

	var res = yield(Yupdatepotreeprioritiesfromcamera(primarycameraorigin, pointsizefactor, Cpointsizevisibilitycutoff), "completed")
	while res["sweptvisiblepointcount"] < minvisiblepoints and len(res["pointsizes"]) != 0 and res["pointsizes"].min() < Cpointsizevisibilitycutoff:
		Cpointsizevisibilitycutoff *= 0.5
		var Dsweptvisiblepointcount = res["sweptvisiblepointcount"]
		res = yield(Yupdatepotreeprioritiesfromcamera(primarycameraorigin, pointsizefactor, Cpointsizevisibilitycutoff), "completed")
		print("scaling down Cpointsizevisibilitycutoff ", Cpointsizevisibilitycutoff, "  prevcount: ", Dsweptvisiblepointcount, " newcount: ", res["sweptvisiblepointcount"])
	while res["sweptvisiblepointcount"] > maxvisiblepoints and len(res["pointsizes"]) != 0 and res["pointsizes"].max() > Cpointsizevisibilitycutoff:
		Cpointsizevisibilitycutoff *= 2.0
		var Dsweptvisiblepointcount = res["sweptvisiblepointcount"]
		res = yield(Yupdatepotreeprioritiesfromcamera(primarycameraorigin, pointsizefactor, Cpointsizevisibilitycutoff), "completed")
		print("scaling up Cpointsizevisibilitycutoff ", Cpointsizevisibilitycutoff, "  prevcount: ", Dsweptvisiblepointcount, " newcount: ", res["sweptvisiblepointcount"])
	print("hierarchynodestoload ", len(res["hierarchynodestoload"]), "   pointcloudnodestoshow  ", len(res["pointcloudnodestoshow"]), "   pointcloudnodestohide  ", len(res["pointcloudnodestohide"]),  "  sweptvisiblepointcount ", res["sweptvisiblepointcount"],  "  nscannednodes ", res["nscannednodes"]) #,   " pointsizes: ", res["pointsizes"].min(), " ", res["pointsizes"].max())
	return res

func updatepotreeprioritiesLoop():
	while true:
		if queuekillpotree or rootnode == null:
			if rootnode != null:
				rootnode.processingnode = null
				remove_child(rootnode)
				rootnode.queue_free()
				rootnode = null
			break

		if not visible:
			yield(get_tree().create_timer(timems_fornextupdatepriorities*0.001), "timeout")
			continue
		yield(get_tree(), "idle_frame")
		var ticksms_tonextupdatepriorities = OS.get_ticks_msec() + timems_fornextupdatepriorities

		var res = yield(Yupdatepotreeprioritiesfull(), "completed")
		for nnode in res["pointcloudnodestohide"]:
			if nnode.visible:
				rootnode.uppernodevisibilitymask(nnode, false)

		while visible and len(res["pointcloudnodestoshow"]) != 0 and OS.get_ticks_msec() < ticksms_tonextupdatepriorities:
			var nnode = res["pointcloudnodestoshow"].pop_front()
			if not nnode.visible:
				if nnode.pointmaterial == null:
					var nonimagedataobject = { "url":rootnode.urloctree, 
											   "callbackobject":self, 
											   "callbacksignal":"updatepotreepriorities_fetchsignal", 
											   "byteOffset":nnode.byteOffset, 
											   "byteSize":nnode.byteSize }
					$LoadingCube.mesh.size = nnode.ocellsize
					$LoadingCube.global_transform.origin = nnode.global_transform.origin
					matloadingcube.albedo_color = coloctcellpointsfetching
					$LoadingCube.visible = true
					nnode.Dloadedstate = "fetching"
					ImageSystem.fetchrequesturl(nonimagedataobject)
					var foctreeF = yield(self, "updatepotreepriorities_fetchsignal")
					if rootnode.urloctree.substr(0, 4) != "http" or foctreeF.get_len() == nnode.byteSize:
						var roottransforminverse = rootnode.get_parent().global_transform.inverse()
						var tp0 = OS.get_ticks_msec()
						matloadingcube.albedo_color = coloctcellpointsloading
						nnode.Dloadedstate = "pointsloading"
						yield(nnode.Yloadoctcellpoints(foctreeF, pointsizefactor, roottransforminverse, rootnode), "completed")
						var dt = OS.get_ticks_msec() - tp0
						if dt > 100:
							print("    Warning: long loadoctcellpoints ", nnode.get_path(), " of ", dt, " msecs", " numPoints:", nnode.numPoints, " carrieddown:", nnode.numPointsCarriedDown)
						nnode.Dloadedstate = "pointsloaded"
					else:
						nnode.Dloadedstate = "failedfetching"
						print("foctree nodesize bytes fail ", foctreeF.get_len(), " ", nnode.byteSize)
					$LoadingCube.visible = false
				if not nnode.visible and nnode.pointmaterial != null:
					rootnode.uppernodevisibilitymask(nnode, true)
		
			
		while visible and len(res["hierarchynodestoload"]) != 0 and OS.get_ticks_msec() < ticksms_tonextupdatepriorities:
			var hnode = res["hierarchynodestoload"].pop_front()
			$LoadingCube.mesh.size = hnode.ocellsize
			$LoadingCube.global_transform.origin = hnode.global_transform.origin
			matloadingcube.albedo_color = colhierarchyfetching
			$LoadingCube.visible = true
			var nonimagedataobject = { "url":rootnode.urlhierarchy, "callbackobject":self, 
									   "callbacksignal":"updatepotreepriorities_fetchsignal", 
									   "byteOffset":hnode.hierarchybyteOffset, 
									   "byteSize":hnode.hierarchybyteSize }
			ImageSystem.fetchrequesturl(nonimagedataobject)
			var fhierarchyF = yield(self, "updatepotreepriorities_fetchsignal")
			# assert ((urlhierarchy.substr(0, 4) != "http") or (fhierarchyF.get_len() == processingnode.hierarchybyteSize))
			matloadingcube.albedo_color = colhierarchyloading
			var nodesh = yield(hnode.Yloadhierarchychunk(fhierarchyF, rootnode.get_parent().global_transform.inverse()), "completed")
			$LoadingCube.visible = false
			for node in nodesh:
				if node.name[0] != "h":
					rootnode.otreecellscount += 1

		var tremaining = ticksms_tonextupdatepriorities - OS.get_ticks_msec()
		if tremaining > 5:
			yield(get_tree().create_timer(tremaining*0.001), "timeout")




func Dcorrectvisibilitymask():
	print("Dcorrectvisibilitymask runn")
	var scanningnode = rootnode
	while scanningnode != null:
		var locellmask = 0
		for i in range(1, scanningnode.get_child_count()):
			var cnode = scanningnode.get_child(i)
			if cnode.visible:
				locellmask |= (1 << int(cnode.name))
		if scanningnode.ocellmask != locellmask:
			print("Incorrect--visibility ", scanningnode.ocellmask, " ", locellmask, " on ", scanningnode.get_name())
		if scanningnode.pointmaterial != null:
			var kk = scanningnode.pointmaterial.get_shader_param("ocellmask")
			if scanningnode.ocellmask != kk:
				print("ocellmask not matching ", scanningnode.ocellmask, " ", kk)
			scanningnode.pointmaterial.set_shader_param("ocellmask", scanningnode.ocellmask)
		scanningnode = rootnode.successornode(scanningnode, false)
		print("Dcorrectvisibilitymask runn")
	

func laserplanfitting(Glaserorient, laserlength):
	var rayradius = 0.15
	var raywallfilterradius = rayradius*0.6
	var floorfilterdepth = rayradius*0.4
		
	var laserelev = rad2deg(-atan2(Glaserorient.basis.z.y, Vector2(Glaserorient.basis.z.x, Glaserorient.basis.z.z).length()))
	var laserorient = transform.inverse()*Glaserorient
	
	print("Glaserorient  ", Glaserorient.basis.z, " ", laserorient.basis.z)
	
	var aabbsegmentfrom = laserorient.origin
	var aabbsegmentto = laserorient.origin - laserorient.basis.z*laserlength
	var segintersectingboxestoscan = [ ]

	var scanningnode = rootnode
	while scanningnode != null:
		if scanningnode.name[0] == "h" or scanningnode.pointmaterial == null:
			scanningnode = rootnode.successornode(scanningnode, true)
		else:
			assert (scanningnode.mesh != null)
			var boxcentre = scanningnode.ocellorigin
			var boxextents = scanningnode.ocellsize/2 + Vector3(rayradius, rayradius, rayradius)
			var boxminmax = AABB(boxcentre - boxextents, boxextents*2)
			var segintersects = boxminmax.intersects_segment(aabbsegmentfrom, aabbsegmentto)
			if segintersects:
				segintersectingboxestoscan.push_back(scanningnode)
			scanningnode = rootnode.successornode(scanningnode, not segintersects)

	print("Nboxestoscan for potree collision ", len(segintersectingboxestoscan))
	var lammin = -1.0
	for lscanningnode in segintersectingboxestoscan:
		var relsegfrom = laserorient.origin - lscanningnode.ocellorigin
		var relsegvector = -laserorient.basis.z
		var surfacearrays = lscanningnode.mesh.surface_get_arrays(0)
		var surfacepoints = surfacearrays[Mesh.ARRAY_VERTEX]
		for p in surfacepoints:
			var vp = p - relsegfrom
			var lam = vp.dot(relsegvector)
			if lam > 0.0 and (lam < lammin or lammin == -1):
				var vpradial = vp - relsegvector*lam
				var vpradiallen = vpradial.length()
				if vpradiallen < rayradius:
					lammin = lam
				
	if lammin == -1:
		return null

	var hvec = Vector3(-Glaserorient.basis.z.x, 0.0, -Glaserorient.basis.z.z).normalized()
	var hvecperp = Vector3(hvec.z, 0.0, -hvec.x)
	
	var potreecontactpoint = laserorient.origin - lammin*laserorient.basis.z
	var Gpotreecontactpoint = transform.xform(potreecontactpoint)
	
	var potreewallpoints = [ ]
	var potreewallFpoints = [ ]
	var Nscan2s = 0
	var nrayradiuspoints = 0
	var sumpotreefloorzs = 0.0
	var npotreefloorzs = 0
	for lscanningnode in segintersectingboxestoscan:
		var boxradius = (lscanningnode.ocellsize/2).length()
		if potreecontactpoint.distance_to(lscanningnode.ocellorigin) < rayradius + boxradius:
			var relsegfrom = potreecontactpoint - lscanningnode.ocellorigin
			Nscan2s += 1
			var surfacearrays = lscanningnode.mesh.surface_get_arrays(0)
			var surfacepoints = surfacearrays[Mesh.ARRAY_VERTEX]  # will contain duplicates from lower boxes if we don't filter out by the visibility mask
			for p in surfacepoints:
				var vp = p - relsegfrom
				var Gvp = transform.xform(p + lscanningnode.ocellorigin) - Gpotreecontactpoint
				#     var Gvp = transform.basis.xform(vp)
				assert (is_equal_approx(vp.length(), Gvp.length()))
				if Gvp.length() < rayradius:
					nrayradiuspoints += 1
					if abs(Gvp.y) < floorfilterdepth:
						sumpotreefloorzs += Gvp.y
						npotreefloorzs += 1
					var fGvp = Vector2(hvecperp.dot(Gvp), hvec.dot(Gvp))
					if abs(fGvp.y) < raywallfilterradius:
						potreewallpoints.push_back(Gvp)
						potreewallFpoints.push_back(fGvp)
					
					
	if abs(laserelev) > 60.0:
		if npotreefloorzs > nrayradiuspoints*0.6:
			var bheight = sumpotreefloorzs/npotreefloorzs
			var planepoint = Gpotreecontactpoint + Vector3(0, bheight, 0)
			if laserelev < 0.0:
				return Transform(Vector3(1,0,0), Vector3(0,0,-1), Vector3(0,1,0), planepoint)
			else:
				return Transform(Vector3(1,0,0), Vector3(0,0,1), Vector3(0,-1,0), planepoint)

	var Sx = 0.0
	var Sx2 = 0.0
	var Sy = 0.0
	var Sxy = 0.0
	var n = len(potreewallFpoints)
	for fp in potreewallFpoints:
		Sx += fp.x
		Sx2 += fp.x*fp.x
		Sy += fp.y
		Sxy += fp.x*fp.y
	var d = n*Sx2 - Sx*Sx
	if d == 0:
		return null
		
	var a = (n*Sxy - Sx*Sy)/d
	var b = (Sy*Sx2 - Sx*Sxy)/d
	
	var planeang = atan(a)
	print("aa  ", a, " ", b, " ", n, "points out of ", nrayradiuspoints, " planeang ", rad2deg(planeang))
	var planepoint = Gpotreecontactpoint + b*hvec
	var planebasis = Glaserorient.basis.rotated(Vector3(0,-1,0), planeang)

	var Dnewhvec = Vector3(-planebasis.z.x, 0.0, -planebasis.z.z).normalized()
	var Dnewhvecperp = Vector3(Dnewhvec.z, 0.0, -Dnewhvec.x)
	var Dhd = [ ]
	var Dhpd = [ ]
	for Dp in potreewallpoints:
		Dhd.push_back(Dnewhvec.dot(Dp))
		Dhpd.push_back(Dnewhvecperp.dot(Dp))
	Dhd.sort()
	Dhpd.sort()
	print("hd ", Dhd[0], ",", Dhd[-1], " sidehd ", Dhpd[0], ",", Dhpd[-1])

# finish summing these up, then do a second time with a narrow band around the points
# then return this wall straight out
# we can also scan along a continuum and set a range size for the wall
#	hvec = 
#	var orientedwallpoints
	
	print("Nscan2s ", Nscan2s, " wallpoints ", len(potreewallpoints))
	var planefittrans = Transform(planebasis, planepoint)
	return planefittrans


