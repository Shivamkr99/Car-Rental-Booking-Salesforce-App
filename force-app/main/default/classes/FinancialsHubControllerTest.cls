@isTest
private class FinancialsHubControllerTest {

    @testSetup
    static void setupTestData() {
        Car__c car = new Car__c(
            Brand__c = 'Mahindra',
            Car_Model__c = 'XUV700',
            Car_Type__c = 'SUV',
            Daily_Rental_Rate__c = 3500,
            Location__c = 'Bangalore',
            Status__c = 'Available',
            Active__c = true
        );
        insert car;

        Customer__c cust = new Customer__c(
            First_Name__c = 'Vikram',
            Last_Name__c = 'Batra',
            Email__c = 'vikram.batra@example.com',
            Phone__c = '9876599999',
            Driving_License_Number__c = 'DL-PUN-33221',
            License_Expiry_Date__c = Date.today().addYears(3),
            Active__c = true
        );
        insert cust;

        Booking__c b = new Booking__c(
            Car__c = car.Id,
            Customer__c = cust.Id,
            Start_Date__c = Date.today().addDays(1),
            End_Date__c = Date.today().addDays(3),
            Pickup_Location__c = 'Bangalore',
            Return_Location__c = 'Bangalore',
            Booking_Type__c = 'Short Term',
            Status__c = 'Confirmed',
            Total_Amount__c = 7000
        );
        insert b;

        Payment__c p1 = new Payment__c(
            Booking__c = b.Id,
            Amount__c = 7000,
            Payment_Date__c = Date.today(),
            Payment_Method__c = 'UPI',
            Payment_Status__c = 'Paid',
            Transaction_Reference__c = 'TXN-PAID-001'
        );
        insert p1;

        Payment__c p2 = new Payment__c(
            Booking__c = b.Id,
            Amount__c = 2000,
            Payment_Date__c = Date.today(),
            Payment_Method__c = 'Cash',
            Payment_Status__c = 'Pending',
            Transaction_Reference__c = 'TXN-PEND-002'
        );
        insert p2;
    }

    @isTest
    static void testGetFinancialKPIsAndPayments() {
        Test.startTest();
        FinancialsHubController.FinancialKPIs kpis = FinancialsHubController.getFinancialKPIs();
        List<FinancialsHubController.PaymentTransactionWrapper> payments = FinancialsHubController.getPayments('All', '');
        Test.stopTest();

        Assert.areEqual(7000, kpis.totalRevenue, 'Total revenue should match paid amount');
        Assert.areEqual(2000, kpis.pendingRevenue, 'Pending revenue should match pending amount');
        Assert.areEqual(2, payments.size(), 'Should return 2 payments');
    }

    @isTest
    static void testSavePaymentAndRefund() {
        Booking__c b = [SELECT Id FROM Booking__c LIMIT 1];
        Payment__c newP = new Payment__c(
            Booking__c = b.Id,
            Amount__c = 1500,
            Payment_Method__c = 'Credit Card',
            Payment_Status__c = 'Paid'
        );

        Test.startTest();
        Payment__c saved = FinancialsHubController.savePaymentRecord(newP);
        Payment__c refunded = FinancialsHubController.refundPayment(saved.Id);
        Test.stopTest();

        Assert.isNotNull(saved.Id, 'Payment should be saved with ID');
        Assert.areEqual('Refunded', refunded.Payment_Status__c, 'Payment should be marked as Refunded');
    }
}
