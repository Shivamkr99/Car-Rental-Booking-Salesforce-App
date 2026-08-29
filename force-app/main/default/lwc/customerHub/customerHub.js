import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getCustomers from '@salesforce/apex/CustomerHubController.getCustomers';
import getCustomer360 from '@salesforce/apex/CustomerHubController.getCustomer360';
import saveCustomerRecord from '@salesforce/apex/CustomerHubController.saveCustomerRecord';

export default class CustomerHub extends LightningElement {
    @track searchKey = '';
    @track licenseFilter = 'All';
    @track customersList = [];
    @track isLoading = true;

    licenseFilterOptions = [
        { label: 'All License Statuses', value: 'All' },
        { label: 'Valid', value: 'Valid' },
        { label: 'Expiring Soon (<30 days)', value: 'Expiring Soon' },
        { label: 'Expired', value: 'Expired' }
    ];

    // Customer 360 Modal
    @track is360ModalOpen = false;
    @track selected360Customer = {};
    @track customer360Bookings = [];
    @track customer360Payments = [];
    @track customer360Reviews = [];

    // Add Customer Modal
    @track isAddModalOpen = false;
    @track newFirstName = '';
    @track newLastName = '';
    @track newEmail = '';
    @track newPhone = '';
    @track newLicense = '';
    @track newExpiryDate = '';

    connectedCallback() {
        this.fetchCustomers();
        const futureDate = new Date();
        futureDate.setFullYear(futureDate.getFullYear() + 5);
        this.newExpiryDate = this.formatDate(futureDate);
    }

    formatDate(d) {
        const year = d.getFullYear();
        const month = String(d.getMonth() + 1).padStart(2, '0');
        const day = String(d.getDate()).padStart(2, '0');
        return `${year}-${month}-${day}`;
    }

    fetchCustomers() {
        this.isLoading = true;
        getCustomers({
            searchKey: this.searchKey,
            licenseStatusFilter: this.licenseFilter
        })
            .then(data => {
                this.customersList = data.map(c => {
                    let licenseBadgeClass = 'badge-license';
                    if (c.licenseStatus === 'Valid') licenseBadgeClass += ' badge-valid';
                    else if (c.licenseStatus === 'Expiring Soon') licenseBadgeClass += ' badge-expiring';
                    else licenseBadgeClass += ' badge-expired';

                    const formattedSpend = c.lifetimeSpent != null ? `₹${Number(c.lifetimeSpent).toLocaleString('en-IN')}` : '₹0';
                    const phoneDisplay = c.phone || 'No Phone';

                    return {
                        ...c,
                        licenseBadgeClass,
                        formattedSpend,
                        phoneDisplay
                    };
                });
                this.isLoading = false;
            })
            .catch(error => {
                console.error('Error fetching customers:', error);
                this.customersList = [];
                this.isLoading = false;
            });
    }

    handleSearchChange(e) {
        this.searchKey = e.target.value;
        this.fetchCustomers();
    }

    handleLicenseFilterChange(e) {
        this.licenseFilter = e.detail.value;
        this.fetchCustomers();
    }

    handleResetFilters() {
        this.searchKey = '';
        this.licenseFilter = 'All';
        this.fetchCustomers();
    }

    // Computed Stats
    get totalCustomersCount() {
        return this.customersList.length;
    }

    get activeRentersCount() {
        return this.customersList.filter(c => c.activeBookings > 0).length;
    }

    get expiringLicensesCount() {
        return this.customersList.filter(c => c.licenseStatus === 'Expiring Soon' || c.licenseStatus === 'Expired').length;
    }

    get totalLifetimeSpent() {
        if (!this.customersList || this.customersList.length === 0) return '₹0';
        const sum = this.customersList.reduce((acc, c) => acc + (c.lifetimeSpent || 0), 0);
        return `₹${Math.round(sum).toLocaleString('en-IN')}`;
    }

    get hasCustomers() {
        return this.customersList && this.customersList.length > 0;
    }

    // Customer 360 Handlers
    handleOpenCustomer360(e) {
        const custId = e.target.dataset.id;
        getCustomer360({ customerId: custId })
            .then(data => {
                this.selected360Customer = data.customer;
                this.customer360Bookings = data.bookings || [];
                this.customer360Payments = data.payments || [];
                this.customer360Reviews = data.reviews || [];
                this.is360ModalOpen = true;
            })
            .catch(error => {
                console.error('Customer 360 error:', error);
                this.showToast('Error', 'Unable to retrieve Customer 360 data.', 'error');
            });
    }

    handleCloseCustomer360() {
        this.is360ModalOpen = false;
    }

    get has360Bookings() {
        return this.customer360Bookings && this.customer360Bookings.length > 0;
    }

    get has360Payments() {
        return this.customer360Payments && this.customer360Payments.length > 0;
    }

    // Add Customer Handlers
    handleOpenAddModal() {
        this.isAddModalOpen = true;
    }

    handleCloseAddModal() {
        this.isAddModalOpen = false;
    }

    handleNewFirstChange(e) { this.newFirstName = e.target.value; }
    handleNewLastChange(e) { this.newLastName = e.target.value; }
    handleNewEmailChange(e) { this.newEmail = e.target.value; }
    handleNewPhoneChange(e) { this.newPhone = e.target.value; }
    handleNewLicenseChange(e) { this.newLicense = e.target.value; }
    handleNewExpiryChange(e) { this.newExpiryDate = e.target.value; }

    async handleSubmitNewCustomer() {
        if (!this.newLastName || !this.newEmail || !this.newLicense) {
            this.showToast('Validation Error', 'Last Name, Email, and Driving License Number are required.', 'error');
            return;
        }

        try {
            await saveCustomerRecord({
                customer: {
                    First_Name__c: this.newFirstName,
                    Last_Name__c: this.newLastName,
                    Email__c: this.newEmail,
                    Phone__c: this.newPhone,
                    Driving_License_Number__c: this.newLicense,
                    License_Expiry_Date__c: this.newExpiryDate,
                    Active__c: true
                }
            });

            this.showToast('Success', `Customer ${this.newFirstName} ${this.newLastName} registered successfully!`, 'success');
            this.handleCloseAddModal();
            this.fetchCustomers();
        } catch (error) {
            console.error('Error saving customer:', error);
            const msg = error.body && error.body.message ? error.body.message : 'Failed to register customer.';
            this.showToast('Error', msg, 'error');
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
