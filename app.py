import csv
import io
import sys
import os
import json
import time
import hashlib
from datetime import datetime, timezone, timedelta
from zoneinfo import ZoneInfo
from typing import Dict, Optional, List, Any
from functools import wraps

from flask import Flask, jsonify, render_template, request, redirect, url_for, send_file, Response, stream_with_context, session
from werkzeug.middleware.proxy_fix import ProxyFix
from flask_sqlalchemy import SQLAlchemy
from sqlalchemy import text

import config
import sheets_logger
import threading
import requests
from urllib.parse import urljoin
from cryptography.fernet import Fernet
import base64

# Import services
from services.roster import RosterService
from services.ban import BanService
from services.session import SessionService

# Import models
from models.user import create_user_model

app = Flask(__name__)
# Fix for Render/Heroku: Trust X-Forwarded-Proto header for HTTPS
app.wsgi_app = ProxyFix(app.wsgi_app, x_for=1, x_proto=1, x_host=1, x_prefix=1)

# Prefer DATABASE_URL from env (Render), else config.py
app.config["SQLALCHEMY_DATABASE_URI"] = os.getenv("DATABASE_URL", config.DATABASE_URL)
app.config["SQLALCHEMY_TRACK_MODIFICATIONS"] = False
app.config["SECRET_KEY"] = config.SECRET_KEY
app.config["PERMANENT_SESSION_LIFETIME"] = timedelta(hours=8)  # Admin sessions last 8 hours

# Google OAuth config (2.0 multi-user support)
app.config["GOOGLE_CLIENT_ID"] = getattr(config, 'GOOGLE_CLIENT_ID', '')
app.config["GOOGLE_CLIENT_SECRET"] = getattr(config, 'GOOGLE_CLIENT_SECRET', '')

db = SQLAlchemy(app)
TZ = ZoneInfo(config.TIMEZONE)

# Encryption Key Setup
# We derive a Fernet key from the SECRET_KEY to ensure it's deterministic but secure
# If SECRET_KEY is changed, the database will need to be cleared/re-uploaded
def _get_encryption_key():
    # Pad or truncate SECRET_KEY to 32 bytes for base64 encoding
    key_material = app.config["SECRET_KEY"].encode()
    # Use SHA256 to get 32 bytes
    key_32 = hashlib.sha256(key_material).digest()
    return base64.urlsafe_b64encode(key_32)

cipher_suite = Fernet(_get_encryption_key())


# ---------- Models ----------

# Create User model for multi-tenancy (2.0)
User = create_user_model(db)

class Student(db.Model):
    id = db.Column(db.String, primary_key=True)          # barcode value or student id
    name = db.Column(db.String, nullable=False)
    # 2.0: Add user_id FK (nullable for migration compatibility)
    user_id = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=True, index=True)

class Session(db.Model):
    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    student_id = db.Column(db.String, db.ForeignKey("student.id"), nullable=False, index=True)
    start_ts = db.Column(db.DateTime(timezone=True), nullable=False, index=True)
    end_ts = db.Column(db.DateTime(timezone=True), nullable=True, index=True)
    ended_by = db.Column(db.String, nullable=True)       # "kiosk_scan", "override", "auto"
    room = db.Column(db.String, nullable=True)
    # 2.0: Add user_id FK (nullable for migration compatibility)
    user_id = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=True, index=True)

    student = db.relationship("Student")
    user = db.relationship('User', backref='sessions')

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
    auto_ban_overdue = db.Column(db.Boolean, nullable=False, default=False)
    # 2.0: Add user_id FK (nullable for migration compatibility, ID=1 is legacy global)
    user_id = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=True, index=True)
    
    user = db.relationship('User', backref='settings')

class StudentName(db.Model):
    """FERPA-compliant storage of student names only (no ID association)"""
    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    name_hash = db.Column(db.String, nullable=False)  # Hash of student_id for lookup (removed unique, see constraint below)
    encrypted_id = db.Column(db.String, nullable=True)   # Encrypted ID for admin retrieval
    display_name = db.Column(db.String, nullable=False)  # Actual name to display
    created_at = db.Column(db.DateTime(timezone=True), nullable=False, default=lambda: datetime.now(timezone.utc))
    banned = db.Column(db.Boolean, nullable=False, default=False)  # Restroom ban flag
    # 2.0: Add user_id FK (nullable for migration compatibility)
    user_id = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=True, index=True)
    
    user = db.relationship('User', backref='student_names')
    
    # 2.0: Composite unique constraint - same student can exist for different users
    __table_args__ = (
        db.UniqueConstraint('user_id', 'name_hash', name='uq_user_name_hash'),
    )

# ---------- Service Initialization ----------
# Initialize services after models are defined
roster_service: Optional[RosterService] = None
ban_service: Optional[BanService] = None
session_service: Optional[SessionService] = None

def initialize_services():
    """Initialize service layer after app context is available"""
    global roster_service, ban_service, session_service
    roster_service = RosterService(db, cipher_suite, StudentName)
    ban_service = BanService(db, StudentName, roster_service)
    session_service = SessionService(db, Session)
    print("Services initialized successfully")

# Create tables after models are defined (works under Gunicorn too)
STATIC_VERSION = os.getenv("STATIC_VERSION", str(int(time.time())))

