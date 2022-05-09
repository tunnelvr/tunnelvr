extends Node


func _ready():
	$RayCast.collision_mask = CollisionLayer.CL_CaveWall

func addwaterlevelfan(surfaceTool, cpt, vf):
	var vfperp = Vector2(vf.y, -vf.x)
	var prevvv = null
	var prevpr = null
	for i in range(11):
		var a = deg2rad((i - 5)/5.0*45)
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
		
func sequenceapplyendcapjoins(facseqs, endcap):
	var seqmatches = [ ]
	for i in range(len(facseqs)):
		var facseq = facseqs[i]
		for j in range(len(endcap)):
			if facseq[-1].is_equal_approx(endcap[j]):
				seqmatches.push_back([-1,i,j])
			if facseq[0].is_equal_approx(endcap[j]):
				seqmatches.push_back([0,i,j])
	seqmatches.sort()
	if len(seqmatches) == 2:
		var i0 = seqmatches[0][1]
		var i1 = seqmatches[1][1]
		var j0 = seqmatches[0][2]
		var j1 = seqmatches[1][2]
		endcap.remove(max(j0, j1))
		endcap.remove(min(j0, j1))
		var seq = facseqs[i0]
		if i0 != i1:
			seq += facseqs[i1]
		else:
			seq.push_back(seq[0])
		facseqs.remove(max(i0, i1))
		facseqs.remove(min(i0, i1))
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

	var poly = facseqs[0]
	if poly[-1] == poly[0]:
		poly.remove(len(poly)-1)
	var pi = Geometry.triangulate_polygon(PoolVector2Array(poly))
	for u in pi:
		surfaceTool.add_uv(poly[u])
		surfaceTool.add_vertex(Vector3(poly[u].x, yval, poly[u].y))
	return (len(pi) != 0)


func drawwaterlevelmesh(sketchsystem, waterflowlevelvectors, nodepoints):
	var raycast = $RayCast
	var xctubes = sketchsystem.get_node("XCtubes")
	var xcdrawings = sketchsystem.get_node("XCdrawings")
	var arraymesh = ArrayMesh.new()
	var surfaceTool = SurfaceTool.new()
	surfaceTool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for nodename in waterflowlevelvectors:
		var cpt = nodepoints[nodename]
		raycast.transform.origin = cpt
		raycast.cast_to = Vector3(0, -10, 0)
		raycast.force_raycast_update()
		var watertube = raycast.get_collider()
		var waterleveladded = false
		if watertube != null:
			var nodepath = watertube.get_path()
			var w2 = nodepath.get_name(2)
			var w3 = nodepath.get_name(3)
			if w2 == "SketchSystem" and w3 == "XCtubes":
				var tubename = nodepath.get_name(4)
				var xctube = xctubes.get_node(tubename)
				var xcdrawing0 = xcdrawings.get_node(xctube.xcname0)
				var xcdrawing1 = xcdrawings.get_node(xctube.xcname1)
				waterleveladded = addwaterleveltube(surfaceTool, xcdrawing0, xcdrawing1, xctube, cpt.y)
		if not waterleveladded:
			addwaterlevelfan(surfaceTool, cpt, -Vector2(waterflowlevelvectors[nodename].x, waterflowlevelvectors[nodename].z)*1.2)

	surfaceTool.generate_normals()
	surfaceTool.generate_tangents()
	surfaceTool.commit(arraymesh)
	return arraymesh
