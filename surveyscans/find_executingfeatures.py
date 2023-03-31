#!/usr/bin/python

import os, sys, subprocess

res = [ os.path.splitext(os.path.split(__file__)[1])[0] ]  # "find_executingfeatures"

dump3dexe = '"C:\\Program Files (x86)\\Survex\\dump3d.exe"'
if sys.platform == "linux":
    dump3dexe = "dump3d"

try:
    p = subprocess.run(["dump3d", "--help"], capture_output=True)
    if p.returncode == 0:
        res.append("parse3ddmp_centreline")
except (FileNotFoundError, PermissionError) as f:
    pass

try:
    p = subprocess.run(["PotreeConverter", "--help"], capture_output=True)
    if p.returncode == 0:
        res.append("PotreeConverter")
except (FileNotFoundError, PermissionError) as f:
    pass

try:
    p = subprocess.run(["caddy", "version"], capture_output=True)
    if p.returncode == 0:
        res.append("caddy")
except (FileNotFoundError, PermissionError) as f:
    pass


try:
    import laspy
    if laspy.LazBackend.Laszip:
        res.append("python_laspy")
except (ModuleNotFoundError, AttributeError) as e:
    pass

try:
    import ipfshttpclient
    client = ipfshttpclient.connect()
    res.append("python_ipfshttpclient")
except (ModuleNotFoundError) as e:
    raise

if set(["PotreeConverter", "python_laspy", "python_ipfshttpclient"]).issubset(res):
    res.append("potreeconvertipfs_files")

sys.stdout.write("FOUNDEXECUTINGFEATURES: %s" % " ".join(res))
