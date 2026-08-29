/**
 * CarRentalDashboardController
 * Provides comprehensive executive business analytics, sales metrics,
 * fleet utilization, and operational KPIs for the carRentalDashboard LWC.
 */
public inherited sharing class CarRentalDashboardController {

    public class CarPerformanceWrapper {
        @AuraEnabled public Id carId { get; set; }
        @AuraEnabled public String carName { get; set; }
        @AuraEnabled public String brand { get; set; }
        @AuraEnabled public String carType { get; set; }
        @AuraEnabled public String imageUrl { get; set; }
        @AuraEnabled public Decimal totalRevenue { get; set; }
        @AuraEnabled public Integer totalBookings { get; set; }
    }

    public class DashboardData {
        @AuraEnabled public Integer activeBookings { get; set; }
        @AuraEnabled public Integer pendingBookings { get; set; }
        @AuraEnabled public Integer completedBookings { get; set; }
        @AuraEnabled public Integer availableCars { get; set; }
        @AuraEnabled public Integer bookedCars { get; set; }
        @AuraEnabled public Integer totalCars { get; set; }
        @AuraEnabled public Integer totalCustomers { get; set; }
        @AuraEnabled public Integer fleetUtilization { get; set; } // Percentage
        @AuraEnabled public Decimal totalRevenue { get; set; }
        @AuraEnabled public Decimal monthlyRevenue { get; set; }
        @AuraEnabled public Decimal todayRevenue { get; set; }
        @AuraEnabled public Decimal pendingRevenue { get; set; }
        @AuraEnabled public List<CarPerformanceWrapper> topCars { get; set; }
    }

    /**
     * Get complete dashboard KPI data for the business owner.
     */
    @AuraEnabled(cacheable=true)
    public static DashboardData getDashboardData() {
        DashboardData data = new DashboardData();

        data.activeBookings = [SELECT COUNT() FROM Booking__c WHERE Status__c = 'Active'];
        data.pendingBookings = [SELECT COUNT() FROM Booking__c WHERE Status__c = 'Pending'];
        data.completedBookings = [SELECT COUNT() FROM Booking__c WHERE Status__c = 'Completed'];
        data.availableCars = [SELECT COUNT() FROM Car__c WHERE Status__c = 'Available'];
        data.bookedCars = [SELECT COUNT() FROM Car__c WHERE Status__c = 'Booked'];
        data.totalCars = [SELECT COUNT() FROM Car__c];
        data.totalCustomers = [SELECT COUNT() FROM Customer__c];

        // Fleet utilization %
        if (data.totalCars > 0) {
            data.fleetUtilization = Math.round(((Decimal)(data.totalCars - data.availableCars) * 100) / data.totalCars);
        } else {
            data.fleetUtilization = 0;
        }

        // Total collected revenue from paid payments
        AggregateResult[] revenueResult = [
            SELECT SUM(Amount__c) totalRev
            FROM Payment__c
            WHERE Payment_Status__c = 'Paid'
        ];
        data.totalRevenue = (revenueResult[0].get('totalRev') != null)
            ? (Decimal) revenueResult[0].get('totalRev')
            : 0;

        // Pending receivables
        AggregateResult[] pendingResult = [
            SELECT SUM(Amount__c) pendingRev
            FROM Payment__c
            WHERE Payment_Status__c = 'Pending'
        ];
        data.pendingRevenue = (pendingResult[0].get('pendingRev') != null)
            ? (Decimal) pendingResult[0].get('pendingRev')
            : 0;

        // This month revenue
        Date monthStart = Date.today().toStartOfMonth();
        Date monthEnd = monthStart.addMonths(1);
        AggregateResult[] monthResult = [
            SELECT SUM(Amount__c) monthRev
            FROM Payment__c
            WHERE Payment_Status__c = 'Paid'
              AND Payment_Date__c >= :monthStart
              AND Payment_Date__c < :monthEnd
        ];
        data.monthlyRevenue = (monthResult[0].get('monthRev') != null)
            ? (Decimal) monthResult[0].get('monthRev')
            : 0;

        // Today revenue
        Date today = Date.today();
        AggregateResult[] todayResult = [
            SELECT SUM(Amount__c) todayRev
            FROM Payment__c
            WHERE Payment_Status__c = 'Paid'
              AND Payment_Date__c = :today
        ];
        data.todayRevenue = (todayResult[0].get('todayRev') != null)
            ? (Decimal) todayResult[0].get('todayRev')
            : 0;

        // Top performing vehicles by bookings
        data.topCars = new List<CarPerformanceWrapper>();
        for (Car__c c : [
            SELECT Id, Brand__c, Car_Model__c, Car_Type__c, Car_Image_URL__c, Total_Bookings__c
            FROM Car__c
            ORDER BY Total_Bookings__c DESC NULLS LAST, Daily_Rental_Rate__c DESC
            LIMIT 4
        ]) {
            CarPerformanceWrapper cp = new CarPerformanceWrapper();
            cp.carId = c.Id;
            cp.brand = c.Brand__c;
            cp.carName = c.Brand__c + ' ' + c.Car_Model__c;
            cp.carType = c.Car_Type__c;
            cp.imageUrl = c.Car_Image_URL__c;
            cp.totalBookings = c.Total_Bookings__c != null ? (Integer)c.Total_Bookings__c : 0;
            data.topCars.add(cp);
        }

        return data;
    }

    /**
     * Get recent bookings for the dashboard with vehicle images.
     */
    @AuraEnabled(cacheable=true)
    public static List<Booking__c> getRecentBookings() {
        return [
            SELECT Id, Name, Customer__c, Customer__r.First_Name__c,
                   Customer__r.Last_Name__c, Customer__r.Phone__c,
                   Car__c, Car__r.Brand__c, Car__r.Car_Model__c,
                   Car__r.Car_Image_URL__c, Car__r.Registration_Number__c,
                   Start_Date__c, End_Date__c, Status__c, Total_Amount__c,
                   Booking_Type__c, Pickup_Location__c, Return_Location__c
            FROM Booking__c
            ORDER BY CreatedDate DESC
            LIMIT 10
        ];
    }

    /**
     * Get car status breakdown.
     */
    @AuraEnabled(cacheable=true)
    public static List<AggregateResult> getCarsByStatus() {
        return [
            SELECT Status__c, COUNT(Id) carCount
            FROM Car__c
            GROUP BY Status__c
        ];
    }
}
