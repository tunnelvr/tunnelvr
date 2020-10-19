tool
#extends EditorPlugin

# Copyright (c) 2019, Pycom Limited.
# Some parts copyright (c) 2020, Dynamic Devices Ltd

# This software is licensed under the GNU GPL version 3 or any
# later version, with permitted additional terms. For more information
# see the Pycom Licence v1.0 document supplied with this file, or
# available at https://www.pycom.io/opensource/licensing
#
#
# Ported to gdscript by Alex J Lennon <ajlennon@dynamicdevices.co.uk>
#
# - ssl not implemented yet
# - lwt not tested
# - qos 1,2 may not work
#
# Code should be considered ALPHA

extends Node

var server = "sensorcity.io"
var port = 1883
var client_id = "client_id"
var client = null
var ssl = false
var ssl_params = null
var pid = 0
var user = null
var pswd = null
var keepalive = 0
var lw_topic = null
var lw_msg = null
var lw_qos = 0
var lw_retain = false

var _timer = null

signal received_message(topic, message)

#func _init(client_id, server, port=0, user=null, password=null, keepalive=0,ssl=false, ssl_params={}):
#	self.server = server
#	if port == 0:
#		port = 8883 if ssl else 1883
#	self.port = port
#	self.client_id = client_id
#	self.client = null
#	self.ssl = ssl
#	self.ssl_params = ssl_params
#	self.pid = 0
#	self.user = user
#	self.pswd = password
#	self.keepalive = keepalive
#	self.lw_topic = null
#	self.lw_msg = null
#	self.lw_qos = 0
#	self.lw_retain = false

func _recv_len():
	var n = 0
	var sh = 0
	var b
	while 1:
		b = self.client.get_u8() # Is this right ?
		n |= (b & 0x7f) << sh
		if not b & 0x80:
			return n
		sh += 7

func set_last_will(topic, msg, retain=false, qos=0):
	assert(0 <= qos <= 2)
	assert(topic)
	self.lw_topic = topic
	self.lw_msg = msg
	self.lw_qos = qos
	self.lw_retain = retain

func connect_to_server(clean_session=true):

	self.client = StreamPeerTCP.new()
	self.client.set_no_delay(true)
	self.client.set_big_endian(true)
	self.client.connect_to_host(self.server, self.port)
#	if self.ssl:
#		import ussl
#		self.sock = ussl.wrap_socket(self.sock, **self.ssl_params)
	
	# I don't think this test works...
	while not self.client.is_connected_to_host():
		pass
	# todo: Add in a timeout
	while self.client.get_status() != StreamPeerTCP.STATUS_CONNECTED:
		pass
	print("Connected to server")
		
	# May need a little delay after connecting to the server ?
	
	var msg = PoolByteArray()
	# Must be an easier way of doing this...
	msg.append(0x10);
	msg.append(0x00);
	msg.append(0x00);
	msg.append(0x04);
	msg.append_array("MQTT".to_ascii());
	msg.append(0x04);
	msg.append(0x02);
	msg.append(0x00);
	msg.append(0x00);

	msg[1] = 10 + 2 + len(self.client_id)
	msg[9] = (1<<1) if clean_session else 0
	if self.user != null:
		msg[1] += 2 + len(self.user) + 2 + len(self.pswd)
		msg[9] |= 0xC0
	if self.keepalive:
		assert(self.keepalive < 65536)
		msg[10] |= self.keepalive >> 8
		msg[11] |= self.keepalive & 0x00FF
	if self.lw_topic:
		msg[1] += 2 + len(self.lw_topic) + 2 + len(self.lw_msg)
		msg[9] |= 0x4 | (self.lw_qos & 0x1) << 3 | (self.lw_qos & 0x2) << 3
		msg[9] |= 1<<5 if self.lw_retain else 0

	msg.append(self.client_id.length() >> 8)
	msg.append(self.client_id.length() & 0xFF)
	msg.append_array(self.client_id.to_ascii())
	if self.lw_topic:
		msg.append_array(self.lw_topic.to_ascii())
		msg.append_array(self.lw_msg.to_ascii())
	if self.user != null:
		msg.append(self.user.length() >> 8)
		msg.append(self.user.length() & 0xFF)
		msg.append_array(self.user.to_ascii())
		msg.append(self.pswd.length() >> 8)
		msg.append(self.pswd.length() & 0xFF)
		msg.append_array(self.pswd.to_ascii())
	self.client.put_data(msg)
	
	var ret = self.client.get_data(4)
	var error = ret[0]
	assert(error == 0)
	var data = ret[1]
	assert(data[0] == 0x20 and data[1] == 0x02)
	if data[3] != 0:
		push_error(data[3])

	# Setup timer to check for incoming messages
	_timer = Timer.new()
	add_child(_timer)

	_timer.connect("timeout", self, "_on_Timer_timeout")
	_timer.set_wait_time(1.0)
	_timer.set_one_shot(false) # Make sure it loops
	_timer.start()

	return data[2] & 1

