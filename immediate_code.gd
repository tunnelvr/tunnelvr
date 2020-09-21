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
	var x = Basis()
	x = x.rotated(Vector3(0.22,1,0).normalized(), 1.01)
	var q = x.get_rotation_quat()
	var y = x.rotated(Vector3(0,0,1), 0.34)
	var q2 = y.get_rotation_quat()
	print(q2)
	#var a = q.inverse()*q2
	var a = q2.inverse()*q
	print(a, a.w, " ", acos(a.w)*2)
	var v = {"a":9, "jj":10}
	print(v)
	v.erase("a")
	print(v)
