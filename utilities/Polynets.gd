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


static func makexcdpolysDict(nodepoints, onepathpairs):
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
		
	var polysdict = { }
	var linearpaths = [ ]
	var outerpoly = null
	
	assert (len(opvisits2) == len(onepathpairs))
	var npoly = 0
	for i in range(len(opvisits2)):
		if opvisits2[i] != 0:
			continue
		var ne = int(i/2)
		var np = onepathpairs[ne*2 + (0 if ((i%2)==0) else 1)]
		var poly = [ ]
		var singlenodeindexes = [ ]
		var hasnondoublenodes = false
		while (opvisits2[ne*2 + (0 if onepathpairs[ne*2] == np else 1)]) == 0:
			npoly += 1
			opvisits2[ne*2 + (0 if onepathpairs[ne*2] == np else 1)] = npoly
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
			
		if len(singlenodeindexes) == 2 and not hasnondoublenodes:
			var linearpath
			if singlenodeindexes[1] != len(poly):
				linearpath = poly.slice(singlenodeindexes[0], singlenodeindexes[1])
			else:	
				linearpath = poly.slice(0, singlenodeindexes[0])
			if not isinnerpoly(linearpath, nodepoints):
				linearpath.invert()
			linearpaths.append(linearpath)
			continue

		var polyname = "u_%d" % len(polysdict)
		if len(singlenodeindexes) == 1 and hasnondoublenodes:
			var ii = singlenodeindexes.pop_at(0)
			var iip1 = 0 if ii == len(poly)-1 else ii+1
			var iim1 = len(poly)-1 if ii == 0 else ii-1
			if poly[iip1] == poly[iim1]:
				polyname = poly[ii]
				if ii != 0:
					poly.remove(ii)
					poly.remove(ii-1)
				else:
					poly.remove(1)
					poly.remove(0)
			
		if len(singlenodeindexes) == 0:
			if not isinnerpoly(poly, nodepoints):
				if outerpoly != null:
					print(" *** extra outer poly ", outerpoly, poly)
					polysdict[polyname] = outerpoly 
				outerpoly = poly
			else:
				polysdict[polyname] = poly
			
	if len(polysdict) != 0:
		if outerpoly != null:
			polysdict["outerpoly"] = outerpoly
		return polysdict
	if len(linearpaths) == 1:
		return { "linearpath":linearpaths[0] }
	return { }


static func makexcdpolys(nodepoints, onepathpairs):
	var polysdict = makexcdpolysDict(nodepoints, onepathpairs)
	if len(polysdict) == 0:
		return [ ]
	if polysdict.has("linearpath"):
		return [ polysdict["linearpath"] ]
	var outerpoly = polysdict.get("outerpoly", [ ])
	polysdict.erase("outerpoly")
	var polys = [ ]
	for k in polysdict:
		if k.begins_with("u_"):
			polys.append(polysdict[k])
	polys.append(outerpoly)
	return polys
		

static func makeropenodesequences(nodepoints, onepathpairs, oddropeverts, anchorropeverts, suppresswallnodeson8):
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

	var breaksequenceatwallnodes = true
	if oddropeverts != null:
		oddropeverts.clear()
		anchorropeverts.clear()
		for ii in nodepoints.keys():
			if (len(Lpathvectorseq[ii])%2) == 1:
				oddropeverts.push_back(ii)
			if ii[0] == "a":
				anchorropeverts.push_back(ii)
		breaksequenceatwallnodes = not (suppresswallnodeson8 and len(oddropeverts) >= 8)
		
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
			if breaksequenceatwallnodes and i1[0] == "a":
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
			if breaksequenceatwallnodes and i1[0] == "a":
				break
			assert (Lpathvectorseq[i1].has(j1))
			j1 = Lpathvectorseq[i1][1] if Lpathvectorseq[i1][0] == j1 else Lpathvectorseq[i1][0]
			if opvisits[j1] != 0:
				assert (opvisits[j1] == len(ropesequences)+1)
				print("ropehang loop detected")
				break
			opvisits[j1] = len(ropesequences)+1
			assert ((i1 == onepathpairs[j1*2]) or (i1 == onepathpairs[j1*2+1]))
			ropeseq.append(onepathpairs[j1*2+1] if (i1 == onepathpairs[j1*2]) else onepathpairs[j1*2])
		if len(ropeseq) >= 2:
			if breaksequenceatwallnodes and ropeseq[-1][0] == "a":
				ropeseq.invert()
			elif breaksequenceatwallnodes and ropeseq[0][0] == "a" and ropeseq[-1][0] != "a":
				pass
			elif len(Lpathvectorseq[ropeseq[0]]) == 1:
				ropeseq.invert()
			ropesequences.append(ropeseq)
	return ropesequences


static func ropeseqsfindsplitatnode(ropeseqs, nodename):
	var ropeseqssplit = [ ]
	for ropeseq in ropeseqs:
		var i = ropeseq.find(nodename)
		if i == 0:
			ropeseqssplit.push_back(ropeseq)
		elif i == len(ropeseq) - 1:
			ropeseq.invert()
			ropeseqssplit.push_back(ropeseq)
		elif i != -1:
			ropeseqssplit.push_back(ropeseq.slice(0, i))
			ropeseqssplit[-1].invert()
			ropeseqssplit.push_back(ropeseq.slice(i, len(ropeseq)))
	return ropeseqssplit
	

static func triangulateguardianpolygon(poly):
	var surfaceTool = SurfaceTool.new()
	surfaceTool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pv = PoolVector2Array()
	for p in poly:
		pv.append(Vector2(p.x, p.z))
	var pi = Geometry.triangulate_polygon(pv)
	for u in pi:
		surfaceTool.add_uv(Vector2(poly[u].x, poly[u].z))
		surfaceTool.add_vertex(poly[u])
	surfaceTool.generate_normals()
	return surfaceTool.commit()



