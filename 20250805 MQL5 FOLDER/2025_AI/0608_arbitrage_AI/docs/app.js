// Forex Arbitrage Trading System JavaScript

class ForexArbitrageSystem {
    constructor() {
        this.isRunning = true;
        this.refreshInterval = 5000; // 5 seconds
        this.refreshTimer = null;
        this.startTime = Date.now();
        
        // Data from provided JSON
        this.currencyPairs = [
            {"symbol": "EURUSD", "bid": 1.0856, "ask": 1.0858, "spread": 0.0002, "change": "+0.0003"},
            {"symbol": "GBPUSD", "bid": 1.2645, "ask": 1.2647, "spread": 0.0002, "change": "-0.0008"},
            {"symbol": "USDJPY", "bid": 149.24, "ask": 149.26, "spread": 0.02, "change": "+0.15"},
            {"symbol": "USDCHF", "bid": 0.8734, "ask": 0.8736, "spread": 0.0002, "change": "+0.0004"},
            {"symbol": "AUDUSD", "bid": 0.6587, "ask": 0.6589, "spread": 0.0002, "change": "-0.0012"},
            {"symbol": "NZDUSD", "bid": 0.5934, "ask": 0.5936, "spread": 0.0002, "change": "+0.0007"},
            {"symbol": "USDCAD", "bid": 1.3812, "ask": 1.3814, "spread": 0.0002, "change": "-0.0005"},
            {"symbol": "EURGBP", "bid": 0.8584, "ask": 0.8586, "spread": 0.0002, "change": "+0.0011"}
        ];

        this.arbitrageOpportunities = [
            {"pair": "EURGBP", "real_price": 0.8584, "synthetic_price": 0.8591, "spread": 0.0007, "profit_potential": "$35", "action": "BUY", "confidence": "High"},
            {"pair": "AUDUSD", "real_price": 0.6587, "synthetic_price": 0.6582, "spread": 0.0005, "profit_potential": "$25", "action": "SELL", "confidence": "Medium"},
            {"pair": "NZDUSD", "real_price": 0.5934, "synthetic_price": 0.5940, "spread": 0.0006, "profit_potential": "$30", "action": "BUY", "confidence": "High"}
        ];

        this.performanceStats = {
            "total_trades": 247,
            "win_rate": 68.4,
            "average_profit": 23.50,
            "current_balance": 11320,
            "daily_profit": 156,
            "open_positions": 3,
            "max_drawdown": 6.5,
            "sharpe_ratio": 1.84
        };

        this.init();
    }

    init() {
        this.updateLastUpdateTime();
        this.populateCurrencyTable();
        this.populateArbitrageTable();
        this.updatePerformanceStats();
        this.setupEventListeners();
        this.startAutoRefresh();
        this.updateSystemStatus();
    }

    updateLastUpdateTime() {
        const now = new Date();
        const timeString = now.toLocaleTimeString('en-US', { 
            hour12: false,
            hour: '2-digit',
            minute: '2-digit',
            second: '2-digit'
        });
        document.getElementById('lastUpdate').textContent = `Last Update: ${timeString}`;
    }

    populateCurrencyTable() {
        const tbody = document.getElementById('currencyTableBody');
        tbody.innerHTML = '';

        this.currencyPairs.forEach(pair => {
            const row = document.createElement('tr');
            
            // Determine spread class
            let spreadClass = 'spread-tight';
            if (pair.spread > 0.0003) spreadClass = 'spread-medium';
            if (pair.spread > 0.0005) spreadClass = 'spread-wide';

            // Determine change class
            const changeClass = pair.change.startsWith('+') ? 'change-positive' : 'change-negative';

            row.innerHTML = `
                <td><span class="currency-symbol">${pair.symbol}</span></td>
                <td><span class="price-value">${pair.bid.toFixed(pair.symbol === 'USDJPY' ? 2 : 4)}</span></td>
                <td><span class="price-value">${pair.ask.toFixed(pair.symbol === 'USDJPY' ? 2 : 4)}</span></td>
                <td><span class="${spreadClass}">${pair.spread.toFixed(pair.symbol === 'USDJPY' ? 2 : 4)}</span></td>
                <td><span class="${changeClass}">${pair.change}</span></td>
                <td><span class="status status--success">ACTIVE</span></td>
            `;

            tbody.appendChild(row);
        });
    }

