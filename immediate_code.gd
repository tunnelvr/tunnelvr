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
	var g = "res://surveyscans/find_executingfeatures.py"
	var fg = g.rsplit("/")[-1]
	var dd = Directory.new()
	var d = "user://executingfeatures/"+fg
	print(ProjectSettings.globalize_path(d))
	var e = dd.copy(g, d)
	print(e)
