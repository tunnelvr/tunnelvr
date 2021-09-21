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

var ocellmask = 0
var rootnode = null
func _input(event):

	if event is InputEventKey and event.scancode == KEY_7 and event.pressed:
		assert (get_child_count() == 0)
		var rnode = MeshInstance.new()
		rnode.set_script(load("res://potreework/Onode_root.gd"))
		rnode.loadotree(d, "root")
		add_child(rnode)
		nodestoload.append(rnode)
		rootnode = rnode
		
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
		for i in range(0, 12):
			if len(nodestopointload) != 0:
				var rnode = nodestopointload.pop_front()
				print("loading ", rnode.get_path())
				rnode.loadoctcellpoints(rootnode.foctree, rootnode.mdscale, rootnode.mdoffset, rootnode.pointsizefactor)
				nodespointloaded.push_back(rnode)
		for rnode in nodespointloaded:
			rnode.setocellmask()

	if event is InputEventKey and event.scancode == KEY_4 and event.pressed:
		var primarycameraorigin = Vector3(0, 0, 0)
		var primarycamera = instance_from_id(Tglobal.primarycamera_instanceid)
		if primarycamera != null:
			primarycameraorigin = primarycamera.get_camera_transform().origin
		var nodestoload = rootnode.recalclodvisibility(primarycameraorigin)
		for node in nodestoload:
			if node.name[0] == "h":
				node.loadhierarchychunk(rootnode.fhierarchy)
			elif node.pointmaterial == null:
				node.loadoctcellpoints(rootnode.foctree, rootnode.mdscale, rootnode.mdoffset, rootnode.pointsizefactor)
		
		if false:
			if ocellmask == 0:
				ocellmask = 1
			elif ocellmask < 128:
				ocellmask = ocellmask*2
			else:
				ocellmask = 0
			print("ocellmask ", ocellmask)
			for rnode in nodespointloaded:
				rnode.pointmaterial.set_shader_param("ocellmask", ocellmask)
