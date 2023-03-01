extends Node

var imgdir = "user://northernimages/"
var nonimagedir = "user://nonimagewebpages/"

var queuedrequests =  [ ]
var operatingrequests =  [ ]
var completedrequests = [ ]

var sparehttpclients = [ ]
const Nmaxsparehttpclients = 4
const Nmaxoperatingrequests = 4

var imageloadingthreadmutex = Mutex.new()
var imageloadingthreadsemaphore = Semaphore.new()
var imageloadingthread = Thread.new()
var Nimageloadingrequests = 0

var imageloadingrequests = [ ]
var imageloadedrequests = [ ]

var imagethreadloadedflags = Texture.FLAG_MIPMAPS|Texture.FLAG_REPEAT # |Texture.FILTER

onready var imagesystemreportslabel = get_node("/root/Spatial/GuiSystem/GUIPanel3D/Viewport/GUI/Panel/ImageSystemReports")

var regexurl = RegEx.new()

# to convert PDFs nix-shell -p imagemagick and ghostscript, then 
# convert firstfloorplan.pdf -density 600 -geometry 200% -trim -background white -alpha remove -alpha off firstfloorplan.png
# density is still blurry because resizing is happening after rendering, so I had to use Gimp to load and export at a higher resolution

func imageloadingthread_function(userdata):
	print("imageloadingthread_function started")
	while true:
		imageloadingthreadsemaphore.wait()
		imageloadingthreadmutex.lock()
		var imagerequestR = imageloadingrequests.pop_front()
		imageloadingthreadmutex.unlock()
		if imagerequestR == null:
			break
		var t0 = OS.get_ticks_msec()
		var Dmsgfile = ""
#		print("imagerequestRimagerequestR ", imagerequestR)
		if "paperdrawing" in imagerequestR:
			var imagerequest = imagerequestR
			var limageloadingthreaddrawingfile = imagerequest["fetcheddrawingfile"]
			var limageloadingthreadloadedimagetexture = ImageTexture.new()
			if not limageloadingthreaddrawingfile.begins_with("res://"):
				var limageloadingthreadloadedimage = Image.new()
				limageloadingthreadloadedimage.load(limageloadingthreaddrawingfile)
				limageloadingthreadloadedimagetexture = ImageTexture.new()
				limageloadingthreadloadedimagetexture.create_from_image(limageloadingthreadloadedimage, imagethreadloadedflags)
			else:
				limageloadingthreadloadedimagetexture = ResourceLoader.load(limageloadingthreaddrawingfile)
			imagerequest["imageloadingthreadloadedimagetexture"] = limageloadingthreadloadedimagetexture
			Dmsgfile = limageloadingthreaddrawingfile
			
		elif "nnode" in imagerequestR:
			imagerequestR["rootnode"].loadocellpointsmesh_InWorkerThread(imagerequestR)
			
		else:
			print("   &&& whattttnott")
			
		var dt = OS.get_ticks_msec() - t0
		if dt > 100:
			print("thread loading ", Dmsgfile, " took ", dt, " msecs")
		imageloadingthreadmutex.lock()

		print(" ****yooooo ", Dmsgfile)
		imageloadedrequests.push_back(imagerequestR)
		imageloadingthreadmutex.unlock()

func _exit_tree():
	imageloadingthreadmutex.lock()
	imageloadingrequests.push_front(null)
	imageloadingthreadmutex.unlock()
	imageloadingthreadsemaphore.post()
	imageloadingthread.wait_to_finish()

func _ready():
	imageloadingthread.start(self, "imageloadingthread_function")
	regexurl.compile("^(https?)://([^/:]*)(:\\d+)?(/.*)")

func clearallimageloadingactivity():
	operatingrequests.clear()
	completedrequests.clear()
	queuedrequests.clear()
	imageloadingrequests.clear()
	imageloadedrequests.clear()

