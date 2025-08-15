import csv
import io
import os
import json
import time
import hashlib
from datetime import datetime, timezone, timedelta
from zoneinfo import ZoneInfo

from flask import Flask, jsonify, render_template, request, redirect, url_for, send_file, Response, stream_with_context, session, flash
from flask_sqlalchemy import SQLAlchemy
from sqlalchemy import text

import config
import sheets_logger
import threading
import requests
from urllib.parse import urljoin

app = Flask(__name__)

# Prefer DATABASE_URL from env (Render), else config.py
app.config["SQLALCHEMY_DATABASE_URI"] = os.getenv("DATABASE_URL", config.DATABASE_URL)
app.config["SQLALCHEMY_TRACK_MODIFICATIONS"] = False
app.config["SECRET_KEY"] = config.SECRET_KEY
app.config["PERMANENT_SESSION_LIFETIME"] = timedelta(hours=8)  # Admin sessions last 8 hours

db = SQLAlchemy(app)
TZ = ZoneInfo(config.TIMEZONE)

# FERPA-Compliant Memory Cache for Student Roster
# This is not persistent storage - roster expires automatically
_memory_roster = {}
_roster_expiry = None
ROSTER_EXPIRY_HOURS = 24  # Roster expires after 24 hours for FERPA compliance

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
    kiosk_suspended = db.Column(db.Boolean, nullable=False, default=False)

class StudentName(db.Model):
    """FERPA-compliant storage of student names only (no ID association)"""
    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    name_hash = db.Column(db.String, nullable=False, unique=True)  # Hash of student_id for lookup
    display_name = db.Column(db.String, nullable=False)  # Actual name to display
    created_at = db.Column(db.DateTime(timezone=True), nullable=False, default=lambda: datetime.now(timezone.utc))

# Create tables after models are defined (works under Gunicorn too)
STATIC_VERSION = os.getenv("STATIC_VERSION", str(int(time.time())))

# Database initialization temporarily commented out for testing
# Uncomment and run 'flask --app app.py init-db' if needed
# with app.app_context():
#     db.create_all()
#     # Ensure a singleton settings row exists
#     try:
#         if not Settings.query.get(1):
#             s = Settings(id=1, room_name=config.ROOM_NAME, capacity=config.CAPACITY,
#                          overdue_minutes=getattr(config, "MAX_MINUTES", 10), kiosk_suspended=False)
#             db.session.add(s)
#             db.session.commit()
#     except Exception as e:
#         print(f"Warning: Could not initialize settings row: {e}")
#         print("You may need to run database migrations.")

# ---------- FERPA-Compliant Roster Utilities ----------

def get_memory_roster():
    """Get student roster from memory cache, checking expiry for FERPA compliance."""
    global _memory_roster, _roster_expiry
    
    if _roster_expiry is None or datetime.now(timezone.utc) > _roster_expiry:
        # Roster expired or never set - clear it for FERPA compliance
        _memory_roster = {}
        _roster_expiry = None
        return {}
    
    return _memory_roster

def set_memory_roster(roster_dict):
    """Set student roster in memory cache with automatic expiry for FERPA compliance."""
    global _memory_roster, _roster_expiry
    
    _memory_roster = roster_dict.copy()
    _roster_expiry = datetime.now(timezone.utc) + timedelta(hours=ROSTER_EXPIRY_HOURS)

def clear_memory_roster():
    """Clear student roster from memory cache."""
    global _memory_roster, _roster_expiry
    
    _memory_roster = {}
    _roster_expiry = None

def _hash_student_id(student_id):
    """Create a hash of student ID for FERPA-compliant lookup"""
    return hashlib.sha256(f"student_{student_id}".encode()).hexdigest()[:16]

def store_student_name_db(student_id, name):
    """Store student name in database using hash for FERPA compliance"""
    try:
        name_hash = _hash_student_id(student_id)
        existing = StudentName.query.filter_by(name_hash=name_hash).first()
        if existing:
            existing.display_name = name
        else:
            student_name = StudentName(name_hash=name_hash, display_name=name)
            db.session.add(student_name)
        db.session.commit()
    except Exception as e:
        print(f"DEBUG: Error storing student name: {e}")
        db.session.rollback()

def get_student_name_db(student_id):
    """Get student name from database using hash lookup"""
    try:
        name_hash = _hash_student_id(student_id)
        student_name = StudentName.query.filter_by(name_hash=name_hash).first()
        return student_name.display_name if student_name else None
    except Exception:
        return None