static func stalfromropenodesequences(nodepoints, ropeseqs):  # stalactites, stalagmites and columns
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
	if ropeseqs[1][0][0] != "a":
		return null
	if ropeseqs[0][0][0] != "a":
		return null
		
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
	
	
static func makestalshellmesh(revseq, p0, vec):
	var Nsides = max(8, int(300/(len(revseq) + 10)))
	var arraymesh = ArrayMesh.new()
	var surfaceTool = SurfaceTool.new()
	surfaceTool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var prevrevring = null
	var prevringrad = 1
	var v = 0
	for j in range(len(revseq)):
		var rp = revseq[j]
		var lam = vec.dot(rp - p0)/vec.dot(vec)
		var a = p0 + vec*lam
		var rv = rp - a
		var ringrad = rv.length()
		var rvperp = rv.cross(vec.normalized())
		var revring = [ ]
		for i in range(Nsides):
			var theta = deg2rad(i*360.0/Nsides)
			var pt = a + cos(theta)*rv + sin(theta)*rvperp
			var u = theta*(prevringrad + ringrad)*0.5
			revring.push_back(pt)
			revring.push_back(Vector2(u, v))
		if prevrevring != null:
			for i in range(Nsides):
				var i1 = (i+1)%Nsides
				surfaceTool.add_uv(prevrevring[i*2+1])
				surfaceTool.add_uv2(prevrevring[i*2+1])
				surfaceTool.add_vertex(prevrevring[i*2])
				surfaceTool.add_uv(revring[i*2+1])
				surfaceTool.add_uv2(revring[i*2+1])
				surfaceTool.add_vertex(revring[i*2])
				surfaceTool.add_uv(revring[i1*2+1])
				surfaceTool.add_uv2(revring[i1*2+1])
				surfaceTool.add_vertex(revring[i1*2])

				surfaceTool.add_uv(prevrevring[i*2+1])
				surfaceTool.add_uv2(prevrevring[i*2+1])
				surfaceTool.add_vertex(prevrevring[i*2])
				surfaceTool.add_uv(revring[i1*2+1])
				surfaceTool.add_uv2(revring[i1*2+1])
				surfaceTool.add_vertex(revring[i1*2])
				surfaceTool.add_uv(prevrevring[i1*2+1])
				surfaceTool.add_uv2(prevrevring[i1*2+1])
				surfaceTool.add_vertex(prevrevring[i1*2])
		prevrevring = revring
		prevringrad = ringrad
		v += vec.length()
	surfaceTool.generate_normals()
	surfaceTool.generate_tangents()
	surfaceTool.commit(arraymesh)
	return arraymesh

static func signpostfromropenodesequences(nodepoints, ropeseqs, flagsignlabels):
	if len(ropeseqs) <= 1:
		return null
		
	var ropeseqdanchoredlong = { }
	var ropeseqsanchoredshort = [ ]
	var ropeseqmiddles = [ ]
	for ropeseq in ropeseqs:
		if ropeseq[0][0] == "a":
			if len(ropeseq) > 2:
				ropeseqdanchoredlong[ropeseq[-1]] = ropeseq
			elif len(ropeseq) == 2:
				ropeseqsanchoredshort.push_back(ropeseq)
		else:
			ropeseqmiddles.push_back(ropeseq)
	if len(ropeseqsanchoredshort) != 1:
		return null
	var signpostseq = ropeseqsanchoredshort[0]

	if len(ropeseqdanchoredlong) != 0 and not flagsignlabels:
		return null
	var ropeseqstrails = [ ]
	for nodenamejoin in ropeseqdanchoredlong:
		var ropemiddlestrailendsj = [ ]
		for j in len(ropeseqmiddles):
			var ropeseqm = ropeseqmiddles[j]
			if ropeseqm[0] == nodenamejoin or ropeseqm[-1] == nodenamejoin:
				ropemiddlestrailendsj.append(j)
		if len(ropemiddlestrailendsj) != 2:
			return null
		var ropemiddle1 = ropeseqmiddles.pop_at(ropemiddlestrailendsj[1]).duplicate()
		var ropemiddle0 = ropeseqmiddles.pop_at(ropemiddlestrailendsj[0]).duplicate()
		if ropemiddle0[0] == nodenamejoin:
			ropemiddle0.invert()
		if ropemiddle1[-1] == nodenamejoin:
			ropemiddle1.invert()
		ropemiddle0.pop_back()
		ropemiddle0.append_array(ropemiddle1)
		ropeseqmiddles.push_back(ropemiddle0)

	var vss = nodepoints[signpostseq[1]] - nodepoints[signpostseq[0]]
	var vssa = rad2deg(Vector2(vss.y, Vector2(vss.x, vss.z).length()).angle())
	var signdownwards = (vssa > 90)
	if (180-vssa if signdownwards else vssa) > 45:
		return null
	
	var ptsignroot = nodepoints[signpostseq[0]]
	var ptsigntopy = nodepoints[signpostseq[1]].y
	var flagpolys = [ ]
	
	if len(ropeseqmiddles) == 1:
		var flagseq = ropeseqmiddles[0]
		if len(flagseq) < 4:
			return null
		if flagseq[0] != flagseq[-1]:
			return null
		var vs0 = nodepoints[flagseq[1]] - nodepoints[flagseq[0]]
		var vs1 = nodepoints[flagseq[-2]] - nodepoints[flagseq[-1]]
		var vs0a = rad2deg(Vector2(vs0.y, Vector2(vs0.x, vs0.z).length()).angle())
		var vs1a = rad2deg(Vector2(vs1.y, Vector2(vs1.x, vs1.z).length()).angle())
		if signdownwards:
			vs0a = 180-vs0a
			vs1a = 180-vs1a
		if vs1a < vs0a:
			flagseq.invert()
			vs0a = vs1a
		if vs0a > 45:
			return null
			
		ptsigntopy = nodepoints[flagseq[1]].y
		flagpolys.append(flagseq)
		
	elif len(ropeseqmiddles) >= 3:
		var signpostseqjtop = -1
		for j in range(len(ropeseqmiddles)):
			var ropeseq = ropeseqs[j]
			if len(ropeseq) == 2:
				if signpostseqjtop != -1:
					return null
				if ropeseq[-1] == signpostseq[1]:
					ropeseq.invert()
				if ropeseq[0] != signpostseq[1]:
					return null
				signpostseqjtop = j
		if signpostseqjtop == -1:
			return null
		var signpostseqtop = ropeseqmiddles.pop_at(signpostseqjtop)

		for ropeseq in ropeseqmiddles:
			if ropeseq[-1] == signpostseqtop[1]:
				ropeseq.invert()
			if ropeseq[0] != signpostseqtop[1] or ropeseq[-1] != signpostseqtop[0]:
				return null
			var flagseq = signpostseqtop.duplicate()
			for k in range(1, len(ropeseq)):
				flagseq.append(ropeseq[k])
			flagpolys.append(flagseq)
		ptsigntopy = nodepoints[signpostseqtop[1]].y
		
	var ptsigntop = Vector3(ptsignroot.x, ptsigntopy, ptsignroot.z)
	var flagsigns = [ ]
	var nohideaxisnodes = [ signpostseq[0] ]
	for j in range(len(flagpolys)):
		var ppoly = [ ]
		var flagmsg = ""
		var nodelabelled = null
		var flagtrail = [ ]
		for d in flagpolys[j]:
			ppoly.append(nodepoints[d])
			var flagsignlabel = flagsignlabels.get(d)
			if flagsignlabel != null and len(flagsignlabel) > len(flagmsg):
				flagmsg = flagsignlabel
				nodelabelled = d
			if ropeseqdanchoredlong.has(d):
				flagtrail = ropeseqdanchoredlong[d]
				
		var vecfurthest = ppoly[0] - ptsigntop
		var nodefurthest = flagpolys[j][0]
		for i in range(1, len(ppoly)):
			var veci = ppoly[i] - ptsigntop
			if veci.length_squared() > vecfurthest.length_squared():
				vecfurthest = veci
				nodefurthest = flagpolys[j][i]
		if nodelabelled == null:
			nodelabelled = nodefurthest
			flagmsg = "node - "+nodelabelled
		nohideaxisnodes.append(nodelabelled)

		var veciang = rad2deg(Vector2(Vector2(vecfurthest.x, vecfurthest.z).length(), vecfurthest.y).angle())
		if abs(veciang) < 40:
			vecfurthest.y = 0
		var vecletters = vecfurthest.normalized()
		var veclettersup = Vector3(0, 1, 0)
		if vecletters.y != 0:
			var vecletters2d = Vector2(vecletters.x, vecletters.z).length()
			if vecletters2d != 0.0:
				veclettersup = Vector3(-vecletters.x/vecletters2d*vecletters.y, vecletters2d, -vecletters.z/vecletters2d*vecletters.y)
			else:
				veclettersup = Vector3(1, 0, 0)
		flagsigns.append({ "flagmsg":flagmsg, 
						   "nodelabelled":nodelabelled, 
						   "vecletters":vecletters, 
						   "veclettersup":veclettersup, 
						   "flagtrail":flagtrail })

	return { "ptsignroot":ptsignroot, 
			 "ptsigntop":ptsigntopy, 
			 "flagsigns":flagsigns, 
			 "nohideaxisnodes":nohideaxisnodes }


