extends Node

var verropthreadmutex = Mutex.new()
var verropthreadsemaphore = Semaphore.new()
var verropthread = Thread.new()
var verropthreadoperating = false

var verropropehang_in = null
var verropropehang_out = null
var threadtoexit = false

var ropehangsinprocess = [ ]

func _exit_tree():
	finishveropthread()
	
func finishveropthread():
	verropthreadmutex.lock()
	verropropehang_in = null
	threadtoexit = true
	verropthreadmutex.unlock()
	verropthreadsemaphore.post()
	verropthread.wait_to_finish()
	threadtoexit = false
	verropthreadoperating = false

func _ready():
	verropthread.start(self, "verropthread_function")
	$RayCast.collision_mask = CollisionLayer.CL_PointerFloor | CollisionLayer.CL_CaveWall

func verropthread_function(userdata):
	print("verropthread_function started")
	while not threadtoexit:
		verropthreadsemaphore.wait()
		verropthreadmutex.lock()
		var lverropropehang = verropropehang_in
		verropropehang_in = null
		var lthreadtoexit = threadtoexit
		verropthreadmutex.unlock()
		if lthreadtoexit:
			break
		if lverropropehang != null:
			for i in range(10):
				lverropropehang.verletprojstep()
				lverropropehang.verletpullstep()
				lverropropehang.verletpullstep()
			lverropropehang.verletcollidestep($RayCast)
		verropthreadmutex.lock()
		verropropehang_out = lverropropehang
		verropthreadmutex.unlock()
	print("verropthread_function stopped")

func clearallverletactivity():
	ropehangsinprocess.clear()
	finishveropthread()
	verropthread.start(self, "verropthread_function")

func setropenodelabel(ropehang, ropenodename, labelstring):
	var labelgenerator = get_node("/root/Spatial/LabelGenerator")
	var xcn = ropehang.get_node("../XCnodes").get_node(ropenodename)
	if not xcn.has_node("RopeLabel"):
		var materialsystem = get_node("/root/Spatial/MaterialSystem")
		var ropelabelmaterialnode = materialsystem.get_node("labelmaterials/RopeLabel")
		var noderopelabel = ropelabelmaterialnode.duplicate()
		var mat = noderopelabel.get_surface_material(0).duplicate()
		noderopelabel.mesh = noderopelabel.mesh.duplicate()
		noderopelabel.set_surface_material(0, mat)
		xcn.add_child(noderopelabel)
	xcn.get_node("RopeLabel").visible = true
	print(" labelstring ", labelstring)
	labelgenerator.remainingropelabels.push_back([ropehang.get_parent().get_name(), ropenodename, labelstring])
	labelgenerator.restartlabelmakingprocess(null)

func addropehang(ropehang):
	if len(ropehang.oddropeverts) == 2:
		setropenodelabel(ropehang, ropehang.oddropeverts[0], "%.2fm"%ropehang.totalropeleng)
	if not ropehangsinprocess.has(ropehang):
		ropehangsinprocess.push_back(ropehang)
	ropehang.prevverletstretch = -1.0
	ropehang.verletiterations = 0
	#print("addropehang ", ropehang.get_parent().get_name())
	set_process(true)
	
func reportstretch(verropropehang):
	var labelgenerator = get_node("/root/Spatial/LabelGenerator")
	for oddnode in $RopeHang.oddropeverts:
		var xcn = $XCnodes.get_node(oddnode)
		if not xcn.has_node("RopeLabel"):
			xcn.add_child($RopeHang/RopeLabel.duplicate())
		xcn.get_node("RopeLabel").visible = true
		labelgenerator.remainingropelabels.push_back([get_name(), oddnode, "%.2fm"%$RopeHang.totalropeleng])
	if len($RopeHang.oddropeverts) != 0:
		labelgenerator.restartlabelmakingprocess(null)

	
var nFrame = 0
var verropcountdowntimer = 0.0
var verropcountdowntime = 0.5
var ropehangprocessindex = 0

var sortdfunctorigin = Vector3(0,0,0)
func sortdfunc(a, b):
	return sortdfunctorigin.distance_squared_to(a.get_parent().nodepointmean) < sortdfunctorigin.distance_squared_to(b.get_parent().nodepointmean)

func _process(delta):
	nFrame += 1
	if verropcountdowntimer > 0.0:
		verropcountdowntimer -= delta
		return
	verropcountdowntimer = verropcountdowntime
	if not verropthreadoperating:
		if len(ropehangsinprocess) != 0:
			ropehangprocessindex = (ropehangprocessindex+1)%len(ropehangsinprocess)
			if ropehangprocessindex == 3:
				sortdfunctorigin = get_node("/root/Spatial").playerMe.get_node("HeadCam").global_transform.origin
				ropehangsinprocess.sort_custom(self, "sortdfunc")
				ropehangprocessindex = 0
			verropthreadmutex.lock()
			verropropehang_in = ropehangsinprocess[ropehangprocessindex]
			verropthreadmutex.unlock()
			verropthreadoperating = true
			verropthreadsemaphore.post()
		else:
			set_process(false)

	else:
		verropthreadmutex.lock()
		var verropropehang = verropropehang_out
		verropropehang_out = null
		verropthreadmutex.unlock()
		if verropropehang != null:
			verropthreadoperating = false
			if verropropehang.get_parent().drawingvisiblecode == DRAWING_TYPE.VIZ_XCD_HIDE and verropropehang.get_parent().get_node("XCnodes").get_child_count() != 0:
				verropropehang.verletiterations += 1
				verropropehang.updatehangingrope_Verlet()
				var verletstretch = verropropehang.verletstretch()
				var verletmaxvelocity = verropropehang.verletmaxvelocity()
				if verropropehang.verletiterations == 5:
					verropropehang.verletgravity *= 0.4
				#print(" verletmaxvelocity ", verletmaxvelocity, " verletstretch ", verletstretch, " g", verropropehang.verletgravity)
				if (verletmaxvelocity < 0.0002 and verropropehang.prevverletstretch != -1 and abs(verropropehang.prevverletstretch - verletstretch) < 0.01) or \
						(verropropehang.verletiterations > 10):
					if len(verropropehang.oddropeverts) == 2:
						var stretchratio = (verropropehang.totalstretchropeleng - verropropehang.totalropeleng)/verropropehang.totalropeleng
						setropenodelabel(verropropehang, verropropehang.oddropeverts[-1], "%+.0f%%" % (stretchratio*100))
					ropehangsinprocess.erase(verropropehang)

				else:
					verropropehang.prevverletstretch = verletstretch
			else:
				ropehangsinprocess.erase(verropropehang)
			
	
	
	
	
