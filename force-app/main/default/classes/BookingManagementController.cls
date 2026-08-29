/**
 * BookingManagementController
 * Provides lifecycle management, status transitions, and quick payment logging
 * for the bookingManagementHub LWC.
 */
public inherited sharing class BookingManagementController {

    public class BookingCardWrapper {
        @AuraEnabled public Id id { get; set; }
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public Id customerId { get; set; }
        @AuraEnabled public String customerName { get; set; }
        @AuraEnabled public String customerEmail { get; set; }
        @AuraEnabled public String customerPhone { get; set; }
        @AuraEnabled public Id carId { get; set; }
        @AuraEnabled public String carName { get; set; }
        @AuraEnabled public String carType { get; set; }
        @AuraEnabled public String carImageUrl { get; set; }
        @AuraEnabled public String carRegistration { get; set; }
        @AuraEnabled public Date startDate { get; set; }
        @AuraEnabled public Date endDate { get; set; }
        @AuraEnabled public Integer durationDays { get; set; }
        @AuraEnabled public String pickupLocation { get; set; }
        @AuraEnabled public String returnLocation { get; set; }
        @AuraEnabled public String bookingType { get; set; }
        @AuraEnabled public String notes { get; set; }
        @AuraEnabled public String status { get; set; }
        @AuraEnabled public Decimal totalAmount { get; set; }
        @AuraEnabled public String paymentStatus { get; set; }
        @AuraEnabled public Datetime createdDate { get; set; }
    }

    public class BookingCountSummary {
        @AuraEnabled public Integer allCount { get; set; }
        @AuraEnabled public Integer pendingCount { get; set; }
        @AuraEnabled public Integer confirmedCount { get; set; }
        @AuraEnabled public Integer activeCount { get; set; }
        @AuraEnabled public Integer completedCount { get; set; }
        @AuraEnabled public Integer cancelledCount { get; set; }
    }

    /**
     * Get bookings list with full customer and vehicle context.
     */
    @AuraEnabled(cacheable=true)
    public static List<BookingCardWrapper> getBookings(String statusFilter, String searchKey) {
        String query = 'SELECT Id, Name, Customer__c, Customer__r.First_Name__c, Customer__r.Last_Name__c, ' +
                       'Customer__r.Email__c, Customer__r.Phone__c, Car__c, Car__r.Brand__c, Car__r.Car_Model__c, ' +
                       'Car__r.Car_Type__c, Car__r.Car_Image_URL__c, Car__r.Registration_Number__c, ' +
                       'Start_Date__c, End_Date__c, Pickup_Location__c, Return_Location__c, ' +
                       'Booking_Type__c, Booking_Notes__c, Status__c, Total_Amount__c, CreatedDate ' +
                       'FROM Booking__c WHERE Id != null ';

        if (String.isNotBlank(statusFilter) && statusFilter != 'All') {
            query += ' AND Status__c = :statusFilter';
        }

        if (String.isNotBlank(searchKey)) {
            String key = '%' + String.escapeSingleQuotes(searchKey.trim()) + '%';
            query += ' AND (Name LIKE :key OR Customer__r.First_Name__c LIKE :key OR Customer__r.Last_Name__c LIKE :key OR Car__r.Brand__c LIKE :key OR Car__r.Car_Model__c LIKE :key OR Pickup_Location__c LIKE :key)';
        }

        query += ' ORDER BY CreatedDate DESC LIMIT 150';

        List<Booking__c> rawList = Database.query(query);
        Set<Id> bookingIds = new Set<Id>();
        for (Booking__c b : rawList) {
            bookingIds.add(b.Id);
        }

        // Map latest payment status
        Map<Id, String> payStatusMap = new Map<Id, String>();
        for (Payment__c p : [
            SELECT Booking__c, Payment_Status__c
            FROM Payment__c
            WHERE Booking__c IN :bookingIds
            ORDER BY Payment_Date__c DESC, CreatedDate DESC
        ]) {
            if (!payStatusMap.containsKey(p.Booking__c)) {
                payStatusMap.put(p.Booking__c, p.Payment_Status__c);
            }
        }

        List<BookingCardWrapper> cards = new List<BookingCardWrapper>();
        for (Booking__c b : rawList) {
            BookingCardWrapper w = new BookingCardWrapper();
            w.id = b.Id;
            w.name = b.Name;
            w.customerId = b.Customer__c;
            w.customerName = (b.Customer__r != null ? (String.isNotBlank(b.Customer__r.First_Name__c) ? b.Customer__r.First_Name__c + ' ' : '') + b.Customer__r.Last_Name__c : 'N/A');
            w.customerEmail = b.Customer__r != null ? b.Customer__r.Email__c : '';
            w.customerPhone = b.Customer__r != null ? b.Customer__r.Phone__c : '';
            w.carId = b.Car__c;
            w.carName = b.Car__r != null ? b.Car__r.Brand__c + ' ' + b.Car__r.Car_Model__c : 'N/A';
            w.carType = b.Car__r != null ? b.Car__r.Car_Type__c : '';
            w.carImageUrl = b.Car__r != null ? b.Car__r.Car_Image_URL__c : '';
            w.carRegistration = b.Car__r != null ? b.Car__r.Registration_Number__c : '';
            w.startDate = b.Start_Date__c;
            w.endDate = b.End_Date__c;
            w.durationDays = (b.Start_Date__c != null && b.End_Date__c != null) ? Math.max(1, b.Start_Date__c.daysBetween(b.End_Date__c)) : 1;
            w.pickupLocation = b.Pickup_Location__c;
            w.returnLocation = b.Return_Location__c;
            w.bookingType = b.Booking_Type__c;
            w.notes = b.Booking_Notes__c;
            w.status = b.Status__c;
            w.totalAmount = b.Total_Amount__c;
            w.paymentStatus = payStatusMap.containsKey(b.Id) ? payStatusMap.get(b.Id) : 'Unpaid';
            w.createdDate = b.CreatedDate;
            cards.add(w);
        }
        return cards;
    }

    /**
     * Get booking counts by status for tab badge headers.
     */
    @AuraEnabled(cacheable=true)
    public static BookingCountSummary getBookingCounts() {
        BookingCountSummary counts = new BookingCountSummary();
        counts.allCount = 0;
        counts.pendingCount = 0;
        counts.confirmedCount = 0;
        counts.activeCount = 0;
        counts.completedCount = 0;
        counts.cancelledCount = 0;

        for (AggregateResult ar : [
            SELECT Status__c st, COUNT(Id) cnt
            FROM Booking__c
            GROUP BY Status__c
        ]) {
            String st = (String) ar.get('st');
            Integer c = (Integer) ar.get('cnt');
            counts.allCount += c;
            if (st == 'Pending') counts.pendingCount = c;
            else if (st == 'Confirmed') counts.confirmedCount = c;
            else if (st == 'Active') counts.activeCount = c;
            else if (st == 'Completed') counts.completedCount = c;
            else if (st == 'Cancelled') counts.cancelledCount = c;
        }
        return counts;
    }

    /**
     * Update booking status and trigger vehicle sync.
     */
    @AuraEnabled
    public static Booking__c updateStatus(Id bookingId, String newStatus) {
        if (bookingId == null || String.isBlank(newStatus)) {
            throw new AuraHandledException('Booking ID and new status are required.');
        }

        Booking__c b = [SELECT Id, Status__c, Car__c, Total_Amount__c FROM Booking__c WHERE Id = :bookingId LIMIT 1];
        b.Status__c = newStatus;
        update b;

        return [SELECT Id, Name, Status__c FROM Booking__c WHERE Id = :bookingId];
    }

    /**
     * Record a payment against a booking directly from the bookings center.
     */
    @AuraEnabled
    public static Payment__c recordPaymentForBooking(
        Id bookingId,
        Decimal amount,
        String paymentMethod,
        String transactionRef
    ) {
        if (bookingId == null || amount == null || amount <= 0) {
            throw new AuraHandledException('Valid Booking ID and Payment Amount are required.');
        }

        Payment__c p = new Payment__c(
            Booking__c = bookingId,
            Amount__c = amount,
            Payment_Date__c = Date.today(),
            Payment_Method__c = String.isNotBlank(paymentMethod) ? paymentMethod : 'UPI',
            Payment_Status__c = 'Paid',
            Transaction_Reference__c = String.isNotBlank(transactionRef) ? transactionRef : 'TXN-' + System.currentTimeMillis()
        );
        insert p;

        return p;
    }
}
