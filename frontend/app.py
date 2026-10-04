"""
Frontend web app for the K8s demo.

Serves a simple HTML page that lists messages and lets you add one.
It talks to the BACKEND by its Kubernetes Service name (default: http://backend:5000),
demonstrating service discovery via cluster DNS.
"""
import os

import requests
from flask import Flask, redirect, render_template, request, url_for

app = Flask(__name__)

# The backend is reached by its Service name, NOT an IP address.
# In Kubernetes, "backend" resolves via cluster DNS to the backend Service.
BACKEND_URL = os.environ.get("BACKEND_URL", "http://backend:5000")


@app.route("/health")
def health():
    return {"status": "ok"}, 200


@app.route("/")
def index():
    messages = []
    error = None
    try:
        resp = requests.get(f"{BACKEND_URL}/api/messages", timeout=5)
        resp.raise_for_status()
        messages = resp.json().get("messages", [])
    except Exception as exc:  # noqa: BLE001
        error = f"Could not reach backend at {BACKEND_URL}: {exc}"
    return render_template(
        "index.html", messages=messages, error=error, backend_url=BACKEND_URL
    )


@app.route("/add", methods=["POST"])
def add():
    text = (request.form.get("text") or "").strip()
    if text:
        try:
            requests.post(
                f"{BACKEND_URL}/api/messages", json={"text": text}, timeout=5
            )
        except Exception as exc:  # noqa: BLE001
            print(f"Failed to post message: {exc}", flush=True)
    return redirect(url_for("index"))


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
