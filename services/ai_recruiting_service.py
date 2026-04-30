"""AI Recruiting Service — resume parsing and applicant ranking (placeholder)."""
import json
import re
from services.db import get_cursor


def parse_resume_text(applicant_id, raw_text):
    """Extract skills/education/experience as JSON from raw resume text.

    Compute match_score against requisition requirements.
    Insert into recruitment.parsed_profiles.
    """
    # Placeholder extraction logic
    skills = []
    education = []
    experience_years = 0

    # Simple keyword extraction
    text_lower = raw_text.lower()

    # Extract skills (look for common patterns)
    skill_keywords = [
        'python', 'java', 'javascript', 'sql', 'react', 'node', 'aws', 'docker',
        'kubernetes', 'excel', 'tableau', 'power bi', 'management', 'leadership',
        'communication', 'project management', 'agile', 'scrum', 'git', 'ci/cd',
        'machine learning', 'data analysis', 'salesforce', 'sap', 'hr', 'payroll',
    ]
    for sk in skill_keywords:
        if sk in text_lower:
            skills.append(sk.title())

    # Extract education keywords
    edu_keywords = ['bachelor', 'master', 'phd', 'mba', 'associate', 'diploma', 'certificate']
    for ek in edu_keywords:
        if ek in text_lower:
            education.append(ek.title())

    # Estimate experience years
    year_match = re.findall(r'(\d+)\s*(?:\+\s*)?years?\s*(?:of\s+)?experience', text_lower)
    if year_match:
        experience_years = max(int(y) for y in year_match)

    parsed_data = {
        'skills': skills,
        'education': education,
        'experience_years': experience_years,
    }

    # Compute match score against requisition requirements
    match_score = 0.0
    with get_cursor(commit=True) as cur:
        # Get requisition requirements for this applicant
        cur.execute("""
            SELECT r.requirements
            FROM recruitment.applicants a
            JOIN recruitment.requisitions r ON r.id = a.requisition_id
            WHERE a.id = %s
        """, (applicant_id,))
        req = cur.fetchone()

        if req and req.get('requirements'):
            req_text = req['requirements'].lower() if isinstance(req['requirements'], str) else ''
            # Score based on matching skills
            if skills:
                matching = sum(1 for s in skills if s.lower() in req_text)
                match_score = min(matching / max(len(skills), 1), 1.0)
            # Bonus for experience
            if experience_years >= 5:
                match_score = min(match_score + 0.15, 1.0)
            elif experience_years >= 3:
                match_score = min(match_score + 0.10, 1.0)
            # Bonus for education
            if education:
                match_score = min(match_score + 0.10, 1.0)

        match_score = round(match_score, 3)

        cur.execute("""
            INSERT INTO recruitment.parsed_profiles
                (applicant_id, parsed_data, skills_extracted, education_extracted,
                 experience_years, match_score)
            VALUES (%s, %s, %s, %s, %s, %s)
            ON CONFLICT (applicant_id)
            DO UPDATE SET parsed_data = EXCLUDED.parsed_data,
                          skills_extracted = EXCLUDED.skills_extracted,
                          education_extracted = EXCLUDED.education_extracted,
                          experience_years = EXCLUDED.experience_years,
                          match_score = EXCLUDED.match_score,
                          parsed_at = NOW()
            RETURNING id
        """, (applicant_id, json.dumps(parsed_data), json.dumps(skills),
              json.dumps(education), experience_years, match_score))
        profile_id = cur.fetchone()['id']

    return {
        'profile_id': profile_id,
        'parsed_data': parsed_data,
        'match_score': match_score,
    }


def get_parsed_profiles(applicant_id=None):
    """List parsed profiles with scores."""
    conditions = []
    params = []
    if applicant_id:
        conditions.append('pp.applicant_id = %s')
        params.append(applicant_id)
    where = 'WHERE ' + ' AND '.join(conditions) if conditions else ''
    with get_cursor() as cur:
        cur.execute(f"""
            SELECT pp.*,
                   a.first_name || ' ' || a.last_name AS applicant_name,
                   a.email AS applicant_email,
                   r.title AS requisition_title
            FROM recruitment.parsed_profiles pp
            JOIN recruitment.applicants a ON a.id = pp.applicant_id
            LEFT JOIN recruitment.requisitions r ON r.id = a.requisition_id
            {where}
            ORDER BY pp.match_score DESC
        """, params)
        return cur.fetchall()


def rank_applicants(requisition_id):
    """Rank applicants for a requisition by match_score."""
    with get_cursor() as cur:
        cur.execute("""
            SELECT pp.*,
                   a.first_name || ' ' || a.last_name AS applicant_name,
                   a.email AS applicant_email,
                   a.status AS applicant_status
            FROM recruitment.parsed_profiles pp
            JOIN recruitment.applicants a ON a.id = pp.applicant_id
            WHERE a.requisition_id = %s
            ORDER BY pp.match_score DESC
        """, (requisition_id,))
        return cur.fetchall()
