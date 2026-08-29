import { LightningElement, track, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getDashboardData from '@salesforce/apex/CarRentalDashboardController.getDashboardData';
import getRecentBookings from '@salesforce/apex/CarRentalDashboardController.getRecentBookings';
import { getCarImage, CAR_ASSETS } from './carImageAssets';

const FALLBACK_SVG = 'data:image/svg+xml;utf8,<svg xmlns="http://www.w3.org/2000/svg" width="600" height="360" viewBox="0 0 600 360"><rect width="600" height="360" fill="%230f172a"/><path d="M120 220 L160 140 L440 140 L480 220 Z" fill="%230284c7"/><circle cx="180" cy="230" r="30" fill="%23e2e8f0"/><circle cx="420" cy="230" r="30" fill="%23e2e8f0"/><text x="300" y="300" fill="%2338bdf8" font-size="22" font-family="sans-serif" font-weight="bold" text-anchor="middle">PREMIUM FLEET VEHICLE</text></svg>';

export default class CarRentalDashboard extends NavigationMixin(LightningElement) {
    @track dashboardData = {};
    @track recentBookingsList = [];
    @track topCarsList = [];
    @track error;

    @wire(getDashboardData)
    wiredDashboard({ error, data }) {
        if (data) {
            this.dashboardData = data;
            if (data.topCars) {
                this.topCarsList = data.topCars.map(c => ({
                    ...c,
                    displayImageUrl: getCarImage(c.brand, c.carName)
                }));
            }
            this.error = undefined;
        } else if (error) {
            this.error = error;
            this.dashboardData = {};
        }
    }

    @wire(getRecentBookings)
    wiredBookings({ error, data }) {
        if (data) {
            this.recentBookingsList = data.map(booking => {
                const customerName = booking.Customer__r
                    ? `${booking.Customer__r.First_Name__c || ''} ${booking.Customer__r.Last_Name__c || ''}`.trim()
                    : 'Verified Client';
                const carBrand = booking.Car__r ? (booking.Car__r.Brand__c || '') : '';
                const carModel = booking.Car__r ? (booking.Car__r.Car_Model__c || '') : '';
                const carName = `${carBrand} ${carModel}`.trim() || 'Vehicle';
                const displayImageUrl = getCarImage(carBrand, carModel);

                const startDate = booking.Start_Date__c || '';
                const endDate = booking.End_Date__c || '';
                const dateRange = `${startDate} → ${endDate}`;
                const formattedAmount = booking.Total_Amount__c != null
                    ? `₹${Number(booking.Total_Amount__c).toLocaleString('en-IN')}`
                    : '—';

                let statusBadgeClass = 'dash-status-badge';
                if (booking.Status__c === 'Active') statusBadgeClass += ' st-active';
                else if (booking.Status__c === 'Confirmed') statusBadgeClass += ' st-confirmed';
                else if (booking.Status__c === 'Pending') statusBadgeClass += ' st-pending';
                else if (booking.Status__c === 'Completed') statusBadgeClass += ' st-completed';
                else statusBadgeClass += ' st-cancelled';

                return {
                    ...booking,
                    customerName,
                    carName,
                    displayImageUrl,
                    dateRange,
                    formattedAmount,
                    statusBadgeClass
                };
            });
            this.error = undefined;
        } else if (error) {
            this.error = error;
            this.recentBookingsList = [];
        }
    }

    handleImageError(event) {
        event.target.src = FALLBACK_SVG;
    }

    // Computed Properties
    get activeBookings() { return this.dashboardData.activeBookings || 0; }
    get pendingBookings() { return this.dashboardData.pendingBookings || 0; }
    get availableCars() { return this.dashboardData.availableCars || 0; }
    get bookedCars() { return this.dashboardData.bookedCars || 0; }
    get totalCars() { return this.dashboardData.totalCars || 0; }
    get totalCustomers() { return this.dashboardData.totalCustomers || 0; }
    get fleetUtilization() { return this.dashboardData.fleetUtilization || 0; }

    get formattedTotalRevenue() {
        const val = this.dashboardData.totalRevenue || 0;
        return `₹${Number(val).toLocaleString('en-IN')}`;
    }

    get formattedMonthlyRevenue() {
        const val = this.dashboardData.monthlyRevenue || 0;
        return `₹${Number(val).toLocaleString('en-IN')}`;
    }

    get formattedPendingRevenue() {
        const val = this.dashboardData.pendingRevenue || 0;
        return `₹${Number(val).toLocaleString('en-IN')}`;
    }

    get hasTopCars() {
        return this.topCarsList && this.topCarsList.length > 0;
    }

    get hasBookings() {
        return this.recentBookingsList && this.recentBookingsList.length > 0;
    }

    // Navigation Handlers
    handleNewBooking() {
        this[NavigationMixin.Navigate]({
            type: 'standard__navItemPage',
            attributes: {
                apiName: 'Cars_Fleet_Page'
            }
        });
    }

    handleNewCustomer() {
        this[NavigationMixin.Navigate]({
            type: 'standard__navItemPage',
            attributes: {
                apiName: 'Customers_Hub_Page'
            }
        });
    }

    handleNewCar() {
        this[NavigationMixin.Navigate]({
            type: 'standard__navItemPage',
            attributes: {
                apiName: 'Cars_Fleet_Page'
            }
        });
    }

    handleViewAllBookings() {
        this[NavigationMixin.Navigate]({
            type: 'standard__navItemPage',
            attributes: {
                apiName: 'Bookings_Hub_Page'
            }
        });
    }

    handleBookingClick(event) {
        const bookingId = event.currentTarget.dataset.id;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: bookingId,
                objectApiName: 'Booking__c',
                actionName: 'view'
            }
        });
    }
}
