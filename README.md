# Hall Pass Tracker

A simple Flask web application that allows students to scan their ID badges to check hall passes in and out. Features a kiosk interface for scanning, a display screen for status monitoring, and an admin panel for management.

## Features

- **Kiosk Interface**: Students scan their ID to check passes in/out
- **Display Screen**: Shows current status (available/in use/overdue) 
- **Admin Panel**: Manage students, view analytics, suspend/resume kiosk
- **CSV Export**: Download daily session logs
- **Real-time Updates**: Live status updates via Server-Sent Events
- **Configurable**: Set room name, capacity, overdue thresholds

## Quick Start (Local Development)

```bash
# Clone and setup
git clone <your-repo-url>
cd hallpass-tracker
python -m venv .venv
source .venv/bin/activate  # Windows: .venv\Scripts\activate
pip install -r requirements.txt

# Initialize database and import sample students
flask --app app.py init-db

# Run development server
flask --app app.py run --debug
```

**Access the application:**
- `http://localhost:5000/kiosk` - Scanning interface for students
- `http://localhost:5000/display` - Status display for monitors/projectors  
- `http://localhost:5000/admin` - Admin management panel

## Configuration

The app uses environment variables for configuration. Set these in your deployment environment:

| Variable | Description | Default |
|----------|-------------|---------|
| `DATABASE_URL` | Database connection string | `sqlite:///instance/hallpass.db` |
| `HALLPASS_SECRET_KEY` | Flask secret key (change in production!) | `change-me-in-production` |
| `HALLPASS_ROOM_NAME` | Display name for the room/location | `Hall Pass` |
| `HALLPASS_CAPACITY` | Max students out simultaneously | `1` |
| `HALLPASS_MAX_MINUTES` | Minutes before marking overdue | `12` |
| `HALLPASS_TIMEZONE` | Timezone for displays and exports | `America/Chicago` |

## Cloud Deployment

### Render.com (Recommended)

1. **Fork this repository** to your GitHub account

2. **Create a new Web Service** on Render:
   - Connect your GitHub repository
   - Choose "Python" as the environment
   - Build command: `pip install -r requirements.txt`
   - Start command: `gunicorn app:app`

3. **Set Environment Variables** in Render dashboard:
   ```
   HALLPASS_SECRET_KEY=your-secret-key-here-make-it-long-and-random
   HALLPASS_ROOM_NAME=Your Room Name Here
   HALLPASS_CAPACITY=1
   HALLPASS_MAX_MINUTES=10
   HALLPASS_TIMEZONE=America/New_York
   ```

4. **Add PostgreSQL Database** (recommended for production):
   - Add a PostgreSQL add-on in Render
   - The `DATABASE_URL` will be automatically set

5. **Initialize Database**: After first deploy, run in Render shell:
   ```bash
   flask --app app.py init-db
   ```

### Railway

1. **Deploy from GitHub**:
   - Connect your repository
   - Railway will auto-detect Python and deploy

2. **Set Environment Variables**:
   ```
   HALLPASS_SECRET_KEY=your-secret-key
   HALLPASS_ROOM_NAME=Your Room Name
   ```

3. **Add PostgreSQL**: Add PostgreSQL service, `DATABASE_URL` will be set automatically

### Heroku

1. **Create Heroku app**:
   ```bash
   heroku create your-app-name
   heroku addons:create heroku-postgresql:mini
   ```

2. **Set config vars**:
   ```bash
   heroku config:set HALLPASS_SECRET_KEY=your-secret-key
   heroku config:set HALLPASS_ROOM_NAME="Your Room Name"
   ```

3. **Deploy**:
   ```bash
   git push heroku main
   heroku run flask --app app.py init-db
   ```

### Generic Linux VPS

1. **Install dependencies**:
   ```bash
   sudo apt update
   sudo apt install python3 python3-pip python3-venv nginx
   ```

2. **Setup application**:
   ```bash
   git clone <your-repo>
   cd hallpass-tracker
   python3 -m venv venv
   source venv/bin/activate
   pip install -r requirements.txt
   ```

3. **Set environment variables** in `/etc/environment` or `.bashrc`:
   ```bash
   export HALLPASS_SECRET_KEY="your-secret-key"
   export HALLPASS_ROOM_NAME="Your Room Name"
   export DATABASE_URL="sqlite:////path/to/your/app/instance/hallpass.db"
   ```

4. **Initialize database**:
   ```bash
   flask --app app.py init-db
   ```

5. **Setup systemd service** (`/etc/systemd/system/hallpass.service`):
   ```ini
   [Unit]
   Description=Hall Pass Tracker
   After=network.target

   [Service]
   User=www-data
   WorkingDirectory=/path/to/hallpass-tracker
   Environment=PATH=/path/to/hallpass-tracker/venv/bin
   ExecStart=/path/to/hallpass-tracker/venv/bin/gunicorn --bind 127.0.0.1:8000 app:app
   Restart=always

   [Install]
   WantedBy=multi-user.target
   ```

6. **Configure Nginx** as reverse proxy:
   ```nginx
   server {
       listen 80;
       server_name your-domain.com;
       
       location / {
           proxy_pass http://127.0.0.1:8000;
           proxy_set_header Host $host;
           proxy_set_header X-Real-IP $remote_addr;
       }
   }
   ```

## Student Roster Management

Upload a CSV file with two columns: `id,name`
- The `id` should match what your barcode scanner outputs
- Most barcode scanners automatically send an "Enter" key after scanning

Example CSV:
```csv
123456,John Smith
789012,Jane Doe
345678,Bob Johnson
```

## Usage Notes

- **Barcode Scanners**: Most USB barcode scanners work as keyboard input devices
- **Capacity**: Can be set higher than 1 to allow multiple students out simultaneously  
- **Suspension**: Admins can suspend the kiosk to prevent new checkouts
- **Real-time**: Status updates automatically across all connected displays
- **Mobile Friendly**: All interfaces work on tablets and mobile devices

## Support

This application is designed to run on any modern Python hosting platform. The SQLite database works great for small to medium schools, but PostgreSQL is recommended for larger deployments or high availability requirements.