# Automatic database initialization - detects empty/new databases
def initialize_database_if_needed():
    """Initialize database tables and settings if they don't exist."""
    print("Starting database initialization check...")
    try:
        with app.app_context():
            print(f"Using database URL: {app.config['SQLALCHEMY_DATABASE_URI'][:50]}...")
            
            # First, try to create all tables (safe if they already exist)
            print("Creating database tables...")
            db.create_all()
            print("Tables created successfully")
            
            # IMPORTANT: Run migrations FIRST to add new columns before querying with them
            print("Running database migrations (adding new columns)...")
            try:
                msgs = run_migrations()
                for msg in msgs:
                    print(f"Migration: {msg}")
            except Exception as e:
                print(f"Migration warning (non-fatal): {e}")
                try:
                    db.session.rollback()
                except Exception:
                    pass
            
            # Initialize services
            initialize_services()
            
            # Check if Settings table exists and has data
            # Use raw SQL to avoid ORM column mapping issues
            settings_exists = False
            try:
                # Use raw SQL to check if settings record exists (avoids user_id column issue)
                result = db.session.execute(text("SELECT id FROM settings WHERE id = 1")).scalar()
                if result:
                    settings_exists = True
                    print("Database appears to be initialized (Settings found)")
                else:
                    print("Settings table exists but is empty - initializing...")
                    settings_exists = False
            except Exception as e:
                # Table doesn't exist or query failed
                print(f"Settings table query failed: {e} - will initialize...")
                try:
                    db.session.rollback()  # Clear failed transaction state
                except Exception:
                    pass
                settings_exists = False
            
            # Initialize settings if needed
            if not settings_exists:
                try:
                    db.session.rollback()  # Ensure clean transaction state
                    print("Creating default settings record...")
                    s = Settings(id=1, room_name=config.ROOM_NAME, capacity=config.CAPACITY,
                               overdue_minutes=getattr(config, "MAX_MINUTES", 10), kiosk_suspended=False, auto_ban_overdue=False)
                    db.session.add(s)
                    db.session.commit()
                    print("Database initialized successfully with default settings")
                except Exception as e:
                    print(f"ERROR: Could not initialize settings: {e}")
                    try:
                        db.session.rollback()
                    except Exception:
                        pass
                    raise  # Re-raise to see the full error
            
            # Test that we can actually query the database
            try:
                test_count = Session.query.count()
                print(f"Database test successful - found {test_count} sessions")
            except Exception as e:
                print(f"ERROR: Database test failed: {e}")
                raise

            
    except Exception as e:
        print(f"CRITICAL: Database initialization failed: {e}")
        import traceback
        print(f"Full traceback: {traceback.format_exc()}")
        # Don't re-raise - let the app try to start anyway



# ---------- Error Handling Utilities ----------

def handle_db_errors(f):
    """Decorator to handle database errors consistently."""
    @wraps(f)
    def wrapper(*args, **kwargs):
        try:
            return f(*args, **kwargs)
        except Exception as e:
            try:
                db.session.rollback()
            except Exception:
                pass
            return jsonify(ok=False, message=str(e)), 500
    return wrapper

# ---------- Utility (Context Resolver) ----------

def get_current_user_id(token: Optional[str] = None) -> Optional[int]:
    """
    Get the effective user_id context.
    1. If token provided (Kiosk/Display), resolve user from token.
    2. If logged in via session['user_id'], return that.
    3. If legacy admin_authenticated (no user_id), return None (global).
    """
    if token:
        user = User.query.filter((User.kiosk_token == token) | (User.kiosk_slug == token)).first()
        if user:
            return user.id
            
    if 'user_id' in session:
        return session['user_id']
        
    # Legacy: admin_authenticated but no user_id implies legacy global mode
    return None

# ---------- FERPA-Compliant Roster Utilities ----------

def get_memory_roster(user_id: Optional[int] = None) -> Dict[str, str]:
    """Get student roster from memory cache (scoped to user)."""
    return roster_service.get_memory_roster(user_id) if roster_service else {}

def set_memory_roster(roster_dict: Dict[str, str], user_id: Optional[int] = None) -> None:
    """Set student roster in memory cache (scoped to user)."""
    if roster_service:
        roster_service.set_memory_roster(user_id, roster_dict)

def clear_memory_roster(user_id: Optional[int] = None) -> None:
    """Clear student roster from memory cache (scoped to user)."""
    if roster_service:
        roster_service.clear_memory_roster(user_id)

def get_student_name(student_id: str, fallback: str = "Student", user_id: Optional[int] = None) -> str:
    """Get student name from memory or database (scoped to user)."""
    return roster_service.get_student_name(user_id, student_id, fallback) if roster_service else fallback

def is_student_banned(student_id: str, user_id: Optional[int] = None) -> bool:
    """Check if a student is banned from using the restroom (scoped to user)."""
    return ban_service.is_student_banned(user_id, student_id) if ban_service else False

def set_student_banned(student_id: str, banned_status: bool, user_id: Optional[int] = None) -> bool:
    """Ban or unban a student from using the restroom (scoped to user)."""
    return ban_service.set_student_banned(user_id, student_id, banned_status) if ban_service else False

def get_overdue_students(user_id: Optional[int] = None) -> List[Dict[str, Any]]:
    """Get list of students who are currently overdue (scoped to user)."""
    if not ban_service or not session_service:
        return []
    try:
        settings = get_settings(user_id)
        open_sessions = session_service.get_open_sessions(user_id)
        return ban_service.get_overdue_students(user_id, open_sessions, settings["overdue_minutes"])
    except Exception:
        return []

def auto_ban_overdue_students(user_id: Optional[int] = None) -> Dict[str, Any]:
    """Automatically ban students who are currently overdue (scoped to user)."""
    if not ban_service or not session_service:
        return {'count': 0, 'students': []}
    try:
        settings = get_settings(user_id)
        open_sessions = session_service.get_open_sessions(user_id)
        return ban_service.auto_ban_overdue_students(user_id, open_sessions, settings["overdue_minutes"])
    except Exception:
        return {'count': 0, 'students': []}

# ---------- Utility ----------

def now_utc():
    return datetime.now(timezone.utc)

def to_local(dt_utc):
    return dt_utc.astimezone(TZ)

def get_open_sessions(user_id: Optional[int] = None):
    """Get all currently open sessions (scoped to user)."""
    return session_service.get_open_sessions(user_id) if session_service else []

def get_current_holder(user_id: Optional[int] = None):
    """Get the first student currently holding the pass (scoped to user)."""
    return session_service.get_current_holder(user_id) if session_service else None

def get_settings(user_id: Optional[int] = None):
    """Get settings for a specific user (or legacy global defaults)."""
    try:
        s = None
        if user_id is not None:
             s = Settings.query.filter_by(user_id=user_id).first()
        
        # Fallback to legacy ID=1 if no user specified or no user settings found (though usually we should create them)
        if not s:
             s = Settings.query.get(1)

        if not s:
            return {"room_name": config.ROOM_NAME, "capacity": config.CAPACITY, "overdue_minutes": getattr(config, "MAX_MINUTES", 10), "kiosk_suspended": False, "auto_ban_overdue": False}
        
        # Handle case where columns might not exist yet (during migration)
        try:
            kiosk_suspended = s.kiosk_suspended
        except AttributeError:
            kiosk_suspended = False
        
        try:
            auto_ban_overdue = s.auto_ban_overdue
        except AttributeError:
            auto_ban_overdue = False
        
        return {"room_name": s.room_name, "capacity": s.capacity, "overdue_minutes": s.overdue_minutes, "kiosk_suspended": kiosk_suspended, "auto_ban_overdue": auto_ban_overdue}
    except Exception:
        # If query fails, return defaults
        return {"room_name": config.ROOM_NAME, "capacity": config.CAPACITY, "overdue_minutes": getattr(config, "MAX_MINUTES", 10), "kiosk_suspended": False, "auto_ban_overdue": False}

