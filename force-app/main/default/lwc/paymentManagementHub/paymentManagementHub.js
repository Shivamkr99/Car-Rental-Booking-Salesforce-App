import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getFinancialKPIs from '@salesforce/apex/FinancialsHubController.getFinancialKPIs';
import getPayments from '@salesforce/apex/FinancialsHubController.getPayments';
import savePaymentRecord from '@salesforce/apex/FinancialsHubController.savePaymentRecord';
import refundPayment from '@salesforce/apex/FinancialsHubController.refundPayment';
import getBookings from '@salesforce/apex/BookingManagementController.getBookings';

export default class PaymentManagementHub extends LightningElement {
    @track searchKey = '';
    @track statusFilter = 'All';
    @track paymentsList = [];
    @track kpis = { totalRevenue: 0, monthRevenue: 0, pendingRevenue: 0, refundedAmount: 0, totalTransactions: 0, paidCount: 0, pendingCount: 0, refundedCount: 0 };
    @track isLoading = true;

    statusOptions = [
        { label: 'All Statuses', value: 'All' },
        { label: 'Paid', value: 'Paid' },
        { label: 'Pending', value: 'Pending' },
        { label: 'Refunded', value: 'Refunded' }
    ];

    statusFormOptions = [
        { label: 'Paid', value: 'Paid' },
        { label: 'Pending', value: 'Pending' }
    ];

    paymentMethodOptions = [
        { label: 'UPI (Google Pay / PhonePe)', value: 'UPI' },
        { label: 'Credit / Debit Card', value: 'Credit Card' },
        { label: 'Cash', value: 'Cash' },
        { label: 'Bank Transfer', value: 'Bank Transfer' }
    ];

    // New Payment Modal
    @track isNewPayModalOpen = false;
    @track bookingOptions = [];
    @track newPayBookingId = '';
    @track newPayAmount = 0;
    @track newPayMethod = 'UPI';
    @track newPayStatus = 'Paid';
    @track newPayDate = '';
    @track newPayRef = '';

    connectedCallback() {
        this.fetchData();
        this.newPayDate = this.formatDate(new Date());
    }

    formatDate(d) {
        const year = d.getFullYear();
        const month = String(d.getMonth() + 1).padStart(2, '0');
        const day = String(d.getDate()).padStart(2, '0');
        return `${year}-${month}-${day}`;
    }

    fetchData() {
        this.isLoading = true;
        Promise.all([
            getFinancialKPIs(),
            getPayments({ statusFilter: this.statusFilter, searchKey: this.searchKey })
        ])
            .then(([kpisData, payments]) => {
                this.kpis = kpisData;
                this.paymentsList = payments.map(p => {
                    const formattedAmount = p.amount != null ? `₹${Number(p.amount).toLocaleString('en-IN')}` : '₹0';

                    let statusClass = 'pay-status-pill';
                    if (p.paymentStatus === 'Paid') statusClass += ' pill-paid';
                    else if (p.paymentStatus === 'Pending') statusClass += ' pill-pending';
                    else statusClass += ' pill-refunded';

                    const isPaid = p.paymentStatus === 'Paid';

                    return {
                        ...p,
                        formattedAmount,
                        statusClass,
                        isPaid
                    };
                });
                this.isLoading = false;
            })
            .catch(error => {
                console.error('Error fetching payments:', error);
                this.paymentsList = [];
                this.isLoading = false;
            });
    }

    handleSearchChange(e) {
        this.searchKey = e.target.value;
        this.fetchData();
    }

    handleStatusFilterChange(e) {
        this.statusFilter = e.detail.value;
        this.fetchData();
    }

    handleResetFilters() {
        this.searchKey = '';
        this.statusFilter = 'All';
        this.fetchData();
    }

    // Computed KPI Strings
    get formattedTotalRevenue() {
        return `₹${Number(this.kpis.totalRevenue || 0).toLocaleString('en-IN')}`;
    }

    get formattedMonthRevenue() {
        return `₹${Number(this.kpis.monthRevenue || 0).toLocaleString('en-IN')}`;
    }

    get formattedPendingRevenue() {
        return `₹${Number(this.kpis.pendingRevenue || 0).toLocaleString('en-IN')}`;
    }

    get formattedRefundedAmount() {
        return `₹${Number(this.kpis.refundedAmount || 0).toLocaleString('en-IN')}`;
    }

    get hasPayments() {
        return this.paymentsList && this.paymentsList.length > 0;
    }

    // Refund Handler
    async handleRefundClick(e) {
        const paymentId = e.currentTarget.dataset.id;
        try {
            await refundPayment({ paymentId });
            this.showToast('Refund Processed', 'Payment has been refunded successfully.', 'success');
            this.fetchData();
        } catch (error) {
            console.error('Refund error:', error);
            this.showToast('Error', 'Failed to refund payment.', 'error');
        }
    }

    // New Payment Modal Handlers
    handleOpenNewPayModal() {
        getBookings({ statusFilter: 'All', searchKey: '' })
            .then(bookings => {
                this.bookingOptions = bookings.map(b => ({
                    label: `${b.name} - ${b.customerName} (${b.carName}) - Total: ₹${b.totalAmount}`,
                    value: b.id
                }));
                if (this.bookingOptions.length > 0) {
                    this.newPayBookingId = this.bookingOptions[0].value;
                }
                this.newPayRef = 'TXN-' + Date.now();
                this.isNewPayModalOpen = true;
            })
            .catch(err => console.error('Booking fetch error:', err));
    }

    handleCloseNewPayModal() {
        this.isNewPayModalOpen = false;
    }

    handleNewPayBookingChange(e) { this.newPayBookingId = e.detail.value; }
    handleNewPayAmountChange(e) { this.newPayAmount = e.target.value; }
    handleNewPayMethodChange(e) { this.newPayMethod = e.detail.value; }
    handleNewPayStatusChange(e) { this.newPayStatus = e.detail.value; }
    handleNewPayDateChange(e) { this.newPayDate = e.target.value; }
    handleNewPayRefChange(e) { this.newPayRef = e.target.value; }

    async handleSubmitNewPay() {
        if (!this.newPayBookingId || !this.newPayAmount || this.newPayAmount <= 0) {
            this.showToast('Validation Error', 'Booking selection and valid amount are required.', 'error');
            return;
        }

        try {
            await savePaymentRecord({
                payment: {
                    Booking__c: this.newPayBookingId,
                    Amount__c: Number(this.newPayAmount),
                    Payment_Method__c: this.newPayMethod,
                    Payment_Status__c: this.newPayStatus,
                    Payment_Date__c: this.newPayDate,
                    Transaction_Reference__c: this.newPayRef
                }
            });

            this.showToast('Success', 'Payment transaction logged successfully!', 'success');
            this.handleCloseNewPayModal();
            this.fetchData();
        } catch (error) {
            console.error('Error recording payment:', error);
            this.showToast('Error', 'Failed to save payment transaction.', 'error');
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