static func makesignpostshellmesh(xcdrawing, ptsignroot, ptsigntopy, postrad):
	var Nsides = 8
	var postarraymesh = ArrayMesh.new()
	var surfaceTool = SurfaceTool.new()
	surfaceTool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var vheight = ptsigntopy - ptsignroot.y
	var ptpr = ptsignroot + Vector3(postrad, 0, 0)
	var ptpt = ptsignroot + Vector3(postrad, vheight, 0)
	var up = 0.0
	for i in range(Nsides):
		var theta = deg2rad((i+1)*360.0/Nsides)
		var vp = Vector3(cos(theta)*postrad, 0, sin(theta)*postrad) if i < Nsides-1 else Vector3(postrad, 0, 0)
		var ptnr = ptsignroot + vp
		var ptnt = ptnr + Vector3(0, vheight, 0)
		var un = theta*postrad
		
		surfaceTool.add_uv(Vector2(up, 0))
		surfaceTool.add_uv2(Vector2(up, 0))
		surfaceTool.add_vertex(ptpr)
		surfaceTool.add_uv(Vector2(un, 0))
		surfaceTool.add_uv2(Vector2(un, 0))
		surfaceTool.add_vertex(ptnr)
		surfaceTool.add_uv(Vector2(un, vheight))
		surfaceTool.add_uv2(Vector2(un, vheight))
		surfaceTool.add_vertex(ptnt)

		surfaceTool.add_uv(Vector2(up, 0))
		surfaceTool.add_uv2(Vector2(up, 0))
		surfaceTool.add_vertex(ptpr)
		surfaceTool.add_uv(Vector2(un, vheight))
		surfaceTool.add_uv2(Vector2(un, vheight))
		surfaceTool.add_vertex(ptnt)
		surfaceTool.add_uv(Vector2(up, vheight))
		surfaceTool.add_uv2(Vector2(up, vheight))
		surfaceTool.add_vertex(ptpt)

		ptpr = ptnr
		ptpt = ptnt
		up = un

	surfaceTool.generate_normals()
	surfaceTool.generate_tangents()
	surfaceTool.commit(postarraymesh)
	
	return postarraymesh


	
static func oppositenode(nodename, ropeseq):
	return ropeseq[-1 if (ropeseq[0] == nodename) else 0]
static func nextseqnode(nodename, ropeseq):
	return ropeseq[1 if (ropeseq[0] == nodename) else -2]
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

