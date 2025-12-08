"""
Roster Service: Handles student roster management
Refactored for 2.0 multi-tenancy with user_id scoping
"""
from typing import Dict, Optional


class RosterService:
    def __init__(self, db, cipher_suite, student_name_model, user_id: Optional[int] = None):
        """
        Initialize RosterService.
        
        Args:
            db: SQLAlchemy database instance
            cipher_suite: Fernet cipher for encryption
            student_name_model: StudentName model class
            user_id: Optional user ID for scoping (None = legacy/global mode)
        """
        self.db = db
        self.cipher_suite = cipher_suite
        self.StudentName = student_name_model
        self._user_id = user_id
        self._memory_roster: Dict[str, str] = {}
    
    def set_user_id(self, user_id: int) -> None:
        """Set the user_id for scoped queries (call this per-request)"""
        self._user_id = user_id
        self._memory_roster = {}  # Clear cache when switching users
    
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
            
            # Build query with optional user_id scoping
            query = self.StudentName.query.filter_by(name_hash=name_hash)
            if self._user_id is not None:
                query = query.filter_by(user_id=self._user_id)
            
            existing = query.first()
            if existing:
                existing.display_name = name
                existing.encrypted_id = encrypted_id
            else:
                student_name = self.StudentName(
                    name_hash=name_hash, 
                    display_name=name, 
                    encrypted_id=encrypted_id,
                    user_id=self._user_id  # 2.0: Associate with user
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
            
            # Build query with optional user_id scoping
            query = self.StudentName.query.filter_by(name_hash=name_hash)
            if self._user_id is not None:
                query = query.filter_by(user_id=self._user_id)
            
            student_name = query.first()
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
        """Clear all student names from database (scoped to user if set)"""
        try:
            if self._user_id is not None:
                self.StudentName.query.filter_by(user_id=self._user_id).delete()
            else:
                self.StudentName.query.delete()
            self.db.session.commit()
        except Exception:
            self.db.session.rollback()
    
    def get_all_students(self) -> list:
        """Get all students for the current user (for admin display)"""
        try:
            query = self.StudentName.query
            if self._user_id is not None:
                query = query.filter_by(user_id=self._user_id)
            return query.all()
        except Exception:
            return []
    
    def update_anonymous_students(self, student_model) -> int:
        """
        Update Student.name for any Anonymous_* entries matching the roster.
        Called after roster upload to retroactively fix anonymous entries.
        Returns the count of updated students.
        
        NOTE (v2.0): Scoped to current user if user_id is set.
        """
        updated_count = 0
        try:
            # Build query with optional user_id scoping
            query = student_model.query.filter(
                student_model.name.like('Anonymous_%')
            )
            if self._user_id is not None:
                query = query.filter_by(user_id=self._user_id)
            
            anonymous_students = query.all()
            
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


# Import at top level after class definition to avoid circular import
import hashlib

