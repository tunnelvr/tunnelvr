extends Spatial

var networkID = 0

var puppetpositionstack = [ ]  # [ { "timestamp", "Ltimestamp", "playertransform", "headcamtransform" } ] 
	
remote func initplayerpuppet(playerishandtracked):
	$HandLeft.initpuppetracking(playerishandtracked)
	$HandRight.initpuppetracking(playerishandtracked)

# reltime is localtime - remotetime.  More delay means message sent earlier, means bigger number. Find smallest filtering any outliers
var relativetimeminmax = 0
var remotetimegapmaxmin = 0
var firstrelativetimenotset = true
var prevremotetime = 0
var reltimebatchcount = 0
var remotetimegapmin = 0
var relativetimemax = 0
var remotetimegap_dtmax = 0.8  # copied from PlayerMotion.gd
remote func setavatarposition(positiondict):
	var t0 = OS.get_ticks_msec()*0.001
	var reltime = t0 - positiondict["timestamp"]
	if reltimebatchcount == 0 or reltime > relativetimemax:
		relativetimemax = reltime
	if reltimebatchcount > 0:
		var remotetimegap = positiondict["timestamp"] - prevremotetime
		if reltimebatchcount == 1 or remotetimegap < remotetimegapmin:
			remotetimegapmin = remotetimegap
	reltimebatchcount += 1
	prevremotetime = positiondict["timestamp"]
	if reltimebatchcount == 10:
		if firstrelativetimenotset or relativetimemax < relativetimeminmax:
			relativetimeminmax = relativetimemax
		if firstrelativetimenotset or remotetimegapmin > remotetimegapmaxmin:
			remotetimegapmaxmin = remotetimegapmin
		reltimebatchcount = 0
		firstrelativetimenotset = false
		print("relativetimeminmax ", relativetimeminmax, "  ", remotetimegapmaxmin)
	if firstrelativetimenotset:
		return
			
	var dt = relativetimeminmax + remotetimegap_dtmax + 0.05  # was remotetimegapmaxmin, but only gets smooth when it gets to that value
	
	var puppetbody = { "timestamp":positiondict["timestamp"] }
	if positiondict.has("playertransform"):
		puppetbody["playertransform"] = positiondict["playertransform"]
	if positiondict.has("headcamtransform"):
		puppetbody["headcamtransform"] = positiondict["headcamtransform"]
	puppetbody["Ltimestamp"] = positiondict["timestamp"] + dt
	while len(puppetpositionstack) > 20:
		puppetpositionstack.pop_front()
	if puppetbody.has("playertransform") or puppetbody.has("headcamtransform"):
		puppetpositionstack.push_back(puppetbody)
	
	while len($HandLeft.handpositionstack) > 20:
		$HandLeft.handpositionstack.pop_front()
	while len($HandRight.handpositionstack) > 20:
		$HandRight.handpositionstack.pop_front()
	if positiondict.has("handleft"):
		positiondict["handleft"]["Ltimestamp"] = positiondict["handleft"]["timestamp"] + dt
		$HandLeft.handpositionstack.push_back(positiondict["handleft"])
	if positiondict.has("handright"):
		positiondict["handright"]["Ltimestamp"] = positiondict["handright"]["timestamp"] + dt
		$HandRight.handpositionstack.push_back(positiondict["handright"])

func _process(delta):
	process_puppetpositionstack(delta)

func process_puppetpositionstack(delta):
	var t = OS.get_ticks_msec()*0.001
	while len(puppetpositionstack) >= 2 and puppetpositionstack[1]["Ltimestamp"] <= t:
		puppetpositionstack.pop_front()
	if len(puppetpositionstack) == 0 or t < puppetpositionstack[0]["Ltimestamp"]:
		return
	var pp = puppetpositionstack[0]
	if len(puppetpositionstack) == 1:
		if pp.has("playertransform"):
			global_transform = pp["playertransform"]
		if pp.has("headcamtransform"):
			$HeadCam.transform = pp["headcamtransform"]
		puppetpositionstack.pop_front()
	else:
		var pp1 = puppetpositionstack[1]
		var lam = inverse_lerp(pp["Ltimestamp"], pp1["Ltimestamp"], t)
		if pp.has("playertransform") and pp1.has("playertransform"):
			global_transform = Transform(pp["playertransform"].basis.slerp(pp1["playertransform"].basis, lam), lerp(pp["playertransform"].origin, pp1["playertransform"].origin, lam))
		if pp.has("headcamtransform") and pp1.has("headcamtransform"):
			$HeadCam.transform = Transform(pp["headcamtransform"].basis.slerp(pp1["headcamtransform"].basis, lam), lerp(pp["headcamtransform"].origin, pp1["headcamtransform"].origin, lam))


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
