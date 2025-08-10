import os
import json
import time
from typing import Optional

try:
    import gspread
    from google.oauth2.service_account import Credentials
except Exception:  # pragma: no cover - optional dependency
    gspread = None
    Credentials = None


# Column headers and order required by the sheet
HEADERS = [
    "session_id",
    "student_id",
    "name",
    "room",
    "start_utc",
    "end_utc",
    "duration_seconds",
    "ended_by",
    "created_at_utc",
    "updated_at_utc",
]

_status: str = "off"  # off | ok | degraded
_worksheet = None
_sheet_id = os.getenv("GOOGLE_SHEETS_LOG_ID")
_creds_json = os.getenv("GOOGLE_APPLICATION_CREDENTIALS_JSON")


def sheets_enabled() -> bool:
    return bool(_sheet_id and _creds_json and gspread and Credentials)


def get_status() -> str:
    if not sheets_enabled():
        return "off"
    return _status


def _build_client():
    global _status
    if not sheets_enabled():
        _status = "off"
        return None

    try:
        info = json.loads(_creds_json)
        scopes = ["https://www.googleapis.com/auth/spreadsheets"]
        creds = Credentials.from_service_account_info(info, scopes=scopes)
        client = gspread.authorize(creds)
        _status = "ok"
        return client
    except Exception:
        _status = "degraded"
        raise


def _get_worksheet(retries: int = 3):
    """Return the 'Sessions' worksheet, creating it and headers if needed."""
    global _worksheet, _status
    if _worksheet is not None:
        return _worksheet
    if not sheets_enabled():
        return None

    backoff = 0.5
    last_exc = None
    for _ in range(retries):
        try:
            client = _build_client()
            if client is None:
                return None
            ss = client.open_by_key(_sheet_id)
            try:
                ws = ss.worksheet("Sessions")
            except gspread.WorksheetNotFound:
                ws = ss.add_worksheet(title="Sessions", rows=1000, cols=len(HEADERS))
                ws.update("A1", [HEADERS])
            # Ensure headers exist and are correct
            first_row = ws.row_values(1)
            if first_row != HEADERS:
                # Reset to exact headers if sheet is empty or wrong
                ws.clear()
                ws.update("A1", [HEADERS])
            _worksheet = ws
            _status = "ok"
            return _worksheet
        except Exception as e:
            _status = "degraded"
            last_exc = e
            time.sleep(backoff)
            backoff *= 2
    if last_exc:
        raise last_exc
    return None


def _with_retry(fn, *args, **kwargs):
    backoff = 0.5
    last_exc = None
    for _ in range(3):
        try:
            return fn(*args, **kwargs)
        except Exception as e:
            global _status
            _status = "degraded"
            last_exc = e
            time.sleep(backoff)
            backoff *= 2
    if last_exc:
        raise last_exc


def append_start(session_id: int, student_id: str, name: str, room: str, start_iso: str, created_iso: str) -> Optional[int]:
    """Append a start row. Returns the row index if known, else None.
    Never raises to caller on failure; returns None when disabled or failing.
    """
    try:
        ws = _get_worksheet()
        if ws is None:
            return None
        row = [
            str(session_id),
            str(student_id),
            name,
            room,
            start_iso,
            "",
            "",
            "",
            created_iso,
            "",
        ]
        _with_retry(ws.append_row, row, value_input_option="RAW")
        # Attempt to infer last row index (append_row appends at the end)
        return ws.row_count  # best-effort, may be larger than actual used rows
    except Exception:
        # Already set degraded in helpers
        return None


def complete_end(student_id: str, end_iso: str, duration_seconds: int, ended_by: str, updated_iso: str) -> Optional[int]:
    """Find last row for student with blank end_utc and update end/duration/ended_by/updated.
    Returns row index if updated, else None. Never raises to caller.
    """
    try:
        ws = _get_worksheet()
        if ws is None:
            return None

        # Fetch columns for student_id and end_utc
        # Determine column indices from headers
        headers = ws.row_values(1)
        if headers != HEADERS:
            # Attempt to realign headers if possible
            ws.update("A1", [HEADERS])
            headers = HEADERS

        col_student = headers.index("student_id") + 1
        col_end = headers.index("end_utc") + 1
        col_duration = headers.index("duration_seconds") + 1
        col_ended_by = headers.index("ended_by") + 1
        col_updated = headers.index("updated_at_utc") + 1

        student_col = ws.col_values(col_student)
        end_col = ws.col_values(col_end)

        # Find last row index where student matches and end is blank
        last_row_idx = None
        # Skip header at index 0
        for idx in range(1, max(len(student_col), len(end_col))):
            sid = student_col[idx] if idx < len(student_col) else ""
            e = end_col[idx] if idx < len(end_col) else ""
            if sid == str(student_id) and (e is None or e == ""):
                last_row_idx = idx + 1  # convert to 1-based row index
        if last_row_idx is None:
            return None

        # Batch update the target row
        updates = [
            (last_row_idx, col_end, end_iso),
            (last_row_idx, col_duration, str(duration_seconds)),
            (last_row_idx, col_ended_by, ended_by),
            (last_row_idx, col_updated, updated_iso),
        ]
        _with_retry(ws.update, [
            [end_iso, str(duration_seconds), ended_by, updated_iso]
        ],
        range_name=f"{gspread.utils.rowcol_to_a1(last_row_idx, col_end)}:" \
                   f"{gspread.utils.rowcol_to_a1(last_row_idx, col_updated)}",
        value_input_option="RAW")
        return last_row_idx
    except Exception:
        return None