static func cuboidfacrailsseq(nodename0, ropeseqs, ropeseqqs):
	assert (len(ropeseqqs) == 4)
	var ropeseq0 = ropeseqs[ropeseqqs[0]]
	var dropeseq0 = (ropeseq0[0] == nodename0)
	var nodename1 = ropeseq0[-1] if dropeseq0 else ropeseq0[0]
	var ropeseq1 = ropeseqs[ropeseqqs[1]]
	var dropeseq1 = (ropeseq1[0] == nodename1)
	var nodename2 = ropeseq1[-1] if dropeseq1 else ropeseq1[0]
	var ropeseq2 = ropeseqs[ropeseqqs[2]]
	var dropeseq2 = (ropeseq2[0] == nodename2)
	var nodename3 = ropeseq2[-1] if dropeseq2 else ropeseq2[0]
	var ropeseq3 = ropeseqs[ropeseqqs[3]]
	var dropeseq3 = (ropeseq3[0] == nodename3)
	var nodename4 = ropeseq3[-1] if dropeseq3 else ropeseq3[0]
	assert (nodename4 == nodename0)
	if max(len(ropeseq0), len(ropeseq2)) > max(len(ropeseq1), len(ropeseq3)):
		var quadrail0 = ropeseq0.duplicate()  if dropeseq0  else ropeseq0.slice(len(ropeseq0)-1, 0, -1)
		var quadrail1 = ropeseq2.duplicate()  if not dropeseq2  else ropeseq2.slice(len(ropeseq2)-1, 0, -1)
		var railseqrung0 = ropeseq3.slice(1, len(ropeseq3)-2)  if not dropeseq3  else ropeseq3.slice(len(ropeseq3)-2, 1, -1)
		var railseqrung1 = ropeseq1.slice(1, len(ropeseq1)-2)  if dropeseq1  else ropeseq1.slice(len(ropeseq1)-2, 1, -1)
		assert (len(quadrail0) + len(quadrail1) + len(railseqrung0) + len(railseqrung1) == len(ropeseq0) + len(ropeseq1) + len(ropeseq2) + len(ropeseq3) - 4)
		return [quadrail0, quadrail1, railseqrung0, railseqrung1]
	var quadrail0 = ropeseq1.duplicate()  if dropeseq1  else ropeseq1.slice(len(ropeseq1)-1, 0, -1)
	var quadrail1 = ropeseq3.duplicate()  if not dropeseq3  else ropeseq3.slice(len(ropeseq3)-1, 0, -1)
	var railseqrung0 = ropeseq0.slice(1, len(ropeseq0)-2)  if not dropeseq0  else ropeseq0.slice(len(ropeseq0)-2, 1, -1)
	var railseqrung1 = ropeseq2.slice(1, len(ropeseq2)-2)  if dropeseq2  else ropeseq2.slice(len(ropeseq2)-2, 1, -1)
	assert (len(quadrail0) + len(quadrail1) + len(railseqrung0) + len(railseqrung1) == len(ropeseq0) + len(ropeseq1) + len(ropeseq2) + len(ropeseq3) - 4)
	return [quadrail0, quadrail1, railseqrung0, railseqrung1]
	
static func calcropeseqends(ropeseqs):
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
	return ropeseqends
	
static func cuboidfromropenodesequences(nodepoints, ropeseqs, badinvert):
	if len(ropeseqs) != 12:
		return null
	var ropeseqends = calcropeseqends(ropeseqs)
	if len(ropeseqends) != 8:
		return null
		
	var topnode = null
	for nodename in ropeseqends.keys():
		if len(ropeseqends[nodename]) != 3:
			return null
		if topnode == null or (nodepoints[nodename].y > nodepoints[topnode].y):
			topnode = nodename

	var ropeseqendsoftopnode = ropeseqends[topnode]
	var tcpn0 = nodepoints[nextseqnode(topnode, ropeseqs[ropeseqendsoftopnode[0]])]
	var tcpn1 = nodepoints[nextseqnode(topnode, ropeseqs[ropeseqendsoftopnode[1]])]
	var tcpn2 = nodepoints[nextseqnode(topnode, ropeseqs[ropeseqendsoftopnode[2]])]
	var tcpnN = ((tcpn1 - tcpn0).cross(tcpn2 - tcpn0))
	if (tcpnN.y < 0) != badinvert:
		swaparrindexes(ropeseqendsoftopnode, 1, 2)

	var secondseqq = [ ]
	for j in ropeseqendsoftopnode:
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

	var cuboidrailfacs = [ ]
	for k in range(3):
		cuboidrailfacs.push_back(cuboidfacrailsseq(topnode, ropeseqs, [secondseqq[k][0], secondseqq[k][4], secondseqq[(k+1)%3][2], secondseqq[(k+1)%3][0]]))
		cuboidrailfacs.push_back(cuboidfacrailsseq(secondseqq[k][1], ropeseqs, [secondseqq[k][2], secondseqq[(k+2)%3][6], secondseqq[k][6], secondseqq[k][4]]))
	return cuboidrailfacs
	
static func triangledistortionmeasure(p0, p1, p2, f0, f1, f2):
	var parea = 0.5*(p1 - p0).cross(p2 - p0).length()
	var farea = 0.5*(f1 - f0).cross(f2 - f0)
	var areachange = farea/parea
	var u = clamp((areachange - 0.5), 0.001, 0.999)
	#print(u, " ", parea, " ", farea)
	return Vector2(u, 0.001)




static func initialcuboidrails(nodepoints, quadrail0, quadrail1):
	var ila0N = len(quadrail0) - 1
	var ila1N = len(quadrail1) - 1
	var acc = -ila0N/2.0  if ila0N>=ila1N  else  ila1N/2
	var i0 = 0
	var i1 = 0

	var pti0 = nodepoints[quadrail0[0]]
	var pti1 = nodepoints[quadrail1[0]]
	var uvi0 = Vector2(0, 0)
	var uvi1 = Vector2(pti0.distance_to(pti1),0)

	var tuberail0 = [ [ pti0, uvi0, 0.0 ] ]
	var tuberail1 = [ [ pti1, uvi1, 0.0 ] ]
	while i0 < ila0N or i1 < ila1N:
		assert (i0 <= ila0N and i1 <= ila1N)
		if i0 < ila0N and (acc - ila0N < 0 or i1 == ila1N):
			acc += ila1N
			i0 += 1
			var pti0next = nodepoints[quadrail0[i0]]
			uvi0 = advanceuvFar(uvi1, pti1, uvi0, pti0, pti0next, true)
			pti0 = pti0next
		if i1 < ila1N and (acc >= 0 or i0 == ila0N):
			acc -= ila0N
			i1 += 1
			var pti1next = nodepoints[quadrail1[i1]]
			uvi1 = advanceuvFar(uvi0, pti0, uvi1, pti1, pti1next, false)
			pti1 = pti1next
		tuberail0.push_back([pti0, uvi0, i0*1.0/ila0N if ila0N != 0 else 1.0])
		tuberail1.push_back([pti1, uvi1, i1*1.0/ila1N if ila1N != 0 else 1.0])
	return [tuberail0, tuberail1]


static func cubeintermedrailbasis(i, tuberail0, tuberail1):
	assert (len(tuberail0) == len(tuberail1))
	var pt0 = tuberail0[i][0]
	var pt1 = tuberail1[i][0]
	var im1 = max(i-1, 0)
	var ip1 = min(i+1, len(tuberail0)-1)
	#var hpt = (pt0 + pt1)/2
	var hptP1 = (tuberail0[ip1][0] + tuberail1[ip1][0])/2
	var hptM1 = (tuberail0[im1][0] + tuberail1[im1][0])/2
	var avec = pt1 - pt0
	var svec = hptP1 - hptM1
	return Basis(svec.normalized(), avec.cross(svec).normalized(), avec/avec.length_squared())
	
