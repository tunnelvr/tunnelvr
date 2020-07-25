extends Resource

# This is the class that holds the raw data for a cave environment
# and must be synced with the VR objects in some way
# It is also used for loading and saving and generating derived stuff, like surfaces
# and it can be used for communication -- syncronizing stuff across the network

onready var OneTube = load("res://OneTube.gd")

var nodepoints 		 : = PoolVector3Array() 
var onepathpairs 	 : = PoolIntArray()  # 2* pairs indexing into nodepoints

# drawnstations should be made part of the centreline, in truth -- can we backport them into that data?
var drawnstationnodesRAW = [ ]  # temporary case till we know what to do


func _ready():
	pass # Replace with function body

func newotnodepoint():
	nodepoints.push_back(Vector3())
	return len(nodepoints) - 1

func removeotnodepoint(i):
	var e = len(nodepoints) - 1

	nodepoints[i] = nodepoints[e]


	nodepoints.resize(e)

	for j in range(len(onepathpairs) - 2, -1, -2):
		if (onepathpairs[j] == i) or (onepathpairs[j+1] == i):
			onepathpairs[j] = onepathpairs[-2]
			onepathpairs[j+1] = onepathpairs[-1]
			onepathpairs.resize(len(onepathpairs) - 2)
		else:
			if onepathpairs[j] == e:
				onepathpairs[j] = i
			if onepathpairs[j+1] == e:
				onepathpairs[j+1] = i
	return i != e
	
func copyopntootnode(opn):
	nodepoints[opn.otIndex] = opn.global_transform.origin

func copyotnodetoopn(opn):
	opn.global_transform.origin = nodepoints[opn.otIndex]
	opn.scale.y = opn.global_transform.origin.y

func applyonepath(i0, i1):
	for j in range(len(onepathpairs)-2, -3, -2):
		if j == -2:
			print("addingonepath ", len(onepathpairs))
			onepathpairs.push_back(i0)
			onepathpairs.push_back(i1)
		elif (onepathpairs[j] == i0 and onepathpairs[j+1] == i1) or (onepathpairs[j] == i1 and onepathpairs[j+1] == i0):
			onepathpairs[j] = onepathpairs[-2]
			onepathpairs[j+1] = onepathpairs[-1]
			onepathpairs.resize(len(onepathpairs) - 2)
			print("deletedonepath ", j)
			break


func unflattenpoolvector3(r):
	var v = PoolVector3Array()
	for i in range(2, len(r), 3):
		v.append(Vector3(r[i-2], r[i-1], r[i]))
	return v

func unflattenpoolvector2(r):
	var v = PoolVector2Array()
	for i in range(1, len(r), 2):
		v.append(Vector2(r[i-1], r[i]))
	return v

func loadonetunnel(fname):
	var save_game = File.new()
	save_game.open(fname, File.READ)
	var node_data = parse_json(save_game.get_line())
	nodepoints = unflattenpoolvector3(node_data["nodepoints"])
	print("nnnnnn", nodepoints)
	onepathpairs = node_data["onepathpairs"]
	drawnstationnodesRAW = node_data["drawnstationnodes"]
	save_game.close()

func flattenpoolvector3(v):
	var r = PoolRealArray()
	for p in v:
		r.append_array([p.x, p.y, p.z])
	return r

func flattenpoolvector2(v):
	var r = PoolRealArray()
	for p in v:
		r.append_array([p.x, p.y])
	return r
	
func saveonetunnel(fname):
	var save_dict = { "nodepoints":flattenpoolvector3(nodepoints), 
					  "onepathpairs":onepathpairs,
					  "drawnstationnodes":drawnstationnodesRAW }
	var save_game = File.new()
	save_game.open(fname, File.WRITE)
	save_game.store_line(to_json(save_dict))
	save_game.close()


func verifyonetunnelmatches(sketchsystem):
	var N = len(nodepoints)
	var onepathnodes = sketchsystem.get_node("OnePathNodes").get_children()
	assert(N == len(onepathnodes))
	for i in range(N):
		var opn = onepathnodes[i]
		assert (opn.otIndex == i)
		print(i, opn.global_transform.origin, nodepoints[i])
		assert (opn.global_transform.origin == nodepoints[i])
	return true


