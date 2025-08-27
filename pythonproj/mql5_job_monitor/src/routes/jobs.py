from flask import Blueprint, request, jsonify
from src.models.job_posting import JobPosting, db
from src.scraper import MQL5Scraper
import json
from datetime import datetime, timedelta
from sqlalchemy import and_, or_

jobs_bp = Blueprint('jobs', __name__)

@jobs_bp.route('/scrape', methods=['POST'])
def scrape_jobs():
    """Trigger a new scrape of MQL5 job postings"""
    try:
        data = request.get_json() or {}
        username = data.get('username')
        password = data.get('password')
        max_pages = data.get('max_pages', 3)
        
        # Initialize scraper
        scraper = MQL5Scraper(username, password)
        
        # Attempt login if credentials provided
        if username and password:
            login_success = scraper.login()
            if not login_success:
                return jsonify({
                    'success': False,
                    'message': 'Login failed, proceeding without authentication'
                }), 200
        
        # Scrape job listings
        jobs_data = scraper.scrape_job_listings(max_pages=max_pages)
        
        # Store jobs in database
        new_jobs_count = 0
        updated_jobs_count = 0
        
        for job_data in jobs_data:
            # Check if job already exists (by title and price as a simple check)
            existing_job = JobPosting.query.filter_by(
                title=job_data['title'],
                price=job_data['price']
            ).first()
            
            if existing_job:
                # Update existing job
                existing_job.applications_count = job_data['applications_count']
                existing_job.is_new = False
                updated_jobs_count += 1
            else:
                # Create new job
                new_job = JobPosting(
                    title=job_data['title'],
                    price=job_data['price'],
                    description=job_data['description'],
                    time_posted=job_data['time_posted'],
                    url=job_data['url'],
                    applications_count=job_data['applications_count'],
                    is_new=True
                )
                new_job.set_categories(job_data['categories'])
                new_job.set_skills(job_data['skills'])
                
                db.session.add(new_job)
                new_jobs_count += 1
        
        db.session.commit()
        
        return jsonify({
            'success': True,
            'message': f'Scraping completed. {new_jobs_count} new jobs, {updated_jobs_count} updated jobs.',
            'new_jobs': new_jobs_count,
            'updated_jobs': updated_jobs_count,
            'total_scraped': len(jobs_data)
        })
        
    except Exception as e:
        return jsonify({
            'success': False,
            'message': f'Error during scraping: {str(e)}'
        }), 500

@jobs_bp.route('/jobs', methods=['GET'])
def get_jobs():
    """Get job postings with optional filtering"""
    try:
        # Get query parameters
        page = request.args.get('page', 1, type=int)
        per_page = request.args.get('per_page', 20, type=int)
        keywords = request.args.get('keywords', '')
        categories = request.args.get('categories', '')
        min_price = request.args.get('min_price', type=int)
        max_price = request.args.get('max_price', type=int)
        new_only = request.args.get('new_only', 'false').lower() == 'true'
        days_back = request.args.get('days_back', 7, type=int)
        
        # Build query
        query = JobPosting.query
        
        # Filter by keywords
        if keywords:
            keyword_filter = or_(
                JobPosting.title.contains(keywords),
                JobPosting.description.contains(keywords)
            )
            query = query.filter(keyword_filter)
        
        # Filter by categories
        if categories:
            category_list = [cat.strip() for cat in categories.split(',')]
            category_filters = []
            for category in category_list:
                category_filters.append(JobPosting.categories.contains(category))
            if category_filters:
                query = query.filter(or_(*category_filters))
        
        # Filter by price range
        if min_price is not None or max_price is not None:
            # This is tricky since price is stored as text
            # We'll need to extract numeric values
            if min_price is not None:
                query = query.filter(JobPosting.price.regexp(f'[0-9]+'))
            if max_price is not None:
                query = query.filter(JobPosting.price.regexp(f'[0-9]+'))
        
        # Filter by new jobs only
        if new_only:
            query = query.filter(JobPosting.is_new == True)
        
        # Filter by date range
        if days_back > 0:
            cutoff_date = datetime.utcnow() - timedelta(days=days_back)
            query = query.filter(JobPosting.date_added >= cutoff_date)
        
        # Order by date added (newest first)
        query = query.order_by(JobPosting.date_added.desc())
        
        # Paginate
        pagination = query.paginate(
            page=page, 
            per_page=per_page, 
            error_out=False
        )
        
        jobs = [job.to_dict() for job in pagination.items]
        
        return jsonify({
            'success': True,
            'jobs': jobs,
            'pagination': {
                'page': page,
                'per_page': per_page,
                'total': pagination.total,
                'pages': pagination.pages,
                'has_next': pagination.has_next,
                'has_prev': pagination.has_prev
            }
        })
        
    except Exception as e:
        return jsonify({
            'success': False,
            'message': f'Error retrieving jobs: {str(e)}'
        }), 500

