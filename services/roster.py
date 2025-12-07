"""
Roster Service: Handles student roster management
"""
from typing import Dict, Optional
import hashlib


class RosterService:
    def __init__(self, db, cipher_suite, student_name_model):
        self.db = db
        self.cipher_suite = cipher_suite
        self.StudentName = student_name_model
        self._memory_roster: Dict[str, str] = {}
    
    def _hash_student_id(self, student_id: str) -> str:
        """Create a hash of student ID for FERPA-compliant lookup"""
        return hashlib.sha256(f"student_{student_id}".encode()).hexdigest()[:16]
    
    def get_memory_roster(self) -> Dict[str, str]:
        """Get student roster from memory cache"""
        return self._memory_roster
    
    def set_memory_roster(self, roster_dict: Dict[str, str]) -> None:
        """Set student roster in memory cache"""
        self._memory_roster = roster_dict.copy()
    
    def clear_memory_roster(self) -> None:
        """Clear student roster from memory cache"""
        self._memory_roster = {}
    
    def store_student_name(self, student_id: str, name: str) -> None:
        """Store student name in database using hash for lookup and encryption for retrieval"""
        try:
            name_hash = self._hash_student_id(student_id)
            encrypted_id = self.cipher_suite.encrypt(student_id.encode()).decode()
            
            existing = self.StudentName.query.filter_by(name_hash=name_hash).first()
            if existing:
                existing.display_name = name
                existing.encrypted_id = encrypted_id
            else:
                student_name = self.StudentName(
                    name_hash=name_hash, 
                    display_name=name, 
                    encrypted_id=encrypted_id
                )
                self.db.session.add(student_name)
            self.db.session.commit()
        except Exception:
            try:
                self.db.session.rollback()
            except Exception:
                pass
    
    def get_student_name_from_db(self, student_id: str) -> Optional[str]:
        """Get student name from database using hash lookup"""
        try:
            name_hash = self._hash_student_id(student_id)
            student_name = self.StudentName.query.filter_by(name_hash=name_hash).first()
            return student_name.display_name if student_name else None
        except Exception:
            return None
    
    def get_student_name(self, student_id: str, fallback: str = "Student") -> str:
        """Get student name from memory or database"""
        # Try memory roster first (fastest)
        name = self._memory_roster.get(student_id)
        if name:
            return name
        
        # Try database lookup
        name = self.get_student_name_from_db(student_id)
        if name:
            # Cache it back to memory
            self._memory_roster[student_id] = name
            return name
        
        return fallback
    
    def clear_all_student_names(self) -> None:
        """Clear all student names from database"""
        try:
            self.StudentName.query.delete()
            self.db.session.commit()
        except Exception:
            self.db.session.rollback()
    
    def update_anonymous_students(self, student_model) -> int:
        """
        Update Student.name for any Anonymous_* entries matching the roster.
        Called after roster upload to retroactively fix anonymous entries.
        Returns the count of updated students.
        
        NOTE (v2.0): This may be legacy code. Since /api/stats/week now does 
        roster lookups via get_student_name(), this retroactive DB update is 
        mostly cosmetic. Consider removing in a 2.0 refactor if Student.name 
        is no longer used directly anywhere.
        """
        updated_count = 0
        try:
            # Get all Anonymous students from the Student table
            anonymous_students = student_model.query.filter(
                student_model.name.like('Anonymous_%')
            ).all()
            
            for student in anonymous_students:
                # Check if we have a real name in the roster
                real_name = self.get_student_name(student.id, fallback=None)
                if real_name and real_name != student.name:
                    student.name = real_name
                    updated_count += 1
            
            if updated_count > 0:
                self.db.session.commit()
                
        except Exception:
            try:
                self.db.session.rollback()
            except Exception:
                pass
        
        return updated_count
