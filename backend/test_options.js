const mongoose = require('mongoose');
const GameConfig = require('./src/models/GameConfig');
const { serializeGameConfig } = require('./src/services/gameConfig.service');

async function test() {
  await mongoose.connect('mongodb://localhost:27017/matka_local');
  const gc = await GameConfig.findOne({ code: 'STANDARD_GAME_CONFIG' });
  const serialized = serializeGameConfig(gc, null);
  const panna = serialized.find(t => t.id === 'panna');
  const panaSubtype = panna.subtypes.find(s => s.id === 'pana');
  
  console.log(JSON.stringify(panaSubtype.options.slice(0, 5), null, 2));
  process.exit(0);
}
test();
