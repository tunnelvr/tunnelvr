extends Spatial

remote func setavatarposition(playertransform, headcamtransform, handlefttransform, handrighttransform):
	global_transform = playertransform
	$HeadCam.transform = headcamtransform
	$HandLeft.visible = (handlefttransform != null)
	if $HandLeft.visible:
		$HandLeft.transform = handlefttransform
	$HandRight.visible = (handrighttransform != null)
	if $HandRight.visible:
		$HandRight.transform = handrighttransform

remotesync func playvoicerecording(wavrecording):
	print("playing recording ", wavrecording.size()) 
	var stream = AudioStreamSample.new()
	stream.format = AudioStreamSample.FORMAT_16_BITS
	stream.data = wavrecording
	stream.mix_rate = 44100
	stream.stereo = true
	$HandLeft/AudioStreamPlayer3D.stream = stream
	$HandLeft/AudioStreamPlayer3D.play()
