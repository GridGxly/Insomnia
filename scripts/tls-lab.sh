#!/bin/bash
# A local stand-in for api.github.com in a lab VM, for PR 117's checks: a
# throwaway test CA trusted in the VM's System keychain, a certificate for
# api.github.com and evil.test, and a Python HTTPS server on port 443.
#   tls-lab.sh up          make the CA and certificate, trust the CA, start the server
#   tls-lab.sh hosts-on    point api.github.com and evil.test at this VM in /etc/hosts
#   tls-lab.sh hosts-off   put /etc/hosts back
#   tls-lab.sh mode MODE   older: Latest is v0.0.9; redirect: every api.github.com
#                          request gets a 302 to evil.test, which answers v9.9.9
#   tls-lab.sh down        stop the server, untrust and delete the CA, restore everything
set -u
D="$HOME/lab-tls"
CN="Insomnia Lab Test CA"
flush() { sudo -n dscacheutil -flushcache; sudo -n killall -HUP mDNSResponder; }
case "${1:-}" in
up)
  rm -rf "$D" && mkdir -p "$D" && cd "$D" || exit 1
  cat > ca.cnf <<CNF
[req]
distinguished_name = dn
prompt = no
x509_extensions = v3_ca
[dn]
CN = $CN
[v3_ca]
basicConstraints = critical,CA:TRUE
keyUsage = critical,keyCertSign,cRLSign
subjectKeyIdentifier = hash
CNF
  cat > leaf.ext <<EXT
basicConstraints = CA:FALSE
keyUsage = critical,digitalSignature,keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = DNS:api.github.com,DNS:evil.test
EXT
  openssl req -x509 -newkey rsa:2048 -nodes -sha256 -days 7 -keyout ca.key -out ca.pem -config ca.cnf 2>/dev/null || exit 1
  openssl req -newkey rsa:2048 -nodes -keyout leaf.key -out leaf.csr -subj "/CN=api.github.com" 2>/dev/null || exit 1
  openssl x509 -req -in leaf.csr -CA ca.pem -CAkey ca.key -CAcreateserial -out leaf.pem -days 7 -sha256 -extfile leaf.ext 2>/dev/null || exit 1
  # Adding an admin trust setting asks for a password, which no one can
  # type over SSH; allow it for the test and put the rule back in down.
  sudo -n security authorizationdb read com.apple.trust-settings.admin > authdb.plist 2>/dev/null
  sudo -n security authorizationdb write com.apple.trust-settings.admin allow >/dev/null 2>&1
  sudo -n security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain ca.pem || exit 1
  echo older > mode
  sudo -n /usr/bin/python3 "$HOME/lab/tls-server.py" "$D" > server.out 2>&1 &
  sleep 2
  echo "CA trusted: $(security find-certificate -c "$CN" /Library/Keychains/System.keychain >/dev/null 2>&1 && echo yes || echo no); server: $(pgrep -f "lab/tls-server.py" | tr '\n' ' ')"
  ;;
hosts-on)
  sudo -n cp /etc/hosts "$D/hosts.orig"
  printf '127.0.0.1 api.github.com evil.test\n::1 api.github.com evil.test\n' | sudo -n tee -a /etc/hosts >/dev/null
  flush
  echo "api.github.com and evil.test point at this VM"
  ;;
hosts-off)
  [ -f "$D/hosts.orig" ] && sudo -n cp "$D/hosts.orig" /etc/hosts
  flush
  echo "/etc/hosts restored: $(grep -c -E 'api.github.com|evil.test' /etc/hosts) stand-in lines"
  ;;
mode)
  echo "$2" > "$D/mode"
  echo "stand-in mode: $2"
  ;;
down)
  sudo -n pkill -f "lab/tls-server.py"
  [ -f "$D/hosts.orig" ] && sudo -n cp "$D/hosts.orig" /etc/hosts && flush
  sudo -n security remove-trusted-cert -d "$D/ca.pem" 2>/dev/null
  sudo -n security delete-certificate -c "$CN" /Library/Keychains/System.keychain >/dev/null 2>&1
  if [ -s "$D/authdb.plist" ]; then
    sudo -n security authorizationdb write com.apple.trust-settings.admin < "$D/authdb.plist" >/dev/null 2>&1
  fi
  echo "server: $(pgrep -f "lab/tls-server.py" | wc -l | tr -d ' ') running; CA in keychain: $(security find-certificate -c "$CN" /Library/Keychains/System.keychain >/dev/null 2>&1 && echo yes || echo no); stand-in lines in /etc/hosts: $(grep -c -E 'api.github.com|evil.test' /etc/hosts); trust rule: $(sudo -n security authorizationdb read com.apple.trust-settings.admin 2>/dev/null | grep -A3 '<key>rule</key>' | grep -oE 'authenticate-admin|allow' | head -1)"
  ;;
*) echo "usage: tls-lab.sh up|hosts-on|hosts-off|mode MODE|down" >&2; exit 2 ;;
esac
