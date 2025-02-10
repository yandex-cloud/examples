# How to run STT client in Docker

1. Build Docker image
```sh
docker build .
```

2. Provide YC_API_KEY to Docker container as environment variable
```sh
docker run -e YC_API_KEY=<YOUR_YC_API_KEY> <docker_image>
```