static func sidecubeintermedrail(nodepoints, tuberail0, tuberail1, quadrail, bfore):
	var i = 0 if bfore else len(tuberail0)-1
	var qib = cubeintermedrailbasis(i, tuberail0, tuberail1)
	var pt0 = tuberail0[i][0]
	var zi = [ ]
	for qr in quadrail:
		var qpt = nodepoints[qr]
		var vpt = qpt - pt0
		var lz = qib.z.dot(vpt)
		#var z = clamp(lz, 0.0 if len(zi) == 0 else zi[-1].z, 1.0)
		var sp = lerp(tuberail0[i][0], tuberail1[i][0], lz)
		var dpt = qpt - sp
		zi.push_back(Vector3(qib.x.dot(dpt), qib.y.dot(dpt), lz))
		zi.push_back(qpt)
	return zi
	
	
static func slicerungsatintermediatecuberail(tuberail0, tuberail1, rung0k, rung1k, rung0kp, rung1kp):
	assert(len(tuberail0) == len(tuberail1))
	var tuberailk = [ ]
	for i in range(len(tuberail0)):
		var dpp
		var x
		if i != 0 and i != len(tuberail0) - 1:
			var u0 = tuberail0[i][2]
			var u1 = tuberail1[i][2]
			var z0 = rung0k.z
			var z1 = rung1k.z
			x = (z0 + (z1-z0)*u0) / (1 - (z1-z0)*(u1-u0))
			var y = u0 + x*(u1-u0)
			assert(is_equal_approx(x, z0 + y*(z1-z0)))
			#assert(0 <= x and x <= 1 and 0 <= y and y <= 1)
			var dpi = lerp(rung0k, rung1k, y)
			var qib = cubeintermedrailbasis(i, tuberail0, tuberail1)
			var sp = lerp(tuberail0[i][0], tuberail1[i][0], dpi.z)
			dpp = sp + qib.x*dpi.x + qib.y*dpi.y
		else:
			var dpi
			if i == 0:
				assert(tuberail0[i][2] == 0.0 and tuberail1[i][2] == 0.0)
				dpi = rung0k
				dpp = rung0kp
			else:
				assert(tuberail0[i][2] == 1.0 and tuberail1[i][2] == 1.0)
				dpi = rung1k
				dpp = rung1kp
			if ((dpi.z == 0.0 or dpi.z == 1.0) and dpi.x == 0.0 and dpi.y == 0.0):
				dpp = tuberail0[i][0] if dpi.z == 0.0 else tuberail1[i][0]
			x = dpi.z
			#var Dqib = cubeintermedrailbasis(i, tuberail0, tuberail1)
			#var Dsp = lerp(tuberail0[i][0], tuberail1[i][0], dpi.z)
			#var Ddpp = Dsp + Dqib.x*dpi.x + Dqib.y*dpi.y
			assert (dpp.is_equal_approx(dpp))
			
		var dpuv = lerp(tuberail0[i][1], tuberail1[i][1], x)
		tuberailk.push_back([dpp, dpuv])

	return tuberailk
	
static func makerailcuboidshellmeshface(surfaceTool, nodepoints, cuboidrailfac):
	var quadrail0 = cuboidrailfac[0]
	var quadrail1 = cuboidrailfac[1]
	var railseqrung0 = cuboidrailfac[2]
	var railseqrung1 = cuboidrailfac[3]
	var tuberails = initialcuboidrails(nodepoints, quadrail0, quadrail1)
	var tuberail0 = tuberails[0]
	var tuberail1 = tuberails[1]
		
	if len(railseqrung0) != 0 or len(railseqrung1) != 0:
		var zi = sidecubeintermedrail(nodepoints, tuberail0, tuberail1, railseqrung0, true)
		var zi1 = sidecubeintermedrail(nodepoints, tuberail0, tuberail1, railseqrung1, false)
		var railsequencerung0 = [ ]
		var railsequencerung1 = [ ]
		intermediaterailsequence2(zi, zi1, railsequencerung0, railsequencerung1)
		assert(len(railsequencerung0) == len(railsequencerung1))
		var tuberailk0 = tuberail0
		for k2 in range(0, len(railsequencerung0)+2, 2):
			var tuberailk1
			if k2 < len(railsequencerung0):
				tuberailk1 = slicerungsatintermediatecuberail(tuberail0, tuberail1, railsequencerung0[k2], railsequencerung1[k2], railsequencerung0[k2+1], railsequencerung1[k2+1])
			else:
				tuberailk1 = tuberail1
			triangulatetuberails(surfaceTool, tuberailk0, tuberailk1)
			tuberailk0 = tuberailk1
	else:
		triangulatetuberails(surfaceTool, tuberail0, tuberail1)

const recuboidbyvalueinversion = false
static func makerailcuboidshellmesh(nodepoints, cuboidrailfacs, checkcorrectextnormals):
	var arraymesh = ArrayMesh.new()
	var surfaceTool = SurfaceTool.new()
	surfaceTool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for cuboidrailfac in cuboidrailfacs:
		makerailcuboidshellmeshface(surfaceTool, nodepoints, cuboidrailfac)
	surfaceTool.generate_normals()
	if not checkcorrectextnormals:
		surfaceTool.commit(arraymesh)
		return arraymesh

	var ama = surfaceTool.commit_to_arrays()
	var amaverts = ama[ArrayMesh.ARRAY_VERTEX]
	var amanorms = ama[ArrayMesh.ARRAY_NORMAL]
	var imax = 0
	var ymax = amaverts[0].y
	var ynmax = amanorms[0].y
	for i in range(1, len(amaverts)):
		var y = amaverts[i].y
		var yn = amanorms[i].y
		if y > ymax or (y == ymax and abs(yn) > abs(ynmax)):
			ymax = y
			ynmax = yn
			imax = i
	print("Boulder with highest point normal inverted ", amaverts[imax], amanorms[imax])
	if ynmax < 0.0:
		print("Inverting boulder with highest point normal inverted ", amaverts[imax], amanorms[imax])
		if not recuboidbyvalueinversion:
			return null
		var amauvs = ama[ArrayMesh.ARRAY_TEX_UV]
		for i in range(2, len(amaverts), 3):
			var a = amaverts[i-1]
			amaverts[i-1] = amaverts[i]
			amaverts[i] = a
			var b = amauvs[i-1]
			amauvs[i-1] = amauvs[i]
			amauvs[i] = b
		for i in range(len(amanorms)):
			amanorms[i] = -amanorms[i]
		ama[ArrayMesh.ARRAY_VERTEX] = amaverts
		ama[ArrayMesh.ARRAY_NORMAL] = amanorms
		ama[ArrayMesh.ARRAY_TEX_UV] = amauvs
	arraymesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, ama)
	return arraymesh