func disconnect_from_server():
	self.client.put_u16(0xE000)
	self.client.disconnect_from_host()
	_timer.stop()
	
func ping():
	self.client.put_u16(0xC000)

func publish(topic, msg, retain=false, qos=0):

	var pkt = PoolByteArray()
	# Must be an easier way of doing this...
	pkt.append(0x30);
	pkt.append(0x00);

	pkt[0] |= ((1<<1) if qos else 0) | (1 if retain else 0)
	var sz = 2 + len(topic) + len(msg)
	if qos > 0:
		sz += 2
	assert(sz < 2097152)
	var i = 1
	while sz > 0x7f:
		pkt[i] = (sz & 0x7f) | 0x80
		sz >>= 7
		i += 1
	pkt[i] = sz
	
	pkt.append(topic.length() >> 8)
	pkt.append(topic.length() & 0xFF)
	pkt.append_array(topic.to_ascii())

	if qos > 0:
		self.pid += 1
		pkt.append(self.pid >> 8)
		pkt.append(self.pid & 0xFF)

	pkt.append_array(msg.to_ascii())
	
	self.client.put_data(pkt)
	
	if qos == 1:
		while 1:
			var op = self.wait_msg()
			if op == 0x40:
				sz = self.client.get_u8()
				assert(sz == 0x02)
				var rcv_pid = self.client.get_u16()
				if self.pid == rcv_pid:
					return
	elif qos == 2:
		assert(0)

func subscribe(topic, qos=0):
	self.pid += 1

	var msg = PoolByteArray()
	# Must be an easier way of doing this...
	msg.append(0x82);
	var length = 2 + 2 + topic.length() + 1
	msg.append(length)
	msg.append(self.pid >> 8)
	msg.append(self.pid & 0xFF)
	msg.append(topic.length() >> 8)
	msg.append(topic.length() & 0xFF)
	msg.append_array(topic.to_ascii())
	msg.append(qos);
	
	self.client.put_data(msg)
	
	while 1:
		var op = self.wait_msg()
		if op == 0x90:
			var ret = self.client.get_data(4)
			var error = ret[0]
			assert(error == 0)
			var data = ret[1]
			assert(data[1] == (self.pid >> 8)  and data[2] == (self.pid & 0x0F))
			if data[3] == 0x80:
				push_error(data[3])
			return

# Wait for a single incoming MQTT message and process it.
# Subscribed messages are delivered to a callback previously
# set by .set_callback() method. Other (internal) MQTT
# messages processed internally.
func wait_msg():
	
	if(self.client == null):
		return
		
	if(!self.client.is_connected_to_host()):
		return
		
	if(self.client.get_available_bytes() <= 0):
		return
		
	var res = self.client.get_u8()
#	self.sock.setblocking(True)
	if res == null:
		return null
	if res == 0:
		push_error("-1")
	if res == 0xD0:  # PINGRESP
		var sz = self.client.get_u8()
		assert(sz == 0)
		return null
	var op = res
	if op & 0xf0 != 0x30:
		return op
	var sz = _recv_len()
	var topic_len = self.client.get_u16()
	var ret = self.client.get_data(topic_len)
	var error = ret[0]
	assert(error == 0)
	var topic = ret[1].get_string_from_ascii()
	sz -= topic_len + 2
	if op & 6:
		var pid = self.sock.get_u16()
		sz -= 2
	ret  = self.client.get_data(sz)
	error = ret[0]
	assert(error == 0)
	# warn: May not want to convert payload as ascii
	var msg = ret[1].get_string_from_ascii()
	
	emit_signal("received_message", topic, msg)
	
#	self.cb(topic, msg)
	if op & 6 == 2:
		var pkt = PoolByteArray()
		# Must be an easier way of doing this...
		pkt.append(0x40);
		pkt.append(0x02);
		pkt.append(0x00);
		pkt.append(0x00);
#		struct.pack_into("!H", pkt, 2, pid)
#		self.sock.write(pkt)
	elif op & 6 == 4:
		assert(0)

# Checks whether a pending message from server is available.
# If not, returns immediately with None. Otherwise, does
# the same processing as wait_msg.
func check_msg():
#	self.sock.setblocking(false)
	return self.wait_msg()

func _on_Timer_timeout():
	check_msg()