func assignhttpclient(operatingrequest):
	assert (not operatingrequest.has("httpclient"))
	var urlcomponents = regexurl.search(operatingrequest["url"])
	if not urlcomponents:
		print("bad urlcomponents ", operatingrequest["url"])
		return false
	var host = urlcomponents.strings[2]
	var use_ssl = (urlcomponents.strings[1] == "https")
	var port = int(urlcomponents.strings[3])
	operatingrequest["urlkey"] = "%s %s %s"%[ host, port, use_ssl ]
	operatingrequest["urlpath"] = urlcomponents.strings[4]
	var httpclient = null
	for i in range(len(sparehttpclients)-1, -1, -1):
		if sparehttpclients[i]["urlkey"] == operatingrequest["urlkey"]:
			httpclient = sparehttpclients.pop_at(i)["httpclient"]
			break
	if httpclient != null:
		sparehttpclients.erase(operatingrequest["urlkey"])
		if httpclient.get_status() == HTTPClient.STATUS_CONNECTED:
			operatingrequest["httpclient"] = httpclient
			print(" reusing httpclient ", operatingrequest["url"])
			return true
	httpclient = HTTPClient.new()
	var e = httpclient.connect_to_host(host, (port if port else -1), use_ssl)
	if e != OK:
		print("not okay connect_to_host ", e)
		return false
	operatingrequest["httpclient"] = httpclient
	print(" new httpclient ", operatingrequest["urlkey"])
	return true

func storinghttpclient(operatingrequest):
	var httpclient = operatingrequest["httpclient"]
	operatingrequest.erase("httpclient")
	if httpclient.get_status() == HTTPClient.STATUS_CONNECTED:
		sparehttpclients.push_back({"urlkey":operatingrequest["urlkey"], "httpclient":httpclient})
		print(" storing httpclient ", operatingrequest["urlkey"])
	else:
		print(" dropping httpclient ", operatingrequest["urlkey"], " status ", httpclient.get_status())
	while len(sparehttpclients) >= Nmaxsparehttpclients:
		sparehttpclients.pop_front()

func http_request_poll(operatingrequest):
	var httpclient = operatingrequest["httpclient"]
	httpclient.poll()
	var httpclientstatus = httpclient.get_status()
	if httpclientstatus == HTTPClient.STATUS_DISCONNECTED:
		print(" disconnected httpclient ", operatingrequest["urlkey"])
		return -1
	elif httpclientstatus == HTTPClient.STATUS_RESOLVING or httpclientstatus == HTTPClient.STATUS_CONNECTING:
		return 0
	elif httpclientstatus == HTTPClient.STATUS_CANT_RESOLVE or httpclientstatus == HTTPClient.STATUS_CANT_CONNECT or httpclientstatus == HTTPClient.STATUS_CONNECTION_ERROR:
		var merr = "can't resolve" if httpclientstatus == HTTPClient.STATUS_CANT_RESOLVE else "can't connect" if httpclientstatus == HTTPClient.STATUS_CANT_CONNECT else "connection error"
		print(" bad httpclientstatus ", operatingrequest["urlkey"], " ", merr)
		return -1
	elif httpclientstatus == HTTPClient.STATUS_CONNECTED and not operatingrequest.has("partbody"):
		var err = httpclient.request(HTTPClient.METHOD_GET, operatingrequest["urlpath"], PoolStringArray(operatingrequest.get("headers", []))) 
		if err == OK:
			print(" httprequest made to ", operatingrequest["urlpath"])
			operatingrequest["partbody"] = PoolByteArray()
			return 0
		print("bad httpclient.request ", err)
		return -1
	elif httpclientstatus == HTTPClient.STATUS_REQUESTING:
		return 0
	elif httpclientstatus == HTTPClient.STATUS_BODY:
		var chunk = httpclient.read_response_body_chunk()
		if chunk.size() != 0:
			operatingrequest["partbody"] = operatingrequest["partbody"] + chunk
			#print("httpclient Chunk size ", chunk.size(), " ", len(operatingrequest["partbody"]), " ", operatingrequest["url"])
		return 0
	elif httpclientstatus == HTTPClient.STATUS_CONNECTED and operatingrequest.has("partbody"):
		var response_code = httpclient.get_response_code()
		if response_code == 200 or response_code == 206:
			var fout = File.new()
			var fname = operatingrequest["fetchednonimagedataobjectfile"] if operatingrequest.has("fetchednonimagedataobjectfile") else operatingrequest["fetcheddrawingfile"]
			fout.open(fname, File.WRITE)
			print("storing ", len(operatingrequest["partbody"]), " bytes to ", fname)
			fout.store_buffer(operatingrequest["partbody"])
			fout.close()
			operatingrequest.erase("partbody")
			storinghttpclient(operatingrequest)
			return 1
		else:
			operatingrequest.erase("partbody")
			print(" http response code bad ", response_code, " for ", operatingrequest)
			return -1
			
	else:
		print(" unknown httpclientstatus ", httpclientstatus)
		return -1
		

