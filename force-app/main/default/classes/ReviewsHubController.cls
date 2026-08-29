/**
 * ReviewsHubController
 * Provides fleet rating analysis, star breakdowns, customer feedback cards,
 * and review submission for reviewsHub LWC.
 */
public inherited sharing class ReviewsHubController {

    public class ReviewSummaryMetrics {
        @AuraEnabled public Decimal averageRating { get; set; }
        @AuraEnabled public Integer totalReviews { get; set; }
        @AuraEnabled public Integer fiveStarCount { get; set; }
        @AuraEnabled public Integer fourStarCount { get; set; }
        @AuraEnabled public Integer threeStarCount { get; set; }
        @AuraEnabled public Integer twoStarCount { get; set; }
        @AuraEnabled public Integer oneStarCount { get; set; }
        @AuraEnabled public Integer fiveStarPercent { get; set; }
        @AuraEnabled public Integer fourStarPercent { get; set; }
        @AuraEnabled public Integer threeStarPercent { get; set; }
        @AuraEnabled public Integer twoStarPercent { get; set; }
        @AuraEnabled public Integer oneStarPercent { get; set; }
    }

    public class ReviewCardWrapper {
        @AuraEnabled public Id id { get; set; }
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public Id customerId { get; set; }
        @AuraEnabled public String customerName { get; set; }
        @AuraEnabled public String customerInitials { get; set; }
        @AuraEnabled public Id carId { get; set; }
        @AuraEnabled public String carName { get; set; }
        @AuraEnabled public String carType { get; set; }
        @AuraEnabled public String carImageUrl { get; set; }
        @AuraEnabled public Decimal rating { get; set; }
        @AuraEnabled public Integer numericRating { get; set; }
        @AuraEnabled public String comment { get; set; }
        @AuraEnabled public Date reviewDate { get; set; }
        @AuraEnabled public Datetime createdDate { get; set; }
    }

    /**
     * Get review summary stats and star distributions.
     */
    @AuraEnabled(cacheable=true)
    public static ReviewSummaryMetrics getReviewsSummary(Id carId) {
        ReviewSummaryMetrics summary = new ReviewSummaryMetrics();
        summary.averageRating = 5.0;
        summary.totalReviews = 0;
        summary.fiveStarCount = 0;
        summary.fourStarCount = 0;
        summary.threeStarCount = 0;
        summary.twoStarCount = 0;
        summary.oneStarCount = 0;

        String query = 'SELECT Rating__c FROM Review__c ';
        if (carId != null) {
            query += ' WHERE Car__c = :carId';
        }

        List<Review__c> allReviews = Database.query(query);
        summary.totalReviews = allReviews.size();

        if (summary.totalReviews == 0) {
            summary.fiveStarPercent = 0;
            summary.fourStarPercent = 0;
            summary.threeStarPercent = 0;
            summary.twoStarPercent = 0;
            summary.oneStarPercent = 0;
            return summary;
        }

        Decimal totalScore = 0;
        for (Review__c r : allReviews) {
            Integer star = (r.Rating__c != null) ? Integer.valueOf(Math.round(r.Rating__c)) : 5;
            totalScore += (r.Rating__c != null ? r.Rating__c : 5);

            if (star >= 5) summary.fiveStarCount++;
            else if (star == 4) summary.fourStarCount++;
            else if (star == 3) summary.threeStarCount++;
            else if (star == 2) summary.twoStarCount++;
            else summary.oneStarCount++;
        }

        summary.averageRating = (totalScore / summary.totalReviews).setScale(1);
        summary.fiveStarPercent = (summary.fiveStarCount * 100) / summary.totalReviews;
        summary.fourStarPercent = (summary.fourStarCount * 100) / summary.totalReviews;
        summary.threeStarPercent = (summary.threeStarCount * 100) / summary.totalReviews;
        summary.twoStarPercent = (summary.twoStarCount * 100) / summary.totalReviews;
        summary.oneStarPercent = (summary.oneStarCount * 100) / summary.totalReviews;

        return summary;
    }

    /**
     * Get list of review cards with customer and car info.
     */
    @AuraEnabled(cacheable=true)
    public static List<ReviewCardWrapper> getReviews(Id carId, String ratingFilter, String searchKey) {
        String query = 'SELECT Id, Name, Customer__c, Customer__r.First_Name__c, Customer__r.Last_Name__c, ' +
                       'Car__c, Car__r.Brand__c, Car__r.Car_Model__c, Car__r.Car_Type__c, Car__r.Car_Image_URL__c, ' +
                       'Rating__c, Comment__c, Review_Date__c, CreatedDate ' +
                       'FROM Review__c WHERE Id != null ';

        if (carId != null) {
            query += ' AND Car__c = :carId';
        }

        if (String.isNotBlank(ratingFilter) && ratingFilter != 'All') {
            Decimal targetRating = Decimal.valueOf(ratingFilter);
            query += ' AND Rating__c = :targetRating';
        }

        if (String.isNotBlank(searchKey)) {
            String key = '%' + String.escapeSingleQuotes(searchKey.trim()) + '%';
            query += ' AND (Comment__c LIKE :key OR Customer__r.First_Name__c LIKE :key OR Customer__r.Last_Name__c LIKE :key OR Car__r.Brand__c LIKE :key OR Car__r.Car_Model__c LIKE :key)';
        }

        query += ' ORDER BY Review_Date__c DESC, CreatedDate DESC LIMIT 100';

        List<ReviewCardWrapper> results = new List<ReviewCardWrapper>();
        for (Review__c r : Database.query(query)) {
            ReviewCardWrapper w = new ReviewCardWrapper();
            w.id = r.Id;
            w.name = r.Name;
            w.customerId = r.Customer__c;

            String fn = (r.Customer__r != null && r.Customer__r.First_Name__c != null) ? r.Customer__r.First_Name__c : '';
            String ln = (r.Customer__r != null && r.Customer__r.Last_Name__c != null) ? r.Customer__r.Last_Name__c : '';
            w.customerName = (fn + ' ' + ln).trim();
            if (String.isBlank(w.customerName)) w.customerName = 'Verified Customer';

            String fi = fn.length() > 0 ? fn.substring(0, 1).toUpperCase() : '';
            String li = ln.length() > 0 ? ln.substring(0, 1).toUpperCase() : 'C';
            w.customerInitials = fi + li;

            w.carId = r.Car__c;
            w.carName = r.Car__r != null ? r.Car__r.Brand__c + ' ' + r.Car__r.Car_Model__c : 'N/A';
            w.carType = r.Car__r != null ? r.Car__r.Car_Type__c : '';
            w.carImageUrl = r.Car__r != null ? r.Car__r.Car_Image_URL__c : '';

            w.rating = r.Rating__c != null ? r.Rating__c : 5.0;
            w.numericRating = r.Rating__c != null ? Integer.valueOf(Math.round(r.Rating__c)) : 5;

            w.comment = r.Comment__c;
            w.reviewDate = r.Review_Date__c;
            w.createdDate = r.CreatedDate;
            results.add(w);
        }
        return results;
    }

    /**
     * Submit a customer review.
     */
    @AuraEnabled
    public static Review__c submitReview(Review__c review) {
        if (review == null || review.Car__c == null || review.Rating__c == null) {
            throw new AuraHandledException('Car and Rating are required to submit a review.');
        }
        if (review.Review_Date__c == null) {
            review.Review_Date__c = Date.today();
        }
        upsert review;

        // Recalculate Car Rating average
        List<AggregateResult> avgRes = [
            SELECT AVG(Rating__c) avgRating
            FROM Review__c
            WHERE Car__c = :review.Car__c
        ];
        if (!avgRes.isEmpty() && avgRes[0].get('avgRating') != null) {
            Decimal avg = ((Decimal)avgRes[0].get('avgRating')).setScale(1);
            update new Car__c(Id = review.Car__c, Rating__c = avg);
        }

        return review;
    }
}
