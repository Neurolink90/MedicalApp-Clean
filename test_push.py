import firebase_admin
from firebase_admin import credentials, messaging

# 1. Initialize Firebase Admin SDK
# Ensure 'serviceAccountKey.json' is in the same folder as this script!
try:
    cred = credentials.Certificate("serviceAccountKey.json")
    if not firebase_admin._apps:
        firebase_admin.initialize_app(cred)
    print("✅ Firebase Admin initialized.")
except Exception as e:
    print(f"❌ Initialization failed: {e}")

def send_force_push(target_token, title, body):
    print(f"Attempting to send notification to: {target_token}")
    
    # 2. Build the notification message
    message = messaging.Message(
        notification=messaging.Notification(
            title=title,
            body=body
        ),
        token=target_token
    )
    
    try:
        # 3. Send the message via Google's servers
        response = messaging.send(message)
        print(f"✅ Success! Message accepted by Google. ID: {response}")
    except Exception as e:
        # If this fails with "Requested entity was not found", it's because 
        # 'fcm_test_token_12345_67890' is a placeholder, not a real device.
        print(f"❌ Delivery failed: {e}")

if __name__ == "__main__":
    # --- YOUR INJECTED TOKEN FROM SCREENSHOT ---
    MY_TOKEN = "fcm_test_token_12345_67890" 
    
    send_force_push(
        MY_TOKEN, 
        "Emergency Alert", 
        "The backend pipeline is officially connected!"
    )