static func findclosestcuboidshellface(targetpoint, dragvec, nodepoints, cuboidrailfacs):
	var closestcuberailfac = [ ]
	var closestdist = -1.0
	var vrayfrom = targetpoint + dragvec
	var vraydir = -dragvec
	for cuboidrailfac in cuboidrailfacs:
		var surfaceTool = SurfaceTool.new()
		surfaceTool.begin(Mesh.PRIMITIVE_TRIANGLES)
		makerailcuboidshellmeshface(surfaceTool, nodepoints, cuboidrailfac)
		var sarrays = surfaceTool.commit_to_arrays()
		var vertices = sarrays[ArrayMesh.ARRAY_VERTEX]
		print("findclosestcuboidshellface ", len(vertices))
		for i in range(2, len(vertices), 3):
			var vt = Geometry.ray_intersects_triangle(vrayfrom, vraydir, vertices[i-2], vertices[i-1], vertices[i])
			if vt != null:
				var dist = targetpoint.distance_to(vt)
				if closestdist == -1.0 or dist < closestdist:
					closestcuberailfac = cuboidrailfac
					closestdist = dist
	return closestcuberailfac


static func pickpolyskey(polysdict, xcdrawinglink, js):
	var pickpolykey = ""
	for k in polysdict.keys():
		var poly = polysdict[k]
		var meetsallnodes = true
		var j = js
		while j < len(xcdrawinglink):
			var meetnodename = xcdrawinglink[j]
			if not poly.has(meetnodename):
				meetsallnodes = false
				break
			j += 2
		if meetsallnodes:
			pickpolykey = k
			break
	if pickpolykey == "linearpath":
		var meetnodenames = xcdrawinglink.slice(js, len(xcdrawinglink), 2)
		var poly = polysdict[pickpolykey]
		if (not meetnodenames.has(poly[0])) or (not meetnodenames.has(poly[-1])):
			pickpolykey = ""
	return pickpolykey

static func addarrowmesh(surfaceTool, p0, p1, aperp, linewidth, intermediatepts):
	var p0m = p0
	var p0mleft = p0m - linewidth*aperp
	var p0mright = p0m + linewidth*aperp

	for i in range(len(intermediatepts)):
		var ipt = intermediatepts[i]
		var lp1m = ipt
		var lp1mleft = lp1m - linewidth*aperp
		var lp1mright = lp1m + linewidth*aperp
		surfaceTool.add_vertex(p0mleft)
		surfaceTool.add_vertex(lp1mleft)
		surfaceTool.add_vertex(p0mright)
		surfaceTool.add_vertex(p0mright)
		surfaceTool.add_vertex(lp1mleft)
		surfaceTool.add_vertex(lp1mright)
		p0m = ipt
		p0mleft = lp1mleft
		p0mright = lp1mright

	var vec = p1 - p0m
	var veclen = max(0.01, vec.length())
	var arrowlen = min(0.4, veclen*0.5)

	var p1m = p1 - vec*(arrowlen/veclen)
	var p1mleft = p1m - linewidth*aperp
	var p1mright = p1m + linewidth*aperp
	
	surfaceTool.add_vertex(p0mleft)
	surfaceTool.add_vertex(p1mleft)
	surfaceTool.add_vertex(p0mright)
	surfaceTool.add_vertex(p0mright)
	surfaceTool.add_vertex(p1mleft)
	surfaceTool.add_vertex(p1mright)

	var pa = p1m
	var arrowfac = max(2*linewidth, arrowlen/2)
	surfaceTool.add_vertex(p1)
	surfaceTool.add_vertex(pa + arrowfac*aperp)
	surfaceTool.add_vertex(pa - arrowfac*aperp)

static func addnoarrowhorizontalmesh(surfaceTool, p0, p1, linewidth, intermediatepts):
	var p0m = p0
	var p0mleft = p0m
	var p0mright = p0m
	for i in range(1 + len(intermediatepts)):
		var lp1m = intermediatepts[i] if i != len(intermediatepts) else p1
		var aperp = Vector3(lp1m.x - p0m.x, 0.0, lp1m.z - p0m.z).cross(Vector3(0,1,0)).normalized()
		if i == 0:
			p0mleft = p0m - linewidth*aperp
			p0mright = p0m + linewidth*aperp
		var lp1mleft = lp1m - linewidth*aperp
		var lp1mright = lp1m + linewidth*aperp
		surfaceTool.add_vertex(p0mleft)
		surfaceTool.add_vertex(lp1mleft)
		surfaceTool.add_vertex(p0mright)
		surfaceTool.add_vertex(p0mright)
		surfaceTool.add_vertex(lp1mleft)
		surfaceTool.add_vertex(lp1mright)
		p0m = lp1m
		p0mleft = lp1mleft
		p0mright = lp1mright


static func triangulatetuberung(surfaceTool, tuberail0rung0, tuberail1rung0, tuberail0rung1, tuberail1rung1):
	surfaceTool.add_uv(tuberail0rung0[1])
	#surfaceTool.add_uv2(tuberail0rung0[1])
	surfaceTool.add_uv2(Vector2(tuberail0rung0[0].x, tuberail0rung0[0].z))
	surfaceTool.add_vertex(tuberail0rung0[0])

	surfaceTool.add_uv(tuberail1rung0[1])
	#surfaceTool.add_uv2(tuberail1rung0[1])
	surfaceTool.add_uv2(Vector2(tuberail1rung0[0].x, tuberail1rung0[0].z))
	surfaceTool.add_vertex(tuberail1rung0[0])

	if tuberail1rung0[0] != tuberail1rung1[0]:
		surfaceTool.add_uv(tuberail1rung1[1])
		#surfaceTool.add_uv2(tuberail1rung1[1])
		surfaceTool.add_uv2(Vector2(tuberail1rung1[0].x, tuberail1rung1[0].z))
		surfaceTool.add_vertex(tuberail1rung1[0])
		if tuberail0rung0[0] == tuberail0rung1[0]:
			return

		surfaceTool.add_uv(tuberail0rung0[1])
		#surfaceTool.add_uv2(tuberail0rung0[1])
		surfaceTool.add_uv2(Vector2(tuberail0rung0[0].x, tuberail0rung0[0].z))
		surfaceTool.add_vertex(tuberail0rung0[0])

		surfaceTool.add_uv(tuberail1rung1[1])
		#surfaceTool.add_uv2(tuberail1rung1[1])
		surfaceTool.add_uv2(Vector2(tuberail1rung1[0].x, tuberail1rung1[0].z))
		surfaceTool.add_vertex(tuberail1rung1[0])

	surfaceTool.add_uv(tuberail0rung1[1])
	#surfaceTool.add_uv2(tuberail0rung1[1])
	surfaceTool.add_uv2(Vector2(tuberail0rung1[0].x, tuberail0rung1[0].z))
	surfaceTool.add_vertex(tuberail0rung1[0])


