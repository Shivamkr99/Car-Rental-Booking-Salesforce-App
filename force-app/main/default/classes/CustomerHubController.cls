/**
 * CustomerHubController
 * Provides Customer 360 insights, license validity alerts,
 * lifetime rental stats, and customer creation for customerHub LWC.
 */
public inherited sharing class CustomerHubController {

    public class CustomerSummary {
        @AuraEnabled public Id id { get; set; }
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public String firstName { get; set; }
        @AuraEnabled public String lastName { get; set; }
        @AuraEnabled public String fullName { get; set; }
        @AuraEnabled public String email { get; set; }
        @AuraEnabled public String phone { get; set; }
        @AuraEnabled public String licenseNumber { get; set; }
        @AuraEnabled public Date licenseExpiryDate { get; set; }
        @AuraEnabled public String licenseStatus { get; set; } // Valid, Expiring Soon, Expired
        @AuraEnabled public Integer licenseDaysLeft { get; set; }
        @AuraEnabled public Boolean active { get; set; }
        @AuraEnabled public Integer totalBookings { get; set; }
        @AuraEnabled public Integer activeBookings { get; set; }
        @AuraEnabled public Decimal lifetimeSpent { get; set; }
        @AuraEnabled public Date lastBookingDate { get; set; }
        @AuraEnabled public String initials { get; set; }
    }

    public class Customer360Data {
        @AuraEnabled public CustomerSummary customer { get; set; }
        @AuraEnabled public List<Booking__c> bookings { get; set; }
        @AuraEnabled public List<Payment__c> payments { get; set; }
        @AuraEnabled public List<Review__c> reviews { get; set; }
    }

    /**
     * Get list of customers with computed metrics and license expiry badges.
     */
    @AuraEnabled(cacheable=true)
    public static List<CustomerSummary> getCustomers(String searchKey, String licenseStatusFilter) {
        String query = 'SELECT Id, Name, First_Name__c, Last_Name__c, Email__c, Phone__c, ' +
                       'Driving_License_Number__c, License_Expiry_Date__c, Active__c ' +
                       'FROM Customer__c WHERE Active__c = true ';

        if (String.isNotBlank(searchKey)) {
            String key = '%' + String.escapeSingleQuotes(searchKey.trim()) + '%';
            query += ' AND (First_Name__c LIKE :key OR Last_Name__c LIKE :key OR Email__c LIKE :key OR Phone__c LIKE :key OR Driving_License_Number__c LIKE :key)';
        }

        query += ' ORDER BY Last_Name__c ASC, First_Name__c ASC LIMIT 100';

        List<Customer__c> custList = Database.query(query);
        Set<Id> custIds = new Set<Id>();
        for (Customer__c c : custList) {
            custIds.add(c.Id);
        }

        // Aggregate bookings and revenue by customer
        Map<Id, Integer> totalBookingsMap = new Map<Id, Integer>();
        Map<Id, Integer> activeBookingsMap = new Map<Id, Integer>();
        Map<Id, Decimal> revenueMap = new Map<Id, Decimal>();
        Map<Id, Date> lastBookingMap = new Map<Id, Date>();

        for (Booking__c b : [
            SELECT Id, Customer__c, Status__c, Total_Amount__c, Start_Date__c
            FROM Booking__c
            WHERE Customer__c IN :custIds
            ORDER BY Start_Date__c DESC
        ]) {
            // Count total
            totalBookingsMap.put(b.Customer__c, totalBookingsMap.get(b.Customer__c) != null ? totalBookingsMap.get(b.Customer__c) + 1 : 1);

            // Count active
            if (b.Status__c == 'Active' || b.Status__c == 'Confirmed') {
                activeBookingsMap.put(b.Customer__c, activeBookingsMap.get(b.Customer__c) != null ? activeBookingsMap.get(b.Customer__c) + 1 : 1);
            }

            // Sum spent (if completed, active, or confirmed)
            if (b.Status__c != 'Cancelled' && b.Total_Amount__c != null) {
                Decimal current = revenueMap.containsKey(b.Customer__c) ? revenueMap.get(b.Customer__c) : 0;
                revenueMap.put(b.Customer__c, current + b.Total_Amount__c);
            }

            // Last booking date
            if (!lastBookingMap.containsKey(b.Customer__c) && b.Start_Date__c != null) {
                lastBookingMap.put(b.Customer__c, b.Start_Date__c);
            }
        }

        List<CustomerSummary> summaries = new List<CustomerSummary>();
        Date today = Date.today();

        for (Customer__c c : custList) {
            CustomerSummary s = new CustomerSummary();
            s.id = c.Id;
            s.name = c.Name;
            s.firstName = c.First_Name__c;
            s.lastName = c.Last_Name__c;
            s.fullName = (String.isNotBlank(c.First_Name__c) ? c.First_Name__c + ' ' : '') + c.Last_Name__c;
            s.email = c.Email__c;
            s.phone = c.Phone__c;
            s.licenseNumber = c.Driving_License_Number__c;
            s.licenseExpiryDate = c.License_Expiry_Date__c;
            s.active = c.Active__c;

            // Compute initials
            String fn = String.isNotBlank(c.First_Name__c) ? c.First_Name__c.substring(0, 1).toUpperCase() : '';
            String ln = String.isNotBlank(c.Last_Name__c) ? c.Last_Name__c.substring(0, 1).toUpperCase() : '';
            s.initials = fn + ln;

            // Compute license status
            if (c.License_Expiry_Date__c == null) {
                s.licenseStatus = 'Valid';
                s.licenseDaysLeft = 365;
            } else if (c.License_Expiry_Date__c < today) {
                s.licenseStatus = 'Expired';
                s.licenseDaysLeft = c.License_Expiry_Date__c.daysBetween(today) * -1;
            } else {
                Integer days = today.daysBetween(c.License_Expiry_Date__c);
                s.licenseDaysLeft = days;
                if (days <= 30) {
                    s.licenseStatus = 'Expiring Soon';
                } else {
                    s.licenseStatus = 'Valid';
                }
            }

            s.totalBookings = totalBookingsMap.containsKey(c.Id) ? totalBookingsMap.get(c.Id) : 0;
            s.activeBookings = activeBookingsMap.containsKey(c.Id) ? activeBookingsMap.get(c.Id) : 0;
            s.lifetimeSpent = revenueMap.containsKey(c.Id) ? revenueMap.get(c.Id) : 0;
            s.lastBookingDate = lastBookingMap.get(c.Id);

            if (String.isBlank(licenseStatusFilter) || licenseStatusFilter == 'All' || s.licenseStatus == licenseStatusFilter) {
                summaries.add(s);
            }
        }
        return summaries;
    }

    /**
     * Get Customer 360 detailed view including bookings, payments, and reviews.
     */
    @AuraEnabled
    public static Customer360Data getCustomer360(Id customerId) {
        if (customerId == null) {
            throw new AuraHandledException('Customer ID is required.');
        }

        List<CustomerSummary> summaries = getCustomers('', 'All');
        CustomerSummary customer = null;
        for (CustomerSummary s : summaries) {
            if (s.id == customerId) {
                customer = s;
                break;
            }
        }

        Customer360Data data = new Customer360Data();
        data.customer = customer;

        data.bookings = [
            SELECT Id, Name, Car__c, Car__r.Brand__c, Car__r.Car_Model__c, Car__r.Car_Image_URL__c,
                   Start_Date__c, End_Date__c, Pickup_Location__c, Return_Location__c,
                   Status__c, Total_Amount__c, Booking_Type__c
            FROM Booking__c
            WHERE Customer__c = :customerId
            ORDER BY Start_Date__c DESC
        ];

        Set<Id> bookingIds = new Set<Id>();
        for (Booking__c b : data.bookings) {
            bookingIds.add(b.Id);
        }

        data.payments = [
            SELECT Id, Name, Booking__c, Booking__r.Name, Amount__c, Payment_Date__c,
                   Payment_Method__c, Payment_Status__c, Transaction_Reference__c
            FROM Payment__c
            WHERE Booking__c IN :bookingIds
            ORDER BY Payment_Date__c DESC
        ];

        data.reviews = [
            SELECT Id, Name, Car__c, Car__r.Brand__c, Car__r.Car_Model__c,
                   Rating__c, Comment__c, Review_Date__c
            FROM Review__c
            WHERE Customer__c = :customerId
            ORDER BY Review_Date__c DESC
        ];

        return data;
    }

    /**
     * Create or edit a customer record.
     */
    @AuraEnabled
    public static Customer__c saveCustomerRecord(Customer__c customer) {
        if (customer == null) {
            throw new AuraHandledException('Customer record cannot be null.');
        }
        if (String.isBlank(customer.Last_Name__c) || String.isBlank(customer.Email__c) || String.isBlank(customer.Driving_License_Number__c)) {
            throw new AuraHandledException('Last Name, Email, and Driving License Number are required.');
        }
        if (customer.License_Expiry_Date__c == null) {
            customer.License_Expiry_Date__c = Date.today().addYears(5);
        }
        upsert customer;
        return customer;
    }
}
