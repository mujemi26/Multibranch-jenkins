# Use an official base image
FROM nginx:alpine

# Set working directory in the container
WORKDIR /usr/share/nginx/html

# Copy files from your local machine to the container
COPY . .

# Expose port 80
EXPOSE 80

# Command to run when container starts
CMD ["nginx", "-g", "daemon off;"]
