class_name Polynets

class sd0class:
	static func sd0(a, b):
		return a[0] < b[0]

static func isinnerpoly(poly, nodepoints):
	var jbl = 0
	var ptbl = nodepoints[poly[jbl]]
	for j in range(1, len(poly)):
		var pt = nodepoints[poly[j]]
		if pt.y < ptbl.y or (pt.y == ptbl.y and pt.x < ptbl.x):
			jbl = j
			ptbl = pt
	var ptblFore = nodepoints[poly[(jbl+1)%len(poly)]]
	var ptblBack = nodepoints[poly[(jbl+len(poly)-1)%len(poly)]]
	var angFore = Vector2(ptblFore.x-ptbl.x, ptblFore.y-ptbl.y).angle()
	var angBack = Vector2(ptblBack.x-ptbl.x, ptblBack.y-ptbl.y).angle()
	return (angBack < angFore)

static func makexcdpolys(nodepoints, onepathpairs):
	var Lpathvectorseq = { } 
	for i in nodepoints.keys():
		Lpathvectorseq[i] = [ ]  # [ (arg, pathindex) ]
	var Npaths = len(onepathpairs)/2
	var opvisits2 = [ ]
	for i in range(Npaths):
		var i0 = onepathpairs[i*2]
		var i1 = onepathpairs[i*2+1]
		if i0 != i1:
			var vec3 = nodepoints[i1] - nodepoints[i0]
			var vec = Vector2(vec3.x, vec3.y)
			Lpathvectorseq[i0].append([vec.angle(), i])
			Lpathvectorseq[i1].append([(-vec).angle(), i])
			opvisits2.append(0)
			opvisits2.append(0)
		else:
			print("Suppressing loop edge in onepathpairs (how did it get here?) polynet function would fail as it relies on orientation")
			opvisits2.append(-1)
			opvisits2.append(-1)
		
	for pathvectorseq in Lpathvectorseq.values():
		pathvectorseq.sort_custom(sd0class, "sd0")
		
	var polys = [ ]
	var linearpaths = [ ]
	var outerpoly = null
	assert (len(opvisits2) == len(onepathpairs))
	for i in range(len(opvisits2)):
		if opvisits2[i] != 0:
			continue
		var ne = int(i/2)
		var np = onepathpairs[ne*2 + (0 if ((i%2)==0) else 1)]
		var poly = [ ]
		var singlenodeindexes = [ ]
		var hasnondoublenodes = false
		while (opvisits2[ne*2 + (0 if onepathpairs[ne*2] == np else 1)]) == 0:
			opvisits2[ne*2 + (0 if onepathpairs[ne*2] == np else 1)] = len(polys)+1
			poly.append(np)
			np = onepathpairs[ne*2 + (1  if onepathpairs[ne*2] == np  else 0)]
			if len(Lpathvectorseq[np]) == 1:
				singlenodeindexes.append(len(poly))
			elif len(Lpathvectorseq[np]) != 2:
				hasnondoublenodes = true
			for j in range(len(Lpathvectorseq[np])):
				if Lpathvectorseq[np][j][1] == ne:
					ne = Lpathvectorseq[np][(j+1)%len(Lpathvectorseq[np])][1]
					break
		
		# find and record the orientation of the polygon by looking at the bottom left
		if len(poly) == 0:
			print("bad poly size 0")
			continue
			
		if len(singlenodeindexes) == 0:
			if not isinnerpoly(poly, nodepoints):
				if outerpoly != null:
					print(" *** extra outer poly ", outerpoly, poly)
					polys.append(outerpoly) 
				outerpoly = poly
			else:
				polys.append(poly)
		if len(singlenodeindexes) == 2 and not hasnondoublenodes:
			var linearpath
			if singlenodeindexes[1] != len(poly):
				linearpath = poly.slice(singlenodeindexes[0], singlenodeindexes[1])
			else:	
				linearpath = poly.slice(0, singlenodeindexes[0])
			if isinnerpoly(linearpath, nodepoints):
				linearpath.invert()
			linearpaths.append(linearpath)
			
	if len(polys) != 0:
		polys.append(outerpoly if outerpoly != null else [])
		return polys
	if len(linearpaths) == 1:
		return linearpaths
	return [ ]


