@isTest
private class CarFleetControllerTest {

    @testSetup
    static void setupTestData() {
        Car__c car1 = new Car__c(
            Brand__c = 'Toyota',
            Car_Model__c = 'Fortuner',
            Car_Type__c = 'SUV',
            Daily_Rental_Rate__c = 4500,
            Fuel_Type__c = 'Diesel',
            Transmission__c = 'Automatic',
            Seats__c = 7,
            Status__c = 'Available',
            Location__c = 'Mumbai',
            Active__c = true
        );
        insert car1;

        Customer__c cust1 = new Customer__c(
            First_Name__c = 'Amit',
            Last_Name__c = 'Sharma',
            Email__c = 'amit.sharma@example.com',
            Phone__c = '9876543210',
            Driving_License_Number__c = 'DL-MUM-12345',
            License_Expiry_Date__c = Date.today().addYears(3),
            Active__c = true
        );
        insert cust1;
    }

    @isTest
    static void testGetFleetCars() {
        Test.startTest();
        List<CarFleetController.CarWrapper> cars = CarFleetController.getFleetCars('', 'Toyota', 'SUV', 'Available', 'Diesel', 'Automatic');
        Test.stopTest();

        Assert.areNotEqual(0, cars.size(), 'Should return at least 1 car matching filter');
        Assert.areEqual('Toyota', cars[0].brand, 'Brand should match');
    }

    @isTest
    static void testGetFleetFilterOptions() {
        Test.startTest();
        Map<String, List<String>> options = CarFleetController.getFleetFilterOptions();
        Test.stopTest();

        Assert.isNotNull(options, 'Filter options map should not be null');
        Assert.isTrue(options.containsKey('brands'), 'Should contain brands list');
    }

    @isTest
    static void testCreateInstantBookingWithPayment() {
        Car__c car = [SELECT Id FROM Car__c LIMIT 1];
        Customer__c cust = [SELECT Id FROM Customer__c LIMIT 1];

        Test.startTest();
        Booking__c b = CarFleetController.createInstantBooking(
            car.Id,
            cust.Id,
            Date.today().addDays(2),
            Date.today().addDays(5),
            'Mumbai',
            'Mumbai',
            'Short Term',
            'VIP Customer',
            true,
            'UPI'
        );
        Test.stopTest();

        Assert.isNotNull(b.Id, 'Booking should be created successfully');
        List<Payment__c> payments = [SELECT Id, Amount__c FROM Payment__c WHERE Booking__c = :b.Id];
        Assert.areEqual(1, payments.size(), 'Payment should be created immediately');
    }

    @isTest
    static void testSaveCarRecord() {
        Car__c newCar = new Car__c(
            Brand__c = 'Honda',
            Car_Model__c = 'City',
            Car_Type__c = 'Sedan',
            Daily_Rental_Rate__c = 2200,
            Location__c = 'Mumbai',
            Status__c = 'Available',
            Active__c = true
        );

        Test.startTest();
        Car__c saved = CarFleetController.saveCarRecord(newCar);
        Test.stopTest();

        Assert.isNotNull(saved.Id, 'Car should be upserted with an ID');
    }
}