@jobs_bp.route('/jobs/<int:job_id>', methods=['GET'])
def get_job(job_id):
    """Get a specific job by ID"""
    try:
        job = JobPosting.query.get_or_404(job_id)
        return jsonify({
            'success': True,
            'job': job.to_dict()
        })
    except Exception as e:
        return jsonify({
            'success': False,
            'message': f'Error retrieving job: {str(e)}'
        }), 500

@jobs_bp.route('/jobs/<int:job_id>/mark-read', methods=['POST'])
def mark_job_read(job_id):
    """Mark a job as read (not new)"""
    try:
        job = JobPosting.query.get_or_404(job_id)
        job.is_new = False
        db.session.commit()
        
        return jsonify({
            'success': True,
            'message': 'Job marked as read'
        })
    except Exception as e:
        return jsonify({
            'success': False,
            'message': f'Error marking job as read: {str(e)}'
        }), 500

@jobs_bp.route('/stats', methods=['GET'])
def get_stats():
    """Get statistics about job postings"""
    try:
        total_jobs = JobPosting.query.count()
        new_jobs = JobPosting.query.filter_by(is_new=True).count()
        
        # Jobs by category
        categories_stats = {}
        jobs_with_categories = JobPosting.query.filter(JobPosting.categories.isnot(None)).all()
        for job in jobs_with_categories:
            for category in job.get_categories():
                categories_stats[category] = categories_stats.get(category, 0) + 1
        
        # Recent activity (last 7 days)
        week_ago = datetime.utcnow() - timedelta(days=7)
        recent_jobs = JobPosting.query.filter(JobPosting.date_added >= week_ago).count()
        
        return jsonify({
            'success': True,
            'stats': {
                'total_jobs': total_jobs,
                'new_jobs': new_jobs,
                'recent_jobs': recent_jobs,
                'categories': categories_stats
            }
        })
    except Exception as e:
        return jsonify({
            'success': False,
            'message': f'Error retrieving stats: {str(e)}'
        }), 500

@jobs_bp.route('/categories', methods=['GET'])
def get_categories():
    """Get all available job categories"""
    try:
        categories = set()
        jobs_with_categories = JobPosting.query.filter(JobPosting.categories.isnot(None)).all()
        
        for job in jobs_with_categories:
            categories.update(job.get_categories())
        
        return jsonify({
            'success': True,
            'categories': sorted(list(categories))
        })
    except Exception as e:
        return jsonify({
            'success': False,
            'message': f'Error retrieving categories: {str(e)}'
        }), 500

@jobs_bp.route('/skills', methods=['GET'])
def get_skills():
    """Get all available job skills"""
    try:
        skills = set()
        jobs_with_skills = JobPosting.query.filter(JobPosting.skills.isnot(None)).all()
        
        for job in jobs_with_skills:
            skills.update(job.get_skills())
        
        return jsonify({
            'success': True,
            'skills': sorted(list(skills))
        })
    except Exception as e:
        return jsonify({
            'success': False,
            'message': f'Error retrieving skills: {str(e)}'
        }), 500

