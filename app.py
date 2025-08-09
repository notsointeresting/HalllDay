import csv
import io
import os
import json
import time
from datetime import datetime, timezone, timedelta
from zoneinfo import ZoneInfo

from flask import Flask, jsonify, render_template, request, redirect, url_for, send_file, Response, stream_with_context
from flask_sqlalchemy import SQLAlchemy

import config

app = Flask(__name__)

# Prefer DATABASE_URL from env (Render), else config.py
app.config["SQLALCHEMY_DATABASE_URI"] = os.getenv("DATABASE_URL", config.DATABASE_URL)
app.config["SQLALCHEMY_TRACK_MODIFICATIONS"] = False
app.config["SECRET_KEY"] = config.SECRET_KEY

db = SQLAlchemy(app)
TZ = ZoneInfo(config.TIMEZONE)

# ---------- Models ----------

class Student(db.Model):
    id = db.Column(db.String, primary_key=True)          # barcode value or student id
    name = db.Column(db.String, nullable=False)

class Session(db.Model):
    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    student_id = db.Column(db.String, db.ForeignKey("student.id"), nullable=False, index=True)
    start_ts = db.Column(db.DateTime(timezone=True), nullable=False, index=True)
    end_ts = db.Column(db.DateTime(timezone=True), nullable=True, index=True)
    ended_by = db.Column(db.String, nullable=True)       # "kiosk_scan", "override", "auto"
    room = db.Column(db.String, nullable=True)

    student = db.relationship("Student")

    @property
    def duration_seconds(self):
        end = self.end_ts or datetime.now(timezone.utc)
        return int((end - self.start_ts).total_seconds())

