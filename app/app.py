import os
import pyodbc
import psycopg2
from flask import Flask, jsonify
from azure.identity import DefaultAzureCredential
from azure.keyvault.secrets import SecretClient
import boto3
import csv
import io

app = Flask(__name__)

# --- Azure SQL config ---
KEY_VAULT_URL = os.environ.get("KEY_VAULT_URL")
SQL_PASSWORD_SECRET_NAME = "sql-admin-password"
_cached_password = None


def get_sql_password():
    global _cached_password
    if _cached_password is None:
        credential = DefaultAzureCredential()
        client = SecretClient(vault_url=KEY_VAULT_URL, credential=credential)
        _cached_password = client.get_secret(SQL_PASSWORD_SECRET_NAME).value
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


# --- AWS RDS config ---
RDS_HOST = os.environ.get("RDS_HOST")
RDS_DB = os.environ.get("RDS_DB")
RDS_USER = os.environ.get("RDS_USER")
RDS_PASSWORD = os.environ.get("RDS_PASSWORD")


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
        return jsonify(status="error", message=str(e)), 500


@app.route("/rds-check")
def rds_check():
    try:
        conn = psycopg2.connect(
            host=RDS_HOST,
            dbname=RDS_DB,
            user=RDS_USER,
            password=RDS_PASSWORD,
            port=5432,
            connect_timeout=10
        )
        cursor = conn.cursor()
        cursor.execute("SELECT 1")
        result = cursor.fetchone()
        conn.close()
        return jsonify(status="ok", message="connected to RDS", result=str(result))
    except Exception as e:
        return jsonify(status="error", message=str(e)), 500


S3_BUCKET = os.environ.get("SYNC_S3_BUCKET")

@app.route("/sync-to-aws")
def sync_to_aws():
    try:
        # Export from Azure SQL
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("SELECT 1 as id, 'test' as value")  # placeholder query - swap for your real table
        rows = cursor.fetchall()
        columns = [desc[0] for desc in cursor.description]
        conn.close()

        # Write to CSV in memory
        buffer = io.StringIO()
        writer = csv.writer(buffer)
        writer.writerow(columns)
        writer.writerows(rows)

        # Upload to S3
        s3 = boto3.client("s3")
        s3.put_object(Bucket=S3_BUCKET, Key="sync/latest.csv", Body=buffer.getvalue())
      # Import into RDS
        rds_conn = psycopg2.connect(host=RDS_HOST, dbname=RDS_DB, user=RDS_USER, password=RDS_PASSWORD, port=5432)
        rds_cursor = rds_conn.cursor()
        rds_cursor.execute("CREATE TABLE IF NOT EXISTS synced_data (id INT, value TEXT)")
        rds_cursor.execute("TRUNCATE synced_data")
        for row in rows:
            rds_cursor.execute("INSERT INTO synced_data (id, value) VALUES (%s, %s)", row)
        rds_conn.commit()
        rds_conn.close()

        return jsonify(status="ok", message=f"synced {len(rows)} rows", timestamp=str(__import__('datetime').datetime.utcnow()))
    except Exception as e:
        return jsonify(status="error", message=str(e)), 500

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)# retest workflows
