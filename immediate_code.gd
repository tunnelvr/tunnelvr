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
	var x = "asdasd asdas\nasdasd\nasssd"
	print(x.split("\n"))
	
