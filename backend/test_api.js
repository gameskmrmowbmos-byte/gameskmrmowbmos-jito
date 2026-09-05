const axios = require('axios');
const http = require('http');

async function test() {
  try {
    const res = await axios.get('http://localhost:5002/api/prints?page=1&limit=10&fromDate=2026-08-06&toDate=2026-08-13');
    console.log(res.data);
  } catch (err) {
    console.log("ERROR:", err.response ? err.response.data : err.message);
  }
}
test();
