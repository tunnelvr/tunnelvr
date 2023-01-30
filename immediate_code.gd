tool
extends EditorScript

# *******
# Control-Shift X to run this code in the editor
# *******

var regexacceptablefilecommand = RegEx.new()

func D_run():
	regexacceptablefilecommand.compile('(?i)^(?:|([a-z0-9.\\-_]+)\\s*:\\s*(newcave|newdir|cleardir|deletedir))\\s*$')
	var x = ""
	var mmtext = regexacceptablefilecommand.search(x)
	print(mmtext)
	if mmtext:
		print(mmtext.strings)
		print(len(mmtext.strings[0]))

func _run():
	print(Input.get_joy_name(0), " ", Input.get_joy_axis(0, 0), " ", Input.get_joy_axis(0, 1))
