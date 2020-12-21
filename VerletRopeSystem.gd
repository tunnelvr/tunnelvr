extends Node

var verropthreadmutex = Mutex.new()
var verropthreadsemaphore = Semaphore.new()
var verropthread = Thread.new()
var verropthreadoperating = false

var verropropehang_in = null
var verropropehang_out = null

var ropehangsinprocess = [ ]

func _exit_tree():
	verropthreadmutex.lock()
	verropropehang_in = null
	verropthreadmutex.unlock()
	verropthreadsemaphore.post()
	verropthread.wait_to_finish()

func _ready():
	verropthread.start(self, "verropthread_function")
	$RayCast.collision_mask = CollisionLayer.CL_PointerFloor | CollisionLayer.CL_CaveWall

func verropthread_function(userdata):
	print("verropthread_function started")
	while true:
		verropthreadsemaphore.wait()
		verropthreadmutex.lock()
		var lverropropehang = verropropehang_in
		verropropehang_in = null
		verropthreadmutex.unlock()
		if lverropropehang != null:
			for i in range(10):
				lverropropehang.verletprojstep()
				lverropropehang.verletpullstep()
				lverropropehang.verletpullstep()
			lverropropehang.verletcollidestep($RayCast)
		verropthreadmutex.lock()
		verropropehang_out = lverropropehang
		verropthreadmutex.unlock()


func addropehang(ropehang):
	if not ropehangsinprocess.has(ropehang):
		ropehangsinprocess.push_back(ropehang)
	ropehang.prevverletstretch = -1.0
	ropehang.verletiterations = 0
	set_process(true)
	
var nFrame = 0
var verropcountdowntimer = 0.0
var verropcountdowntime = 0.5
var ropehangprocessindex = 0
func _process(delta):
	nFrame += 1
	if verropcountdowntimer > 0.0:
		verropcountdowntimer -= delta
		return
	verropcountdowntimer = verropcountdowntime
	if not verropthreadoperating:
		if len(ropehangsinprocess) != 0:
			ropehangprocessindex = (ropehangprocessindex+1)%len(ropehangsinprocess)
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
			if verropropehang.get_parent().drawingvisiblecode == DRAWING_TYPE.VIZ_XCD_HIDE:
				verropropehang.verletiterations += 1
				verropropehang.updatehangingrope_Verlet()
				var verletstretch = verropropehang.verletstretch()
				var verletmaxvelocity = verropropehang.verletmaxvelocity()
				print(" verletmaxvelocity ", verletmaxvelocity, " verletstretch ", verletstretch)
				if (verletmaxvelocity < 0.0002 and verropropehang.prevverletstretch != -1 and abs(verropropehang.prevverletstretch - verletstretch) < 0.01) or \
						(verropropehang.verletiterations > 10):
					ropehangsinprocess.erase(verropropehang)
				else:
					verropropehang.prevverletstretch = verletstretch

			else:
				ropehangsinprocess.erase(verropropehang)
			
	
	
	
	
