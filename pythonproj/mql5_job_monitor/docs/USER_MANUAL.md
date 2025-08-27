# MQL5 Job Monitor - User Manual

## Table of Contents
1. [Getting Started](#getting-started)
2. [First Time Setup](#first-time-setup)
3. [Using the Application](#using-the-application)
4. [Configuration Options](#configuration-options)
5. [Understanding the Interface](#understanding-the-interface)
6. [Troubleshooting](#troubleshooting)

## Getting Started

### System Requirements
- Windows 10 or later
- Python 3.11 or higher
- At least 100MB free disk space
- Internet connection
- Modern web browser (Chrome, Firefox, Edge)

### Quick Start
1. Extract the application files to a folder (e.g., `C:\MQL5JobMonitor`)
2. Open Command Prompt or PowerShell as Administrator
3. Navigate to the application folder
4. Run the setup commands (see Installation section)
5. Start the application
6. Open your web browser to `http://localhost:8080`

## First Time Setup

### Step 1: Install Python Dependencies
```bash
# Navigate to the application directory
cd C:\MQL5JobMonitor

# Create virtual environment
python -m venv venv

# Activate virtual environment
venv\Scripts\activate

# Install required packages
pip install -r requirements.txt
```

### Step 2: Start the Application
```bash
# Make sure virtual environment is activated
venv\Scripts\activate

# Start the application
python test_app.py
```

### Step 3: Access the Web Interface
1. Open your web browser
2. Navigate to `http://localhost:8080`
3. You should see the MQL5 Job Monitor interface

### Step 4: Configure Your Settings
1. Click the **Settings** button (⚙️) in the top-right corner
2. Enter your MQL5 credentials:
   - **Username**: Your MQL5.com username
   - **Password**: Your MQL5.com password
   - **Max Pages**: How many pages to scrape (recommended: 3)
3. Click **Save Settings**

## Using the Application

### Dashboard Overview
The main dashboard shows:
- **Statistics Cards**: Total jobs, new jobs, recent jobs, and categories count
- **Filter Section**: Tools to narrow down job listings
- **Job Listings**: Current job postings with details
- **Pagination**: Navigate through multiple pages of results

### Scraping New Jobs
1. **Ensure your settings are configured** with valid MQL5 credentials
2. **Click "Scrape New Jobs"** button in the job listings section
3. **Wait for the process to complete** (you'll see a loading indicator)
4. **Check the notification** for results (e.g., "5 new jobs found")
5. **Review the updated job listings** and statistics

### Filtering Jobs
Use the filter section to find specific jobs:

#### Keyword Search
- Enter terms to search in job titles and descriptions
- Example: "EA", "indicator", "MT4", "strategy"

#### Category Filter
Select from available categories:
- **Indicators**: Custom technical indicators
- **Experts**: Expert Advisors (trading robots)
- **Libraries**: Code libraries and modules
- **Scripts**: Trading scripts
- **Integration**: API and system integration
- **Converting**: Code conversion between platforms
- **Translation**: Language translation services
- **Design**: UI/UX and graphic design
- **Consultation**: Trading and technical consulting
- **Other**: Miscellaneous projects

#### Price Range
- **Min Price**: Minimum budget in USD
- **Max Price**: Maximum budget in USD
- Leave empty for no limit

#### Additional Filters
- **New Jobs Only**: Show only recently discovered jobs
- **Days Back**: How far back to look (1-30 days)

### Managing Job Listings

#### Viewing Job Details
Each job card shows:
- **Title**: Project name and description
- **Price**: Budget or price range
- **Categories**: Project type tags
- **Skills**: Required technical skills
- **Applications**: Number of freelancer applications
- **Time Posted**: When the job was posted on MQL5
- **Description**: Project details (truncated)

#### Marking Jobs as Read
- Click **"Mark as read"** on new jobs to remove the "NEW" badge
- This helps track which jobs you've already reviewed

#### Opening Original Job Posts
- Click the **"View"** button to open the original MQL5 job posting
- This opens in a new browser tab

### Refreshing Data
- Click the **"Refresh"** button (🔄) to update statistics and job listings
- This doesn't scrape new jobs, only refreshes the display

## Configuration Options

### Settings Panel
Access via the Settings button (⚙️):

#### MQL5 Credentials
- **Username**: Your MQL5.com account username
- **Password**: Your MQL5.com account password
- **Note**: Credentials are stored locally in your browser

#### Scraping Options
- **Max Pages**: Number of job listing pages to scrape (1-10)
  - **1 page**: ~20 jobs (fastest)
  - **3 pages**: ~60 jobs (recommended)
  - **5+ pages**: 100+ jobs (slower but comprehensive)

### Local Storage
Settings are automatically saved in your browser's local storage and persist between sessions.

## Understanding the Interface

### Statistics Cards
- **Total Jobs**: All jobs in your local database
- **New Jobs**: Jobs marked as new (not yet reviewed)
- **Recent Jobs**: Jobs added in the last 7 days
- **Categories**: Number of different job categories

### Job Status Indicators
- **NEW Badge**: Recently discovered jobs
- **Green Border**: High-priority or well-paying jobs
- **Application Count**: Shows competition level
- **Time Stamps**: Helps identify fresh opportunities

### Pagination
- Navigate through multiple pages of results
- Shows current page and total pages
- Use Previous/Next buttons or click page numbers

### Toast Notifications
Temporary messages that appear in the top-right:
- **Green**: Success messages (e.g., "Scraping completed")
- **Red**: Error messages (e.g., "Login failed")
- **Blue**: Information messages (e.g., "Settings saved")

## Troubleshooting

### Application Won't Start
**Problem**: Error when running `python test_app.py`
**Solutions**:
1. Ensure Python 3.11+ is installed
2. Activate virtual environment: `venv\Scripts\activate`
3. Install dependencies: `pip install -r requirements.txt`
4. Check for port conflicts (close other applications using port 8080)

### Can't Access Web Interface
**Problem**: Browser shows "Connection refused" at `http://localhost:8080`
**Solutions**:
1. Verify the application is running (check command prompt)
2. Try a different browser
3. Check Windows Firewall settings
4. Restart the application

### Scraping Fails
**Problem**: "Scraping failed" or "Login failed" messages
**Solutions**:
1. **Verify MQL5 credentials** in Settings
2. **Check internet connection**
3. **Try manual login** to MQL5.com to verify account status
4. **Reduce max pages** to 1 and try again
5. **Wait a few minutes** before retrying (avoid rate limiting)

### No Jobs Appear
**Problem**: Job listings section is empty
**Solutions**:
1. **Click "Scrape New Jobs"** to fetch initial data
2. **Check filter settings** (clear all filters)
3. **Verify database** was created (check for `src/database/app.db`)
4. **Restart application** if database issues persist

### Login Issues
**Problem**: Authentication fails with correct credentials
**Solutions**:
1. **Verify credentials** by logging into MQL5.com manually
2. **Check for special characters** in password
3. **Try without authentication** (some content may be accessible)
4. **Clear browser cache** and restart application

### Performance Issues
**Problem**: Application runs slowly
**Solutions**:
1. **Reduce max pages** in settings
2. **Close other browser tabs**
3. **Restart the application** periodically
4. **Clear old job data** by deleting the database file

### Browser Compatibility
**Problem**: Interface doesn't display correctly
**Solutions**:
1. **Use a modern browser** (Chrome, Firefox, Edge)
2. **Enable JavaScript** in browser settings
3. **Clear browser cache** and cookies
4. **Try incognito/private mode**

### Data Not Updating
**Problem**: Statistics or job listings don't refresh
**Solutions**:
1. **Click the Refresh button** (🔄)
2. **Hard refresh** the browser page (Ctrl+F5)
3. **Check network connectivity**
4. **Restart the application**

## Advanced Usage Tips

### Optimal Scraping Strategy
1. **Start with 1-2 pages** to test functionality
2. **Gradually increase** to 3-5 pages for comprehensive coverage
3. **Run scraping 2-3 times per day** for best results
4. **Monitor for new categories** and adjust filters accordingly

### Efficient Job Monitoring
1. **Use keyword filters** for your specialization
2. **Set price range filters** based on your rates
3. **Check "New Jobs Only"** for quick reviews
4. **Mark jobs as read** to track your progress

### Data Management
1. **Regularly scrape** to keep data current
2. **Use date filters** to focus on recent opportunities
3. **Export important jobs** by copying URLs
4. **Clean database** periodically by deleting the app.db file

---

**Need Help?** Check the README.md file for technical details or contact support.

