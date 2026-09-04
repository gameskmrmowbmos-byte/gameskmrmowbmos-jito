require('dotenv').config();
const mongoose = require('mongoose');
const Market = require('../src/models/Market');
const User = require('../src/models/User');

const standardMarkets = [
  {
    name: 'Kalyan',
    code: 'KALYAN',
    openingTime: '16:30',
    closingTime: '18:30',
    resultTime: '18:45',
    description: 'Most popular main market',
  },
  {
    name: 'Milan Day',
    code: 'MILAND',
    openingTime: '15:00',
    closingTime: '17:00',
    resultTime: '17:15',
    description: 'Milan Day market',
  },
  {
    name: 'Milan Night',
    code: 'MILANN',
    openingTime: '21:00',
    closingTime: '23:00',
    resultTime: '23:15',
    description: 'Milan Night market',
  },
  {
    name: 'Rajdhani Day',
    code: 'RAJD',
    openingTime: '15:00',
    closingTime: '17:00',
    resultTime: '17:15',
    description: 'Rajdhani Day market',
  },
  {
    name: 'Rajdhani Night',
    code: 'RAJN',
    openingTime: '21:30',
    closingTime: '23:45',
    resultTime: '23:55',
    description: 'Rajdhani Night market',
  },
  {
    name: 'Main Mumbai',
    code: 'MMUMBAI',
    openingTime: '21:30',
    closingTime: '23:55',
    resultTime: '23:59',
    description: 'Historic and famous market',
  },
  {
    name: 'Sridevi',
    code: 'SRIDEVI',
    openingTime: '11:30',
    closingTime: '12:30',
    resultTime: '12:45',
    description: 'Popular daily market',
  }
];

async function addMarkets() {
  try {
    await mongoose.connect(process.env.MONGODB_URI);
    console.log('Connected to DB');

    const admin = await User.findOne({ role: 'admin' });
    if (!admin) {
      console.error('No admin user found to assign createdBy');
      process.exit(1);
    }

    for (const data of standardMarkets) {
      const exists = await Market.findOne({ code: data.code });
      if (!exists) {
        await Market.create({ ...data, createdBy: admin._id });
        console.log(`Added market: ${data.name}`);
      } else {
        console.log(`Market already exists: ${data.name}`);
      }
    }
    
    console.log('Done!');
    process.exit(0);
  } catch (err) {
    console.error(err);
    process.exit(1);
  }
}

addMarkets();
