import os
import json
import base64
import logging
from datetime import datetime, timedelta

from fastapi import FastAPI, Form, HTTPException, File, UploadFile, Request, Body, Depends
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
import stripe
import firebase_admin
from firebase_admin import credentials, messaging, firestore, storage, auth

# ── Logging ───────────────────────────────────────────────────────────────────
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(title="Daysman API")

# ── Stripe ────────────────────────────────────────────────────────────────────
stripe.api_key = os.getenv("STRIPE_SECRET_KEY")

# ── Firebase Admin Init ───────────────────────────────────────────────────────
try:
    if not firebase_admin._apps:
        firebase_b64 = os.getenv("FIREBASE_CONFIG_JSON")
        key_path     = "/etc/secrets/serviceAccountKey.json"

        if firebase_b64:
            decoded   = base64.b64decode(firebase_b64.strip())
            cred_info = json.loads(decoded.decode("utf-8"))
            cred      = credentials.Certificate(cred_info)
            firebase_admin.initialize_app(cred, {
                "storageBucket": "medirecords-pro.firebasestorage.app"
            })
            logger.info("✅ Firebase initialized from Base64 env var")
        elif os.path.exists(key_path):
            cred = credentials.Certificate(key_path)
            firebase_admin.initialize_app(cred, {
                "storageBucket": "medirecords-pro.firebasestorage.app"
            })
            logger.info(f"✅ Firebase initialized from {key_path}")
        else:
            logger.warning("⚠️ No Firebase credentials found.")
except Exception as e:
    logger.error(f"❌ Firebase Init Error: {e}")

try:
    db     = firestore.client()
    bucket = storage.bucket()
except Exception as e:
    db     = None
    bucket = None
    logger.warning(f"⚠️ Firebase clients offline: {e}")

# ── CORS ──────────────────────────────────────────────────────────────────────
app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "https://daysman.health",
        "https://api.daysman.health",
        "http://localhost:8080",
        "http://localhost:3000",
    ],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ── Auth Helper ───────────────────────────────────────────────────────────────
bearer_scheme = HTTPBearer()

def verify_owner(email: str, creds: HTTPAuthorizationCredentials):
    """Verifies the bearer token is a valid Firebase ID token belonging to `email`."""
    try:
        decoded = auth.verify_id_token(creds.credentials)
    except Exception:
        raise HTTPException(status_code=401, detail="Invalid or expired token")
    if decoded.get("email") != email:
        raise HTTPException(status_code=403, detail="Not authorized for this resource")

