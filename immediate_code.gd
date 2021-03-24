tool
extends EditorScript

# *******
# Control-Shift X to run this code in the editor
# *******

func rotationtoalign(a, b):
	var c = a.cross(b)
	var clength = c.length()
	var abl = a.length()*b.length()
	if abl == 0.0 or clength == 0.0:
		return Basis()
	var sinrot = clength/(a.length()*b.length())
	print("sinrot ", rad2deg(asin(sinrot)))
	return Basis(c/clength, asin(sinrot))
	

func _run():
	print(OS.get_unique_id() == "6e6e2e697912445d86bb1b5b93996cfe")
	
