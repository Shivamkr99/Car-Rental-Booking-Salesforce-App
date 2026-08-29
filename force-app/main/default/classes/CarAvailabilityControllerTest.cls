/**
 * CarAvailabilityControllerTest
 * Test class for CarAvailabilityController.
 * Covers: searchAvailableCars, getAvailableLocations, getCarTypes.
 */
@isTest
private class CarAvailabilityControllerTest {

    @TestSetup
    static void setupTestData() {
        Customer__c customer = new Customer__c(
            First_Name__c = 'Avail',
            Last_Name__c = 'Tester',
            Email__c = 'avail@test.com',
            Phone__c = '9876543213',
            Driving_License_Number__c = 'DL-TEST-004',
            License_Expiry_Date__c = Date.today().addYears(2)
        );
        insert customer;

        List<Car__c> cars = new List<Car__c>();
        cars.add(new Car__c(
            Brand__c = 'Kia',
            Car_Model__c = 'Seltos',
            Car_Type__c = 'SUV',
            Daily_Rental_Rate__c = 2500,
            Status__c = 'Available',
            Active__c = true,
            Location__c = 'Delhi',
            Fuel_Type__c = 'Petrol',
            Transmission__c = 'Automatic',
            Seats__c = 5,
            Registration_Number__c = 'DL-04-KL-1111'
        ));
        cars.add(new Car__c(
            Brand__c = 'Mahindra',
            Car_Model__c = 'XUV700',
            Car_Type__c = 'SUV',
            Daily_Rental_Rate__c = 4000,
            Status__c = 'Available',
            Active__c = true,
            Location__c = 'Mumbai',
            Fuel_Type__c = 'Diesel',
            Transmission__c = 'Automatic',
            Seats__c = 7,
            Registration_Number__c = 'MH-03-MN-2222'
        ));
        insert cars;

        // Book the first car for specific dates
        Booking__c booking = new Booking__c(
            Customer__c = customer.Id,
            Car__c = cars[0].Id,
            Start_Date__c = Date.today().addDays(5),
            End_Date__c = Date.today().addDays(10),
            Pickup_Location__c = 'Delhi',
            Return_Location__c = 'Delhi',
            Booking_Type__c = 'Short Term'
        );
        insert booking;
    }

    /**
     * Test: Search with no filters returns all available cars.
     */
    @isTest
    static void testSearchNoFilters() {
        Test.startTest();
        List<Car__c> results = CarAvailabilityController.searchAvailableCars(
            null, null, null, null
        );
        Test.stopTest();

        System.assert(results.size() >= 2, 'Should return available cars');
    }

    /**
     * Test: Search with location filter.
     */
    @isTest
    static void testSearchByLocation() {
        Test.startTest();
        List<Car__c> results = CarAvailabilityController.searchAvailableCars(
            'Delhi', null, null, null
        );
        Test.stopTest();

        for (Car__c c : results) {
            System.assertEquals('Delhi', c.Location__c, 'Should only return Delhi cars');
        }
    }

    /**
     * Test: Search with date range excludes booked cars.
     */
    @isTest
    static void testSearchExcludesBookedCars() {
        Test.startTest();
        // Search for dates overlapping with the existing booking
        List<Car__c> results = CarAvailabilityController.searchAvailableCars(
            'Delhi',
            Date.today().addDays(6),
            Date.today().addDays(8),
            null
        );
        Test.stopTest();

        // The Kia Seltos in Delhi should NOT appear (it's booked for those dates)
        Set<String> brands = new Set<String>();
        for (Car__c c : results) {
            brands.add(c.Brand__c);
        }
        System.assert(!brands.contains('Kia'),
            'Kia should not appear since it is booked for those dates');
    }

    /**
     * Test: getAvailableLocations returns locations.
     */
    @isTest
    static void testGetAvailableLocations() {
        Test.startTest();
        List<String> locations = CarAvailabilityController.getAvailableLocations();
        Test.stopTest();

        System.assert(locations.size() >= 1, 'Should return at least 1 location');
    }

    /**
     * Test: getCarTypes returns car types.
     */
    @isTest
    static void testGetCarTypes() {
        Test.startTest();
        List<String> types = CarAvailabilityController.getCarTypes();
        Test.stopTest();

        System.assert(types.size() >= 1, 'Should return at least 1 car type');
    }
}
