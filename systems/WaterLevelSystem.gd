extends Node

var waterlevelropequeue = [ ]
var waterlevelqueueprocessing = false

func _ready():
	$RayCast.collision_mask = CollisionLayer.CL_CaveWall

# also keep track of the ropehangs that will need updating as we change the tube

func addtowaterlevelropeque(waterlevelrope):
	if waterlevelrope != null:
		waterlevelropequeue.push_back(waterlevelrope)
	if waterlevelqueueprocessing:
		return
	waterlevelqueueprocessing = true
	var sketchsystem = get_node("/root/Spatial/SketchSystem")
	var xcdrawings = sketchsystem.get_node("XCdrawings")
	while len(waterlevelropequeue) != 0:
		if not Tglobal.notisloadingcavechunks:
			yield(get_tree().create_timer(0.1), "timeout")
			continue
		var xcname = waterlevelropequeue.pop_back()
		var xcdrawing = xcdrawings.get_node_or_null(xcname)
		if xcdrawing == null:
			continue
		var ropehang = xcdrawing.get_node_or_null("RopeHang")
		if ropehang == null:
			continue
		var ropeseqs = Polynets.makeropenodesequences(xcdrawing.nodepoints, xcdrawing.onepathpairs, ropehang.oddropeverts, ropehang.anchorropeverts, true)
		var waterflowlevelvectors = Polynets.waterlevelsfromropesequences(xcdrawing.nodepoints, ropeseqs)
		if waterflowlevelvectors != null:
			ropehang.get_node("RopeMesh").mesh = makewaterlevelmeshfull(xcdrawing, ropeseqs, sketchsystem, waterflowlevelvectors)
		yield(get_tree().create_timer(0.1), "timeout")
	waterlevelqueueprocessing = false

func makewaterlevelmeshfull(xcdrawing, ropeseqs, sketchsystem, waterflowlevelvectors):
	var failedwaterflowlevelvectors = { }
	var nodestotubes = { }
	var waterleveltubes = { }
	for nodename in waterflowlevelvectors:
		var cpt = xcdrawing.nodepoints[nodename]
		var tubename = castraytotubename(cpt)
		if tubename != null:
			nodestotubes[nodename] = tubename
			waterleveltubes[tubename] = cpt
		else:
			failedwaterflowlevelvectors[nodename] = waterflowlevelvectors[nodename]
	var tubeintervalnodepairs = extendwaterleveltubesnodes(waterleveltubes, xcdrawing.nodepoints, ropeseqs, nodestotubes, failedwaterflowlevelvectors)
	extendwaterleveltubesintermediate(sketchsystem, waterleveltubes, tubeintervalnodepairs)
	return drawwaterlevelmesh(sketchsystem, waterleveltubes, failedwaterflowlevelvectors, xcdrawing.nodepoints)

func makewaterlevelmeshsimple(xcdrawing, sketchsystem, waterflowlevelvectors):
	return drawwaterlevelmesh(sketchsystem, {}, waterflowlevelvectors, xcdrawing.nodepoints)


func addwaterlevelfan(surfaceTool, cpt, ffv):
	var vf = -Vector2(ffv.x, ffv.z)*1.2
	var sectordeg = 45
	if vf == Vector2(0,0):
		vf = Vector2(0.3, 0)
		sectordeg = 180
	var vfperp = Vector2(vf.y, -vf.x)
	var prevvv = null
	var prevpr = null
	for i in range(11):
		var a = deg2rad((i - 5)/5.0*sectordeg)
		var vv = cos(a)*vf - sin(a)*vfperp
		var pr = cpt + Vector3(vv.x, 0, vv.y)
		if i != 0:
			surfaceTool.add_uv(Vector2(0, 0))
			surfaceTool.add_vertex(cpt)
			surfaceTool.add_uv(prevvv)
			surfaceTool.add_vertex(prevpr)
			surfaceTool.add_uv(vv)
			surfaceTool.add_vertex(pr)
		prevvv = vv
		prevpr = pr

func xcdrawingslice(xcdrawing, yval):
	var res = [ ]
	for i in range(0, len(xcdrawing.onepathpairs), 2):
		var s0 = xcdrawing.onepathpairs[i]
		var s1 = xcdrawing.onepathpairs[i+1]
		var p0 = xcdrawing.transform.xform(xcdrawing.nodepoints[s0])
		var p1 = xcdrawing.transform.xform(xcdrawing.nodepoints[s1])
		if p0.y < yval and not p1.y < yval:
			var lam = inverse_lerp(p0.y, p1.y, yval)
			var pm = lerp(Vector2(p0.x, p0.z), Vector2(p1.x, p1.z), lam)
			res.push_back(pm)
		elif p1.y < yval and not p0.y < yval:
			var lam = inverse_lerp(p1.y, p0.y, yval)
			var pm = lerp(Vector2(p1.x, p1.z), Vector2(p0.x, p0.z), lam)
			res.push_back(pm)
	return res
	