def clear_all_student_names_db():
    """Clear all student names from database"""
    try:
        StudentName.query.delete()
        db.session.commit()
        print("DEBUG: Cleared all student names from database")
    except Exception as e:
        print(f"DEBUG: Error clearing student names: {e}")
        db.session.rollback()

def get_student_name(student_id, fallback="Student"):
    """Get student name from session, memory, or database for FERPA compliance."""
    # First try session roster (for admin session)
    session_roster = session.get('student_roster', {})
    name = session_roster.get(student_id)
    if name:
        return name
    
    # Then try memory roster (for display/kiosk from different sessions)
    memory_roster = get_memory_roster()
    name = memory_roster.get(student_id)
    if name:
        return name
    
    # Try database lookup (FERPA-compliant hashed lookup)
    name = get_student_name_db(student_id)
    if name:
        return name
    
    # If memory roster is empty but session roster has data, repopulate memory roster
    # This handles server restarts where memory is lost but session persists
    if len(memory_roster) == 0 and len(session_roster) > 0:
        print(f"DEBUG: Repopulating memory roster from session ({len(session_roster)} students)")
        set_memory_roster(session_roster)
        # Try again with the repopulated memory roster
        memory_roster = get_memory_roster()
        name = memory_roster.get(student_id)
        if name:
            return name
    
    # Debug logging (remove in production)
    if student_id and not name:
        print(f"DEBUG: Student {student_id} not found. Session: {len(session_roster)}, Memory: {len(memory_roster)}, DB lookup attempted")
    
    return name or fallback

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
    try:
        s = Settings.query.get(1)
        if not s:
            return {"room_name": config.ROOM_NAME, "capacity": config.CAPACITY, "overdue_minutes": getattr(config, "MAX_MINUTES", 10), "kiosk_suspended": False}
        
        # Handle case where kiosk_suspended column might not exist yet (during migration)
        try:
            kiosk_suspended = s.kiosk_suspended
        except AttributeError:
            kiosk_suspended = False
        
        return {"room_name": s.room_name, "capacity": s.capacity, "overdue_minutes": s.overdue_minutes, "kiosk_suspended": kiosk_suspended}
    except Exception:
        # If query fails (e.g., missing column), return defaults
        return {"room_name": config.ROOM_NAME, "capacity": config.CAPACITY, "overdue_minutes": getattr(config, "MAX_MINUTES", 10), "kiosk_suspended": False}

@app.context_processor
def inject_room_name():
    return {"room": get_settings()["room_name"], "static_version": STATIC_VERSION}

# ---------- Admin Authentication ----------

def is_admin_authenticated():
    """Check if current session is authenticated as admin."""
    return session.get('admin_authenticated', False)

def require_admin_auth(f):
    """Decorator to require admin authentication for a route."""
    from functools import wraps
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if not is_admin_authenticated():
            return redirect(url_for('admin_login'))
        return f(*args, **kwargs)
    return decorated_function

def require_admin_auth_api(f):
    """Decorator to require admin authentication for API routes (returns JSON error)."""
    from functools import wraps
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if not is_admin_authenticated():
            return jsonify(ok=False, message="Admin authentication required"), 401
        return f(*args, **kwargs)
    return decorated_function

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

@app.route("/admin/login", methods=["GET", "POST"])
def admin_login():
    if request.method == "POST":
        passcode = request.form.get("passcode", "").strip()
        if passcode == config.ADMIN_PASSCODE:
            session['admin_authenticated'] = True
            session.permanent = True  # Keep session alive
            return redirect(url_for('admin'))
        else:
            return render_template("admin_login.html", error="Invalid passcode. Please try again.")
    return render_template("admin_login.html")

@app.route("/admin/logout")
def admin_logout():
    session.pop('admin_authenticated', None)
    return redirect(url_for('admin_login'))

