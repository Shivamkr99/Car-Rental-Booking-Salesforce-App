import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getFleetCars from '@salesforce/apex/CarFleetController.getFleetCars';
import getFleetFilterOptions from '@salesforce/apex/CarFleetController.getFleetFilterOptions';
import createInstantBooking from '@salesforce/apex/CarFleetController.createInstantBooking';
import saveCarRecord from '@salesforce/apex/CarFleetController.saveCarRecord';
import getCustomers from '@salesforce/apex/CustomerHubController.getCustomers';
import saveCustomerRecord from '@salesforce/apex/CustomerHubController.saveCustomerRecord';
import { getCarImage, CAR_ASSETS } from './carImageAssets';

const DEFAULT_CAR_IMAGES = {
    'Toyota Fortuner': 'https://upload.wikimedia.org/wikipedia/commons/thumb/6/66/2015_Toyota_Fortuner_%28New_Zealand%29.jpg/800px-2015_Toyota_Fortuner_%28New_Zealand%29.jpg',
    'Toyota Innova Crysta': 'https://upload.wikimedia.org/wikipedia/commons/thumb/9/91/2016_Toyota_Innova_2.4_V_wagon_%28GUN142R%2C_Indonesia%29_front_view.jpg/800px-2016_Toyota_Innova_2.4_V_wagon_%28GUN142R%2C_Indonesia%29_front_view.jpg',
    'Toyota Corolla': 'https://upload.wikimedia.org/wikipedia/commons/thumb/c/ca/2019_Toyota_Corolla_Icon_Tech_HEV_1.8_Front.jpg/800px-2019_Toyota_Corolla_Icon_Tech_HEV_1.8_Front.jpg',
    'Honda City': 'https://upload.wikimedia.org/wikipedia/commons/thumb/f/f6/2020_Honda_City_1.0_VTEC_Turbo_SV_%28Thailand%29_front_view.jpg/800px-2020_Honda_City_1.0_VTEC_Turbo_SV_%28Thailand%29_front_view.jpg',
    'Honda Amaze': 'https://upload.wikimedia.org/wikipedia/commons/thumb/3/30/2018_Honda_Amaze_V_i-DTEC_%28India%29_front_view.jpg/800px-2018_Honda_Amaze_V_i-DTEC_%28India%29_front_view.jpg',
    'Kia Seltos': 'https://upload.wikimedia.org/wikipedia/commons/thumb/1/1d/2021_Kia_Seltos_EX_AWD%2C_front_10.22.21.jpg/800px-2021_Kia_Seltos_EX_AWD%2C_front_10.22.21.jpg',
    'Mahindra XUV700': 'https://upload.wikimedia.org/wikipedia/commons/thumb/8/87/2021_Mahindra_XUV700_AX7_Luxury_Pack_%28India%29_front_view.jpg/800px-2021_Mahindra_XUV700_AX7_Luxury_Pack_%28India%29_front_view.jpg',
    'Hyundai Creta': 'https://upload.wikimedia.org/wikipedia/commons/thumb/2/29/2020_Hyundai_Creta_SX_%28India%29_front_view.jpg/800px-2020_Hyundai_Creta_SX_%28India%29_front_view.jpg',
    'Tata Nexon': 'https://upload.wikimedia.org/wikipedia/commons/thumb/1/1a/2020_Tata_Nexon_XZ%2B_%28India%29_front_view.jpg/800px-2020_Tata_Nexon_XZ%2B_%28India%29_front_view.jpg',
    'Maruti Swift': 'https://upload.wikimedia.org/wikipedia/commons/thumb/6/6e/2018_Suzuki_Swift_SZ5_Boosterjet_SHVS_1.0_Front.jpg/800px-2018_Suzuki_Swift_SZ5_Boosterjet_SHVS_1.0_Front.jpg',
    'default': 'https://upload.wikimedia.org/wikipedia/commons/thumb/c/ca/2019_Toyota_Corolla_Icon_Tech_HEV_1.8_Front.jpg/800px-2019_Toyota_Corolla_Icon_Tech_HEV_1.8_Front.jpg'
};

