# MQL5 Job Monitor - Deployment Guide

## Overview
This guide provides instructions for deploying the MQL5 Job Monitor application on a Windows machine for production use.

## Deployment Options

### Option 1: Local Development Server (Recommended for Personal Use)
This is the simplest option for personal use on a single Windows machine.

#### Prerequisites
- Windows 10 or later
- Python 3.11 or higher
- Git (optional, for updates)

#### Installation Steps

1. **Download and Extract**
   ```bash
   # Extract the application files to your desired location
   # Example: C:\MQL5JobMonitor
   ```

2. **Setup Python Environment**
   ```bash
   cd C:\MQL5JobMonitor
   python -m venv venv
   venv\Scripts\activate
   pip install -r requirements.txt
   ```

3. **Create Startup Script**
   Create `start_app.bat`:
   ```batch
   @echo off
   cd /d "C:\MQL5JobMonitor"
   call venv\Scripts\activate
   python test_app.py
   pause
   ```

4. **Create Desktop Shortcut**
   - Right-click on `start_app.bat`
   - Select "Create shortcut"
   - Move shortcut to Desktop
   - Rename to "MQL5 Job Monitor"

#### Running the Application
1. Double-click the desktop shortcut
2. Wait for "Starting MQL5 Job Monitor..." message
3. Open browser to `http://localhost:8080`

### Option 2: Windows Service (Advanced)
For running as a background service that starts automatically.

#### Prerequisites
- All requirements from Option 1
- Administrative privileges
- NSSM (Non-Sucking Service Manager) or similar tool

#### Installation Steps

1. **Download NSSM**
   - Download from https://nssm.cc/download
   - Extract to `C:\nssm`

2. **Create Service Script**
   Create `service_app.py`:
   ```python
   import os
   import sys
   
   # Set working directory
   os.chdir(r'C:\MQL5JobMonitor')
   
   # Add to Python path
   sys.path.insert(0, os.getcwd())
   
   # Import and run the app
   from test_app import app
   
   if __name__ == '__main__':
       app.run(host='0.0.0.0', port=8080, debug=False)
   ```

3. **Install Service**
   ```bash
   # Run as Administrator
   cd C:\nssm\win64
   nssm install MQL5JobMonitor
   
   # Configure service
   nssm set MQL5JobMonitor Application "C:\MQL5JobMonitor\venv\Scripts\python.exe"
   nssm set MQL5JobMonitor AppParameters "C:\MQL5JobMonitor\service_app.py"
   nssm set MQL5JobMonitor AppDirectory "C:\MQL5JobMonitor"
   nssm set MQL5JobMonitor DisplayName "MQL5 Job Monitor"
   nssm set MQL5JobMonitor Description "MQL5 Freelance Job Monitoring Service"
   
   # Start service
   nssm start MQL5JobMonitor
   ```

### Option 3: Standalone Executable (Future Enhancement)
For distribution without Python installation requirements.

#### Using PyInstaller
```bash
# Install PyInstaller
pip install pyinstaller

# Create executable
pyinstaller --onefile --windowed --add-data "src/static;static" test_app.py

# The executable will be in dist/test_app.exe
```

## Configuration for Production

### Security Considerations

1. **Change Secret Key**
   In `test_app.py`, change:
   ```python
   app.config['SECRET_KEY'] = 'your-secure-random-key-here'
   ```

2. **Database Security**
   - Ensure database file has proper permissions
   - Consider encryption for sensitive data

3. **Network Security**
   - Use firewall rules to restrict access
   - Consider HTTPS for remote access

### Performance Optimization

1. **Database Optimization**
   ```python
   # Add database indexes for better performance
   # In your model definitions:
   class JobPosting(db.Model):
       # ... existing fields ...
       
       __table_args__ = (
           db.Index('idx_date_added', 'date_added'),
           db.Index('idx_is_new', 'is_new'),
           db.Index('idx_title', 'title'),
       )
   ```

2. **Caching**
   ```python
   # Add caching for frequently accessed data
   from flask_caching import Cache
   
   cache = Cache(app, config={'CACHE_TYPE': 'simple'})
   
   @cache.memoize(timeout=300)  # 5 minutes
   def get_cached_stats():
       # Your stats logic here
       pass
   ```

3. **Rate Limiting**
   ```python
   # Add rate limiting for scraping
   import time
   from datetime import datetime, timedelta
   
   last_scrape_time = None
   MIN_SCRAPE_INTERVAL = 300  # 5 minutes
   
   def can_scrape():
       global last_scrape_time
       if last_scrape_time is None:
           return True
       return datetime.now() - last_scrape_time > timedelta(seconds=MIN_SCRAPE_INTERVAL)
   ```

### Monitoring and Logging

