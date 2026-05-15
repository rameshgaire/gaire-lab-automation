import requests

# This is a test to see if a site is up
target = "https://google.com" 

try:
    response = requests.get(target)
    if response.status_code == 200:
        print(f"SUCCESS: {target} is online and responding!")
    else:
        print(f"WARNING: {target} returned status {response.status_code}")
except Exception as e:
    print(f"ALERT: Could not reach {target}. Error: {e}")