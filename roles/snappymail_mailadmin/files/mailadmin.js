/**
 * MailAdmin Standalone Frontend
 * Calls separate PHP API instead of SnappyMail plugin hooks
 */

(function() {
    'use strict';

    // API endpoint
    const API_URL = '/wm/admin-api.php';

    // Admin View Model
    class MailAdminViewModel {
        constructor() {
            this.domains = ko.observableArray([]);
            this.users = ko.observableArray([]);
            this.aliases = ko.observableArray([]);
            
            this.selectedDomain = ko.observable('');
            this.selectedUser = ko.observable(null);
            
            this.loading = ko.observable(false);
            this.error = ko.observable('');
            this.success = ko.observable('');
            
            // Form data
            this.newDomain = ko.observable('');
            this.newUserEmail = ko.observable('');
            this.newUserPassword = ko.observable('');
            this.newAliasSource = ko.observable('');
            this.newAliasDestination = ko.observable('');
            
            // Signature & Vacation
            this.userSignature = ko.observable('');
            this.vacationSubject = ko.observable('');
            this.vacationMessage = ko.observable('');
            this.vacationStartDate = ko.observable('');
            this.vacationEndDate = ko.observable('');
            this.vacationActive = ko.observable(false);
            
            // Initialize
            this.loadDomains();
        }

        // ========================================
        // API CALLS
        // ========================================

        async apiCall(action, params = {}) {
            this.loading(true);
            this.error('');
            this.success('');

            try {
                const response = await fetch(API_URL, {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json',
                    },
                    body: JSON.stringify({
                        action: action,
                        ...params
                    })
                });

                const data = await response.json();
                
                this.loading(false);

                if (data.success) {
                    if (data.message) {
                        this.success(data.message);
                        setTimeout(() => this.success(''), 3000);
                    }
                    return data;
                } else {
                    this.error(data.message || 'Request failed');
                    return null;
                }
            } catch (error) {
                this.loading(false);
                this.error('Network error: ' + error.message);
                return null;
            }
        }

        // ========================================
        // DOMAIN MANAGEMENT
        // ========================================

        async loadDomains() {
            const result = await this.apiCall('getDomains');
            if (result) {
                this.domains(result.domains || []);
            }
        }

        async addDomain() {
            const domain = this.newDomain().trim();
            if (!domain) {
                this.error('Please enter a domain name');
                return;
            }

            const result = await this.apiCall('addDomain', { domain });
            if (result) {
                this.newDomain('');
                this.loadDomains();
            }
        }

        async removeDomain(domain) {
            if (!confirm(`Delete domain ${domain.name}? This will also delete all users and aliases!`)) {
                return;
            }

            const result = await this.apiCall('removeDomain', { domain: domain.name });
            if (result) {
                this.loadDomains();
                if (this.selectedDomain() === domain.name) {
                    this.selectedDomain('');
                    this.users([]);
                }
            }
        }

        selectDomain(domain) {
            this.selectedDomain(domain.name);
            this.loadUsers(domain.name);
            this.loadAliases(domain.name);
        }

        // ========================================
        // USER MANAGEMENT
        // ========================================

        async loadUsers(domain = '') {
            const result = await this.apiCall('getUsers', { domain });
            if (result) {
                this.users(result.users || []);
            }
        }

        async addUser() {
            const email = this.newUserEmail().trim();
            const password = this.newUserPassword();

            if (!email || !password) {
                this.error('Please enter email and password');
                return;
            }

            const result = await this.apiCall('addUser', { email, password });
            if (result) {
                this.newUserEmail('');
                this.newUserPassword('');
                this.loadUsers(this.selectedDomain());
            }
        }

        async removeUser(user) {
            if (!confirm(`Delete user ${user.email}? This will delete all their emails!`)) {
                return;
            }

            const result = await this.apiCall('removeUser', { email: user.email });
            if (result) {
                this.loadUsers(this.selectedDomain());
            }
        }

        async toggleUserEnabled(user) {
            const action = user.enabled === 1 ? 'disableUser' : 'enableUser';
            const result = await this.apiCall(action, { email: user.email });
            if (result) {
                this.loadUsers(this.selectedDomain());
            }
        }

        async changeUserPassword(user) {
            const password = prompt(`Enter new password for ${user.email}:`);
            if (!password) return;

            await this.apiCall('changePassword', { email: user.email, password });
        }

        selectUser(user) {
            this.selectedUser(user);
            this.loadUserSignature(user.email);
            this.loadUserVacation(user.email);
        }

        // ========================================
        // ALIAS MANAGEMENT
        // ========================================

        async loadAliases(domain = '') {
            const result = await this.apiCall('getAliases', { domain });
            if (result) {
                this.aliases(result.aliases || []);
            }
        }

        async addAlias() {
            const source = this.newAliasSource().trim();
            const destination = this.newAliasDestination().trim();

            if (!source || !destination) {
                this.error('Please enter source and destination');
                return;
            }

            const result = await this.apiCall('addAlias', { source, destination });
            if (result) {
                this.newAliasSource('');
                this.newAliasDestination('');
                this.loadAliases(this.selectedDomain());
            }
        }

        async removeAlias(alias) {
            if (!confirm(`Delete alias ${alias.source}?`)) {
                return;
            }

            const result = await this.apiCall('removeAlias', { source: alias.source });
            if (result) {
                this.loadAliases(this.selectedDomain());
            }
        }

        // ========================================
        // SIGNATURE MANAGEMENT
        // ========================================

        async loadUserSignature(email) {
            const result = await this.apiCall('getSignature', { email });
            if (result) {
                this.userSignature(result.signature || '');
            }
        }

        async saveUserSignature() {
            const user = this.selectedUser();
            if (!user) return;

            await this.apiCall('setSignature', {
                email: user.email,
                signature: this.userSignature()
            });
        }

        // ========================================
        // VACATION MANAGEMENT
        // ========================================

        async loadUserVacation(email) {
            const result = await this.apiCall('getVacation', { email });
            if (result && result.vacation) {
                this.vacationSubject(result.vacation.subject || '');
                this.vacationMessage(result.vacation.message || '');
                this.vacationStartDate(result.vacation.start_date || '');
                this.vacationEndDate(result.vacation.end_date || '');
                this.vacationActive(true);
            } else {
                this.clearVacationForm();
                this.vacationActive(false);
            }
        }

        async saveUserVacation() {
            const user = this.selectedUser();
            if (!user) return;

            const subject = this.vacationSubject().trim();
            const message = this.vacationMessage().trim();
            const startDate = this.vacationStartDate();
            const endDate = this.vacationEndDate();

            if (!subject || !message || !startDate || !endDate) {
                this.error('Please fill all vacation fields');
                return;
            }

            const result = await this.apiCall('setVacation', {
                email: user.email,
                subject,
                message,
                start_date: startDate,
                end_date: endDate
            });

            if (result) {
                this.vacationActive(true);
            }
        }

        async disableUserVacation() {
            const user = this.selectedUser();
            if (!user) return;

            const result = await this.apiCall('disableVacation', { email: user.email });
            if (result) {
                this.clearVacationForm();
                this.vacationActive(false);
            }
        }

        clearVacationForm() {
            this.vacationSubject('');
            this.vacationMessage('');
            this.vacationStartDate('');
            this.vacationEndDate('');
        }

        // ========================================
        // HELPERS
        // ========================================

        formatDate(dateString) {
            if (!dateString) return '';
            const date = new Date(dateString);
            return date.toLocaleDateString();
        }

        getStatusBadge(enabled) {
            return enabled === 1 ? 
                '<span class="badge badge-success">Active</span>' : 
                '<span class="badge badge-danger">Disabled</span>';
        }
    }

    // Initialize after DOM load
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', init);
    } else {
        init();
    }

    function init() {
        // Check if we're logged in to SnappyMail
        if (typeof rl === 'undefined' || !rl.settings) {
            console.log('MailAdmin: Not in SnappyMail context');
            return;
        }

        // Initialize ViewModel
        window.mailAdminVM = new MailAdminViewModel();

        // Add floating admin button
        addAdminButton();
    }

    // Add visible admin button
    function addAdminButton() {
        // Check if button already exists
        if (document.getElementById('mailadmin-btn')) {
            return;
        }
        
        // Create floating button
        const btn = document.createElement('button');
        btn.id = 'mailadmin-btn';
        btn.innerHTML = '⚙️ Admin';
        btn.style.cssText = `
            position: fixed;
            bottom: 20px;
            right: 20px;
            z-index: 9999;
            padding: 12px 20px;
            background: #007bff;
            color: white;
            border: none;
            border-radius: 25px;
            font-size: 14px;
            font-weight: bold;
            cursor: pointer;
            box-shadow: 0 4px 12px rgba(0,0,0,0.3);
            transition: all 0.3s;
        `;
        
        btn.onmouseover = () => {
            btn.style.background = '#0056b3';
            btn.style.transform = 'translateY(-2px)';
            btn.style.boxShadow = '0 6px 16px rgba(0,0,0,0.4)';
        };
        
        btn.onmouseout = () => {
            btn.style.background = '#007bff';
            btn.style.transform = 'translateY(0)';
            btn.style.boxShadow = '0 4px 12px rgba(0,0,0,0.3)';
        };
        
        btn.onclick = (e) => {
            e.preventDefault();
            showMailAdminPanel();
        };
        
        document.body.appendChild(btn);
    }

    // Show admin panel (full HTML from previous version)
    window.showMailAdminPanel = function() {
        // Remove old panel if exists
        const oldPanel = document.getElementById('mailadmin-panel');
        if (oldPanel) {
            oldPanel.remove();
        }

        const panelHTML = `
            <div id="mailadmin-panel" style="position: fixed; top: 0; left: 0; right: 0; bottom: 0; background: rgba(0,0,0,0.5); z-index: 10000; overflow: auto;">
                <div style="max-width: 1200px; margin: 50px auto; background: white; border-radius: 8px; box-shadow: 0 4px 20px rgba(0,0,0,0.3);">
                    <div style="padding: 20px; border-bottom: 2px solid #007bff; display: flex; justify-content: space-between; align-items: center;">
                        <h2 style="margin: 0;">Mail Server Administration</h2>
                        <button onclick="document.getElementById('mailadmin-panel').remove()" style="background: #dc3545; color: white; border: none; padding: 8px 16px; border-radius: 4px; cursor: pointer;">Close</button>
                    </div>
                    
                    <div style="padding: 20px;">
                        <!-- Status Messages -->
                        <div data-bind="visible: error" style="padding: 12px; margin: 10px 0; background: #f8d7da; border: 1px solid #f5c6cb; border-radius: 4px; color: #721c24;" data-bind="text: error"></div>
                        <div data-bind="visible: success" style="padding: 12px; margin: 10px 0; background: #d4edda; border: 1px solid #c3e6cb; border-radius: 4px; color: #155724;" data-bind="text: success"></div>
                        <div data-bind="visible: loading" style="text-align: center; padding: 20px;">⏳ Loading...</div>

                        <!-- Simple Tab Navigation -->
                        <div style="border-bottom: 2px solid #dee2e6; margin-bottom: 20px;">
                            <button onclick="showTab('domains')" id="tab-domains" class="mailadmin-tab" style="padding: 10px 20px; border: none; background: #007bff; color: white; cursor: pointer; margin-right: 5px;">Domains</button>
                            <button onclick="showTab('users')" id="tab-users" class="mailadmin-tab" style="padding: 10px 20px; border: none; background: #6c757d; color: white; cursor: pointer; margin-right: 5px;">Users</button>
                            <button onclick="showTab('aliases')" id="tab-aliases" class="mailadmin-tab" style="padding: 10px 20px; border: none; background: #6c757d; color: white; cursor: pointer;">Aliases</button>
                        </div>

                        <!-- Domains Tab -->
                        <div id="content-domains" class="mailadmin-content">
                            <h3>Virtual Domains</h3>
                            <div style="margin: 20px 0; display: flex; gap: 10px;">
                                <input type="text" data-bind="value: newDomain" placeholder="domain.com" style="flex: 1; padding: 10px; border: 1px solid #ced4da; border-radius: 4px;" />
                                <button data-bind="click: addDomain" style="padding: 10px 20px; background: #007bff; color: white; border: none; border-radius: 4px; cursor: pointer;">Add Domain</button>
                            </div>
                            <table style="width: 100%; border-collapse: collapse; margin-top: 20px;">
                                <thead style="background: #f8f9fa;">
                                    <tr>
                                        <th style="padding: 12px; text-align: left; border-bottom: 2px solid #dee2e6;">Domain</th>
                                        <th style="padding: 12px; text-align: left; border-bottom: 2px solid #dee2e6;">Created</th>
                                        <th style="padding: 12px; text-align: left; border-bottom: 2px solid #dee2e6;">Actions</th>
                                    </tr>
                                </thead>
                                <tbody data-bind="foreach: domains">
                                    <tr style="border-bottom: 1px solid #dee2e6;">
                                        <td style="padding: 12px;" data-bind="text: name"></td>
                                        <td style="padding: 12px;" data-bind="text: created_at"></td>
                                        <td style="padding: 12px;">
                                            <button data-bind="click: $parent.removeDomain" style="padding: 5px 10px; background: #dc3545; color: white; border: none; border-radius: 4px; cursor: pointer;">Delete</button>
                                        </td>
                                    </tr>
                                </tbody>
                            </table>
                        </div>

                        <!-- Users Tab -->
                        <div id="content-users" class="mailadmin-content" style="display: none;">
                            <h3>Users</h3>
                            <div style="margin: 20px 0; display: flex; gap: 10px;">
                                <input type="email" data-bind="value: newUserEmail" placeholder="user@domain.com" style="flex: 1; padding: 10px; border: 1px solid #ced4da; border-radius: 4px;" />
                                <input type="password" data-bind="value: newUserPassword" placeholder="Password" style="flex: 1; padding: 10px; border: 1px solid #ced4da; border-radius: 4px;" />
                                <button data-bind="click: addUser" style="padding: 10px 20px; background: #007bff; color: white; border: none; border-radius: 4px; cursor: pointer;">Add User</button>
                            </div>
                            <table style="width: 100%; border-collapse: collapse; margin-top: 20px;">
                                <thead style="background: #f8f9fa;">
                                    <tr>
                                        <th style="padding: 12px; text-align: left; border-bottom: 2px solid #dee2e6;">Email</th>
                                        <th style="padding: 12px; text-align: left; border-bottom: 2px solid #dee2e6;">Domain</th>
                                        <th style="padding: 12px; text-align: left; border-bottom: 2px solid #dee2e6;">Status</th>
                                        <th style="padding: 12px; text-align: left; border-bottom: 2px solid #dee2e6;">Actions</th>
                                    </tr>
                                </thead>
                                <tbody data-bind="foreach: users">
                                    <tr style="border-bottom: 1px solid #dee2e6;">
                                        <td style="padding: 12px;" data-bind="text: email"></td>
                                        <td style="padding: 12px;" data-bind="text: domain"></td>
                                        <td style="padding: 12px;" data-bind="html: $parent.getStatusBadge(enabled)"></td>
                                        <td style="padding: 12px;">
                                            <button data-bind="click: $parent.toggleUserEnabled" style="padding: 5px 10px; background: #6c757d; color: white; border: none; border-radius: 4px; cursor: pointer; margin-right: 5px;">Toggle</button>
                                            <button data-bind="click: $parent.changeUserPassword" style="padding: 5px 10px; background: #ffc107; color: black; border: none; border-radius: 4px; cursor: pointer; margin-right: 5px;">Password</button>
                                            <button data-bind="click: $parent.removeUser" style="padding: 5px 10px; background: #dc3545; color: white; border: none; border-radius: 4px; cursor: pointer;">Delete</button>
                                        </td>
                                    </tr>
                                </tbody>
                            </table>
                        </div>

                        <!-- Aliases Tab -->
                        <div id="content-aliases" class="mailadmin-content" style="display: none;">
                            <h3>Email Aliases</h3>
                            <div style="margin: 20px 0; display: flex; gap: 10px; align-items: center;">
                                <input type="email" data-bind="value: newAliasSource" placeholder="alias@domain.com" style="flex: 1; padding: 10px; border: 1px solid #ced4da; border-radius: 4px;" />
                                <span>→</span>
                                <input type="email" data-bind="value: newAliasDestination" placeholder="target@domain.com" style="flex: 1; padding: 10px; border: 1px solid #ced4da; border-radius: 4px;" />
                                <button data-bind="click: addAlias" style="padding: 10px 20px; background: #007bff; color: white; border: none; border-radius: 4px; cursor: pointer;">Add Alias</button>
                            </div>
                            <table style="width: 100%; border-collapse: collapse; margin-top: 20px;">
                                <thead style="background: #f8f9fa;">
                                    <tr>
                                        <th style="padding: 12px; text-align: left; border-bottom: 2px solid #dee2e6;">Source</th>
                                        <th style="padding: 12px; text-align: left; border-bottom: 2px solid #dee2e6;">Destination</th>
                                        <th style="padding: 12px; text-align: left; border-bottom: 2px solid #dee2e6;">Actions</th>
                                    </tr>
                                </thead>
                                <tbody data-bind="foreach: aliases">
                                    <tr style="border-bottom: 1px solid #dee2e6;">
                                        <td style="padding: 12px;" data-bind="text: source"></td>
                                        <td style="padding: 12px;" data-bind="text: destination"></td>
                                        <td style="padding: 12px;">
                                            <button data-bind="click: $parent.removeAlias" style="padding: 5px 10px; background: #dc3545; color: white; border: none; border-radius: 4px; cursor: pointer;">Delete</button>
                                        </td>
                                    </tr>
                                </tbody>
                            </table>
                        </div>
                    </div>
                </div>
            </div>
        `;

        document.body.insertAdjacentHTML('beforeend', panelHTML);
        
        // Apply Knockout bindings
        ko.applyBindings(window.mailAdminVM, document.getElementById('mailadmin-panel'));

        // Tab switching function
        window.showTab = function(tabName) {
            // Hide all content
            document.querySelectorAll('.mailadmin-content').forEach(el => el.style.display = 'none');
            // Reset all tab buttons
            document.querySelectorAll('.mailadmin-tab').forEach(el => el.style.background = '#6c757d');
            // Show selected content
            document.getElementById('content-' + tabName).style.display = 'block';
            // Highlight selected tab
            document.getElementById('tab-' + tabName).style.background = '#007bff';
        };
    };

})();