@app.context_processor
def inject_room_name():
    # Try to resolve user context to show correct room name
    token = request.args.get('token')
    user_id = get_current_user_id(token)
    return {"room": get_settings(user_id)["room_name"], "static_version": STATIC_VERSION}

# ---------- Admin Authentication ----------

def is_admin_authenticated():
    """Check if current session is authenticated as admin (Legacy Passcode OR Google OAuth)."""
    return session.get('admin_authenticated', False) or 'user_id' in session

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

# Register auth blueprint for Google OAuth (2.0)
from auth import auth_bp, init_oauth
app.register_blueprint(auth_bp)
init_oauth(app)

@app.route("/")
def index():
    return redirect(url_for("kiosk"))

# Legacy kiosk route (for backward compatibility and logged-in users)
@app.route("/kiosk")
def kiosk():
    user_id = get_current_user_id()
    if user_id:
        # Redirect logged-in users to their personal kiosk
        user = User.query.get(user_id)
        if user and user.kiosk_token:
             return redirect(url_for('public_kiosk', token=user.kiosk_slug or user.kiosk_token))
    return render_template("kiosk.html")

# Public kiosk routes (2.0 - no login required, token-based)
@app.route("/k/<token>")
@app.route("/kiosk/<token>")
def public_kiosk(token):
    """Public kiosk access via unique token or slug"""
    user = User.query.filter(
        (User.kiosk_token == token) | (User.kiosk_slug == token)
    ).first()
    if not user:
        return "Kiosk not found", 404
    return render_template("kiosk.html", user_id=user.id, user_name=user.name, token=token)

# Legacy display route (for backward compatibility)
@app.route("/display")
def display():
    user_id = get_current_user_id()
    if user_id:
        # Redirect logged-in users to their personal display
        user = User.query.get(user_id)
        if user and user.kiosk_token:
             return redirect(url_for('public_display', token=user.kiosk_slug or user.kiosk_token))
    return render_template("display.html")

# Public display routes (2.0 - no login required, token-based)
@app.route("/d/<token>")
@app.route("/display/<token>")
def public_display(token):
    """Public display access via unique token or slug"""
    user = User.query.filter(
        (User.kiosk_token == token) | (User.kiosk_slug == token)
    ).first()
    if not user:
        return "Display not found", 404
    return render_template("display.html", user_id=user.id, user_name=user.name, token=token)

@app.route("/admin/login", methods=["GET", "POST"])
def admin_login():
    if is_admin_authenticated():
        return redirect(url_for('admin'))
        
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
    """Teacher-facing admin dashboard (clean, user-friendly)"""
    # Get current user if OAuth is active
    current_user = None
    user_id = get_current_user_id()
    
    if user_id:
        current_user = User.query.get(user_id)
    
    # Scope queries to current user if available
    query_session = Session.query
    query_open = Session.query.filter_by(end_ts=None)
    query_roster = StudentName.query
    
    if user_id is not None:
        query_session = query_session.filter_by(user_id=user_id)
        query_open = query_open.filter_by(user_id=user_id)
        query_roster = query_roster.filter_by(user_id=user_id)
        
    total = query_session.count()
    open_count = query_open.count()
    db_roster_count = query_roster.count()
    
    settings = get_settings(user_id)
    
    try:
        # Roster counts
        memory_roster_count = len(get_memory_roster(user_id))
        
        # Build public URLs for Share/Embed section
        kiosk_urls = None
        if current_user:
            base_url = request.url_root.rstrip('/')
            kiosk_urls = current_user.get_public_urls(base_url)
        
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
            db_roster_count=db_roster_count,
            memory_roster_count=memory_roster_count,
            current_user=current_user,
            kiosk_urls=kiosk_urls,
        )
    except Exception as e:
        import traceback
        return f"Admin Page Error: {str(e)} <br><pre>{traceback.format_exc()}</pre>", 500


@app.route("/dev")
@require_admin_auth
def dev():
    """Developer-only admin page with database tools and debugging"""
    # Check if user is actually the developer (legacy auth or admin flag)
    current_user = None
    user_id = session.get('user_id')
    if user_id:
        current_user = User.query.get(user_id)
        # Only allow if user has is_admin flag or is using legacy auth
        if current_user and not current_user.is_admin:
            if not session.get('admin_authenticated'):
                return redirect(url_for('admin'))
    
    total = Session.query.count()
    open_count = Session.query.filter_by(end_ts=None).count()
    settings = get_settings()
    
    try:
        # All roster counts (global, not scoped)
        memory_roster_count = len(get_memory_roster())
        db_roster_count = StudentName.query.count()
        user_count = User.query.count()
        
        # Sheets status
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
            "dev.html",
            total=total,
            open_count=open_count,
            settings=settings,
            sheets_status=sheets_status,
            sheets_link=sheets_link,
            db_roster_count=db_roster_count,
            memory_roster_count=memory_roster_count,
            user_count=user_count,
            current_user=current_user,
        )
    except Exception as e:
        import traceback
        return f"Dev Page Error: {str(e)} <br><pre>{traceback.format_exc()}</pre>", 500

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
    payload = request.get_json(silent=True) or {}
    token = payload.get("token")
    user_id = get_current_user_id(token)

    # Check if kiosk is suspended
    settings = get_settings(user_id)
    if settings["kiosk_suspended"]:
        return jsonify(ok=False, message="Kiosk is currently suspended by administrator"), 403
    
    code = (payload.get("code") or "").strip()
    if not code:
        return jsonify(ok=False, message="No code scanned"), 400

    # Look up student name from encrypted database
    student_name = get_student_name(code, user_id=user_id)
    
    if student_name == "Student":  # Default fallback means student not found
        # Check if roster is actually empty
        if len(get_memory_roster(user_id)) == 0:
            return jsonify(ok=False, message="Roster empty. Please upload student list."), 404
        else:
            return jsonify(ok=False, message=f"Incorrect ID: {code}"), 404
    
    # Ensure minimal Student record exists for foreign key constraint
    # (Note: Student table is global in ID, but scoped via user_id FK if we wanted strict separation)
    # Ideally checking existence by ID is enough, but for 2.0 we might want to attach user_id if creating new
    if not Student.query.get(code):
        anonymous_student = Student(id=code, name=f"Anonymous_{code}", user_id=user_id)
        db.session.add(anonymous_student)
        db.session.commit()

    open_sessions = get_open_sessions(user_id)

    # If this student currently holds the pass, end their session
    # Check if auto-ban is enabled and student is overdue BEFORE ending session
    for s in open_sessions:
        if s.student_id == code:
            # Check if student is overdue and auto-ban is enabled
            if settings.get("auto_ban_overdue", False):
                overdue_seconds = settings["overdue_minutes"] * 60
                if s.duration_seconds > overdue_seconds:
                    # Auto-ban this student for being overdue
                    if not is_student_banned(code, user_id=user_id):
                        set_student_banned(code, True, user_id=user_id)
                        print(f"AUTO-BAN ON SCAN-BACK: {student_name} ({code}) was overdue {round(s.duration_seconds / 60, 1)} minutes")
            
            # End the session
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
    
    # Check if student is banned from starting NEW restroom trips
    # (They can still end existing trips above)
    if is_student_banned(code, user_id=user_id):
        return jsonify(ok=False, action="banned", message="RESTROOM PRIVILEGES SUSPENDED - SEE TEACHER", name=student_name), 403

    # If capacity is full and someone else is out, deny
    if len(open_sessions) >= settings["capacity"]:
        return jsonify(ok=False, action="denied", message=f"Hall pass currently in use"), 409

    # Otherwise start a new session
    sess = Session(student_id=code, start_ts=now_utc(), room=settings["room_name"], user_id=user_id)
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
                room=settings["room_name"],
                start_iso=start_iso,
                created_iso=created_iso,
            )
    except Exception:
        pass
    return jsonify(ok=True, action="started", name=student_name)

