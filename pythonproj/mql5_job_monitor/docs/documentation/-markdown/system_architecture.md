# System Architecture for MQL5 Job Posting Monitor

## 1. Overview

The system will be a Python application with a web frontend, designed to monitor new job postings on the MQL5 freelance portal. It will authenticate with the user's MQL5 account, scrape job data, store it locally, and provide a configurable report.

## 2. Components

### 2.1. Authentication Module

*   **Challenge**: Direct programmatic login to MQL5.com is proving difficult. The `MetaTrader5` Python package is not suitable for web portal interaction, and a public web API for the freelance portal is not readily available.
*   **Proposed Solution**: 
    *   **Initial Approach**: Attempt to use `requests` library with session management to handle cookies and maintain a logged-in state. This will involve identifying the login form fields and submitting credentials programmatically. 
    *   **Fallback (if programmatic login fails)**: If automated login proves too complex or unreliable, the system will prompt the user to manually log in via a browser, and then attempt to capture and reuse the session cookies. This would require the user to perform a one-time manual login when the application starts or when the session expires.

### 2.2. Scraping Module

*   **Technology**: Python with `BeautifulSoup` for HTML parsing and `requests` for making HTTP requests.
*   **Process**: 
    1.  Fetch the MQL5 freelance job portal page (`https://www.mql5.com/en/job`).
    2.  Parse the HTML content to identify individual job postings.
    3.  Extract relevant data for each job posting: 
        *   Job Title
        *   Price/Budget
        *   Categories
        *   Skills (if available)
        *   Description (truncated or full, depending on page structure)
        *   Time Posted
        *   Link to the full job post
    4.  Handle pagination to retrieve all new job postings.

### 2.3. Data Storage Module

*   **Technology**: SQLite database (lightweight, file-based, suitable for local desktop application).
*   **Schema**: A single table `job_postings` will store the extracted data.
    *   `id` (INTEGER PRIMARY KEY AUTOINCREMENT)
    *   `title` (TEXT)
    *   `price` (TEXT)
    *   `categories` (TEXT - comma-separated string or JSON string)
    *   `skills` (TEXT - comma-separated string or JSON string)
    *   `description` (TEXT)
    *   `time_posted` (TEXT - or TIMESTAMP, depending on format)
    *   `url` (TEXT)
    *   `date_added` (TIMESTAMP - for tracking when the job was first seen)
    *   `is_new` (BOOLEAN - flag for new job posts since last report)

### 2.4. Reporting Module

*   **Functionality**: Generate reports based on user-configurable criteria.
*   **Configuration Options (from technical spec)**:
    *   **Keywords**: Filter jobs by keywords in title or description.
    *   **Categories**: Filter by specific job categories.
    *   **Price Range**: Filter by minimum and maximum price.
    *   **Timeframe**: Filter by time posted (e.g., last 24 hours, last week).
*   **Output Format**: Initially, a simple text or HTML report. Could be extended to CSV or PDF.

### 2.5. Web Frontend Module

*   **Technology**: Flask (Python web framework) for the backend API and a simple HTML/CSS/JavaScript frontend.
*   **Features**: 
    *   Login interface (if manual login is required).
    *   Configuration page for report settings.
    *   Display of new job postings.
    *   Option to trigger a new scan.

## 3. Data Flow

1.  User starts the application.
2.  **Authentication Module** attempts to log in or prompts for manual login.
3.  Upon successful authentication, **Scraping Module** fetches job data.
4.  **Scraping Module** parses data and stores it in the **Data Storage Module**.
5.  **Reporting Module** queries the **Data Storage Module** based on user configurations.
6.  **Web Frontend Module** displays the report and provides controls.

## 4. Future Considerations

*   Error handling and retry mechanisms for network requests.
*   Scheduling automated scans.
*   Notifications (e.g., email, desktop notification) for new jobs matching criteria.
*   More robust UI for configuration and reporting.
*   Packaging as a standalone executable for Windows.

