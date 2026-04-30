import os
from dotenv import load_dotenv

load_dotenv(os.path.join(os.path.dirname(os.path.abspath(__file__)), '.env'))

_here = os.path.dirname(os.path.abspath(__file__))


class Config:
    SECRET_KEY        = os.getenv('SECRET_KEY', 'changeme-hris-prod')
    DATABASE_URL      = os.getenv('DATABASE_URL', 'postgresql://hris_admin:hris_secure_pw@localhost:5440/hris_db')
    ANTHROPIC_API_KEY = os.getenv('ANTHROPIC_API_KEY', '')
    PROJECT_ROOT      = os.getenv('PROJECT_ROOT', _here)
    UPLOAD_FOLDER     = os.getenv('UPLOAD_FOLDER', os.path.join(_here, 'uploads'))

    # ── Feature Toggles ───────────────────────────────────────────
    # Phase 1 — ON by default
    ENABLE_ATTENDANCE  = os.getenv('ENABLE_ATTENDANCE',  'true').lower()  == 'true'
    ENABLE_LEAVE       = os.getenv('ENABLE_LEAVE',       'true').lower()  == 'true'
    ENABLE_PAYROLL     = os.getenv('ENABLE_PAYROLL',     'true').lower()  == 'true'
    ENABLE_ANALYTICS   = os.getenv('ENABLE_ANALYTICS',   'true').lower()  == 'true'
    ENABLE_AI          = os.getenv('ENABLE_AI',          'true').lower()  == 'true'

    # Phase 2 — ON by default (government modules)
    ENABLE_RSP         = os.getenv('ENABLE_RSP',         'true').lower()  == 'true'
    ENABLE_PM          = os.getenv('ENABLE_PM',          'true').lower()  == 'true'
    ENABLE_LD          = os.getenv('ENABLE_LD',          'true').lower()  == 'true'
    ENABLE_RR          = os.getenv('ENABLE_RR',          'true').lower()  == 'true'

    # Phase 3 — ON by default
    ENABLE_DMS         = os.getenv('ENABLE_DMS',         'true').lower()  == 'true'
    ENABLE_DISCIPLINE  = os.getenv('ENABLE_DISCIPLINE',  'true').lower()  == 'true'
    ENABLE_HEALTH      = os.getenv('ENABLE_HEALTH',      'true').lower()  == 'true'

    # Phase 4
    ENABLE_ORGCHART    = os.getenv('ENABLE_ORGCHART',    'true').lower()  == 'true'
