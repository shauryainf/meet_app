const express = require('express');
const http = require('http');
const socketIo = require('socket.io');
const cors = require('cors');
const { v4: uuidv4 } = require('uuid');
const dotenv = require('dotenv');
const connectDB = require('./db/connection');
const Meeting = require('./models/Meeting');

// Load environment variables
dotenv.config();

// Create Express app
const app = express();
const server = http.createServer(app);

// Middleware
app.use(cors());
app.use(express.json());

// Create Socket.IO server
const io = socketIo(server, {
  cors: {
    origin: '*',
    methods: ['GET', 'POST'],
  },
});

// Connect to MongoDB
connectDB();

// In-memory storage for active connections
const activeConnections = new Map();

// Socket.IO connection handling
io.on('connection', (socket) => {
  console.log(`User connected: ${socket.id}`);

  // Join meeting
  socket.on('join-meeting', async ({ meetingCode, userName }) => {
    try {
      console.log(`${userName} is joining meeting ${meetingCode}`);
      
      // Find or create the meeting in MongoDB
      let meeting = await Meeting.findOne({ meetingCode });
      
      if (!meeting) {
        // Create new meeting if it doesn't exist
        meeting = new Meeting({
          meetingCode,
          participants: [],
          messages: [],
        });
      }
      
      // Add user to meeting participants
      const newParticipant = {
        userId: socket.id,
        userName,
        joinedAt: new Date(),
      };
      
      // Check if participant already exists and remove if so
      meeting.participants = meeting.participants.filter(
        (p) => p.userId !== socket.id
      );
      
      // Add the new participant
      meeting.participants.push(newParticipant);
      await meeting.save();
      
      // Join the socket to the meeting room
      socket.join(meetingCode);
      
      // Store user info in memory for quick access
      activeConnections.set(socket.id, {
        meetingCode,
        userName,
      });
      
      // Notify others in the meeting
      socket.to(meetingCode).emit('user-joined', {
        userId: socket.id,
        userName,
        participants: meeting.participants,
      });
      
      // Send meeting info to the joining user
      socket.emit('meeting-joined', {
        meetingCode,
        participants: meeting.participants,
      });
    } catch (error) {
      console.error('Error joining meeting:', error);
      socket.emit('error', { message: 'Failed to join meeting' });
    }
  });

  // Leave meeting
  socket.on('leave-meeting', async ({ meetingCode }) => {
    try {
      if (meetingCode) {
        // Remove user from meeting in MongoDB
        const meeting = await Meeting.findOne({ meetingCode });
        
        if (meeting) {
          // Remove participant
          meeting.participants = meeting.participants.filter(
            (p) => p.userId !== socket.id
          );
          await meeting.save();
          
          // Notify others
          socket.to(meetingCode).emit('user-left', {
            userId: socket.id,
            participants: meeting.participants,
          });
          
          // Leave the socket room
          socket.leave(meetingCode);
        }
      }
      
      // Remove from active connections
      activeConnections.delete(socket.id);
    } catch (error) {
      console.error('Error leaving meeting:', error);
    }
  });

  // WebRTC signaling: offer
  socket.on('offer', ({ targetId, sdp }) => {
    socket.to(targetId).emit('offer', {
      sdp,
      fromId: socket.id,
    });
  });

  // WebRTC signaling: answer
  socket.on('answer', ({ targetId, sdp }) => {
    socket.to(targetId).emit('answer', {
      sdp,
      fromId: socket.id,
    });
  });

  // WebRTC signaling: ICE candidate
  socket.on('ice-candidate', ({ targetId, candidate }) => {
    socket.to(targetId).emit('ice-candidate', {
      candidate,
      fromId: socket.id,
    });
  });

  // Chat message
  socket.on('chat-message', async ({ meetingCode, message }) => {
    try {
      if (meetingCode) {
        // Add message to the meeting in MongoDB
        const meeting = await Meeting.findOne({ meetingCode });
        
        if (meeting) {
          // Add message
          meeting.messages.push(message);
          await meeting.save();
          
          // Broadcast to everyone in the meeting
          io.to(meetingCode).emit('chat-message', message);
        }
      }
    } catch (error) {
      console.error('Error handling chat message:', error);
    }
  });

  // Handle disconnection
  socket.on('disconnect', async () => {
    console.log(`User disconnected: ${socket.id}`);
    
    try {
      // Get user's meeting from memory
      const userData = activeConnections.get(socket.id);
      
      if (userData && userData.meetingCode) {
        const { meetingCode } = userData;
        
        // Update MongoDB
        const meeting = await Meeting.findOne({ meetingCode });
        
        if (meeting) {
          // Remove participant
          meeting.participants = meeting.participants.filter(
            (p) => p.userId !== socket.id
          );
          await meeting.save();
          
          // Notify others in the meeting
          socket.to(meetingCode).emit('user-left', {
            userId: socket.id,
            participants: meeting.participants,
          });
        }
      }
      
      // Remove from active connections
      activeConnections.delete(socket.id);
    } catch (error) {
      console.error('Error handling disconnect:', error);
    }
  });
});

// API Routes
app.get('/', (req, res) => {
  res.send('Video Call Server is running');
});

// Create a new meeting
app.post('/api/meetings', async (req, res) => {
  try {
    const meetingCode = uuidv4().substring(0, 6);
    
    // Create new meeting in MongoDB
    const meeting = new Meeting({
      meetingCode,
      participants: [],
      messages: [],
    });
    
    await meeting.save();
    
    res.status(201).json({ meetingCode });
  } catch (error) {
    console.error('Error creating meeting:', error);
    res.status(500).json({ error: 'Failed to create meeting' });
  }
});

// Get meeting information
app.get('/api/meetings/:meetingCode', async (req, res) => {
  try {
    const { meetingCode } = req.params;
    
    // Find meeting in MongoDB
    const meeting = await Meeting.findOne({ meetingCode });
    
    if (!meeting) {
      return res.status(404).json({ error: 'Meeting not found' });
    }
    
    res.json({
      meetingCode: meeting.meetingCode,
      participants: meeting.participants,
      createdAt: meeting.createdAt,
    });
  } catch (error) {
    console.error('Error getting meeting:', error);
    res.status(500).json({ error: 'Failed to get meeting information' });
  }
});

// Health check endpoint will be added by the Dockerfile

// Start the server
const PORT = process.env.PORT || 3000;
server.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
}); 