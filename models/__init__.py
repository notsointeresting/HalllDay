# Models package initialization
# User model uses factory pattern - import create_user_model, not User directly
from .user import create_user_model

__all__ = ['create_user_model']
