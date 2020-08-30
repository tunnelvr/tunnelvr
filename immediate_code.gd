tool
extends EditorScript

# *******
# Control-Shift X to run this code in the editor
# *******
#const xcenum = preload("res://xcenum.gd")

	
var h = HTTPRequest.new()
var url = "http://cave-registry.org.uk/svn/NorthernEngland/ThreeCountiesArea/rawscans/Ireby/"

func _ready():
	print("KKK", h)
	h.connect("request_completed", self, "_on_request_completed")

func _on_request_completed(result, response_code, headers, body):
	print(result, response_code, headers)
	#var r = JSON.parse(body.get_string_from_utf8())
	print(body)
	
func gg(x):
	print(x)
	assert (x)
	print("ggg")	
	return 55

func _run():
	var x = IP.get_local_addresses()
	var k = "://jssss/affff_g"
	print(k.get_extension() == "")
	print(k.get_basename())
	print(k.substr(k.find_last("/")+1))
	k = "abcdefghijklm"
	print(k.substr(0,4), " ", k.substr(len(k)-4))
	