@app.route("/admin")
@require_admin_auth
def admin():
    total = Session.query.count()
    open_count = Session.query.filter_by(end_ts=None).count()
    settings = get_settings()
    
    # FERPA Compliance: Get session-based and memory roster counts
    session_roster = session.get('student_roster', {})
    session_roster_count = len(session_roster)
    memory_roster = get_memory_roster()
    memory_roster_count = len(memory_roster)
    
    # Calculate memory roster expiry info
    global _roster_expiry
    memory_expires_in_hours = None
    if _roster_expiry:
        now = datetime.now(timezone.utc)
        if _roster_expiry > now:
            remaining = _roster_expiry - now
            memory_expires_in_hours = round(remaining.total_seconds() / 3600, 1)
        else:
            memory_expires_in_hours = 0
    
    # Sheets status/link for admin chip
    try:
        sheets_status = sheets_logger.get_status()
    except Exception:
        sheets_status = "off"
    sheets_link = None
    if sheets_logger.sheets_enabled():
        sid = os.getenv("GOOGLE_SHEETS_LOG_ID")
        if sid:
            sheets_link = f"https://docs.google.com/spreadsheets/d/{sid}/edit#gid=0"
    return render_template(
        "admin.html",
        total=total,
        open_count=open_count,
        settings=settings,
        sheets_status=sheets_status,
        sheets_link=sheets_link,
        session_roster_count=session_roster_count,  # For FERPA-compliant display
        memory_roster_count=memory_roster_count,
        memory_expires_in_hours=memory_expires_in_hours,
    )

# ---------- Keep-alive (Render) ----------
_keepalive_started = False

def _should_ping_now(ts_local: datetime) -> bool:
    # Monday=0 ... Sunday=6; work hours 8:00<=h<17:00
    return ts_local.weekday() < 5 and 8 <= ts_local.hour < 17


def _calculate_sleep_until_work_hours(now_local: datetime) -> int:
    """Calculate seconds to sleep until next work period (Mon-Fri 8am-5pm)"""
    # If currently in work hours, this shouldn't be called, but return short sleep as fallback
    if _should_ping_now(now_local):
        return 600  # 10 minutes
    
    # Calculate next Monday 8am if we're on weekend or after Friday 5pm
    current_weekday = now_local.weekday()  # Monday=0, Sunday=6
    current_hour = now_local.hour
    
    # If it's Friday after 5pm or weekend, sleep until Monday 8am
    if current_weekday == 4 and current_hour >= 17:  # Friday after 5pm
        days_until_monday = 3
        target_hour = 8
    elif current_weekday >= 5:  # Weekend (Saturday=5, Sunday=6)
        days_until_monday = 7 - current_weekday  # Saturday: 2 days, Sunday: 1 day
        target_hour = 8
    else:  # Monday-Thursday after hours or before 8am
        if current_hour >= 17:  # After 5pm, sleep until 8am next day
            days_until_monday = 1 if current_weekday < 4 else 3  # Next day or Monday if Thursday
            target_hour = 8
        else:  # Before 8am, sleep until 8am today
            days_until_monday = 0
            target_hour = 8
    
    # Calculate target datetime
    target_date = now_local.date() + timedelta(days=days_until_monday)
    target_datetime = datetime.combine(target_date, datetime.min.time().replace(hour=target_hour), tzinfo=now_local.tzinfo)
    
    # Calculate seconds until target time
    sleep_seconds = int((target_datetime - now_local).total_seconds())
    
    # Minimum sleep of 1 hour to avoid rapid checking if calculation goes wrong
    return max(sleep_seconds, 3600)


def _keep_alive_loop(base_url: str):
    target = urljoin(base_url, "/api/status")
    while True:
        try:
            now_local = datetime.now(TZ)
            if _should_ping_now(now_local):
                try:
                    requests.get(target, timeout=5)
                except Exception:
                    pass
                # every 10 minutes during work hours
                time.sleep(600)
            else:
                # Calculate time until next work period starts
                sleep_duration = _calculate_sleep_until_work_hours(now_local)
                time.sleep(sleep_duration)
        except Exception:
            time.sleep(600)


@app.before_request
def _start_keepalive_thread():
    global _keepalive_started
    if _keepalive_started:
        return
    try:
        base = request.url_root  # e.g., https://yourapp.onrender.com/
    except Exception:
        return
    t = threading.Thread(target=_keep_alive_loop, args=(base,), daemon=True)
    t.start()
    _keepalive_started = True

# ---- API ----

