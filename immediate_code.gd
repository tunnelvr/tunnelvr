tool
extends EditorScript

# *******
# Control-Shift X to run this code in the editor
# *******

func D_run():
	var a = PoolStringArray()
	a.push_back("d")
	if a:
		print("hji there")


func _run():
	var ffindexecutingfeaturespy = "res://surveyscans/find_executingfeatures.py"
	var arguments = PoolStringArray([
			ProjectSettings.globalize_path(ffindexecutingfeaturespy) ])
	print("python ", arguments)
	var output = [ ]
	var ffindexecutingfeaturespy_status = OS.execute("python", arguments, true, output)
	print(ffindexecutingfeaturespy_status, output[0].split(" "))
	print(OS.get_name())
