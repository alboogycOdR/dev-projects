from src.models.user import db
from datetime import datetime
import json

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
    
    def __repr__(self):
        return f'<JobPosting {self.title}>'
    
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
    
    def set_categories(self, categories_list):
        """Set categories from a list"""
        self.categories = json.dumps(categories_list) if categories_list else None
    
    def set_skills(self, skills_list):
        """Set skills from a list"""
        self.skills = json.dumps(skills_list) if skills_list else None
    
    def get_categories(self):
        """Get categories as a list"""
        return json.loads(self.categories) if self.categories else []
    
    def get_skills(self):
        """Get skills as a list"""
        return json.loads(self.skills) if self.skills else []

