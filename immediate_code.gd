tool
extends EditorScript

# *******
# Control-Shift X to run this code in the editor
# *******

func _run():
	var freecadappimage = "/home/julian/executables/FreeCAD_0.19-24267-Linux-Conda_glibc2.12-x86_64.AppImage"
	var surfacemeshfile = "/home/julian/.local/share/godot/app_userdata/tunnelvr_v0.5/executingfeatures/surfacemesh.txt"
	var flatmeshfile = "/home/julian/.local/share/godot/app_userdata/tunnelvr_v0.5/executingfeatures/flatmesh.txt"
	var meshflattenerpy = ProjectSettings.globalize_path("res://executingfeatures/meshflattener.py")
	var output = [ ]
	var pymeshpid = OS.execute("python", PoolStringArray([meshflattenerpy, freecadappimage, surfacemeshfile, flatmeshfile]), true, output)
	print("hi there", output)
