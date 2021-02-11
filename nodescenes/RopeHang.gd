extends Spatial

const uvfacx = 0.2
const uvfacy = 0.4
const roperad = 0.02
const ropeseglen = 0.25

# to abolish
func paraba(L, q):
	var qsq = q*q
	var qcu = q*qsq
	var yc = 0.6846094267632553 + q*0.5490693560779955 + qsq*0.10155603064930156 + qcu*(-0.0065641284014727455)
	var yb = 0.32724146179683267 + q*(-0.1282922369501835) + qsq*0.005644904325406289 + qcu*0.0005066041448132827
	var ya = 0.014515220403965912 + q*0.005970564724231822 + qsq*(-0.00083630038220914)
	return (-yb + sqrt(yb*yb - 4*ya*(yc-L)))/(2*ya)

func genrpsquareAM(verts, uvs, normals, p, vtexv, valong, hv, rad):
	var pv = -hv.cross(valong)
	var pdirs = [ pv+hv, pv-hv, -pv-hv, -pv+hv ]
	for i in range(4):
		verts.append(p+pdirs[i]*rad)
		normals.append(pdirs[i].normalized())
		uvs.append(Vector2(i/4.0, vtexv))

const cN = 4
func ropeseqtubesurfaceArrayMesh(verts, uvs, normals, indices, rpts, hangperpvec, rad, L):
	var p0 = rpts[0]
	var p1 = rpts[1]
	var v0 = (p1 - p0).normalized()
	var p0u = 0.0
	var inoff = len(verts)
	genrpsquareAM(verts, uvs, normals, p0, p0u, v0, hangperpvec, rad)
	var v1 = v0
	for i in range(1, len(rpts)):
		var p1u = p0u + (p1-p0).length()*uvfacx
		var p2 = null
		var v2 = null
		if i+1 < len(rpts):
			p2 = rpts[i+1]
			v2 = (p2 - p1).normalized()
			v1 = (v0 + v2).normalized()
		genrpsquareAM(verts, uvs, normals, p1, p1u, v1, hangperpvec, rad)
		for j in range(cN):
			var j1 = (j+1)%cN
			indices.append(inoff + (i-1)*cN + j)
			indices.append(inoff + i*cN + j)
			indices.append(inoff + i*cN + j1)
			indices.append(inoff + (i-1)*cN + j)
			indices.append(inoff + i*cN + j1)
			indices.append(inoff + (i-1)*cN + j1)
		p0 = p1
		p1 = p2
		v1 = v2
		p0u = p1u
	#print("ropelength L=", L, " curveL=", p0u/uvfacx)


# to abolish
func updatehangingropepathsArrayMesh(nodepoints, onepathpairs):
	var middlenodes = [ ]
	assert (len(onepathpairs) != 0)

	var verts = [] 
	var uvs = []
	var normals = []
	var indices = []
	
	var ropesequences = Polynets.makeropenodesequences(nodepoints, onepathpairs)
	for ropeseq in ropesequences:
		var L = 0.0
		for i in range(1, len(ropeseq)):
			L += (nodepoints[ropeseq[i-1]] - nodepoints[ropeseq[i]]).length()
			if i != len(ropeseq)-1:
				middlenodes.push_back(ropeseq[i])
		var rpt0 = nodepoints[ropeseq[0]]
		var rptF = nodepoints[ropeseq[-1]]		
		var vec = rptF - rpt0
		var H = Vector2(vec.x, vec.z).length()
		var rpts = [ ]
		var hangperpvec
		if H < 0.01:
			rpts = [rpt0, rptF]
			hangperpvec = Vector3(1,0,0)
		elif len(ropeseq) == 2:
			rpts = [rpt0, rptF]
			hangperpvec = Vector3(vec.z, 0, -vec.x)/H
		else:
			hangperpvec = Vector3(vec.z, 0, -vec.x)/H
			var q = vec.y/H
			var a = paraba(L/H, q)
			var N = int(max(L/ropeseglen, 4))
			rpts = [ ]
			for i in range(N+1):
				var x = i*1.0/N
				var y = x*x*a + x*(q-a)
				rpts.push_back(Vector3(rpt0.x + x*vec.x, rpt0.y + y*H, rpt0.z + x*vec.z))
		ropeseqtubesurfaceArrayMesh(verts, uvs, normals, indices, rpts, hangperpvec, roperad, L)

	var arr = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = PoolVector3Array(verts)
	arr[Mesh.ARRAY_TEX_UV] = PoolVector2Array(uvs)
	arr[Mesh.ARRAY_NORMAL] = PoolVector3Array(normals)
	arr[Mesh.ARRAY_INDEX] = PoolIntArray(indices)
	var arr_mesh = ArrayMesh.new()
	arr_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	$RopeMesh.mesh = arr_mesh
	
	var materialsystem = get_node("/root/Spatial/MaterialSystem")
	$RopeMesh.set_surface_material(0, ropematerialcolor)
	return middlenodes


