import os
import pyodbc
from flask import Flask, jsonify
from azure.identity import DefaultAzureCredential
from azure.keyvault.secrets import SecretClient

app = Flask(__name__)

KEY_VAULT_URL = os.environ.get("KEY_VAULT_URL")
SQL_PASSWORD_SECRET_NAME = "sql-admin-password"

_cached_password = None


def get_sql_password():
    # Fetches the secret directly via Managed Identity, routed through our own
    # VNet-integrated code path — bypasses App Service's platform-level Key Vault
    # reference resolution, which doesn't route through VNet integration the same way.
    global _cached_password
    if _cached_password is None:
        credential = DefaultAzureCredential()
        client = SecretClient(vault_url=KEY_VAULT_URL, credential=credential)
        _cached_password = client.get_secret(SQL_PASSWORD_SECRET_NAME).value
        print(f"DEBUG: fetched password length={len(_cached_password)} first3={_cached_password[:3]} last3={_cached_password[-3:]}", flush=True)
    return _cached_password


def get_db_connection():
    server = os.environ.get("SQL_SERVER")
    database = os.environ.get("SQL_DATABASE")
    username = os.environ.get("SQL_USER")
    password = get_sql_password()
    connection_string = (
        f"DRIVER={{ODBC Driver 18 for SQL Server}};"
        f"SERVER={server};"
        f"DATABASE={database};"
        f"UID={username};"
        f"PWD={password};"
        f"Encrypt=yes;"
        f"TrustServerCertificate=no;"
        f"Connection Timeout=30;"
    )
    return pyodbc.connect(connection_string)


@app.route("/")
def home():
    return jsonify(status="ok", message="proj2dr app running")


@app.route("/health")
def health():
    return jsonify(status="healthy")


@app.route("/db-check")
def db_check():
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("SELECT 1")
        result = cursor.fetchone()
        conn.close()
        return jsonify(status="ok", message="connected to SQL", result=str(result))
    except Exception as e:
        pw = _cached_password or ""
        debug_info = {"length": len(pw), "first3": pw[:3], "last3": pw[-3:]}
        return jsonify(status="error", message=str(e), debug=debug_info), 500


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)

#ANOTHER TEST!!
