const express = require('express');
const multer = require('multer');
const { S3Client, PutObjectCommand } = require('@aws-sdk/client-s3');
const path = require('path');

const app = express();
const PORT = 8080;

// 1. Serve Static Files (This lets the browser find your image)
app.use(express.static('public'));

// Configure AWS S3
const s3 = new S3Client({ region: process.env.AWS_REGION || 'us-east-1' });
const BUCKET_NAME = process.env.BUCKET_NAME;

// Configure Multer
const storage = multer.memoryStorage();
const upload = multer({ storage: storage });

app.get('/', (req, res) => {
  res.send(`
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Cloud Assignment</title>
      <style>
        body {
          /* 2. Use the local image */
          background: url('/background.png');
          background-size: cover;
          background-position: center;
          background-repeat: no-repeat;
          font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
          height: 100vh;
          margin: 0;
          padding: 40px;
          box-sizing: border-box;
        }

        .content {
          text-align: left;
          color: white;
        }

        h1 {
          font-size: 3em;
          margin: 0 0 10px 0;
          text-shadow: 2px 2px 4px #000000;
        }
        
        h2 {
          font-size: 2em;
          margin: 5px 0;
          font-weight: bold;
          text-shadow: 2px 2px 4px #000000;
        }

        form {
          margin-top: 40px;
        }

        input[type="file"] {
          display: block;
          margin-bottom: 15px;
          color: white;
          font-size: 1.2em;
          font-weight: bold;
        }

        button {
          background-color: #2196f3;
          color: white;
          border: none;
          padding: 15px 40px;
          font-size: 1.5em;
          font-weight: bold;
          border-radius: 8px;
          cursor: pointer;
          box-shadow: 0 4px 6px rgba(0,0,0,0.3);
          transition: transform 0.2s;
        }

        button:hover {
          transform: scale(1.05);
          background-color: #1976d2;
        }
      </style>
    </head>
    <body>
      <div class="content">
        <h1>Sithumi Jayarathna</h1>
        <h2>23ug1-0066</h2>
        <h2>Cloud Computing</h2>

        <form action="/upload" method="POST" enctype="multipart/form-data">
          <input type="file" name="file" required />
          <button type="submit">Upload File</button>
        </form>
      </div>
    </body>
    </html>
  `);
});

// Health Check
app.get('/health', (req, res) => {
  res.status(200).send('OK');
});

// Upload Logic
app.post('/upload', upload.single('file'), async (req, res) => {
  if (!req.file || !BUCKET_NAME) {
    return res.status(400).send('Error: Missing file or Bucket configuration.');
  }
  try {
    const params = {
      Bucket: BUCKET_NAME,
      Key: `${Date.now()}_${req.file.originalname}`,
      Body: req.file.buffer,
      ContentType: req.file.mimetype,
    };
    await s3.send(new PutObjectCommand(params));
    res.send(`
      <body style="background-color: #212121; color: white; font-family: sans-serif; text-align: center; padding-top: 50px;">
        <h1 style="color: #2196f3;">Success!</h1>
        <p style="font-size: 1.5em;">Successfully uploaded <b>${req.file.originalname}</b></p>
        <a href="/" style="color: #2196f3; font-size: 1.2em; text-decoration: none; border: 2px solid #2196f3; padding: 10px 20px; border-radius: 5px;">Go Back</a>
      </body>
    `);
  } catch (error) {
    console.error(error);
    res.status(500).send('Error uploading to S3: ' + error.message);
  }
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`Server is running on port ${PORT}`);
});