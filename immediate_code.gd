tool
extends EditorScript

# *******
# Control-Shift X to run this code in the editor
# *******
var regex = RegEx.new()

func _run():
	regex.compile(".*[^\\d]$")
	var x = regex.search("3453a")
	if x:
		print("splay")
	else:
		print("not splay")