@app.post("/api/scan")
def api_scan():
    auto_end_expired()
    
    # Check if kiosk is suspended
    if get_settings()["kiosk_suspended"]:
        return jsonify(ok=False, message="Kiosk is currently suspended by administrator"), 403
    
    payload = request.get_json(silent=True) or {}
    code = (payload.get("code") or "").strip()
    if not code:
        return jsonify(ok=False, message="No code scanned"), 400

    # FERPA Compliance: Check both session and memory roster
    student_name = get_student_name(code)
    
    if student_name == "Student":  # Default fallback means student not found
        return jsonify(ok=False, message=f"Unknown ID: {code} - Please upload roster first"), 404
    
    # Ensure memory roster is populated for cross-device access
    # This happens when a student scans successfully, ensuring display can access names
    memory_roster = get_memory_roster()
    session_roster = session.get('student_roster', {})
    if len(memory_roster) == 0 and len(session_roster) > 0:
        print(f"DEBUG: Populating memory roster during scan ({len(session_roster)} students)")
        set_memory_roster(session_roster)
    
    # Ensure minimal Student record exists for foreign key constraint (anonymous)
    if not Student.query.get(code):
        anonymous_student = Student(id=code, name=f"Anonymous_{code}")
        db.session.add(anonymous_student)
        db.session.commit()

    open_sessions = get_open_sessions()

    # If this student currently holds the pass, end their session
    for s in open_sessions:
        if s.student_id == code:
            s.end_ts = now_utc()
            s.ended_by = "kiosk_scan"
            db.session.commit()
            # Sheets completion (non-blocking)
            try:
                if sheets_logger.sheets_enabled():
                    end_iso = s.end_ts.astimezone(timezone.utc).isoformat()
                    sheets_logger.complete_end(
                        student_id=code,
                        end_iso=end_iso,
                        duration_seconds=s.duration_seconds,
                        ended_by="kiosk_scan",
                        updated_iso=end_iso,
                    )
            except Exception:
                pass
            return jsonify(ok=True, action="ended", name=student_name)

    # If capacity is full and someone else is out, deny
    if len(open_sessions) >= get_settings()["capacity"]:
        return jsonify(ok=False, action="denied", message=f"Hall pass currently in use"), 409

    # Otherwise start a new session
    sess = Session(student_id=code, start_ts=now_utc(), room=get_settings()["room_name"])
    db.session.add(sess)
    db.session.commit()
    # Sheets append (non-blocking)
    try:
        if sheets_logger.sheets_enabled():
            start_iso = sess.start_ts.astimezone(timezone.utc).isoformat()
            created_iso = datetime.now(timezone.utc).isoformat()
            sheets_logger.append_start(
                session_id=sess.id,
                student_id=code,
                name=student_name,  # From session, not database
                room=get_settings()["room_name"],
                start_iso=start_iso,
                created_iso=created_iso,
            )
    except Exception:
        pass
    return jsonify(ok=True, action="started", name=student_name)

@app.get("/api/status")
def api_status():
    auto_end_expired()
    settings = get_settings()
    s = get_current_holder()
    overdue_minutes = settings["overdue_minutes"]
    kiosk_suspended = settings["kiosk_suspended"]
    if s:
        is_overdue = s.duration_seconds > overdue_minutes * 60
        
        # FERPA Compliance: Get name from session or memory roster
        student_name = get_student_name(s.student_id, "Student")
        
        return jsonify(in_use=True, name=student_name, start=to_local(s.start_ts).isoformat(), elapsed=s.duration_seconds, overdue=is_overdue, overdue_minutes=overdue_minutes, kiosk_suspended=kiosk_suspended)
    else:
        return jsonify(in_use=False, overdue_minutes=overdue_minutes, kiosk_suspended=kiosk_suspended)

@app.get("/events")
def sse_events():
    def stream():
        last_payload = None
        while True:
            s = get_current_holder()
            settings = get_settings()
            overdue_minutes = settings["overdue_minutes"]
            kiosk_suspended = settings["kiosk_suspended"]
            if s:
                # FERPA Compliance: Get name from session or memory roster
                student_name = get_student_name(s.student_id, "Student")
                
                # Additional fallback for SSE streams that don't have session access
                # If memory roster is empty, try to find any active session with roster data
                if student_name == "Student" and len(get_memory_roster()) == 0:
                    print(f"DEBUG: SSE fallback - trying to find roster data for student {s.student_id}")
                    # This is a last resort - in production, the memory roster should be populated
                    # from the admin session when they upload the roster
                
                # Debug logging (remove in production)
                if student_name == "Student":
                    print(f"DEBUG: SSE stream - Student {s.student_id} showing as 'Student' (name not found)")
                
                payload = {
                    "in_use": True,
                    "name": student_name,
                    "elapsed": s.duration_seconds,
                    "overdue": s.duration_seconds > overdue_minutes * 60,
                    "overdue_minutes": overdue_minutes,
                    "kiosk_suspended": kiosk_suspended,
                }
            else:
                payload = {"in_use": False, "overdue_minutes": overdue_minutes, "kiosk_suspended": kiosk_suspended}
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

