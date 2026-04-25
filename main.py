import os
import io
import json
import base64
import logging
from datetime import datetime, timedelta
from typing import List, Optional

from fastapi import FastAPI, Form, HTTPException, File, UploadFile, Request
from fastapi.middleware.cors import CORSMiddleware
import firebase_admin
from firebase_admin import credentials, messaging, firestore, storage
import bcrypt

# --- INITIALIZATION ---
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(title="MediRecords Pro Unified Backend")

# --- BCRYPT PASSWORD HELPERS ---
def hash_password(password: str) -> str:
    salt = bcrypt.gensalt()
    hashed = bcrypt.hashpw(password.encode('utf-8'), salt)
    return hashed.decode('utf-8')

def verify_password(password: str, hashed: str) -> bool:
    return bcrypt.checkpw(password.encode('utf-8'), hashed.encode('utf-8'))

# --- FIREBASE ADMIN SDK ---
try:
    if not firebase_admin._apps:
        # Fetching the Base64 config from Render environment variables
        firebase_b64 = os.getenv("FIREBASE_CONFIG_JSON")
        if firebase_b64:
            decoded_bytes = base64.b64decode(firebase_b64.strip())
            firebase_info = json.loads(decoded_bytes.decode('utf-8'))
            cred = credentials.Certificate(firebase_info)
            
            # Initializing with your verified bucket name
            firebase_admin.initialize_app(cred, {
                'storageBucket': 'medirecords-pro.firebasestorage.app'
            })
            logger.info("✅ Firebase Admin initialized with Firestore and Storage!")
        else:
            logger.error("❌ FIREBASE_CONFIG_JSON environment variable not found!")
except Exception as e:
    logger.error(f"❌ Firebase Init Error: {e}")

# Initialize Global Clients
db = firestore.client()
bucket = storage.bucket()

