"""
Check-in service — face descriptor matching + geofence validation.

Face descriptors are 128-d float vectors produced by face-api.js in the
browser. We never store the raw image; only the numeric descriptor (which
is non-reversible).  Matching uses Euclidean distance: distances below the
company's face_threshold are considered a match.
"""
import json
import math
from typing import Optional

from services.db import get_cursor


# ── Defaults ──────────────────────────────────────────────────────────
DEFAULT_SETTINGS = {
    'require_face': True,
    'require_geotag': True,
    'capture_photo': False,
    'face_threshold': 0.5,             # Euclidean distance threshold
    'geofence_lat': None,
    'geofence_lng': None,
    'geofence_radius_m': 200,
    'allowed_device_kinds': 'laptop,desktop,mobile',
    'preferred_camera': 'any',
    'activity_types': 'regular,flag_raising,flag_lowering',
}


# ══════════════════════════════════════════════════════════════════════
# Settings
# ══════════════════════════════════════════════════════════════════════
def get_settings(company_id: int) -> dict:
    with get_cursor() as cur:
        cur.execute("""
            SELECT * FROM attendance.att_checkin_settings
            WHERE company_id = %s
        """, (company_id,))
        row = cur.fetchone()
        if row:
            return dict(row)
    # Fallback: return defaults if no row exists yet
    return {'company_id': company_id, **DEFAULT_SETTINGS}


def save_settings(company_id: int, settings: dict, updated_by: int):
    with get_cursor(commit=True) as cur:
        cur.execute("""
            INSERT INTO attendance.att_checkin_settings
                (company_id, require_face, require_geotag, capture_photo,
                 face_threshold, geofence_lat, geofence_lng,
                 geofence_radius_m, allowed_device_kinds, preferred_camera,
                 activity_types, updated_by, updated_at)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, NOW())
            ON CONFLICT (company_id) DO UPDATE SET
                require_face         = EXCLUDED.require_face,
                require_geotag       = EXCLUDED.require_geotag,
                capture_photo        = EXCLUDED.capture_photo,
                face_threshold       = EXCLUDED.face_threshold,
                geofence_lat         = EXCLUDED.geofence_lat,
                geofence_lng         = EXCLUDED.geofence_lng,
                geofence_radius_m    = EXCLUDED.geofence_radius_m,
                allowed_device_kinds = EXCLUDED.allowed_device_kinds,
                preferred_camera     = EXCLUDED.preferred_camera,
                activity_types       = EXCLUDED.activity_types,
                updated_by           = EXCLUDED.updated_by,
                updated_at           = NOW()
        """, (
            company_id,
            bool(settings.get('require_face', True)),
            bool(settings.get('require_geotag', True)),
            bool(settings.get('capture_photo', False)),
            float(settings.get('face_threshold', 0.5)),
            settings.get('geofence_lat'),
            settings.get('geofence_lng'),
            settings.get('geofence_radius_m') or 200,
            settings.get('allowed_device_kinds', 'laptop,desktop,mobile'),
            settings.get('preferred_camera', 'any'),
            settings.get('activity_types', 'regular,flag_raising,flag_lowering'),
            updated_by,
        ))


# ══════════════════════════════════════════════════════════════════════
# Face Enrollment
# ══════════════════════════════════════════════════════════════════════
def save_face_enrollment(employee_id: int, descriptor: list,
                         enrolled_by: int, note: str = '') -> int:
    """
    Store (or replace) the face descriptor for an employee.
    descriptor: list of 128 floats.
    Returns the row id.
    """
    if not isinstance(descriptor, list) or len(descriptor) != 128:
        raise ValueError('descriptor must be a list of 128 floats')
    with get_cursor(commit=True) as cur:
        cur.execute("""
            INSERT INTO attendance.att_face_enrollments
                (employee_id, descriptor, enrolled_by, note, is_active)
            VALUES (%s, %s, %s, %s, TRUE)
            ON CONFLICT (employee_id) DO UPDATE SET
                descriptor   = EXCLUDED.descriptor,
                enrolled_by  = EXCLUDED.enrolled_by,
                note         = EXCLUDED.note,
                enrolled_at  = NOW(),
                is_active    = TRUE,
                sample_count = attendance.att_face_enrollments.sample_count + 1
            RETURNING id
        """, (employee_id, json.dumps(descriptor), enrolled_by, note))
        return cur.fetchone()['id']


