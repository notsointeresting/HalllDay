"""
Ban Service: Handles student ban management
"""
from typing import Dict, List, Any


class BanService:
    def __init__(self, db, student_name_model, roster_service):
        self.db = db
        self.StudentName = student_name_model
        self.roster_service = roster_service
    
    def is_student_banned(self, student_id: str) -> bool:
        """Check if a student is banned from using the restroom"""
        try:
            name_hash = self.roster_service._hash_student_id(student_id)
            student_name = self.StudentName.query.filter_by(name_hash=name_hash).first()
            return student_name.banned if student_name else False
        except Exception:
            return False
    
    def set_student_banned(self, student_id: str, banned_status: bool) -> bool:
        """Ban or unban a student from using the restroom"""
        try:
            name_hash = self.roster_service._hash_student_id(student_id)
            student_name = self.StudentName.query.filter_by(name_hash=name_hash).first()
            if student_name:
                student_name.banned = banned_status
                self.db.session.commit()
                return True
            return False
        except Exception:
            try:
                self.db.session.rollback()
            except Exception:
                pass
            return False
    
    def get_overdue_students(self, open_sessions: list, overdue_minutes: int) -> List[Dict[str, Any]]:
        """Get list of students who are currently overdue"""
        try:
            overdue_seconds = overdue_minutes * 60
            overdue_list = []
            
            for session_obj in open_sessions:
                if session_obj.duration_seconds > overdue_seconds:
                    student_name = self.roster_service.get_student_name(
                        session_obj.student_id, "Student"
                    )
                    is_banned = self.is_student_banned(session_obj.student_id)
                    
                    overdue_list.append({
                        'student_id': session_obj.student_id,
                        'name': student_name,
                        'duration_seconds': session_obj.duration_seconds,
                        'duration_minutes': round(session_obj.duration_seconds / 60, 1),
                        'start_ts': session_obj.start_ts.isoformat(),
                        'banned': is_banned,
                        'session_id': session_obj.id
                    })
            
            return overdue_list
        except Exception:
            return []
    
    def auto_ban_overdue_students(self, open_sessions: list, overdue_minutes: int) -> Dict[str, Any]:
        """Automatically ban students who are currently overdue"""
        try:
            overdue_list = self.get_overdue_students(open_sessions, overdue_minutes)
            banned_count = 0
            banned_students = []
            
            for student in overdue_list:
                if not student['banned']:
                    success = self.set_student_banned(student['student_id'], True)
                    if success:
                        banned_count += 1
                        banned_students.append(student['name'])
            
            return {'count': banned_count, 'students': banned_students}
        except Exception:
            return {'count': 0, 'students': []}
