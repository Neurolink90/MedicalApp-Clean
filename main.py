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
        firebase_b64 = os.getenv("FIREBASE_CONFIG_JSON")
        if firebase_b64:
            decoded_bytes = base64.b64decode(firebase_b64.strip())
            firebase_info = json.loads(decoded_bytes.decode('utf-8'))
            cred = credentials.Certificate(firebase_info)
            firebase_admin.initialize_app(cred, {
                'storageBucket': 'medirecords-pro.firebasestorage.app'
            })
            logger.info("✅ Firebase Admin initialized with Firestore and Storage!")
except Exception as e:
    logger.error(f"❌ Firebase Init Error: {e}")

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

# --- AUTH & TOKEN ---

@app.post("/login")
async def login(email: str = Form(...), password: str = Form(...)):
    # Now looks in Firestore instead of SQLite
    user_doc = db.collection("patients").document(email).get()
    if user_doc.exists:
        user_data = user_doc.to_dict()
        if verify_password(password, user_data['password']):
            return {"success": True, "email": email}
    
    raise HTTPException(status_code=401, detail="Invalid Credentials")

@app.post("/register-token")
@app.post("/update-fcm-token")
async def register_token(request: Request):
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

# --- DATA SAVING & UPLOADING ---

@app.post("/documents/upload")
async def upload_document(email: str = Form(...), file: UploadFile = File(...)):
    try:
        blob_path = f"documents/{email}/{file.filename}"
        blob = bucket.blob(blob_path)
        file_data = await file.read()
        blob.upload_from_string(file_data, content_type=file.content_type)

        signed_url = blob.generate_signed_url(
            version="v4",
            expiration=timedelta(minutes=5),
            method="GET"
        )

        db.collection("documents").add({
            "patient_email": email,
            "filename": file.filename,
            "upload_date": firestore.SERVER_TIMESTAMP,
            "storage_path": blob_path
        })

        return {"success": True, "signed_url": signed_url}
    except Exception as e:
        logger.error(f"Upload Failure: {e}")
        raise HTTPException(status_code=500, detail=str(e))

# --- DEBUG & MIGRATION ROUTES ---

@app.post("/debug/seed-zach")
async def seed_zach():
    """Creates the Zach user in Firestore so login works."""
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
    user_doc = db.collection("patients").document("zach@example.com").get()
    return {"zach_record": user_doc.to_dict() if user_doc.exists else "Not Found"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=int(os.environ.get("PORT", 5000)))