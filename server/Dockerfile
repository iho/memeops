# Start from the official Golang image
FROM golang:1.21

# Set the current working directory inside the container
WORKDIR /app

# Copy the go mod and sum files to download dependencies
COPY go.mod go.sum ./

# Download dependencies
RUN go mod download

# Copy the entire project
COPY . .

# Build the application
RUN go build -o main .

# This command runs the application
CMD ["./main"]