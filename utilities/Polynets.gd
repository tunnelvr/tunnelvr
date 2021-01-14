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

static func makeropenodesequences(nodepoints, onepathpairs, oddropeverts=null):
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
