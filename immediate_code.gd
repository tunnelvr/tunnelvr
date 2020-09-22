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
	var x = Spatial.new()
	x.rotation_degrees.y = -90
	#x.rotation_degrees.z = 180
	var a = x.transform
	print(a.basis.x, a.basis.y, a.basis.z)

#		if islefthand:
#			handmodel.rotation_degrees.y = -90
#			handmodel.rotation_degrees.z = 180
#		else:
#			handmodel.rotation_degrees.y = -90
