@isTest
private class CustomerHubControllerTest {

    @testSetup
    static void setupTestData() {
        Customer__c cust1 = new Customer__c(
            First_Name__c = 'Priya',
            Last_Name__c = 'Patel',
            Email__c = 'priya.patel@example.com',
            Phone__c = '9876543211',
            Driving_License_Number__c = 'DL-GUJ-99887',
            License_Expiry_Date__c = Date.today().addDays(15), // Expiring Soon (<30 days)
            Active__c = true
        );
        insert cust1;

        Customer__c cust2 = new Customer__c(
            First_Name__c = 'Rahul',
            Last_Name__c = 'Verma',
            Email__c = 'rahul.verma@example.com',
            Phone__c = '9876543212',
            Driving_License_Number__c = 'DL-DEL-55443',
            License_Expiry_Date__c = Date.today().addYears(2), // Valid
            Active__c = true
        );
        insert cust2;

        Car__c car1 = new Car__c(
            Brand__c = 'Hyundai',
            Car_Model__c = 'Creta',
            Car_Type__c = 'SUV',
            Daily_Rental_Rate__c = 2500,
            Status__c = 'Available',
            Active__c = true
        );
        insert car1;

        Booking__c b1 = new Booking__c(
            Car__c = car1.Id,
            Customer__c = cust1.Id,
            Start_Date__c = Date.today().addDays(1),
            End_Date__c = Date.today().addDays(3),
            Pickup_Location__c = 'Mumbai Airport',
            Return_Location__c = 'Mumbai Airport',
            Booking_Type__c = 'Short Term',
            Status__c = 'Confirmed',
            Total_Amount__c = 5000
        );
        insert b1;
    }

    @isTest
    static void testGetCustomers() {
        Test.startTest();
        List<CustomerHubController.CustomerSummary> allCusts = CustomerHubController.getCustomers('Priya', 'All');
        List<CustomerHubController.CustomerSummary> expiringSoon = CustomerHubController.getCustomers('', 'Expiring Soon');
        List<CustomerHubController.CustomerSummary> validCusts = CustomerHubController.getCustomers('', 'Valid');
        Test.stopTest();

        Assert.areEqual(1, allCusts.size(), 'Should find 1 customer named Priya');
        Assert.areEqual('Expiring Soon', expiringSoon[0].licenseStatus, 'Should classify as Expiring Soon');
        Assert.areEqual('Valid', validCusts[0].licenseStatus, 'Should classify as Valid');
    }

    @isTest
    static void testGetCustomer360() {
        Customer__c cust = [SELECT Id FROM Customer__c WHERE First_Name__c = 'Priya' LIMIT 1];

        Test.startTest();
        CustomerHubController.Customer360Data data = CustomerHubController.getCustomer360(cust.Id);
        Test.stopTest();

        Assert.isNotNull(data, 'Customer 360 data should not be null');
        Assert.isNotNull(data.customer, 'Customer summary should be present');
        Assert.areEqual(1, data.bookings.size(), 'Customer should have 1 booking');
    }

    @isTest
    static void testSaveCustomerRecord() {
        Customer__c newCust = new Customer__c(
            First_Name__c = 'Sneha',
            Last_Name__c = 'Reddy',
            Email__c = 'sneha.reddy@example.com',
            Phone__c = '9812345678',
            Driving_License_Number__c = 'DL-HYD-77665',
            License_Expiry_Date__c = Date.today().addYears(5),
            Active__c = true
        );

        Test.startTest();
        Customer__c saved = CustomerHubController.saveCustomerRecord(newCust);
        Test.stopTest();

        Assert.isNotNull(saved.Id, 'New customer should be inserted with an ID');
    }
}
