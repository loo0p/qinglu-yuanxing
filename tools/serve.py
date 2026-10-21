# 候选代码·灰盒：本地静态服务（无线程版导出，不需要 COOP/COEP；这里仍加上，便于以后切线程版）
import http.server, socketserver, sys, os
os.chdir(os.path.join(os.path.dirname(__file__), '..', 'build', 'web'))
class H(http.server.SimpleHTTPRequestHandler):
    extensions_map = {**http.server.SimpleHTTPRequestHandler.extensions_map, '.wasm': 'application/wasm', '.pck': 'application/octet-stream', '.js': 'text/javascript'}
    def end_headers(self):
        self.send_header('Cross-Origin-Opener-Policy', 'same-origin')
        self.send_header('Cross-Origin-Embedder-Policy', 'require-corp')
        self.send_header('Cache-Control', 'no-cache')
        super().end_headers()
socketserver.ThreadingTCPServer.allow_reuse_address = True
with socketserver.ThreadingTCPServer(('0.0.0.0', int(sys.argv[1])), H) as s:
    s.serve_forever()