@app.get("/api/status")
def api_status():
    token = request.args.get('token')
    user_id = get_current_user_id(token)
    settings = get_settings(user_id)
    
    s = get_current_holder(user_id)
    overdue_minutes = settings["overdue_minutes"]
    kiosk_suspended = settings["kiosk_suspended"]
    auto_ban_overdue = settings.get("auto_ban_overdue", False)
    
    if s:
        is_overdue = s.duration_seconds > overdue_minutes * 60
        
        # FERPA Compliance: Get name from session or memory roster
        student_name = get_student_name(s.student_id, "Student", user_id=user_id)
        
        return jsonify(in_use=True, name=student_name, start=to_local(s.start_ts).isoformat(), elapsed=s.duration_seconds, overdue=is_overdue, overdue_minutes=overdue_minutes, kiosk_suspended=kiosk_suspended, auto_ban_overdue=auto_ban_overdue)
    else:
        return jsonify(in_use=False, overdue_minutes=overdue_minutes, kiosk_suspended=kiosk_suspended, auto_ban_overdue=auto_ban_overdue)

@app.get("/events")
def sse_events():
    token = request.args.get('token')
    # Capture user_id at start of stream
    user_id = get_current_user_id(token)
    
    def stream():
        last_payload = None
        while True:
            # We must use proper application context inside generator if accessing DB lazily, 
            # but here we just call helpers which usually should be fine if app context is pushed.
            # However, stream_with_context handles the context.
            
            settings = get_settings(user_id)
            
            s = get_current_holder(user_id)
            overdue_minutes = settings["overdue_minutes"]
            kiosk_suspended = settings["kiosk_suspended"]
            auto_ban_overdue = settings.get("auto_ban_overdue", False)
            if s:
                student_name = get_student_name(s.student_id, "Student", user_id=user_id)
                payload = {
                    "in_use": True,
                    "name": student_name,
                    "elapsed": s.duration_seconds,
                    "overdue": s.duration_seconds > overdue_minutes * 60,
                    "overdue_minutes": overdue_minutes,
                    "kiosk_suspended": kiosk_suspended,
                    "auto_ban_overdue": auto_ban_overdue,
                }
            else:
                payload = {"in_use": False, "overdue_minutes": overdue_minutes, "kiosk_suspended": kiosk_suspended, "auto_ban_overdue": auto_ban_overdue}
            if payload != last_payload:
                yield f"data: {json.dumps(payload)}\n\n"
                last_payload = payload
            time.sleep(1)
    return Response(stream_with_context(stream()), mimetype="text/event-stream")

@app.get("/api/stats")
def api_stats():
    """Simple stats: today's hourly counts and last 7 days daily counts."""
    user_id = get_current_user_id()
    today_local = datetime.now(TZ).date()
    start_today = datetime.combine(today_local, datetime.min.time(), tzinfo=TZ).astimezone(timezone.utc)
    end_today = datetime.combine(today_local, datetime.max.time(), tzinfo=TZ).astimezone(timezone.utc)
    
    query = Session.query.filter(Session.start_ts >= start_today, Session.start_ts <= end_today)
    if user_id is not None:
        query = query.filter_by(user_id=user_id)
        
    rows_today = query.all()

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
        
        q = Session.query.filter(Session.start_ts >= ds, Session.start_ts <= de)
        if user_id is not None:
            q = q.filter_by(user_id=user_id)
            
        c = q.count()
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
    user_id = get_current_user_id()
    settings = get_settings(user_id)
    overdue_minutes = settings["overdue_minutes"]
    now = now_utc()
    start_utc = (datetime.now(TZ).date() - timedelta(days=6))
    start_utc = datetime.combine(start_utc, datetime.min.time(), tzinfo=TZ).astimezone(timezone.utc)
    
    query = Session.query.filter(Session.start_ts >= start_utc)
    if user_id is not None:
        query = query.filter_by(user_id=user_id)
        
    rows = query.all()

    per_student = {}
    for r in rows:
        sid = r.student_id
        # Prefer roster name over Student table name (fixes Anonymous entries)
        name = get_student_name(sid, r.student.name, user_id=user_id)
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
    user_id = get_current_user_id()
    s = get_current_holder(user_id)
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
        user_id = get_current_user_id()
        # Find or create settings for this user
        s = None
        if user_id is not None:
            s = Settings.query.filter_by(user_id=user_id).first()
        else:
            s = Settings.query.get(1)
            
        if not s:
            # Create new settings record
            s = Settings(id=1 if user_id is None else None, user_id=user_id, kiosk_suspended=True, room_name=config.ROOM_NAME, capacity=config.CAPACITY)
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
        user_id = get_current_user_id()
        # Find or create settings for this user
        s = None
        if user_id is not None:
            s = Settings.query.filter_by(user_id=user_id).first()
        else:
            s = Settings.query.get(1)
            
        if not s:
            s = Settings(id=1 if user_id is None else None, user_id=user_id, kiosk_suspended=False, room_name=config.ROOM_NAME, capacity=config.CAPACITY)
            db.session.add(s)
        else:
            s.kiosk_suspended = False
        db.session.commit()
        return jsonify(ok=True, suspended=False)
    except Exception as e:
        db.session.rollback()
        return jsonify(ok=False, message=str(e)), 500

