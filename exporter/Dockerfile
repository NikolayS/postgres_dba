# Build stage
FROM golang:1.21-alpine AS builder

# Install build dependencies
RUN apk add --no-cache git

# Set working directory
WORKDIR /app

# Copy go mod files
COPY go.mod go.sum ./

# Download dependencies
RUN go mod download

# Copy source code
COPY *.go ./

# Build the application
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o wal-g-exporter .

# Final stage
FROM alpine:latest

# Install runtime dependencies
RUN apk --no-cache add ca-certificates postgresql-client

# Create non-root user
RUN adduser -D -s /bin/sh exporter

# Set working directory
WORKDIR /home/exporter

# Copy binary from builder stage
COPY --from=builder /app/wal-g-exporter .

# Copy configuration file
COPY config.yaml .

# Change ownership to non-root user
RUN chown -R exporter:exporter /home/exporter

# Switch to non-root user
USER exporter

# Expose port
EXPOSE 9351

# Health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:9351/health || exit 1

# Set default command
CMD ["./wal-g-exporter"]