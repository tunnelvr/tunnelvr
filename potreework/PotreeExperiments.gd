extends Spatial

#var d = "/home/julian/data/pointclouds/potreetests/outdir/"
# PotreeConverter --source xxx.laz --outdir outdir --attributes position_cartesian --method poisson
var d = "D:/potreetests/outdir/"

var potreethreadmutex = Mutex.new()
var potreethreadsemaphore = Semaphore.new()
var potreethread = null # Thread.new()
var threadtoexit = false
var nodestoload = [ ]
var nodestopointload = [ ]
var nodespointloaded = [ ]
var rootnode = null

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
	rootnode.sethighlightplane(planetransform.basis.z, 
							   planetransform.basis.z.dot(planetransform.origin))

func potreeactivatebuttonpressed(buttondown):
	if buttondown:
		var primarycameraorigin = Vector3(0, 0, 0)
		var primarycamera = instance_from_id(Tglobal.primarycamera_instanceid)
		if primarycamera != null:
			primarycameraorigin = primarycamera.get_camera_transform().origin

		if rootnode == null:
			rootnode = MeshInstance.new()
			rootnode.set_script(load("res://potreework/Onode_root.gd"))
			rootnode.primarycameraorigin = primarycameraorigin
			rootnode.name = "hroot"
			add_child(rootnode)
			rootnode.loadotree(d)
		else:
			rootnode.primarycameraorigin = primarycameraorigin
			rootnode.processingnode = rootnode
			rootnode.set_process(true)
			if false:
				var nodestoload = rootnode.recalclodvisibility(primarycameraorigin)
				for node in nodestoload:
					if node.name[0] == "h":
						node.loadhierarchychunk(rootnode.fhierarchy)
					elif node.pointmaterial == null:
						node.loadoctcellpoints(rootnode.foctree, rootnode.mdscale, rootnode.mdoffset, rootnode.pointsizefactor)

func _input(event):
	if event is InputEventKey and event.scancode == KEY_7:
		potreeactivatebuttonpressed(event.pressed)
		
	if event is InputEventKey and event.scancode == KEY_6 and event.pressed:
		if len(nodestoload) != 0:
			var lnode = nodestoload.pop_front()
			var nodes = lnode.loadhierarchychunk(rootnode.fhierarchy)
			for node in nodes:
				if not node.isdefinitionloaded:
					nodestoload.append(node)
				else:
					nodestopointload.append(node)
					
	if event is InputEventKey and event.scancode == KEY_5 and event.pressed:
		var node = rootnode
		while node != null:
			print(node)
			node = rootnode.successornode(node, false)
		if false:
			for i in range(0, 12):
				if len(nodestopointload) != 0:
					var rnode = nodestopointload.pop_front()
					print("loading ", rnode.get_path())
					rnode.loadoctcellpoints(rootnode.foctree, rootnode.mdscale, rootnode.mdoffset, rootnode.pointsizefactor)
					nodespointloaded.push_back(rnode)
			for rnode in nodespointloaded:
				rnode.setocellmask()

