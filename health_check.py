import requests
from datetime import datetime

# ADD MORE TARGETS — check your whole environment at once
targets = [
    "https://google.com",
    "https://github.com",
    "http://SYD-HV01-IP",     # your lab — replace with real IP
    "http://SYD-HV02-IP",     # your lab — replace with real IP
]

# LOG FILE — results saved to disk, not just printed
log_file = "health_log.txt"

def check_site(url):
    try:
        response = requests.get(url, timeout=5)
        if response.status_code == 200:
            return f"[OK]      {url}"
        else:
            return f"[WARN]    {url} — status {response.status_code}"
    except Exception as e:
        return f"[ALERT]   {url} — UNREACHABLE. {e}"

# RUN ALL CHECKS
timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
print(f"\n=== Health Check — {timestamp} ===")

with open(log_file, "a") as log:
    log.write(f"\n=== {timestamp} ===\n")
    for target in targets:
        result = check_site(target)
        print(result)
        log.write(result + "\n")

print(f"\nResults saved to {log_file}")