func correctdefaultimgtrimtofull(d):
	var imgheight = d.imgwidth*d.imgheightwidthratio
	d.imgtrimleftdown = Vector2(-d.imgwidth*0.5, -imgheight*0.5)
	d.imgtrimrightup = Vector2(d.imgwidth*0.5, imgheight*0.5)

func clearcachedir(dname):
	var dir = Directory.new()
	if not dir.dir_exists(dname):
		return
	var e = dir.open(dname)
	if e != OK:
		print("list dir error ", e)
		return
	var fnames = [ ]
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name != "." and file_name != "..":
			assert (not dir.current_is_dir())
			fnames.push_back(dname + file_name)
		file_name = dir.get_next()
	for fname in fnames:
		print("removing ", fname)
		var e1 = dir.remove(fname)
		if e1 != OK:
			print("remove file error ", e1)
	var e2 = dir.remove(dname)
	if e2 != OK:
		print("remove dir error ", e2)
			

func getshortimagename(xcresource, withextension, md5nameleng, nonimagepage={}):
	var fname = xcresource.substr(xcresource.find_last("/")+1)
	var ext = xcresource.get_extension()
	if ext != null and ext != "":
		ext = "."+ext
	fname = fname.get_basename()
	fname = fname.replace(".", "").replace("@", "").replace("%", "")
	var md5name = xcresource.md5_text().substr(0, md5nameleng)
	var extname = ""
	if nonimagepage.has("byteOffset"):
		extname = "_%d_%d" % [nonimagepage["byteOffset"], nonimagepage["byteSize"]]
	if len(fname) > 8:
		fname = fname.substr(0,4)+md5name+extname+fname.substr(len(fname)-4)
	else:
		fname = fname+md5name+extname
	return fname+ext if withextension else fname


