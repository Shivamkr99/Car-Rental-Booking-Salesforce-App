/**
 * CarFleetController
 * Provides fleet management, real-time filtering, instant booking creation,
 * and car record persistence for the carFleetExplorer LWC.
 */
public inherited sharing class CarFleetController {

    public class CarWrapper {
        @AuraEnabled public Id id { get; set; }
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public String brand { get; set; }
        @AuraEnabled public String carModel { get; set; }
        @AuraEnabled public String carType { get; set; }
        @AuraEnabled public Decimal dailyRate { get; set; }
        @AuraEnabled public String fuelType { get; set; }
        @AuraEnabled public String transmission { get; set; }
        @AuraEnabled public Decimal seats { get; set; }
        @AuraEnabled public String status { get; set; }
        @AuraEnabled public String location { get; set; }
        @AuraEnabled public String imageUrl { get; set; }
        @AuraEnabled public Decimal rating { get; set; }
        @AuraEnabled public String registrationNumber { get; set; }
        @AuraEnabled public String description { get; set; }
        @AuraEnabled public Integer totalBookings { get; set; }
        @AuraEnabled public Boolean active { get; set; }
    }

    /**
     * Fetch all cars matching optional filter criteria.
     */
    @AuraEnabled(cacheable=true)
    public static List<CarWrapper> getFleetCars(
        String searchKey,
        String brand,
        String carType,
        String status,
        String fuelType,
        String transmission
    ) {
        String query = 'SELECT Id, Name, Brand__c, Car_Model__c, Car_Type__c, Daily_Rental_Rate__c, ' +
                       'Fuel_Type__c, Transmission__c, Seats__c, Status__c, Location__c, ' +
                       'Car_Image_URL__c, Rating__c, Registration_Number__c, Description__c, ' +
                       'Total_Bookings__c, Active__c ' +
                       'FROM Car__c WHERE Active__c = true ';

        if (String.isNotBlank(searchKey)) {
            String key = '%' + String.escapeSingleQuotes(searchKey.trim()) + '%';
            query += ' AND (Brand__c LIKE :key OR Car_Model__c LIKE :key OR Registration_Number__c LIKE :key OR Location__c LIKE :key)';
        }
        if (String.isNotBlank(brand) && brand != 'All') {
            query += ' AND Brand__c = :brand';
        }
        if (String.isNotBlank(carType) && carType != 'All') {
            query += ' AND Car_Type__c = :carType';
        }
        if (String.isNotBlank(status) && status != 'All') {
            query += ' AND Status__c = :status';
        }
        if (String.isNotBlank(fuelType) && fuelType != 'All') {
            query += ' AND Fuel_Type__c = :fuelType';
        }
        if (String.isNotBlank(transmission) && transmission != 'All') {
            query += ' AND Transmission__c = :transmission';
        }

        query += ' ORDER BY Brand__c ASC, Car_Model__c ASC';

        List<CarWrapper> results = new List<CarWrapper>();
        for (Car__c c : Database.query(query)) {
            CarWrapper w = new CarWrapper();
            w.id = c.Id;
            w.name = c.Name;
            w.brand = c.Brand__c;
            w.carModel = c.Car_Model__c;
            w.carType = c.Car_Type__c;
            w.dailyRate = c.Daily_Rental_Rate__c;
            w.fuelType = c.Fuel_Type__c;
            w.transmission = c.Transmission__c;
            w.seats = c.Seats__c;
            w.status = c.Status__c;
            w.location = c.Location__c;
            w.imageUrl = c.Car_Image_URL__c;
            w.rating = c.Rating__c != null ? c.Rating__c : 4.5;
            w.registrationNumber = c.Registration_Number__c;
            w.description = c.Description__c;
            w.totalBookings = c.Total_Bookings__c != null ? (Integer)c.Total_Bookings__c : 0;
            w.active = c.Active__c;
            results.add(w);
        }
        return results;
    }

    /**
     * Get distinct filter picklists for the fleet explorer.
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, List<String>> getFleetFilterOptions() {
        Map<String, List<String>> options = new Map<String, List<String>>();

        Set<String> brands = new Set<String>();
        Set<String> types = new Set<String>();
        Set<String> fuels = new Set<String>();
        Set<String> transmissions = new Set<String>();
        Set<String> locations = new Set<String>();

        for (Car__c c : [SELECT Brand__c, Car_Type__c, Fuel_Type__c, Transmission__c, Location__c FROM Car__c WHERE Active__c = true]) {
            if (String.isNotBlank(c.Brand__c)) brands.add(c.Brand__c);
            if (String.isNotBlank(c.Car_Type__c)) types.add(c.Car_Type__c);
            if (String.isNotBlank(c.Fuel_Type__c)) fuels.add(c.Fuel_Type__c);
            if (String.isNotBlank(c.Transmission__c)) transmissions.add(c.Transmission__c);
            if (String.isNotBlank(c.Location__c)) locations.add(c.Location__c);
        }

        options.put('brands', new List<String>(brands));
        options.put('types', new List<String>(types));
        options.put('fuels', new List<String>(fuels));
        options.put('transmissions', new List<String>(transmissions));
        options.put('locations', new List<String>(locations));
        return options;
    }

    /**
     * 1-Click Instant Booking Creation from the Fleet Explorer.
     */
    @AuraEnabled
    public static Booking__c createInstantBooking(
        Id carId,
        Id customerId,
        Date startDate,
        Date endDate,
        String pickupLocation,
        String returnLocation,
        String bookingType,
        String notes,
        Boolean isPaid,
        String paymentMethod
    ) {
        if (carId == null || customerId == null || startDate == null || endDate == null) {
            throw new AuraHandledException('Missing required booking details (Car, Customer, Start Date, or End Date).');
        }

        if (endDate < startDate) {
            throw new AuraHandledException('Return Date must be on or after Pickup Date.');
        }

        // Validate overlapping availability
        List<Booking__c> conflicts = [
            SELECT Id FROM Booking__c
            WHERE Car__c = :carId
              AND Status__c NOT IN ('Cancelled', 'Completed')
              AND Start_Date__c < :endDate
              AND End_Date__c > :startDate
        ];
        if (!conflicts.isEmpty()) {
            throw new AuraHandledException('This vehicle already has a confirmed booking for the selected dates.');
        }

        Car__c car = [SELECT Daily_Rental_Rate__c FROM Car__c WHERE Id = :carId LIMIT 1];
        Integer days = startDate.daysBetween(endDate);
        if (days <= 0) days = 1;
        Decimal totalAmount = (car.Daily_Rental_Rate__c != null ? car.Daily_Rental_Rate__c : 1500) * days;

        Booking__c newBooking = new Booking__c(
            Car__c = carId,
            Customer__c = customerId,
            Start_Date__c = startDate,
            End_Date__c = endDate,
            Pickup_Location__c = String.isNotBlank(pickupLocation) ? pickupLocation : 'Mumbai Airport',
            Return_Location__c = String.isNotBlank(returnLocation) ? returnLocation : (String.isNotBlank(pickupLocation) ? pickupLocation : 'Mumbai Airport'),
            Booking_Type__c = String.isNotBlank(bookingType) ? bookingType : 'Short Term',
            Booking_Notes__c = notes,
            Status__c = 'Confirmed',
            Total_Amount__c = totalAmount
        );
        insert newBooking;

        // Optionally create payment immediately
        if (isPaid == true) {
            Payment__c payment = new Payment__c(
                Booking__c = newBooking.Id,
                Amount__c = totalAmount,
                Payment_Date__c = Date.today(),
                Payment_Method__c = String.isNotBlank(paymentMethod) ? paymentMethod : 'UPI',
                Payment_Status__c = 'Paid',
                Transaction_Reference__c = 'TXN-' + System.currentTimeMillis()
            );
            insert payment;
        }

        return [SELECT Id, Name, Status__c, Total_Amount__c FROM Booking__c WHERE Id = :newBooking.Id];
    }

    /**
     * Add or edit a Car record.
     */
    @AuraEnabled
    public static Car__c saveCarRecord(Car__c car) {
        if (car == null) {
            throw new AuraHandledException('Car record cannot be null.');
        }
        upsert car;
        return car;
    }
}