class Settings(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    room_name = db.Column(db.String, nullable=False, default=config.ROOM_NAME)
    capacity = db.Column(db.Integer, nullable=False, default=config.CAPACITY)
    overdue_minutes = db.Column(db.Integer, nullable=False, default=10)

# Create tables after models are defined (works under Gunicorn too)
with app.app_context():
    db.create_all()
    # Ensure a singleton settings row exists
    if not Settings.query.get(1):
        s = Settings(id=1, room_name=config.ROOM_NAME, capacity=config.CAPACITY,
                     overdue_minutes=getattr(config, "MAX_MINUTES", 10))
        db.session.add(s)
        db.session.commit()

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
    # No-op: we no longer auto-end. Overdue is indicated in UI and CSV export.
    return

def get_settings():
    s = Settings.query.get(1)
    if not s:
        return {"room_name": config.ROOM_NAME, "capacity": config.CAPACITY, "overdue_minutes": getattr(config, "MAX_MINUTES", 10)}
    return {"room_name": s.room_name, "capacity": s.capacity, "overdue_minutes": s.overdue_minutes}

@app.context_processor
def inject_room_name():
    return {"room": get_settings()["room_name"]}

# ---------- Routes ----------

@app.route("/")
def index():
    return redirect(url_for("kiosk"))

@app.route("/kiosk")
def kiosk():
    return render_template("kiosk.html")

@app.route("/display")
def display():
    return render_template("display.html")

@app.route("/admin")
def admin():
    total = Session.query.count()
    open_count = Session.query.filter_by(end_ts=None).count()
    students = Student.query.order_by(Student.name.asc()).all()
    settings = get_settings()
    return render_template("admin.html", total=total, open_count=open_count, students=students, settings=settings)

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
    if len(open_sessions) >= get_settings()["capacity"]:
        holder = open_sessions[0].student.name
        return jsonify(ok=False, action="denied", message=f"In use by {holder}"), 409

    # Otherwise start a new session
    sess = Session(student_id=student.id, start_ts=now_utc(), room=get_settings()["room_name"])
    db.session.add(sess)
    db.session.commit()
    return jsonify(ok=True, action="started", name=student.name)

@app.get("/api/status")
def api_status():
    auto_end_expired()
    s = get_current_holder()
    overdue_minutes = get_settings()["overdue_minutes"]
    if s:
        is_overdue = s.duration_seconds > overdue_minutes * 60
        return jsonify(in_use=True, name=s.student.name, start=to_local(s.start_ts).isoformat(), elapsed=s.duration_seconds, overdue=is_overdue, overdue_minutes=overdue_minutes)
    else:
        return jsonify(in_use=False, overdue_minutes=overdue_minutes)

@app.get("/events")
def sse_events():
    def stream():
        last_payload = None
        while True:
            s = get_current_holder()
            overdue_minutes = get_settings()["overdue_minutes"]
            if s:
                payload = {
                    "in_use": True,
                    "name": s.student.name,
                    "elapsed": s.duration_seconds,
                    "overdue": s.duration_seconds > overdue_minutes * 60,
                    "overdue_minutes": overdue_minutes,
                }
            else:
                payload = {"in_use": False, "overdue_minutes": overdue_minutes}
            if payload != last_payload:
                yield f"data: {json.dumps(payload)}\n\n"
                last_payload = payload
            time.sleep(1)
    return Response(stream_with_context(stream()), mimetype="text/event-stream")

@app.get("/api/stats")
def api_stats():
    """Simple stats: today's hourly counts and last 7 days daily counts."""
    today_local = datetime.now(TZ).date()
    start_today = datetime.combine(today_local, datetime.min.time(), tzinfo=TZ).astimezone(timezone.utc)
    end_today = datetime.combine(today_local, datetime.max.time(), tzinfo=TZ).astimezone(timezone.utc)
    rows_today = Session.query.filter(Session.start_ts >= start_today, Session.start_ts <= end_today).all()

    hourly = [0]*24
    for r in rows_today:
        h = r.start_ts.astimezone(TZ).hour
        hourly[h] += 1

    # last 7 days including today
    daily_labels = []
    daily_counts = []
    for i in range(6, -1, -1):
        day = today_local - timedelta(days=i)
        ds = datetime.combine(day, datetime.min.time(), tzinfo=TZ).astimezone(timezone.utc)
        de = datetime.combine(day, datetime.max.time(), tzinfo=TZ).astimezone(timezone.utc)
        c = Session.query.filter(Session.start_ts >= ds, Session.start_ts <= de).count()
        daily_labels.append(day.strftime("%a"))
        daily_counts.append(c)

    return jsonify({
        "hourly": hourly,
        "daily_labels": daily_labels,
        "daily_counts": daily_counts,
    })

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
    w.writerow(["student_id", "name", "start_local", "end_local", "duration_seconds", "ended_by", "overdue"])
    overdue_minutes = get_settings()["overdue_minutes"]
    for r in rows:
        start_local = r.start_ts.astimezone(TZ).strftime("%Y-%m-%d %H:%M:%S")
        end_local = r.end_ts.astimezone(TZ).strftime("%Y-%m-%d %H:%M:%S") if r.end_ts else ""
        duration = r.duration_seconds if r.end_ts else int((now_utc() - r.start_ts).total_seconds())
        is_overdue = duration > overdue_minutes * 60
        w.writerow([r.student_id, r.student.name, start_local, end_local, duration if r.end_ts else "", r.ended_by or "", "YES" if is_overdue else "NO"])
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
    if not Settings.query.get(1):
        db.session.add(Settings(id=1, room_name=config.ROOM_NAME, capacity=config.CAPACITY, overdue_minutes=getattr(config, "MAX_MINUTES", 10)))
        db.session.commit()
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

# ---- Settings API ----
@app.get("/api/settings")
def get_settings_api():
    return jsonify(get_settings())

@app.post("/api/settings")
def update_settings_api():
    data = request.get_json(silent=True) or {}
    s = Settings.query.get(1)
    if not s:
        s = Settings(id=1)
        db.session.add(s)
    if "room_name" in data:
        s.room_name = str(data["room_name"]).strip() or s.room_name
    if "capacity" in data:
        try:
            s.capacity = max(1, int(data["capacity"]))
        except Exception:
            pass
    if "overdue_minutes" in data:
        try:
            s.overdue_minutes = max(1, int(data["overdue_minutes"]))
        except Exception:
            pass
    db.session.commit()
    return jsonify(ok=True, settings=get_settings())

if __name__ == "__main__":
    with app.app_context():
        db.create_all()
    app.run(host="0.0.0.0", port=5000, debug=True)
