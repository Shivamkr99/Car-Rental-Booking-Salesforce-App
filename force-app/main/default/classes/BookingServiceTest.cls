/**
 * BookingServiceTest
 * Test class for BookingService and BookingTrigger.
 * Covers: amount calculation, car availability conflicts,
 * car status updates, and payment auto-creation.
 */
@isTest
private class BookingServiceTest {

    /**
     * Create test data: customers, cars, and optionally bookings.
     */
    @TestSetup
    static void setupTestData() {
        // Create test customers
        Customer__c customer = new Customer__c(
            First_Name__c = 'Test',
            Last_Name__c = 'Customer',
            Email__c = 'test@example.com',
            Phone__c = '9876543210',
            Driving_License_Number__c = 'DL-TEST-001',
            License_Expiry_Date__c = Date.today().addYears(2)
        );
        insert customer;

        // Create test cars
        List<Car__c> cars = new List<Car__c>();
        cars.add(new Car__c(
            Brand__c = 'Toyota',
            Car_Model__c = 'Camry',
            Car_Type__c = 'Sedan',
            Daily_Rental_Rate__c = 2000,
            Status__c = 'Available',
            Active__c = true,
            Location__c = 'Delhi',
            Fuel_Type__c = 'Petrol',
            Transmission__c = 'Automatic',
            Seats__c = 5,
            Registration_Number__c = 'DL-01-AB-1234'
        ));
        cars.add(new Car__c(
            Brand__c = 'Honda',
            Car_Model__c = 'City',
            Car_Type__c = 'Sedan',
            Daily_Rental_Rate__c = 1500,
            Status__c = 'Available',
            Active__c = true,
            Location__c = 'Mumbai',
            Fuel_Type__c = 'Diesel',
            Transmission__c = 'Manual',
            Seats__c = 5,
            Registration_Number__c = 'MH-01-CD-5678'
        ));
        insert cars;
    }

    /**
     * Test: Total amount is correctly calculated on booking creation.
     * 5 days × ₹2000/day = ₹10,000
     */
    @isTest
    static void testTotalAmountCalculation() {
        Customer__c cust = [SELECT Id FROM Customer__c LIMIT 1];
        Car__c car = [SELECT Id, Daily_Rental_Rate__c FROM Car__c WHERE Brand__c = 'Toyota' LIMIT 1];

        Test.startTest();
        Booking__c booking = new Booking__c(
            Customer__c = cust.Id,
            Car__c = car.Id,
            Start_Date__c = Date.today().addDays(1),
            End_Date__c = Date.today().addDays(6),
            Pickup_Location__c = 'Delhi',
            Return_Location__c = 'Delhi',
            Booking_Type__c = 'Short Term'
        );
        insert booking;
        Test.stopTest();

        booking = [SELECT Total_Amount__c FROM Booking__c WHERE Id = :booking.Id];
        // 5 days × 2000 = 10000
        System.assertEquals(10000, booking.Total_Amount__c,
            'Total amount should be 5 days × ₹2000 = ₹10,000');
    }

    /**
     * Test: Double-booking the same car for overlapping dates is blocked.
     */
    @isTest
    static void testCarAvailabilityConflict() {
        Customer__c cust = [SELECT Id FROM Customer__c LIMIT 1];
        Car__c car = [SELECT Id FROM Car__c WHERE Brand__c = 'Toyota' LIMIT 1];

        // Create first booking
        Booking__c booking1 = new Booking__c(
            Customer__c = cust.Id,
            Car__c = car.Id,
            Start_Date__c = Date.today().addDays(10),
            End_Date__c = Date.today().addDays(15),
            Pickup_Location__c = 'Delhi',
            Return_Location__c = 'Delhi',
            Booking_Type__c = 'Short Term'
        );
        insert booking1;

        // Try to create overlapping booking
        Test.startTest();
        Boolean errorOccurred = false;
        try {
            Booking__c booking2 = new Booking__c(
                Customer__c = cust.Id,
                Car__c = car.Id,
                Start_Date__c = Date.today().addDays(12),
                End_Date__c = Date.today().addDays(18),
                Pickup_Location__c = 'Delhi',
                Return_Location__c = 'Delhi',
                Booking_Type__c = 'Short Term'
            );
            insert booking2;
        } catch (DmlException e) {
            errorOccurred = true;
            System.assert(e.getMessage().contains('already booked'),
                'Error message should mention the car is already booked');
        }
        Test.stopTest();

        System.assert(errorOccurred, 'Overlapping booking should be rejected');
    }