const FALLBACK_SVG = 'data:image/svg+xml;utf8,<svg xmlns="http://www.w3.org/2000/svg" width="600" height="360" viewBox="0 0 600 360"><rect width="600" height="360" fill="%230f172a"/><path d="M120 220 L160 140 L440 140 L480 220 Z" fill="%230284c7"/><circle cx="180" cy="230" r="30" fill="%23e2e8f0"/><circle cx="420" cy="230" r="30" fill="%23e2e8f0"/><text x="300" y="300" fill="%2338bdf8" font-size="22" font-family="sans-serif" font-weight="bold" text-anchor="middle">PREMIUM FLEET VEHICLE</text></svg>';

export default class CarFleetExplorer extends LightningElement {
    @track searchKey = '';
    @track selectedBrand = 'All';
    @track selectedCarType = 'All';
    @track selectedStatus = 'All';

    @track fleetCars = [];
    @track isLoading = true;

    // Filters
    @track brandOptions = [{ label: 'All Brands', value: 'All' }];
    @track carTypeOptions = [{ label: 'All Types', value: 'All' }];
    @track statusOptions = [
        { label: 'All Statuses', value: 'All' },
        { label: 'Available', value: 'Available' },
        { label: 'Booked', value: 'Booked' },
        { label: 'Maintenance', value: 'Maintenance' }
    ];

    // Customer options
    @track customerOptions = [];

    // Modals
    @track isBookingModalOpen = false;
    @track isDetailsModalOpen = false;
    @track isAddCarModalOpen = false;

    // Selected Car for Booking
    @track selectedCarForBooking = {};
    @track isCreatingNewCustomer = false;
    @track bookingCustomerId = '';
    @track newCustFirstName = '';
    @track newCustLastName = '';
    @track newCustEmail = '';
    @track newCustPhone = '';
    @track newCustLicense = '';
    @track bookingStartDate = '';
    @track bookingEndDate = '';
    @track bookingPickupLocation = '';
    @track bookingReturnLocation = '';
    @track bookingNotes = '';
    @track bookingIsPaid = true;
    @track bookingPaymentMethod = 'UPI';
    @track isSubmittingBooking = false;

    // Selected Car for Details
    @track selectedCarDetails = {};

    // Add Car Form
    @track newCarBrand = '';
    @track newCarModel = '';
    @track newCarType = 'SUV';
    @track newCarRate = 2500;
    @track newCarReg = '';
    @track newCarTransmission = 'Automatic';
    @track newCarFuel = 'Petrol';
    @track newCarSeats = 5;
    @track newCarLocation = 'Mumbai';
    @track newCarImageUrl = '';
    @track newCarDesc = '';

    paymentMethodOptions = [
        { label: 'UPI (Google Pay / PhonePe)', value: 'UPI' },
        { label: 'Credit / Debit Card', value: 'Credit Card' },
        { label: 'Cash on Delivery', value: 'Cash' },
        { label: 'Bank Transfer / NetBanking', value: 'Bank Transfer' }
    ];

    carTypeOptionsOnly = [
        { label: 'SUV', value: 'SUV' },
        { label: 'Sedan', value: 'Sedan' },
        { label: 'Hatchback', value: 'Hatchback' },
        { label: 'Luxury', value: 'Luxury' }
    ];

    transmissionOptions = [
        { label: 'Automatic', value: 'Automatic' },
        { label: 'Manual', value: 'Manual' }
    ];

    fuelOptions = [
        { label: 'Petrol', value: 'Petrol' },
        { label: 'Diesel', value: 'Diesel' },
        { label: 'Electric', value: 'Electric' },
        { label: 'Hybrid', value: 'Hybrid' }
    ];

    connectedCallback() {
        this.fetchFleet();
        this.fetchFilterOptions();
        this.fetchCustomersList();

        // Default booking dates
        const today = new Date();
        const tomorrow = new Date(today);
        tomorrow.setDate(tomorrow.getDate() + 1);
        const nextWeek = new Date(today);
        nextWeek.setDate(nextWeek.getDate() + 4);

        this.bookingStartDate = this.formatDate(tomorrow);
        this.bookingEndDate = this.formatDate(nextWeek);
    }

