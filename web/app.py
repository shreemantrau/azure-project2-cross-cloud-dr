import os
import requests
from flask import Flask, render_template

app = Flask(__name__)

APP_TIER_URL = os.environ.get("APP_TIER_URL", "http://localhost:5000")


@app.route("/")
def home():
    try:
        resp = requests.get(f"{APP_TIER_URL}/", timeout=5)
        app_status = resp.json()
    except Exception as e:
        app_status = {"status": "error", "message": str(e)}

    return render_template("index.html", app_status=app_status)


@app.route("/health")
def health():
    return {"status": "healthy"}


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)

