/**
 * CarRentalDashboardControllerTest
 * Test class for CarRentalDashboardController.
 * Covers: getDashboardData, getRecentBookings, getCarsByStatus.
 */
@isTest
private class CarRentalDashboardControllerTest {

    @TestSetup
    static void setupTestData() {
        Customer__c customer = new Customer__c(
            First_Name__c = 'Dashboard',
            Last_Name__c = 'Tester',
            Email__c = 'dash@test.com',
            Phone__c = '9876543212',
            Driving_License_Number__c = 'DL-TEST-003',
            License_Expiry_Date__c = Date.today().addYears(2)
        );
        insert customer;

        List<Car__c> cars = new List<Car__c>();
        cars.add(new Car__c(
            Brand__c = 'Maruti',
            Car_Model__c = 'Swift',
            Car_Type__c = 'Hatchback',
            Daily_Rental_Rate__c = 1000,
            Status__c = 'Available',
            Active__c = true,
            Location__c = 'Delhi',
            Fuel_Type__c = 'Petrol',
            Transmission__c = 'Manual',
            Seats__c = 5,
            Registration_Number__c = 'DL-03-GH-3456'
        ));
        cars.add(new Car__c(
            Brand__c = 'Tata',
            Car_Model__c = 'Nexon',
            Car_Type__c = 'SUV',
            Daily_Rental_Rate__c = 2500,
            Status__c = 'Available',
            Active__c = true,
            Location__c = 'Mumbai',
            Fuel_Type__c = 'Diesel',
            Transmission__c = 'Automatic',
            Seats__c = 5,
            Registration_Number__c = 'MH-02-IJ-7890'
        ));
        insert cars;

        // Create a booking
        Booking__c booking = new Booking__c(
            Customer__c = customer.Id,
            Car__c = cars[0].Id,
            Start_Date__c = Date.today().addDays(1),
            End_Date__c = Date.today().addDays(5),
            Pickup_Location__c = 'Delhi',
            Return_Location__c = 'Delhi',
            Booking_Type__c = 'Short Term',
            Status__c = 'Confirmed'
        );
        insert booking;

        // Create paid and pending payments
        Payment__c p1 = new Payment__c(
            Booking__c = booking.Id,
            Amount__c = 5000,
            Payment_Date__c = Date.today(),
            Payment_Method__c = 'UPI',
            Payment_Status__c = 'Paid'
        );
        insert p1;

        Payment__c p2 = new Payment__c(
            Booking__c = booking.Id,
            Amount__c = 1500,
            Payment_Date__c = Date.today(),
            Payment_Method__c = 'Cash',
            Payment_Status__c = 'Pending'
        );
        insert p2;
    }

    @isTest
    static void testGetDashboardData() {
        Test.startTest();
        CarRentalDashboardController.DashboardData data =
            CarRentalDashboardController.getDashboardData();
        Test.stopTest();

        System.assertNotEquals(null, data, 'Dashboard data should not be null');
        System.assert(data.totalCars >= 2, 'Should have at least 2 cars');
        System.assert(data.totalCustomers >= 1, 'Should have at least 1 customer');
        System.assertNotEquals(null, data.totalRevenue, 'Total revenue should not be null');
        System.assertNotEquals(null, data.monthlyRevenue, 'Monthly revenue should not be null');
        System.assertNotEquals(null, data.todayRevenue, 'Today revenue should not be null');
        System.assertNotEquals(null, data.pendingRevenue, 'Pending revenue should not be null');
        System.assertNotEquals(null, data.fleetUtilization, 'Fleet utilization should not be null');
    }

    @isTest
    static void testGetRecentBookings() {
        Test.startTest();
        List<Booking__c> bookings = CarRentalDashboardController.getRecentBookings();
        Test.stopTest();

        System.assert(bookings.size() >= 1, 'Should have at least 1 recent booking');
    }

    @isTest
    static void testGetCarsByStatus() {
        Test.startTest();
        List<AggregateResult> results = CarRentalDashboardController.getCarsByStatus();
        Test.stopTest();

        System.assert(results.size() >= 1, 'Should have at least 1 status group');
    }
}
