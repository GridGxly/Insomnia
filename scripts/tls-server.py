# The stand-in api.github.com for tls-lab.sh. Logs every request with its
# Host header to requests.log. In "older" mode the Latest release is v0.0.9;
# in "redirect" mode api.github.com answers 302 to evil.test, whose answer
# names v9.9.9, so a client that follows the redirect reports v9.9.9.
import http.server, json, os, socket, ssl, sys, time

D = sys.argv[1]
LOG = os.path.join(D, "requests.log")


def mode():
    try:
        return open(os.path.join(D, "mode")).read().strip()
    except OSError:
        return "older"


def release(tag):
    return {"tag_name": tag, "prerelease": False, "draft": False, "published_at": "2026-10-01T00:00:00Z"}


class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        host = (self.headers.get("Host") or "").split(":")[0]
        m = mode()
        with open(LOG, "a") as f:
            f.write("%s mode=%s host=%s GET %s user-agent=%s\n" % (
                time.strftime("%H:%M:%SZ", time.gmtime()), m, host, self.path, self.headers.get("User-Agent")))
        if host == "api.github.com" and m == "redirect":
            self.send_response(302)
            self.send_header("Location", "https://evil.test" + self.path)
            self.send_header("Content-Length", "0")
            self.end_headers()
            return
        tag = "v9.9.9" if host == "evil.test" else "v0.0.9"
        body = json.dumps(release(tag) if self.path.endswith("/releases/latest") else [release(tag)]).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *args):
        pass


class Server(http.server.ThreadingHTTPServer):
    address_family = socket.AF_INET6

    def server_bind(self):
        self.socket.setsockopt(socket.IPPROTO_IPV6, socket.IPV6_V6ONLY, 0)
        super().server_bind()


server = Server(("::", 443), Handler)
ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
ctx.load_cert_chain(os.path.join(D, "leaf.pem"), os.path.join(D, "leaf.key"))
server.socket = ctx.wrap_socket(server.socket, server_side=True)
server.serve_forever()
