"""
Roster Service: Handles student roster management
Centralizes all roster operations for FERPA-compliant student data handling
"""
from typing import Dict, Optional
import hashlib
from cryptography.fernet import Fernet


class RosterService:
    def __init__(self, db, cipher_suite: Fernet, student_name_model):
        """
        Initialize RosterService
        
        Args:
            db: SQLAlchemy database instance
            cipher_suite: Fernet encryption instance
            student_name_model: StudentName model class
        """
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
        except Exception as e:
            print(f"DEBUG: Error storing student name: {e}")
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
            print("DEBUG: Cleared all student names from database")
        except Exception as e:
            print(f"DEBUG: Error clearing student names: {e}")
            self.db.session.rollback()
