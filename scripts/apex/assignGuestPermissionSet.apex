Id psId = [SELECT Id FROM PermissionSet WHERE Name = 'Car_Rental_Guest_Access' LIMIT 1].Id;
List<User> guestUsers = [SELECT Id, Name FROM User WHERE UserType = 'Guest' AND IsActive = true];

List<PermissionSetAssignment> toInsert = new List<PermissionSetAssignment>();
for (User u : guestUsers) {
    List<PermissionSetAssignment> existing = [SELECT Id FROM PermissionSetAssignment WHERE PermissionSetId = :psId AND AssigneeId = :u.Id];
    if (existing.isEmpty()) {
        toInsert.add(new PermissionSetAssignment(
            PermissionSetId = psId,
            AssigneeId = u.Id
        ));
        System.debug('Assigning Car_Rental_Guest_Access to ' + u.Name + ' (' + u.Id + ')');
    }
}

if (!toInsert.isEmpty()) {
    insert toInsert;
    System.debug('Successfully assigned permission set to ' + toInsert.size() + ' guest users.');
} else {
    System.debug('Guest users already have permission set assigned.');
}