static func triangulatetuberails(surfaceTool, tuberail0, tuberail1):
	for i in range(len(tuberail0)-1):
		triangulatetuberung(surfaceTool, tuberail0[i], tuberail1[i], tuberail0[i+1], tuberail1[i+1])

static func advanceuvFar(uvFixed, ptFixed, uvFar, ptFar, ptFarNew, bclockwise):
	var uvvec = uvFar - uvFixed
	var uvperpvec = Vector2(uvvec.y, -uvvec.x) if bclockwise else Vector2(-uvvec.y, uvvec.x)
	var vecFar = ptFar - ptFixed
	var vecFarNew = ptFarNew - ptFixed
	var vecFarFarNewprod = vecFar.length()*vecFarNew.length()
	if vecFarFarNewprod == 0:
		return uvFar
	var vecFarFarNewRatio = vecFarNew.length()/vecFar.length()
	var vecFarNewCos = vecFar.dot(vecFarNew)/vecFarFarNewprod
	var vecFarNewSin = vecFar.cross(vecFarNew).length()/vecFarFarNewprod
	var uvvecnew = uvvec*vecFarNewCos + uvperpvec*vecFarNewSin
	var uvvecnewR = uvvecnew*vecFarFarNewRatio
	return uvFixed + uvvecnewR

static func intermediaterailsequence(zi, zi1, railsequencerung0, railsequencerung1):
	var ij = -1
	var i1j = -1
	var zij0 = Vector3(0,0,0)
	var zi1j0 = Vector3(0,0,0)
	var zij1 = Vector3(0,0,1) if len(zi) == 0 else zi[0]
	var zi1j1 = Vector3(0,0,1) if len(zi1) == 0 else zi1[0]

	while true:
		assert(ij < len(zi) or i1j < len(zi1))
		var adv = 0
		if ij == len(zi):
			adv = 1
		elif i1j == len(zi1):
			adv = -1
		elif zi1j1.z < zij1.z:
			if zi1j1.z - zij0.z < zij1.z - zi1j1.z:
				adv = 1
		else:
			if zij1.z - zi1j0.z < zi1j1.z - zij1.z:
				adv = -1

		if adv <= 0:
			ij += 1
			zij0 = zij1
			if ij != len(zi):
				zij1 = Vector3(0,0,1) if ij+1 == len(zi) else zi[ij+1] 
		if adv >= 0:
			i1j += 1
			zi1j0 = zi1j1
			if i1j != len(zi1):
				zi1j1 = Vector3(0,0,1) if i1j+1 == len(zi1) else zi1[i1j+1] 
		if ij == len(zi) and i1j == len(zi1):
			break
		railsequencerung0.push_back(zij0)
		railsequencerung1.push_back(zi1j0)

static func intermediaterailsequence2(zi, zi1, railsequencerung0, railsequencerung1):
	var ij = -2
	var i1j = -2
	var zij0 = Vector3(0,0,0)
	var zi1j0 = Vector3(0,0,0)
	var zij0z = 0.0
	var zi1j0z = 0.0
	var zij1 = Vector3(0,0,1) if len(zi) == 0 else zi[0]
	var zi1j1 = Vector3(0,0,1) if len(zi1) == 0 else zi1[0]
	var zij1z = 1.0 if len(zi) == 0 else 2.0/len(zi)
	var zi1j1z = 1.0 if len(zi1) == 0 else 2.0/len(zi1)

	while true:
		assert(ij < len(zi) or i1j < len(zi1))
		assert (zij1z >= 0.0 and zij1z <= 1.0 and zi1j1z >= 0.0 and zi1j1z <= 1.0)
		var adv = 0
		if ij == len(zi):
			adv = 1
		elif i1j == len(zi1):
			adv = -1
		elif zi1j1z < zij1z:
			if zi1j1z - zij0z < zij1z - zi1j1z:
				adv = 1
		else:
			if zij1z - zi1j0z < zi1j1z - zij1z:
				adv = -1

		if adv <= 0:
			ij += 2
			zij0 = zij1
			zij0z = zij1z
			if ij != len(zi):
				zij1 = Vector3(0,0,1) if ij+2 == len(zi) else zi[ij+2] 
				zij1z = 1.0 if ij+2 == len(zi) else (ij+2.0)/len(zi)
		if adv >= 0:
			i1j += 2
			zi1j0 = zi1j1
			zi1j0z = zi1j1z
			if i1j != len(zi1):
				zi1j1 = Vector3(0,0,1) if i1j+2 == len(zi1) else zi1[i1j+2] 
				zi1j1z = 1.0 if i1j+2 == len(zi1) else (i1j+2.0)/len(zi1) 
		if ij == len(zi) and i1j == len(zi1):
			break
		railsequencerung0.push_back(zij0)
		railsequencerung0.push_back(zi[ij+1] if ij >= 0 and ij < len(zi) else Vector3(98,98,98))
		
		railsequencerung1.push_back(zi1j0)
		railsequencerung1.push_back(zi1[i1j+1] if i1j >= 0 and i1j < len(zi1) else Vector3(99,99,99))

class sortquatfuncclass:
	static func sortquatfunc(a, b):
		return a.x < b.x or (a.x == b.x and (a.y < b.y or (a.y == b.y and (a.z < b.z or (a.z == b.z and a.w < b.w)))))

