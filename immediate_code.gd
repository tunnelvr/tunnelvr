tool
extends EditorScript

# *******
# Control-Shift X to run this code in the editor
# *******


func D_run():

	var a = Vector3(0,0,0)
	var b = Vector3(2,0,0)
	var c = Vector3(1,1,0)
	var pre_a = a - (c-a)*5
	var post_b = b + (b-c)*5
	for i in range(11):
		var weight = i/10.0
		print(a.cubic_interpolate(b, pre_a, post_b, weight))
func _run():
	var x = "&#21E7;"
	if x[0] == "&":
		print(("&#%d;" % ("0x"+x.substr(2, 4)).hex_to_int()).xml_unescape())
	
	print("&#21E7;".xml_unescape())
	print("sssss &#0059;".xml_unescape())
	
	print("&".xml_escape())
	print("&lt;".xml_unescape())
	print("0x232B".hex_to_int())
	
