/**
 * BookingService
 * Core business logic for the Car Rental Booking lifecycle.
 * Handles amount calculation, availability checks, car status updates,
 * and automatic payment record creation.
 */
public inherited sharing class BookingService {

    /**
     * Calculate the total rental amount for bookings.
     * Formula: Daily_Rental_Rate__c × number of rental days.
     * Called from BookingTrigger (before insert/update).
     */
    public static void calculateTotalAmount(List<Booking__c> bookings) {
        // Collect all Car Ids referenced by the bookings
        Set<Id> carIds = new Set<Id>();
        for (Booking__c b : bookings) {
            if (b.Car__c != null) {
                carIds.add(b.Car__c);
            }
        }

        if (carIds.isEmpty()) {
            return;
        }

        // Query Daily Rental Rate from Car records
        Map<Id, Car__c> carMap = new Map<Id, Car__c>(
            [SELECT Id, Daily_Rental_Rate__c FROM Car__c WHERE Id IN :carIds]
        );

        for (Booking__c b : bookings) {
            if (b.Car__c != null && b.Start_Date__c != null && b.End_Date__c != null) {
                Car__c car = carMap.get(b.Car__c);
                if (car != null && car.Daily_Rental_Rate__c != null) {
                    Integer numberOfDays = b.Start_Date__c.daysBetween(b.End_Date__c);
                    if (numberOfDays <= 0) {
                        numberOfDays = 1; // minimum 1 day
                    }
                    b.Total_Amount__c = car.Daily_Rental_Rate__c * numberOfDays;
                }
            }
        }
    }

    /**
     * Validate that no other active/confirmed booking exists for the same car
     * with overlapping dates.
     * Called from BookingTrigger (before insert/update).
     */
    public static void checkCarAvailability(List<Booking__c> bookings) {
        Set<Id> carIds = new Set<Id>();
        for (Booking__c b : bookings) {
            if (b.Car__c != null && b.Status__c != 'Cancelled' && b.Status__c != 'Completed') {
                carIds.add(b.Car__c);
            }
        }

        if (carIds.isEmpty()) {
            return;
        }

        // Query existing active bookings for these cars
        List<Booking__c> existingBookings = [
            SELECT Id, Car__c, Start_Date__c, End_Date__c
            FROM Booking__c
            WHERE Car__c IN :carIds
              AND Status__c NOT IN ('Cancelled', 'Completed')
        ];

        // Build a map of Car Id → list of existing bookings
        Map<Id, List<Booking__c>> carBookingsMap = new Map<Id, List<Booking__c>>();
        for (Booking__c eb : existingBookings) {
            if (!carBookingsMap.containsKey(eb.Car__c)) {
                carBookingsMap.put(eb.Car__c, new List<Booking__c>());
            }
            carBookingsMap.get(eb.Car__c).add(eb);
        }

        for (Booking__c b : bookings) {
            if (b.Car__c == null || b.Status__c == 'Cancelled' || b.Status__c == 'Completed') {
                continue;
            }
            List<Booking__c> carExisting = carBookingsMap.get(b.Car__c);
            if (carExisting == null) {
                continue;
            }
            for (Booking__c eb : carExisting) {
                // Skip comparing with itself (for updates)
                if (eb.Id == b.Id) {
                    continue;
                }
                // Check for date overlap: bookings overlap if
                // newStart < existingEnd AND newEnd > existingStart
                if (b.Start_Date__c < eb.End_Date__c && b.End_Date__c > eb.Start_Date__c) {
                    b.addError(
                        'This car is already booked from ' +
                        eb.Start_Date__c.format() + ' to ' +
                        eb.End_Date__c.format() +
                        '. Please choose different dates or another car.'
                    );
                    break;
                }
            }
        }
    }

    /**
     * Sync Car__c.Status__c based on booking status changes.
     * - Confirmed/Active → Car becomes "Booked"
     * - Completed/Cancelled → Car becomes "Available"
     * Called from BookingTrigger (after insert/update).
     */
    public static void updateCarStatus(List<Booking__c> newBookings, Map<Id, Booking__c> oldMap) {
        Map<Id, String> carStatusUpdates = new Map<Id, String>();

        for (Booking__c b : newBookings) {
            Booking__c oldBooking = (oldMap != null) ? oldMap.get(b.Id) : null;
            String oldStatus = (oldBooking != null) ? oldBooking.Status__c : null;

            // Only process if status actually changed (or is a new insert)
            if (oldStatus == b.Status__c && oldBooking != null) {
                continue;
            }

            if (b.Car__c == null) {
                continue;
            }

            if (b.Status__c == 'Confirmed' || b.Status__c == 'Active') {
                carStatusUpdates.put(b.Car__c, 'Booked');
            } else if (b.Status__c == 'Completed' || b.Status__c == 'Cancelled') {
                carStatusUpdates.put(b.Car__c, 'Available');
            }
        }

        if (!carStatusUpdates.isEmpty()) {
            List<Car__c> carsToUpdate = new List<Car__c>();
            for (Id carId : carStatusUpdates.keySet()) {
                carsToUpdate.add(new Car__c(
                    Id = carId,
                    Status__c = carStatusUpdates.get(carId)
                ));
            }
            update carsToUpdate;
        }
    }

    /**
     * Auto-create a Payment record when a booking is confirmed.
     * Called from BookingTrigger (after update).
     */
    public static void createPaymentOnConfirmation(List<Booking__c> newBookings, Map<Id, Booking__c> oldMap) {
        List<Payment__c> paymentsToCreate = new List<Payment__c>();

        for (Booking__c b : newBookings) {
            Booking__c oldBooking = (oldMap != null) ? oldMap.get(b.Id) : null;
            String oldStatus = (oldBooking != null) ? oldBooking.Status__c : null;

            // Only create payment when status changes TO Confirmed
            if (b.Status__c == 'Confirmed' && oldStatus != 'Confirmed') {
                paymentsToCreate.add(new Payment__c(
                    Booking__c = b.Id,
                    Amount__c = b.Total_Amount__c,
                    Payment_Status__c = 'Pending',
                    Payment_Date__c = Date.today()
                ));
            }
        }

        if (!paymentsToCreate.isEmpty()) {
            insert paymentsToCreate;
        }
    }
}
