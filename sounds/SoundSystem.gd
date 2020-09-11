extends Spatial

# For lots of sounds to decorate everything
# https://opengameart.org/content/51-ui-sound-effects-buttons-switches-and-clicks

var recording = null
var nowrecording = false

func _ready():
	Tglobal.soundsystem = self

func quicksound(sname, position):
	$quicksounds.get_node(sname).global_transform.origin = position
	$quicksounds.get_node(sname).play()

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

func playmyvoicerecording():
	var playerMe = get_node("/root/Spatial").playerMe
	playerMe.playvoicerecording(recording.get_data())
	if Tglobal.connectiontoserveractive:
		playerMe.rpc("playvoicerecording", recording.get_data())