    populateArbitrageTable() {
        const tbody = document.getElementById('arbitrageTableBody');
        tbody.innerHTML = '';

        this.arbitrageOpportunities.forEach(opp => {
            const row = document.createElement('tr');
            
            // Determine profit class
            const profitValue = parseInt(opp.profit_potential.replace('$', ''));
            const profitClass = profitValue >= 30 ? 'profit-high' : 'profit-medium';

            // Action class
            const actionClass = opp.action === 'BUY' ? 'action-buy' : 'action-sell';

            // Confidence class
            const confidenceClass = `confidence-${opp.confidence.toLowerCase()}`;

            row.className = profitClass;
            row.innerHTML = `
                <td><span class="trading-pair">${opp.pair}</span></td>
                <td><span class="price-value">${opp.real_price.toFixed(4)}</span></td>
                <td><span class="price-value">${opp.synthetic_price.toFixed(4)}</span></td>
                <td><span class="price-value">${opp.spread.toFixed(4)}</span></td>
                <td><span class="price-positive">${opp.profit_potential}</span></td>
                <td><span class="${actionClass}">${opp.action}</span></td>
                <td><span class="${confidenceClass}">${opp.confidence}</span></td>
            `;

            tbody.appendChild(row);
        });

        // Update opportunity count
        document.getElementById('opportunityCount').textContent = this.arbitrageOpportunities.length;
    }

    updatePerformanceStats() {
        document.getElementById('totalTrades').textContent = this.performanceStats.total_trades;
        document.getElementById('winRate').textContent = `${this.performanceStats.win_rate}%`;
        document.getElementById('avgProfit').textContent = `$${this.performanceStats.average_profit}`;
        document.getElementById('currentBalance').textContent = `$${this.performanceStats.current_balance.toLocaleString()}`;
        document.getElementById('dailyProfit').textContent = `$${this.performanceStats.daily_profit}`;
        document.getElementById('openPositions').textContent = this.performanceStats.open_positions;
    }

    updateSystemStatus() {
        const uptime = this.calculateUptime();
        document.getElementById('uptime').textContent = uptime;
        
        const status = this.isRunning ? 'RUNNING' : 'STOPPED';
        const statusElement = document.getElementById('systemStatus');
        statusElement.textContent = status;
        statusElement.className = this.isRunning ? 'status status--success' : 'status status--error';
    }

    calculateUptime() {
        const elapsed = Date.now() - this.startTime;
        const hours = Math.floor(elapsed / (1000 * 60 * 60));
        const minutes = Math.floor((elapsed % (1000 * 60 * 60)) / (1000 * 60));
        return `${hours}h ${minutes}m`;
    }

