"""
Session Service: Handles hallpass session management
"""
from typing import Optional, List
from datetime import datetime, timezone


class SessionService:
    def __init__(self, db, session_model):
        self.db = db
        self.Session = session_model
    
    def get_open_sessions(self) -> List:
        """Get all currently open sessions"""
        try:
            return self.Session.query.filter_by(end_ts=None).order_by(
                self.Session.start_ts.asc()
            ).all()
        except Exception:
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