func _process(delta):
	if len(operatingrequests) != 0:
		for i in range(len(operatingrequests)-1, -1, -1):
			var operatingrequest = operatingrequests[i]
			if http_request_poll(operatingrequest) != 0:
				operatingrequests.remove(i)
				completedrequests.push_back(operatingrequest)
	while len(queuedrequests) != 0 and len(operatingrequests) < Nmaxoperatingrequests:
		var operatingrequest = queuedrequests.pop_back()   # should favour nonimage requests?
		assignhttpclient(operatingrequest)
		operatingrequests.push_back(operatingrequest)
			
	var t0 = OS.get_ticks_msec()
	var Dpt = ""

	if Nimageloadingrequests != 0:
		imageloadingthreadmutex.lock()
		var fetchednonimagedataobject = imageloadedrequests.pop_front() if len(imageloadedrequests) != 0 else null
		imageloadingthreadmutex.unlock()
		if fetchednonimagedataobject != null:
			if "paperdrawing" in fetchednonimagedataobject:
				var imageloadedrequest = fetchednonimagedataobject
				var papertexture = imageloadedrequest["imageloadingthreadloadedimagetexture"]
				Nimageloadingrequests -= 1
				if papertexture.get_width() != 0:
					var fetcheddrawing = imageloadedrequest["paperdrawing"]
					var fetcheddrawingmaterial = fetcheddrawing.get_node("XCdrawingplane/CollisionShape/MeshInstance").get_surface_material(0)
					fetcheddrawingmaterial.set_shader_param("texture_albedo", papertexture)
					var previmgheightwidthratio = fetcheddrawing.imgheightwidthratio
					fetcheddrawing.imgheightwidthratio = papertexture.get_height()*1.0/papertexture.get_width()
					if previmgheightwidthratio == 0:
						correctdefaultimgtrimtofull(fetcheddrawing)				
					if fetcheddrawing.imgwidth != 0:
						fetcheddrawing.applytrimmedpaperuvscale()
						
				else:
					print(imageloadedrequest["fetcheddrawingfile"], "   has zero width, deleting if user://")
					if imageloadedrequest["fetcheddrawingfile"].begins_with("user://"):
						Directory.new().remove(imageloadedrequest["fetcheddrawingfile"])
				Dpt = "paptex"
				
			elif "nnode" in fetchednonimagedataobject:
				fetchednonimagedataobject["callbackobject"].call_deferred(fetchednonimagedataobject["callbackfunction"], fetchednonimagedataobject)
				Dpt = "nnodeload"

	var completedrequest = null
	if len(completedrequests) != 0 and not ("nnode" in completedrequests[0]):
		completedrequest = completedrequests.pop_front()
	if completedrequest == null:
		for i in range(len(completedrequests)):
			if "nnode" in completedrequests[i]:
				var lnnode = completedrequests[i]["nnode"]
				if lnnode.treedepth >= 1:
					var lnnodeparent = lnnode.get_parent()
					if lnnodeparent.mesh == null:
						continue
				completedrequest = completedrequests.pop_at(i)
				break
		
	if completedrequest != null and (("paperdrawing" in completedrequest) or ("nnode" in completedrequest)):
		imageloadingthreadmutex.lock()
		imageloadingrequests.push_back(completedrequest)
		completedrequest = null
		imageloadingthreadmutex.unlock()
		Nimageloadingrequests += 1
		imageloadingthreadsemaphore.post()
		Dpt = "semaphore thread"

	elif completedrequest != null:
		var fetchednonimagedataobject = completedrequest
		#print("FFFN ", fetchednonimagedataobject)
		if fetchednonimagedataobject.get("parsedumpcentreline") == "yes":
			# should be a callbackobject here VVV
			get_node("/root/Spatial/ExecutingFeatures").parse3ddmpcentreline_execute(fetchednonimagedataobject["fetchednonimagedataobjectfile"], fetchednonimagedataobject["url"])

		elif "callbackobject" in fetchednonimagedataobject:
			var f = File.new()
			f.open(fetchednonimagedataobject["fetchednonimagedataobjectfile"], File.READ)
			if "callbackfunction" in fetchednonimagedataobject:
				fetchednonimagedataobject["callbackobject"].call_deferred(fetchednonimagedataobject["callbackfunction"], f, fetchednonimagedataobject)
			elif "callbacksignal" in fetchednonimagedataobject:
				print("sending callbacksignal ", fetchednonimagedataobject["callbacksignal"], f)
				fetchednonimagedataobject["callbackobject"].emit_signal(fetchednonimagedataobject["callbacksignal"], f)
		else:
			print("what here?")
		fetchednonimagedataobject = null

	if len(operatingrequests) == 0 and len(completedrequests) != 0 and Nimageloadingrequests == 0:
		set_process(false)
		
	var dt = OS.get_ticks_msec() - t0
	if dt > 50:
		print("Long image system process ", dt, " ", Dpt)


func fetchrequesturl(nonimagedataobject):
	var url = nonimagedataobject["url"]
	if url.substr(0,4) == "http":
		#print("fetchrequesturl ", url, " ", nonimagedataobject.get("byteOffset"), " ", nonimagedataobject.get("byteSize"))
		fetchnonimagedataobject(nonimagedataobject)
	else:
		var f = File.new()
		f.open(url, File.READ)
		if nonimagedataobject.has("byteOffset"):
			f.seek(nonimagedataobject["byteOffset"])
		if "callbackfunction" in nonimagedataobject:
			nonimagedataobject["callbackobject"].call_deferred(nonimagedataobject["callbackfunction"], f, nonimagedataobject)
		elif "callbacksignal" in nonimagedataobject:
			yield(get_tree(), "idle_frame")
			nonimagedataobject["callbackobject"].emit_signal(nonimagedataobject["callbacksignal"], f)

