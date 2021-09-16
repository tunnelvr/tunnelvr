#!/usr/bin/env python
import http.server
import urllib.parse

class MyRequestHandler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        #for k, v in self.__dict__.items():
        #    print("  ", k, v)
        print(self.path)
        pr = urllib.parse.urlparse(self.path)
        if pr.query:
            qr = urllib.parse.parse_qs(pr.query)
            try:
                nseek = int(qr["seek"][0])
                nread = int(qr["read"][0])
                f = open(pr.path[1:], "rb")
                f.seek(nseek)
                message = f.read(nread)
                self.send_response(200)
                self.send_header('Content-type', 'application/octet-stream')
                self.send_header('Content-Length', str(nread))
                self.end_headers()
                self.wfile.write(message)
                return
            except KeyError:
                pass
            except IndexError:
                pass
            except ValueError:
                pass
                
        return http.server.SimpleHTTPRequestHandler.do_GET(self)

Handler = MyRequestHandler
server = http.server.socketserver.TCPServer(('0.0.0.0', 8080), Handler)

server.serve_forever()
