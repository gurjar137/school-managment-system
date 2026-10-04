const ws = new WebSocket('ws://127.0.0.1:57663/devtools/page/B04643116C1D84A494A748984BB5B345');
const fs = require('fs');

ws.onopen = () => {
  ws.send(JSON.stringify({ id: 1, method: 'Page.captureScreenshot', params: { format: 'png' } }));
};

ws.onmessage = (e) => {
  const data = JSON.parse(e.data);
  if (data.result && data.result.data) {
    fs.writeFileSync('C:\\Users\\dharm\\.gemini\\antigravity\\brain\\31b71747-b77f-48d5-bb40-370d813207da\\scratch\\school_current_screen.png', Buffer.from(data.result.data, 'base64'));
    console.log('Screenshot saved!');
    ws.close();
    process.exit(0);
  }
};