    simulateMarketData() {
        // Simulate small price movements
        this.currencyPairs.forEach(pair => {
            const variation = (Math.random() - 0.5) * 0.0010; // ±0.5 pips
            
            if (pair.symbol === 'USDJPY') {
                pair.bid += variation * 100;
                pair.ask = pair.bid + pair.spread;
            } else {
                pair.bid += variation;
                pair.ask = pair.bid + pair.spread;
            }

            // Update spread occasionally
            if (Math.random() < 0.1) {
                const spreadVariation = (Math.random() - 0.5) * 0.0001;
                pair.spread = Math.max(0.0001, pair.spread + spreadVariation);
                pair.ask = pair.bid + pair.spread;
            }

            // Update change
            const changeValue = (Math.random() - 0.5) * 0.002;
            pair.change = changeValue >= 0 ? `+${changeValue.toFixed(4)}` : `${changeValue.toFixed(4)}`;
        });

        // Simulate arbitrage opportunities changes
        this.arbitrageOpportunities.forEach(opp => {
            const priceVariation = (Math.random() - 0.5) * 0.0004;
            opp.real_price += priceVariation;
            opp.synthetic_price += priceVariation * 0.8; // Synthetic follows with some lag
            opp.spread = Math.abs(opp.synthetic_price - opp.real_price);
            
            // Update profit potential based on spread
            const newProfit = Math.round(opp.spread * 50000); // Simplified calculation
            opp.profit_potential = `$${newProfit}`;
        });

        // Simulate performance stats updates
        if (Math.random() < 0.3) {
            this.performanceStats.total_trades += Math.random() < 0.5 ? 1 : 0;
            this.performanceStats.current_balance += (Math.random() - 0.4) * 100;
            this.performanceStats.daily_profit += (Math.random() - 0.4) * 10;
        }
    }

    animateValueUpdate(element) {
        element.classList.add('value-update');
        setTimeout(() => {
            element.classList.remove('value-update');
        }, 500);
    }

    refresh() {
        if (!this.isRunning) return;

        this.simulateMarketData();
        this.updateLastUpdateTime();
        
        // Animate table updates
        const currencyTable = document.getElementById('currencyTableBody');
        const arbitrageTable = document.getElementById('arbitrageTableBody');
        
        this.animateValueUpdate(currencyTable);
        this.animateValueUpdate(arbitrageTable);
        
        this.populateCurrencyTable();
        this.populateArbitrageTable();
        this.updatePerformanceStats();
        this.updateSystemStatus();
    }

    startAutoRefresh() {
        this.refreshTimer = setInterval(() => {
            this.refresh();
        }, this.refreshInterval);
    }

    stopAutoRefresh() {
        if (this.refreshTimer) {
            clearInterval(this.refreshTimer);
            this.refreshTimer = null;
        }
    }

    toggleSystem() {
        this.isRunning = !this.isRunning;
        const button = document.getElementById('startStopBtn');
        
        if (this.isRunning) {
            button.innerHTML = '<span class="btn-icon">⏸</span>Stop System';
            button.className = 'btn btn--primary control-btn';
            this.startAutoRefresh();
        } else {
            button.innerHTML = '<span class="btn-icon">▶</span>Start System';
            button.className = 'btn btn--secondary control-btn';
            this.stopAutoRefresh();
        }
        
        this.updateSystemStatus();
    }

    resetSystem() {
        // Reset to initial values
        this.performanceStats.total_trades = 247;
        this.performanceStats.current_balance = 11320;
        this.performanceStats.daily_profit = 156;
        this.performanceStats.open_positions = 3;
        
        this.startTime = Date.now();
        this.updatePerformanceStats();
        this.updateSystemStatus();
        
        // Show feedback
        const resetBtn = document.getElementById('resetBtn');
        const originalText = resetBtn.innerHTML;
        resetBtn.innerHTML = '<span class="btn-icon">✓</span>Reset Complete';
        resetBtn.disabled = true;
        
        setTimeout(() => {
            resetBtn.innerHTML = originalText;
            resetBtn.disabled = false;
        }, 2000);
    }

