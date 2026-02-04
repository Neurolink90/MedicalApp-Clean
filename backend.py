from flask import Flask, request, jsonify
from werkzeug.exceptions import HTTPException
from flask_cors import CORS
import logging

# Initialize Flask app and enable CORS
app = Flask(__name__)
CORS(app)  # Allows all domains to access all routes (adjust as needed for production)

# Configure logging
logging.basicConfig(level=logging.INFO)
app.logger.setLevel(logging.INFO)

@app.before_request
def log_request_info():
    app.logger.info("Incoming %s request to %s", request.method, request.url)
    if request.data:
        app.logger.info("Request data: %s", request.data)

# Root Endpoint
@app.route("/")
def index():
    return jsonify(message="Hello from Flask")

# ✅ Updated Login Route
@app.route('/login', methods=['POST'])
def login():
    data = request.get_json()  # Parse JSON payload
    email = data.get('email')
    password = data.get('password')
    
    # ✅ Dummy authentication logic (Replace with real authentication)
    if email == "john@example.com" and password == "securepassword":
        return jsonify(success=True, message="Login successful", email=email)
    else:
        return jsonify(success=False, message="Invalid credentials"), 401

# 404 Error Handling
@app.errorhandler(404)
def not_found(e):
    app.logger.warning("404 Not Found: %s", request.url)
    return jsonify(error="Not Found"), 404

# Global Error Handling
@app.errorhandler(Exception)
def handle_exception(e):
    if isinstance(e, HTTPException):
        app.logger.error("HTTPException occurred: %s", e.description)
        return jsonify(error=e.name, message=e.description), e.code
    app.logger.error("Unhandled Exception: %s", e, exc_info=True)
    return jsonify(error="Internal Server Error"), 500

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=True)
    # Add these imports to your existing backend.py
from medical_code_library import MedicalDataLibrary, Patient, MedicalRecord
import os

# Initialize your library
library = MedicalDataLibrary()

# Mock data initialization (In a real app, this would be a database)
def init_mock_data():
    john = Patient(name="John Doe", dob="1980-01-01", ssn="123-45-6789", 
                   address="123 Main St", email="john@example.com", phone="555-1234")
    # Adding a sample record
    record = MedicalRecord(date="2025-11-28", provider="Dr. Smith", 
                           specialty="Cardiology", content="Follow-up on Metformin dosage.")
    john.add_medical_record(record)
    library.add_patient(john)

init_mock_data()

@app.route('/appointments', methods=['GET'])
def get_appointments():
    # In a real app, you'd verify the user's session/token first
    # For now, we return mock events formatted for your Flutter calendar
    events = {
        "2025-11-28T00:00:00Z": [
            {'title': 'Dr. Smith – Cardiology', 'time': '10:30 AM', 'type': 'appointment'},
            {'title': 'Metformin 500mg', 'time': '8:00 AM', 'type': 'medication'},
        ],
        "2025-11-30T00:00:00Z": [
            {'title': 'Blood Work – LabCorp', 'time': '9:00 AM', 'type': 'appointment'},
        ],
    }
    return jsonify(events)
    
@app.route('/patients', methods=['GET'])
def get_patients():
    # Retrieve all patients from your MedicalDataLibrary
    patient_list = []
    for ssn, patient in library.patients.items():
        patient_list.append({
            "name": patient.name,
            "dob": patient.dob.strftime('%Y-%m-%d'),
            "mrn": f"MRN-{ssn[-4:]}", # Using last 4 of SSN as MRN
            "status": "Stable"
        })
    return jsonify(patient_list)








