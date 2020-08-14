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
	
var dirimg = Directory.new()
var imgdir = "user://northernimages/"
	
func _ready():
	print(dirimg.make_dir(imgdir), " ", ERR_ALREADY_EXISTS)
	var urld = "http://cave-registry.org.uk/svn/NorthernEngland/ThreeCountiesArea/rawscans/Ireby/"
	var fname = "BoltonExtensionsResurvey-DrawnUpSketch-1.jpg"
	$HTTPRequest.connect("request_completed", self, "_on_request_completed")
	downloadimg(urld, fname)

var fimgtosave = ""
func _on_request_completed(result, response_code, headers, body):
	print([len(body), result, response_code, headers])
	var f = File.new()
	var xx = f.open(fimgtosave, File.WRITE)
	print("xx", xx)
	f.store_buffer(body)
	f.close()
	
	var paperdrawing = get_node("../SketchSystem").newXCuniquedrawing("paper1")
	paperdrawing.setaspapertype(fimgtosave)


func downloadimg(urld, fname):
	fimgtosave = dirimg.get_current_dir()+fname
	$HTTPRequest.request(urld+fname)