static func makeropenodesequences(nodepoints, onepathpairs, oddropeverts):
	var Lpathvectorseq = { } 
	for ii in nodepoints.keys():
		Lpathvectorseq[ii] = [ ]
	var Npaths = len(onepathpairs)/2
	var opvisits = [ ]
	for j in range(Npaths):
		var i0 = onepathpairs[j*2]
		var i1 = onepathpairs[j*2+1]
		Lpathvectorseq[i0].append(j)
		Lpathvectorseq[i1].append(j)
		opvisits.append(0)

	if oddropeverts != null:
		oddropeverts.clear()
		for ii in nodepoints.keys():
			if (len(Lpathvectorseq[ii])%2) == 1:
				oddropeverts.push_back(ii)
	
	var ropesequences = [ ]
	for j in range(Npaths):
		if opvisits[j] != 0:
			continue
		opvisits[j] = len(ropesequences)+1
		var ropeseq = [ onepathpairs[j*2], onepathpairs[j*2+1] ]
		var j1 = j
		while true:
			var i1 = ropeseq[-1]
			if len(Lpathvectorseq[i1]) != 2:
				break
			if i1[0] == "a":
				break
			assert (Lpathvectorseq[i1].has(j1))
			j1 = Lpathvectorseq[i1][1] if Lpathvectorseq[i1][0] == j1 else Lpathvectorseq[i1][0]
			if opvisits[j1] != 0:
				assert (opvisits[j1] == len(ropesequences)+1)
				break
			opvisits[j1] = len(ropesequences)+1
			assert ((i1 == onepathpairs[j1*2]) or (i1 == onepathpairs[j1*2+1]))
			ropeseq.append(onepathpairs[j1*2+1] if (i1 == onepathpairs[j1*2]) else onepathpairs[j1*2])
		ropeseq.invert()
		j1 = j
		while true:
			var i1 = ropeseq[-1]
			if len(Lpathvectorseq[i1]) != 2:
				break
			if i1[0] == "a":
				break
			assert (Lpathvectorseq[i1].has(j1))
			j1 = Lpathvectorseq[i1][1] if Lpathvectorseq[i1][0] == j1 else Lpathvectorseq[i1][0]
			if opvisits[j1] != 0:
				assert (opvisits[j1] == len(ropesequences)+1)
				assert (false)
				break
			opvisits[j1] = len(ropesequences)+1
			assert ((i1 == onepathpairs[j1*2]) or (i1 == onepathpairs[j1*2+1]))
			ropeseq.append(onepathpairs[j1*2+1] if (i1 == onepathpairs[j1*2]) else onepathpairs[j1*2])
		if len(ropeseq) >= 2:
			if ropeseq[-1][0] == "a":
				ropeseq.invert()
			elif len(Lpathvectorseq[ropeseq[0]]) == 1:
				ropeseq.invert()
			ropesequences.append(ropeseq)
	return ropesequences

static func triangulatepolygon(poly):
	var surfaceTool = SurfaceTool.new()
	surfaceTool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pv = PoolVector2Array()
	for p in poly:
		pv.append(Vector2(p.x, p.y))
	var pi = Geometry.triangulate_polygon(pv)
	for u in pi:
		surfaceTool.add_uv(Vector2(poly[u].x, poly[u].z))
		surfaceTool.add_vertex(poly[u])
	surfaceTool.generate_normals()
	return surfaceTool.commit()



static func stalfromropenodesequences(nodepoints, ropeseqs):
	if len(ropeseqs) == 1:
		var ropeseq = ropeseqs[0]
		if ropeseq[0] == ropeseq[-1]:
			return null
		if ropeseq[0][0] != "a" or ropeseq[-1][0] != "a":
			return null
		if len(ropeseq) <= 3:
			return null
		var ylo = min(nodepoints[ropeseq[0]].y, nodepoints[ropeseq[-1]].y)
		var yhi = max(nodepoints[ropeseq[0]].y, nodepoints[ropeseq[-1]].y)
		var iext = -1
		for i in range(1, len(ropeseq)-1):
			if nodepoints[ropeseq[i]].y < ylo:
				ylo = nodepoints[ropeseq[i]].y
				iext = i
			if nodepoints[ropeseq[i]].y > yhi:
				yhi = nodepoints[ropeseq[i]].y
				iext = i
		if iext != 1 and iext != len(ropeseq) - 2:
			return null
		ropeseqs.pop_back()
		ropeseqs.push_back(ropeseq.slice(0, iext))
		ropeseqs.push_back(ropeseq.slice(iext, len(ropeseq)-1))
	elif len(ropeseqs) != 2:
		return null
		
	if len(ropeseqs[1]) != 2:
		ropeseqs.invert()
	if len(ropeseqs[1]) != 2:
		return null
	if ropeseqs[0][-1][0] == "a":
		ropeseqs[0].invert()
	if ropeseqs[1][-1][0] == "a":
		ropeseqs[1].invert()
	
	var stalseq = [ ]
	for r in ropeseqs[0]:
		stalseq.push_back(nodepoints[r])
	var ax0 = nodepoints[ropeseqs[1][0]]
	var ax1 = nodepoints[ropeseqs[1][1]]
	var vec = ax0 - ax1
	if vec.dot(stalseq[-1] - stalseq[0]) > 0:
		vec = -vec
	var nohideaxisnodes = [ ropeseqs[1][0] ]
	if ropeseqs[1][1][0] == "a":
		nohideaxisnodes.push_back(ropeseqs[1][1])
	return [stalseq, ax1, vec, nohideaxisnodes]
	
	
	
