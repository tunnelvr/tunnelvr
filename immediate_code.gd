tool
extends EditorScript

# *******
# Control-Shift X to run this code in the editor
# *******
#const xcenum = preload("res://xcenum.gd")

	
var h = HTTPRequest.new()
var url = "http://cave-registry.org.uk/svn/NorthernEngland/ThreeCountiesArea/rawscans/Ireby/"

var xxx = """<html><head><title>NorthernEngland - Revision 3284: /ThreeCountiesArea/rawscans/Ireby</title></head>
<body>
 <h2>NorthernEngland - Revision 3284: /ThreeCountiesArea/rawscans/Ireby</h2>
 <ul>
  <li><a href="../">..</a></li>
  <li><a href="AdulterersNotes1.jpg">AdulterersNotes1.jpg</a></li>
  <li><a href="AdulterersSketch1.jpg">AdulterersSketch1.jpg</a></li>
  <li><a href="BetweenDukeSt1&amp;RopePitch-rawnotes1.jpg">BetweenDukeSt1&amp;RopePitch-rawnotes1.jpg</a></li>
  <li><a href="BetweenDukeSt1&amp;RopePitch-rawnotes2.jpg">BetweenDukeSt1&amp;RopePitch-rawnotes2.jpg</a></li>
  <li><a href="BlissfulCreek-p1of9-NeilNumbers.jpg">BlissfulCreek-p1of9-NeilNumbers.jpg</a></li>
  <li><a href="BlissfulCreek-p2backof9-NeilNumbers.jpg">BlissfulCreek-p2backof9-NeilNumbers.jpg</a></li>
  <li><a href="BlissfulCreek-p2frontof9-NeilSketchA.jpg">BlissfulCreek-p2frontof9-NeilSketchA.jpg</a></li>
  <li><a href="BlissfulCreek-p3of9-NeilSketchB.jpg">BlissfulCreek-p3of9-NeilSketchB.jpg</a></li>
  <li><a href="BlissfulCreek-p4of9-NeilNumbers.jpg">BlissfulCreek-p4of9-NeilNumbers.jpg</a></li>
  <li><a href="BlissfulCreek-p5of9-NeilSketchC.jpg">BlissfulCreek-p5of9-NeilSketchC.jpg</a></li>
  <li><a href="BlissfulCreek-p6of9-BeckaNumbers.jpg">BlissfulCreek-p6of9-BeckaNumbers.jpg</a></li>
  <li><a href="BlissfulCreek-p7of9-BeckaNumbers.jpg">BlissfulCreek-p7of9-BeckaNumbers.jpg</a></li>
  <li><a href="BlissfulCreek-p8of9-BeckaNumbers.jpg">BlissfulCreek-p8of9-BeckaNumbers.jpg</a></li>
  <li><a href="BlissfulCreek-p9of9-BeckaNumbers.jpg">BlissfulCreek-p9of9-BeckaNumbers.jpg</a></li>
  <li><a href="BllissfulCreek001.jpg">BllissfulCreek001.jpg</a></li>
  <li><a href="BllissfulCreek002.jpg">BllissfulCreek002.jpg</a></li>
  <li><a href="Bolton1-SlugDrawnUp.jpg">Bolton1-SlugDrawnUp.jpg</a></li>
"""


func _ready():
	print("KKK", h)
	h.connect("request_completed", self, "_on_request_completed")

func _on_request_completed(result, response_code, headers, body):
	print(result, response_code, headers)
	#var r = JSON.parse(body.get_string_from_utf8())
	print(body)
	
	
class A:
	pass

func _run():
	var regex = RegEx.new()
	regex.compile('<li><a href="([^"]*)">') # Negated whitespace character class.
	var results = []
	#for m in regex.search_all(xxx):
	#	print(m.get_string(1))
# The `results` array now contains "One", "Two", "Three".
	var imgregex = RegEx.new()
	imgregex.compile('(?i)\\.(png|jpg|jpeg)$')
	print(imgregex.search("hj i.PiNG") == null)
	#print(xxx)
	
