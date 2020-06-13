extends Resource

# This is the class that holds the raw data for a cave environment
# and must be synced with the VR objects in some way
# It is also used for loading and saving and generating derived stuff, like surfaces
# and it can be used for communication -- syncronizing stuff across the network

# 
var nodepoints 		 : = PoolVector3Array() 
var nodedrawingindex : = PoolIntArray() 
var nodeuvs 		 : = PoolVector2Array()
var nodewallangle 	 : = PoolRealArray() 
var nodeinwardvec 	 : = PoolVector3Array() 

var onepathpairs 	 : = PoolIntArray()  # 2* pairs indexing into nodepoints


# indexed by nodedrawing; use a PoolStringArray?:
var drawingnames = [ "res://surveyscans/DukeStResurvey-drawnup-p3.jpg" ]  

# drawnstations should be made part of the centreline, in truth -- can we backport them into that data?
var drawnstationnodesRAW = [ ]  # temporary case till we know what to do


func _ready():
	pass # Replace with function body

func newotnodepoint():
	nodepoints.push_back(Vector3())
	nodedrawingindex.push_back(0)
	nodeuvs.push_back(Vector2())
	nodewallangle.push_back(0)
	nodeinwardvec.push_back(Vector3())
	return len(nodepoints) - 1

func removeotnodepoint(i):
	var e = len(nodepoints) - 1

	nodepoints[i] = nodepoints[e]
	nodedrawingindex[i] = nodedrawingindex[e]
	nodeuvs[i] = nodeuvs[e]
	nodewallangle[i] = nodewallangle[e]
	nodeinwardvec[i] = nodeinwardvec[e]

	nodepoints.resize(e)
	nodedrawingindex.resize(e)
	nodeuvs.resize(e)
	nodewallangle.resize(e)
	nodeinwardvec.resize(e)

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
	nodedrawingindex[opn.otIndex] = 0
	nodeuvs[opn.otIndex] = opn.uvpoint
	nodewallangle[opn.otIndex] = opn.wallangle

func copyotnodetoopn(opn):
	opn.global_transform.origin = nodepoints[opn.otIndex]
	nodedrawingindex[opn.otIndex] = 0
	opn.drawingname = drawingnames[nodedrawingindex[opn.otIndex]]
	opn.uvpoint = nodeuvs[opn.otIndex] 
	opn.wallangle = nodewallangle[opn.otIndex]
	opn.scale.y = opn.global_transform.origin.y if opn.wallangle == 0.0 else 0.2

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
	drawingnames = node_data["drawingnames"]
	nodedrawingindex = node_data["nodedrawingindex"]
	nodeuvs = unflattenpoolvector2(node_data["nodeuvs"])
	nodewallangle = node_data["nodewallangle"]
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
					  "nodedrawingindex":nodedrawingindex, 
					  "drawingnames":drawingnames,
					  "nodeuvs":flattenpoolvector2(nodeuvs),
					  "nodewallangle":nodewallangle,
					  "onepathpairs":onepathpairs,
					  "drawnstationnodes":drawnstationnodesRAW }
	var save_game = File.new()
	save_game.open(fname, File.WRITE)
	save_game.store_line(to_json(save_dict))
	save_game.close()


func verifyonetunnelmatches(sketchsystem):
	var N = len(nodepoints)
	assert ((N == len(nodeuvs)) and (N == len(nodedrawingindex)) and (N == len(nodedrawingindex)) and (N == len(nodeinwardvec)) and (N == len(nodewallangle)))
	var onepathnodes = sketchsystem.get_node("OnePathNodes").get_children()
	assert(N == len(onepathnodes))
	for i in range(N):
		var opn = onepathnodes[i]
		assert (opn.otIndex == i)
		print(i, opn.global_transform.origin, nodepoints[i])
		assert (opn.global_transform.origin == nodepoints[i])
		assert (opn.drawingname == drawingnames[nodedrawingindex[i]])
		assert (opn.uvpoint == nodeuvs[i])
	return true


func sd0(a, b):
	return a[0] < b[0]
	
func makeworkingshell():
	var Npaths = len(onepathpairs)/2

	var Lpathvectorseq = [ ] 
	for i in range(len(nodepoints)):
		Lpathvectorseq.append([])  # [ (arg, pathindex) ]
	
	var opvisits2 = [ ]
	for i in range(Npaths):
		var i0 = onepathpairs[i*2]
		var i1 = onepathpairs[i*2+1]
		var vec3 = nodepoints[i1] - nodepoints[i0]
		var vec = Vector2(vec3.x, vec3.z)
		Lpathvectorseq[i0].append([vec.angle(), i])
		Lpathvectorseq[i1].append([(-vec).angle(), i])
		opvisits2.append(0)
		opvisits2.append(0)
	for pathvectorseq in Lpathvectorseq:
		pathvectorseq.sort_custom(self, "sd0")
		print(pathvectorseq)
		
	var polys = [ ]
	for i in range(len(opvisits2)):
		if opvisits2[i] != 0:
			continue
		# warning-ignore:integer_division
		var ne = (i/2)
		print("iiii", i)
		var np = onepathpairs[ne*2 + (0 if ((i%2)==0) else 1)]
		polys.append([ ])
		while (opvisits2[ne*2 + (0 if onepathpairs[ne*2] == np else 1)]) == 0:
			opvisits2[ne*2 + (0 if onepathpairs[ne*2] == np else 1)] = len(polys)
			#polys[-1].append(Vector3(np.global_transform.origin.x, np.scale.y, np.global_transform.origin.z))
			polys[-1].append(np)
			np = onepathpairs[ne*2 + (1  if onepathpairs[ne*2] == np  else 0)]
			for j in range(len(Lpathvectorseq[np])):
				if Lpathvectorseq[np][j][1] == ne:
					ne = Lpathvectorseq[np][(j+1)%len(Lpathvectorseq[np])][1]
					break
		print("pppp ", len(polys[-1]), " ", polys[-1][0])

	var surfaceTool = SurfaceTool.new()
	surfaceTool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for poly in polys:
		var pv = PoolVector2Array()
		for p in poly:
			pv.append(Vector2(nodepoints[p].x, nodepoints[p].z))
		var pi = Geometry.triangulate_polygon(pv)
		print("piiii", pi)
		for u in pi:
			surfaceTool.add_uv(nodeuvs[poly[u]])
			surfaceTool.add_vertex(nodepoints[poly[u]])
	surfaceTool.generate_normals()
	return surfaceTool.commit()

