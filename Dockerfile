# 1. Build Stage: Use official Flutter image to build the app
FROM cirrusci/flutter:3.19.6 as builder

WORKDIR /app

# Copy pubspec and get dependencies first for caching
COPY pubspec.* ./
RUN flutter pub get

# Copy the rest of the application code
COPY . .

# Define ARG for API URL (will be passed by Render Environment Variable)
ARG API_URL="http://localhost:8080" # Default value for local build

# Build the web app, injecting the API URL
# Using html renderer as example
RUN flutter build web --web-renderer html --release --dart-define=API_BASE_URL=${https://listen-like-api.onrender.com/}


# 2. Serve Stage: Use a lightweight web server image (like nginx)
FROM nginx:stable-alpine

# Copy the built web app from the builder stage to nginx's web root
COPY --from=builder /app/build/web /usr/share/nginx/html

# Expose port 80 for nginx
EXPOSE 80

# Nginx default command runs automatically, serving files from /usr/share/nginx/html
# No explicit CMD needed here for standard nginx behavior