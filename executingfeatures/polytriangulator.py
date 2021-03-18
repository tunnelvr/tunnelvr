#!/usr/bin/env python

# docker run -it pymesh/pymesh
# docker run -it --rm -v `pwd`:/models pymesh/pymesh /models/polytriangulator.py abcd

# From https://github.com/PyMesh/PyMesh

import sys, numpy, json
import pymesh
print(sys.argv)

x = json.loads(open(sys.argv[1]).readline())
vertices = numpy.array(x[0])
faces = numpy.array(x[1])
mesh = pymesh.form_mesh(vertices, faces)
tol = float(sys.argv[2])
mesh, info = pymesh.split_long_edges(mesh, tol)
#print(info)

fout = open("temp.txt", "w")
fout.write(json.dumps([mesh.vertices.tolist(), mesh.faces.tolist()]))
fout.close()
os.rename("temp.txt", sys.argv[2])

# then for the flattener 
# wget https://github.com/FreeCAD/FreeCAD/releases/download/0.19_pre/FreeCAD_0.19-24267-Linux-Conda_glibc2.12-x86_64.AppImage