static func oppositenode(nodename, ropeseq):
	return ropeseq[-1 if (ropeseq[0] == nodename) else 0]
static func swaparrindexes(arr, i, j):
	var b = arr[i]
	arr[i] = arr[j]
	arr[j] = b
static func cuboidfacseq(nodename, ropeseqs, ropeseqqs):
	var cseq = [ ]
	for re in ropeseqqs:
		var ropeseq = ropeseqs[re]
		if ropeseq[0] == nodename:
			cseq += ropeseq.slice(0, len(ropeseq)-2)
			nodename = ropeseq[-1]
		else:
			assert (ropeseq[-1] == nodename)
			cseq += ropeseq.slice(len(ropeseq)-1, 1, -1)
			nodename = ropeseq[0]
	return cseq

static func cuboidfromropenodesequences(nodepoints, ropeseqs):
	if len(ropeseqs) != 12:
		return null
	var ropeseqends = { } 
	for j in range(len(ropeseqs)):
		var e0 = ropeseqs[j][0]
		var e1 = ropeseqs[j][-1]
		if ropeseqends.has(e0):
			ropeseqends[e0].push_back(j)
		else:
			ropeseqends[e0] = [ j ]
		if ropeseqends.has(e1):
			ropeseqends[e1].push_back(j)
		else:
			ropeseqends[e1] = [ j ]
	if len(ropeseqends) != 8:
		return null
		
	var topnode = null
	for nodename in ropeseqends.keys():
		if len(ropeseqends[nodename]) != 3:
			return null
		if topnode == null or (nodepoints[nodename].y > nodepoints[topnode].y):
			topnode = nodename

	var secondseqq = [ ]
	for j in ropeseqends[topnode]:
		var secondseqqj = [ j ]
		var jo = oppositenode(topnode, ropeseqs[j])
		secondseqqj.push_back(jo)
		for je in ropeseqends[jo]:
			var jeo = oppositenode(jo, ropeseqs[je])
			if jeo != topnode:
				secondseqqj.push_back(je)
				secondseqqj.push_back(jeo)
		assert (len(secondseqqj) == 6)
		secondseqq.push_back(secondseqqj)
		
	if secondseqq[1][5] == secondseqq[0][3] or secondseqq[1][5] == secondseqq[0][5]:
		swaparrindexes(secondseqq[1], 2, 4)
		swaparrindexes(secondseqq[1], 3, 5)
	if secondseqq[0][3] == secondseqq[1][3]:
		swaparrindexes(secondseqq[0], 2, 4)
		swaparrindexes(secondseqq[0], 3, 5)
	if secondseqq[1][5] == secondseqq[2][5]:
		swaparrindexes(secondseqq[2], 2, 4)
		swaparrindexes(secondseqq[2], 3, 5)
	for k in range(3):
		var sn = secondseqq[k][5]
		if sn != secondseqq[(k+1)%3][3]:
			return null
		var sne = secondseqq[k][4]
		var sne1 = secondseqq[(k+1)%3][2]
		for je in range(3):
			if ropeseqends[sn][je] != sne and ropeseqends[sn][je] != sne1:
				secondseqq[k].push_back(ropeseqends[sn][je])
				secondseqq[k].push_back(oppositenode(sn, ropeseqs[ropeseqends[sn][je]]))
		assert (len(secondseqq[k]) == 8)
		assert (k == 0 or secondseqq[k][-1] == secondseqq[k-1][-1])

	var cuboidfacs = [ ]
	for k in range(3):
		cuboidfacs.push_back(cuboidfacseq(topnode, ropeseqs, [secondseqq[k][0], secondseqq[k][4], secondseqq[(k+1)%3][2], secondseqq[(k+1)%3][0]]))
		cuboidfacs.push_back(cuboidfacseq(secondseqq[k][1], ropeseqs, [secondseqq[k][2], secondseqq[(k+2)%3][6], secondseqq[k][6], secondseqq[k][4]]))
	return cuboidfacs
	
static func triangledistortionmeasure(p0, p1, p2, f0, f1, f2):
	var parea = 0.5*(p1 - p0).cross(p2 - p0).length()
	var farea = 0.5*(f1 - f0).cross(f2 - f0)
	var areachange = farea/parea
	var u = clamp((areachange - 0.5), 0.001, 0.999)
	#print(u, " ", parea, " ", farea)
	return Vector2(u, 0.001)
