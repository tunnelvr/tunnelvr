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
	

func _run():
	var networkID = 61636234
	var a = Color.from_hsv((networkID%10000)/10000.0, 0.2 + (networkID%2222)/6666.0, 0.76)
	print(a)
	print(a.r, " ", a.g, " ", a.b)
	
