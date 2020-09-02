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
	var x = IP.get_local_addresses()
	var lefthandmodel = load("res://addons/godot_ovrmobile/example_scenes/left_hand_model.glb").instance()
	print(lefthandmodel)
	for a in lefthandmodel.get_node("ArmatureLeft/Skeleton").get_children():
		print("  ", a, " ", a.get_name())
	var skel = lefthandmodel.get_node("ArmatureLeft/Skeleton")
	print(skel)
	print(skel.get_bone_count())
	print(skel.get_bone_rest(0))
