from flask import Flask, request, jsonify, send_file
from flask_cors import CORS
import sqlite3
import os
import io
import logging
import firebase_admin
from firebase_admin import credentials, messaging
from werkzeug.security import generate_password_hash, check_password_hash
from datetime import datetime

app = Flask(__name__)

# Explicitly allows your GitHub Pages site to send files and data
CORS(app, resources={r"/*": {"origins": ["https://neurolink90.github.io", "http://localhost:*"]}})

logging.basicConfig(level=logging.INFO)
DB_NAME = "medical_app.db"

# --- FIREBASE INITIALIZATION ---
# This looks for the service account key you download from the Firebase Console
try:
    if not firebase_admin._apps:
        cred = credentials.Certificate("serviceAccountKey.json")
        firebase_admin.initialize_app(cred)
    logging.info("Firebase Admin SDK initialized successfully.")
except Exception as e:
    logging.warning(f"Firebase Admin could not be initialized. Push notifications disabled: {e}")

def get_db():
    conn = sqlite3.connect(DB_NAME)
    conn.row_factory = sqlite3.Row
    return conn

def init_db():
    conn = get_db()
    cursor = conn.cursor()
    
    # 1. Create Core Tables
    cursor.execute('CREATE TABLE IF NOT EXISTS patients (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, dob TEXT, ssn TEXT, address TEXT, email TEXT UNIQUE NOT NULL, phone TEXT, password TEXT NOT NULL)')
    cursor.execute('CREATE TABLE IF NOT EXISTS medications (id INTEGER PRIMARY KEY AUTOINCREMENT, patient_email TEXT, name TEXT, dosage TEXT, frequency TEXT, reminder_time TEXT)')
    cursor.execute('CREATE TABLE IF NOT EXISTS vitals (id INTEGER PRIMARY KEY AUTOINCREMENT, patient_email TEXT, type TEXT, value TEXT, unit TEXT, timestamp TEXT)')
    cursor.execute('CREATE TABLE IF NOT EXISTS documents (id INTEGER PRIMARY KEY AUTOINCREMENT, patient_email TEXT, filename TEXT, file_type TEXT, upload_date TEXT, file_data BLOB)')
    cursor.execute('CREATE TABLE IF NOT EXISTS medical_records (id INTEGER PRIMARY KEY AUTOINCREMENT, patient_email TEXT, date TEXT, provider TEXT, specialty TEXT, content TEXT)')
    
    # 2. Create Messages Table
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS messages (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            sender_email TEXT,
            receiver_email TEXT,
            content TEXT,
            timestamp TEXT
        )
    ''')

    # 3. Safely add the Push Notification Token column
    try:
        cursor.execute('ALTER TABLE patients ADD COLUMN fcm_token TEXT')
    except sqlite3.OperationalError:
        pass # Column already exists

    # 4. PERMANENT SEED FOR ZACH
    cursor.execute('SELECT * FROM patients WHERE email = ?', ("zach@example.com",))
    if not cursor.fetchone():
        hashed_pw = generate_password_hash("helloandgoodbye0")
        cursor.execute('''
            INSERT INTO patients (name, email, password, dob, address, phone) 
            VALUES (?, ?, ?, ?, ?, ?)
        ''', ("Zach SQLite", "zach@example.com", hashed_pw, "1980-01-01", "123 Main St", "555-1234"))
    
    conn.commit()
    conn.close()

init_db()

# --- NOTIFICATION ENGINE ---

def send_push_notification(email, title, body):
    """Retrieves a user's device token and sends a push notification."""
    conn = get_db()
    user = conn.execute('SELECT fcm_token FROM patients WHERE email = ?', (email,)).fetchone()
    conn.close()
    
    if user and user['fcm_token']:
        message = messaging.Message(
            notification=messaging.Notification(title=title, body=body),
            token=user['fcm_token']
        )
        try:
            response = messaging.send(message)
            logging.info(f"Notification sent successfully: {response}")
        except Exception as e:
            logging.error(f"FCM Send Error: {e}")

# --- AUTH & PROFILES ---

@app.route('/register', methods=['POST'])
def register():
    data = request.get_json()
    hashed_pw = generate_password_hash(data.get('password'))
    conn = get_db()
    try:
        conn.execute('INSERT INTO patients (name, email, password, dob) VALUES (?, ?, ?, ?)', 
                     (data.get('name'), data.get('email'), hashed_pw, data.get('dob', '1980-01-01')))
        conn.commit()
        return jsonify(success=True)
    except:
        return jsonify(success=False, message="User already exists"), 400
    finally:
        conn.close()

@app.route('/login', methods=['POST'])
def login():
    data = request.get_json()
    conn = get_db()
    user = conn.execute('SELECT * FROM patients WHERE email = ?', (data.get('email'),)).fetchone()
    conn.close()
    if user and check_password_hash(user['password'], data.get('password')):
        return jsonify(success=True, email=user['email'])
    return jsonify(success=False), 401

@app.route('/patients', methods=['GET'])
def get_patients():
    conn = get_db()
    users = conn.execute('SELECT name, dob, ssn, email FROM patients').fetchall()
    conn.close()
    patient_list = []
    for user in users:
        ssn_val = user['ssn'] if user['ssn'] else "000-00-0000"
        patient_list.append({
            "name": user['name'],
            "dob": user['dob'],
            "mrn": f"MRN-{ssn_val[-4:]}",
            "status": "Stable",
            "email": user['email']
        })
    return jsonify(patient_list)

@app.route('/profile', methods=['GET', 'POST'])
def handle_profile():
    email = request.args.get('email', 'zach@example.com')
    conn = get_db()
    if request.method == 'GET':
        user = conn.execute('SELECT * FROM patients WHERE email = ?', (email,)).fetchone()
        conn.close()
        if user:
            return jsonify({"name": user['name'], "address": user['address'], "phone": user['phone'], "email": user['email'], "dob": user['dob']})
        return jsonify(message="User not found"), 404
    else:
        data = request.get_json()
        conn.execute('UPDATE patients SET name=?, address=?, phone=? WHERE email=?', (data['name'], data['address'], data['phone'], email))
        conn.commit()
        conn.close()
        return jsonify(success=True)

# --- TRACKERS & APPOINTMENTS ---

@app.route('/appointments', methods=['GET'])
def get_appointments():
    email = request.args.get('email', 'zach@example.com')
    conn = get_db()
    records = conn.execute('SELECT * FROM medical_records WHERE patient_email = ?', (email,)).fetchall()
    conn.close()
    formatted = {}
    for r in records:
        date_key = f"{r['date']}T00:00:00Z"
        if date_key not in formatted: formatted[date_key] = []
        formatted[date_key].append({'title': f"{r['provider']} - {r['specialty']}", 'type': 'appointment'})
    return jsonify(formatted)

@app.route('/medications', methods=['GET', 'POST'])
def handle_medications():
    email = request.args.get('email', 'zach@example.com')
    conn = get_db()
    if request.method == 'GET':
        meds = conn.execute('SELECT * FROM medications WHERE patient_email = ?', (email,)).fetchall()
        conn.close()
        return jsonify([dict(m) for m in meds])
    else:
        data = request.get_json()
        conn.execute('INSERT INTO medications (patient_email, name, dosage, frequency, reminder_time) VALUES (?, ?, ?, ?, ?)',
                     (email, data['name'], data['dosage'], data['frequency'], data['reminder_time']))
        conn.commit()
        conn.close()
        return jsonify(success=True)

@app.route('/vitals', methods=['GET', 'POST'])
def handle_vitals():
    email = request.args.get('email', 'zach@example.com')
    conn = get_db()
    if request.method == 'GET':
        vitals = conn.execute('SELECT * FROM vitals WHERE patient_email = ? ORDER BY timestamp DESC', (email,)).fetchall()
        conn.close()
        return jsonify([dict(v) for v in vitals])
    else:
        data = request.get_json()
        conn.execute('INSERT INTO vitals (patient_email, type, value, unit, timestamp) VALUES (?, ?, ?, ?, ?)',
                     (email, data['type'], data['value'], data['unit'], datetime.now().strftime('%Y-%m-%d %H:%M')))
        conn.commit()
        conn.close()
        return jsonify(success=True)

# --- DOCUMENTS & SHARING ---

@app.route('/documents/upload', methods=['POST'])
def upload_document():
    file = request.files.get('file')
    email = request.form.get('email', 'zach@example.com')
    if file:
        file_data = file.read()
        conn = get_db()
        conn.execute('INSERT INTO documents (patient_email, filename, file_type, upload_date, file_data) VALUES (?, ?, ?, ?, ?)',
                     (email, file.filename, file.content_type, datetime.now().strftime('%Y-%m-%d'), file_data))
        conn.commit()
        conn.close()
        
        # --- TRIGGER THE PUSH NOTIFICATION ---
        send_push_notification(email, "New Medical Record", f"'{file.filename}' has been added to your vault.")
        
        return jsonify(success=True)
    return jsonify(success=False), 400

@app.route('/documents', methods=['GET'])
def get_documents():
    email = request.args.get('email', 'zach@example.com')
    conn = get_db()
    docs = conn.execute('SELECT id, filename, upload_date FROM documents WHERE patient_email = ?', (email,)).fetchall()
    conn.close()
    return jsonify([dict(doc) for doc in docs])

@app.route('/share/<int:doc_id>', methods=['GET'])
def share_document(doc_id):
    conn = get_db()
    doc = conn.execute('SELECT filename, file_data, file_type FROM documents WHERE id = ?', (doc_id,)).fetchone()
    conn.close()
    if doc:
        return send_file(io.BytesIO(doc['file_data']), mimetype=doc['file_type'], as_attachment=False, download_name=doc['filename'])
    return "<h1>Document Not Found</h1>", 404

# --- COMMUNICATION MODULE ---

@app.route('/messages', methods=['GET', 'POST'])
def handle_messages():
    email = request.args.get('email', 'zach@example.com')
    conn = get_db()
    if request.method == 'GET':
        msgs = conn.execute('SELECT * FROM messages WHERE sender_email = ? OR receiver_email = ? ORDER BY timestamp ASC', (email, email)).fetchall()
        conn.close()
        return jsonify([dict(m) for m in msgs])
    else:
        data = request.get_json()
        conn.execute('INSERT INTO messages (sender_email, receiver_email, content, timestamp) VALUES (?, ?, ?, ?)',
                     (email, data['receiver_email'], data['content'], datetime.now().strftime('%Y-%m-%d %H:%M')))
        conn.commit()
        conn.close()
        return jsonify(success=True)

# --- PUSH NOTIFICATIONS ---

@app.route('/update-fcm-token', methods=['POST'])
def update_fcm_token():
    data = request.get_json()
    email = data.get('email')
    token = data.get('token')
    
    conn = get_db()
    conn.execute('UPDATE patients SET fcm_token = ? WHERE email = ?', (token, email))
    conn.commit()
    conn.close()
    return jsonify(success=True)

# --- PROVIDER DASHBOARD ---

@app.route('/provider/dashboard', methods=['GET'])
def provider_dashboard():
    conn = get_db()
    summary = conn.execute('''
        SELECT p.name, p.email, p.dob, 
        (SELECT value FROM vitals WHERE patient_email = p.email AND type = 'Blood Pressure' ORDER BY timestamp DESC LIMIT 1) as last_bp
        FROM patients p
    ''').fetchall()
    conn.close()
    return jsonify([dict(row) for row in summary])

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.environ.get("PORT", 5000)))