func xcfacesslicecorrectorient(facseqdict, faces, yval):
	for i in range(0, len(faces), 3):
		var j
		if faces[i].y < yval and not faces[i+1].y < yval:
			j = 0
		elif faces[i+1].y < yval and not faces[i+2].y < yval:
			j = 1
		elif faces[i+2].y < yval and not faces[i].y < yval:
			j = 2
		else:
			continue
		var j1 = j+1 if j < 2 else 0
		var p0 = faces[i+j]
		var p1 = faces[i+j1]
		assert (p0.y < yval and not p1.y < yval)
		var j2 = j1+1 if j1 < 2 else 0
		var p2 = faces[i+j2]
		var lam = inverse_lerp(p0.y, p1.y, yval)
		var pm = lerp(Vector2(p0.x, p0.z), Vector2(p1.x, p1.z), lam)
		if p2.y < yval:
			var lam2 = inverse_lerp(p2.y, p1.y, yval)
			var pm2 = lerp(Vector2(p2.x, p2.z), Vector2(p1.x, p1.z), lam2)
			facseqdict[pm] = pm2
		else:
			var lam2 = inverse_lerp(p0.y, p2.y, yval)
			var pm2 = lerp(Vector2(p0.x, p0.z), Vector2(p2.x, p2.z), lam2)
			facseqdict[pm] = pm2

func sequenceslicededgesdict(facseqdict):
	var seqs = [ ]
	while len(facseqdict) != 0:
		var k0 = facseqdict.keys()[0]
		var kseq = [ k0 ]
		while true:
			var k1 = facseqdict[k0]
			facseqdict.erase(k0)
			k0 = k1
			kseq.push_back(k0)
			if not facseqdict.has(k0):
				break
		for i in range(len(seqs)+1):
			if i < len(seqs):
				if kseq[-1] == seqs[i][0]:
					seqs[i] = kseq.slice(0, -2) + seqs[i]
					break
			else:
				seqs.push_back(kseq)
	return seqs
		
func sortafunc(a, b):
	return a[0] < b[0]
		
func sequenceapplyendcapjoins(facseqs, endcap):
	var seqmatches = [ ]
	for i in range(len(facseqs)):
		var facseq = facseqs[i]
		for j in range(len(endcap)):
			var dvback = facseq[-1] - endcap[j]
			var dvfront = facseq[0] - endcap[j]
			if facseq[-1].is_equal_approx(endcap[j]) or (abs(dvback.x) < 0.002 and abs(dvback.y) < 0.002):
				seqmatches.push_back([-1,i,j])
			if facseq[0].is_equal_approx(endcap[j]) or (abs(dvfront.x) < 0.002 and abs(dvfront.y) < 0.002):
				seqmatches.push_back([0,i,j])
	seqmatches.sort_custom(self, "sortafunc")
	if len(seqmatches) == 2 and seqmatches[0][0] == -1 and seqmatches[1][0] == 0:
		var i0 = seqmatches[0][1]
		var i1 = seqmatches[1][1]
		var j0 = seqmatches[0][2]
		var j1 = seqmatches[1][2]
		endcap.remove(max(j0, j1))
		endcap.remove(min(j0, j1))
		var seq = facseqs[i0]
		if i0 != i1:
			seq += facseqs[i1]
			facseqs.remove(max(i0, i1))
			facseqs.remove(min(i0, i1))
		else:
			seq.push_back(seq[0])
			facseqs.remove(i0)
		facseqs.push_back(seq)
		
		
func addwaterleveltube(surfaceTool, xcdrawing0, xcdrawing1, xctube, yval):
	var facseqdict = { }
	for xctubesector in xctube.get_node("XCtubesectors").get_children():
		var tubesectormesh = xctubesector.get_node("MeshInstance").mesh
		var tubesectorfaces = tubesectormesh.get_faces()
		xcfacesslicecorrectorient(facseqdict, tubesectorfaces, yval)
	var facseqs = sequenceslicededgesdict(facseqdict)
			
	var endcap0 = xcdrawingslice(xcdrawing0, yval)
	var endcap1 = xcdrawingslice(xcdrawing1, yval)
	sequenceapplyendcapjoins(facseqs, endcap0)
	sequenceapplyendcapjoins(facseqs, endcap1)

	if len(facseqs) == 1 and facseqs[0][0] == facseqs[0][-1]:
		var poly = facseqs[0]
		poly.remove(len(poly)-1)
		var pi = Geometry.triangulate_polygon(PoolVector2Array(poly))
		for u in pi:
			surfaceTool.add_uv(poly[u])
			surfaceTool.add_normal(Vector3(0,1,0))
			surfaceTool.add_vertex(Vector3(poly[u].x, yval, poly[u].y))
		return true
	return false



