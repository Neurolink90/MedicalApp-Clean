import os
import json
import base64
import logging
from datetime import datetime, timedelta

from fastapi import FastAPI, Form, HTTPException, File, UploadFile, Request
from fastapi.middleware.cors import CORSMiddleware
import firebase_admin
from firebase_admin import credentials, messaging, firestore, storage, auth

# ── Logging ───────────────────────────────────────────────────────────────────
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(title="MediRecords Pro API")

# ── Firebase Admin Init ───────────────────────────────────────────────────────
try:
    if not firebase_admin._apps:
        firebase_b64 = os.getenv("FIREBASE_CONFIG_JSON")
        if not firebase_b64:
            raise ValueError("FIREBASE_CONFIG_JSON env var not set")
        decoded   = base64.b64decode(firebase_b64.strip())
        cred_info = json.loads(decoded.decode("utf-8"))
        cred      = credentials.Certificate(cred_info)
        firebase_admin.initialize_app(cred, {
            "storageBucket": "medirecords-pro.firebasestorage.app"
        })
        logger.info("✅ Firebase Admin initialized")
except Exception as e:
    logger.error(f"❌ Firebase Init Error: {e}")

db     = firestore.client()
bucket = storage.bucket()

# ── CORS ──────────────────────────────────────────────────────────────────────
app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "https://neurolink90.github.io",
        "http://localhost:8080",
        "http://localhost:3000",
    ],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ── FCM Token Registration ────────────────────────────────────────────────────
@app.post("/register-token")
@app.post("/update-fcm-token")
async def register_token(request: Request):
    """Accepts JSON or Form data and saves FCM token to Firestore."""
    content_type = request.headers.get("content-type", "")
    if "application/json" in content_type:
        data      = await request.json()
        user_id   = data.get("user_id")
        fcm_token = data.get("fcm_token")
    else:
        form      = await request.form()
        user_id   = form.get("user_id")
        fcm_token = form.get("fcm_token")

    if not user_id or not fcm_token:
        raise HTTPException(status_code=400, detail="Missing user_id or fcm_token")

    db.collection("patients").document(user_id).set(
        {"fcm_token": fcm_token, "last_updated": firestore.SERVER_TIMESTAMP},
        merge=True,
    )
    logger.info(f"🚀 FCM token saved for {user_id}")
    return {"status": "success"}

# ── Patient Profile ───────────────────────────────────────────────────────────
@app.get("/patients/{email}")
@app.get("/profile")
async def get_profile(email: str):
    doc = db.collection("patients").document(email).get()
    if doc.exists:
        data = doc.to_dict()
        data.pop("password", None)
        data.pop("fcm_token", None)
        return data
    return {"name": "New User", "email": email, "status": "Stable"}

@app.get("/patients")
async def get_all_patients():
    docs = db.collection("patients").stream()
    results = []
    for d in docs:
        data = d.to_dict()
        data.pop("password", None)
        data.pop("fcm_token", None)
        results.append(data)
    return results

@app.get("/appointments")
async def get_appointments(email: str = ""):
    # Kept as a lightweight UptimeRobot ping target
    return [{"title": "Annual Checkup", "date": "2026-06-15", "time": "10:00 AM"}]

# ── Document Upload ───────────────────────────────────────────────────────────
@app.post("/documents/upload")
async def upload_document(email: str = Form(...), file: UploadFile = File(...)):
    try:
        blob_path = f"documents/{email}/{file.filename}"
        blob      = bucket.blob(blob_path)
        file_data = await file.read()
        blob.upload_from_string(file_data, content_type=file.content_type)

        signed_url = blob.generate_signed_url(
            version="v4",
            expiration=timedelta(minutes=5),
            method="GET",
        )

        db.collection("documents").add({
            "patient_email": email,
            "filename":      file.filename,
            "file_type":     file.content_type,
            "upload_date":   datetime.now().strftime("%Y-%m-%d"),
            "storage_path":  blob_path,
        })

        db.collection("audit_logs").add({
            "timestamp": firestore.SERVER_TIMESTAMP,
            "user":      email,
            "action":    "UPLOAD_DOCUMENT",
            "file":      file.filename,
            "details":   f"Encrypted upload to {blob_path}",
        })

        # FCM notification
        user_doc = db.collection("patients").document(email).get()
        if user_doc.exists:
            token = user_doc.to_dict().get("fcm_token")
            if token:
                try:
                    messaging.send(messaging.Message(
                        notification=messaging.Notification(
                            title="New Record Uploaded",
                            body=f"'{file.filename}' is now encrypted and stored.",
                        ),
                        token=token,
                    ))
                except Exception as fcm_err:
                    logger.warning(f"⚠️ FCM send failed: {fcm_err}")

        return {"success": True, "signed_url": signed_url}

    except Exception as e:
        logger.error(f"❌ Upload error: {e}")
        raise HTTPException(status_code=500, detail=str(e))

# ── Document List ─────────────────────────────────────────────────────────────
@app.get("/documents")
async def get_documents(email: str):
    docs = db.collection("documents").where(
        "patient_email", "==", email).stream()
    return [d.to_dict() for d in docs]

# ── QR Share ──────────────────────────────────────────────────────────────────
@app.get("/documents/share")
async def share_document(email: str, filename: str):
    try:
        blob_path  = f"documents/{email}/{filename}"
        blob       = bucket.blob(blob_path)
        signed_url = blob.generate_signed_url(
            version="v4",
            expiration=timedelta(minutes=5),
            method="GET",
        )

        db.collection("audit_logs").add({
            "timestamp": firestore.SERVER_TIMESTAMP,
            "user":      email,
            "action":    "GENERATE_SHARE_QR",
            "file":      filename,
            "details":   "5-minute signed URL generated for QR share",
        })

        return {"signed_url": signed_url}
    except Exception as e:
        logger.error(f"❌ Share error: {e}")
        raise HTTPException(status_code=500, detail=str(e))

# ── Audit Logs ────────────────────────────────────────────────────────────────
@app.get("/audit-logs")
async def get_audit_logs(email: str):
    try:
        query = (
            db.collection("audit_logs")
            .where("user", "==", email)
            .order_by("timestamp", direction=firestore.Query.DESCENDING)
            .stream()
        )
        results = []
        for d in query:
            data = d.to_dict()
            if data.get("timestamp"):
                data["timestamp"] = data["timestamp"].strftime(
                    "%Y-%m-%d %H:%M:%S")
            results.append(data)
        return results
    except Exception as e:
        logger.error(f"❌ Audit log error: {e}")
        raise HTTPException(status_code=500, detail=str(e))

# ── Entrypoint ────────────────────────────────────────────────────────────────
if __name__ == "__main__":
    import uvicorn
    port = int(os.environ.get("PORT", 5000))
    uvicorn.run(app, host="0.0.0.0", port=port)

# ── REMOVED (do not restore) ──────────────────────────────────────────────────
# /debug/db-check    — exposed raw Firestore patient record
# /debug/seed-zach   — created hardcoded test user with known password