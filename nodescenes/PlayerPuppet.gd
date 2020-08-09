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
	print("playing recording ", len(wavrecording)) 
	$HandLeft/AudioStreamPlayer3D.stream = wavrecording
	$HandLeft/AudioStreamPlayer3D.play()
