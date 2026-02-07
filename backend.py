from flask import Flask, request, jsonify, send_file
from flask_cors import CORS
from medical_code_library import MedicalDataLibrary, Patient, MedicalRecord
from reportlab.lib.pagesizes import letter
from reportlab.pdfgen import canvas
import os
import logging

app = Flask(__name__)
CORS(app)

# Configure logging
logging.basicConfig(level=logging.INFO)

# Initialize Library & Mock Data
library = MedicalDataLibrary()

def init_mock_data():
    john = Patient(
        name="John Doe", dob="1980-01-01", ssn="123-45-6789", 
        address="123 Main St", email="john@example.com", phone="555-1234"
    )
    # Adding more detailed records for the calendar
    john.add_medical_record(MedicalRecord(
        date="2026-02-10", provider="Dr. Smith", specialty="Cardiology", content="Follow-up on heart rate"
    ))
    john.add_medical_record(MedicalRecord(
        date="2026-02-15", provider="LabCorp", specialty="Diagnostics", content="Blood work panel"
    ))
    library.add_patient(john)

init_mock_data()

# --- PDF GENERATOR HELPER ---
def create_reset_pdf(filename, user_email):
    c = canvas.Canvas(filename, pagesize=letter)
    c.drawString(100, 750, "MediRecords Pro - Security Alert")
    c.drawString(100, 730, "------------------------------------------------")
    c.drawString(100, 700, f"Password reset requested for: {user_email}")
    c.drawString(100, 680, "Your temporary reset code is: 123456")
    c.drawString(100, 660, "Please enter this code in the app to set your new password.")
    c.save()

# --- ROUTES ---

@app.route("/")
def health_check():
    return jsonify({"status": "healthy"})

@app.route('/login', methods=['POST'])
def login():
    data = request.get_json()
    # In a real app, you would check the hashed password from the database
    if data.get('email') == "john@example.com" and data.get('password') == "securepassword":
        return jsonify(success=True, message="Login successful")
    return jsonify(success=False, message="Invalid credentials"), 401

@app.route('/forgot-password', methods=['POST'])
def forgot_password():
    data = request.get_json()
    email = data.get('email')

    if email == "john@example.com":
        try:
            # Generate a real PDF dynamically
            pdf_filename = "reset_instructions.pdf"
            create_reset_pdf(pdf_filename, email)
            
            # Send email with the generated PDF
            library.send_email_with_attachment(
                to_email=email,
                subject="MediRecords Pro - Password Reset",
                body="Please find your reset instructions attached.",
                file_path=pdf_filename
            )
            return jsonify(success=True, message="Reset instructions generated! Click download.")
        except Exception as e:
            app.logger.error(f"Error: {e}")
            return jsonify(success=False, message="Server error processing request"), 500

    return jsonify(success=False, message="Email not found"), 404

# --- NEW ROUTE: FIXES THE 404 ERROR ---
@app.route('/download-instructions', methods=['GET'])
def download_instructions():
    """Endpoint to download the generated PDF."""
    try:
        pdf_filename = "reset_instructions.pdf"
        
        # If file doesn't exist (e.g., server restarted), regenerate it
        if not os.path.exists(pdf_filename):
            create_reset_pdf(pdf_filename, "demo@example.com")
            
        return send_file(pdf_filename, as_attachment=True)
    except Exception as e:
        app.logger.error(f"Download error: {e}")
        return jsonify(error=str(e)), 500
# --------------------------------------

@app.route('/reset-password', methods=['POST'])
def reset_password():
    data = request.get_json()
    email = data.get('email')
    new_password = data.get('new_password')
    
    # Mocking the update - in a real DB you would run an UPDATE query here
    if email == "john@example.com" and new_password:
        app.logger.info(f"Password for {email} updated to {new_password}")
        return jsonify(success=True, message="Password updated successfully. Please login.")
    
    return jsonify(success=False, message="Failed to update password"), 400

@app.route('/patients', methods=['GET'])
def get_patients():
    patient_list = []
    for ssn, patient in library.patients.items():
        patient_list.append({
            "name": patient.name,
            "dob": patient.dob.strftime('%Y-%m-%d'),
            "mrn": f"MRN-{ssn[-4:]}",
            "status": "Stable"
        })
    return jsonify(patient_list)

@app.route('/appointments', methods=['GET'])
def get_appointments():
    patient = library.get_patient_by_ssn("123-45-6789")
    if not patient: return jsonify({}), 404
    formatted_events = {}
    for record in patient.medical_records:
        date_key = record.date.strftime('%Y-%m-%dT00:00:00Z')
        if date_key not in formatted_events: formatted_events[date_key] = []
        formatted_events[date_key].append({'title': f"{record.provider} – {record.specialty}", 'time': "10:00 AM", 'type': 'appointment'})
    return jsonify(formatted_events)

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.environ.get("PORT", 5000)))




