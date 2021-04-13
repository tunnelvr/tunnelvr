tool
extends EditorScript

# *******
# Control-Shift X to run this code in the editor
# *******

func _run():
	var ipnums = ["192.168.43.1"]
	for i in range(1000):
		var ipnum = ipnums[i%len(ipnums)]
		var udpsender = PacketPeerUDP.new()
		var msg = "Hello there %d" % i
		udpsender.connect_to_host(ipnum, 4547)
		udpsender.put_packet(PoolByteArray(msg))
		udpsender.close()
		OS.delay_msec(2000)
