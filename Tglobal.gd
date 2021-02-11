extends Node

const version = "v0.5.5"

var connectiontoserveractive = false
var morethanoneplayer = false
var printxcdrawingfromdatamessages = true

var arvrinterfacename = "none"  # OVRMobile, Oculus, OpenVR
var arvrinterface = null
var VRoperating = false

var controlslocked = false
var questhandtracking = false
var questhandtrackingactive = false

var handflickmotiongestureposition = 0
var soundsystem = null

var hidecavewallstoseefloors = false

var splaystationnoderegex = RegEx.new()
func _ready():
	splaystationnoderegex.compile(".*[^\\d]$")
	
