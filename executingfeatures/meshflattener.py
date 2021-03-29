#!/usr/bin/env python

# This code needs to be piped into the executable file:
# /home/julian/executables/FreeCAD_0.19-24267-Linux-Conda_glibc2.12-x86_64.AppImage

# fetch from: wget https://github.com/FreeCAD/FreeCAD/releases/download/0.19_pre/FreeCAD_0.19-24267-Linux-Conda_glibc2.12-x86_64.AppImage


import sys, numpy, json, os, shutil, subprocess

#freecadappimage = "/home/julian/executables/FreeCAD_0.19-24267-Linux-Conda_glibc2.12-x86_64.AppImage"
#surfacemeshfile = "/home/julian/.local/share/godot/app_userdata/tunnelvr_v0.5/executingfeatures/surfacemesh.txt"
#flatmeshfile = "/home/julian/.local/share/godot/app_userdata/tunnelvr_v0.5/executingfeatures/flattenedmesh.txt"

freecadappimage = sys.argv[1]
surfacemeshfile = sys.argv[2]
flatmeshfile = sys.argv[3]

tempfile = os.path.join(os.path.dirname(flatmeshfile), "temp.txt")

fccode = """import flatmesh
import sys, numpy, json, os

surfacemeshfile = "%s"
tempfile = "%s"

x = json.loads(open(surfacemeshfile).readline())
vertices = numpy.array(x[0])*1000
faces = numpy.array(x[1]).reshape((-1, 3))
flattener = flatmesh.FaceUnwrapper(vertices, faces)
flattener.findFlatNodes(10, 0.95)
fnodes = flattener.ze_nodes*0.001

fout = open(tempfile, "w")
print("writing %%d ze_nodes " %% (len(fnodes)))
print("to", tempfile)
fout.write(json.dumps(fnodes.tolist()))
fout.close()
""" % (surfacemeshfile, tempfile)

a = subprocess.run([freecadappimage, "-c"], input=fccode.encode(), capture_output=True)
print(a.stderr.decode())
print(a.stdout)
shutil.move(tempfile, flatmeshfile)


#/home/julian/godotgames/tunnelvr/executingfeatures/meshflattener.py /home/julian/executables/FreeCAD_0.19-24267-Linux-Conda_glibc2.12-x86_64.AppImage /home/julian/.local/share/godot/app_userdata/tunnelvr_v0.5/executingfeatures/surfacemesh.txt /home/julian/.local/share/godot/app_userdata/tunnelvr_v0.5/executingfeatures/flattenedmesh.txt

