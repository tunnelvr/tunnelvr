tool
extends EditorScript

# *******
# Control-Shift X to run this code in the editor
# *******

var d = "/home/julian/data/pointclouds/potreetests/outdir/"


class ONode:
	var name = "r"
	var depth = 0
	var boundingBox = null
	var childMask = 0
	var spacing = 0
	var children = { }
	var isnotloaded = true
	var isleaf = false
	var numPoints = 0
	var byteOffset = 0
	var byteSize = 0
	
	func readroot(metadata):
		isnotloaded = true
		byteOffset = 0
		byteSize = metadata["hierarchy"]["firstChunkSize"]
		var mdmin = Vector3(metadata["boundingBox"]["min"][0], metadata["boundingBox"]["min"][1], metadata["boundingBox"]["min"][2])
		var mdmax = Vector3(metadata["boundingBox"]["max"][0], metadata["boundingBox"]["max"][1], metadata["boundingBox"]["max"][2])
		var mdoffset = Vector3(metadata["offset"][0], metadata["offset"][1], metadata["offset"][2])
		boundingBox = AABB(mdmin-mdoffset, mdmax-mdmin)
		spacing = metadata["spacing"]
		name = "r"
	
	func initsubnode(parent, childIndex):
		name = parent.name + str(childIndex)
		depth = parent.depth+1
		var pbb = parent.boundingBox
		boundingBox = AABB(Vector3(pbb.position.x + (pbb.size.x/2 if childIndex & 0b0001 else 0), 
								   pbb.position.y + (pbb.size.y/2 if childIndex & 0b0010 else 0),
								   pbb.position.z + (pbb.size.z/2 if childIndex & 0b0100 else 0)), 
						   pbb.size/2)
		spacing = parent.spacing/2
		parent.children[childIndex] = self

	func readbuff22(fhierarchy, frontnode):
		var ntype = fhierarchy.get_8()
		#if frontnode and self.depth != 0:
		#	assert not self.isnotloaded
		#	assert self.childMask == buff22[1]
		#	assert self.numPoints == struct.unpack("i", buff22[2:6])[0]
		childMask = fhierarchy.get_8()
		numPoints = fhierarchy.get_32()
		byteOffset = fhierarchy.get_64()
		byteSize = fhierarchy.get_64()
		isnotloaded = (ntype == 2)
		isleaf = (ntype == 1)
		assert (isnotloaded or (self.isleaf == (self.childMask == 0)))

	func loadtreechunk(fhierarchy):
		assert (isnotloaded)
		fhierarchy.seek(byteOffset)
		var nodes = [ self ]
		for i in range(byteSize/22):
			var pnode = nodes[i]
			pnode.readbuff22(fhierarchy, i==0)
			if not pnode.isnotloaded:
				for childIndex in range(8):
					if ((1 << childIndex) & pnode.childMask):
						var cnode = ONode.new()
						cnode.initsubnode(pnode, childIndex)
						nodes.append(cnode)
		return nodes.slice(1, len(nodes))

func _run():
	var a = Vector3(10,20,30)
	var b = Vector3(0.1, 0.9, 3)
	print(a*b)
	
func D_run():
	var fmetadata = File.new()
	fmetadata.open(d+"metadata.json", File.READ)
	var metadata = parse_json(fmetadata.get_as_text())
	var mdoffset = Vector3(metadata["offset"][0], metadata["offset"][1], metadata["offset"][2])
	var mdscale = metadata["scale"]

	var fhierarchy = File.new()
	fhierarchy.open(d+"hierarchy.bin", File.READ)
	assert(len(metadata["attributes"]) == 1)
	#metadata["attributes"], metadata["boundingBox"], mdoffset, mdscale

	var root = ONode.new()
	root.readroot(metadata)
	print(root.boundingBox)

	var allnodes = [root]
	var numbytes = 0
	var i = 0
	while i < len(allnodes):
		var node = allnodes[i]
		if node.isnotloaded:
			var nodes = node.loadtreechunk(fhierarchy)
			allnodes.append_array(nodes)
		numbytes += node.byteSize
		i += 1
	print(numbytes, " ", i)