func drawwaterlevelmesh(sketchsystem, waterleveltubes, failedwaterflowlevelvectors, nodepoints):
	var xctubes = sketchsystem.get_node("XCtubes")
	var xcdrawings = sketchsystem.get_node("XCdrawings")
	var arraymesh = ArrayMesh.new()
	var surfaceTool = SurfaceTool.new()
	surfaceTool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var failedwaterflowleveltubes = { }
	for tubename in waterleveltubes:
		var xctube = xctubes.get_node(tubename)
		var xcdrawing0 = xcdrawings.get_node(xctube.xcname0)
		var xcdrawing1 = xcdrawings.get_node(xctube.xcname1)
		if not addwaterleveltube(surfaceTool, xcdrawing0, xcdrawing1, xctube, waterleveltubes[tubename].y):
			failedwaterflowleveltubes[tubename] = waterleveltubes[tubename]

	for nodename in failedwaterflowlevelvectors:
		addwaterlevelfan(surfaceTool, nodepoints[nodename], failedwaterflowlevelvectors[nodename])
	for tubename in failedwaterflowleveltubes:
		addwaterlevelfan(surfaceTool, failedwaterflowleveltubes[tubename], Vector3(0,0,0))

	surfaceTool.generate_normals()
	surfaceTool.generate_tangents()
	surfaceTool.commit(arraymesh)
	return arraymesh


func castraytotubename(cpt):
	$RayCast.transform.origin = cpt
	$RayCast.cast_to = Vector3(0, -10, 0)
	$RayCast.force_raycast_update()
	var xctube = $RayCast.get_collider()
	if xctube != null:
		var nodepath = xctube.get_path()
		var w2 = nodepath.get_name(2)
		var w3 = nodepath.get_name(3)
		if w2 == "SketchSystem" and w3 == "XCtubes":
			return nodepath.get_name(4)
	return null
		
func neighbourtubes(xcdrawings, xctubes, tubename):
	var ntubes = [ ]
	var xctube = xctubes.get_node(tubename)
	var xcdrawing0 = xcdrawings.get_node(xctube.xcname0)
	var xcdrawing1 = xcdrawings.get_node(xctube.xcname1)
	for xctubec in xcdrawing0.xctubesconn:
		if xctubec != xctube:
			ntubes.push_back(xctubec)
	for xctubec in xcdrawing1.xctubesconn:
		if xctubec != xctube:
			ntubes.push_back(xctubec)
	return ntubes
	

