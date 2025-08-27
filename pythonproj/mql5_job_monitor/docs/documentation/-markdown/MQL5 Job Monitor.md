# MQL5 Job Monitor

A Python web application that monitors MQL5 freelance job postings, authenticates with user credentials, and provides configurable reports on new job posts.

## Features

- **Web Scraping**: Automatically scrapes job postings from the MQL5 freelance portal
- **Authentication**: Supports MQL5 account login for accessing authenticated content
- **Database Storage**: Stores job data in SQLite database for persistence
- **Web Interface**: Modern, responsive web interface built with HTML, CSS, and JavaScript
- **Filtering**: Advanced filtering options by keywords, categories, price range, and date
- **Real-time Updates**: Refresh job listings and statistics in real-time
- **Configurable Reports**: Customizable report scope and criteria

## System Requirements

- Python 3.11 or higher
- Windows operating system (as specified in requirements)
- Internet connection for scraping MQL5 portal
- Modern web browser for accessing the interface

## Installation

1. **Extract the project files** to your desired directory
2. **Navigate to the project directory**:
   ```bash
   cd mql5_job_monitor
   ```
3. **Create and activate a virtual environment**:
   ```bash
   python -m venv venv
   venv\Scripts\activate  # On Windows
   ```
4. **Install dependencies**:
   ```bash
   pip install -r requirements.txt
   ```

## Usage

### Starting the Application

1. **Activate the virtual environment** (if not already activated):
   ```bash
   venv\Scripts\activate  # On Windows
   ```

2. **Run the application**:
   ```bash
   python test_app.py
   ```

3. **Access the web interface**:
   Open your web browser and navigate to `http://localhost:8080`

### Configuration

1. **Click the Settings button** (gear icon) in the top-right corner
2. **Enter your MQL5 credentials**:
   - Username: Your MQL5 username
   - Password: Your MQL5 password
   - Max Pages: Number of pages to scrape (1-10)
3. **Save the settings**

### Scraping Jobs

1. **Click the "Scrape New Jobs" button** to fetch the latest job postings
2. **Monitor the progress** via toast notifications
3. **View the results** in the job listings section

### Filtering Jobs

Use the filter section to narrow down job listings:

- **Keywords**: Search in job titles and descriptions
- **Categories**: Filter by job categories (Indicators, Experts, etc.)
- **Price Range**: Set minimum and maximum price filters
- **New Jobs Only**: Show only newly discovered jobs
- **Date Range**: Filter by how recent the jobs are

## Project Structure

```
mql5_job_monitor/
├── src/
│   ├── models/
│   │   ├── user.py              # User model (from template)
│   │   └── job_posting.py       # Job posting data model
│   ├── routes/
│   │   ├── user.py              # User routes (from template)
│   │   └── jobs.py              # Job-related API endpoints
│   ├── static/
│   │   ├── index.html           # Main web interface
│   │   └── app.js               # Frontend JavaScript
│   ├── database/
│   │   └── app.db               # SQLite database
│   ├── main.py                  # Main Flask application
│   └── scraper.py               # MQL5 web scraper
├── venv/                        # Virtual environment
├── test_app.py                  # Standalone test application
├── requirements.txt             # Python dependencies
└── README.md                    # This file
```

## API Endpoints

The application provides the following REST API endpoints:

### Statistics
- `GET /api/stats` - Get job statistics (total, new, recent, categories)

### Job Management
- `GET /api/jobs` - Get job listings with optional filtering
- `GET /api/jobs/<id>` - Get specific job details
- `POST /api/jobs/<id>/mark-read` - Mark job as read (not new)

### Scraping
- `POST /api/scrape` - Trigger new job scraping
  ```json
  {
    "username": "your_mql5_username",
    "password": "your_mql5_password",
    "max_pages": 3
  }
  ```

### Categories and Skills
- `GET /api/categories` - Get available job categories
- `GET /api/skills` - Get available job skills

## Database Schema

### JobPosting Table
- `id` - Primary key
- `title` - Job title
- `price` - Job price/budget
- `categories` - JSON array of categories
- `skills` - JSON array of required skills
- `description` - Job description
- `time_posted` - When the job was posted
- `url` - Link to the original job posting
- `date_added` - When the job was added to our database
- `is_new` - Whether the job is marked as new
- `applications_count` - Number of applications

## Technical Implementation

### Web Scraping
The scraper (`src/scraper.py`) uses:
- **requests** for HTTP requests
- **BeautifulSoup** for HTML parsing
- **Session management** for maintaining login state
- **Error handling** and retry mechanisms

### Backend
The Flask backend provides:
- **RESTful API** for frontend communication
- **SQLAlchemy ORM** for database operations
- **CORS support** for cross-origin requests
- **Error handling** and validation

### Frontend
The web interface features:
- **Responsive design** with Tailwind CSS
- **Interactive components** with vanilla JavaScript
- **Real-time updates** via AJAX calls
- **Toast notifications** for user feedback
- **Local storage** for settings persistence

## Troubleshooting

### Common Issues

1. **Connection Refused Error**:
   - Ensure the Flask app is running
   - Check that port 8080 is not in use by another application
   - Verify firewall settings

2. **Scraping Fails**:
   - Check your MQL5 credentials
   - Verify internet connection
   - MQL5 website structure may have changed

3. **Database Errors**:
   - Ensure the `src/database/` directory exists
   - Check file permissions
   - Delete `app.db` to reset the database

4. **Import Errors**:
   - Ensure virtual environment is activated
   - Install all dependencies: `pip install -r requirements.txt`

### Logs and Debugging

- Check `app.log` for application logs
- Use browser developer tools for frontend debugging
- Enable Flask debug mode for detailed error messages

## Security Considerations

- **Credentials**: Store MQL5 credentials securely
- **Rate Limiting**: Be respectful of MQL5 server resources
- **Local Use**: This application is designed for local use only
- **HTTPS**: Use HTTPS in production environments

## Future Enhancements

Potential improvements for future versions:

1. **Email Notifications**: Send alerts for new jobs matching criteria
2. **Advanced Filtering**: More sophisticated filtering options
3. **Job Tracking**: Track application status and responses
4. **Export Features**: Export job data to CSV/Excel
5. **Scheduling**: Automated periodic scraping
6. **Multi-user Support**: Support for multiple MQL5 accounts
7. **Mobile App**: Native mobile application
8. **API Integration**: Direct MQL5 API integration (if available)

## License

This project is provided as-is for personal use. Please respect MQL5's terms of service when using this tool.

## Support

For issues or questions:
1. Check the troubleshooting section
2. Review the application logs
3. Ensure all dependencies are properly installed
4. Verify MQL5 website accessibility

---

**Note**: This application is designed to work with the current MQL5 website structure. If MQL5 updates their website, the scraper may need adjustments.