static func unifiedclosedmeshwithnormals(tubeslist, drawingslist):
	var tubepoolvectors = [ ]
	var vertqindexes = [ ]
	var ntriangles = 0
	var nsurfaces = 0
	for tube in tubeslist:
		for k in range(tube.get_node("XCtubesectors").get_child_count()):
			var tubesector = tube.get_node("XCtubesectors").get_child(k)
			if tube.xcsectormaterials[k] != "hole":
				var surfmesharray = tubesector.get_node("MeshInstance").mesh.surface_get_arrays(0)
				var surfverts = surfmesharray[ArrayMesh.ARRAY_VERTEX]
				assert (surfmesharray[ArrayMesh.ARRAY_INDEX] == null)
				for p in surfverts:
					vertqindexes.push_back(Quat(p.x, p.y, p.z, len(vertqindexes)))
				ntriangles += len(surfverts)/3
				nsurfaces += 1

	for xcdrawing in drawingslist:
		if xcdrawing.drawingtype == DRAWING_TYPE.DT_XCDRAWING and xcdrawing.has_node("XCflatshell") and xcdrawing.xcflatshellmaterial != "hole":
			var surfmesharray = xcdrawing.get_node("XCflatshell/MeshInstance").mesh.surface_get_arrays(0)
			if len(surfmesharray) != 0:
				var surfverts = surfmesharray[ArrayMesh.ARRAY_VERTEX]
				assert (surfmesharray[ArrayMesh.ARRAY_INDEX] == null)
				for lp in surfverts:
					var p = xcdrawing.transform.xform(lp)
					vertqindexes.push_back(Quat(p.x, p.y, p.z, len(vertqindexes)))
				ntriangles += len(surfverts)/3
				nsurfaces += 1
	print("Number of triangles: ", ntriangles, " number of surfaces: ", nsurfaces)

	vertqindexes.sort_custom(sortquatfuncclass, "sortquatfunc")
	var dedupverts = [ ]
	var trirefs = [ ]
	for q in vertqindexes:
		var p = Vector3(q.x, q.y, q.z)
		if len(dedupverts) == 0 or dedupverts[-1] != p:
			dedupverts.push_back(p)
		trirefs.push_back(Vector2(q.w, len(dedupverts)-1))
	trirefs.sort()
	var triindex = [ ]
	for t in trirefs:
		assert (len(triindex) == t.x)
		triindex.push_back(int(t.y))
		
	var arr = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = PoolVector3Array(dedupverts)
	arr[Mesh.ARRAY_INDEX] = PoolIntArray(triindex)
	var joinedmesh = ArrayMesh.new()
	joinedmesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	
	var cornertrinorms = [ ]
	var mdt = MeshDataTool.new()
	mdt.create_from_surface(joinedmesh, 0)
	for i in range(mdt.get_vertex_count()):
		var fs = mdt.get_vertex_faces(i)
		var nsum = Vector3(0, 0, 0)
		for f in fs:
			var i0 = mdt.get_face_vertex(f, 0)
			var i1 = mdt.get_face_vertex(f, 1)
			var i2 = mdt.get_face_vertex(f, 2)
			var p
			var p1
			var p2
			if i == i0:
				p = mdt.get_vertex(i0)
				p1 = mdt.get_vertex(i1)
				p2 = mdt.get_vertex(i2)
			elif i == i1:
				p = mdt.get_vertex(i1)
				p1 = mdt.get_vertex(i2)
				p2 = mdt.get_vertex(i0)
			else:
				assert (i == i2)
				p = mdt.get_vertex(i2)
				p1 = mdt.get_vertex(i0)
				p2 = mdt.get_vertex(i1)
			var n = (p1 - p).cross(p2 - p)
			nsum += n
		cornertrinorms.push_back(nsum.normalized())

	arr[Mesh.ARRAY_NORMAL] = PoolVector3Array(cornertrinorms)
	var arr_mesh = ArrayMesh.new()
	arr_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return arr_mesh
			

static func waterlevelsfromropesequences(nodepoints, ropeseqs):
	var waterflowlevelvectors = { }
	for ropeseq in ropeseqs:
		if len(ropeseq) == 4 and ropeseq[0] == ropeseq[3]:
			if ropeseq[1][0] != "a" and ropeseq[2][0] != "a":
				var tailpoint = (nodepoints[ropeseq[1]] + nodepoints[ropeseq[2]])*0.5
				var watervector = nodepoints[ropeseq[0]] - tailpoint
				waterflowlevelvectors[ropeseq[0]] = watervector
			else:
				return null
	return null if len(waterflowlevelvectors) == 0 else waterflowlevelvectors

static func thincurve(pts, tol):
	if len(pts) <= 3:
		return pts
	var i0 = 0
	var tpts = [ pts[i0] ]
	var i1stack = [ len(pts)-1 ]
	while i1stack:
		var i1 = i1stack[-1]
		var pt0 = pts[i0]
		var pt1 = pts[i1]
		var vec = pt1 - pt0
		var vecsq = vec.length_squared()
		var immaxd = -1
		var maxd = -1.0
		for i in range(i0+1, i1):
			var pti = pts[i]
			var vecd = vec.dot(pti - pt0)
			var lam = clamp(vecd/vecsq, 0.0, 1.0) if vecsq != 0.0 else 0.0
			var dpti = pt0 + vec*lam - pti
			var dptilen = dpti.length()
			if immaxd == -1 or dptilen > maxd:
				immaxd = i
				maxd = dptilen
		if maxd >= tol:
			i1stack.push_back(immaxd)
		else:
			i0 = i1
			tpts.push_back(pts[i0])
			i1stack.pop_back()
	return tpts
	
static func intermediatedrawnpoints(pts, spbasis):
	if len(pts) <= 2:
		return [ ]
	var intermediatepoints = [ ]
	var p0 = pts[0]
	var p1 = pts[-1]
	var vec = p1 - p0
	var vecsq = vec.length_squared()
	if vecsq == 0.0:
		vecsq = 1.0
	for i in range(1, len(pts) - 1):
		var dpz = clamp((pts[i] - p0).dot(vec)/vecsq, 0.0, 1.0)
		var sp = lerp(p0, p1, dpz)
		var dp = pts[i] - sp
		intermediatepoints.push_back(Vector3(dp.dot(spbasis.x), dp.dot(spbasis.z), dpz))
	return intermediatepoints
