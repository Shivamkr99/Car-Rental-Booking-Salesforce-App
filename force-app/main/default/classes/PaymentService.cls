/**
 * PaymentService
 * Handles payment-related business logic.
 * When a Payment is marked as "Paid", the associated Booking
 * is updated to "Active" status.
 */
public inherited sharing class PaymentService {

    /**
     * Update booking status to "Active" when payment is marked "Paid".
     * Handle refund scenario: if payment is "Refunded", set booking to "Cancelled".
     * Called from PaymentTrigger (after update).
     */
    public static void updateBookingOnPayment(List<Payment__c> newPayments, Map<Id, Payment__c> oldMap) {
        List<Booking__c> bookingsToUpdate = new List<Booking__c>();

        for (Payment__c p : newPayments) {
            Payment__c oldPayment = (oldMap != null) ? oldMap.get(p.Id) : null;
            String oldStatus = (oldPayment != null) ? oldPayment.Payment_Status__c : null;

            if (p.Booking__c == null) {
                continue;
            }

            // Payment status changed TO "Paid"
            if (p.Payment_Status__c == 'Paid' && oldStatus != 'Paid') {
                bookingsToUpdate.add(new Booking__c(
                    Id = p.Booking__c,
                    Status__c = 'Active'
                ));
            }

            // Payment status changed TO "Refunded" → cancel the booking
            if (p.Payment_Status__c == 'Refunded' && oldStatus != 'Refunded') {
                bookingsToUpdate.add(new Booking__c(
                    Id = p.Booking__c,
                    Status__c = 'Cancelled'
                ));
            }
        }

        if (!bookingsToUpdate.isEmpty()) {
            update bookingsToUpdate;
        }
    }
}
