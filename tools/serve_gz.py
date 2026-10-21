# 本地模拟 GitHub Pages：.bin/.json 按 Content-Encoding: gzip 发（v0.7.1 的线上空白立绘就是这样才复现）
# 用法：python3 tools/serve_gz.py 8813 build/web
import http.server, gzip, os, sys
root=sys.argv[2]; port=int(sys.argv[1])
class H(http.server.SimpleHTTPRequestHandler):
    def __init__(s,*a,**k): super().__init__(*a,directory=root,**k)
    def log_message(s,*a): pass
    def do_GET(s):
        p=s.translate_path(s.path.split('?')[0])
        if os.path.isfile(p) and p.endswith(('.bin','.json')) and 'gzip' in s.headers.get('Accept-Encoding',''):
            d=gzip.compress(open(p,'rb').read())
            s.send_response(200); s.send_header('Content-Type','application/octet-stream'); s.send_header('Content-Encoding','gzip'); s.send_header('Content-Length',str(len(d))); s.end_headers(); s.wfile.write(d); return
        return super().do_GET()
http.server.ThreadingHTTPServer(('127.0.0.1',port),H).serve_forever()
