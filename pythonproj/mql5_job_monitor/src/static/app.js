// MQL5 Job Monitor Frontend JavaScript

class MQL5JobMonitor {
    constructor() {
        this.apiBase = '/api';
        this.currentPage = 1;
        this.currentFilters = {};
        this.settings = this.loadSettings();
        this.init();
    }

    init() {
        this.bindEvents();
        this.loadStats();
        this.loadCategories();
        this.loadJobs();
    }

    bindEvents() {
        // Refresh button
        document.getElementById('refreshBtn').addEventListener('click', () => {
            this.loadStats();
            this.loadJobs();
        });

        // Settings button
        document.getElementById('settingsBtn').addEventListener('click', () => {
            this.showSettings();
        });

        // Settings modal
        document.getElementById('closeSettingsBtn').addEventListener('click', () => {
            this.hideSettings();
        });

        document.getElementById('cancelSettingsBtn').addEventListener('click', () => {
            this.hideSettings();
        });

        document.getElementById('saveSettingsBtn').addEventListener('click', () => {
            this.saveSettings();
        });

        // Filters
        document.getElementById('applyFiltersBtn').addEventListener('click', () => {
            this.applyFilters();
        });

        // Scrape button
        document.getElementById('scrapeBtn').addEventListener('click', () => {
            this.scrapeJobs();
        });

        // Close modal when clicking outside
        document.getElementById('settingsModal').addEventListener('click', (e) => {
            if (e.target.id === 'settingsModal') {
                this.hideSettings();
            }
        });
    }

    async loadStats() {
        try {
            const response = await fetch(`${this.apiBase}/stats`);
            const data = await response.json();
            
            if (data.success) {
                document.getElementById('totalJobs').textContent = data.stats.total_jobs;
                document.getElementById('newJobs').textContent = data.stats.new_jobs;
                document.getElementById('recentJobs').textContent = data.stats.recent_jobs;
                document.getElementById('categoriesCount').textContent = Object.keys(data.stats.categories).length;
            }
        } catch (error) {
            console.error('Error loading stats:', error);
            this.showToast('Error loading statistics', 'error');
        }
    }

    async loadCategories() {
        try {
            const response = await fetch(`${this.apiBase}/categories`);
            const data = await response.json();
            
            if (data.success) {
                const select = document.getElementById('categoriesFilter');
                select.innerHTML = '<option value="">All Categories</option>';
                
                data.categories.forEach(category => {
                    const option = document.createElement('option');
                    option.value = category;
                    option.textContent = category;
                    select.appendChild(option);
                });
            }
        } catch (error) {
            console.error('Error loading categories:', error);
        }
    }

    async loadJobs(page = 1) {
        try {
            this.showLoading();
            
            const params = new URLSearchParams({
                page: page,
                per_page: 20,
                ...this.currentFilters
            });

            const response = await fetch(`${this.apiBase}/jobs?${params}`);
            const data = await response.json();
            
            if (data.success) {
                this.renderJobs(data.jobs);
                this.renderPagination(data.pagination);
                document.getElementById('jobCount').textContent = `${data.pagination.total} jobs found`;
            } else {
                this.showToast(data.message || 'Error loading jobs', 'error');
            }
        } catch (error) {
            console.error('Error loading jobs:', error);
            this.showToast('Error loading jobs', 'error');
            this.renderError('Failed to load jobs. Please try again.');
        }
    }

