extends Spatial

const uvfacx = 0.2
const uvfacy = 0.4
const roperad = 0.02

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
	print("ropelength L=", L, " curveL=", p0u/uvfacx)

func updatehangingropepathsArrayMesh(nodepoints, onepathpairs):
	var middlenodes = [ ]
	if len(onepathpairs) == 0:
		$PathLines.mesh = null
		return middlenodes
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
			var N = int(max(L/0.1, 4))
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
	$RopeMesh.set_surface_material(0, materialsystem.pathlinematerial("rope"))
	return middlenodes
