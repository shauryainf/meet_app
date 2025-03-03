FROM node:20-alpine

WORKDIR /app

# Copy package.json and package-lock.json
COPY package*.json ./

# Install dependencies
RUN npm install --production

# Copy the rest of the application
COPY . .

# Create a directory for persistent data
RUN mkdir -p /app/data

# Expose the port the app runs on
EXPOSE 3000

# Add a healthcheck endpoint to index.js (fix the syntax error with proper newlines)
RUN echo "" >> index.js && echo "" >> index.js && echo "app.get('/health', (req, res) => { res.status(200).send('OK'); });" >> index.js

# Command to run the application
CMD ["node", "index.js"] 