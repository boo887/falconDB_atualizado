const fs = require('fs');
const path = require('path');
const winston = require('winston');
const { Writable } = require('stream');

const LOGS_DIR = path.join(__dirname, '..', '..', 'logs');

if (!fs.existsSync(LOGS_DIR)) {
  fs.mkdirSync(LOGS_DIR);
}

const LEVELS = {
  levels: { error: 0, warn: 1, info: 2, debug: 3, trace: 4 },
  colors: { error: 'red', warn: 'yellow', info: 'green', debug: 'blue', trace: 'grey' }
};

winston.addColors(LEVELS.colors);

function makeSyncTransport(filename) {
  fs.writeFileSync(filename, '');
  const stream = new Writable({
    write(chunk, encoding, callback) {
      try { fs.appendFileSync(filename, chunk); } catch (_) {}
      callback();
    }
  });
  return new winston.transports.Stream({ stream });
}

function createLogger(filename) {
  return winston.createLogger({
    levels: LEVELS.levels,
    level: 'trace',
    format: winston.format.combine(
      winston.format.timestamp(),
      winston.format.simple()
    ),
    transports: [
      makeSyncTransport(path.join(LOGS_DIR, filename)),
      new winston.transports.Console({ level: 'info' })
    ]
  });
}

function createRaftLogger(filename) {
  return winston.createLogger({
    levels: LEVELS.levels,
    level: 'trace',
    format: winston.format.combine(
      winston.format.timestamp(),
      winston.format.simple()
    ),
    transports: [
      makeSyncTransport(path.join(LOGS_DIR, filename))
    ]
  });
}

module.exports = { createLogger, createRaftLogger };
