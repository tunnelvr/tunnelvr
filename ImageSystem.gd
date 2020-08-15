extends Node

var url = "http://cave-registry.org.uk/svn/NorthernEngland/ThreeCountiesArea/rawscans/Ireby/"
var urlimg = url+"BoltonExtensionsResurvey-DrawnUpSketch-1.jpg"

func D_on_request_completed(result, response_code, headers, body):
	print(result, response_code, headers)
	var f = File.new()
	var xx = f.open("user://northernimages/thing.jpg", File.WRITE)
	print("xx", xx)
	f.store_buffer(body)
	f.close()
	return
	
	var dir = Directory.new()
	if dir.open("user://cavedata/") == OK:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if dir.current_is_dir():
				print("Found directory: " + file_name)
			else:
				print("Found file: " + file_name)
			file_name = dir.get_next()
	else:
		print("An error occurred when trying to access the path.")
		
	var b :String = body.get_string_from_utf8()
	var regex = RegEx.new()
	regex.compile('href="(.*?)"')
	var g = regex.search_all(b)
	var a = g[0]
	for x in g:
		print(x.strings)
	
var imgdir = "user://northernimages/"
#var dirimg = Directory.new()
var urldir = "http://cave-registry.org.uk/svn/NorthernEngland/ThreeCountiesArea/rawscans/Ireby/"
var imglist = ["BoltonExtensionsResurvey-DrawnUpSketch-1.jpg", 
			   "DukeStResurvey-drawnup-p1.jpg", 
			   "DukeStResurvey-drawnup-p2.jpg", 
			   "DukeStResurvey-drawnup-p3.jpg", 
			   "DukeStParallelSidePassage-DrawnUp1.jpg",
			   "DukeStParallelSidePassage-DrawnUp2.jpg"
			]
	
func _ready():
	connect("loadpaperimage_signal", self, "loadpaperimage")
	
signal loadpaperimage_signal(paperdrawing)

var paperwidth = 0.4

func loadpaperimage(paperdrawing, timer=null):
	if timer != null:
		timer.queue_free()
	var img = Image.new()

	if paperdrawing.get_name() == "floordrawing" or paperdrawing.get_name() == "paper_DukeStResurvey-drawnup-p3":
		var x = load("res://surveyscans/DukeStResurvey-drawnup-p3.jpg")
		print(x.get_data(), x)
		img.copy_from(x.get_data())
	else:
		var fname = paperdrawing.get_name().replace("paper_", "")+".jpg"
		img.load(imgdir+fname)
	var papertexture = ImageTexture.new()
	papertexture.create_from_image(img)
	paperdrawing.get_node("XCdrawingplane/CollisionShape/MeshInstance").get_surface_material(0).albedo_texture = papertexture
	if papertexture.get_width() != 0:
		paperdrawing.get_node("XCdrawingplane").scale.y = paperdrawing.get_node("XCdrawingplane").scale.x*papertexture.get_height()/papertexture.get_width()
	else:
		print(paperdrawing.get_name(), "   has zero width ")
	nextrequest()

var fimgtosave = ""
func _http_request_completed(result, response_code, headers, body, httprequest, paperdrawing):
	httprequest.queue_free()
	requestcount -= 1
	if response_code != 200:
		print("http response code bad ", response_code, " for ", paperdrawing.get_name())
	emit_signal("loadpaperimage_signal", paperdrawing)

var paperdrawinglist = [ ]
var requestcount = 0
func nextrequest():
	if not Directory.new().dir_exists(imgdir):
		Directory.new().make_dir(imgdir)
	if len(paperdrawinglist) > 0:
		var paperdrawing = paperdrawinglist.pop_front()
		if paperdrawing.get_name() == "floordrawing" or paperdrawing.get_name() == "paper_DukeStResurvey-drawnup-p3":
			loadpaperimage(paperdrawing)  # ready not called yet so no signal connection
		else:
			var fname = paperdrawing.get_name().replace("paper_", "")+".jpg"
			if File.new().file_exists(imgdir+fname):
				var timer = Timer.new()
				timer.connect("timeout", self, "loadpaperimage", [paperdrawing, timer])
				add_child(timer)
				timer.set_wait_time(0.1)
				timer.start()
			else:
				var httprequest = HTTPRequest.new()
				add_child(httprequest)
				httprequest.connect("request_completed", self, "_http_request_completed", [httprequest, paperdrawing])
				httprequest.download_file = imgdir+fname
				httprequest.request(urldir+fname)
	else:
		requestcount -= 1
	
func fetchimportpapers():
	var player = get_node("/root/Spatial").playerMe
	var playerhead = player.get_node("HeadCam")
	var playerhgaze = Vector3(playerhead.global_transform.basis.z.x, 0, playerhead.global_transform.basis.z.z).normalized()
	var paperorg = Vector3(player.global_transform.origin) + Vector3(0, 0.2, 0) - playerhgaze*2.3
	var lookvec = paperorg - (playerhead.global_transform.origin + Vector3(0,0.9,0))
	var papertransorg = Transform(Basis(), paperorg).looking_at(paperorg + lookvec, Vector3(0,1,0))
	for i in range(len(imglist)):
		var papertrans = Transform(papertransorg.basis, papertransorg.origin 
									+ papertransorg.basis.x*((i%5)-2)*(paperwidth + 0.05) 
									+ papertransorg.basis.z*(i%2)*(paperwidth*0.2) 
									+ Vector3(0, int(i/5+1)*(paperwidth*0.6+0.05), 0))
		
		var fname = imglist[i]
		var sname = "paper_"+fname.replace(".jpg", "")
		var paperdrawing = get_node("/root/Spatial/SketchSystem").newXCuniquedrawing(DRAWING_TYPE.DT_PAPERTEXTURE, sname)
		paperdrawing.global_transform = papertrans
		paperdrawing.get_node("XCdrawingplane").scale = Vector3(paperwidth/2, paperwidth/2, 1)
		paperdrawinglist.append(paperdrawing)
		
	requestcount += 1
	nextrequest()

func fetchpaperdrawing(paperdrawing):
	paperdrawinglist.append(paperdrawing)
	if requestcount == 0:
		requestcount += 1
		nextrequest()


func _input(event):
	if event is InputEventKey and event.pressed and event.scancode == KEY_V:
		fetchimportpapers()