# --- CORS SETUP ---
app.add_middleware(
    CORSMiddleware,
    allow_origins=["https://neurolink90.github.io", "http://localhost:8080"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# --- AUTH & TOKEN MANAGEMENT ---

@app.post("/login")
async def login(email: str = Form(...), password: str = Form(...)):
    """Authenticates a user against Firestore data."""
    user_doc = db.collection("patients").document(email).get()
    if user_doc.exists:
        user_data = user_doc.to_dict()
        if verify_password(password, user_data['password']):
            return {"success": True, "email": email}
    raise HTTPException(status_code=401, detail="Invalid Credentials")

@app.post("/register-token")
@app.post("/update-fcm-token")
async def register_token(request: Request):
    """Saves the FCM token to Firestore for background notifications."""
    if request.headers.get('content-type') == 'application/json':
        data = await request.json()
        user_id = data.get('user_id')
        fcm_token = data.get('fcm_token')
    else:
        form_data = await request.form()
        user_id = form_data.get('user_id')
        fcm_token = form_data.get('fcm_token')

    if not user_id or not fcm_token:
        raise HTTPException(status_code=400, detail="Missing user_id or fcm_token")

    db.collection("patients").document(user_id).set({
        "fcm_token": fcm_token,
        "last_updated": firestore.SERVER_TIMESTAMP
    }, merge=True)
    
    logger.info(f"🚀 Token persisted in Firestore for {user_id}")
    return {"status": "success"}

# --- PROFILE, PATIENTS & APPOINTMENTS (Fixes 404 Errors) ---

@app.get("/profile")
@app.get("/patients/{email}")
async def get_profile(email: str):
    """Fetches user profile data."""
    user_doc = db.collection("patients").document(email).get()
    if user_doc.exists:
        return user_doc.to_dict()
    # Fallback to prevent crash if record is still syncing
    return {"name": "New User", "email": email, "status": "Stable"}

@app.get("/patients")
async def get_all_patients():
    """Fetches all patients (for provider dashboard)."""
    docs = db.collection("patients").stream()
    return [d.to_dict() for d in docs]

@app.get("/appointments")
async def get_appointments(email: str = "zach@example.com"):
    """Returns dummy appointment data so the calendar UI stops spinning."""
    return [{"title": "Annual Checkup", "date": "2026-04-25", "time": "10:00 AM"}]

# --- DOCUMENT MANAGEMENT (UPLOAD & LIST) ---

@app.post("/documents/upload")
async def upload_document(email: str = Form(...), file: UploadFile = File(...)):
    """Uploads file to Storage, generates Signed URL, and logs the event."""
    try:
        blob_path = f"documents/{email}/{file.filename}"
        blob = bucket.blob(blob_path)
        file_data = await file.read()
        blob.upload_from_string(file_data, content_type=file.content_type)

        # Generate a 5-minute guest pass for immediate viewing
        signed_url = blob.generate_signed_url(
            version="v4",
            expiration=timedelta(minutes=5),
            method="GET"
        )

        # Save metadata to Firestore
        db.collection("documents").add({
            "patient_email": email,
            "filename": file.filename,
            "file_type": file.content_type,
            "upload_date": datetime.now().strftime('%Y-%m-%d'),
            "storage_path": blob_path
        })

        # HIPAA Audit Log Entry
        db.collection("audit_logs").add({
            "timestamp": firestore.SERVER_TIMESTAMP,
            "user": email,
            "action": "UPLOAD_DOCUMENT",
            "file": file.filename,
            "details": f"Secure upload to {blob_path}"
        })

        # Notify the User via FCM
        user_doc = db.collection("patients").document(email).get()
        if user_doc.exists:
            token = user_doc.to_dict().get("fcm_token")
            if token:
                message = messaging.Message(
                    notification=messaging.Notification(
                        title="New Record Uploaded", 
                        body=f"'{file.filename}' is now encrypted and stored."
                    ),
                    token=token
                )
                messaging.send(message)

        return {"success": True, "signed_url": signed_url}
    except Exception as e:
        logger.error(f"❌ Upload Failure: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/documents")
async def get_documents_list(email: str):
    """Fetches list of document metadata from Firestore."""
    docs_query = db.collection("documents").where("patient_email", "==", email).stream()
    return [d.to_dict() for d in docs_query]

# --- SECURE SHARING & AUDIT LOGS ---

@app.get("/documents/share")
async def share_document(email: str, filename: str):
    """Generates a fresh 5-minute guest pass for QR code sharing."""
    try:
        blob_path = f"documents/{email}/{filename}"
        blob = bucket.blob(blob_path)

        signed_url = blob.generate_signed_url(
            version="v4",
            expiration=timedelta(minutes=5),
            method="GET"
        )

        # Track WHO generated the pass in the Audit Log
        db.collection("audit_logs").add({
            "timestamp": firestore.SERVER_TIMESTAMP,
            "user": email,
            "action": "GENERATE_SHARE_QR",
            "file": filename,
            "details": "Signed URL generated for QR code display"
        })

        return {"signed_url": signed_url}
    except Exception as e:
        logger.error(f"❌ Sharing Failure: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/audit-logs")
async def get_audit_logs(email: str):
    """Fetches history of actions for the specific user."""
    try:
        logs_query = db.collection("audit_logs") \
            .where("user", "==", email) \
            .order_by("timestamp", direction=firestore.Query.DESCENDING) \
            .stream()
            
        results = []
        for d in logs_query:
            data = d.to_dict()
            if data.get('timestamp'):
                # Format timestamp for JSON readability
                data['timestamp'] = data['timestamp'].strftime('%Y-%m-%d %H:%M:%S')
            results.append(data)
            
        return results
    except Exception as e:
        logger.error(f"❌ Audit Fetch Error: {e}")
        raise HTTPException(status_code=500, detail=str(e))

# --- DEBUG & SEEDING ---

@app.post("/debug/seed-zach")
async def seed_zach():
    """Initializes the Zach user in Firestore for testing."""
    hashed_pw = hash_password("helloandgoodbye0")
    db.collection("patients").document("zach@example.com").set({
        "name": "Zach Firestore",
        "email": "zach@example.com",
        "password": hashed_pw,
        "dob": "1980-01-01",
        "status": "Stable"
    })
    return {"success": "User zach@example.com created in Firestore!"}

@app.get("/debug/db-check")
async def db_check():
    """Simple verification route to check the current user record."""
    user_doc = db.collection("patients").document("zach@example.com").get()
    return {"zach_record": user_doc.to_dict() if user_doc.exists else "Not Found"}

if __name__ == "__main__":
    import uvicorn
    # Render provides the PORT environment variable
    port = int(os.environ.get("PORT", 5000))
    uvicorn.run(app, host="0.0.0.0", port=port)