extends Node

const version = "v0.5.7"

var connectiontoserveractive = false
var morethanoneplayer = false
var printxcdrawingfromdatamessages = true

var arvrinterfacename = "none"  # OVRMobile, Oculus, OpenVR
var arvrinterface = null
var VRoperating = false

var controlslocked = false
var virtualkeyboardactive = false
var questhandtracking = false
var questhandtrackingactive = false

var handflickmotiongestureposition = 0
var soundsystem = null

var hidecavewallstoseefloors = false

var splaystationnoderegex = null
func _ready():
	splaystationnoderegex = RegEx.new()
	splaystationnoderegex.compile(".*[^\\d]$")
	
