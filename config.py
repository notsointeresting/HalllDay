import os

# App configuration with environment variable support
CAPACITY = int(os.getenv("HALLPASS_CAPACITY", "1"))  # How many students can be out at once
MAX_MINUTES = int(os.getenv("HALLPASS_MAX_MINUTES", "12"))  # Auto-end after this many minutes (failsafe)
ROOM_NAME = os.getenv("HALLPASS_ROOM_NAME", "Hall Pass")  # Default room name
TIMEZONE = os.getenv("HALLPASS_TIMEZONE", "America/Chicago")  # For display and CSV export
SECRET_KEY = os.getenv("HALLPASS_SECRET_KEY", "change-me-in-production")  # Flask session key
DATABASE_URL = os.getenv("DATABASE_URL", "sqlite:///instance/hallpass.db")  # Use relative path for local dev
