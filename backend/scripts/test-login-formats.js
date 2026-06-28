const formats = [
  { phone: '+243999939477', pin: '1234' },
  { phone: '999939477', pin: '1234' },
  { phone: '0999939477', pin: '1234' },
  { phone: '243999939477', pin: '1234' },
  { phone: '+243 999 939 477', pin: '1234' },
];

async function testLogin(body) {
  const res = await fetch('http://127.0.0.1:3001/api/auth/login', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ ...body, deviceId: 'test' }),
  });
  const json = await res.json();
  const ok = res.status === 200 && json.access_token;
  console.log(`${body.phone.padEnd(20)} → ${res.status} ${ok ? 'OK' : JSON.stringify(json)}`);
}

async function main() {
  for (const f of formats) await testLogin(f);
}

main().catch(console.error);
