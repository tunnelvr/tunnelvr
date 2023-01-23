extends Spatial

# For lots of sounds to decorate everything
# https://opengameart.org/content/51-ui-sound-effects-buttons-switches-and-clicks

var recording = null
var nowrecording = false

var quicksoundlastsoundposition = { "GentleCollide":Vector3(0,0,0),
									"GlancingMotion":Vector3(0,0,0) }

onready var HandLeftController = get_node("/root/Spatial/Players/PlayerMe/HandLeftController")
onready var HandRightController = get_node("/root/Spatial/Players/PlayerMe/HandRightController")

func _ready():
	Tglobal.soundsystem = self

func quicksound(sname, position):
	$quicksounds.get_node(sname).global_transform.origin = position
	$quicksounds.get_node(sname).play()

func quicksoundonpositionchange(sname, position, dist):
	if dist == 0 or position.distance_to(quicksoundlastsoundposition[sname]) > dist:
		if not $quicksounds.get_node(sname).playing:
			quicksoundlastsoundposition[sname] = position
			$quicksounds.get_node(sname).global_transform.origin = position
			$quicksounds.get_node(sname).play()
			return true
	return false
	
func startmyvoicerecording():
	var audiobusrecordeffect = AudioServer.get_bus_effect(AudioServer.get_bus_index("Record"), 0)
	audiobusrecordeffect.set_recording_active(true)
	print("Doing the recording ", audiobusrecordeffect)
	nowrecording = true

func stopmyvoicerecording():
	nowrecording = false
	var audiobusrecordeffect = AudioServer.get_bus_effect(AudioServer.get_bus_index("Record"), 0)
	recording = audiobusrecordeffect.get_recording()
	audiobusrecordeffect.set_recording_active(false)
	if recording != null:
		recording.save_to_wav("user://record4.wav")
		print("recording length ", recording.get_data().size())
		#print("fastlz ", recording.get_data().compress(File.COMPRESSION_FASTLZ).size())
		#print("COMPRESSION_DEFLATE ", recording.get_data().compress(File.COMPRESSION_DEFLATE).size())
		#print("COMPRESSION_ZSTD ", recording.get_data().compress(File.COMPRESSION_ZSTD).size())
		#print("COMPRESSION_GZIP ", recording.get_data().compress(File.COMPRESSION_GZIP).size())
		return recording.get_data().size()
	return 0
	
func playmyvoicerecording():
	var playerMe = get_node("/root/Spatial").playerMe
	if recording:
		playerMe.playvoicerecording(recording.get_data())
		if Tglobal.connectiontoserveractive:
			assert(playerMe.networkID != 0)			
			playerMe.rpc("playvoicerecording", recording.get_data())


var rumblecountdownleft = 0
var rumblecountdownright = 0
func _process(delta):
	rumblecountdownleft -= delta
	rumblecountdownright -= delta
	if rumblecountdownleft <= 0:
		HandLeftController.rumble = 0.0
	if rumblecountdownright <= 0:
		HandRightController.rumble = 0.0
	if rumblecountdownleft <= 0 and rumblecountdownright <= 0:
		set_process(false)

func shortvibrate(leftright, duration, intensity):
	if not Tglobal.questhandtrackingactive:
		if leftright:
			HandLeftController.rumble = intensity
			rumblecountdownleft = duration
		else:
			HandRightController.rumble = intensity
			rumblecountdownright = duration
		set_process(true)
