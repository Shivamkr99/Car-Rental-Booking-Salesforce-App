import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getReviewsSummary from '@salesforce/apex/ReviewsHubController.getReviewsSummary';
import getReviews from '@salesforce/apex/ReviewsHubController.getReviews';
import submitReview from '@salesforce/apex/ReviewsHubController.submitReview';
import getFleetCars from '@salesforce/apex/CarFleetController.getFleetCars';
import getCustomers from '@salesforce/apex/CustomerHubController.getCustomers';
import { getCarImage, CAR_ASSETS } from './carImageAssets';

const FALLBACK_SVG = 'data:image/svg+xml;utf8,<svg xmlns="http://www.w3.org/2000/svg" width="600" height="360" viewBox="0 0 600 360"><rect width="600" height="360" fill="%230f172a"/><path d="M120 220 L160 140 L440 140 L480 220 Z" fill="%230284c7"/><circle cx="180" cy="230" r="30" fill="%23e2e8f0"/><circle cx="420" cy="230" r="30" fill="%23e2e8f0"/><text x="300" y="300" fill="%2338bdf8" font-size="22" font-family="sans-serif" font-weight="bold" text-anchor="middle">PREMIUM FLEET VEHICLE</text></svg>';

export default class ReviewsHub extends LightningElement {
    @track searchKey = '';
    @track ratingFilter = 'All';
    @track reviewsList = [];
    @track summary = { averageRating: 5.0, totalReviews: 0, fiveStarCount: 0, fourStarCount: 0, threeStarCount: 0, twoStarCount: 0, oneStarCount: 0, fiveStarPercent: 0, fourStarPercent: 0, threeStarPercent: 0, twoStarPercent: 0, oneStarPercent: 0 };
    @track isLoading = true;

    ratingFilterOptions = [
        { label: 'All Ratings', value: 'All' },
        { label: '5 Stars ★★★★★', value: '5' },
        { label: '4 Stars ★★★★☆', value: '4' },
        { label: '3 Stars ★★★☆☆', value: '3' },
        { label: '2 Stars ★★☆☆☆', value: '2' },
        { label: '1 Star ★☆☆☆☆', value: '1' }
    ];

    ratingOptions = [
        { label: '5 Stars - Excellent (★★★★★)', value: '5' },
        { label: '4 Stars - Very Good (★★★★☆)', value: '4' },
        { label: '3 Stars - Average (★★★☆☆)', value: '3' },
        { label: '2 Stars - Poor (★★☆☆☆)', value: '2' },
        { label: '1 Star - Terrible (★☆☆☆☆)', value: '1' }
    ];

    // New Review Modal
    @track isNewReviewModalOpen = false;
    @track carOptions = [];
    @track customerOptions = [];
    @track newRevCarId = '';
    @track newRevCustId = '';
    @track newRevRating = '5';
    @track newRevDate = '';
    @track newRevComment = '';
    @track isSubmitting = false;

    connectedCallback() {
        this.fetchData();
        this.fetchDropdowns();
        this.newRevDate = this.formatDate(new Date());
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
            getReviewsSummary({ carId: null }),
            getReviews({ carId: null, ratingFilter: this.ratingFilter, searchKey: this.searchKey })
        ])
            .then(([sumData, reviews]) => {
                this.summary = sumData;
                this.reviewsList = reviews.map(r => {
                    const stars = '★'.repeat(r.numericRating || 5) + '☆'.repeat(5 - (r.numericRating || 5));
                    const displayImageUrl = getCarImage('', r.carName);
                    return {
                        ...r,
                        displayImageUrl,
                        starDisplay: stars
                    };
                });
                this.isLoading = false;
            })
            .catch(error => {
                console.error('Error fetching reviews:', error);
                this.reviewsList = [];
                this.isLoading = false;
            });
    }

    handleImageError(event) {
        event.target.src = FALLBACK_SVG;
    }

    handleSearchChange(e) {
        this.searchKey = e.target.value;
        this.fetchData();
    }

    handleRatingFilterChange(e) {
        this.ratingFilter = e.detail.value;
        this.fetchData();
    }

    handleResetFilters() {
        this.searchKey = '';
        this.ratingFilter = 'All';
        this.fetchData();
    }

    // Dynamic Progress Bar Styles
    get fiveStarStyle() { return `width: ${this.summary.fiveStarPercent || 0}%;`; }
    get fourStarStyle() { return `width: ${this.summary.fourStarPercent || 0}%;`; }
    get threeStarStyle() { return `width: ${this.summary.threeStarPercent || 0}%;`; }
    get twoStarStyle() { return `width: ${this.summary.twoStarPercent || 0}%;`; }
    get oneStarStyle() { return `width: ${this.summary.oneStarPercent || 0}%;`; }

    get hasReviews() {
        return this.reviewsList && this.reviewsList.length > 0;
    }

    fetchDropdowns() {
        getFleetCars({ searchKey: '', brand: 'All', carType: 'All', status: 'All', fuelType: 'All', transmission: 'All' })
            .then(cars => {
                if (cars && cars.length > 0) {
                    this.carOptions = cars.map(c => ({ label: `${c.brand} ${c.carModel}`, value: c.id }));
                    this.newRevCarId = cars[0].id;
                }
            })
            .catch(err => console.error('Cars dropdown error:', err));

        getCustomers({ searchKey: '', licenseStatusFilter: 'All' })
            .then(custs => {
                if (custs && custs.length > 0) {
                    this.customerOptions = custs.map(c => ({ label: c.fullName, value: c.id }));
                    this.newRevCustId = custs[0].id;
                }
            })
            .catch(err => console.error('Customers dropdown error:', err));
    }

    handleOpenNewReviewModal() {
        this.isNewReviewModalOpen = true;
    }

    handleCloseNewReviewModal() {
        this.isNewReviewModalOpen = false;
    }

    handleRevCarChange(e) { this.newRevCarId = e.detail.value; }
    handleRevCustChange(e) { this.newRevCustId = e.detail.value; }
    handleRevRatingChange(e) { this.newRevRating = e.detail.value; }
    handleRevDateChange(e) { this.newRevDate = e.target.value; }
    handleRevCommentChange(e) { this.newRevComment = e.target.value; }

    async handleSubmitReview() {
        if (!this.newRevCarId || !this.newRevRating) {
            this.showToast('Validation Error', 'Car and Rating are required.', 'error');
            return;
        }

        this.isSubmitting = true;
        try {
            await submitReview({
                review: {
                    Car__c: this.newRevCarId,
                    Customer__c: this.newRevCustId || null,
                    Rating__c: Number(this.newRevRating),
                    Comment__c: this.newRevComment,
                    Review_Date__c: this.newRevDate
                }
            });

            this.showToast('Review Added!', 'Customer review recorded and vehicle score updated.', 'success');
            this.handleCloseNewReviewModal();
            this.fetchData();
        } catch (error) {
            console.error('Error submitting review:', error);
            this.showToast('Error', 'Failed to submit review.', 'error');
        } finally {
            this.isSubmitting = false;
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