def get_face_enrollment(employee_id: int) -> Optional[dict]:
    with get_cursor() as cur:
        cur.execute("""
            SELECT id, employee_id, descriptor, sample_count,
                   enrolled_at, enrolled_by, is_active, note
            FROM attendance.att_face_enrollments
            WHERE employee_id = %s AND is_active = TRUE
        """, (employee_id,))
        row = cur.fetchone()
        if not row:
            return None
        result = dict(row)
        # Make sure descriptor is a Python list (psycopg2 may return JSON)
        desc = result['descriptor']
        if isinstance(desc, str):
            desc = json.loads(desc)
        result['descriptor'] = desc
        return result


def is_face_enrolled(employee_id: int) -> bool:
    return get_face_enrollment(employee_id) is not None


# ══════════════════════════════════════════════════════════════════════
# Matching
# ══════════════════════════════════════════════════════════════════════
def euclidean_distance(a: list, b: list) -> float:
    return math.sqrt(sum((x - y) ** 2 for x, y in zip(a, b)))


def verify_face(employee_id: int, descriptor: list, threshold: float):
    """
    Compare incoming descriptor against stored enrollment.
    Returns (matched: bool, distance: float | None, match_score: float | None).
    match_score is a 0..1 value (1 = identical, 0 = far).
    """
    enrolled = get_face_enrollment(employee_id)
    if not enrolled:
        return False, None, None
    distance = euclidean_distance(enrolled['descriptor'], descriptor)
    # Convert distance to a 0..1 score (1 at d=0, 0 at d=1.0 and above)
    score = max(0.0, min(1.0, 1.0 - distance))
    return (distance <= threshold), distance, score


# ══════════════════════════════════════════════════════════════════════
# Geofence
# ══════════════════════════════════════════════════════════════════════
def haversine_m(lat1, lon1, lat2, lon2) -> float:
    """Great-circle distance between two (lat,lng) points, in meters."""
    R = 6371000.0
    phi1 = math.radians(float(lat1))
    phi2 = math.radians(float(lat2))
    dphi = math.radians(float(lat2) - float(lat1))
    dlam = math.radians(float(lon2) - float(lon1))
    a = (math.sin(dphi / 2) ** 2
         + math.cos(phi1) * math.cos(phi2) * math.sin(dlam / 2) ** 2)
    return 2 * R * math.asin(math.sqrt(a))


def verify_geofence(lat, lng, settings: dict):
    """
    Returns (within: bool, distance_m: float | None).
    If no geofence is configured, returns (True, None).
    """
    if settings.get('geofence_lat') is None or settings.get('geofence_lng') is None:
        return True, None
    if lat is None or lng is None:
        return False, None
    d = haversine_m(settings['geofence_lat'], settings['geofence_lng'], lat, lng)
    return d <= (settings.get('geofence_radius_m') or 200), d


