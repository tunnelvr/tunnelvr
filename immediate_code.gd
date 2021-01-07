tool
extends EditorScript

# *******
# Control-Shift X to run this code in the editor
# *******
	
	
func _run():
	
	print(hash("aaaaaaaaaaaaa"))
	print(hash("bbbbbbbbbbbbb"))
	var n = "mmmmmmmmmmmmm"
	var d = ((hash(n)%10000)/10000.0*(181-22)+22)/400
	print("%.0f%%" % 6.5)
	
	print(Color.from_hsv(d, 0.47, 0.97))