    formatDate(d) {
        const year = d.getFullYear();
        const month = String(d.getMonth() + 1).padStart(2, '0');
        const day = String(d.getDate()).padStart(2, '0');
        return `${year}-${month}-${day}`;
    }

    fetchFleet() {
        this.isLoading = true;
        getFleetCars({
            searchKey: this.searchKey,
            brand: this.selectedBrand,
            carType: this.selectedCarType,
            status: this.selectedStatus,
            fuelType: 'All',
            transmission: 'All'
        })
            .then(data => {
                this.fleetCars = data.map(c => {
                    const displayName = `${c.brand || ''} ${c.carModel || ''}`.trim();
                    const displayImageUrl = getCarImage(c.brand, c.carModel);
                    const formattedRate = c.dailyRate != null ? `₹${Number(c.dailyRate).toLocaleString('en-IN')}` : '₹2,000';
                    const isAvailable = c.status === 'Available';

                    let statusBadgeClass = 'status-badge';
                    if (c.status === 'Available') statusBadgeClass += ' status-avail';
                    else if (c.status === 'Booked') statusBadgeClass += ' status-booked';
                    else statusBadgeClass += ' status-maint';

                    return {
                        ...c,
                        displayName,
                        displayImageUrl,
                        formattedRate,
                        isAvailable,
                        statusBadgeClass
                    };
                });
                this.isLoading = false;
            })
            .catch(error => {
                console.error('Error fetching fleet:', error);
                this.fleetCars = [];
                this.isLoading = false;
            });
    }

    handleImageError(event) {
        event.target.src = FALLBACK_SVG;
    }

    fetchFilterOptions() {
        getFleetFilterOptions()
            .then(data => {
                if (data) {
                    if (data.brands) {
                        this.brandOptions = [
                            { label: 'All Brands', value: 'All' },
                            ...data.brands.map(b => ({ label: b, value: b }))
                        ];
                    }
                    if (data.types) {
                        this.carTypeOptions = [
                            { label: 'All Types', value: 'All' },
                            ...data.types.map(t => ({ label: t, value: t }))
                        ];
                    }
                }
            })
            .catch(err => console.error('Filter options error:', err));
    }

    fetchCustomersList() {
        getCustomers({ searchKey: '', licenseStatusFilter: 'All' })
            .then(data => {
                if (data && data.length > 0) {
                    this.customerOptions = data.map(c => ({
                        label: `${c.fullName} (${c.phone || c.email}) - Lic: ${c.licenseNumber || 'N/A'}`,
                        value: c.id
                    }));
                    if (!this.bookingCustomerId) {
                        this.bookingCustomerId = data[0].id;
                    }
                }
            })
            .catch(err => console.error('Customer list error:', err));
    }

    // Filter Handlers
    handleSearchChange(e) {
        this.searchKey = e.target.value;
        this.fetchFleet();
    }

    handleBrandChange(e) {
        this.selectedBrand = e.detail.value;
        this.fetchFleet();
    }

    handleCarTypeChange(e) {
        this.selectedCarType = e.detail.value;
        this.fetchFleet();
    }

    handleStatusChange(e) {
        this.selectedStatus = e.detail.value;
        this.fetchFleet();
    }

    handleResetFilters() {
        this.searchKey = '';
        this.selectedBrand = 'All';
        this.selectedCarType = 'All';
        this.selectedStatus = 'All';
        this.fetchFleet();
    }

    // Computed Stats
    get totalCarsCount() {
        return this.fleetCars.length;
    }

    get availableCarsCount() {
        return this.fleetCars.filter(c => c.status === 'Available').length;
    }

    get bookedCarsCount() {
        return this.fleetCars.filter(c => c.status === 'Booked').length;
    }