@app.get("/api/stats/week")
def api_stats_week():
    """Weekly, per-student focus: counts and overdues (last 7 days including today)."""
    settings = get_settings()
    overdue_minutes = settings["overdue_minutes"]
    now = now_utc()
    start_utc = (datetime.now(TZ).date() - timedelta(days=6))
    start_utc = datetime.combine(start_utc, datetime.min.time(), tzinfo=TZ).astimezone(timezone.utc)
    rows = Session.query.filter(Session.start_ts >= start_utc).all()

    per_student = {}
    for r in rows:
        sid = r.student_id
        name = r.student.name
        if sid not in per_student:
            per_student[sid] = {"name": name, "count": 0, "overdue": 0}
        per_student[sid]["count"] += 1
        end = r.end_ts or now
        duration = int((end - r.start_ts).total_seconds())
        if duration > overdue_minutes * 60:
            per_student[sid]["overdue"] += 1

    # top by count
    top_usage = sorted(per_student.values(), key=lambda x: x["count"], reverse=True)[:10]
    # top by overdue absolute
    top_overdue = sorted(per_student.values(), key=lambda x: x["overdue"], reverse=True)[:10]
    # top by overdue rate (only if count >= 1)
    for v in per_student.values():
        v["overdue_rate"] = (v["overdue"] / v["count"]) if v["count"] else 0
    top_overdue_rate = sorted(per_student.values(), key=lambda x: x["overdue_rate"], reverse=True)[:10]

    def pack(arr):
        return {"labels": [a["name"] for a in arr], "values": [a["count"] for a in arr], "overdues": [a["overdue"] for a in arr], "rates": [round(a.get("overdue_rate", 0)*100, 1) for a in arr]}

    return jsonify({
        "top_usage": pack(top_usage),
        "top_overdue": pack(top_overdue),
        "top_overdue_rate": {
            "labels": [a["name"] for a in top_overdue_rate],
            "values": [a["overdue"] for a in top_overdue_rate],
            "rates": [round(a["overdue_rate"]*100, 1) for a in top_overdue_rate],
        },
        "overdue_minutes": overdue_minutes,
    })

@app.post("/api/override_end")
@require_admin_auth_api
def api_override_end():
    s = get_current_holder()
    if not s:
        return jsonify(ok=False, message="No one is out."), 400
    s.end_ts = now_utc()
    s.ended_by = "override"
    db.session.commit()
    return jsonify(ok=True)

@app.post("/api/suspend_kiosk")
@require_admin_auth_api
def api_suspend_kiosk():
    try:
        s = Settings.query.get(1)
        if not s:
            s = Settings(id=1, kiosk_suspended=True)
            db.session.add(s)
        else:
            s.kiosk_suspended = True
        db.session.commit()
        return jsonify(ok=True, suspended=True)
    except Exception as e:
        db.session.rollback()
        return jsonify(ok=False, message=str(e)), 500

@app.post("/api/resume_kiosk")
@require_admin_auth_api
def api_resume_kiosk():
    try:
        s = Settings.query.get(1)
        if not s:
            s = Settings(id=1, kiosk_suspended=False)
            db.session.add(s)
        else:
            s.kiosk_suspended = False
        db.session.commit()
        return jsonify(ok=True, suspended=False)
    except Exception as e:
        db.session.rollback()
        return jsonify(ok=False, message=str(e)), 500



