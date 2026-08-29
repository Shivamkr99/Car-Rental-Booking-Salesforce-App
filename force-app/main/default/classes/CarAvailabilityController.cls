/**
 * CarAvailabilityController
 * Provides search functionality for finding available cars
 * based on location, date range, and car type.
 * Used by the carAvailabilitySearch LWC component.
 */
public inherited sharing class CarAvailabilityController {

    /**
     * Search for available cars based on criteria.
     * A car is "available" if:
     *   1. Its Status__c is 'Available'
     *   2. No existing booking overlaps the requested date range
     *
     * @param location  - The pickup location (optional filter)
     * @param startDate - Desired pickup date
     * @param endDate   - Desired return date
     * @param carType   - Car type filter: SUV, Sedan, etc. (optional)
     */
    @AuraEnabled(cacheable=true)
    public static List<Car__c> searchAvailableCars(
        String location,
        Date startDate,
        Date endDate,
        String carType
    ) {
        // Build dynamic query for cars
        String query = 'SELECT Id, Name, Brand__c, Car_Model__c, Car_Type__c, ' +
                        'Daily_Rental_Rate__c, Fuel_Type__c, Transmission__c, ' +
                        'Seats__c, Status__c, Location__c, Car_Image_URL__c, ' +
                        'Rating__c, Registration_Number__c ' +
                        'FROM Car__c WHERE Status__c = \'Available\' AND Active__c = true';

        // Apply location filter
        if (String.isNotBlank(location)) {
            query += ' AND Location__c = :location';
        }

        // Apply car type filter
        if (String.isNotBlank(carType)) {
            query += ' AND Car_Type__c = :carType';
        }

        query += ' ORDER BY Daily_Rental_Rate__c ASC';

        List<Car__c> availableCars = Database.query(query);

        // If date range is specified, exclude cars with overlapping bookings
        if (startDate != null && endDate != null && !availableCars.isEmpty()) {
            Set<Id> carIds = new Set<Id>();
            for (Car__c c : availableCars) {
                carIds.add(c.Id);
            }

            // Find cars that have overlapping bookings
            Set<Id> bookedCarIds = new Set<Id>();
            for (Booking__c b : [
                SELECT Car__c
                FROM Booking__c
                WHERE Car__c IN :carIds
                  AND Status__c NOT IN ('Cancelled', 'Completed')
                  AND Start_Date__c < :endDate
                  AND End_Date__c > :startDate
            ]) {
                bookedCarIds.add(b.Car__c);
            }

            // Filter out booked cars
            List<Car__c> result = new List<Car__c>();
            for (Car__c c : availableCars) {
                if (!bookedCarIds.contains(c.Id)) {
                    result.add(c);
                }
            }
            return result;
        }

        return availableCars;
    }

    /**
     * Get distinct locations from existing cars for the location filter picklist.
     */
    @AuraEnabled(cacheable=true)
    public static List<String> getAvailableLocations() {
        List<String> locations = new List<String>();
        for (AggregateResult ar : [
            SELECT Location__c loc
            FROM Car__c
            WHERE Location__c != null
            GROUP BY Location__c
            ORDER BY Location__c
        ]) {
            locations.add((String) ar.get('loc'));
        }
        return locations;
    }

    /**
     * Get distinct car types for the car type filter picklist.
     */
    @AuraEnabled(cacheable=true)
    public static List<String> getCarTypes() {
        List<String> types = new List<String>();
        for (AggregateResult ar : [
            SELECT Car_Type__c ctype
            FROM Car__c
            WHERE Car_Type__c != null
            GROUP BY Car_Type__c
            ORDER BY Car_Type__c
        ]) {
            types.add((String) ar.get('ctype'));
        }
        return types;
    }
}
