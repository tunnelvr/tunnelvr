tool
extends EditorScript

# *******
# Control-Shift X to run this code in the editor
# *******


func _run():
	var m = RegEx.new()
	var merr = m.compile('\\[\\s*([^,]+),\\s*([^,]+),\\k*(\\S+)\\s*')
	print(merr, " ", m)
	print(m.search("jjj"))
	m.compile("\\S+")
	print(m.search("jjj"))
	
