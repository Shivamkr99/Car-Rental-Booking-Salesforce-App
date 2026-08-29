import { LightningElement, api, wire } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import STATUS_FIELD from '@salesforce/schema/Booking__c.Status__c';

const STEPS = [
    { value: 'Pending', label: 'Pending', index: 1 },
    { value: 'Confirmed', label: 'Confirmed', index: 2 },
    { value: 'Active', label: 'Active', index: 3 },
    { value: 'Completed', label: 'Completed', index: 4 }
];

/**
 * BookingStatusPath
 * Visual progress indicator showing the booking lifecycle.
 * Steps: Pending → Confirmed → Active → Completed
 * Shows a cancelled banner when applicable.
 */
export default class BookingStatusPath extends LightningElement {
    @api recordId;
    currentStatus = '';

    @wire(getRecord, { recordId: '$recordId', fields: [STATUS_FIELD] })
    wiredBooking({ data }) {
        if (data) {
            this.currentStatus = getFieldValue(data, STATUS_FIELD) || 'Pending';
        }
    }

    get statusSteps() {
        const currentIndex = STEPS.findIndex(s => s.value === this.currentStatus);
        const isCancelled = this.currentStatus === 'Cancelled';

        return STEPS.map((step, idx) => {
            let stepClass = 'step';
            const isCompleted = !isCancelled && idx < currentIndex;
            const isCurrent = !isCancelled && idx === currentIndex;

            if (isCompleted) {
                stepClass += ' step-completed';
            } else if (isCurrent) {
                stepClass += ' step-current';
            } else {
                stepClass += ' step-upcoming';
            }

            if (isCancelled) {
                stepClass += ' step-cancelled';
            }

            return {
                ...step,
                stepClass,
                isCompleted,
                isCurrent
            };
        });
    }

    get isCancelled() {
        return this.currentStatus === 'Cancelled';
    }
}
