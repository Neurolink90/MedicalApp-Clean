import unittest
import json
from backend import app

class MedicalBackendTests(unittest.TestCase):

    def setUp(self):
        # Set up a temporary test client
        self.app = app.test_client()
        self.app.testing = True 

    def test_health_check(self):
        """Test if the server is up and running"""
        response = self.app.get('/')
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.get_json()['status'], 'healthy')
        print("✅ Health Check Passed")

    def test_login_success(self):
        """Test logging in with correct credentials"""
        payload = {"email": "john@example.com", "password": "securepassword"}
        response = self.app.post('/login', 
                                 data=json.dumps(payload),
                                 content_type='application/json')
        self.assertEqual(response.status_code, 200)
        self.assertTrue(response.get_json()['success'])
        print("✅ Login Success Test Passed")

    def test_login_failure(self):
        """Test logging in with wrong password"""
        payload = {"email": "john@example.com", "password": "WRONG_PASSWORD"}
        response = self.app.post('/login', 
                                 data=json.dumps(payload),
                                 content_type='application/json')
        self.assertEqual(response.status_code, 401)
        print("✅ Login Failure Test Passed")

    def test_forgot_password_flow(self):
        """Test the full forgot password -> download flow"""
        # 1. Request Password Reset
        payload = {"email": "john@example.com"}
        response = self.app.post('/forgot-password', 
                                 data=json.dumps(payload),
                                 content_type='application/json')
        self.assertEqual(response.status_code, 200)
        self.assertIn("Reset instructions generated", response.get_json()['message'])
        
        # 2. Download the PDF
        download_response = self.app.get('/download-instructions')
        self.assertEqual(download_response.status_code, 200)
        self.assertEqual(download_response.content_type, 'application/pdf')
        print("✅ Forgot Password & PDF Download Test Passed")

if __name__ == '__main__':
    unittest.main()