    renderJobs(jobs) {
        const container = document.getElementById('jobsList');
        
        if (jobs.length === 0) {
            container.innerHTML = `
                <div class="text-center py-12">
                    <i class="fas fa-search text-4xl text-gray-400 mb-4"></i>
                    <p class="text-gray-600">No jobs found matching your criteria.</p>
                </div>
            `;
            return;
        }

        container.innerHTML = jobs.map(job => `
            <div class="job-card bg-gray-50 rounded-lg p-6 mb-4 border border-gray-200 fade-in">
                <div class="flex items-start justify-between mb-3">
                    <div class="flex-1">
                        <h3 class="text-lg font-semibold text-gray-800 mb-2 line-clamp-2">
                            ${this.escapeHtml(job.title)}
                            ${job.is_new ? '<span class="inline-block bg-green-500 text-white text-xs px-2 py-1 rounded-full ml-2">NEW</span>' : ''}
                        </h3>
                        <div class="flex items-center space-x-4 text-sm text-gray-600 mb-3">
                            ${job.price ? `<span class="flex items-center"><i class="fas fa-dollar-sign mr-1"></i>${this.escapeHtml(job.price)}</span>` : ''}
                            ${job.applications_count ? `<span class="flex items-center"><i class="fas fa-users mr-1"></i>${job.applications_count} applications</span>` : ''}
                            ${job.time_posted ? `<span class="flex items-center"><i class="fas fa-clock mr-1"></i>${this.escapeHtml(job.time_posted)}</span>` : ''}
                        </div>
                    </div>
                    ${job.url ? `<a href="${this.escapeHtml(job.url)}" target="_blank" class="bg-blue-500 hover:bg-blue-600 text-white px-4 py-2 rounded-lg transition-all duration-300 flex items-center space-x-2 ml-4">
                        <i class="fas fa-external-link-alt"></i>
                        <span>View</span>
                    </a>` : ''}
                </div>
                
                ${job.categories && job.categories.length > 0 ? `
                    <div class="flex flex-wrap gap-2 mb-3">
                        ${job.categories.map(cat => `<span class="bg-blue-100 text-blue-800 text-xs px-2 py-1 rounded-full">${this.escapeHtml(cat)}</span>`).join('')}
                    </div>
                ` : ''}
                
                ${job.skills && job.skills.length > 0 ? `
                    <div class="flex flex-wrap gap-2 mb-3">
                        ${job.skills.map(skill => `<span class="bg-purple-100 text-purple-800 text-xs px-2 py-1 rounded-full">${this.escapeHtml(skill)}</span>`).join('')}
                    </div>
                ` : ''}
                
                ${job.description ? `
                    <p class="text-gray-700 text-sm line-clamp-3">${this.escapeHtml(job.description)}</p>
                ` : ''}
                
                <div class="flex items-center justify-between mt-4">
                    <span class="text-xs text-gray-500">Added: ${new Date(job.date_added).toLocaleDateString()}</span>
                    ${job.is_new ? `<button onclick="app.markAsRead(${job.id})" class="text-xs text-blue-600 hover:text-blue-800">Mark as read</button>` : ''}
                </div>
            </div>
        `).join('');
    }

    renderPagination(pagination) {
        const container = document.getElementById('pagination');
        
        if (pagination.pages <= 1) {
            container.innerHTML = '';
            return;
        }

        let paginationHTML = '<div class="flex items-center space-x-2">';
        
        // Previous button
        if (pagination.has_prev) {
            paginationHTML += `<button onclick="app.loadJobs(${pagination.page - 1})" class="px-3 py-2 bg-white border border-gray-300 rounded-lg hover:bg-gray-50 transition-all duration-300">Previous</button>`;
        }
        
        // Page numbers
        const startPage = Math.max(1, pagination.page - 2);
        const endPage = Math.min(pagination.pages, pagination.page + 2);
        
        if (startPage > 1) {
            paginationHTML += `<button onclick="app.loadJobs(1)" class="px-3 py-2 bg-white border border-gray-300 rounded-lg hover:bg-gray-50 transition-all duration-300">1</button>`;
            if (startPage > 2) {
                paginationHTML += '<span class="px-3 py-2">...</span>';
            }
        }
        
        for (let i = startPage; i <= endPage; i++) {
            const isActive = i === pagination.page;
            paginationHTML += `<button onclick="app.loadJobs(${i})" class="px-3 py-2 ${isActive ? 'bg-blue-500 text-white' : 'bg-white border border-gray-300 hover:bg-gray-50'} rounded-lg transition-all duration-300">${i}</button>`;
        }
        
        if (endPage < pagination.pages) {
            if (endPage < pagination.pages - 1) {
                paginationHTML += '<span class="px-3 py-2">...</span>';
            }
            paginationHTML += `<button onclick="app.loadJobs(${pagination.pages})" class="px-3 py-2 bg-white border border-gray-300 rounded-lg hover:bg-gray-50 transition-all duration-300">${pagination.pages}</button>`;
        }
        
        // Next button
        if (pagination.has_next) {
            paginationHTML += `<button onclick="app.loadJobs(${pagination.page + 1})" class="px-3 py-2 bg-white border border-gray-300 rounded-lg hover:bg-gray-50 transition-all duration-300">Next</button>`;
        }
        
        paginationHTML += '</div>';
        container.innerHTML = paginationHTML;
    }

    renderError(message) {
        const container = document.getElementById('jobsList');
        container.innerHTML = `
            <div class="text-center py-12">
                <i class="fas fa-exclamation-triangle text-4xl text-red-400 mb-4"></i>
                <p class="text-gray-600">${message}</p>
                <button onclick="app.loadJobs()" class="mt-4 bg-blue-500 hover:bg-blue-600 text-white px-4 py-2 rounded-lg transition-all duration-300">
                    Try Again
                </button>
            </div>
        `;
    }

