import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getBookings from '@salesforce/apex/BookingManagementController.getBookings';
import getBookingCounts from '@salesforce/apex/BookingManagementController.getBookingCounts';
import updateStatus from '@salesforce/apex/BookingManagementController.updateStatus';
import recordPaymentForBooking from '@salesforce/apex/BookingManagementController.recordPaymentForBooking';
import { getCarImage, CAR_ASSETS } from './carImageAssets';

const FALLBACK_SVG = 'data:image/svg+xml;utf8,<svg xmlns="http://www.w3.org/2000/svg" width="600" height="360" viewBox="0 0 600 360"><rect width="600" height="360" fill="%230f172a"/><path d="M120 220 L160 140 L440 140 L480 220 Z" fill="%230284c7"/><circle cx="180" cy="230" r="30" fill="%23e2e8f0"/><circle cx="420" cy="230" r="30" fill="%23e2e8f0"/><text x="300" y="300" fill="%2338bdf8" font-size="22" font-family="sans-serif" font-weight="bold" text-anchor="middle">PREMIUM FLEET VEHICLE</text></svg>';

export default class BookingManagementHub extends LightningElement {
    @track currentStatusTab = 'All';
    @track searchKey = '';
    @track bookingsList = [];
    @track counts = { allCount: 0, pendingCount: 0, confirmedCount: 0, activeCount: 0, completedCount: 0, cancelledCount: 0 };
    @track isLoading = true;

    // Payment Modal
    @track isPaymentModalOpen = false;
    @track payBookingId = '';
    @track payAmount = 0;
    @track payMethod = 'UPI';
    @track payRef = '';

    paymentMethodOptions = [
        { label: 'UPI (Google Pay / PhonePe)', value: 'UPI' },
        { label: 'Credit / Debit Card', value: 'Credit Card' },
        { label: 'Cash', value: 'Cash' },
        { label: 'Bank Transfer', value: 'Bank Transfer' }
    ];

    connectedCallback() {
        this.fetchData();
    }

    fetchData() {
        this.isLoading = true;
        Promise.all([
            getBookings({ statusFilter: this.currentStatusTab, searchKey: this.searchKey }),
            getBookingCounts()
        ])
            .then(([bookings, countsData]) => {
                this.counts = countsData;
                this.bookingsList = bookings.map(b => {
                    const displayImageUrl = getCarImage('', b.carName);

                    let statusBadgeClass = 'badge-status';
                    if (b.status === 'Active') statusBadgeClass += ' badge-active';
                    else if (b.status === 'Confirmed') statusBadgeClass += ' badge-confirmed';
                    else if (b.status === 'Pending') statusBadgeClass += ' badge-pending';
                    else if (b.status === 'Completed') statusBadgeClass += ' badge-completed';
                    else statusBadgeClass += ' badge-cancelled';

                    let payStatusClass = 'badge-pay';
                    if (b.paymentStatus === 'Paid') payStatusClass += ' pay-paid';
                    else if (b.paymentStatus === 'Refunded') payStatusClass += ' pay-refunded';
                    else payStatusClass += ' pay-unpaid';

                    const isPending = b.status === 'Pending';
                    const isConfirmed = b.status === 'Confirmed';
                    const isActive = b.status === 'Active';
                    const isCompleted = b.status === 'Completed';
                    const isCancelled = b.status === 'Cancelled';
                    const isUnpaid = b.paymentStatus !== 'Paid';

                    return {
                        ...b,
                        displayImageUrl,
                        statusBadgeClass,
                        payStatusClass,
                        isPending,
                        isConfirmed,
                        isActive,
                        isCompleted,
                        isCancelled,
                        isUnpaid
                    };
                });
                this.isLoading = false;
            })
            .catch(error => {
                console.error('Error fetching bookings:', error);
                this.bookingsList = [];
                this.isLoading = false;
            });
    }

    handleImageError(event) {
        event.target.src = FALLBACK_SVG;
    }

    handleRefresh() {
        this.fetchData();
    }

    handleTabClick(e) {
        this.currentStatusTab = e.currentTarget.dataset.status;
        this.fetchData();
    }

    handleSearchChange(e) {
        this.searchKey = e.target.value;
        this.fetchData();
    }

    // Status Tab Active Classes
    get tabAllClass() { return `tab-btn ${this.currentStatusTab === 'All' ? 'active-tab' : ''}`; }
    get tabPendingClass() { return `tab-btn ${this.currentStatusTab === 'Pending' ? 'active-tab' : ''}`; }
    get tabConfirmedClass() { return `tab-btn ${this.currentStatusTab === 'Confirmed' ? 'active-tab' : ''}`; }
    get tabActiveClass() { return `tab-btn ${this.currentStatusTab === 'Active' ? 'active-tab active-green' : ''}`; }
    get tabCompletedClass() { return `tab-btn ${this.currentStatusTab === 'Completed' ? 'active-tab' : ''}`; }
    get tabCancelledClass() { return `tab-btn ${this.currentStatusTab === 'Cancelled' ? 'active-tab' : ''}`; }

    get hasBookings() {
        return this.bookingsList && this.bookingsList.length > 0;
    }

    // Lifecycle Status Action Handler
    async handleUpdateStatus(e) {
        const bookingId = e.target.dataset.id;
        const newStatus = e.target.dataset.status;

        try {
            await updateStatus({ bookingId, newStatus });
            this.showToast('Status Updated', `Booking status changed to ${newStatus}.`, 'success');
            this.fetchData();
        } catch (error) {
            console.error('Error updating status:', error);
            const msg = error.body && error.body.message ? error.body.message : 'Failed to update booking status.';
            this.showToast('Error', msg, 'error');
        }
    }

    // Payment Modal
    handleOpenPaymentModal(e) {
        this.payBookingId = e.target.dataset.id;
        this.payAmount = e.target.dataset.amount || 0;
        this.payRef = 'TXN-' + Date.now();
        this.isPaymentModalOpen = true;
    }

    handleClosePaymentModal() {
        this.isPaymentModalOpen = false;
    }

    handlePayAmountChange(e) { this.payAmount = e.target.value; }
    handlePayMethodChange(e) { this.payMethod = e.detail.value; }
    handlePayRefChange(e) { this.payRef = e.target.value; }

    async handleSubmitPayment() {
        if (!this.payAmount || this.payAmount <= 0) {
            this.showToast('Validation Error', 'Enter a valid payment amount.', 'error');
            return;
        }

        try {
            await recordPaymentForBooking({
                bookingId: this.payBookingId,
                amount: Number(this.payAmount),
                paymentMethod: this.payMethod,
                transactionRef: this.payRef
            });

            this.showToast('Payment Recorded', `Payment of ₹${this.payAmount} recorded successfully!`, 'success');
            this.handleClosePaymentModal();
            this.fetchData();
        } catch (error) {
            console.error('Payment record error:', error);
            this.showToast('Error', 'Failed to record payment.', 'error');
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
