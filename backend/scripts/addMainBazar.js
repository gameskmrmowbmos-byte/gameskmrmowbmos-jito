require('dotenv').config();
const mongoose = require('mongoose');
const Market = require('../src/models/Market');
const User = require('../src/models/User');

const standardMarkets = [
  {
    name: 'Main Bazar',
    code: 'MAINBAZAR',
    openingTime: '21:35',
    closingTime: '00:05',
    resultTime: '00:15',
    description: 'Main Bazar night market',
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
