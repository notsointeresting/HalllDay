# IDK Can You? - Hall Pass Tracker

A modern, FERPA-compliant digital hall pass system designed for classrooms. Built with Flask and Material 3 Expressive Design, it prioritizes student data privacy and engaging user interactions.

## Key Features

- **Smart Scanning**: Fast check-in/out via barcode scanner or numpad.
- **Privacy First (FERPA)**: Student IDs are hashed for lookup and encrypted at rest. No PII is exposed in plain text.
- **Material 3 Design**: Beautiful, responsive interface with expressive animations and color-coded states (Available, In Use, Overdue).
- **Real-time Sync**: Instant status updates across Kiosk and Display screens via Server-Sent Events (SSE).
- **Google Sheets Integration**: Automatic logging of sessions to Google Sheets for external auditing.
- **Auto-Ban**: Configurable automatic banning of students who exceed time limits.

## Quick Start (Local)

1.  **Clone and Setup**:
    ```bash
    git clone <your-repo-url>
    cd HalllDay
    python -m venv .venv
    source .venv/bin/activate  # Windows: .venv\Scripts\activate
    pip install -r requirements.txt
    ```

2.  **Initialize Database**:
    ```bash
    flask --app app.py init-db
    ```

3.  **Run Development Server**:
    ```bash
    flask --app app.py run --debug
    ```

4.  **Access the App**:
    -   **Kiosk**: `http://localhost:5000/kiosk` (Student facing)
    -   **Display**: `http://localhost:5000/display` (Classroom facing)
    -   **Admin**: `http://localhost:5000/admin` (Teacher control)

## Configuration

Configure the application using environment variables.

| Variable | Description | Default |
| :--- | :--- | :--- |
| `HALLPASS_SECRET_KEY` | **CRITICAL**: Used for encryption. Change in production. | `change-me-in-production` |
| `HALLPASS_ADMIN_PASSCODE` | Passcode for the admin panel. | `admin123` |
| `HALLPASS_ROOM_NAME` | Name displayed on the screen. | `Hall Pass` |
| `HALLPASS_CAPACITY` | Max students allowed out at once. | `1` |
| `HALLPASS_MAX_MINUTES` | Threshold for "Overdue" status (minutes). | `12` |
| `DATABASE_URL` | Database connection string. | `sqlite:///instance/hallpass.db` |
| `GOOGLE_SHEETS_LOG_ID` | (Optional) Sheet ID for logging sessions. | `None` |
| `GOOGLE_APPLICATION_CREDENTIALS_JSON` | (Optional) JSON content of Google Service Account. | `None` |

## Deployment

### Render.com (Recommended)
1.  Fork this repo.
2.  Create a **Web Service** on Render (Python 3).
3.  **Build Command**: `pip install -r requirements.txt`
4.  **Start Command**: `gunicorn app:app`
5.  Set your Environment Variables in the dashboard.
6.  Add a **PostgreSQL** database (optional but recommended for persistence).

## Admin Manual

### Roster Management
Upload a CSV file (`id, name`) in the Admin Panel. 
-   **Security**: Names are **encrypted** before being stored in the database.
-   **Lookup**: Student IDs are **hashed** to allow private lookups without storing plain IDs.

### Kiosk Control
-   **Suspend**: Temporarily disable the kiosk (e.g., during tests).
-   **Override**: Manually end a session if a student forgets to scan back in.
-   **Bans**: Manually ban specific students from using the pass (viewable in Admin panel).

### Google Sheets Logging
To enable remote logging:
1.  Create a Google Service Account and download the JSON key.
2.  Share your Google Sheet with the Service Account email.
3.  Set `GOOGLE_SHEETS_LOG_ID` to your Sheet ID.
4.  Set `GOOGLE_APPLICATION_CREDENTIALS_JSON` to the *content* of your JSON key file.
