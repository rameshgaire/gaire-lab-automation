import requests
from datetime import datetime

# gaire.lab — verified IPs May 2026
# Run from: Mac (home network) or SYD-VM01 via n8n
targets = [
    # Internet connectivity check
    ("Internet - Google",   "https://google.com"),
    ("Internet - GitHub",   "https://github.com"),
    # Domain controllers (pinned to hypervisor hosts)
    ("SYD-DC01",            "http://10.10.10.10"),
    ("SYD-DC02",            "http://10.10.10.11"),
    # Cluster VMs
    ("SYD-VM01",            "http://10.10.10.12"),
    ("SYD-SQL01",           "http://10.10.10.15"),
    ("SYD-RDS01",           "http://10.10.10.21"),
    # Hypervisor hosts
    ("SYD-HV01",            "http://10.10.10.50"),
    ("SYD-HV02",            "http://10.10.10.51"),
    # Storage
    ("SYD-STOR01",          "http://10.10.10.60"),
    # Docker services on SYD-VM01
    ("Portainer",           "https://10.10.10.12:9443"),
    ("n8n",                 "http://10.10.10.12:5678"),
    ("Ollama",              "http://10.10.10.12:11434"),
    ("Open WebUI",          "http://10.10.10.12:3000"),
]

log_file = "health_log.txt"

def check_site(name, url):
    try:
        response = requests.get(url, timeout=5, verify=False)
        if response.status_code == 200:
            return f"[OK]      {name:<20} {url}"
        else:
            return f"[WARN]    {name:<20} {url} — status {response.status_code}"
    except Exception as e:
        return f"[ALERT]   {name:<20} {url} — UNREACHABLE"

timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
print(f"\n=== Health Check — {timestamp} ===")

with open(log_file, "a") as log:
    log.write(f"\n=== {timestamp} ===\n")
    for name, url in targets:
        result = check_site(name, url)
        print(result)
        log.write(result + "\n")

print(f"\nResults saved to {log_file}")