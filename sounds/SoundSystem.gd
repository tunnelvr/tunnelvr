extends Spatial

# For lots of sounds to decorate everything
# https://opengameart.org/content/51-ui-sound-effects-buttons-switches-and-clicks

func _ready():
	Tglobal.soundsystem = self

func quicksound(sname, position):
	get_node(sname).global_transform.origin = position
	get_node(sname).play()


# store functions here temporarily
func Dstartrecording():
	var audiobusrecordeffect = AudioServer.get_bus_effect(AudioServer.get_bus_index("Record"), 0)
	audiobusrecordeffect.set_recording_active(true)
	print("Doing the recording ", audiobusrecordeffect)

func Ddonerecording():
	var audiobusrecordeffect = AudioServer.get_bus_effect(AudioServer.get_bus_index("Record"), 0)
	var recording = audiobusrecordeffect.get_recording()
	var playerMe = get_node("/root/Spatial").playerMe
	if recording != null:
		recording.save_to_wav("user://record3.wav")
		audiobusrecordeffect.set_recording_active(false)
		#print("Saved WAV file to: %s\n(%s)" % ["user://record3.wav", ProjectSettings.globalize_path("user://record3.wav")])
		print("end_recording ", audiobusrecordeffect)
		#handleft.get_node("AudioStreamPlayer3D").stream = recording
		#handleft.get_node("AudioStreamPlayer3D").play()
		print("recording length ", recording.get_data().size())
		print("fastlz ", recording.get_data().compress(File.COMPRESSION_FASTLZ).size())
		print("COMPRESSION_DEFLATE ", recording.get_data().compress(File.COMPRESSION_DEFLATE).size())
		print("COMPRESSION_ZSTD ", recording.get_data().compress(File.COMPRESSION_ZSTD).size())
		print("COMPRESSION_GZIP ", recording.get_data().compress(File.COMPRESSION_GZIP).size())
		playerMe.playvoicerecording(recording.get_data())
		if Tglobal.connectiontoserveractive:
			playerMe.rpc("playvoicerecording", recording.get_data())



