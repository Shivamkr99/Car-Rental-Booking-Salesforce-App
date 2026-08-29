@isTest
private class ReviewsHubControllerTest {

    @testSetup
    static void setupTestData() {
        Car__c car = new Car__c(
            Brand__c = 'Tata',
            Car_Model__c = 'Nexon',
            Car_Type__c = 'SUV',
            Daily_Rental_Rate__c = 1900,
            Location__c = 'Delhi',
            Status__c = 'Available',
            Active__c = true
        );
        insert car;

        Customer__c cust = new Customer__c(
            First_Name__c = 'Ananya',
            Last_Name__c = 'Panday',
            Email__c = 'ananya.panday@example.com',
            Phone__c = '9876588888',
            Driving_License_Number__c = 'DL-MAH-44556',
            License_Expiry_Date__c = Date.today().addYears(3),
            Active__c = true
        );
        insert cust;

        Review__c r = new Review__c(
            Car__c = car.Id,
            Customer__c = cust.Id,
            Rating__c = 5.0,
            Comment__c = 'Smooth drive and pristine condition!',
            Review_Date__c = Date.today()
        );
        insert r;
    }

    @isTest
    static void testGetReviewsSummaryAndList() {
        Test.startTest();
        ReviewsHubController.ReviewSummaryMetrics summary = ReviewsHubController.getReviewsSummary(null);
        List<ReviewsHubController.ReviewCardWrapper> reviews = ReviewsHubController.getReviews(null, 'All', '');
        Test.stopTest();

        Assert.areEqual(1, summary.totalReviews, 'Total reviews should be 1');
        Assert.areEqual(5.0, summary.averageRating, 'Average rating should be 5.0');
        Assert.areEqual(1, reviews.size(), 'Should return 1 review card');
    }

    @isTest
    static void testSubmitReview() {
        Car__c car = [SELECT Id FROM Car__c LIMIT 1];
        Customer__c cust = [SELECT Id FROM Customer__c LIMIT 1];

        Review__c newReview = new Review__c(
            Car__c = car.Id,
            Customer__c = cust.Id,
            Rating__c = 4.0,
            Comment__c = 'Great mileage and comfort.'
        );

        Test.startTest();
        Review__c submitted = ReviewsHubController.submitReview(newReview);
        Test.stopTest();

        Assert.isNotNull(submitted.Id, 'Review should be submitted with ID');
    }
}
