import socket
import subprocess
import platform
from datetime import datetime

# gaire.lab - Enterprise-style monitoring
# Uses ICMP ping + TCP port checks - correct protocols per server role

targets = [
    # Internet checks - HTTP is correct here
    {"name": "Internet - Google",   "type": "http",  "host": "google.com",      "port": 443},
    {"name": "Internet - GitHub",   "type": "http",  "host": "github.com",       "port": 443},
    # Domain Controllers - check LDAP port 389
    {"name": "SYD-DC01",            "type": "tcp",   "host": "10.10.10.10",      "port": 389},
    {"name": "SYD-DC02",            "type": "tcp",   "host": "10.10.10.11",      "port": 389},
    # SQL Server - check SQL port 1433
    {"name": "SYD-SQL01",           "type": "tcp",   "host": "10.10.10.15",      "port": 1433},
    # RDS - check RDP port 3389
    {"name": "SYD-RDS01",           "type": "tcp",   "host": "10.10.10.21",      "port": 3389},
    # Hypervisor hosts - check WinRM port 5985
    {"name": "SYD-HV01",            "type": "tcp",   "host": "10.10.10.50",      "port": 5985},
    {"name": "SYD-HV02",            "type": "tcp",   "host": "10.10.10.51",      "port": 5985},
    # Storage - check SMB port 445
    {"name": "SYD-STOR01",          "type": "tcp",   "host": "10.10.10.60",      "port": 445},
    # Docker services on SYD-VM01 - HTTP is correct
    {"name": "Portainer",           "type": "http",  "host": "10.10.10.12",      "port": 9443},
    {"name": "n8n",                 "type": "http",  "host": "10.10.10.12",      "port": 5678},
    {"name": "Ollama",              "type": "http",  "host": "10.10.10.12",      "port": 11434},
    {"name": "Open WebUI",          "type": "http",  "host": "10.10.10.12",      "port": 3000},
]

log_file = "health_log.txt"

def check_tcp(host, port, timeout=5):
    """Check if a TCP port is open - works for any service"""
    try:
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(timeout)
        result = sock.connect_ex((host, port))
        sock.close()
        return result == 0
    except Exception:
        return False

def check_http(host, port, timeout=5):
    """Check if an HTTP/HTTPS service responds"""
    import urllib.request
    import ssl
    try:
        protocol = "https" if port in [443, 9443] else "http"
        url = f"{protocol}://{host}:{port}"
        ctx = ssl.create_default_context()
        ctx.check_hostname = False
        ctx.verify_mode = ssl.CERT_NONE
        req = urllib.request.urlopen(url, timeout=timeout, context=ctx)
        return True
    except Exception:
        return False

def check_target(target):
    if target["type"] == "tcp":
        ok = check_tcp(target["host"], target["port"])
    else:
        ok = check_http(target["host"], target["port"])
    
    status = "OK   " if ok else "ALERT"
    return f"[{status}] {target['name']:<25} {target['host']}:{target['port']}"

timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
print(f"\n=== gaire.lab Health Check — {timestamp} ===")

results = []
alerts = []

with open(log_file, "a") as log:
    log.write(f"\n=== {timestamp} ===\n")
    for target in targets:
        result = check_target(target)
        print(result)
        log.write(result + "\n")
        results.append(result)
        if "ALERT" in result:
            alerts.append(target["name"])

print(f"\n{'='*50}")
print(f"Total: {len(targets)} | OK: {len(targets)-len(alerts)} | ALERTS: {len(alerts)}")
if alerts:
    print(f"Failed: {', '.join(alerts)}")
print(f"Results saved to {log_file}")