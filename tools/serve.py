# 本地静态服务：python3 tools/serve.py <端口> [目录，默认 build/web]
# 不加 COOP/COEP（和 GitHub Pages 一致；无线程版导出不需要）。加 no-cache 便于调试。
import http.server, socketserver, sys, os
d = sys.argv[2] if len(sys.argv) > 2 else os.path.join(os.path.dirname(__file__), '..', 'build', 'web')
os.chdir(d)
class H(http.server.SimpleHTTPRequestHandler):
    extensions_map = {**http.server.SimpleHTTPRequestHandler.extensions_map, '.wasm': 'application/wasm', '.pck': 'application/octet-stream', '.js': 'text/javascript'}
    def end_headers(self):
        self.send_header('Cache-Control', 'no-cache')
        super().end_headers()
    def log_message(self, *a):
        pass
socketserver.ThreadingTCPServer.allow_reuse_address = True
with socketserver.ThreadingTCPServer(('0.0.0.0', int(sys.argv[1])), H) as s:
    s.serve_forever()
