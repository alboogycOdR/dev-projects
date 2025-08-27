import requests
from bs4 import BeautifulSoup
import re
import time
import json
from urllib.parse import urljoin, urlparse
from datetime import datetime
import logging

# Set up logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class MQL5Scraper:
    def __init__(self, username=None, password=None):
        self.session = requests.Session()
        self.session.headers.update({
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
        })
        self.username = username
        self.password = password
        self.base_url = 'https://www.mql5.com'
        self.job_url = 'https://www.mql5.com/en/job'
        self.is_authenticated = False
    
    def login(self):
        """Attempt to log in to MQL5.com"""
        if not self.username or not self.password:
            logger.warning("No credentials provided. Will attempt to scrape without authentication.")
            return False
        
        try:
            # Get the login page first
            login_page_url = 'https://www.mql5.com/en/auth_login'
            response = self.session.get(login_page_url)
            response.raise_for_status()
            
            soup = BeautifulSoup(response.content, 'html.parser')
            
            # Find the login form
            login_form = soup.find('form')
            if not login_form:
                logger.error("Could not find login form")
                return False
            
            # Extract form action and method
            form_action = login_form.get('action', '/en/auth_login')
            form_method = login_form.get('method', 'post').lower()
            
            # Find input fields
            username_field = None
            password_field = None
            hidden_fields = {}
            
            for input_tag in login_form.find_all('input'):
                input_type = input_tag.get('type', '').lower()
                input_name = input_tag.get('name', '')
                input_value = input_tag.get('value', '')
                
                if input_type in ['text', 'email'] or 'login' in input_name.lower() or 'user' in input_name.lower():
                    username_field = input_name
                elif input_type == 'password':
                    password_field = input_name
                elif input_type == 'hidden':
                    hidden_fields[input_name] = input_value
            
            if not username_field or not password_field:
                logger.error("Could not identify username and password fields")
                return False
            
            # Prepare login data
            login_data = hidden_fields.copy()
            login_data[username_field] = self.username
            login_data[password_field] = self.password
            
            # Submit login form
            login_url = urljoin(self.base_url, form_action)
            response = self.session.post(login_url, data=login_data)
            response.raise_for_status()
            
            # Check if login was successful
            # Look for indicators of successful login (e.g., user profile link, logout link)
            if 'logout' in response.text.lower() or self.username.lower() in response.text.lower():
                self.is_authenticated = True
                logger.info("Successfully logged in to MQL5.com")
                return True
            else:
                logger.error("Login failed - no success indicators found")
                return False
                
        except Exception as e:
            logger.error(f"Login failed with error: {str(e)}")
            return False
    
    def scrape_job_listings(self, max_pages=5):
        """Scrape job listings from MQL5 freelance portal"""
        all_jobs = []
        
        try:
            for page in range(1, max_pages + 1):
                logger.info(f"Scraping page {page}")
                
                # Construct URL for the page
                if page == 1:
                    url = self.job_url
                else:
                    url = f"{self.job_url}?page={page}"
                
                response = self.session.get(url)
                response.raise_for_status()
                
                soup = BeautifulSoup(response.content, 'html.parser')
                
                # Parse job listings from the page
                jobs = self._parse_job_listings(soup)
                
                if not jobs:
                    logger.info(f"No jobs found on page {page}, stopping")
                    break
                
                all_jobs.extend(jobs)
                logger.info(f"Found {len(jobs)} jobs on page {page}")
                
                # Add delay between requests to be respectful
                time.sleep(1)
            
            logger.info(f"Total jobs scraped: {len(all_jobs)}")
            return all_jobs
            
        except Exception as e:
            logger.error(f"Error scraping job listings: {str(e)}")
            return all_jobs
    
    def _parse_job_listings(self, soup):
        """Parse individual job listings from the page HTML"""
        jobs = []
        
        try:
            # Look for job listing containers
            # Based on the HTML structure we observed, jobs are in specific containers
            job_containers = soup.find_all('div', class_='job-item') or \
                           soup.find_all('tr', class_='job-row') or \
                           soup.find_all('article') or \
                           soup.find_all('div', class_='item')
            
            # If no specific containers found, try to find patterns in the HTML
            if not job_containers:
                # Look for links that might be job titles
                job_links = soup.find_all('a', href=re.compile(r'/en/job/\d+'))
                for link in job_links:
                    # Try to extract job info from the surrounding context
                    job_data = self._extract_job_from_link(link)
                    if job_data:
                        jobs.append(job_data)
            else:
                # Parse each job container
                for container in job_containers:
                    job_data = self._extract_job_from_container(container)
                    if job_data:
                        jobs.append(job_data)
            
            # Fallback: try to parse from the extracted markdown content we saw earlier
            if not jobs:
                jobs = self._parse_from_text_content(soup)
            
        except Exception as e:
            logger.error(f"Error parsing job listings: {str(e)}")
        
        return jobs
    
    def _extract_job_from_container(self, container):
        """Extract job data from a job container element"""
        try:
            job_data = {
                'title': '',
                'price': '',
                'categories': [],
                'skills': [],
                'description': '',
                'time_posted': '',
                'url': '',
                'applications_count': 0
            }
            
            # Extract title and URL
            title_link = container.find('a', href=re.compile(r'/en/job/'))
            if title_link:
                job_data['title'] = title_link.get_text(strip=True)
                job_data['url'] = urljoin(self.base_url, title_link.get('href', ''))
            
            # Extract price
            price_patterns = [
                re.compile(r'\$?\d+[\+\-\s]*USD', re.IGNORECASE),
                re.compile(r'\d+\s*[\+\-]\s*\d+\s*USD', re.IGNORECASE),
                re.compile(r'\d+\+?\s*USD', re.IGNORECASE)
            ]
            
            container_text = container.get_text()
            for pattern in price_patterns:
                price_match = pattern.search(container_text)
                if price_match:
                    job_data['price'] = price_match.group().strip()
                    break
            
            # Extract applications count
            app_pattern = re.compile(r'(\d+)\s*Applications?', re.IGNORECASE)
            app_match = app_pattern.search(container_text)
            if app_match:
                job_data['applications_count'] = int(app_match.group(1))
            
            # Extract time posted
            time_patterns = [
                re.compile(r'(\d+)\s*(minutes?|hours?|days?)\s*ago', re.IGNORECASE),
                re.compile(r'yesterday', re.IGNORECASE)
            ]
            
            for pattern in time_patterns:
                time_match = pattern.search(container_text)
                if time_match:
                    job_data['time_posted'] = time_match.group().strip()
                    break
            
            # Extract categories and skills (look for common MQL5 terms)
            categories = []
            skills = []
            
            category_keywords = ['Indicators', 'Experts', 'Libraries', 'Scripts', 'Integration', 
                               'Converting', 'Translation', 'Design', 'Consultation', 'Other']
            skill_keywords = ['MQL4', 'MQL5', 'Forex', 'Trading robot', 'Strategy optimization', 
                            'Statistics', 'C++', 'Python', 'JavaScript', 'MySQL']
            
            for keyword in category_keywords:
                if keyword.lower() in container_text.lower():
                    categories.append(keyword)
            
            for keyword in skill_keywords:
                if keyword.lower() in container_text.lower():
                    skills.append(keyword)
            
            job_data['categories'] = categories
            job_data['skills'] = skills
            
            # Extract description (try to get a meaningful snippet)
            description_elem = container.find('p') or container.find('div', class_='description')
            if description_elem:
                job_data['description'] = description_elem.get_text(strip=True)[:500]
            else:
                # Fallback: use container text but limit length
                job_data['description'] = container_text[:500].strip()
            
            # Only return if we have at least a title
            if job_data['title']:
                return job_data
            
        except Exception as e:
            logger.error(f"Error extracting job from container: {str(e)}")
        
        return None
    
    def _extract_job_from_link(self, link):
        """Extract job data from a job title link"""
        try:
            job_data = {
                'title': link.get_text(strip=True),
                'url': urljoin(self.base_url, link.get('href', '')),
                'price': '',
                'categories': [],
                'skills': [],
                'description': '',
                'time_posted': '',
                'applications_count': 0
            }
            
            # Try to find additional info in the parent elements
            parent = link.parent
            for _ in range(3):  # Check up to 3 levels up
                if parent:
                    parent_text = parent.get_text()
                    
                    # Look for price
                    price_match = re.search(r'\$?\d+[\+\-\s]*USD', parent_text, re.IGNORECASE)
                    if price_match and not job_data['price']:
                        job_data['price'] = price_match.group().strip()
                    
                    # Look for applications count
                    app_match = re.search(r'(\d+)\s*Applications?', parent_text, re.IGNORECASE)
                    if app_match:
                        job_data['applications_count'] = int(app_match.group(1))
                    
                    parent = parent.parent
                else:
                    break
            
            return job_data if job_data['title'] else None
            
        except Exception as e:
            logger.error(f"Error extracting job from link: {str(e)}")
            return None
    
    def _parse_from_text_content(self, soup):
        """Fallback method to parse jobs from text content"""
        jobs = []
        
        try:
            # Get all text content
            text_content = soup.get_text()
            
            # Look for job patterns in the text
            # This is a basic pattern matching approach
            job_patterns = re.findall(
                r'(\d+\+?\s*USD.*?)(?=\d+\+?\s*USD|\Z)', 
                text_content, 
                re.DOTALL | re.IGNORECASE
            )
            
            for pattern in job_patterns:
                # Try to extract structured data from the pattern
                lines = [line.strip() for line in pattern.split('\n') if line.strip()]
                
                if len(lines) >= 2:
                    job_data = {
                        'title': lines[1] if len(lines) > 1 else 'Unknown',
                        'price': lines[0] if 'USD' in lines[0] else '',
                        'categories': [],
                        'skills': [],
                        'description': ' '.join(lines[2:5]) if len(lines) > 2 else '',
                        'time_posted': '',
                        'url': '',
                        'applications_count': 0
                    }
                    
                    # Look for applications count
                    app_match = re.search(r'(\d+)\s*Applications?', pattern, re.IGNORECASE)
                    if app_match:
                        job_data['applications_count'] = int(app_match.group(1))
                    
                    jobs.append(job_data)
            
        except Exception as e:
            logger.error(f"Error parsing from text content: {str(e)}")
        
        return jobs
    
    def get_job_details(self, job_url):
        """Get detailed information for a specific job"""
        try:
            response = self.session.get(job_url)
            response.raise_for_status()
            
            soup = BeautifulSoup(response.content, 'html.parser')
            
            # Extract detailed job information
            details = {
                'full_description': '',
                'requirements': '',
                'budget': '',
                'deadline': '',
                'client_info': ''
            }
            
            # This would need to be implemented based on the specific structure
            # of individual job pages
            
            return details
            
        except Exception as e:
            logger.error(f"Error getting job details: {str(e)}")
            return {}

# Test function
def test_scraper():
    """Test the scraper functionality"""
    scraper = MQL5Scraper()
    
    # Test without authentication first
    jobs = scraper.scrape_job_listings(max_pages=1)
    
    print(f"Found {len(jobs)} jobs")
    for i, job in enumerate(jobs[:3]):  # Show first 3 jobs
        print(f"\nJob {i+1}:")
        print(f"Title: {job['title']}")
        print(f"Price: {job['price']}")
        print(f"Categories: {job['categories']}")
        print(f"Applications: {job['applications_count']}")
        print(f"Description: {job['description'][:100]}...")

if __name__ == "__main__":
    test_scraper()

