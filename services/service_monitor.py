import os
import subprocess
import urllib.request
import urllib.error

from config import Config

# Project root: the HCM application directory (where docker-compose.yml lives).
PROJECT_ROOT = Config.PROJECT_ROOT

# Registry of monitored services.
# compose_root: path to the directory containing that service's docker-compose.yml,
#               relative to PROJECT_ROOT (or absolute).  Defaults to PROJECT_ROOT.
# Leave management is now built into the HRIS app (leave_mgmt schema).
# Add external services here if/when they are deployed separately.
SERVICES = []

_SERVICE_MAP = {s['name']: s for s in SERVICES}


def check_service(name: str) -> dict:
    """Return {'name', 'label', 'status': 'up'|'down', 'error': str|None}."""
    svc = _SERVICE_MAP.get(name)
    if not svc:
        return {'name': name, 'label': name, 'status': 'unknown', 'error': 'Not in registry'}
    try:
        req = urllib.request.urlopen(svc['health_url'], timeout=3)
        status = 'up' if req.status == 200 else 'down'
        error = None
    except Exception as exc:
        status = 'down'
        error = str(exc)
    return {'name': svc['name'], 'label': svc['label'], 'status': status, 'error': error}


def check_all_services() -> list:
    return [check_service(s['name']) for s in SERVICES]


def start_service(name: str) -> dict:
    """Start a service using docker-compose up -d from its compose_root."""
    svc = _SERVICE_MAP.get(name)
    if not svc:
        return {'success': False, 'message': f'Unknown service: {name}'}

    compose_dir = svc.get('compose_root', PROJECT_ROOT)
    compose_file = os.path.join(compose_dir, 'docker-compose.yml')

    if not os.path.isfile(compose_file):
        # Fall back to plain docker start if no compose file is found
        return _docker_start(svc)

    try:
        result = subprocess.run(
            ['docker-compose', 'up', '-d', '--no-recreate'],
            cwd=compose_dir,
            capture_output=True, text=True, timeout=60
        )
        if result.returncode == 0:
            return {'success': True, 'message': f"{svc['label']} started successfully."}
        return {'success': False, 'message': result.stderr.strip() or 'docker-compose up failed'}
    except FileNotFoundError:
        # docker-compose not found; try plain docker start
        return _docker_start(svc)
    except Exception as exc:
        return {'success': False, 'message': str(exc)}


def _docker_start(svc: dict) -> dict:
    """Fallback: start an already-created container by name."""
    try:
        result = subprocess.run(
            ['docker', 'start', svc['container']],
            capture_output=True, text=True, timeout=15
        )
        if result.returncode == 0:
            return {'success': True, 'message': f"{svc['label']} started successfully."}
        return {'success': False, 'message': result.stderr.strip() or 'docker start failed'}
    except FileNotFoundError:
        return {'success': False, 'message': 'Docker CLI not found on this host.'}
    except Exception as exc:
        return {'success': False, 'message': str(exc)}