@app.post("/api/toggle_kiosk_suspend_quick")
def api_toggle_kiosk_suspend_quick():
    """Toggle kiosk suspension without passcode (for emergency kiosk shortcut)."""
    try:
        # Resolve user context from token (sent by frontend) or session
        payload = request.get_json(silent=True) or {}
        token = payload.get("token")
        user_id = get_current_user_id(token)
        
        # Toggle suspension
        s = None
        if user_id is not None:
            s = Settings.query.filter_by(user_id=user_id).first()
        else:
            s = Settings.query.get(1)
            
        if not s:
            s = Settings(id=1 if user_id is None else None, user_id=user_id, kiosk_suspended=True, room_name=config.ROOM_NAME, capacity=config.CAPACITY)
            db.session.add(s)
            new_state = True
        else:
            s.kiosk_suspended = not s.kiosk_suspended
            new_state = s.kiosk_suspended
        
        db.session.commit()
        return jsonify(ok=True, suspended=new_state, message=f"Kiosk {'suspended' if new_state else 'resumed'}")
    except Exception as e:
        db.session.rollback()
        return jsonify(ok=False, message=str(e)), 500

@app.get("/api/students")
@require_admin_auth_api
@handle_db_errors
def api_get_students():
    """Get list of all students with their ban status from the database."""
    user_id = get_current_user_id()
    # Get all students from database (scoped to user)
    # RosterService handles scoping via student_names table
    # StudentName query:
    query = StudentName.query
    if user_id is not None:
        query = query.filter_by(user_id=user_id)
        
    student_records = query.all()
    students = []
    
    for record in student_records:
        # Decrypt ID if available
        sid = None
        if record.encrypted_id:
            try:
                sid = cipher_suite.decrypt(record.encrypted_id.encode()).decode()
            except Exception:
                # If decryption fails (e.g. key changed), skip or show placeholder
                sid = f"ERR_{record.id}"
        
        if sid:
            students.append({
                'id': sid,
                'name': record.display_name,
                'banned': record.banned
            })
    
    # Sort alphabetically by name
    students.sort(key=lambda x: x['name'].lower())
    
    return jsonify(ok=True, students=students, count=len(students))

@app.post("/api/ban_student")
@require_admin_auth_api
@handle_db_errors
def api_ban_student():
    """Ban a student from using the restroom."""
    user_id = get_current_user_id()
    payload = request.get_json(silent=True) or {}
    student_id = payload.get('student_id', '').strip()
    
    if not student_id:
        return jsonify(ok=False, message="No student ID provided"), 400
    
    # Get student name to confirm they exist
    student_name = get_student_name(student_id, user_id=user_id)
    if student_name == "Student":
        return jsonify(ok=False, message="Student not found in roster"), 404
    
    # Set ban status
    success = set_student_banned(student_id, True, user_id=user_id)
    
    if success:
        return jsonify(ok=True, message=f"{student_name} banned from restroom", student_id=student_id)
    else:
        return jsonify(ok=False, message="Failed to ban student"), 500

@app.post("/api/unban_student")
@require_admin_auth_api
@handle_db_errors
def api_unban_student():
    """Unban a student from using the restroom."""
    user_id = get_current_user_id()
    payload = request.get_json(silent=True) or {}
    student_id = payload.get('student_id', '').strip()
    
    if not student_id:
        return jsonify(ok=False, message="No student ID provided"), 400
    
    # Get student name to confirm they exist
    student_name = get_student_name(student_id, user_id=user_id)
    if student_name == "Student":
        return jsonify(ok=False, message="Student not found in roster"), 404
    
    # Remove ban status
    success = set_student_banned(student_id, False, user_id=user_id)
    
    if success:
        return jsonify(ok=True, message=f"{student_name} unbanned from restroom", student_id=student_id)
    else:
        return jsonify(ok=False, message="Failed to unban student"), 500

@app.get("/api/overdue_students")
@require_admin_auth_api
@handle_db_errors
def api_get_overdue_students():
    """Get list of students who are currently overdue."""
    user_id = get_current_user_id()
    overdue_list = get_overdue_students(user_id)
    settings = get_settings(user_id)
    
    return jsonify(
        ok=True, 
        students=overdue_list, 
        count=len(overdue_list),
        overdue_threshold_minutes=settings["overdue_minutes"]
    )

@app.post("/api/auto_ban_overdue")
@require_admin_auth_api
@handle_db_errors
def api_auto_ban_overdue():
    """Manually trigger auto-ban for all students who are currently overdue."""
    user_id = get_current_user_id()
    result = auto_ban_overdue_students(user_id)
    
    return jsonify(
        ok=True, 
        message=f"Manually banned {result['count']} overdue student(s)",
        banned_count=result['count'],
        students=result['students']
    )



