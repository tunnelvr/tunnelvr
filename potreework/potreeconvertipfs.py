import os, sys, re, subprocess, tempfile

potreeconverterexe = 'PotreeConverter'

from optparse import OptionParser
parser = OptionParser()
parser.add_option("-l", "--laz",        dest="inlaz",      metavar="FILE",                     help="Input laz file")
parser.add_option("-o", "--outdir",     dest="outdir",     metavar="DIR",                      help="Potree files directory")
parser.add_option("-r", "--repaired",   dest="repaired",   metavar="FILE",                     help="Repaired laz file")
parser.add_option("-p", "--generate-page", dest="generatepage", action="store_true", default=False, help="Generate potree page")
parser.add_option("-F", "--ipfs",       dest="ipfs",       action="store_true", default=False, help="IPFS add potree files")
parser.add_option("-s", "--reffile",    dest="reffile",    metavar="FILE",                     help="File to store result IPFS ref")

parser.description = "Convert survex LAZ file to potree bin data, fixing errors"
parser.epilog = "python potreconversion.py thing.laz --ipfs\n"

options, args = parser.parse_args()

# push command line args that look like files into file options 
if len(args) >= 1 and re.search("\.la[sz]$", args[0]) and not options.inlaz:
    options.inlaz = args.pop(0)
if len(args) >= 1 and not options.outdir:
    options.outdir = args.pop(0)
if not options.inlaz:
    parser.print_help()
    exit(1)
if not options.outdir:
    if options.ipfs:
        TDoutdir = tempfile.TemporaryDirectory()
        options.outdir = TDoutdir.name
    else:
        options.outdir = os.path.splitext(options.inlaz)[0]
if os.path.exists(options.outdir) and not os.path.isdir(options.outdir):
    print("Outdir", options.outdir, "is a file")
    exit(1)

inlaz = os.path.abspath(options.inlaz)
outdir = os.path.abspath(options.outdir)
        
print("Reading: ", inlaz, "  writing: ", outdir)
args = [potreeconverterexe, "--source", inlaz, "--outdir", outdir, "--attributes", "position_cartesian", "--attributes", "rgb", "--method", "poisson"]
if options.generatepage:
    args.append("--generate-page")
    args.append("index")
print(args)
p = subprocess.run(args, capture_output=True)
if p.returncode != 0 and b"invalid bounding box" in p.stdout:
    print(p.stdout.decode())
    print("sterr", p.stderr.decode())
    print("bad bounding box, try again")
    import laspy
    lp = laspy.open(options.inlaz, "r").read()
    if not options.repaired:
        lz = tempfile.NamedTemporaryFile(suffix=os.path.splitext(options.inlaz)[1])
        lzname = lz.name
    else:
        lzname = options.repaired
    print("Writing to temp file", lzname)
    lpf = laspy.open(lzname, "w", header=lp.header)
    lpf.write_points(lp.points)
    lpf.close()
    args[2] = lzname
    p = subprocess.run(args, capture_output=True)
    print(p.stdout.decode())
    print("sterr", p.stderr.decode())

else:
    print(p.stdout.decode())
    print("sterr", p.stderr.decode())
if p.returncode != 0:
    print("Conversion failed somewhere")
    exit(1)
    
if options.ipfs:
    unwantedlogfile = os.path.join(outdir, "log.txt")
    if os.path.isfile(unwantedlogfile):
        os.remove(unwantedlogfile)
    assert options.generatepage or os.path.isfile(os.path.join(outdir, "metadata.json"))

    import ipfshttpclient
    client = ipfshttpclient.connect()
    print("Adding the potreefiles to IPFS")
    res = client.add(outdir, recursive=options.generatepage)
    for r in res:
        print(r)
    ipfsmetadatafile = '{ "ipfsrefpotreemetadatafile": "%s/metadata.json" }' % res[-1]["Hash"]
    print(ipfsmetadatafile)
    if options.reffile:
        fout = open(options.reffile, "w")
        fout.write(ipfsmetadatafile)
        fout.close()
        
    
#http://localhost:8080/ipfs/QmVoYVqKQiqHCQqEdTMcePpu6u8XWsBYtBQL4Uh7CzncSR/metadata.json
#http://bafybeido4v3yhfyxlau6za4ywej4dvplbm7efw7qx6uunzvaeoe2m44xuy.ipfs.localhost:8080/metadata.json
#http://100.123.107.21:8080/ipfs/QmcTV4tny6gfC5Zvb3mL51dYEUvtNywbVoGU2rwqWsPpbJ/metadata.json
#nix build -f ./default.nix --arg file ./astralship.laz --experimental-features 'impure-derivations ca-derivations flakes nix-command' --store $(pwd)/local -L^C   nix build -f ./default.nix --arg file ./astralship.laz --experimental-features 'impure-derivations ca-derivations flakes nix-command' --store $(pwd)/local -L
Qmd4gpa3xrskJUDWLiY9bZNtdFVrtF3N3ePYKFECgvap66