var nodenamesArr = [ ]
var nodenamesAnchorN = 0
var old_nverts = [ ]
var nverts = [ ]
var prev_collideverts = [ ]
var collidenormals = [ ]

var nropeseqs = [ ]

var nropeseqLengs = [ ]
var nropeseqLengsMeasured = [ ]
var nropeseqseglens = [ ]
var oddropeverts = [ ]
var totalropeleng = 0
var totalstretchropeleng = 0
var ropematerialcolor = null
var ropematerialsolidcolor = null

func setropematerialcolour(n):
	var materialsystem = get_node("/root/Spatial/MaterialSystem")
	ropematerialcolor = materialsystem.pathlinematerial("rope").duplicate()
	ropematerialsolidcolor = materialsystem.pathlinematerial("ropesolid").duplicate()
	var h = hash([n,n,n,n,n,"abcv"])+5000
	var d = ((h%10000)/10000.0*(321-22)+22)/400
	var col = Color.from_hsv(d, 0.47, 0.97)
	ropematerialcolor.albedo_color = col
	ropematerialsolidcolor.albedo_color = col
	
func derivenverts(nodepoints, onepathpairs):
	nodenamesArr = [ ]
	nodenamesAnchorN = 0
	nverts = [ ]
	var middlenodes = [ ]
	var nnodenames = { }
	for nn in nodepoints:
		if nn[0] == "a":
			nnodenames[nn] = len(nodenamesArr)
			nodenamesArr.push_back(nn)
			nverts.push_back(nodepoints[nn])
	nodenamesAnchorN = len(nodenamesArr)
	for nn in nodepoints:
		if nn[0] != "a":
			nnodenames[nn] = len(nodenamesArr)
			nodenamesArr.push_back(nn)
			nverts.push_back(nodepoints[nn])
		
	nropeseqs = [ ]
	nropeseqLengs = [ ]
	nropeseqseglens = [ ]
	oddropeverts = [ ]
	totalropeleng = 0.0
	var ropesequences = Polynets.makeropenodesequences(nodepoints, onepathpairs, oddropeverts)
	for r in range(len(ropesequences)):
		var ropeseq = ropesequences[r]
		var nropeseq = [ nnodenames[ropeseq[0]] ]
		var L = 0.0
		for i in range(1, len(ropeseq)):
			var np0 = nodepoints[ropeseq[i-1]]
			var np1 = nodepoints[ropeseq[i]]
			var Ln = (np0 - np1).length()
			L += Ln
			var ns = max(1, int(Ln/ropeseglen + 0.5))
			for j in range(1, ns):
				nropeseq.push_back(len(nverts))
				nverts.push_back(lerp(np0, np1, j*1.0/ns))
			nropeseq.push_back(nnodenames[ropeseq[i]])
			if i != len(ropeseq)-1:
				middlenodes.push_back(ropeseq[i])
		nropeseqs.push_back(nropeseq)
		nropeseqLengs.push_back(L)
		nropeseqseglens.push_back(L/(len(nropeseq)-1))
		totalropeleng += L
	old_nverts = nverts.duplicate()
	prev_collideverts = nverts.duplicate()
	nropeseqLengsMeasured = nropeseqLengs.duplicate()
	collidenormals = [ ]
	for i in range(len(nverts)):
		collidenormals.push_back(null)
	totalstretchropeleng = totalropeleng
	return middlenodes
	
func updatehangingropepathsArrayMesh_Verlet(nodepoints, onepathpairs):
	assert (len(onepathpairs) != 0)
	var middlenodes = derivenverts(nodepoints, onepathpairs)
	#print("nropeseqLengs ", nropeseqLengs)
	
	var verts = [] 
	var normals = []
	var uvs = []
	var indices = []
	
	for nropeseq in nropeseqs:
		var rpts = [ ]
		for i in nropeseq:
			rpts.push_back(nverts[i])
		var rvec = rpts[-1] - rpts[0]
		var hangperpvec = Vector3(1,0,0) if Vector2(rvec.x, rvec.z).length() < 0.01 else Vector3(rvec.z, 0, -rvec.x).normalized()
		ropeseqtubesurfaceArrayMesh(verts, uvs, normals, indices, rpts, hangperpvec, roperad, -1.0)

	var arr = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = PoolVector3Array(verts)
	arr[Mesh.ARRAY_TEX_UV] = PoolVector2Array(uvs)
	arr[Mesh.ARRAY_NORMAL] = PoolVector3Array(normals)
	arr[Mesh.ARRAY_INDEX] = PoolIntArray(indices)
	var arr_mesh = ArrayMesh.new()
	arr_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	$RopeMesh.mesh = arr_mesh
	
	$RopeMesh.set_surface_material(0, ropematerialsolidcolor)
	verletgravity = orgverletgravity

	return middlenodes

