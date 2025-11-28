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







