#!/bin/bash

# Exit on any error
set -e

# Print commands being executed
set -x

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "Docker is not installed. Please install Docker first."
    exit 1
fi

# Check if Docker Compose is installed
if ! command -v docker-compose &> /dev/null; then
    echo "Docker Compose is not installed. Please install Docker Compose first."
    exit 1
fi

# Build and start the containers
echo "Building and starting the application containers..."
docker-compose build --no-cache
docker-compose up -d

# Check if the containers are running
echo "Checking container status..."
docker-compose ps

# Print the logs
echo "Container logs:"
docker-compose logs

echo ""
echo "Deployment completed successfully!"
echo "The application should now be accessible at:"
echo "- Frontend: http://localhost"
echo "- Backend: http://localhost:3000"
echo ""
echo "If you're deploying to a server, make sure ports 80 and 3000 are open."
echo "For production use, it's recommended to set up HTTPS using a reverse proxy."
echo ""
echo "For more information, see the DEPLOYMENT.md file." 