tool
extends EditorScript

# *******
# Control-Shift X to run this code in the editor
# *******

func _run():
	var d = hash(String(OS.get_unix_time())+"abc")
	var headcolour = Color.from_hsv((d%10000)/10000.0, 0.5 + (d%2222)/6666.0, 0.75)
	print(d, " ", headcolour)