func fetchunrolltree(fileviewtree, item, url, filetreeresource):
	var nonimagedataobject = { "url":url, 
							   "tree":fileviewtree, 
							   "item":item, 
							   "donotusecache":true, 
							   "callbackobject":get_node("/root/Spatial/PlanViewSystem"), 
							   "callbackfunction":"actunrolltree"
							 }
	if filetreeresource != null:
		nonimagedataobject["filetreeresource"] = filetreeresource
		if filetreeresource.get("type") == "caddyfiles":
			nonimagedataobject["headers"] = [ "accept: application/json" ]
	fetchnonimagedataobject(nonimagedataobject)

		
func fetchpaperdrawing(paperdrawing):
	#print(" ****yaaaaaa ", paperdrawing.xcresource)
	var fetcheddrawingfile = "res://guimaterials/imagefilefailure.png"
	if paperdrawing.xcresource.begins_with("http"):
		fetcheddrawingfile = imgdir+getshortimagename(paperdrawing.xcresource, true, 12)
		if not File.new().file_exists(fetcheddrawingfile):
			if not Directory.new().dir_exists(imgdir):
				var err = Directory.new().make_dir(imgdir)
				print("Making directory ", imgdir, " err code: ", err)
			var queuedrequest = { "paperdrawing":paperdrawing, 
								  "objectname":paperdrawing.get_name(), 
								  "fetcheddrawingfile":fetcheddrawingfile, 
								  "url":paperdrawing.xcresource }
			queuedrequests.push_back(queuedrequest)
			return
		else:
			print("using cached image ", fetcheddrawingfile)
	elif paperdrawing.xcresource.begins_with("res://"):
		fetcheddrawingfile = paperdrawing.xcresource
	completedrequests.push_back({ "paperdrawing":paperdrawing, 
								  "fetcheddrawingfile":fetcheddrawingfile })
	set_process(true)
	
func shuffleimagetotopoflist(paperdrawing):
	var fi = -1
	for i in range(len(queuedrequests)):
		var queuedrequest = queuedrequests[i]
		if "paperdrawing" in queuedrequest:
			if queuedrequests[i]["paperdrawing"] == paperdrawing:
				fi = i
	if fi != -1:
		print("shuffling from ", fi, " in list ", len(queuedrequests))
		var queuedrequest = queuedrequests[-1]
		queuedrequests[fi] = queuedrequests[-1]
		queuedrequests[-1] = queuedrequest
	else:
		print("image not in queuedrequests list")

func fetchnonimagedataobject(nonimagepage):
	nonimagepage["fetchednonimagedataobjectfile"] = nonimagedir + \
		getshortimagename(nonimagepage["url"], true, 
						  (10 if nonimagepage.has("byteOffset") else 20), 
						  nonimagepage)
	if not File.new().file_exists(nonimagepage["fetchednonimagedataobjectfile"]) or nonimagepage.get("donotusecache"):
		if not Directory.new().dir_exists(nonimagedir):
			var err = Directory.new().make_dir(nonimagedir)
			print("Making directory ", nonimagedir, " err code: ", err)
		var headers = nonimagepage.get("headers", [])
		if nonimagepage.has("byteOffset"):
			headers.push_back("Range: bytes=%d-%d" % [nonimagepage["byteOffset"], nonimagepage["byteOffset"]+nonimagepage["byteSize"]-1])
		nonimagepage["headers"] = headers
		imagesystemreportslabel.text = "%d-%s" % [len(queuedrequests), "nonimage"]
		queuedrequests.push_back(nonimagepage)
	else:
		completedrequests.push_back(nonimagepage)
	set_process(true)