    get avgDailyRate() {
        if (!this.fleetCars || this.fleetCars.length === 0) return '₹0';
        const sum = this.fleetCars.reduce((acc, c) => acc + (c.dailyRate || 0), 0);
        const avg = Math.round(sum / this.fleetCars.length);
        return `₹${avg.toLocaleString('en-IN')}`;
    }

    get hasCars() {
        return this.fleetCars && this.fleetCars.length > 0;
    }

    // Booking Handlers
    handleOpenBookingModal(e) {
        const carId = e.target.dataset.id;
        const car = this.fleetCars.find(c => c.id === carId);
        if (car) {
            this.selectedCarForBooking = car;
            this.bookingPickupLocation = car.location || 'Mumbai';
            this.bookingReturnLocation = car.location || 'Mumbai';
            this.isBookingModalOpen = true;
        }
    }

    handleCloseBookingModal() {
        this.isBookingModalOpen = false;
        this.isCreatingNewCustomer = false;
    }

    handleToggleNewCustomer() {
        this.isCreatingNewCustomer = !this.isCreatingNewCustomer;
    }

    get customerToggleLabel() {
        return this.isCreatingNewCustomer ? '← Choose Existing Customer' : '+ Add New Customer';
    }

    handleBookingCustomerChange(e) { this.bookingCustomerId = e.detail.value; }
    handleNewCustFirstChange(e) { this.newCustFirstName = e.target.value; }
    handleNewCustLastChange(e) { this.newCustLastName = e.target.value; }
    handleNewCustEmailChange(e) { this.newCustEmail = e.target.value; }
    handleNewCustPhoneChange(e) { this.newCustPhone = e.target.value; }
    handleNewCustLicenseChange(e) { this.newCustLicense = e.target.value; }

    handleBookingStartChange(e) { this.bookingStartDate = e.target.value; }
    handleBookingEndChange(e) { this.bookingEndDate = e.target.value; }
    handleBookingPickupChange(e) { this.bookingPickupLocation = e.target.value; }
    handleBookingReturnChange(e) { this.bookingReturnLocation = e.target.value; }
    handleBookingNotesChange(e) { this.bookingNotes = e.target.value; }
    handleBookingIsPaidChange(e) { this.bookingIsPaid = e.target.checked; }
    handleBookingPaymentMethodChange(e) { this.bookingPaymentMethod = e.detail.value; }

