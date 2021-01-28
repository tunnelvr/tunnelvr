# Run this and then we can use POST to upload scripts and download STL ascii files

from http.server import BaseHTTPRequestHandler, HTTPServer
import time
import urllib.parse
from cadquery import cqgi, exporters
import io

hostName = "localhost"
serverPort = 8080

def convscript(user_script):
    parsed_script = cqgi.parse(user_script)
    build_result = parsed_script.build(build_parameters={}, build_options={} )
    if build_result.results:
        b = build_result.results[0]
        s = io.StringIO()
        exporters.exportShape(b.shape, "STL", s, 0.01)
        res = s.getvalue()
    else:
        res = str(build_result.exception)
    return res


class MyServer(BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        self.send_header("Content-type", "text/html")
        self.end_headers()
        self.wfile.write(bytes("<html><head><title>https://pythonbasics.org</title></head>", "utf-8"))
        self.wfile.write(bytes("<p>Request: %s</p>" % self.path, "utf-8"))
        self.wfile.write(bytes("<body>", "utf-8"))
        self.wfile.write(bytes("<p>This is an example web server.</p>", "utf-8"))
        self.wfile.write(bytes('<form method="POST"><textarea name="t">result = cq.Workplane("front").box(2.0, 2.0, 0.5); show_object(result)</textarea><input type="submit" value="Submit"></form>', "utf-8"))
        self.wfile.write(bytes("</body></html>", "utf-8"))

    def do_POST(self):
        content_len = int(self.headers.get('Content-Length'))
        post_body = self.rfile.read(content_len)
        post_data = urllib.parse.parse_qs(post_body)
        print(post_data)
        self.send_response(200)
        self.send_header("Content-type", "text/plain")
        self.end_headers()
        t = post_data[b"t"][0]
        print([t])
        self.wfile.write(bytes(convscript(t.decode()), "utf-8"))


if __name__ == "__main__":        
    webServer = HTTPServer((hostName, serverPort), MyServer)
    print("Server started http://%s:%s" % (hostName, serverPort))

    try:
        webServer.serve_forever()
    except KeyboardInterrupt:
        pass

    webServer.server_close()
    print("Server stopped.")
