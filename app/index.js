// File: app/index.js

const express = require('express');
const app = express();
const PORT = process.env.PORT || 8080;

app.get('/', (req, res) => {
  
  res.send(`
    <h1>Hello from Node Server!</h1>
    <p>Deployed by: <b>Sithumi Jayarathna</b></p>
    <p>Student ID: 23ug1-0066 </p>
  `);
});

app.get('/health', (req, res) => {
  res.status(200).send('OK');
});

// Force listening on ALL network interfaces (0.0.0.0)
const server = app.listen(PORT, '0.0.0.0', () => {
  console.log(`Server is running on port ${PORT}`);
});

process.on('SIGTERM', () => {
  console.log('SIGTERM received. Shutting down gracefully.');
  server.close(() => {
    console.log('Process terminated.');
  });
});