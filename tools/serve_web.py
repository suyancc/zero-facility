"""Loopback-only development preview. Serve only generated exports/web."""
from http.server import ThreadingHTTPServer,SimpleHTTPRequestHandler
from pathlib import Path
from functools import partial
import os
class Handler(SimpleHTTPRequestHandler):
    def send_head(self):
        path=self.translate_path(self.path)
        compressed=path+'.gz'
        if 'gzip' in self.headers.get('Accept-Encoding','') and os.path.isfile(compressed):
            f=open(compressed,'rb')
            self.send_response(200)
            self.send_header('Content-Type',self.guess_type(path))
            self.send_header('Content-Encoding','gzip')
            self.send_header('Vary','Accept-Encoding')
            self.send_header('Content-Length',str(os.fstat(f.fileno()).st_size))
            self.send_header('Cache-Control','no-cache')
            self.end_headers()
            return f
        return super().send_head()
root=Path('exports/web').resolve()
if not (root/'index.html').exists():raise SystemExit('Build Web first')
server=ThreadingHTTPServer(('127.0.0.1',8765),partial(Handler,directory=str(root)))
print('Gravity Courier preview: http://127.0.0.1:8765/ (gzip enabled)',flush=True)
server.serve_forever()
