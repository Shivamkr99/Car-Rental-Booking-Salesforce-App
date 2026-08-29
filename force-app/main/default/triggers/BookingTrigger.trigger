/**
 * BookingTrigger
 * Orchestrates all booking-related automation.
 *
 * Before Insert/Update:
 *   - Calculate total amount from car daily rate × days
 *   - Validate car availability (no overlapping bookings)
 *
 * After Insert:
 *   - Update car status based on booking status
 *
 * After Update:
 *   - Update car status based on booking status changes
 *   - Create payment record when booking is confirmed
 */
trigger BookingTrigger on Booking__c (before insert, before update, after insert, after update) {

    if (Trigger.isBefore) {
        // Calculate total rental amount
        BookingService.calculateTotalAmount(Trigger.new);

        // Validate car availability — prevent double-booking
        BookingService.checkCarAvailability(Trigger.new);
    }

    if (Trigger.isAfter) {
        // Update the Car status (Available ↔ Booked)
        BookingService.updateCarStatus(Trigger.new, Trigger.oldMap);

        // Auto-create Payment when booking is confirmed (after update only)
        if (Trigger.isUpdate) {
            BookingService.createPaymentOnConfirmation(Trigger.new, Trigger.oldMap);
        }
    }
}