    showLoading() {
        const container = document.getElementById('jobsList');
        container.innerHTML = `
            <div class="flex items-center justify-center py-12">
                <div class="text-center">
                    <i class="fas fa-spinner loading text-4xl text-blue-500 mb-4"></i>
                    <p class="text-gray-600">Loading job listings...</p>
                </div>
            </div>
        `;
    }

    applyFilters() {
        this.currentFilters = {
            keywords: document.getElementById('keywordsFilter').value,
            categories: document.getElementById('categoriesFilter').value,
            min_price: document.getElementById('minPriceFilter').value,
            max_price: document.getElementById('maxPriceFilter').value,
            new_only: document.getElementById('newOnlyFilter').checked,
            days_back: document.getElementById('daysBackFilter').value
        };

        // Remove empty filters
        Object.keys(this.currentFilters).forEach(key => {
            if (this.currentFilters[key] === '' || this.currentFilters[key] === false) {
                delete this.currentFilters[key];
            }
        });

        this.currentPage = 1;
        this.loadJobs(1);
    }

    async scrapeJobs() {
        try {
            const button = document.getElementById('scrapeBtn');
            const originalHTML = button.innerHTML;
            button.innerHTML = '<i class="fas fa-spinner loading mr-2"></i>Scraping...';
            button.disabled = true;

            const response = await fetch(`${this.apiBase}/scrape`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({
                    username: this.settings.username,
                    password: this.settings.password,
                    max_pages: parseInt(this.settings.maxPages) || 3
                })
            });

            const data = await response.json();
            
            if (data.success) {
                this.showToast(`Scraping completed! ${data.new_jobs} new jobs found.`, 'success');
                this.loadStats();
                this.loadJobs();
            } else {
                this.showToast(data.message || 'Scraping failed', 'error');
            }
        } catch (error) {
            console.error('Error scraping jobs:', error);
            this.showToast('Error during scraping', 'error');
        } finally {
            const button = document.getElementById('scrapeBtn');
            button.innerHTML = '<i class="fas fa-download mr-2"></i>Scrape New Jobs';
            button.disabled = false;
        }
    }

    async markAsRead(jobId) {
        try {
            const response = await fetch(`${this.apiBase}/jobs/${jobId}/mark-read`, {
                method: 'POST'
            });

            const data = await response.json();
            
            if (data.success) {
                this.loadJobs(this.currentPage);
                this.loadStats();
            }
        } catch (error) {
            console.error('Error marking job as read:', error);
        }
    }

    showSettings() {
        // Populate settings form
        document.getElementById('usernameInput').value = this.settings.username || '';
        document.getElementById('passwordInput').value = this.settings.password || '';
        document.getElementById('maxPagesInput').value = this.settings.maxPages || '3';
        
        document.getElementById('settingsModal').classList.remove('hidden');
    }

    hideSettings() {
        document.getElementById('settingsModal').classList.add('hidden');
    }

    saveSettings() {
        this.settings = {
            username: document.getElementById('usernameInput').value,
            password: document.getElementById('passwordInput').value,
            maxPages: document.getElementById('maxPagesInput').value
        };

        localStorage.setItem('mql5JobMonitorSettings', JSON.stringify(this.settings));
        this.hideSettings();
        this.showToast('Settings saved successfully', 'success');
    }

    loadSettings() {
        const saved = localStorage.getItem('mql5JobMonitorSettings');
        return saved ? JSON.parse(saved) : {};
    }

    showToast(message, type = 'info') {
        const container = document.getElementById('toastContainer');
        const toast = document.createElement('div');
        
        const bgColor = type === 'success' ? 'bg-green-500' : type === 'error' ? 'bg-red-500' : 'bg-blue-500';
        const icon = type === 'success' ? 'fa-check-circle' : type === 'error' ? 'fa-exclamation-circle' : 'fa-info-circle';
        
        toast.className = `${bgColor} text-white px-6 py-3 rounded-lg shadow-lg flex items-center space-x-3 fade-in`;
        toast.innerHTML = `
            <i class="fas ${icon}"></i>
            <span>${message}</span>
            <button onclick="this.parentElement.remove()" class="ml-4 text-white hover:text-gray-200">
                <i class="fas fa-times"></i>
            </button>
        `;
        
        container.appendChild(toast);
        
        // Auto remove after 5 seconds
        setTimeout(() => {
            if (toast.parentElement) {
                toast.remove();
            }
        }, 5000);
    }

    escapeHtml(text) {
        const div = document.createElement('div');
        div.textContent = text;
        return div.innerHTML;
    }
}

// Initialize the app
const app = new MQL5JobMonitor();

