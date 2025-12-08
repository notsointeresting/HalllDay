"""
Authentication Module: Google OAuth for HalllDay 2.0
"""
from functools import wraps
from datetime import datetime, timezone

from flask import Blueprint, redirect, url_for, session, request, jsonify, current_app
from authlib.integrations.flask_client import OAuth

auth_bp = Blueprint('auth', __name__, url_prefix='/auth')
oauth = OAuth()


def init_oauth(app):
    """Initialize OAuth with the Flask app"""
    oauth.init_app(app)
    
    # Only register Google if credentials are configured
    if app.config.get('GOOGLE_CLIENT_ID') and app.config.get('GOOGLE_CLIENT_SECRET'):
        oauth.register(
            name='google',
            client_id=app.config['GOOGLE_CLIENT_ID'],
            client_secret=app.config['GOOGLE_CLIENT_SECRET'],
            server_metadata_url='https://accounts.google.com/.well-known/openid-configuration',
            client_kwargs={
                'scope': 'openid email profile'
            },
        )
        app.logger.info("Google OAuth configured successfully")
    else:
        app.logger.warning("Google OAuth not configured - GOOGLE_CLIENT_ID or GOOGLE_CLIENT_SECRET missing")


def get_current_user():
    """Get the current logged-in user from session"""
    user_id = session.get('user_id')
    if not user_id:
        return None
    
    # Import here to avoid circular imports
    from app import User, db
    return User.query.get(user_id)


def require_auth(f):
    """Decorator to require Google authentication for a route"""
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if not session.get('user_id'):
            # Store the original URL to redirect back after login
            session['next_url'] = request.url
            return redirect(url_for('auth.login'))
        return f(*args, **kwargs)
    return decorated_function


def require_auth_api(f):
    """Decorator to require authentication for API routes (returns JSON error)"""
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if not session.get('user_id'):
            return jsonify(ok=False, message="Authentication required"), 401
        return f(*args, **kwargs)
    return decorated_function


@auth_bp.route('/debug')
def debug_auth():
    """Debug OAuth configuration (Temporary)"""
    # Check what Flask thinks the callback URL is
    callback_url = url_for('auth.callback', _external=True)
    
    # Check config presence
    client_id = current_app.config.get('GOOGLE_CLIENT_ID')
    client_secret = current_app.config.get('GOOGLE_CLIENT_SECRET')
    
    return jsonify({
        "callback_url_generated": callback_url,
        "client_id_configured": bool(client_id),
        "client_id_prefix": client_id[:5] + "..." if client_id else None,
        "client_secret_configured": bool(client_secret),
        "client_secret_length": len(client_secret) if client_secret else 0,
        "scheme": request.scheme,
        "headers": dict(request.headers)
    })


@auth_bp.route('/login')
def login():
    """Redirect to Google OAuth login"""
    # Check if OAuth is configured
    if not hasattr(oauth, 'google'):
        # Fall back to legacy login if OAuth not configured
        return redirect(url_for('admin_login'))
    
    # Build callback URL
    redirect_uri = url_for('auth.callback', _external=True)
    return oauth.google.authorize_redirect(redirect_uri)


@auth_bp.route('/callback')
def callback():
    """Handle Google OAuth callback"""
    from app import User, db
    
    try:
        token = oauth.google.authorize_access_token()
        user_info = token.get('userinfo')
        
        if not user_info:
            # Try to get user info from the id_token
            user_info = oauth.google.parse_id_token(token, None)
        
        if not user_info or not user_info.get('sub'):
            return "Failed to get user information from Google", 400
        
        google_id = user_info['sub']
        email = user_info.get('email', '')
        name = user_info.get('name', email.split('@')[0])
        picture = user_info.get('picture', '')
        
        # Find or create user
        user = User.query.filter_by(google_id=google_id).first()
        
        if not user:
            # Create new user
            user = User(
                google_id=google_id,
                email=email,
                name=name,
                picture_url=picture
            )
            db.session.add(user)
            current_app.logger.info(f"Created new user: {email}")
        else:
            # Update existing user info
            user.email = email
            user.name = name
            user.picture_url = picture
        
        user.update_last_login()
        db.session.commit()
        
        # Store user ID in session
        session['user_id'] = user.id
        session.permanent = True
        
        # Redirect to originally requested page or admin
        next_url = session.pop('next_url', None)
        return redirect(next_url or url_for('admin'))
        
    except Exception as e:
        current_app.logger.error(f"OAuth callback error: {str(e)}")
        return f"Authentication error: {str(e)}", 500


@auth_bp.route('/logout')
def logout():
    """Log out the current user"""
    session.pop('user_id', None)
    session.pop('admin_authenticated', None)  # Clear legacy auth too
    return redirect(url_for('index'))


@auth_bp.route('/me')
@require_auth_api
def me():
    """Get current user information (API)"""
    user = get_current_user()
    if not user:
        return jsonify(ok=False, message="Not authenticated"), 401
    
    return jsonify(
        ok=True,
        user={
            'id': user.id,
            'email': user.email,
            'name': user.name,
            'picture_url': user.picture_url,
            'kiosk_token': user.kiosk_token,
            'kiosk_slug': user.kiosk_slug,
        }
    )
