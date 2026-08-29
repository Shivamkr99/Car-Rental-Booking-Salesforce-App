/**
 * PaymentTrigger
 * When a Payment's status changes, update the linked Booking accordingly.
 *   - Paid → Booking becomes Active
 *   - Refunded → Booking becomes Cancelled
 */
trigger PaymentTrigger on Payment__c (after update) {

    if (Trigger.isAfter && Trigger.isUpdate) {
        PaymentService.updateBookingOnPayment(Trigger.new, Trigger.oldMap);
    }
}
