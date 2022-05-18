tool
extends EditorScript

# *******
# Control-Shift X to run this code in the editor
# *******

func sortquatfunc(a, b):
	return a.x < b.x or (a.x == b.x and (a.y < b.y or (a.y == b.y and (a.z < b.z or (a.z == b.z and a.w < b.w)))))



func _run():
	var dirname = "res://assets/iphonelidarmodels"
	var dir = Directory.new()
	var glbfiles = [ ]
	if dir.open(dirname) == OK:
		dir.list_dir_begin()
		while true:
			var file_name = dir.get_next()
			if file_name == "":  break
			if not dir.current_is_dir() and file_name.ends_with(".glb"):
				glbfiles.push_back(dirname+"/"+file_name)
	print(glbfiles)
	glbfiles.sort()
	var h = load(glbfiles[0])
	print(h)