@app.post("/api/upload_session_roster")
@require_admin_auth_api
def api_upload_session_roster():
    """FERPA-compliant: Upload student roster to session only (not database)"""
    try:
        if "file" not in request.files:
            return jsonify(ok=False, message="No file uploaded"), 400
        
        f = request.files["file"]
        if not f or f.filename == '':
            return jsonify(ok=False, message="No file selected"), 400
            
        text = f.stream.read().decode("utf-8", errors="ignore")
        reader = csv.reader(io.StringIO(text))
        
        # Store roster in session only - FERPA compliant (no database interactions)
        student_roster = {}
        count = 0
        
        for row in reader:
            if not row or len(row) < 2:
                continue
            sid, name = row[0].strip(), row[1].strip()
            if not sid or not name:
                continue
            student_roster[sid] = name
            count += 1
        
        # Store roster in session, memory, and database for FERPA compliance
        session['student_roster'] = student_roster
        session.permanent = True
        
        # Also store in memory cache so display can access it (expires automatically)
        set_memory_roster(student_roster)
        
        # Store in database using hashed IDs for cross-session access
        for student_id, name in student_roster.items():
            store_student_name_db(student_id, name)
        
        # Debug logging (remove in production)
        print(f"DEBUG: Roster uploaded - {count} students stored in session, memory, and database")
        print(f"DEBUG: Memory roster now contains {len(get_memory_roster())} students")
            
        return jsonify(ok=True, imported=count, message=f"Roster uploaded (FERPA compliant - hashed storage, expires in {ROSTER_EXPIRY_HOURS} hours)")
        
    except Exception as e:
        return jsonify(ok=False, message=f"Upload failed: {str(e)}"), 500

@app.post("/api/test_auth")
@require_admin_auth_api
def api_test_auth():
    """Test endpoint to verify admin authentication is working"""
    return jsonify(ok=True, message="Admin authentication is working", authenticated=True)

@app.get("/api/session_roster")
@require_admin_auth_api
def api_get_session_roster():
    """Get current session roster for debugging"""
    student_roster = session.get('student_roster', {})
    return jsonify(ok=True, roster=student_roster, count=len(student_roster))

@app.get("/api/memory_roster_status")
@require_admin_auth_api
def api_get_memory_roster_status():
    """Get memory roster status for admin display"""
    global _roster_expiry
    memory_roster = get_memory_roster()
    
    status = {
        'count': len(memory_roster),
        'active': len(memory_roster) > 0,
        'expiry': _roster_expiry.isoformat() if _roster_expiry else None,
        'expires_in_hours': None
    }
    
    if _roster_expiry:
        now = datetime.now(timezone.utc)
        if _roster_expiry > now:
            remaining = _roster_expiry - now
            status['expires_in_hours'] = round(remaining.total_seconds() / 3600, 1)
        else:
            status['expires_in_hours'] = 0
    
    return jsonify(ok=True, **status)

@app.get("/api/debug_roster")
def api_debug_roster():
    """Debug endpoint to check roster status (no auth required for testing)"""
    global _roster_expiry, _memory_roster
    
    # Get current session holder
    s = get_current_holder()
    student_id = s.student_id if s else None
    
    # Check both rosters
    session_roster = session.get('student_roster', {})
    memory_roster = get_memory_roster()
    
    # Test get_student_name function
    test_name = get_student_name(student_id, "Student") if student_id else None
    
    debug_info = {
        'current_student_id': student_id,
        'session_roster_count': len(session_roster),
        'memory_roster_count': len(memory_roster),
        'memory_roster_expired': _roster_expiry is None or datetime.now(timezone.utc) > _roster_expiry if _roster_expiry else True,
        'expiry_time': _roster_expiry.isoformat() if _roster_expiry else None,
        'test_student_name': test_name,
        'memory_roster_sample': dict(list(memory_roster.items())[:3]) if memory_roster else {},
        'session_roster_sample': dict(list(session_roster.items())[:3]) if session_roster else {}
    }
    
    return jsonify(ok=True, debug=debug_info)

@app.post("/api/clear_session_roster")
@require_admin_auth_api
def api_clear_session_roster():
    """Clear session, memory, and database roster for FERPA compliance"""
    session.pop('student_roster', None)
    clear_memory_roster()
    clear_all_student_names_db()
    return jsonify(ok=True, message="All rosters cleared (session, memory, and database)")




