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

# --- INITIALIZATION ---
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(title="MediRecords Pro Unified Backend")

# --- FIREBASE ADMIN SDK ---
try:
    if not firebase_admin._apps:
        firebase_b64 = os.getenv("FIREBASE_CONFIG_JSON")
        if firebase_b64:
            decoded_bytes = base64.b64decode(firebase_b64.strip())
            firebase_info = json.loads(decoded_bytes.decode('utf-8'))
            cred = credentials.Certificate(firebase_info)
            # Initialize with Storage bucket
            firebase_admin.initialize_app(cred, {
                'storageBucket': 'medirecords-pro.firebasestorage.app'
            })
            logger.info("✅ Firebase Admin initialized with Firestore and Storage!")
except Exception as e:
    logger.error(f"❌ Firebase Init Error: {e}")

# Clients
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

# --- 1. THE PIVOT TO PERSISTENCE (FIRESTORE) ---

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

    # Save to Firestore (Persistent across restarts)
    db.collection("patients").document(user_id).set({
        "fcm_token": fcm_token,
        "last_updated": firestore.SERVER_TIMESTAMP
    }, merge=True)
    
    logger.info(f"🚀 Token persisted in Firestore for {user_id}")
    return {"status": "success"}

# --- 2. SECURE FILE LOGIC & 3. AUDIT LOGGING ---

@app.post("/documents/upload")
async def upload_document(email: str = Form(...), file: UploadFile = File(...)):
    try:
        # 1. Upload file to Firebase Storage
        blob_path = f"documents/{email}/{file.filename}"
        blob = bucket.blob(blob_path)
        file_data = await file.read()
        blob.upload_from_string(file_data, content_type=file.content_type)

        # 2. Generate a 5-minute Signed URL
        signed_url = blob.generate_signed_url(
            version="v4",
            expiration=timedelta(minutes=5),
            method="GET"
        )

        # 3. Save metadata to Firestore
        doc_ref = db.collection("documents").document()
        doc_ref.set({
            "patient_email": email,
            "filename": file.filename,
            "file_type": file.content_type,
            "upload_date": firestore.SERVER_TIMESTAMP,
            "storage_path": blob_path
        })

        # 4. AUDIT LOG (HIPAA Compliance)
        audit_ref = db.collection("audit_logs").document()
        audit_ref.set({
            "timestamp": firestore.SERVER_TIMESTAMP,
            "user": email,
            "action": "UPLOAD_DOCUMENT",
            "file": file.filename,
            "details": f"File uploaded to {blob_path}"
        })

        # 5. Trigger FCM Notification
        user_doc = db.collection("patients").document(email).get()
        if user_doc.exists:
            token = user_doc.to_dict().get("fcm_token")
            if token:
                message = messaging.Message(
                    notification=messaging.Notification(
                        title="New Medical Record", 
                        body=f"Document '{file.filename}' is now secured."
                    ),
                    token=token
                )
                messaging.send(message)

        return {
            "success": True, 
            "signed_url": signed_url,
            "message": "File secured and logged."
        }

    except Exception as e:
        logger.error(f"Upload Failure: {e}")
        raise HTTPException(status_code=500, detail=str(e))

# --- DEBUG & HELPERS ---

@app.get("/debug/db-check")
async def db_check(email: str = "zach@example.com"):
    user_doc = db.collection("patients").document(email).get()
    if user_doc.exists:
        return {"zach_record": user_doc.to_dict()}
    return {"detail": "Not Found in Firestore"}

@app.get("/documents")
async def get_documents_list(email: str = "zach@example.com"):
    docs_query = db.collection("documents").where("patient_email", "==", email).stream()
    return [d.to_dict() for d in docs_query]

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=int(os.environ.get("PORT", 5000)))