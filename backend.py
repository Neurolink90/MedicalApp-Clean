from flask import Flask, request, jsonify
from flask_cors import CORS
from medical_code_library import MedicalDataLibrary, Patient, MedicalRecord
import os
import logging

app = Flask(__name__)
CORS(app)

# Initialize the library
library = MedicalDataLibrary()

# Mock data initialization using your library classes
def init_mock_data():
    # Adding the demo patient you use for login
    john = Patient(
        name="John Doe", 
        dob="1980-01-01", 
        ssn="123-45-6789", 
        address="123 Main St", 
        email="john@example.com", 
        phone="555-1234"
    )
    
    # Adding sample records (these will appear in your Flutter Calendar)
    john.add_medical_record(MedicalRecord(
        date="2026-02-10", 
        provider="Dr. Smith", 
        specialty="Cardiology", 
        content="Follow-up on heart rate"
    ))
    john.add_medical_record(MedicalRecord(
        date="2026-02-15", 
        provider="LabCorp", 
        specialty="Diagnostics", 
        content="Standard blood panel"
    ))
    
    library.add_patient(john)

init_mock_data()

# --- ROUTES ---

@app.route('/forgot-password', methods=['POST'])
def forgot_password():
    data = request.get_json()
    email = data.get('email')
    
    # Use your library to find the patient by email (simulated)
    if email == "john@example.com":
        # In a real app, you'd generate a real PDF. Here we mock the call.
        library.send_email_with_attachment(
            to_email=email,
            subject="Password Reset Request",
            body="Attached are your instructions to reset your MediRecords Pro password.",
            file_path="reset_instructions.pdf" # Mock path
        )
        return jsonify(success=True, message="Reset instructions sent to your email.")
    
    return jsonify(success=False, message="Email not found."), 404
    
@app.route('/forgot-password', methods=['POST'])
def forgot_password():
    """
    Simulates a password reset request.
    It verifies the email, triggers the encryption library, 
    and mocks sending an email with an attachment.
    """
    data = request.get_json()
    email = data.get('email')

    if not email:
        return jsonify(success=False, message="Email is required"), 400

    # In a real app, you would query your database for this user.
    # For the demo, we use the John Doe email from your library.
    if email == "john@example.com":
        try:
            # Using your library logic to simulate sending the reset file
            library.send_email_with_attachment(
                to_email=email,
                subject="MediRecords Pro - Password Reset",
                body="Hello, please find the instructions for your password reset attached.",
                file_path="reset_instructions.pdf" # Mock filename
            )
            return jsonify(success=True, message="Reset instructions sent to your email.")
        except Exception as e:
            app.logger.error(f"Error in forgot_password: {e}")
            return jsonify(success=False, message="Failed to process request"), 500

    return jsonify(success=False, message="Email address not found"), 404
    
@app.route("/")
def health_check():
    return jsonify({
        "status": "healthy",
        "fernet_key_set": os.environ.get('FERNET_KEY') is not None
    })

@app.route('/login', methods=['POST'])
def login():
    data = request.get_json()
    if data.get('email') == "john@example.com" and data.get('password') == "securepassword":
        return jsonify(success=True, message="Login successful")
    return jsonify(success=False, message="Invalid credentials"), 401

@app.route('/patients', methods=['GET'])
def get_patients():
    # Formats the library data for your MedicalRecordsScreen ListView
    patient_list = []
    for ssn, patient in library.patients.items():
        patient_list.append({
            "name": patient.name,
            "dob": patient.dob.strftime('%Y-%m-%d'),
            "mrn": f"MRN-{ssn[-4:]}", # Using last 4 of SSN as a demo MRN
            "status": "Stable"
        })
    return jsonify(patient_list)

@app.route('/appointments', methods=['GET'])
def get_appointments():
    # Hardcoded for the demo user, but pulls from the library records
    patient = library.get_patient_by_ssn("123-45-6789")
    if not patient:
        return jsonify({}), 404

    formatted_events = {}
    for record in patient.medical_records:
        # Normalize date to the format TableCalendar expects (YYYY-MM-DDT00:00:00Z)
        date_key = record.date.strftime('%Y-%m-%dT00:00:00Z')
        event = {
            'title': f"{record.provider} – {record.specialty}",
            'time': "10:00 AM",
            'type': 'appointment'
        }
        if date_key not in formatted_events:
            formatted_events[date_key] = []
        formatted_events[date_key].append(event)
    
    return jsonify(formatted_events)

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.environ.get("PORT", 5000)))