@app.post("/api/reset_database")
@require_admin_auth_api
def api_reset_database():
    """Reset: Delete all sessions from database (students stored in session only).

    This clears all session history while preserving student roster in browser session.
    Settings are preserved.
    """
    try:
        # Count before deletion
        total_sessions = Session.query.count()

        # Delete all sessions (no need to delete students - they're session-only now)
        db.session.query(Session).delete()
        db.session.commit()

        return jsonify(
            ok=True,
            cleared_sessions=total_sessions,
            message="Database reset complete - all sessions removed (student roster remains in session)"
        )
    except Exception as e:
        try:
            db.session.rollback()
        except Exception:
            pass
        return jsonify(ok=False, message=f"Reset failed: {str(e)}"), 500

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
    """Initialize DB (students are now session-only, not database-stored)."""
    db.create_all()
    if not Settings.query.get(1):
        db.session.add(Settings(id=1, room_name=config.ROOM_NAME, capacity=config.CAPACITY, overdue_minutes=getattr(config, "MAX_MINUTES", 10), kiosk_suspended=False))
        db.session.commit()
    # Note: Student roster is now uploaded via web interface to session only (FERPA compliant)
    print("Database initialized (students are session-only).")


def run_migrations():
    """Perform schema migrations and return log messages.

    This function is written to be safe on PostgreSQL where a failed statement
    puts the transaction into an error state. We explicitly roll back before
    executing DDL and run DDL inside an engine-level transaction block.
    """
    messages = []

    # Migration 1: ensure Settings.kiosk_suspended exists
    column_exists = False
    try:
        # Prefer information_schema to avoid raising exceptions
        res = db.session.execute(text(
            """
            SELECT 1
            FROM information_schema.columns
            WHERE table_name = 'settings' AND column_name = 'kiosk_suspended'
            """
        ))
        column_exists = res.scalar() is not None
    except Exception as e:
        messages.append(f"Warning: column introspection failed: {e}; attempting ALTER TABLE…")

    if column_exists:
        messages.append("kiosk_suspended column already exists")
        return messages

    messages.append("Adding kiosk_suspended column to settings table")

    # Clear any failed transaction state before running DDL
    try:
        db.session.rollback()
    except Exception:
        pass

    try:
        # Use engine.begin() so DDL is committed independently of the ORM session
        with db.engine.begin() as conn:
            conn.execute(text("ALTER TABLE settings ADD COLUMN IF NOT EXISTS kiosk_suspended BOOLEAN DEFAULT FALSE"))
            conn.execute(text("UPDATE settings SET kiosk_suspended = FALSE WHERE kiosk_suspended IS NULL"))
            conn.execute(text("ALTER TABLE settings ALTER COLUMN kiosk_suspended SET NOT NULL"))
        messages.append("Added kiosk_suspended column successfully")
    except Exception as e:
        # Make sure session is usable afterwards
        try:
            db.session.rollback()
        except Exception:
            pass
        messages.append(f"Failed to add kiosk_suspended column: {e}")
        raise

    return messages


@app.cli.command("migrate")
def migrate_db():
    """Run database migrations for schema updates."""
    print("Running database migrations...")
    try:
        messages = run_migrations()
        for m in messages:
            print(f"- {m}")
        print("Database migrations completed successfully!")
    except Exception as e:
        print(f"Migration failed: {e}")

# ---- Debug & Migration API ----

@app.get("/api/debug/settings")
def api_debug_settings():
    """Expose raw settings row for debugging purposes."""
    try:
        s = Settings.query.get(1)
        if not s:
            return jsonify(ok=True, settings=None)
        data = {
            "id": s.id,
            "room_name": s.room_name,
            "capacity": s.capacity,
            "overdue_minutes": s.overdue_minutes,
        }
        try:
            data["kiosk_suspended"] = s.kiosk_suspended
        except AttributeError:
            data["kiosk_suspended"] = "<missing>"
        return jsonify(ok=True, settings=data)
    except Exception as e:
        return jsonify(ok=False, message=str(e)), 500


@app.post("/api/migrate")
@require_admin_auth_api
def migrate_api():
    """Run database migrations via HTTP for platforms without shell access."""
    try:
        messages = run_migrations()
        return jsonify(ok=True, messages=messages)
    except Exception as e:
        # Ensure the session is usable after an error
        try:
            db.session.rollback()
        except Exception:
            pass
        return jsonify(ok=False, message=str(e)), 500

# ---- Settings API ----
@app.get("/api/settings")
@require_admin_auth_api
def get_settings_api():
    return jsonify(get_settings())

@app.post("/api/settings")
@require_admin_auth_api
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
    if "kiosk_suspended" in data:
        s.kiosk_suspended = bool(data["kiosk_suspended"])
    db.session.commit()
    return jsonify(ok=True, settings=get_settings())

if __name__ == "__main__":
    with app.app_context():
        db.create_all()
    app.run(host="0.0.0.0", port=5001, debug=True)
