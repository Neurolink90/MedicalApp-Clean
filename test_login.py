import requests

url = "http://127.0.0.1:5000/login"  # Change to 10.0.2.2 for emulator
payload = {"email": "john@example.com", "password": "securepassword"}
headers = {"Content-Type": "application/json"}

response = requests.post(url, json=payload, headers=headers)

print("Status Code:", response.status_code)
print("Response:", response.json())
