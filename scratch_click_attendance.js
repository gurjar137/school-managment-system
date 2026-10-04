const ws = new WebSocket('ws://127.0.0.1:61012/devtools/page/1E20E6513280A8BDB43A5961DC3A8140');
const fs = require('fs');

ws.onopen = () => {
  ws.send(JSON.stringify({ id: 1, method: 'Page.enable' }));
  // Click at (140, 430)
  ws.send(JSON.stringify({
    id: 2,
    method: 'Input.dispatchMouseEvent',
    params: { type: 'mousePressed', x: 140, y: 430, button: 'left', clickCount: 1 }
  }));
  ws.send(JSON.stringify({
    id: 3,
    method: 'Input.dispatchMouseEvent',
    params: { type: 'mouseReleased', x: 140, y: 430, button: 'left', clickCount: 1 }
  }));

  // Wait 1.5s for navigation and screenshot
  setTimeout(() => {
    ws.send(JSON.stringify({ id: 4, method: 'Page.captureScreenshot', params: { format: 'png' } }));
  }, 1500);
};

ws.onmessage = (e) => {
  const data = JSON.parse(e.data);
  if (data.id === 4 && data.result && data.result.data) {
    fs.writeFileSync('C:\\Users\\dharm\\.gemini\\antigravity\\brain\\31b71747-b77f-48d5-bb40-370d813207da\\scratch\\parent_attendance_screen_view.png', Buffer.from(data.result.data, 'base64'));
    console.log('Attendance screen captured!');
    ws.close();
    process.exit(0);
  }
};
