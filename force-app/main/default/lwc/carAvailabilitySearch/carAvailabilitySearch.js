import { LightningElement, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import searchAvailableCars from '@salesforce/apex/CarAvailabilityController.searchAvailableCars';
import getAvailableLocations from '@salesforce/apex/CarAvailabilityController.getAvailableLocations';
import getCarTypes from '@salesforce/apex/CarAvailabilityController.getCarTypes';

/**
 * CarAvailabilitySearch
 * LWC component for searching available cars by location, dates, and type.
 * Displays results as visual car cards with a "Book Now" button.
 */
export default class CarAvailabilitySearch extends NavigationMixin(LightningElement) {
    selectedLocation = '';
    startDate = '';
    endDate = '';
    selectedCarType = '';
    searchResults = [];
    isLoading = false;
    hasSearched = false;
    locationOptions = [];
    carTypeOptions = [];

    // ========================
    // Wire: Get filter options
    // ========================
    @wire(getAvailableLocations)
    wiredLocations({ data }) {
        if (data) {
            this.locationOptions = [
                { label: 'All Locations', value: '' },
                ...data.map(loc => ({ label: loc, value: loc }))
            ];
        }
    }

    @wire(getCarTypes)
    wiredCarTypes({ data }) {
        if (data) {
            this.carTypeOptions = [
                { label: 'All Types', value: '' },
                ...data.map(t => ({ label: t, value: t }))
            ];
        }
    }

    // ========================
    // Event Handlers
    // ========================
    handleLocationChange(event) {
        this.selectedLocation = event.detail.value;
    }

    handleStartDateChange(event) {
        this.startDate = event.detail.value;
    }

    handleEndDateChange(event) {
        this.endDate = event.detail.value;
    }

    handleCarTypeChange(event) {
        this.selectedCarType = event.detail.value;
    }

    handleSearch() {
        this.isLoading = true;
        this.hasSearched = true;

        searchAvailableCars({
            location: this.selectedLocation || null,
            startDate: this.startDate || null,
            endDate: this.endDate || null,
            carType: this.selectedCarType || null
        })
            .then(result => {
                this.searchResults = result.map(car => ({
                    ...car,
                    carDisplayName: `${car.Brand__c || ''} ${car.Car_Model__c || ''}`.trim(),
                    formattedRate: car.Daily_Rental_Rate__c != null
                        ? `₹${Number(car.Daily_Rental_Rate__c).toLocaleString('en-IN')}`
                        : '—'
                }));
                this.isLoading = false;
            })
            .catch(error => {
                console.error('Search error:', error);
                this.searchResults = [];
                this.isLoading = false;
            });
    }

    handleClear() {
        this.selectedLocation = '';
        this.startDate = '';
        this.endDate = '';
        this.selectedCarType = '';
        this.searchResults = [];
        this.hasSearched = false;
    }

    handleBookNow(event) {
        const carId = event.currentTarget.dataset.carId;
        // Navigate to new Booking with car pre-filled
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: {
                objectApiName: 'Booking__c',
                actionName: 'new'
            },
            state: {
                defaultFieldValues: `Car__c=${carId}`
            }
        });
    }

    // ========================
    // Computed Properties
    // ========================
    get hasResults() {
        return this.hasSearched && !this.isLoading && this.searchResults.length > 0;
    }

    get noResults() {
        return this.hasSearched && !this.isLoading && this.searchResults.length === 0;
    }

    get resultCount() {
        return this.searchResults.length;
    }
}