1. **Enhanced Logging**
   ```python
   import logging
   from logging.handlers import RotatingFileHandler
   
   # Configure logging
   if not app.debug:
       file_handler = RotatingFileHandler('logs/mql5_monitor.log', maxBytes=10240, backupCount=10)
       file_handler.setFormatter(logging.Formatter(
           '%(asctime)s %(levelname)s: %(message)s [in %(pathname)s:%(lineno)d]'
       ))
       file_handler.setLevel(logging.INFO)
       app.logger.addHandler(file_handler)
       app.logger.setLevel(logging.INFO)
   ```

2. **Health Check Endpoint**
   ```python
   @app.route('/health')
   def health_check():
       return jsonify({
           'status': 'healthy',
           'timestamp': datetime.utcnow().isoformat(),
           'version': '1.0.0'
       })
   ```

### Backup and Recovery

1. **Database Backup Script**
   Create `backup_db.py`:
   ```python
   import shutil
   import os
   from datetime import datetime
   
   def backup_database():
       timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
       source = 'src/database/app.db'
       backup_dir = 'backups'
       
       if not os.path.exists(backup_dir):
           os.makedirs(backup_dir)
       
       backup_file = f'{backup_dir}/app_db_backup_{timestamp}.db'
       shutil.copy2(source, backup_file)
       print(f'Database backed up to {backup_file}')
   
   if __name__ == '__main__':
       backup_database()
   ```

2. **Automated Backup Task**
   Create Windows Task Scheduler entry:
   ```bash
   # Run daily at 2 AM
   schtasks /create /tn "MQL5 DB Backup" /tr "C:\MQL5JobMonitor\venv\Scripts\python.exe C:\MQL5JobMonitor\backup_db.py" /sc daily /st 02:00
   ```

## Maintenance

### Regular Tasks

1. **Database Cleanup**
   ```python
   # Remove old job postings (older than 30 days)
   from datetime import datetime, timedelta
   
   def cleanup_old_jobs():
       cutoff_date = datetime.utcnow() - timedelta(days=30)
       old_jobs = JobPosting.query.filter(JobPosting.date_added < cutoff_date).all()
       
       for job in old_jobs:
           db.session.delete(job)
       
       db.session.commit()
       print(f'Cleaned up {len(old_jobs)} old job postings')
   ```

2. **Log Rotation**
   - Logs are automatically rotated using RotatingFileHandler
   - Monitor disk space usage
   - Archive old logs if needed

3. **Update Dependencies**
   ```bash
   # Periodically update Python packages
   venv\Scripts\activate
   pip list --outdated
   pip install --upgrade package_name
   pip freeze > requirements.txt
   ```

### Troubleshooting Production Issues

1. **Check Service Status**
   ```bash
   # For Windows Service deployment
   sc query MQL5JobMonitor
   nssm status MQL5JobMonitor
   ```

2. **View Logs**
   ```bash
   # Check application logs
   type logs\mql5_monitor.log
   
   # Check Windows Event Viewer for service issues
   eventvwr.msc
   ```

3. **Restart Service**
   ```bash
   # Restart the service
   nssm restart MQL5JobMonitor
   
   # Or stop and start
   nssm stop MQL5JobMonitor
   nssm start MQL5JobMonitor
   ```

## Scaling Considerations

### Multiple Users
For supporting multiple users:

1. **User Authentication**
   - Implement user registration/login
   - Separate job data per user
   - User-specific settings

2. **Database Migration**
   - Consider PostgreSQL for better concurrency
   - Implement proper database migrations
   - Add user foreign keys to job postings

3. **Load Balancing**
   - Use WSGI server (Gunicorn, uWSGI)
   - Implement reverse proxy (Nginx)
   - Consider containerization (Docker)

### High Availability
For production environments:

1. **Database Replication**
   - Master-slave database setup
   - Automated failover
   - Regular backup verification

2. **Application Redundancy**
   - Multiple application instances
   - Load balancer health checks
   - Graceful degradation

3. **Monitoring**
   - Application performance monitoring
   - Database performance monitoring
   - Alert systems for failures

## Security Hardening

### Application Security
1. **Input Validation**
   - Sanitize all user inputs
   - Validate API parameters
   - Prevent SQL injection

2. **Authentication Security**
   - Encrypt stored credentials
   - Implement session timeouts
   - Use secure password policies

3. **Network Security**
   - Use HTTPS in production
   - Implement CSRF protection
   - Add security headers

### System Security
1. **File Permissions**
   - Restrict database file access
   - Secure log file permissions
   - Limit application user privileges

2. **Firewall Configuration**
   - Block unnecessary ports
   - Allow only required traffic
   - Monitor network connections

3. **Update Management**
   - Regular security updates
   - Dependency vulnerability scanning
   - Automated patch management

---

This deployment guide provides a comprehensive approach to deploying the MQL5 Job Monitor in various environments. Choose the option that best fits your needs and security requirements.

