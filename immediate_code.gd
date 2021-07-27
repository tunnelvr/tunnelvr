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
	var s = "[clol].,..[/as]"
	var regexrichtextcodes = RegEx.new()
	regexrichtextcodes.compile('\\[[^\\]\n]*\\]')
	print(s)
	print([regexrichtextcodes.sub(s, "", true)])
