#!/usr/bin/env python

# docker run -it pymesh/pymesh
# docker run -it --rm -v `pwd`:/models pymesh/pymesh /models/polytriangulator.py abcd
# docker run -it --rm -v /home/julian/.local/share/godot/app_userdata/tunnelvr_v0.5/executingfeatures:/data -v /home/julian/godotgames/tunnelvr/executingfeatures:/code pymesh/pymesh /code/polytriangulator.py /data/polygon.txt 0.250000 /data/mesh.txt

# From https://github.com/PyMesh/PyMesh

import sys, numpy, json, os, shutil
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
print("writing %d verts and %d faces" % (len(mesh.vertices), len(mesh.faces)))
fout.write(json.dumps([mesh.vertices.tolist(), mesh.faces.flatten().tolist()]))
fout.close()
shutil.move("temp.txt", sys.argv[3])


# then for the flattener 
# wget https://github.com/FreeCAD/FreeCAD/releases/download/0.19_pre/FreeCAD_0.19-24267-Linux-Conda_glibc2.12-x86_64.AppImage

