#!/usr/bin/python

import os, sys

dump3dexe = '"C:\\Program Files (x86)\\Survex\\dump3d.exe"'
if sys.platform == "linux":
    dump3dexe = "dump3d"

sys.stdout.write("parse3ddmp_centreline find_executingfeatures")
