from flask import Flask, request, jsonify, send_file
from flask_cors import CORS
import sqlite3
import os
import io
import logging
from werkzeug.security import generate_password_hash, check_password_hash
from datetime import datetime

app = Flask(__name__)
CORS(app)

logging.basicConfig(level=logging.INFO)
DB_NAME = "medical_app.db"

# --- DATABASE HELPERS ---

def get_db():
    conn = sqlite3.connect(DB_NAME)
    conn.row_factory = sqlite3.Row
    return conn

def init_db():
    conn = get_db()
    cursor = conn.cursor()
    
    # 1. Users Table
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS patients (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            dob TEXT,
            ssn TEXT UNIQUE,
            address TEXT,
            email TEXT UNIQUE NOT NULL,
            phone TEXT,
            password TEXT NOT NULL
        )
    ''')

    # 2. Medical Records Table (Structured Data)
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS medical_records (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            patient_email TEXT NOT NULL,
            date TEXT,
            provider TEXT,
            specialty TEXT,
            content TEXT,
            FOREIGN KEY(patient_email) REFERENCES patients(email)
        )
    ''')
    
    # 3. NEW: Documents Table (Files/BLOBs)
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS documents (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            patient_email TEXT NOT NULL,
            filename TEXT NOT NULL,
            file_type TEXT,
            upload_date TEXT,
            file_data BLOB,
            FOREIGN KEY(patient_email) REFERENCES patients(email)
        )
    ''')
    
    conn.commit()
    
    # Seed Demo User
    cursor.execute('SELECT * FROM patients WHERE email = ?', ("john@example.com",))
    if not cursor.fetchone():
        app.logger.info("Seeding demo user...")
        hashed_pw = generate_password_hash("securepassword")
        cursor.execute('''
            INSERT INTO patients (name, dob, ssn, address, email, phone, password)
            VALUES (?, ?, ?, ?, ?, ?, ?)
        ''', ("John Doe", "1980-01-01", "123-45-6789", "123 Main St", "john@example.com", "555-1234", hashed_pw))
        conn.commit()
    
    conn.close()

init_db()

# --- ROUTES ---

@app.route("/")
def health_check():
    return jsonify({"status": "healthy"})

@app.route('/login', methods=['POST'])
def login():
    data = request.get_json()
    email = data.get('email')
    password = data.get('password')
    
    conn = get_db()
    user = conn.execute('SELECT * FROM patients WHERE email = ?', (email,)).fetchone()
    conn.close()

    if user and check_password_hash(user['password'], password):
        return jsonify(success=True, message="Login successful")
    return jsonify(success=False, message="Invalid credentials"), 401

# --- NEW: DOCUMENT ROUTES ---

@app.route('/documents/upload', methods=['POST'])
def upload_document():
    if 'file' not in request.files:
        return jsonify(success=False, message="No file part"), 400
    
    file = request.files['file']
    patient_email = request.form.get('email', 'john@example.com') # Default to John for now

    if file.filename == '':
        return jsonify(success=False, message="No selected file"), 400

    if file:
        filename = file.filename
        file_type = file.content_type
        file_data = file.read() # Read raw bytes
        upload_date = datetime.now().strftime('%Y-%m-%d')

        conn = get_db()
        try:
            conn.execute('''
                INSERT INTO documents (patient_email, filename, file_type, upload_date, file_data)
                VALUES (?, ?, ?, ?, ?)
            ''', (patient_email, filename, file_type, upload_date, file_data))
            conn.commit()
            return jsonify(success=True, message="File uploaded successfully!")
        except Exception as e:
            app.logger.error(f"Upload Error: {e}")
            return jsonify(success=False, message="Database error"), 500
        finally:
            conn.close()

@app.route('/documents', methods=['GET'])
def get_documents():
    """List all documents for the user."""
    conn = get_db()
    docs = conn.execute('SELECT id, filename, file_type, upload_date FROM documents WHERE patient_email = ?', ("john@example.com",)).fetchall()
    conn.close()

    doc_list = []
    for doc in docs:
        doc_list.append({
            "id": doc['id'],
            "filename": doc['filename'],
            "type": doc['file_type'],
            "date": doc['upload_date']
        })
    return jsonify(doc_list)

@app.route('/documents/<int:doc_id>', methods=['GET'])
def download_document(doc_id):
    """Download a specific document by ID."""
    conn = get_db()
    doc = conn.execute('SELECT filename, file_data FROM documents WHERE id = ?', (doc_id,)).fetchone()
    conn.close()

    if doc:
        return send_file(
            io.BytesIO(doc['file_data']),
            download_name=doc['filename'],
            as_attachment=False # Open in browser/app instead of saving
        )
    return jsonify(message="File not found"), 404

# --- EXISTING ROUTES (Profile, Patients, etc.) ---
# (Kept short for brevity - assume previous Profile/Patient logic is here or just use your previous file)

@app.route('/profile', methods=['GET'])
def get_profile():
    conn = get_db()
    user = conn.execute('SELECT * FROM patients WHERE email = ?', ("john@example.com",)).fetchone()
    conn.close()
    if user:
        # Simple decode helper
        def clean(val): return val if val else ""
        return jsonify({
            "name": clean(user['name']), "address": clean(user['address']),
            "phone": clean(user['phone']), "email": clean(user['email']), "dob": user['dob']
        })
    return jsonify(message="User not found"), 404

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.environ.get("PORT", 5000)))