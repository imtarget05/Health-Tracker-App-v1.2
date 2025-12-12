FROM node:18-alpine

WORKDIR /usr/src/app

# install deps
COPY package.json package-lock.json ./
RUN npm ci --production

# copy source
COPY . ./

EXPOSE 5001

# default env will come from docker-compose or env file
CMD ["node", "src/index.js"]