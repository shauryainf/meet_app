const mongoose = require('mongoose');

// Get MongoDB URI from environment variable or use default
const mongoURI = process.env.MONGODB_URI || 'mongodb://localhost:27017/videocall';

// Maximum number of connection attempts
const MAX_RETRIES = 5;
let retryCount = 0;

// Connect to MongoDB with retry logic
const connectDB = async () => {
  try {
    console.log('Connecting to MongoDB...');
    await mongoose.connect(mongoURI, {
      useNewUrlParser: true,
      useUnifiedTopology: true,
      serverSelectionTimeoutMS: 5000, // Timeout after 5s instead of 30s
    });
    console.log('MongoDB connected successfully');
    retryCount = 0; // Reset retry count on successful connection
  } catch (error) {
    console.error('MongoDB connection error:', error);
    
    // Implement retry with exponential backoff
    if (retryCount < MAX_RETRIES) {
      retryCount++;
      const delay = Math.pow(2, retryCount) * 1000; // Exponential backoff: 2s, 4s, 8s, 16s, 32s
      console.log(`Retrying connection (${retryCount}/${MAX_RETRIES}) in ${delay}ms...`);
      
      setTimeout(async () => {
        await connectDB();
      }, delay);
    } else {
      console.error(`Failed to connect to MongoDB after ${MAX_RETRIES} attempts`);
      process.exit(1);
    }
  }
};

module.exports = connectDB; 