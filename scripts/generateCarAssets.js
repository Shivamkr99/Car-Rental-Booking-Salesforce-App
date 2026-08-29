const fs = require('fs');
const path = require('path');

const carPhotosDir = path.join(__dirname, '..', 'Car Photos');

const mapping = [
    { key: 'Toyota Fortuner', file: 'Toyota Fortuner.avif', mime: 'image/avif' },
    { key: 'Toyota Innova Crysta', file: 'innova.avif', mime: 'image/avif' },
    { key: 'Toyota Corolla', file: 'corolla.jpg', mime: 'image/jpeg' },
    { key: 'Honda City', file: 'honda city.avif', mime: 'image/avif' },
    { key: 'Honda Amaze', file: 'Honda Amaze Golden.avif', mime: 'image/avif' },
    { key: 'Kia Seltos', file: 'kia seltos.avif', mime: 'image/avif' },
    { key: 'Mahindra XUV700', file: 'Mahindra xuv700.jpg', mime: 'image/jpeg' },
    { key: 'Hyundai Creta', file: 'Hyundai Creta.avif', mime: 'image/avif' },
    { key: 'Tata Nexon', file: 'Tata Nexon.avif', mime: 'image/avif' },
    { key: 'Maruti Swift', file: 'Maruti Suzuki Swift.avif', mime: 'image/avif' }
];

const assets = {};

mapping.forEach(item => {
    const filePath = path.join(carPhotosDir, item.file);
    if (fs.existsSync(filePath)) {
        const data = fs.readFileSync(filePath);
        const base64 = data.toString('base64');
        assets[item.key] = `data:${item.mime};base64,${base64}`;
        console.log(`✓ Loaded image for ${item.key} from ${item.file} (${data.length} bytes)`);
    } else {
        console.error(`✗ Missing file: ${item.file}`);
    }
});

const fileContent = `// Auto-generated Real Photo Asset Library from user-uploaded "Car Photos" folder
export const CAR_ASSETS = ${JSON.stringify(assets, null, 4)};

export function getCarImage(brand, model) {
    const cleanBrand = (brand || '').trim();
    const cleanModel = (model || '').trim();
    const key = \`\${cleanBrand} \${cleanModel}\`.trim();

    if (CAR_ASSETS[key]) return CAR_ASSETS[key];

    // Fuzzy matching by model or brand
    const searchStr = \`\${cleanBrand} \${cleanModel}\`.toLowerCase();
    for (const [name, dataUri] of Object.entries(CAR_ASSETS)) {
        const nameLower = name.toLowerCase();
        if (cleanModel && nameLower.includes(cleanModel.toLowerCase())) return dataUri;
        if (searchStr && (nameLower.includes(searchStr) || searchStr.includes(nameLower))) return dataUri;
    }

    return CAR_ASSETS['Toyota Fortuner'] || '';
}
`;

const targets = [
    path.join(__dirname, '..', 'force-app', 'main', 'default', 'lwc', 'carFleetExplorer', 'carImageAssets.js'),
    path.join(__dirname, '..', 'force-app', 'main', 'default', 'lwc', 'carRentalDashboard', 'carImageAssets.js'),
    path.join(__dirname, '..', 'force-app', 'main', 'default', 'lwc', 'bookingManagementHub', 'carImageAssets.js'),
    path.join(__dirname, '..', 'force-app', 'main', 'default', 'lwc', 'reviewsHub', 'carImageAssets.js')
];

targets.forEach(target => {
    fs.writeFileSync(target, fileContent, 'utf8');
    console.log(`Generated: ${target}`);
});

console.log('All car asset modules generated successfully!');
