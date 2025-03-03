const express = require('express');
const http = require('http');
const socketIo = require('socket.io');
const cors = require('cors');
const fs = require('fs');
const path = require('path');
const { v4: uuidv4 } = require('uuid');

// Initialize Express app
const app = express();
app.use(cors());
app.use(express.json());

// Create HTTP server
const server = http.createServer(app);

// Initialize Socket.IO
const io = socketIo(server, {
  cors: {
    origin: "*",
    methods: ["GET", "POST"]
  }
});

// File to store meetings data
const MEETINGS_FILE = path.join(__dirname, 'meetings.json');

// In-memory meetings data
let meetings = {};

// Load meetings from file on startup
function loadMeetings() {
  try {
    if (fs.existsSync(MEETINGS_FILE)) {
      const data = fs.readFileSync(MEETINGS_FILE, 'utf8');
      meetings = JSON.parse(data);
      console.log(`Loaded ${Object.keys(meetings).length} meetings from file`);
    } else {
      console.log('No meetings file found, starting with empty meetings');
      meetings = {};
    }
  } catch (err) {
    console.error('Error loading meetings file:', err);
    meetings = {};
  }
}

// Save meetings to file
function saveMeetings() {
  try {
    fs.writeFileSync(MEETINGS_FILE, JSON.stringify(meetings, null, 2), 'utf8');
    console.log(`Saved ${Object.keys(meetings).length} meetings to file`);
  } catch (err) {
    console.error('Error saving meetings file:', err);
  }
}

// Generate a unique 6-digit meeting code
function generateMeetingCode() {
  // Generate a random 6-digit number
  const code = Math.floor(100000 + Math.random() * 900000).toString();
  
  // Check if code already exists
  if (meetings[code]) {
    return generateMeetingCode(); // Recursively try again
  }
  
  return code;
}

// Clean up old meetings (older than 24 hours)
function cleanupOldMeetings() {
  const now = Date.now();
  const oneDayMs = 24 * 60 * 60 * 1000;
  let cleaned = 0;
  
  for (const code in meetings) {
    const meeting = meetings[code];
    if (now - meeting.createdAt > oneDayMs) {
      delete meetings[code];
      cleaned++;
    }
  }
  
  if (cleaned > 0) {
    console.log(`Cleaned up ${cleaned} old meetings`);
    saveMeetings();
  }
}

// API routes
app.post('/api/meetings', (req, res) => {
  const code = generateMeetingCode();
  
  meetings[code] = {
    code,
    createdAt: Date.now(),
    participants: [],
    messages: []
  };
  
  saveMeetings();
  
  res.json({
    success: true,
    meetingCode: code
  });
});

app.get('/api/meetings/:code', (req, res) => {
  const { code } = req.params;
  const exists = !!meetings[code];
  
  res.json({
    success: true,
    exists
  });
});

app.get('/api/meetings/:code/messages', (req, res) => {
  const { code } = req.params;
  const meeting = meetings[code];
  
  if (!meeting) {
    return res.json({
      success: false,
      error: 'Meeting not found'
    });
  }
  
  res.json({
    success: true,
    messages: meeting.messages
  });
});

// Socket.IO connection handling
io.on('connection', (socket) => {
  console.log(`New client connected: ${socket.id}`);
  
  // Join a meeting
  socket.on('join-meeting', (data) => {
    const { meetingCode, userName } = data;
    
    // Validate meeting code
    if (!meetings[meetingCode]) {
      // Create meeting if it doesn't exist
      meetings[meetingCode] = {
        code: meetingCode,
        createdAt: Date.now(),
        participants: [],
        messages: []
      };
    }
    
    // Add user to meeting
    const participant = {
      id: socket.id,
      name: userName,
      joinedAt: Date.now()
    };
    
    // Remove any previous entries for this socket ID
    meetings[meetingCode].participants = meetings[meetingCode].participants.filter(
      p => p.id !== socket.id
    );
    
    // Add the new participant
    meetings[meetingCode].participants.push(participant);
    
    // Join the socket room
    socket.join(meetingCode);
    
    // Save to users room map for quick lookup
    socket.meetingCode = meetingCode;
    
    // Notify everyone in the meeting
    io.to(meetingCode).emit('user-joined', {
      userId: socket.id,
      participants: meetings[meetingCode].participants
    });
    
    // Notify the user who joined
    socket.emit('meeting-joined', {
      meetingCode,
      participants: meetings[meetingCode].participants
    });
    
    console.log(`User ${userName} (${socket.id}) joined meeting ${meetingCode}`);
    saveMeetings();
  });
  
  // WebRTC signaling: Offer
  socket.on('offer', (data) => {
    const { targetId, sdp } = data;
    
    io.to(targetId).emit('offer', {
      fromId: socket.id,
      sdp
    });
  });
  
  // WebRTC signaling: Answer
  socket.on('answer', (data) => {
    const { targetId, sdp } = data;
    
    io.to(targetId).emit('answer', {
      fromId: socket.id,
      sdp
    });
  });
  
  // WebRTC signaling: ICE Candidate
  socket.on('ice-candidate', (data) => {
    const { targetId, candidate } = data;
    
    io.to(targetId).emit('ice-candidate', {
      fromId: socket.id,
      candidate
    });
  });
  
  // Chat message
  socket.on('chat-message', (data) => {
    const { meetingCode, message } = data;
    
    if (!meetings[meetingCode]) {
      return;
    }
    
    // Add timestamp if not provided
    if (!message.timestamp) {
      message.timestamp = Date.now();
    }
    
    // Add message to meeting
    meetings[meetingCode].messages.push(message);
    
    // Broadcast to all participants
    io.to(meetingCode).emit('chat-message', message);
    
    saveMeetings();
  });
  
  // Leave meeting
  socket.on('leave-meeting', (data) => {
    handleUserDisconnect(socket, data.meetingCode);
  });
  
  // Handle disconnection
  socket.on('disconnect', () => {
    console.log(`Client disconnected: ${socket.id}`);
    handleUserDisconnect(socket, socket.meetingCode);
  });
  
  // Helper function to handle user disconnect/leave
  function handleUserDisconnect(socket, meetingCode) {
    if (!meetingCode || !meetings[meetingCode]) {
      return;
    }
    
    // Remove user from meeting
    meetings[meetingCode].participants = meetings[meetingCode].participants.filter(
      p => p.id !== socket.id
    );
    
    // Notify everyone in the meeting
    io.to(meetingCode).emit('user-left', {
      userId: socket.id,
      participants: meetings[meetingCode].participants
    });
    
    // Remove the socket from the room
    socket.leave(meetingCode);
    
    // Clean up empty meetings
    if (meetings[meetingCode].participants.length === 0) {
      console.log(`Meeting ${meetingCode} is empty, marking for cleanup`);
    }
    
    saveMeetings();
  }
});

// Start the server
const PORT = process.env.PORT || 3000;
server.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
  loadMeetings();
  
  // Clean up old meetings every hour
  setInterval(cleanupOldMeetings, 60 * 60 * 1000);
}); 