@app.post("/api/upload_session_roster")
@require_admin_auth_api
def api_upload_session_roster():
    """Upload student roster to database (encrypted) for persistent access."""
    try:
        user_id = get_current_user_id()
        if "file" not in request.files:
            return jsonify(ok=False, message="No file uploaded"), 400
        
        f = request.files["file"]
        if not f or f.filename == '':
            return jsonify(ok=False, message="No file selected"), 400
            
        text = f.stream.read().decode("utf-8", errors="ignore")
        reader = csv.reader(io.StringIO(text))
        
        student_roster = {}
        count = 0
        
        # Clear existing memory roster to force refresh
        clear_memory_roster(user_id)
        
        # We don't clear the DB first - we upsert/add. 
        # If user wants to clear, they should use the clear endpoint first.
        
        for row in reader:
            if not row or len(row) < 2:
                continue
            sid, name = row[0].strip(), row[1].strip()
            if not sid or not name:
                continue
            student_roster[sid] = name
            count += 1
            
            # Store in DB (encrypted)
            roster_service.store_student_name(user_id, sid, name)
        
        # Populate memory cache for immediate performance
        set_memory_roster(student_roster, user_id)
        
        # Update any Anonymous students with real names from the roster
        # This global update needs review for multi-tenancy as Student table is mixed
        updated_count = roster_service.update_anonymous_students(Student)
            
        msg = f"Roster uploaded successfully ({count} students)."
        if updated_count > 0:
            msg += f" Updated {updated_count} previously anonymous entries."
        return jsonify(ok=True, imported=count, updated_anonymous=updated_count, message=msg)
        
    except Exception as e:
        return jsonify(ok=False, message=f"Upload failed: {str(e)}"), 500

@app.get("/api/memory_roster_status")
@require_admin_auth_api
def api_get_memory_roster_status():
    """Get memory roster status for admin display"""
    user_id = get_current_user_id()
    memory_roster = get_memory_roster(user_id)
    
    status = {
        'count': len(memory_roster),
        'active': len(memory_roster) > 0,
    }
    
    return jsonify(ok=True, **status)

@app.post("/api/clear_session_roster")
@require_admin_auth_api
def api_clear_session_roster():
    """Clear memory and database roster."""
    user_id = get_current_user_id()
    clear_memory_roster(user_id)
    roster_service.clear_all_student_names(user_id)
    return jsonify(ok=True, message="All rosters cleared")