# ── Stripe Checkout ───────────────────────────────────────────────────────────
@app.post("/create-checkout-session")
async def create_checkout_session(
    data: dict = Body(...),
    creds: HTTPAuthorizationCredentials = Depends(bearer_scheme),
):
    if not stripe.api_key:
        raise HTTPException(status_code=500, detail="Stripe not configured")

    email = data.get("email", "")
    if not email:
        raise HTTPException(status_code=400, detail="Email required")

    verify_owner(email, creds)

    try:
        session = stripe.checkout.Session.create(
            payment_method_types=["card"],
            line_items=[{
                "price_data": {
                    "currency": "usd",
                    "product_data": {
                        "name": "Daysman — Personal Plan",
                        "description": (
                            "Unlimited health records, QR sharing, "
                            "medication tracker, appointment calendar, "
                            "emergency QR, biometric lock"
                        ),
                    },
                    "unit_amount": 999,
                    "recurring": {"interval": "month"},
                },
                "quantity": 1,
            }],
            mode="subscription",
            customer_email=email,
            metadata={"patient_email": email},
            success_url=(
                "https://api.daysman.health/payment-success"
                "?session_id={CHECKOUT_SESSION_ID}"
            ),
            cancel_url="https://api.daysman.health/payment-cancelled",
        )
        logger.info(f"✅ Stripe session created for {email}")
        return {"url": session.url}

    except stripe.error.StripeError as e:
        logger.error(f"❌ Stripe error: {e}")
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        logger.error(f"❌ Checkout session error: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/stripe-webhook")
async def stripe_webhook(request: Request):
    # NOTE: Intentionally NOT protected by verify_owner — this is called by
    # Stripe's servers, not the app, and has no Firebase ID token to send.
    # It is secured instead by Stripe's own webhook signature verification
    # below, which is the correct mechanism for a server-to-server webhook.
    webhook_secret = os.getenv("STRIPE_WEBHOOK_SECRET")
    payload        = await request.body()
    sig_header     = request.headers.get("stripe-signature")

    try:
        event = stripe.Webhook.construct_event(
            payload, sig_header, webhook_secret
        )
    except stripe.error.SignatureVerificationError:
        logger.error("❌ Stripe webhook signature failed")
        raise HTTPException(status_code=400, detail="Invalid signature")
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

    if event["type"] == "checkout.session.completed":
        session       = event["data"]["object"]
        patient_email = session.get("metadata", {}).get("patient_email")
        if patient_email and db:
            db.collection("patients").document(patient_email).set(
                {
                    "subscription_tier":    "personal",
                    "subscription_updated": firestore.SERVER_TIMESTAMP,
                },
                merge=True,
            )
            db.collection("audit_logs").add({
                "timestamp": firestore.SERVER_TIMESTAMP,
                "user":      patient_email,
                "action":    "SUBSCRIPTION_UPGRADED",
                "file":      "",
                "details":   "Upgraded to Daysman Personal via Stripe",
            })
            logger.info(f"✅ Subscription activated for {patient_email}")

    elif event["type"] in ("customer.subscription.deleted",
                           "customer.subscription.paused"):
        customer_id = event["data"]["object"].get("customer")
        if customer_id and db:
            try:
                customer      = stripe.Customer.retrieve(customer_id)
                patient_email = customer.get("email")
                if patient_email:
                    db.collection("patients").document(patient_email).set(
                        {"subscription_tier": "free"}, merge=True)
                    logger.info(f"⬇️ Subscription downgraded for {patient_email}")
            except Exception as e:
                logger.error(f"❌ Downgrade error: {e}")

    return {"status": "received"}


@app.get("/payment-success")
async def payment_success(session_id: str = ""):
    return {
        "message": "Payment successful! Open the Daysman app to access your subscription.",
        "session_id": session_id,
    }


@app.get("/payment-cancelled")
async def payment_cancelled():
    return {"message": "Payment cancelled. Return to the Daysman app to try again."}


# ── FCM Token ─────────────────────────────────────────────────────────────────
@app.post("/register-token")
@app.post("/update-fcm-token")
async def register_token(
    request: Request,
    creds: HTTPAuthorizationCredentials = Depends(bearer_scheme),
):
    if not db:
        raise HTTPException(status_code=500, detail="Database disconnected")

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

    verify_owner(user_id, creds)

    db.collection("patients").document(user_id).set(
        {"fcm_token": fcm_token, "last_updated": firestore.SERVER_TIMESTAMP},
        merge=True,
    )
    logger.info(f"🚀 FCM token saved for {user_id}")
    return {"status": "success"}


# ── Patient Profile ───────────────────────────────────────────────────────────
# Requires a valid Firebase ID token belonging to the requested email.
@app.get("/patients/{email}")
@app.get("/profile")
async def get_profile(
    email: str,
    creds: HTTPAuthorizationCredentials = Depends(bearer_scheme),
):
    verify_owner(email, creds)
    if not db:
        raise HTTPException(status_code=500, detail="Database disconnected")
    doc = db.collection("patients").document(email).get()
    if doc.exists:
        data = doc.to_dict()
        data.pop("password",  None)
        data.pop("fcm_token", None)
        return data
    return {"name": "New User", "email": email, "status": "Stable"}