const maxnumberofintermediatetubestobridge = 15
func extendwaterleveltubesintermediate(sketchsystem, waterleveltubes, tubeintervalnodepairs):
	var xctubes = sketchsystem.get_node("XCtubes")
	var xcdrawings = sketchsystem.get_node("XCdrawings")
	for i in range(0, len(tubeintervalnodepairs), 2):
		var tubenameP0 = tubeintervalnodepairs[i]
		var tubenameP1 = tubeintervalnodepairs[i+1]
		var xctube0 = xctubes.get_node_or_null(tubenameP0)
		var xctube1 = xctubes.get_node_or_null(tubenameP1)
		if xctube0 == null or xctube1 == null:
			continue
		var midtubes = [ ]
		var midtubespoints = [ ]
		var xct0xcdrawing0 = xcdrawings.get_node(xctube0.xcname0)
		var xct0xcdrawing1 = xcdrawings.get_node(xctube0.xcname1)
		var xct1xcdrawing0 = xcdrawings.get_node(xctube1.xcname0)
		var xct1xcdrawing1 = xcdrawings.get_node(xctube1.xcname1)
		var xct0xcdm0 = xct0xcdrawing0.transform.xform(xct0xcdrawing0.nodepointmean)
		var xct0xcdm1 = xct0xcdrawing1.transform.xform(xct0xcdrawing1.nodepointmean)
		var xct1xcdm0 = xct1xcdrawing0.transform.xform(xct1xcdrawing0.nodepointmean)
		var xct1xcdm1 = xct1xcdrawing1.transform.xform(xct1xcdrawing1.nodepointmean)
		var xct0mid = (xct0xcdm0 + xct0xcdm1)*0.5
		var xct1mid = (xct1xcdm0 + xct1xcdm1)*0.5
		for j in range(maxnumberofintermediatetubestobridge):
			var vaimdirection = xct1mid - xct0mid
			var xct0direction01dot = vaimdirection.dot(xct0xcdm1 - xct0xcdm0)
			var bxct0direction01 = (xct0direction01dot > 0)
			var xct0xcdrawingToCross = xct0xcdrawing1 if bxct0direction01 else xct0xcdrawing0
			var xctube0prev = xctube0
			xctube0 = null
			for lxctube0 in xct0xcdrawingToCross.xctubesconn:
				if lxctube0 == xctube0prev:
					continue
				var lxct0xcdrawing0 = xcdrawings.get_node(lxctube0.xcname0)
				var lxct0xcdrawing1 = xcdrawings.get_node(lxctube0.xcname1)
				var lxct0xcdm0 = lxct0xcdrawing0.transform.xform(lxct0xcdrawing0.nodepointmean)
				var lxct0xcdm1 = lxct0xcdrawing1.transform.xform(lxct0xcdrawing1.nodepointmean)
				var lxct0mid = (lxct0xcdm0 + lxct0xcdm1)*0.5
				if xctube0 != null:
					print("xctube y-junction ", lxctube0.get_name(), " ", xct1mid.distance_to(lxct0mid), "  ", xctube0.get_name(), " ", xct1mid.distance_to(xct0mid))
				if xctube0 == null or xct1mid.distance_to(lxct0mid) < xct1mid.distance_to(xct0mid):
					xctube0 = lxctube0
					xct0xcdrawing0 = lxct0xcdrawing0
					xct0xcdrawing1 = lxct0xcdrawing1
					xct0xcdm0 = lxct0xcdm0
					xct0xcdm1 = lxct0xcdm1
					xct0mid = lxct0mid
			if xctube0 == null:
				midtubes.clear()
				break
			if xctube0 == xctube1:
				break
			midtubes.push_back(xctube0.get_name())
			midtubespoints.push_back(xct0mid)				
		if len(midtubes) != 0:
			for j in range(len(midtubes)):
				if not waterleveltubes.has(midtubes[j]):
					var mpt = midtubespoints[j]
					mpt.y = lerp(waterleveltubes[tubenameP0].y, waterleveltubes[tubenameP1].y, (j+1)/(len(midtubes)+1))
					waterleveltubes[midtubes[j]] = mpt
	
func extendwaterleveltubesnodes(waterleveltubes, nodepoints, ropeseqs, nodestotubes, failedwaterflowlevelvectors):
	var tubeintervalnodepairs = [ ]
	for ropeseq in ropeseqs:
		if len(ropeseq) == 4 and ropeseq[0] == ropeseq[3]:
			continue
		var tubenameQ0 = nodestotubes.get(ropeseq[0])
		var tubenameQ1 = nodestotubes.get(ropeseq[-1])
		if tubenameQ0 == null and tubenameQ1 == null:
			for i in range(len(ropeseq)):
				if not failedwaterflowlevelvectors.has(ropeseq[i]):
					failedwaterflowlevelvectors[ropeseq[i]] = Vector3(0,0,0)
			continue
		var cptQ0 = nodepoints[ropeseq[0]]
		var cptQ1 = nodepoints[ropeseq[-1]]
		if tubenameQ0 == null:
			tubenameQ0 = castraytotubename(cptQ0)
			cptQ0.y = cptQ1.y
			if tubenameQ0 != null:
				nodestotubes[ropeseq[0]] = tubenameQ0
				waterleveltubes[tubenameQ0] = cptQ0
		if tubenameQ1 == null:
			tubenameQ1 = castraytotubename(cptQ1)
			cptQ1.y = cptQ0.y
			if tubenameQ1 != null:
				nodestotubes[ropeseq[-1]] = tubenameQ1
				waterleveltubes[tubenameQ1] = cptQ1
		var tubename0 = tubenameQ0
		for i in range(1, len(ropeseq)):
			var tubename1 = tubenameQ1
			if i < len(ropeseq) - 1:
				var nodename1 = ropeseq[i]
				var cpt1 = nodepoints[nodename1]
				tubename1 = castraytotubename(cpt1)
				if tubename1 != null:
					var lam = i*1.0/len(ropeseqs)
					cpt1.y = lerp(cptQ0.y, cptQ1.y, lam)
					if not waterleveltubes.has(tubename1):
						waterleveltubes[tubename1] = cpt1
				else:
					failedwaterflowlevelvectors[nodename1] = Vector3(0,0,0)
			if tubename0 != null and tubename1 != null:
				tubeintervalnodepairs.push_back(tubename0)
				tubeintervalnodepairs.push_back(tubename1)
			tubename0 = tubename1
	return tubeintervalnodepairs
