const mongoose = require('mongoose');

const participantSchema = new mongoose.Schema({
  userId: {
    type: String,
    required: true,
  },
  userName: {
    type: String,
    required: true,
  },
  joinedAt: {
    type: Date,
    default: Date.now,
  },
});

const messageSchema = new mongoose.Schema({
  id: {
    type: String,
    required: true,
  },
  senderId: {
    type: String,
    required: true,
  },
  senderName: {
    type: String,
    required: true,
  },
  content: {
    type: String,
    required: true,
  },
  timestamp: {
    type: Number,
    default: () => Date.now(),
  },
});

const meetingSchema = new mongoose.Schema({
  meetingCode: {
    type: String,
    required: true,
    unique: true,
    index: true,
  },
  createdAt: {
    type: Date,
    default: Date.now,
  },
  participants: [participantSchema],
  messages: [messageSchema],
  lastActivity: {
    type: Date,
    default: Date.now,
  },
});

// Update lastActivity timestamp on save
meetingSchema.pre('save', function (next) {
  this.lastActivity = new Date();
  next();
});

const Meeting = mongoose.model('Meeting', meetingSchema);

module.exports = Meeting; 