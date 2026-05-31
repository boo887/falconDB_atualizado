const crypto = require('crypto');

function getDN(key, totalDNs) {

  const hash = crypto.createHash('md5').update(key).digest('hex');

  const number = parseInt(
    hash.substring(0, 8),
    16
  );

  return number % totalDNs;
}

module.exports = {
  getDN
};
