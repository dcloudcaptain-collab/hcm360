from flask import Blueprint, render_template, request
from services.search_service import search_all

bp = Blueprint('search', __name__)


@bp.route('/search')
def search():
    term = request.args.get('q', '').strip()
    results = search_all(term) if term else []
    return render_template('search/results.html', term=term, results=results)