# ══════════════════════════════════════════════════════════════════════
# Check-in submission
# ══════════════════════════════════════════════════════════════════════
def submit_checkin(employee_id: int, payload: dict, ip_address: str = None) -> dict:
    """
    payload expects:
      check_type (IN/OUT), descriptor (list of 128 floats or None),
      latitude, longitude, accuracy_m, device_kind, device_info (dict),
      activity, notes
    Returns {'ok': bool, 'id': <row id>, 'face_match_score', 'distance',
             'geo_distance_m', 'message'}.
    """
    # Look up company for settings
    with get_cursor() as cur:
        cur.execute("""
            SELECT e.company_id
            FROM core.employees e
            WHERE e.id = %s
        """, (employee_id,))
        emp = cur.fetchone()
        if not emp:
            return {'ok': False, 'message': 'Employee not found.'}
    settings = get_settings(emp['company_id'])

    messages = []
    face_ok = True
    geo_ok = True
    distance = None
    score = None
    geo_distance = None

    # Face check
    if settings.get('require_face') and payload.get('descriptor'):
        matched, distance, score = verify_face(
            employee_id, payload['descriptor'],
            float(settings.get('face_threshold', 0.5))
        )
        face_ok = matched
        if not face_ok:
            messages.append(
                f'Face not matched (distance {distance:.3f} > threshold '
                f"{settings.get('face_threshold'):.3f})"
            )
    elif settings.get('require_face') and not payload.get('descriptor'):
        face_ok = False
        messages.append('Face descriptor required but not provided.')

    # Geofence check
    if settings.get('require_geotag'):
        geo_ok, geo_distance = verify_geofence(
            payload.get('latitude'), payload.get('longitude'), settings
        )
        if not geo_ok and geo_distance is not None:
            messages.append(
                f"Outside geofence ({geo_distance:.0f} m from centre, "
                f"allowed {settings.get('geofence_radius_m')} m)"
            )
        elif not geo_ok:
            messages.append('Geolocation required but not provided.')

    # Insert the event regardless — auditing value; flag verified/not-verified
    with get_cursor(commit=True) as cur:
        cur.execute("""
            INSERT INTO attendance.att_checkins
                (employee_id, check_type, latitude, longitude, accuracy_m,
                 face_match_score, face_verified, geo_verified,
                 device_kind, device_info, ip_address, photo_path,
                 activity, notes)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
            RETURNING id, checked_at
        """, (
            employee_id,
            payload.get('check_type', 'IN'),
            payload.get('latitude'),
            payload.get('longitude'),
            payload.get('accuracy_m'),
            score,
            face_ok if settings.get('require_face') else None,
            geo_ok if settings.get('require_geotag') else None,
            payload.get('device_kind'),
            json.dumps(payload.get('device_info') or {}),
            ip_address,
            payload.get('photo_path'),
            payload.get('activity') or 'regular',
            payload.get('notes'),
        ))
        row = cur.fetchone()

    ok = face_ok and geo_ok
    return {
        'ok': ok,
        'id': row['id'],
        'checked_at': row['checked_at'].isoformat(),
        'face_match_score': score,
        'face_distance': distance,
        'geo_distance_m': geo_distance,
        'message': 'Checked in successfully.' if ok else '; '.join(messages),
    }


# ══════════════════════════════════════════════════════════════════════
# History
# ══════════════════════════════════════════════════════════════════════
def get_history(employee_id: int, limit: int = 50) -> list:
    with get_cursor() as cur:
        cur.execute("""
            SELECT id, check_type, checked_at, latitude, longitude, accuracy_m,
                   face_match_score, face_verified, geo_verified,
                   device_kind, activity, notes
            FROM attendance.att_checkins
            WHERE employee_id = %s
            ORDER BY checked_at DESC
            LIMIT %s
        """, (employee_id, limit))
        return cur.fetchall()


def get_enrollments_summary(company_id: int) -> dict:
    with get_cursor() as cur:
        cur.execute("""
            SELECT COUNT(*) AS total_employees
            FROM core.employees WHERE company_id = %s AND status = 'ACTIVE'
        """, (company_id,))
        total = cur.fetchone()['total_employees']
        cur.execute("""
            SELECT COUNT(*) AS enrolled
            FROM attendance.att_face_enrollments f
            JOIN core.employees e ON e.id = f.employee_id
            WHERE e.company_id = %s AND f.is_active = TRUE
        """, (company_id,))
        enrolled = cur.fetchone()['enrolled']
    return {
        'total_employees': total,
        'enrolled': enrolled,
        'pct': (enrolled / total * 100) if total else 0,
    }
