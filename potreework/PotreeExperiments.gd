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
			rootnode.commenceloadotree(urlotreedir)	
				
		else:
			rootnode.primarycameraorigin = primarycameraorigin
			rootnode.commenceocellprocessing()

func _input(event):
	if event is InputEventKey and event.scancode == KEY_7:
		potreeactivatebuttonpressed(event.pressed)
	if event is InputEventKey and event.scancode == KEY_6:
		if rootnode != null and rootnode.processingnode == null:
			rootnode.garbagecollectionsweep()
