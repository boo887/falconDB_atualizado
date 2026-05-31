FROM node:22-alpine

WORKDIR /app

# Install bash (Alpine uses dash by default; bashrc uses bash-specific syntax)
RUN apk add --no-cache bash

# Install forever globally so it is on PATH in every container
RUN npm install -g forever

# Install all component deps in one step
COPY src/lib/package.json src/lib/
COPY src/reverseProxy/package.json src/reverseProxy/
COPY src/dataNode/package.json src/dataNode/
RUN cd src/lib && npm install && \
    cd /app/src/reverseProxy && npm install && \
    cd /app/src/dataNode && npm install

# Copy all source, config and control scripts
COPY src ./src
COPY etc ./etc
COPY bin ./bin

ENV APP_ROOT=/app
ENV PATH="${PATH}:/app/bin"

# Create runtime directories (winston logs, forever logs, DB data)
RUN mkdir -p /app/logs /app/DBdata

# Make all control scripts executable
RUN chmod +x \
    /app/bin/forever-start \
    /app/bin/falconDBd \
    /app/src/reverseProxy/bin/forever-start.sh \
    /app/src/reverseProxy/bin/forever-stop.sh \
    /app/src/dataNode/bin/forever-start.sh \
    /app/src/dataNode/bin/forever-stop.sh
