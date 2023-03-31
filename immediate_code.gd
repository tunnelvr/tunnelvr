tool
extends EditorScript

# *******
# Control-Shift X to run this code in the editor
# *******

func _run():
#	print(OS.get_datetime())
#	print(Time.get_ticks_msec())
	var k = parse_json('  {"hi":1}')
	if k:
		print(k)
	print("%.1f" % 5)