    /**
     * Test: Non-overlapping booking for the same car succeeds.
     */
    @isTest
    static void testNonOverlappingBookingSucceeds() {
        Customer__c cust = [SELECT Id FROM Customer__c LIMIT 1];
        Car__c car = [SELECT Id FROM Car__c WHERE Brand__c = 'Toyota' LIMIT 1];

        Booking__c booking1 = new Booking__c(
            Customer__c = cust.Id,
            Car__c = car.Id,
            Start_Date__c = Date.today().addDays(1),
            End_Date__c = Date.today().addDays(5),
            Pickup_Location__c = 'Delhi',
            Return_Location__c = 'Delhi',
            Booking_Type__c = 'Short Term'
        );
        insert booking1;

        Test.startTest();
        Booking__c booking2 = new Booking__c(
            Customer__c = cust.Id,
            Car__c = car.Id,
            Start_Date__c = Date.today().addDays(6),
            End_Date__c = Date.today().addDays(10),
            Pickup_Location__c = 'Delhi',
            Return_Location__c = 'Delhi',
            Booking_Type__c = 'Short Term'
        );
        insert booking2;
        Test.stopTest();

        // Both bookings should exist
        Integer count = [SELECT COUNT() FROM Booking__c WHERE Car__c = :car.Id];
        System.assertEquals(2, count, 'Non-overlapping bookings should both be created');
    }

    /**
     * Test: Car status changes to "Booked" when booking is confirmed.
     */
    @isTest
    static void testCarStatusUpdatedOnConfirmation() {
        Customer__c cust = [SELECT Id FROM Customer__c LIMIT 1];
        Car__c car = [SELECT Id FROM Car__c WHERE Brand__c = 'Toyota' LIMIT 1];

        Booking__c booking = new Booking__c(
            Customer__c = cust.Id,
            Car__c = car.Id,
            Start_Date__c = Date.today().addDays(1),
            End_Date__c = Date.today().addDays(5),
            Pickup_Location__c = 'Delhi',
            Return_Location__c = 'Delhi',
            Booking_Type__c = 'Short Term'
        );
        insert booking;

        Test.startTest();
        booking.Status__c = 'Confirmed';
        update booking;
        Test.stopTest();

        car = [SELECT Status__c FROM Car__c WHERE Id = :car.Id];
        System.assertEquals('Booked', car.Status__c,
            'Car status should be Booked after booking confirmation');
    }

    /**
     * Test: Car status changes back to "Available" when booking is completed.
     */
    @isTest
    static void testCarStatusResetOnCompletion() {
        Customer__c cust = [SELECT Id FROM Customer__c LIMIT 1];
        Car__c car = [SELECT Id FROM Car__c WHERE Brand__c = 'Toyota' LIMIT 1];

        Booking__c booking = new Booking__c(
            Customer__c = cust.Id,
            Car__c = car.Id,
            Start_Date__c = Date.today().addDays(1),
            End_Date__c = Date.today().addDays(5),
            Pickup_Location__c = 'Delhi',
            Return_Location__c = 'Delhi',
            Booking_Type__c = 'Short Term'
        );
        insert booking;

        booking.Status__c = 'Confirmed';
        update booking;

        Test.startTest();
        booking.Status__c = 'Completed';
        update booking;
        Test.stopTest();

        car = [SELECT Status__c FROM Car__c WHERE Id = :car.Id];
        System.assertEquals('Available', car.Status__c,
            'Car status should be Available after booking completion');
    }

    /**
     * Test: Payment record is auto-created when booking is confirmed.
     */
    @isTest
    static void testPaymentCreatedOnConfirmation() {
        Customer__c cust = [SELECT Id FROM Customer__c LIMIT 1];
        Car__c car = [SELECT Id FROM Car__c WHERE Brand__c = 'Toyota' LIMIT 1];

        Booking__c booking = new Booking__c(
            Customer__c = cust.Id,
            Car__c = car.Id,
            Start_Date__c = Date.today().addDays(1),
            End_Date__c = Date.today().addDays(5),
            Pickup_Location__c = 'Delhi',
            Return_Location__c = 'Delhi',
            Booking_Type__c = 'Short Term'
        );
        insert booking;

        Test.startTest();
        booking.Status__c = 'Confirmed';
        update booking;
        Test.stopTest();

        List<Payment__c> payments = [
            SELECT Amount__c, Payment_Status__c
            FROM Payment__c
            WHERE Booking__c = :booking.Id
        ];
        System.assertEquals(1, payments.size(), 'One payment record should be created');
        System.assertEquals('Pending', payments[0].Payment_Status__c,
            'Payment should start with Pending status');
    }

    /**
     * Test: Car status changes back to "Available" when booking is cancelled.
     */
    @isTest
    static void testCarStatusOnCancellation() {
        Customer__c cust = [SELECT Id FROM Customer__c LIMIT 1];
        Car__c car = [SELECT Id FROM Car__c WHERE Brand__c = 'Toyota' LIMIT 1];

        Booking__c booking = new Booking__c(
            Customer__c = cust.Id,
            Car__c = car.Id,
            Start_Date__c = Date.today().addDays(1),
            End_Date__c = Date.today().addDays(5),
            Pickup_Location__c = 'Delhi',
            Return_Location__c = 'Delhi',
            Booking_Type__c = 'Short Term'
        );
        insert booking;

        booking.Status__c = 'Confirmed';
        update booking;

        Test.startTest();
        booking.Status__c = 'Cancelled';
        update booking;
        Test.stopTest();

        car = [SELECT Status__c FROM Car__c WHERE Id = :car.Id];
        System.assertEquals('Available', car.Status__c,
            'Car should become Available after cancellation');
    }
}
