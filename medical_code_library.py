import os
from datetime import datetime
from typing import List, Dict, Optional
from cryptography.fernet import Fernet
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from email.mime.base import MIMEBase
from email import encoders

# --- Encryption Key Setup (REPLACED FOR CONSISTENCY) ---
# This looks for the permanent mL-N5N... key you saved in your Render settings.
env_key = os.environ.get('FERNET_KEY')

if env_key:
    # Use the stable key from Render environment
    cipher = Fernet(env_key.encode())
else:
    # Fallback for local testing if no environment variable is found
    # In production (Render), it will use your permanent key.
    fallback_key = b'mL-N5Npl_dijvORR5c4im7nWs5HydjW_qXCbVFKFGKk='
    cipher = Fernet(fallback_key)
    print("WARNING: Using fallback key for local environment.")

# --- SMTP Configuration ---
SMTP_SERVER = 'localhost'
SMTP_PORT = 1025
EMAIL_USER = 'test@example.com'
EMAIL_PASS = 'password'

# --- MedicalRecord Class ---
class MedicalRecord:
    def __init__(self, date: str, provider: str, specialty: str, content: str):
        self.date = datetime.strptime(date, '%Y-%m-%d')
        self.provider = provider
        self.specialty = specialty
        self.content = cipher.encrypt(content.encode())

    def get_decrypted_content(self):
        return cipher.decrypt(self.content).decode()

# --- MedicalImage Class ---
class MedicalImage:
    def __init__(self, date: str, image_type: str, file_path: str):
        self.date = datetime.strptime(date, '%Y-%m-%d')
        self.image_type = image_type
        self.file_path = file_path

# --- Patient Class ---
class Patient:
    def __init__(self, name: str, dob: str, ssn: str, address: str, email: str, phone: str):
        self.name = name
        self.dob = datetime.strptime(dob, '%Y-%m-%d')
        self.ssn = cipher.encrypt(ssn.encode())
        self.address = address
        self.email = cipher.encrypt(email.encode())
        self.phone = phone
        self.medical_records: List[MedicalRecord] = []
        self.medical_images: List[MedicalImage] = []

    def add_medical_record(self, record: MedicalRecord):
        self.medical_records.append(record)

    def add_medical_image(self, image: MedicalImage):
        self.medical_images.append(image)

    def get_decrypted_email(self):
        return cipher.decrypt(self.email).decode()

    def get_decrypted_ssn(self):
        return cipher.decrypt(self.ssn).decode()

# --- MedicalDataLibrary Class ---
class MedicalDataLibrary:
    def __init__(self):
        self.patients: Dict[str, Patient] = {}

    def add_patient(self, patient: Patient):
        # Index by decrypted SSN for easy retrieval
        self.patients[patient.get_decrypted_ssn()] = patient

    def get_patient_by_ssn(self, ssn: str) -> Optional[Patient]:
        return self.patients.get(ssn)

    def send_email_with_attachment(self, to_email: str, subject: str, body: str, file_path: str):
        """Send an email with an attachment."""
        try:
            msg = MIMEMultipart()
            msg['From'] = EMAIL_USER
            msg['To'] = to_email
            msg['Subject'] = subject
            msg.attach(MIMEText(body, 'plain'))

            if not os.path.exists(file_path):
                print(f"Attachment file not found: {file_path}")
                return

            with open(file_path, 'rb') as attachment:
                part = MIMEBase('application', 'octet-stream')
                part.set_payload(attachment.read())
                encoders.encode_base64(part)
                part.add_header('Content-Disposition', f"attachment; filename= {os.path.basename(file_path)}")
                msg.attach(part)

            server = smtplib.SMTP(SMTP_SERVER, SMTP_PORT)
            text = msg.as_string()
            server.sendmail(EMAIL_USER, to_email, text)
            server.quit()
        except Exception as e:
            print(f"Failed to send email: {e}")

    def receive_file_via_sftp(self, remote_path: str, local_path: str):
        print(f"Mocked SFTP transfer from {remote_path} to {local_path}")
