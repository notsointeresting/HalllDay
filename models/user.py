"""
User Model: Multi-tenancy support for HalllDay 2.0
"""
import secrets
from datetime import datetime, timezone


def create_user_model(db):
    """Factory function to create User model with the given db instance.
    
    This pattern allows the model to be created after the db is initialized
    in app.py, avoiding circular imports.
    """
    
    class User(db.Model):
        __tablename__ = 'user'
        
        id = db.Column(db.Integer, primary_key=True, autoincrement=True)
        
        # Google OAuth fields
        google_id = db.Column(db.String(255), unique=True, nullable=False)
        email = db.Column(db.String(255), unique=True, nullable=False)
        name = db.Column(db.String(255), nullable=False)
        picture_url = db.Column(db.String(512), nullable=True)
        
        # Public kiosk/display access tokens
        kiosk_token = db.Column(db.String(32), unique=True, nullable=False, 
                                default=lambda: secrets.token_urlsafe(16))
        kiosk_slug = db.Column(db.String(64), unique=True, nullable=True)  # Optional custom slug
        
        # Timestamps
        created_at = db.Column(db.DateTime(timezone=True), nullable=False, 
                              default=lambda: datetime.now(timezone.utc))
        last_login = db.Column(db.DateTime(timezone=True), nullable=True)
        
        # For admin/developer access (temporary during migration)
        is_admin = db.Column(db.Boolean, nullable=False, default=False)
        
        def __repr__(self):
            return f'<User {self.email}>'
        
        def update_last_login(self):
            """Update the last login timestamp"""
            self.last_login = datetime.now(timezone.utc)
        
        def regenerate_kiosk_token(self):
            """Generate a new kiosk token"""
            self.kiosk_token = secrets.token_urlsafe(16)
            return self.kiosk_token
        
        def set_kiosk_slug(self, slug: str) -> bool:
            """Set a custom kiosk slug, returns False if invalid"""
            if not slug:
                self.kiosk_slug = None
                return True
            
            # Validate slug format (lowercase, alphanumeric, hyphens only)
            import re
            if not re.match(r'^[a-z0-9][a-z0-9-]{2,62}[a-z0-9]$', slug):
                return False
            
            self.kiosk_slug = slug
            return True
        
        def get_public_urls(self, base_url: str) -> dict:
            """Get the public URLs for kiosk and display"""
            token = self.kiosk_slug or self.kiosk_token
            return {
                'kiosk': f"{base_url.rstrip('/')}/k/{token}",
                'display': f"{base_url.rstrip('/')}/d/{token}",
                'kiosk_full': f"{base_url.rstrip('/')}/kiosk/{token}",
                'display_full': f"{base_url.rstrip('/')}/display/{token}",
            }
    
    return User
