#!/usr/bin/env python

# docker run -it pymesh/pymesh
# docker run -it --rm -v `pwd`:/models pymesh/pymesh /models/polytriangulator.py abcd

# From https://github.com/PyMesh/PyMesh

import sys, os
import pymesh
#print(dir(pymesh))
print(sys.argv)
fout = open("/models/junk", "w")
fout.write("%s\n" % str(os.listdir()))
fout.write("%s\n" % str(sys.argv))
fout.close()



