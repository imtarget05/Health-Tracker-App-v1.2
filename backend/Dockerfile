FROM node:18-alpine

WORKDIR /usr/src/app

# install deps
COPY package.json package-lock.json ./
RUN npm ci --production

# copy source
COPY . ./

EXPOSE 5001

# create a non-root user for improved security and set ownership
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
RUN mkdir -p /usr/src/app/src/middleware/tmp && \
	chown -R appuser:appgroup /usr/src/app && chown -R appuser:appgroup /usr/src/app/src/middleware/tmp && \
	chmod -R a+rwx /usr/src/app/src/middleware/tmp || true

# default env will come from docker-compose or env file
USER appuser
CMD ["node", "src/index.js"]