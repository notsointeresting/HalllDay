import csv
import io
import os
from datetime import datetime, timezone, timedelta
from zoneinfo import ZoneInfo

from flask import Flask, jsonify, render_template, request, redirect, url_for, send_file, abort
from flask_sqlalchemy import SQLAlchemy

import config

app = Flask(__name__)
# Use DATABASE_URL environment variable if set; fall back to config.DATABASE_URL
app.config["SQLALCHEMY_DATABASE_URI"] = os.getenv("DATABASE_URL", config.DATABASE_URL)
app.config["SQLALCHEMY_TRACK_MODIFICATIONS"] = False
app.config["SECRET_KEY"] = config.SECRET_KEY
db = SQLAlchemy(app)

TZ = ZoneInfo(config.TIMEZONE)

# ---------- Models ----------

class Student(db.Model):
    id = db.Column(db.String, primary_key=True)  # barcode value or student id
    name = db.Column(db.String, nullable=False)

class Session(db.Model):
    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    student_id = db.Column(db.String, db.ForeignKey("student.id"), nullable=False, index=True)
    start_ts = db.Column(db.DateTime(timezone=True), nullable=False, index=True)
    end_ts = db.Column(db.DateTime(timezone=True), nullable=True, index=True)
    ended_by = db.Column(db.String, nullable=True)  # "kiosk_scan", "override", "auto"
    room = db.Column(db.String, nullable=True)

    student = db.relationship("Student")

    @property
    def duration_seconds(self):
        end = self.end_ts or datetime.now(timezone.utc)
        return int((end - self.start_ts).total_seconds())

# ---------- Utility ----------

def now_utc():
    return datetime.now(timezone.utc)

def to_local(dt_utc):
    return dt_utc.astimezone(TZ)

def get_open_sessions():
    return Session.query.filter_by(end_ts=None).order_by(Session.start_ts.asc()).all()

def get_current_holder():
    open_sessions = get_open_sessions()
    return open_sessions[0] if open_sessions else None

def auto_end_expired():
    """Failsafe to auto-end any open session that exceeded MAX_MINUTES."""
    max_age = timedelta(minutes=config.MAX_MINUTES)
    changed = False
    for s in get_open_sessions():
        if now_utc() - s.start_ts > max_age:
            s.end_ts = now_utc()
            s.ended_by = "auto"
            changed = True
    if changed:
        db.session.commit()

# ---------- Routes ----------

@app.route("/")
def index():
    return redirect(url_for("kiosk"))

@app.route("/kiosk")
def kiosk():
    return render_template("kiosk.html", room=config.ROOM_NAME)

@app.route("/display")
def display():
    return render_template("display.html", room=config.ROOM_NAME)

@app.route("/admin")
def admin():
    # Simple admin page
    total = Session.query.count()
    open_count = Session.query.filter_by(end_ts=None).count()
    students = Student.query.order_by(Student.name.asc()).all()
    return render_template("admin.html", total=total, open_count=open_count, students=students, room=config.ROOM_NAME)

# ---- API ----

@app.post("/api/scan")
def api_scan():
    auto_end_expired()

    payload = request.get_json(silent=True) or {}
    code = (payload.get("code") or "").strip()
    if not code:
        return jsonify(ok=False, message="No code scanned"), 400

    student = Student.query.get(code)
    if not student:
        return jsonify(ok=False, message=f"Unknown ID: {code}"), 404

    open_sessions = get_open_sessions()

    # If this student currently holds the pass, end their session
    for s in open_sessions:
        if s.student_id == student.id:
            s.end_ts = now_utc()
            s.ended_by = "kiosk_scan"
            db.session.commit()
            return jsonify(ok=True, action="ended", name=student.name)

    # If capacity is full and someone else is out, deny
    if len(open_sessions) >= config.CAPACITY:
        holder = open_sessions[0].student.name
        return jsonify(ok=False, action="denied", message=f"In use by {holder}"), 409

    # Otherwise start a new session
    sess = Session(student_id=student.id, start_ts=now_utc(), room=config.ROOM_NAME)
    db.session.add(sess)
    db.session.commit()
    return jsonify(ok=True, action="started", name=student.name)

@app.get("/api/status")
def api_status():
    auto_end_expired()
    s = get_current_holder()
    if s:
        return jsonify(in_use=True, name=s.student.name, start=to_local(s.start_ts).isoformat(), elapsed=s.duration_seconds)
    else:
        return jsonify(in_use=False)

@app.post("/api/override_end")
def api_override_end():
    s = get_current_holder()
    if not s:
        return jsonify(ok=False, message="No one is out."), 400
    s.end_ts = now_utc()
    s.ended_by = "override"
    db.session.commit()
    return jsonify(ok=True)

@app.post("/api/import_roster")
def api_import_roster():
    """Import a CSV uploaded as form-data file with two columns: id,name."""
    if "file" not in request.files:
        return jsonify(ok=False, message="No file uploaded"), 400
    f = request.files["file"]
    text = f.stream.read().decode("utf-8", errors="ignore")
    reader = csv.reader(io.StringIO(text))
    count = 0
    for row in reader:
        if not row or len(row) < 2:
            continue
        sid, name = row[0].strip(), row[1].strip()
        if not sid or not name:
            continue
        existing = Student.query.get(sid)
        if existing:
            existing.name = name
        else:
            db.session.add(Student(id=sid, name=name))
        count += 1
    db.session.commit()
    return jsonify(ok=True, imported=count)

@app.get("/export.csv")
def export_csv():
    """Export sessions for the current day in local timezone."""
    auto_end_expired()
    today_local = datetime.now(TZ).date()
    start = datetime.combine(today_local, datetime.min.time(), tzinfo=TZ).astimezone(timezone.utc)
    end = datetime.combine(today_local, datetime.max.time(), tzinfo=TZ).astimezone(timezone.utc)

    rows = Session.query.filter(Session.start_ts >= start, Session.start_ts <= end).order_by(Session.start_ts.asc()).all()

    out = io.StringIO()
    w = csv.writer(out)
    w.writerow(["student_id", "name", "start_local", "end_local", "duration_seconds", "ended_by"])
    for r in rows:
        start_local = r.start_ts.astimezone(TZ).strftime("%Y-%m-%d %H:%M:%S")
        end_local = r.end_ts.astimezone(TZ).strftime("%Y-%m-%d %H:%M:%S") if r.end_ts else ""
        w.writerow([r.student_id, r.student.name, start_local, end_local, r.duration_seconds if r.end_ts else "", r.ended_by or ""])
    out.seek(0)

    return send_file(
        io.BytesIO(out.getvalue().encode("utf-8")),
        mimetype="text/csv",
        as_attachment=True,
        download_name="hallpass_export.csv",
    )

# ---------- CLI helpers ----------

@app.cli.command("init-db")
def init_db():
    """Initialize DB and load students.csv if present."""
    db.create_all()
    roster = "students.csv"
    if os.path.exists(roster):
        with open(roster, newline="", encoding="utf-8") as f:
            reader = csv.reader(f)
            for row in reader:
                if not row or len(row) < 2:
                    continue
                sid, name = row[0].strip(), row[1].strip()
                if not sid or not name:
                    continue
                if not Student.query.get(sid):
                    db.session.add(Student(id=sid, name=name))
        db.session.commit()
        print(f"Loaded roster from {roster}")
    print("Database initialized.")

if __name__ == "__main__":
    with app.app_context():
        db.create_all()
    app.run(host="0.0.0.0", port=5000, debug=True)
