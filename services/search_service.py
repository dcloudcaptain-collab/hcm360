from services.db import get_cursor


def search_all(term):
    q = f"%{term}%"
    with get_cursor() as cur:
        cur.execute("""
            SELECT entity_type, entity_id, title, subtitle, url AS target_url
            FROM search_index
            WHERE title ILIKE %s OR subtitle ILIKE %s OR keywords ILIKE %s
            ORDER BY title
            LIMIT 20
        """, (q, q, q))
        return cur.fetchall()
