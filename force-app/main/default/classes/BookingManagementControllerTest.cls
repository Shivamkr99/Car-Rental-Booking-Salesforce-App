@isTest
private class BookingManagementControllerTest {

    @testSetup
    static void setupTestData() {
        Car__c car = new Car__c(
            Brand__c = 'Kia',
            Car_Model__c = 'Seltos',
            Car_Type__c = 'SUV',
            Daily_Rental_Rate__c = 2800,
            Status__c = 'Available',
            Active__c = true
        );
        insert car;

        Customer__c cust = new Customer__c(
            First_Name__c = 'Karan',
            Last_Name__c = 'Johar',
            Email__c = 'karan.johar@example.com',
            Phone__c = '9876500000',
            Driving_License_Number__c = 'DL-MUM-99112',
            License_Expiry_Date__c = Date.today().addYears(2),
            Active__c = true
        );
        insert cust;

        Booking__c b = new Booking__c(
            Car__c = car.Id,
            Customer__c = cust.Id,
            Start_Date__c = Date.today().addDays(1),
            End_Date__c = Date.today().addDays(4),
            Pickup_Location__c = 'Delhi Airport',
            Return_Location__c = 'Delhi Airport',
            Booking_Type__c = 'Short Term',
            Status__c = 'Pending',
            Total_Amount__c = 8400
        );
        insert b;
    }

    @isTest
    static void testGetBookingsAndCounts() {
        Test.startTest();
        List<BookingManagementController.BookingCardWrapper> bookings = BookingManagementController.getBookings('All', '');
        BookingManagementController.BookingCountSummary counts = BookingManagementController.getBookingCounts();
        Test.stopTest();

        Assert.areEqual(1, bookings.size(), 'Should return 1 booking');
        Assert.areEqual(1, counts.allCount, 'Total booking count should be 1');
        Assert.areEqual(1, counts.pendingCount, 'Pending count should be 1');
    }

    @isTest
    static void testUpdateStatusAndRecordPayment() {
        Booking__c b = [SELECT Id FROM Booking__c LIMIT 1];

        Test.startTest();
        Booking__c updated = BookingManagementController.updateStatus(b.Id, 'Confirmed');
        Payment__c p = BookingManagementController.recordPaymentForBooking(b.Id, 8400, 'Credit Card', 'TXN-TEST-123');
        Test.stopTest();

        Assert.areEqual('Confirmed', updated.Status__c, 'Status should update to Confirmed');
        Assert.isNotNull(p.Id, 'Payment should be created');
        Assert.areEqual('Paid', p.Payment_Status__c, 'Payment status should be Paid');
    }
}
