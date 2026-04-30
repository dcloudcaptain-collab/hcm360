"""
Photo Service — profile picture upload + serve.

Storage layout:
    /app/uploads/employee_photos/<emp_id>.<ext>

DB column: core.employees.profile_photo_path stores the relative path
           (e.g. "employee_photos/123.jpg") so the orgchart + list views
           can construct the full URL via /uploads/<path>.
"""
import os
import time
from werkzeug.utils import secure_filename
from config import Config
from services.db import get_cursor

# ── Config ─────────────────────────────────────────────────────────
# Resolve the upload root from Config (which honors the UPLOAD_FOLDER env
# var, default `<project>/uploads`). Storing files under the same root
# Flask serves from at /uploads/* keeps reads + writes consistent.
UPLOAD_ROOT = Config.UPLOAD_FOLDER
PHOTO_SUBDIR = 'employee_photos'
PHOTO_ROOT = os.path.join(UPLOAD_ROOT, PHOTO_SUBDIR)
ALLOWED_EXT = {'jpg', 'jpeg', 'png', 'webp', 'gif'}
ALLOWED_MIME = {
    'image/jpeg', 'image/jpg', 'image/png',
    'image/webp', 'image/gif',
}
MAX_BYTES = 5 * 1024 * 1024  # 5 MB


# ── Helpers ────────────────────────────────────────────────────────
def _ensure_root():
    os.makedirs(PHOTO_ROOT, exist_ok=True)


def _ext_of(filename):
    if not filename or '.' not in filename:
        return ''
    return filename.rsplit('.', 1)[-1].lower()


def is_allowed(filename, mimetype=None):
    ext = _ext_of(filename)
    if ext not in ALLOWED_EXT:
        return False
    if mimetype and mimetype.lower() not in ALLOWED_MIME:
        return False
    return True


# ── Save ───────────────────────────────────────────────────────────
def save_photo(employee_id, file_storage):
    """Persist the uploaded file. Returns (relative_path, error).
    If error is set, relative_path is None."""
    if not file_storage or not file_storage.filename:
        return None, 'No file selected.'

    if not is_allowed(file_storage.filename, file_storage.mimetype):
        return None, 'Only JPG, PNG, WebP, or GIF images are allowed.'

    # Size guard (Flask gives us no Content-Length up front; check after save)
    _ensure_root()

    # Wipe any prior photo for this employee
    prev = current_path(employee_id)
    if prev:
        try:
            full_prev = os.path.join(UPLOAD_ROOT, prev)
            if os.path.isfile(full_prev):
                os.remove(full_prev)
        except OSError:
            pass

    ext = _ext_of(file_storage.filename) or 'jpg'
    # Cache-bust suffix so browsers refresh after re-upload
    fname = f'{int(employee_id)}_{int(time.time())}.{ext}'
    fname = secure_filename(fname)
    full_path = os.path.join(PHOTO_ROOT, fname)
    file_storage.save(full_path)

    if os.path.getsize(full_path) > MAX_BYTES:
        os.remove(full_path)
        return None, f'Photo too large (max {MAX_BYTES // (1024*1024)} MB).'

    rel = f'employee_photos/{fname}'
    with get_cursor(commit=True) as cur:
        cur.execute(
            'UPDATE core.employees SET profile_photo_path = %s WHERE id = %s',
            (rel, employee_id),
        )
    return rel, None


# ── Delete ─────────────────────────────────────────────────────────
def delete_photo(employee_id):
    rel = current_path(employee_id)
    with get_cursor(commit=True) as cur:
        cur.execute(
            'UPDATE core.employees SET profile_photo_path = NULL WHERE id = %s',
            (employee_id,),
        )
    if rel:
        full = os.path.join(UPLOAD_ROOT, rel)
        if os.path.isfile(full):
            try:
                os.remove(full)
            except OSError:
                pass
    return True


# ── Lookup ─────────────────────────────────────────────────────────
def current_path(employee_id):
    with get_cursor() as cur:
        cur.execute(
            'SELECT profile_photo_path FROM core.employees WHERE id = %s',
            (employee_id,),
        )
        row = cur.fetchone()
        return row['profile_photo_path'] if row else None
