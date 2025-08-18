#!/usr/bin/env python3
"""
Simple API wrapper for sealed-secrets operations
Provides a REST API to encrypt/decrypt secrets without direct cluster access
"""

import os
import json
import yaml
import base64
import subprocess
from pathlib import Path
from flask import Flask, request, jsonify
from cryptography.hazmat.primitives import serialization, hashes
from cryptography.hazmat.primitives.asymmetric import rsa, padding

app = Flask(__name__)

class SecretsAPI:
    def __init__(self, private_key_path=None, cert_path=None):
        self.script_dir = Path(__file__).parent
        self.private_key_path = private_key_path or self.script_dir / "sealed-secrets-private.key"
        self.cert_path = cert_path or self.script_dir / "sealed-secrets-cert.crt"
        
    def load_private_key(self):
        """Load the private key for decryption"""
        if not self.private_key_path.exists():
            raise FileNotFoundError(f"Private key not found at {self.private_key_path}")
            
        with open(self.private_key_path, 'rb') as f:
            private_key = serialization.load_pem_private_key(
                f.read(),
                password=None
            )
        return private_key
    
    def decrypt_sealed_secret(self, sealed_secret_data):
        """Decrypt a sealed secret using kubeseal"""
        try:
            # Write sealed secret to temp file
            temp_file = self.script_dir / "temp_sealed_secret.yaml"
            with open(temp_file, 'w') as f:
                yaml.dump(sealed_secret_data, f)
            
            # Use kubeseal to decrypt
            cmd = [
                'kubeseal', 
                '--recovery-unseal',
                '--recovery-private-key', str(self.private_key_path)
            ]
            
            result = subprocess.run(
                cmd,
                stdin=open(temp_file, 'r'),
                capture_output=True,
                text=True
            )
            
            # Clean up temp file
            temp_file.unlink()
            
            if result.returncode != 0:
                raise Exception(f"kubeseal error: {result.stderr}")
                
            return yaml.safe_load(result.stdout)
            
        except Exception as e:
            raise Exception(f"Decryption failed: {str(e)}")
    
    def encrypt_secret(self, secret_data):
        """Encrypt a secret using kubeseal"""
        try:
            # Write secret to temp file
            temp_file = self.script_dir / "temp_secret.yaml"
            with open(temp_file, 'w') as f:
                yaml.dump(secret_data, f)
            
            # Use kubeseal to encrypt
            cmd = ['kubeseal', '-o', 'yaml']
            
            result = subprocess.run(
                cmd,
                stdin=open(temp_file, 'r'),
                capture_output=True,
                text=True
            )
            
            # Clean up temp file
            temp_file.unlink()
            
            if result.returncode != 0:
                raise Exception(f"kubeseal error: {result.stderr}")
                
            return yaml.safe_load(result.stdout)
            
        except Exception as e:
            raise Exception(f"Encryption failed: {str(e)}")

# Initialize the API
secrets_api = SecretsAPI()

@app.route('/health', methods=['GET'])
def health():
    """Health check endpoint"""
    return jsonify({"status": "healthy", "service": "sealed-secrets-api"})

@app.route('/decrypt', methods=['POST'])
def decrypt():
    """Decrypt a sealed secret"""
    try:
        sealed_secret = request.json
        if not sealed_secret:
            return jsonify({"error": "No sealed secret data provided"}), 400
            
        decrypted = secrets_api.decrypt_sealed_secret(sealed_secret)
        return jsonify({"decrypted_secret": decrypted})
        
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/encrypt', methods=['POST'])
def encrypt():
    """Encrypt a regular secret into a sealed secret"""
    try:
        secret = request.json
        if not secret:
            return jsonify({"error": "No secret data provided"}), 400
            
        encrypted = secrets_api.encrypt_secret(secret)
        return jsonify({"sealed_secret": encrypted})
        
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/secrets', methods=['GET'])
def list_secrets():
    """List all sealed secret files in the current directory"""
    try:
        sealed_files = list(Path('.').glob('*-sealed.yaml'))
        secrets_list = []
        
        for file in sealed_files:
            with open(file, 'r') as f:
                data = yaml.safe_load(f)
                secrets_list.append({
                    "file": str(file),
                    "name": data.get('metadata', {}).get('name', 'unknown'),
                    "namespace": data.get('metadata', {}).get('namespace', 'default')
                })
        
        return jsonify({"secrets": secrets_list})
        
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/secrets/<filename>/decrypt', methods=['GET'])
def decrypt_file(filename):
    """Decrypt a specific sealed secret file"""
    try:
        file_path = Path(filename)
        if not file_path.exists():
            return jsonify({"error": f"File {filename} not found"}), 404
            
        with open(file_path, 'r') as f:
            sealed_secret = yaml.safe_load(f)
            
        decrypted = secrets_api.decrypt_sealed_secret(sealed_secret)
        return jsonify({
            "file": filename,
            "decrypted_secret": decrypted
        })
        
    except Exception as e:
        return jsonify({"error": str(e)}), 500

if __name__ == '__main__':
    print("🔐 Sealed Secrets API Server")
    print("============================")
    print("Endpoints:")
    print("  GET  /health                    - Health check")
    print("  GET  /secrets                   - List sealed secret files")
    print("  GET  /secrets/<file>/decrypt    - Decrypt specific file")
    print("  POST /decrypt                   - Decrypt sealed secret (JSON)")
    print("  POST /encrypt                   - Encrypt secret (JSON)")
    print("")
    print("Example usage:")
    print("  curl http://localhost:5000/secrets")
    print("  curl http://localhost:5000/secrets/my-secret-sealed.yaml/decrypt")
    print("")
    
    app.run(host='0.0.0.0', port=5000, debug=True)