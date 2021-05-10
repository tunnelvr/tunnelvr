tool
extends EditorScript

# *******
# Control-Shift X to run this code in the editor
# *******

func _run():
	var plyname = "res://surveyscans/pointscans/WSC 10cm WGS1984 - Cloud.ply"
	var fout = File.new()
	if fout.file_exists(plyname):
		fout.open(plyname, File.READ)
		while fout.get_line() != "end_header":
			print(fout.get_line())
		print("-----------------points")
		for i in range(2000000):
			var v = fout.get_line().trim_suffix(" ").split(" ")
			if len(v) != 8:
				print("vvvv ", v, i)
				break
				
		fout.close()
		