@app.post("/api/reset_database")
@require_admin_auth_api
def api_reset_database():
    """Reset: Delete user's sessions from database.
    
    This clears all session history for the current user. Student roster and settings are preserved.
    """
    try:
        user_id = get_current_user_id()
        
        if user_id is not None:
             # Scope delete to user
             total_sessions = Session.query.filter_by(user_id=user_id).delete()
        else:
             # Legacy global wipe
             total_sessions = Session.query.delete()
             
        db.session.commit()

        return jsonify(
            ok=True,
            cleared_sessions=total_sessions,
            message="Database reset complete - sessions removed"
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
    # Note: export.csv is usually hit by browser so cookie auth works if admin logged in.
    # We should require authentication explicitly if not already (it wasn't fastidiously enforced before?)
    # Adding @require_admin_auth wrapper or just handling it inside
    if not is_admin_authenticated():
        return redirect(url_for('admin_login'))
        
    user_id = get_current_user_id()
    today_local = datetime.now(TZ).date()
    start = datetime.combine(today_local, datetime.min.time(), tzinfo=TZ).astimezone(timezone.utc)
    end = datetime.combine(today_local, datetime.max.time(), tzinfo=TZ).astimezone(timezone.utc)

    query = Session.query.filter(Session.start_ts >= start, Session.start_ts <= end)
    if user_id is not None:
        query = query.filter_by(user_id=user_id)
        
    rows = query.order_by(Session.start_ts.asc()).all()

    out = io.StringIO()
    w = csv.writer(out)
    w.writerow(["student_id", "name", "start_local", "end_local", "duration_seconds", "ended_by", "overdue"])
    
    settings = get_settings(user_id)
    overdue_minutes = settings["overdue_minutes"]
    
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

@app.post("/api/settings/kiosk-slug")
@require_admin_auth_api
def api_set_kiosk_slug():
    """Set a custom slug for the kiosk URL."""
    try:
        user_id = get_current_user_id()
        if not user_id:
            return jsonify(ok=False, message="Feature available for registered users only"), 403
            
        payload = request.get_json(silent=True) or {}
        slug = payload.get("slug", "").strip()
        
        # Validation
        if not slug:
            return jsonify(ok=False, message="Slug cannot be empty"), 400
            
        if len(slug) < 3:
            return jsonify(ok=False, message="Slug must be at least 3 characters"), 400
            
        import re
        if not re.match(r"^[a-zA-Z0-9-_]+$", slug):
            return jsonify(ok=False, message="Slug can only contain letters, numbers, hyphens, and underscores"), 400
            
        # Check uniqueness
        existing_user = User.query.filter(
            (User.kiosk_slug == slug) | (User.kiosk_token == slug)
        ).first()
        
        if existing_user and existing_user.id != user_id:
             return jsonify(ok=False, message="Slug is already taken"), 409
             
        # Update user
        user = User.query.get(user_id)
        user.kiosk_slug = slug
        db.session.commit()
        
        return jsonify(ok=True, slug=slug, message="Kiosk URL updated successfully")
        
    except Exception as e:
        db.session.rollback()
        return jsonify(ok=False, message=str(e)), 500

# ---------- Developer API ----------

@app.get("/api/dev/users")
@require_admin_auth_api
def api_dev_users():
    """Get list of all users (developer only)"""
    try:
        users = User.query.all()
        user_list = []
        for u in users:
            session_count = Session.query.filter_by(user_id=u.id).count()
            user_list.append({
                'id': u.id,
                'email': u.email,
                'name': u.name,
                'is_admin': u.is_admin,
                'kiosk_token': u.kiosk_token,
                'kiosk_slug': u.kiosk_slug,
                'session_count': session_count,
                'created_at': u.created_at.isoformat() if u.created_at else None,
                'last_login': u.last_login.isoformat() if u.last_login else None,
            })
        return jsonify(ok=True, users=user_list, count=len(user_list))
    except Exception as e:
        return jsonify(ok=False, message=str(e)), 500


@app.post("/api/dev/set_admin")
@require_admin_auth_api
def api_dev_set_admin():
    """Set a user's admin flag (developer only)"""
    payload = request.get_json(silent=True) or {}
    target_user_id = payload.get('user_id')
    is_admin = payload.get('is_admin', False)
    
    if not target_user_id:
        return jsonify(ok=False, message="user_id required"), 400
    
    try:
        user = User.query.get(target_user_id)
        if not user:
            return jsonify(ok=False, message="User not found"), 404
        
        user.is_admin = is_admin
        db.session.commit()
        return jsonify(ok=True, message=f"User {user.email} admin status: {is_admin}")
    except Exception as e:
        db.session.rollback()
        return jsonify(ok=False, message=str(e)), 500

# ---------- CLI helpers ----------

@app.cli.command("init-db")
def init_db():
    """Initialize database tables and default settings."""
    db.create_all()
    if not Settings.query.get(1):
        db.session.add(Settings(id=1, room_name=config.ROOM_NAME, capacity=config.CAPACITY, overdue_minutes=getattr(config, "MAX_MINUTES", 10), kiosk_suspended=False, auto_ban_overdue=False))
        db.session.commit()
    print("Database initialized successfully.")


def run_migrations():
    """Perform schema migrations and return log messages.

    This function is written to be safe on PostgreSQL where a failed statement
    puts the transaction into an error state. We explicitly roll back before
    executing DDL and run DDL inside an engine-level transaction block.
    """
    messages = []

    # Migration 1: ensure Settings.kiosk_suspended exists
    kiosk_suspended_exists = False
    try:
        # Prefer information_schema to avoid raising exceptions
        res = db.session.execute(text(
            """
            SELECT 1
            FROM information_schema.columns
            WHERE table_name = 'settings' AND column_name = 'kiosk_suspended'
            """
        ))
        kiosk_suspended_exists = res.scalar() is not None
    except Exception as e:
        messages.append(f"Warning: column introspection failed: {e}; attempting ALTER TABLE…")

    if not kiosk_suspended_exists:
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
    else:
        messages.append("kiosk_suspended column already exists")

    # Migration 2: ensure StudentName.banned exists
    banned_exists = False
    try:
        res = db.session.execute(text(
            """
            SELECT 1
            FROM information_schema.columns
            WHERE table_name = 'student_name' AND column_name = 'banned'
            """
        ))
        banned_exists = res.scalar() is not None
    except Exception as e:
        messages.append(f"Warning: banned column introspection failed: {e}; attempting ALTER TABLE…")

    if not banned_exists:
        messages.append("Adding banned column to student_name table")

        # Clear any failed transaction state before running DDL
        try:
            db.session.rollback()
        except Exception:
            pass

        try:
            # Use engine.begin() so DDL is committed independently of the ORM session
            with db.engine.begin() as conn:
                conn.execute(text("ALTER TABLE student_name ADD COLUMN IF NOT EXISTS banned BOOLEAN DEFAULT FALSE"))
                conn.execute(text("UPDATE student_name SET banned = FALSE WHERE banned IS NULL"))
                conn.execute(text("ALTER TABLE student_name ALTER COLUMN banned SET NOT NULL"))
            messages.append("Added banned column successfully")
        except Exception as e:
            # Make sure session is usable afterwards
            try:
                db.session.rollback()
            except Exception:
                pass
            messages.append(f"Failed to add banned column: {e}")
            raise
    else:
        messages.append("banned column already exists")

    # Migration 3: ensure Settings.auto_ban_overdue exists
    auto_ban_overdue_exists = False
    try:
        res = db.session.execute(text(
            """
            SELECT 1
            FROM information_schema.columns
            WHERE table_name = 'settings' AND column_name = 'auto_ban_overdue'
            """
        ))
        auto_ban_overdue_exists = res.scalar() is not None
    except Exception as e:
        messages.append(f"Warning: auto_ban_overdue column introspection failed: {e}; attempting ALTER TABLE…")

    if not auto_ban_overdue_exists:
        messages.append("Adding auto_ban_overdue column to settings table")

        # Clear any failed transaction state before running DDL
        try:
            db.session.rollback()
        except Exception:
            pass

        try:
            # Use engine.begin() so DDL is committed independently of the ORM session
            with db.engine.begin() as conn:
                conn.execute(text("ALTER TABLE settings ADD COLUMN IF NOT EXISTS auto_ban_overdue BOOLEAN DEFAULT FALSE"))
                conn.execute(text("UPDATE settings SET auto_ban_overdue = FALSE WHERE auto_ban_overdue IS NULL"))
                conn.execute(text("ALTER TABLE settings ALTER COLUMN auto_ban_overdue SET NOT NULL"))
            messages.append("Added auto_ban_overdue column successfully")
        except Exception as e:
            # Make sure session is usable afterwards
            try:
                db.session.rollback()
            except Exception:
                pass
            messages.append(f"Failed to add auto_ban_overdue column: {e}")
            raise
    else:
        messages.append("auto_ban_overdue column already exists")

    # Migration 4: ensure StudentName.encrypted_id exists
    try:
        with db.engine.connect() as conn:
            res = conn.execute(text(
                "SELECT column_name FROM information_schema.columns WHERE table_name='student_name' AND column_name='encrypted_id'"
            ))
            if res.scalar():
                messages.append("encrypted_id column already exists")
            else:
                conn.execute(text("ALTER TABLE student_name ADD COLUMN IF NOT EXISTS encrypted_id VARCHAR"))
                conn.commit()
                messages.append("Added encrypted_id column successfully")
                
    except Exception as e:
        messages.append(f"Failed to add encrypted_id column: {e}")
        raise e

    # ===== 2.0 MIGRATIONS =====
    
    # Migration 5: Create User table if not exists
    try:
        db.create_all()  # This will create User table if it doesn't exist
        messages.append("User table created/verified")
    except Exception as e:
        messages.append(f"Warning: User table creation: {e}")
    
    # Migration 5b: Ensure all User table columns exist (fixes partial table creation)
    user_columns = [
        ("user", "google_id", "VARCHAR"),
        ("user", "email", "VARCHAR"),
        ("user", "name", "VARCHAR"),
        ("user", "picture_url", "VARCHAR"),
        ("user", "kiosk_token", "VARCHAR"),
        ("user", "kiosk_slug", "VARCHAR"),
        ("user", "created_at", "TIMESTAMP WITH TIME ZONE"),
        ("user", "last_login", "TIMESTAMP WITH TIME ZONE"),
        ("user", "is_admin", "BOOLEAN DEFAULT FALSE"),
    ]
    
    for table_name, column_name, column_type in user_columns:
        try:
            res = db.session.execute(text(f"""
                SELECT 1 FROM information_schema.columns
                WHERE table_name = '{table_name}' AND column_name = '{column_name}'
            """))
            if res.scalar() is None:
                messages.append(f"Adding {column_name} to {table_name}")
                try:
                    db.session.rollback()
                except Exception:
                    pass
                with db.engine.begin() as conn:
                    conn.execute(text(f'ALTER TABLE "{table_name}" ADD COLUMN IF NOT EXISTS {column_name} {column_type}'))
                messages.append(f"Added {column_name} to {table_name}")
        except Exception as e:
            messages.append(f"User column {column_name}: {e}")
            
    # Migration 5c: Cleanup legacy display_name column if it exists (causes NOT NULL errors)
    try:
        res = db.session.execute(text("""
            SELECT 1 FROM information_schema.columns 
            WHERE table_name = 'user' AND column_name = 'display_name'
        """))
        if res.scalar() is not None:
            messages.append("Found legacy display_name column. Cleaning up...")
            try:
                db.session.rollback()
            except Exception:
                pass
            with db.engine.begin() as conn:
                # Copy display_name to name if name is null
                conn.execute(text('UPDATE "user" SET name = display_name WHERE name IS NULL'))
                # Drop the legacy column
                conn.execute(text('ALTER TABLE "user" DROP COLUMN display_name'))
            messages.append("Removed legacy display_name column")
    except Exception as e:
        messages.append(f"Warning: display_name cleanup: {e}")
    
    # Migration 6: Add user_id columns to existing tables
    user_id_migrations = [
        ("settings", "user_id"),
        ("session", "user_id"),
        ("student_name", "user_id"),
        ("student", "user_id"),
    ]
    
    for table_name, column_name in user_id_migrations:
        column_exists = False
        try:
            res = db.session.execute(text(f"""
                SELECT 1 FROM information_schema.columns
                WHERE table_name = '{table_name}' AND column_name = '{column_name}'
            """))
            column_exists = res.scalar() is not None
        except Exception:
            pass
        
        if not column_exists:
            messages.append(f"Adding {column_name} column to {table_name} table")
            try:
                db.session.rollback()
            except Exception:
                pass
            
            try:
                with db.engine.begin() as conn:
                    conn.execute(text(f"ALTER TABLE {table_name} ADD COLUMN IF NOT EXISTS {column_name} INTEGER"))
                messages.append(f"Added {column_name} to {table_name} successfully")
            except Exception as e:
                try:
                    db.session.rollback()
                except Exception:
                    pass
                messages.append(f"Failed to add {column_name} to {table_name}: {e}")
        else:
            messages.append(f"{column_name} column already exists in {table_name}")
    
    # Migration 7: Create default migration user for legacy data if needed
    try:
        # Check if there's any legacy data without user_id
        legacy_settings = Settings.query.filter_by(user_id=None).first()
        if legacy_settings:
            # Check if migration user exists
            migration_user = User.query.filter_by(google_id="LEGACY_MIGRATION").first()
            if not migration_user:
                import secrets
                migration_user = User(
                    google_id="LEGACY_MIGRATION",
                    email="legacy@halllday.local",
                    name="Legacy Data (Pre-2.0)",
                    kiosk_token=secrets.token_urlsafe(16)
                )
                db.session.add(migration_user)
                db.session.commit()
                messages.append(f"Created migration user (ID: {migration_user.id})")
            
            # Backfill user_id on legacy records
            Settings.query.filter_by(user_id=None).update({Settings.user_id: migration_user.id})
            Session.query.filter_by(user_id=None).update({Session.user_id: migration_user.id})
            StudentName.query.filter_by(user_id=None).update({StudentName.user_id: migration_user.id})
            Student.query.filter_by(user_id=None).update({Student.user_id: migration_user.id})
            db.session.commit()
            messages.append("Backfilled user_id on legacy records")
        else:
            messages.append("No legacy data migration needed")
    except Exception as e:
        try:
            db.session.rollback()
        except Exception:
            pass
        messages.append(f"Legacy data migration: {e}")

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

@app.get("/api/debug/database")
def api_debug_database():
    """Debug endpoint to check database status - accessible without auth for troubleshooting."""
    debug_info = {
        "database_url": app.config['SQLALCHEMY_DATABASE_URI'][:50] + "..." if len(app.config['SQLALCHEMY_DATABASE_URI']) > 50 else app.config['SQLALCHEMY_DATABASE_URI'],
        "tables_exist": {},
        "settings_record": None,
        "session_count": None,
        "errors": []
    }
    
    # Check if each table exists and can be queried
    tables_to_check = [
        ("settings", Settings),
        ("session", Session),
        ("student", Student),
        ("student_name", StudentName)
    ]
    
    for table_name, model_class in tables_to_check:
        try:
            count = model_class.query.count()
            debug_info["tables_exist"][table_name] = f"exists ({count} records)"
        except Exception as e:
            debug_info["tables_exist"][table_name] = f"error: {str(e)}"
            debug_info["errors"].append(f"{table_name}: {str(e)}")
    
    # Try to get settings record
    try:
        s = Settings.query.get(1)
        if s:
            debug_info["settings_record"] = {
                "id": s.id,
                "room_name": s.room_name,
                "capacity": s.capacity,
                "overdue_minutes": s.overdue_minutes,
                "kiosk_suspended": getattr(s, 'kiosk_suspended', 'missing_column')
            }
        else:
            debug_info["settings_record"] = "not_found"
    except Exception as e:
        debug_info["settings_record"] = f"error: {str(e)}"
        debug_info["errors"].append(f"settings_query: {str(e)}")
    
    # Try to count sessions
    try:
        debug_info["session_count"] = Session.query.count()
    except Exception as e:
        debug_info["session_count"] = f"error: {str(e)}"
        debug_info["errors"].append(f"session_count: {str(e)}")
    
    return jsonify(ok=True, debug=debug_info)


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
    if "auto_ban_overdue" in data:
        s.auto_ban_overdue = bool(data["auto_ban_overdue"])
    db.session.commit()
    return jsonify(ok=True, settings=get_settings())

if __name__ == "__main__":
    with app.app_context():
        db.create_all()
    app.run(host="0.0.0.0", port=5001, debug=True)

# Run automatic initialization (must be after all functions are defined)
# Only run this if we are in the main process (not a reloader or worker)
if os.environ.get("WERKZEUG_RUN_MAIN") == "true" or not os.environ.get("WERKZEUG_RUN_MAIN"):
    try:
        initialize_database_if_needed()
    except Exception as e:
        print(f"Startup initialization failed: {e}")

# CRITICAL FIX for Render/Gunicorn with --preload:
# We must close the database connection pool in the parent process after initialization.
# This forces each forked worker to create its own clean SSL connection.
# Without this, workers inherit a broken SSL state and fail with "decryption failed".
with app.app_context():
    db.engine.dispose()
