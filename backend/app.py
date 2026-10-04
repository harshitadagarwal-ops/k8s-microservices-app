"""
Backend REST API for the K8s demo app.

Endpoints:
  GET  /health        -> liveness/readiness check
  GET  /api/messages  -> list all messages from MySQL
  POST /api/messages  -> add a message  (JSON: {"text": "..."})

Reads DB connection info from environment variables, which are injected
by a Kubernetes ConfigMap (host/db name) and Secret (user/password).
"""
import os
import time

import pymysql
from flask import Flask, jsonify, request

app = Flask(__name__)

DB_CONFIG = {
    "host": os.environ.get("DB_HOST", "mysql"),
    "user": os.environ.get("DB_USER", "appuser"),
    "password": os.environ.get("DB_PASSWORD", "apppassword"),
    "database": os.environ.get("DB_NAME", "appdb"),
    "cursorclass": pymysql.cursors.DictCursor,
}


def get_connection():
    """Open a new DB connection."""
    return pymysql.connect(**DB_CONFIG)


def init_db(retries=15, delay=4):
    """Wait for MySQL to be ready, then ensure the messages table exists.

    MySQL may start slower than the backend, so we retry. This makes the
    demo resilient when everything comes up at once.
    """
    for attempt in range(1, retries + 1):
        try:
            conn = get_connection()
            with conn.cursor() as cur:
                cur.execute(
                    """
                    CREATE TABLE IF NOT EXISTS messages (
                        id INT AUTO_INCREMENT PRIMARY KEY,
                        text VARCHAR(255) NOT NULL,
                        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                    )
                    """
                )
            conn.commit()
            conn.close()
            print("DB initialized successfully.", flush=True)
            return
        except Exception as exc:  # noqa: BLE001 - demo code, log and retry
            print(
                f"DB not ready (attempt {attempt}/{retries}): {exc}",
                flush=True,
            )
            time.sleep(delay)
    print("WARNING: DB init failed after retries; will retry on requests.", flush=True)


@app.route("/health")
def health():
    return jsonify(status="ok"), 200


@app.route("/api/messages", methods=["GET"])
def list_messages():
    try:
        conn = get_connection()
        with conn.cursor() as cur:
            cur.execute("SELECT id, text, created_at FROM messages ORDER BY id DESC")
            rows = cur.fetchall()
        conn.close()
        return jsonify(messages=rows), 200
    except Exception as exc:  # noqa: BLE001
        return jsonify(error=str(exc)), 500


@app.route("/api/messages", methods=["POST"])
def add_message():
    data = request.get_json(silent=True) or {}
    text = (data.get("text") or "").strip()
    if not text:
        return jsonify(error="'text' is required"), 400
    try:
        conn = get_connection()
        with conn.cursor() as cur:
            cur.execute("INSERT INTO messages (text) VALUES (%s)", (text,))
        conn.commit()
        conn.close()
        return jsonify(status="created", text=text), 201
    except Exception as exc:  # noqa: BLE001
        return jsonify(error=str(exc)), 500


if __name__ == "__main__":
    init_db()
    app.run(host="0.0.0.0", port=5000)