func genrpsquareMDT(mdt, j, p, valong, hv, rad):
	var pv = -hv.cross(valong)
	var pdirs = [ pv+hv, pv-hv, -pv-hv, -pv+hv ]
	for i in range(cN):
		mdt.set_vertex(j+i, p+pdirs[i]*rad)
		mdt.set_vertex_normal(j+i, pdirs[i].normalized())

func ropeseqtubesurfaceMDT(mdt, inoff, rpts, hangperpvec, rad):
	var p0 = rpts[0]
	var p1 = rpts[1]
	var v0 = (p1 - p0).normalized()
	genrpsquareMDT(mdt, inoff, p0, v0, hangperpvec, rad)
	var v1 = v0
	for i in range(1, len(rpts)):
		var p2 = null
		var v2 = null
		if i+1 < len(rpts):
			p2 = rpts[i+1]
			v2 = (p2 - p1).normalized()
			v1 = (v0 + v2).normalized()
		genrpsquareMDT(mdt, inoff+i*cN, p1, v1, hangperpvec, rad)
		p0 = p1
		p1 = p2
		v1 = v2

func updatehangingrope_Verlet():
	var mdt = MeshDataTool.new()
	mdt.create_from_surface($RopeMesh.mesh, 0)

	var inoff = 0
	for nropeseq in nropeseqs:
		var rpts = [ ]
		for i in nropeseq:
			rpts.push_back(nverts[i])
		var rvec = rpts[-1] - rpts[0]
		var hangperpvec = Vector3(1,0,0) if Vector2(rvec.x, rvec.z).length() < 0.01 else Vector3(rvec.z, 0, -rvec.x).normalized()
		ropeseqtubesurfaceMDT(mdt, inoff, rpts, hangperpvec, roperad)
		inoff += len(rpts)*cN

	$RopeMesh.mesh.surface_remove(0)
	mdt.commit_to_surface($RopeMesh.mesh)

	for i in range(nodenamesAnchorN, len(nodenamesArr)):
		var xcn = get_parent().get_node("XCnodes").get_node(nodenamesArr[i])
		xcn.transform.origin = nverts[i]

const verletfriction = 0.9
const orgverletgravity = -0.005
var verletgravity = orgverletgravity
func verletprojstep():
	for i in range(nodenamesAnchorN, len(nverts)):
		var nvec = nverts[i] - old_nverts[i]
		old_nverts[i] = nverts[i] 
		var nv = nverts[i] + nvec*verletfriction
		if collidenormals[i] == null:
			nv += Vector3(0,verletgravity,0)
		else:
			nv = old_nverts[i]
		nverts[i] = nv

func verletpullstep():
	for k in range(len(nropeseqs)):
		var nropeseq = nropeseqs[k]
		var ropeseglenK = nropeseqseglens[k]
		var Lm = 0.0
		for j in range(1, len(nropeseq)):
			var i0 = nropeseq[j-1]
			var i1 = nropeseq[j]
			var vec = nverts[i1] - nverts[i0]
			var vecleng = vec.length()
			Lm += vecleng
			var h = 1.0 - ropeseglenK/vecleng
			if i1 < nodenamesAnchorN:
				if not (i0 < nodenamesAnchorN):
					nverts[i0] += h*vec
			elif i0 < nodenamesAnchorN:
					nverts[i1] += -h*vec
			else:
				nverts[i0] += (h/2)*vec
				nverts[i1] += -(h/2)*vec
		nropeseqLengsMeasured[k] = Lm

func verletcollidestep(raycast):
	var ncollisions = 0
	for i in range(nodenamesAnchorN, len(nverts)):
		raycast.transform.origin = prev_collideverts[i]
		raycast.cast_to = nverts[i] - prev_collideverts[i]
		raycast.force_raycast_update()
		if raycast.is_colliding():
			nverts[i] = raycast.get_collision_point()
			collidenormals[i] = raycast.get_collision_normal()
			ncollisions += 1
		else:
			prev_collideverts[i] = nverts[i]
	if ncollisions != 0:
		pass #print("verlet collidesteps ", ncollisions)
	
var prevverletstretch = -1
var verletiterations = 0
func verletstretch():
	var L = 0.0
	totalstretchropeleng = 0.0
	for i in range(len(nropeseqLengs)):
		L += nropeseqLengs[i]
		totalstretchropeleng += nropeseqLengsMeasured[i]
	return totalstretchropeleng/L

func verletmaxvelocity():
	var maxvel = 0.0
	for i in range(nodenamesAnchorN, len(nverts)):
		var nvec = nverts[i] - old_nverts[i]
		maxvel = max(maxvel, nvec.length())
	return maxvel
	
var N = 0
func iteratehangingrope_Verlet():
	verletprojstep()
	verletpullstep()
	updatehangingrope_Verlet()
	print("nropeseqLengsM ", nropeseqLengsMeasured)
	
