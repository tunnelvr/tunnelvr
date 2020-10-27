tool
extends EditorScript

# *******
# Control-Shift X to run this code in the editor
# *******
#const xcenum = preload("res://xcenum.gd")



func _ready():
	pass
	
func _on_request_completed(result, response_code, headers, body):
	print(result, response_code, headers)
	#var r = JSON.parse(body.get_string_from_utf8())
	print(body)
	
	
class A:
	pass

func _run():
	var a = "sdfsdf&amp; fg&ampdfg"
	if a.find(" ") != -1:
		a = a.left(a.find(" "))
	print([a])
	print(a.is_valid_ip_address())

	
