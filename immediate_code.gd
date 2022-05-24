tool
extends EditorScript

# *******
# Control-Shift X to run this code in the editor
# *******


func _run():
	var m = RegEx.new()
	m.compile('\\[\\s*([^,]+),\\s*([^,]+),\\s*(\\S+)\\s*]')
	print(m.sub(j, "[$1, $2, $3]", true))

	var x = { "a":"b", "c":[1,2,3], "d":[-1e6,10,-99], "f":"hithere" }
	var j = JSON.print(x, "  ", true)
	# ([^,],)\s*([^,],)\s*(\S+)\s*\]
	print(j)

