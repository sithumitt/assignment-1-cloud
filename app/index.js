const express = require('express');
const multer = require('multer');
const { S3Client, PutObjectCommand } = require('@aws-sdk/client-s3');

const app = express();
const PORT = 8080;

// 1. Configure AWS S3 Client
const s3 = new S3Client({ region: process.env.AWS_REGION || 'us-east-1' });
const BUCKET_NAME = process.env.BUCKET_NAME;

// 2. Configure Multer (Temp storage for uploads)
const storage = multer.memoryStorage();
const upload = multer({ storage: storage });

// Home Route with Upload Form
app.get('/', (req, res) => {
  res.send(`
    <h1>Hello from Node Server!</h1>
    <p>Deployed by: [YOUR NAME]</p>
    <hr>
    <h3>Upload a File to S3</h3>
    <form action="/upload" method="POST" enctype="multipart/form-data">
      <input type="file" name="file" required />
      <button type="submit">Upload</button>
    </form>
  `);
});

// Health Check
app.get('/health', (req, res) => {
  res.status(200).send('OK');
});

// Upload Route
app.post('/upload', upload.single('file'), async (req, res) => {
  if (!req.file || !BUCKET_NAME) {
    return res.status(400).send('Error: Missing file or Bucket configuration.');
  }

  try {
    const params = {
      Bucket: BUCKET_NAME,
      Key: `${Date.now()}_${req.file.originalname}`, // Unique filename
      Body: req.file.buffer,
      ContentType: req.file.mimetype,
    };

    await s3.send(new PutObjectCommand(params));
    res.send(`Successfully uploaded <b>${req.file.originalname}</b> to S3 bucket: ${BUCKET_NAME}`);
  } catch (error) {
    console.error(error);
    res.status(500).send('Error uploading to S3: ' + error.message);
  }
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`Server is running on port ${PORT}`);
});