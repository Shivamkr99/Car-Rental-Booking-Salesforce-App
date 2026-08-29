/**
 * PaymentServiceTest
 * Test class for PaymentService and PaymentTrigger.
 * Covers: Booking status update when payment is Paid/Refunded.
 */
@isTest
private class PaymentServiceTest {

    @TestSetup
    static void setupTestData() {
        Customer__c customer = new Customer__c(
            First_Name__c = 'Payment',
            Last_Name__c = 'Tester',
            Email__c = 'payment@test.com',
            Phone__c = '9876543211',
            Driving_License_Number__c = 'DL-TEST-002',
            License_Expiry_Date__c = Date.today().addYears(2)
        );
        insert customer;

        Car__c car = new Car__c(
            Brand__c = 'Hyundai',
            Car_Model__c = 'Creta',
            Car_Type__c = 'SUV',
            Daily_Rental_Rate__c = 3000,
            Status__c = 'Available',
            Active__c = true,
            Location__c = 'Delhi',
            Fuel_Type__c = 'Petrol',
            Transmission__c = 'Automatic',
            Seats__c = 5,
            Registration_Number__c = 'DL-02-EF-9012'
        );
        insert car;
    }

    /**
     * Test: Booking becomes Active when Payment is marked Paid.
     */
    @isTest
    static void testBookingActivatedOnPayment() {
        Customer__c cust = [SELECT Id FROM Customer__c LIMIT 1];
        Car__c car = [SELECT Id FROM Car__c LIMIT 1];

        // Create and confirm booking (auto-creates payment)
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

        // Get the auto-created payment
        Payment__c payment = [
            SELECT Id, Payment_Status__c
            FROM Payment__c
            WHERE Booking__c = :booking.Id
            LIMIT 1
        ];

        Test.startTest();
        payment.Payment_Status__c = 'Paid';
        update payment;
        Test.stopTest();

        booking = [SELECT Status__c FROM Booking__c WHERE Id = :booking.Id];
        System.assertEquals('Active', booking.Status__c,
            'Booking should be Active after payment is marked Paid');
    }

    /**
     * Test: Booking becomes Cancelled when Payment is Refunded.
     */
    @isTest
    static void testBookingCancelledOnRefund() {
        Customer__c cust = [SELECT Id FROM Customer__c LIMIT 1];
        Car__c car = [SELECT Id FROM Car__c LIMIT 1];

        Booking__c booking = new Booking__c(
            Customer__c = cust.Id,
            Car__c = car.Id,
            Start_Date__c = Date.today().addDays(10),
            End_Date__c = Date.today().addDays(15),
            Pickup_Location__c = 'Delhi',
            Return_Location__c = 'Delhi',
            Booking_Type__c = 'Short Term'
        );
        insert booking;

        booking.Status__c = 'Confirmed';
        update booking;

        Payment__c payment = [
            SELECT Id, Payment_Status__c
            FROM Payment__c
            WHERE Booking__c = :booking.Id
            LIMIT 1
        ];

        // First mark as Paid
        payment.Payment_Status__c = 'Paid';
        update payment;

        Test.startTest();
        // Then refund
        payment.Payment_Status__c = 'Refunded';
        update payment;
        Test.stopTest();

        booking = [SELECT Status__c FROM Booking__c WHERE Id = :booking.Id];
        System.assertEquals('Cancelled', booking.Status__c,
            'Booking should be Cancelled after payment refund');
    }

    /**
     * Test: Payment with no booking reference does not cause errors.
     */
    @isTest
    static void testPaymentWithoutBooking() {
        Payment__c payment = new Payment__c(
            Amount__c = 5000,
            Payment_Status__c = 'Pending',
            Payment_Method__c = 'Cash',
            Payment_Date__c = Date.today()
        );
        insert payment;

        Test.startTest();
        payment.Payment_Status__c = 'Paid';
        update payment;
        Test.stopTest();

        // Should not throw any error
        payment = [SELECT Payment_Status__c FROM Payment__c WHERE Id = :payment.Id];
        System.assertEquals('Paid', payment.Payment_Status__c);
    }
}
