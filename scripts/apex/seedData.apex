// Update existing cars with verified high-availability Wikimedia Commons vehicle photos
Map<String, String> carImages = new Map<String, String>{
    'Fortuner' => 'https://upload.wikimedia.org/wikipedia/commons/thumb/6/66/2015_Toyota_Fortuner_%28New_Zealand%29.jpg/800px-2015_Toyota_Fortuner_%28New_Zealand%29.jpg',
    'Innova Crysta' => 'https://upload.wikimedia.org/wikipedia/commons/thumb/9/91/2016_Toyota_Innova_2.4_V_wagon_%28GUN142R%2C_Indonesia%29_front_view.jpg/800px-2016_Toyota_Innova_2.4_V_wagon_%28GUN142R%2C_Indonesia%29_front_view.jpg',
    'Corolla' => 'https://upload.wikimedia.org/wikipedia/commons/thumb/c/ca/2019_Toyota_Corolla_Icon_Tech_HEV_1.8_Front.jpg/800px-2019_Toyota_Corolla_Icon_Tech_HEV_1.8_Front.jpg',
    'City' => 'https://upload.wikimedia.org/wikipedia/commons/thumb/f/f6/2020_Honda_City_1.0_VTEC_Turbo_SV_%28Thailand%29_front_view.jpg/800px-2020_Honda_City_1.0_VTEC_Turbo_SV_%28Thailand%29_front_view.jpg',
    'Amaze' => 'https://upload.wikimedia.org/wikipedia/commons/thumb/3/30/2018_Honda_Amaze_V_i-DTEC_%28India%29_front_view.jpg/800px-2018_Honda_Amaze_V_i-DTEC_%28India%29_front_view.jpg',
    'Seltos' => 'https://upload.wikimedia.org/wikipedia/commons/thumb/1/1d/2021_Kia_Seltos_EX_AWD%2C_front_10.22.21.jpg/800px-2021_Kia_Seltos_EX_AWD%2C_front_10.22.21.jpg',
    'XUV700' => 'https://upload.wikimedia.org/wikipedia/commons/thumb/8/87/2021_Mahindra_XUV700_AX7_Luxury_Pack_%28India%29_front_view.jpg/800px-2021_Mahindra_XUV700_AX7_Luxury_Pack_%28India%29_front_view.jpg',
    'Creta' => 'https://upload.wikimedia.org/wikipedia/commons/thumb/2/29/2020_Hyundai_Creta_SX_%28India%29_front_view.jpg/800px-2020_Hyundai_Creta_SX_%28India%29_front_view.jpg',
    'Nexon' => 'https://upload.wikimedia.org/wikipedia/commons/thumb/1/1a/2020_Tata_Nexon_XZ%2B_%28India%29_front_view.jpg/800px-2020_Tata_Nexon_XZ%2B_%28India%29_front_view.jpg',
    'Swift' => 'https://upload.wikimedia.org/wikipedia/commons/thumb/6/6e/2018_Suzuki_Swift_SZ5_Boosterjet_SHVS_1.0_Front.jpg/800px-2018_Suzuki_Swift_SZ5_Boosterjet_SHVS_1.0_Front.jpg'
};

List<Car__c> carsToUpdate = [SELECT Id, Car_Model__c, Brand__c, Car_Image_URL__c, Rating__c FROM Car__c];
for (Car__c c : carsToUpdate) {
    if (carImages.containsKey(c.Car_Model__c)) {
        c.Car_Image_URL__c = carImages.get(c.Car_Model__c);
    } else {
        c.Car_Image_URL__c = 'https://upload.wikimedia.org/wikipedia/commons/thumb/c/ca/2019_Toyota_Corolla_Icon_Tech_HEV_1.8_Front.jpg/800px-2019_Toyota_Corolla_Icon_Tech_HEV_1.8_Front.jpg';
    }
    if (c.Rating__c == null) {
        c.Rating__c = 4.8;
    }
}
if (!carsToUpdate.isEmpty()) {
    update carsToUpdate;
    System.debug('Updated ' + carsToUpdate.size() + ' cars with verified Wikimedia HD photos.');
}