    updateRiskSettings() {
        const maxTrades = document.getElementById('maxTrades').value;
        const lotSize = document.getElementById('lotSize').value;
        const spreadThreshold = document.getElementById('spreadThreshold').value;
        
        // In a real system, these would be sent to the backend
        console.log('Risk settings updated:', {
            maxTrades,
            lotSize,
            spreadThreshold
        });
        
        // Update system behavior based on settings
        if (parseFloat(spreadThreshold) > 5) {
            // Simulate fewer opportunities with higher threshold
            this.arbitrageOpportunities = this.arbitrageOpportunities.slice(0, 1);
        } else {
            // Restore full opportunities
            this.arbitrageOpportunities = [
                {"pair": "EURGBP", "real_price": 0.8584, "synthetic_price": 0.8591, "spread": 0.0007, "profit_potential": "$35", "action": "BUY", "confidence": "High"},
                {"pair": "AUDUSD", "real_price": 0.6587, "synthetic_price": 0.6582, "spread": 0.0005, "profit_potential": "$25", "action": "SELL", "confidence": "Medium"},
                {"pair": "NZDUSD", "real_price": 0.5934, "synthetic_price": 0.5940, "spread": 0.0006, "profit_potential": "$30", "action": "BUY", "confidence": "High"}
            ];
        }
        
        this.populateArbitrageTable();
    }

    setupEventListeners() {
        // System control buttons
        document.getElementById('startStopBtn').addEventListener('click', () => {
            this.toggleSystem();
        });

        document.getElementById('resetBtn').addEventListener('click', () => {
            this.resetSystem();
        });

        // Risk settings
        document.getElementById('maxTrades').addEventListener('change', () => {
            this.updateRiskSettings();
        });

        document.getElementById('lotSize').addEventListener('change', () => {
            this.updateRiskSettings();
        });

        document.getElementById('spreadThreshold').addEventListener('change', () => {
            this.updateRiskSettings();
        });

        // Table row hover effects
        document.addEventListener('DOMContentLoaded', () => {
            const tables = document.querySelectorAll('.data-table tbody tr');
            tables.forEach(row => {
                row.addEventListener('mouseenter', (e) => {
                    e.target.style.transform = 'scale(1.01)';
                    e.target.style.transition = 'transform 0.2s ease';
                });
                
                row.addEventListener('mouseleave', (e) => {
                    e.target.style.transform = 'scale(1)';
                });
            });
        });

        // Keyboard shortcuts
        document.addEventListener('keydown', (e) => {
            if (e.ctrlKey || e.metaKey) {
                switch(e.key) {
                    case 's':
                        e.preventDefault();
                        this.toggleSystem();
                        break;
                    case 'r':
                        e.preventDefault();
                        this.resetSystem();
                        break;
                }
            }
        });
    }

    // Public methods for external control
    getSystemStatus() {
        return {
            isRunning: this.isRunning,
            uptime: this.calculateUptime(),
            totalTrades: this.performanceStats.total_trades,
            currentBalance: this.performanceStats.current_balance,
            opportunities: this.arbitrageOpportunities.length
        };
    }

    exportData() {
        const data = {
            timestamp: new Date().toISOString(),
            systemStatus: this.getSystemStatus(),
            currencyPairs: this.currencyPairs,
            arbitrageOpportunities: this.arbitrageOpportunities,
            performanceStats: this.performanceStats
        };
        
        const blob = new Blob([JSON.stringify(data, null, 2)], {
            type: 'application/json'
        });
        
        const url = URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = `arbitrage-data-${new Date().toISOString().slice(0, 19)}.json`;
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
        URL.revokeObjectURL(url);
    }
}

// Initialize the system when the page loads
document.addEventListener('DOMContentLoaded', () => {
    window.arbitrageSystem = new ForexArbitrageSystem();
    
    // Add export functionality
    const exportBtn = document.createElement('button');
    exportBtn.className = 'btn btn--outline';
    exportBtn.innerHTML = '📊 Export Data';
    exportBtn.style.position = 'fixed';
    exportBtn.style.bottom = '20px';
    exportBtn.style.right = '20px';
    exportBtn.style.zIndex = '1000';
    exportBtn.addEventListener('click', () => {
        window.arbitrageSystem.exportData();
    });
    document.body.appendChild(exportBtn);
    
    // Performance monitoring
    setInterval(() => {
        const status = window.arbitrageSystem.getSystemStatus();
        console.log('System Status:', status);
    }, 30000); // Log every 30 seconds
});