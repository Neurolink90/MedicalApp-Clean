import os
from datetime import datetime
from typing import List, Dict, Optional
from cryptography.fernet import Fernet
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from email.mime.base import MIMEBase
from email import encoders

# --- Encryption Key Setup (Store Securely) ---
encryption_key = Fernet.generate_key()  # Store securely
cipher = Fernet(encryption_key)

# --- SMTP Configuration (For Sending Emails with Attachments) ---
SMTP_SERVER = 'localhost'  # Local SMTP server for debugging
SMTP_PORT = 1025           # Mock SMTP server port
EMAIL_USER = 'test@example.com'
EMAIL_PASS = 'password'    # Mock password, not actually used

# --- MedicalRecord Class with Encryption ---
class MedicalRecord:
    def __init__(self, date: str, provider: str, specialty: str, content: str):
        self.date = datetime.strptime(date, '%Y-%m-%d')
        self.provider = provider
        self.specialty = specialty
        self.content = cipher.encrypt(content.encode())

    def get_decrypted_content(self):
        return cipher.decrypt(self.content).decode()

# --- MedicalImage Class (Handles Image Files) ---
class MedicalImage:
    def __init__(self, date: str, image_type: str, file_path: str):
        self.date = datetime.strptime(date, '%Y-%m-%d')
        self.image_type = image_type
        self.file_path = file_path  # File path for the image

# --- Patient Class with Encryption for Sensitive Data ---
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
        self.patients[patient.get_decrypted_ssn()] = patient

    def get_patient_by_ssn(self, ssn: str) -> Optional[Patient]:
        encrypted_ssn = cipher.encrypt(ssn.encode())
        return self.patients.get(cipher.decrypt(encrypted_ssn).decode(), None)

    def send_email_with_attachment(self, to_email: str, subject: str, body: str, file_path: str):
        """Send an email with an attachment."""
        try:
            msg = MIMEMultipart()
            msg['From'] = EMAIL_USER
            msg['To'] = to_email
            msg['Subject'] = subject
            msg.attach(MIMEText(body, 'plain'))

            # Check if the file exists before attaching
            if not os.path.exists(file_path):
                print(f"Attachment file not found: {file_path}")
                return

            with open(file_path, 'rb') as attachment:
                part = MIMEBase('application', 'octet-stream')
                part.set_payload(attachment.read())
                encoders.encode_base64(part)
                part.add_header('Content-Disposition', f"attachment; filename= {os.path.basename(file_path)}")
                msg.attach(part)

            # Attempt to connect to the SMTP server
            server = smtplib.SMTP(SMTP_SERVER, SMTP_PORT)
            text = msg.as_string()
            server.sendmail(EMAIL_USER, to_email, text)
            server.quit()
            print(f"Email sent to {to_email} with attachment {file_path}")
        except ConnectionRefusedError:
            print("Failed to connect to the SMTP server. Is the server running?")
        except Exception as e:
            print(f"Failed to send email: {e}")

    def receive_file_via_sftp(self, remote_path: str, local_path: str):
        """Mocked function to simulate receiving a file securely via SFTP."""
        print(f"Mocked SFTP transfer: Simulated file received from {remote_path} to {local_path}")

# --- Example Usage ---
library = MedicalDataLibrary()

# Add a new patient
patient = Patient(name="John Doe", dob="1980-01-01", ssn="123-45-6789", address="123 Main St", email="john@example.com", phone="555-1234")
library.add_patient(patient)

# Add medical records and images
record1 = MedicalRecord(date="2023-01-01", provider="Dr. Smith", specialty="Cardiology", content="Cardiology report content")
image1 = MedicalImage(date="2023-01-05", image_type="CT", file_path="C:\\Users\\Zach\\Documents\\ct1.png")  # Update path to actual file

patient.add_medical_record(record1)
patient.add_medical_image(image1)

# Send a medical report as an email attachment using the mock SMTP server
library.send_email_with_attachment(
    to_email=patient.get_decrypted_email(),
    subject="Your Medical Report",
    body="Please find attached your medical report.",
    file_path="C:\\Users\\Zach\\Documents\\ct1.png"  # Update path to actual file
)

# Mocked receive a file from an SFTP server
library.receive_file_via_sftp(remote_path='/remote/path/medical_report.pdf', local_path='C:\\Users\\Zach\\Documents\\medical_report.pdf')