    get calculatedDurationDays() {
        if (!this.bookingStartDate || !this.bookingEndDate) return 1;
        const start = new Date(this.bookingStartDate);
        const end = new Date(this.bookingEndDate);
        const diffTime = Math.abs(end - start);
        const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24));
        return diffDays > 0 ? diffDays : 1;
    }

    get formattedCalculatedTotal() {
        const rate = this.selectedCarForBooking.dailyRate || 2000;
        const total = rate * this.calculatedDurationDays;
        return `₹${total.toLocaleString('en-IN')}`;
    }

    async handleSubmitBooking() {
        this.isSubmittingBooking = true;
        try {
            let customerIdToUse = this.bookingCustomerId;

            // If creating new customer first
            if (this.isCreatingNewCustomer) {
                if (!this.newCustLastName || !this.newCustEmail || !this.newCustLicense) {
                    this.showToast('Validation Error', 'Last Name, Email, and Driver License are required for new customer.', 'error');
                    this.isSubmittingBooking = false;
                    return;
                }

                const newCust = await saveCustomerRecord({
                    customer: {
                        First_Name__c: this.newCustFirstName,
                        Last_Name__c: this.newCustLastName,
                        Email__c: this.newCustEmail,
                        Phone__c: this.newCustPhone,
                        Driving_License_Number__c: this.newCustLicense,
                        Active__c: true
                    }
                });
                customerIdToUse = newCust.Id;
                this.fetchCustomersList();
            }

            if (!customerIdToUse) {
                this.showToast('Customer Required', 'Please select or create a customer to proceed.', 'error');
                this.isSubmittingBooking = false;
                return;
            }

            const booking = await createInstantBooking({
                carId: this.selectedCarForBooking.id,
                customerId: customerIdToUse,
                startDate: this.bookingStartDate,
                endDate: this.bookingEndDate,
                pickupLocation: this.bookingPickupLocation,
                returnLocation: this.bookingReturnLocation,
                bookingType: 'Short Term',
                notes: this.bookingNotes,
                isPaid: this.bookingIsPaid,
                paymentMethod: this.bookingPaymentMethod
            });

            this.showToast('Booking Confirmed! 🎉', `Booking ${booking.Name} created successfully for ${this.selectedCarForBooking.displayName}.`, 'success');
            this.handleCloseBookingModal();
            this.fetchFleet();
        } catch (error) {
            console.error('Booking submission error:', error);
            const msg = error.body && error.body.message ? error.body.message : 'An error occurred while creating booking.';
            this.showToast('Booking Failed', msg, 'error');
        } finally {
            this.isSubmittingBooking = false;
        }
    }

    // Car Details Modal
    handleOpenDetailsModal(e) {
        const carId = e.target.dataset.id;
        const car = this.fleetCars.find(c => c.id === carId);
        if (car) {
            this.selectedCarDetails = car;
            this.isDetailsModalOpen = true;
        }
    }

    handleCloseDetailsModal() {
        this.isDetailsModalOpen = false;
    }

    handleOpenBookingFromDetails() {
        this.selectedCarForBooking = this.selectedCarDetails;
        this.bookingPickupLocation = this.selectedCarDetails.location || 'Mumbai';
        this.bookingReturnLocation = this.selectedCarDetails.location || 'Mumbai';
        this.isDetailsModalOpen = false;
        this.isBookingModalOpen = true;
    }

    // Add Car Modal
    handleOpenAddCarModal() {
        this.isAddCarModalOpen = true;
    }

    handleCloseAddCarModal() {
        this.isAddCarModalOpen = false;
    }

    handleNewCarBrandChange(e) { this.newCarBrand = e.target.value; }
    handleNewCarModelChange(e) { this.newCarModel = e.target.value; }
    handleNewCarTypeChange(e) { this.newCarType = e.detail.value; }
    handleNewCarRateChange(e) { this.newCarRate = e.target.value; }
    handleNewCarRegChange(e) { this.newCarReg = e.target.value; }
    handleNewCarTransChange(e) { this.newCarTransmission = e.detail.value; }
    handleNewCarFuelChange(e) { this.newCarFuel = e.detail.value; }
    handleNewCarSeatsChange(e) { this.newCarSeats = e.target.value; }
    handleNewCarLocationChange(e) { this.newCarLocation = e.target.value; }
    handleNewCarImageChange(e) { this.newCarImageUrl = e.target.value; }
    handleNewCarDescChange(e) { this.newCarDesc = e.target.value; }

    async handleSubmitAddCar() {
        if (!this.newCarBrand || !this.newCarModel || !this.newCarRate) {
            this.showToast('Validation Error', 'Brand, Model, and Daily Rate are required.', 'error');
            return;
        }

        try {
            await saveCarRecord({
                car: {
                    Brand__c: this.newCarBrand,
                    Car_Model__c: this.newCarModel,
                    Car_Type__c: this.newCarType,
                    Daily_Rental_Rate__c: Number(this.newCarRate),
                    Registration_Number__c: this.newCarReg,
                    Transmission__c: this.newCarTransmission,
                    Fuel_Type__c: this.newCarFuel,
                    Seats__c: Number(this.newCarSeats),
                    Location__c: this.newCarLocation,
                    Car_Image_URL__c: this.newCarImageUrl,
                    Description__c: this.newCarDesc,
                    Status__c: 'Available',
                    Active__c: true
                }
            });

            this.showToast('Success', `Vehicle ${this.newCarBrand} ${this.newCarModel} added to fleet!`, 'success');
            this.handleCloseAddCarModal();
            this.fetchFleet();
        } catch (error) {
            console.error('Error adding car:', error);
            this.showToast('Error', 'Failed to add vehicle to fleet.', 'error');
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
