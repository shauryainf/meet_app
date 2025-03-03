const mongoose = require('mongoose');

// Get MongoDB URI from environment variable or use default
const mongoURI = process.env.MONGODB_URI || 'mongodb://localhost:27017/videocall';

// Connect to MongoDB
const connectDB = async () => {
  try {
    console.log('Connecting to MongoDB...');
    await mongoose.connect(mongoURI, {
      useNewUrlParser: true,
      useUnifiedTopology: true,
    });
    console.log('MongoDB connected successfully');
  } catch (error) {
    console.error('MongoDB connection error:', error);
    process.exit(1);
  }
};

module.exports = connectDB; 