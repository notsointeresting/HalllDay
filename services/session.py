"""
Session Service: Handles hallpass session management
Centralizes session queries and operations
"""
from typing import Optional, List
from datetime import datetime, timezone


class SessionService:
    def __init__(self, db, session_model):
        """
        Initialize SessionService
        
        Args:
            db: SQLAlchemy database instance
            session_model: Session model class
        """
        self.db = db
        self.Session = session_model
    
    def get_open_sessions(self) -> List:
        """Get all currently open sessions"""
        try:
            return self.Session.query.filter_by(end_ts=None).order_by(
                self.Session.start_ts.asc()
            ).all()
        except Exception as e:
            print(f"DEBUG: Database error in get_open_sessions, rolling back: {e}")
            self.db.session.rollback()
            try:
                return self.Session.query.filter_by(end_ts=None).order_by(
                    self.Session.start_ts.asc()
                ).all()
            except Exception:
                return []
    
    def get_current_holder(self):
        """Get the first student currently holding the pass"""
        open_sessions = self.get_open_sessions()
        return open_sessions[0] if open_sessions else None
    
    def create_session(self, student_id: str, room_name: str):
        """Create a new session for a student"""
        now = datetime.now(timezone.utc)
        session = self.Session(
            student_id=student_id,
            start_ts=now,
            room=room_name
        )
        self.db.session.add(session)
        self.db.session.commit()
        return session
    
    def end_session(self, session_obj, ended_by: str = "kiosk_scan"):
        """End an active session"""
        session_obj.end_ts = datetime.now(timezone.utc)
        session_obj.ended_by = ended_by
        self.db.session.commit()
        return session_obj
