# Hall Pass Tracker (MVP)

Simple Flask app that lets students scan their badge to check a restroom pass in/out, shows a big red/green status screen, and logs sessions to CSV.

## Quick start

```bash
cd hallpass_mvp
python -m venv .venv
source .venv/bin/activate  # Windows: .venv\Scripts\activate
pip install -r requirements.txt

# Initialize the database and import sample students.csv
flask --app app.py init-db

# Run the app
flask --app app.py run --debug
```

Open:
- `http://localhost:5000/kiosk` on the device with the scanner
- `http://localhost:5000/display` on a projector/monitor for students
- `http://localhost:5000/admin` for roster import and CSV export

## Roster
Upload a simple CSV with two columns: `id,name`. The barcode scanner should emit the `id`, followed by Enter.

## Config
Edit `config.py` to change room name, capacity, auto-timeout, and timezone.

## Export
Visit `/export.csv` for today's log. Use the Admin page link.

## Notes
- Most scanners send an Enter key suffix. The kiosk page captures keystrokes and submits when Enter is received.
- Capacity is set to 1 by default but can be raised.
- Auto-failsafe ends a session after `MAX_MINUTES`.
