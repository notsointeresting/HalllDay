import os

# App configuration with environment variable support
CAPACITY = int(os.getenv("HALLPASS_CAPACITY", "1"))  # How many students can be out at once
MAX_MINUTES = int(os.getenv("HALLPASS_MAX_MINUTES", "12"))  # Overdue threshold in minutes
ROOM_NAME = os.getenv("HALLPASS_ROOM_NAME", "Hall Pass")  # Default room name
TIMEZONE = os.getenv("HALLPASS_TIMEZONE", "America/Chicago")  # For display and CSV export
SECRET_KEY = os.getenv("HALLPASS_SECRET_KEY", "change-me-in-production")  # Flask session key
DATABASE_URL = os.getenv("DATABASE_URL", "sqlite:///instance/hallpass.db")  # Use relative path for local dev

# Google OAuth Configuration (for 2.0 multi-user support)
GOOGLE_CLIENT_ID = os.getenv("GOOGLE_CLIENT_ID", "")
GOOGLE_CLIENT_SECRET = os.getenv("GOOGLE_CLIENT_SECRET", "")

# Legacy admin passcode (deprecated in 2.0, kept for migration/fallback)
ADMIN_PASSCODE = os.getenv("HALLPASS_ADMIN_PASSCODE", "admin123")

