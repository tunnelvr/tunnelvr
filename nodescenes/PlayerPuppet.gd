extends Spatial

var networkID = 0

	
remote func initplayerpuppet(playerishandtracked):
	$HandLeft.initpuppetracking(playerishandtracked)
	$HandRight.initpuppetracking(playerishandtracked)

remote func setavatarposition(positiondict):
	var t0 = OS.get_ticks_msec()
	positiondict["handleft"]["timestamp"] = t0  # disable timestamping for now
	positiondict["handright"]["timestamp"] = t0  
	global_transform = positiondict["playertransform"]
	$HeadCam.transform = positiondict["headcamtransform"]
	while len($HandLeft.handpositionstack) > 10:
		$HandLeft.handpositionstack.pop_front()
	while len($HandRight.handpositionstack) > 10:
		$HandRight.handpositionstack.pop_front()
	$HandLeft.handpositionstack.push_back(positiondict.handleft)
	$HandRight.handpositionstack.push_back(positiondict.handright)

puppet func bouncedoppelgangerposition(bouncebackID, positiondict):
	get_parent().get_parent().playerMe.rpc_unreliable_id(bouncebackID, "setdoppelgangerposition", positiondict)

puppet func setdoppelgangerposition(positiondict):
	var doppelganger = get_parent().get_parent().playerMe.doppelganger
	if is_instance_valid(doppelganger):
		doppelganger.setavatarposition(positiondict)

remote func playvoicerecording(wavrecording):
	print("playing recording ", wavrecording.size()) 
	var stream = AudioStreamSample.new()
	stream.format = AudioStreamSample.FORMAT_16_BITS
	stream.data = wavrecording
	stream.mix_rate = 44100
	stream.stereo = true
	$HandRight/AudioStreamPlayer3D.stream = stream
	$HandRight/AudioStreamPlayer3D.play()
