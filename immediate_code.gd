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
	
	var csvname = "res://surveyscans/pointscans/smallcloud.csv"
	print("Loading pointmesh ", csvname)
	var fin = File.new()
	fin.open(csvname, File.READ)
	var v = fin.get_csv_line()
	while len(v) == 3:
		var a = Vector3(float(v[0]), float(v[2]), float(v[1]))
		v = fin.get_csv_line()
	fin.close()
	