@app.get("/appointments")
async def get_appointments(email: str = ""):
    # Intentionally unauthenticated and returns static dummy data — this is
    # the UptimeRobot ping target that keeps the Render free instance from
    # spinning down. It does NOT touch Firestore and is NOT the real
    # appointments data path (that's read directly via Firestore, see
    # /patients/{email}/appointments/{appId} in firestore.rules). Do not
    # add auth here or UptimeRobot will be unable to reach it.
    return [{"title": "Annual Checkup", "date": "2026-06-15", "time": "10:00 AM"}]


# ── Document Upload ───────────────────────────────────────────────────────────
@app.post("/documents/upload")
async def upload_document(
    email: str = Form(...),
    file: UploadFile = File(...),
    creds: HTTPAuthorizationCredentials = Depends(bearer_scheme),
):
    verify_owner(email, creds)
    if not db or not bucket:
        raise HTTPException(status_code=500, detail="Firebase disconnected")
    try:
        blob_path = f"documents/{email}/{file.filename}"
        blob      = bucket.blob(blob_path)
        file_data = await file.read()
        blob.upload_from_string(file_data, content_type=file.content_type)
        signed_url = blob.generate_signed_url(
            version="v4", expiration=timedelta(minutes=5), method="GET")

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
async def get_documents(
    email: str,
    creds: HTTPAuthorizationCredentials = Depends(bearer_scheme),
):
    verify_owner(email, creds)
    if not db:
        raise HTTPException(status_code=500, detail="Database disconnected")
    docs = db.collection("documents").where(
        "patient_email", "==", email).stream()
    return [d.to_dict() for d in docs]


# ── QR Share (short-lived, meant to be scanned by someone else) ───────────────
@app.get("/documents/share")
async def share_document(
    email: str,
    filename: str,
    creds: HTTPAuthorizationCredentials = Depends(bearer_scheme),
):
    verify_owner(email, creds)
    if not db or not bucket:
        raise HTTPException(status_code=500, detail="Firebase disconnected")
    try:
        blob_path  = f"documents/{email}/{filename}"
        blob       = bucket.blob(blob_path)
        signed_url = blob.generate_signed_url(
            version="v4", expiration=timedelta(minutes=5), method="GET")
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


# ── Document Download (patient downloading their own file to their device) ───
@app.get("/documents/download")
async def download_document(
    email: str,
    filename: str,
    creds: HTTPAuthorizationCredentials = Depends(bearer_scheme),
):
    verify_owner(email, creds)
    if not db or not bucket:
        raise HTTPException(status_code=500, detail="Firebase disconnected")
    try:
        blob_path  = f"documents/{email}/{filename}"
        blob       = bucket.blob(blob_path)
        signed_url = blob.generate_signed_url(
            version="v4", expiration=timedelta(minutes=5), method="GET")
        db.collection("audit_logs").add({
            "timestamp": firestore.SERVER_TIMESTAMP,
            "user":      email,
            "action":    "DOWNLOAD_DOCUMENT",
            "file":      filename,
            "details":   "Signed URL generated for direct device download",
        })
        return {"signed_url": signed_url}
    except Exception as e:
        logger.error(f"❌ Download error: {e}")
        raise HTTPException(status_code=500, detail=str(e))


# ── Audit Logs ────────────────────────────────────────────────────────────────
@app.get("/audit-logs")
async def get_audit_logs(
    email: str,
    creds: HTTPAuthorizationCredentials = Depends(bearer_scheme),
):
    verify_owner(email, creds)
    if not db:
        raise HTTPException(status_code=500, detail="Database disconnected")
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
                data["timestamp"] = data["timestamp"].strftime("%Y-%m-%d %H:%M:%S")
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

# ── REMOVED — do not restore ──────────────────────────────────────────────────
# /debug/db-check    — exposed raw Firestore patient data
# /debug/seed-zach   — hardcoded test credentials
# /patients (list-all) — unauthenticated dump of every patient's data