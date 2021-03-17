tool
extends EditorScript

# *******
# Control-Shift X to run this code in the editor
# *******
var regex = RegEx.new()
func _run():
	var output = [ ]
	#var x = OS.execute("pwd", PoolStringArray(), true, output)
	var exit_code = OS.execute("dir", [".."], true, output)
	print(exit_code, output)
	print(OS.get_user_data_dir())
