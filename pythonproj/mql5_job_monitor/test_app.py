#!/usr/bin/env python3

import os
import sys

# Add the project root to the Python path
project_root = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, project_root)

from flask import Flask, send_from_directory, jsonify
from flask_cors import CORS
from flask_sqlalchemy import SQLAlchemy
import json
from datetime import datetime

# Initialize Flask app
app = Flask(__name__, static_folder=os.path.join(project_root, 'src', 'static'))
app.config['SECRET_KEY'] = 'asdf#FGSgvasgf$5$WGT'
CORS(app)

# Database configuration
app.config['SQLALCHEMY_DATABASE_URI'] = f"sqlite:///{os.path.join(project_root, 'src', 'database', 'app.db')}"
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False

# Initialize database
db = SQLAlchemy(app)

# Job Posting Model
class JobPosting(db.Model):
    __tablename__ = 'job_postings'
    
    id = db.Column(db.Integer, primary_key=True)
    title = db.Column(db.Text, nullable=False)
    price = db.Column(db.String(100), nullable=True)
    categories = db.Column(db.Text, nullable=True)  # JSON string
    skills = db.Column(db.Text, nullable=True)  # JSON string
    description = db.Column(db.Text, nullable=True)
    time_posted = db.Column(db.String(100), nullable=True)
    url = db.Column(db.Text, nullable=True)
    date_added = db.Column(db.DateTime, default=datetime.utcnow)
    is_new = db.Column(db.Boolean, default=True)
    applications_count = db.Column(db.Integer, default=0)
    
    def to_dict(self):
        return {
            'id': self.id,
            'title': self.title,
            'price': self.price,
            'categories': json.loads(self.categories) if self.categories else [],
            'skills': json.loads(self.skills) if self.skills else [],
            'description': self.description,
            'time_posted': self.time_posted,
            'url': self.url,
            'date_added': self.date_added.isoformat() if self.date_added else None,
            'is_new': self.is_new,
            'applications_count': self.applications_count
        }

# Create database tables
with app.app_context():
    db.create_all()

# Routes
@app.route('/', defaults={'path': ''})
@app.route('/<path:path>')
def serve(path):
    static_folder_path = app.static_folder
    if static_folder_path is None:
        return "Static folder not configured", 404

    if path != "" and os.path.exists(os.path.join(static_folder_path, path)):
        return send_from_directory(static_folder_path, path)
    else:
        index_path = os.path.join(static_folder_path, 'index.html')
        if os.path.exists(index_path):
            return send_from_directory(static_folder_path, 'index.html')
        else:
            return "index.html not found", 404

@app.route('/api/stats', methods=['GET'])
def get_stats():
    """Get statistics about job postings"""
    try:
        total_jobs = JobPosting.query.count()
        new_jobs = JobPosting.query.filter_by(is_new=True).count()
        
        # Recent activity (last 7 days)
        from datetime import timedelta
        week_ago = datetime.utcnow() - timedelta(days=7)
        recent_jobs = JobPosting.query.filter(JobPosting.date_added >= week_ago).count()
        
        return jsonify({
            'success': True,
            'stats': {
                'total_jobs': total_jobs,
                'new_jobs': new_jobs,
                'recent_jobs': recent_jobs,
                'categories': {}
            }
        })
    except Exception as e:
        return jsonify({
            'success': False,
            'message': f'Error retrieving stats: {str(e)}'
        }), 500

@app.route('/api/jobs', methods=['GET'])
def get_jobs():
    """Get job postings"""
    try:
        jobs = JobPosting.query.order_by(JobPosting.date_added.desc()).limit(20).all()
        return jsonify({
            'success': True,
            'jobs': [job.to_dict() for job in jobs],
            'pagination': {
                'page': 1,
                'per_page': 20,
                'total': len(jobs),
                'pages': 1,
                'has_next': False,
                'has_prev': False
            }
        })
    except Exception as e:
        return jsonify({
            'success': False,
            'message': f'Error retrieving jobs: {str(e)}'
        }), 500

@app.route('/api/scrape', methods=['POST'])
def scrape_jobs():
    """Trigger a new scrape of MQL5 job postings"""
    try:
        # Import the scraper
        from src.scraper import MQL5Scraper
        
        # Get request data
        data = request.get_json() or {}
        username = data.get('username')
        password = data.get('password')
        max_pages = data.get('max_pages', 1)
        
        # Initialize scraper
        scraper = MQL5Scraper(username, password)
        
        # Scrape job listings
        jobs_data = scraper.scrape_job_listings(max_pages=max_pages)
        
        # Store jobs in database
        new_jobs_count = 0
        
        for job_data in jobs_data:
            # Check if job already exists
            existing_job = JobPosting.query.filter_by(
                title=job_data['title']
            ).first()
            
            if not existing_job:
                # Create new job
                new_job = JobPosting(
                    title=job_data['title'],
                    price=job_data['price'],
                    description=job_data['description'],
                    time_posted=job_data['time_posted'],
                    url=job_data['url'],
                    applications_count=job_data['applications_count'],
                    categories=json.dumps(job_data['categories']),
                    skills=json.dumps(job_data['skills']),
                    is_new=True
                )
                
                db.session.add(new_job)
                new_jobs_count += 1
        
        db.session.commit()
        
        return jsonify({
            'success': True,
            'message': f'Scraping completed. {new_jobs_count} new jobs found.',
            'new_jobs': new_jobs_count,
            'total_scraped': len(jobs_data)
        })
        
    except Exception as e:
        return jsonify({
            'success': False,
            'message': f'Error during scraping: {str(e)}'
        }), 500

@app.route('/api/categories', methods=['GET'])
def get_categories():
    """Get all available job categories"""
    return jsonify({
        'success': True,
        'categories': ['Indicators', 'Experts', 'Libraries', 'Scripts', 'Integration', 'Converting', 'Translation', 'Design', 'Consultation', 'Other']
    })

if __name__ == '__main__':
    print("Starting MQL5 Job Monitor...")
    print("Access the application at: http://localhost:8080")
    app.run(host='0.0.0.0', port=8080, debug=True)

