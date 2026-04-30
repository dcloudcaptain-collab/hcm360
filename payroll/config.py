import os

_here = os.path.dirname(os.path.abspath(__file__))


class Config:
    SECRET_KEY   = os.getenv('PAYROLL_SECRET_KEY', 'payroll-standalone-secret')
    DATABASE_URL = os.getenv('DATABASE_URL', 'postgresql://hris_admin:hris_secure_pw@localhost:5440/hris_db')
    PORT         = int(os.getenv('PAYROLL_PORT', '5001'))
    PROJECT_ROOT = os.getenv('PROJECT_ROOT', _here)
    UPLOAD_FOLDER = os.getenv('UPLOAD_FOLDER', os.path.join(_here, 'uploads'))
