const ws = new WebSocket('ws://127.0.0.1:61012/devtools/page/1E20E6513280A8BDB43A5961DC3A8140');
const fs = require('fs');

ws.onopen = () => {
  setTimeout(() => {
    ws.send(JSON.stringify({ id: 1, method: 'Page.captureScreenshot', params: { format: 'png' } }));
  }, 1000);
};

ws.onmessage = (e) => {
  const data = JSON.parse(e.data);
  if (data.result && data.result.data) {
    fs.writeFileSync('C:\\Users\\dharm\\.gemini\\antigravity\\brain\\31b71747-b77f-48d5-bb40-370d813207da\\scratch\\parent_app_attendance_tab.png', Buffer.from(data.result.data, 'base64'));
    console.log('Parent App Attendance Tab captured!');
    process.exit(0);
  }
};
