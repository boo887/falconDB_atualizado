var express = require('express');
var router = express.Router();

/* GET home page. */
router.get('/', function(req, res, next) {
  //console.log( "==>>", Object.keys(req) );
  console.log( "==>> url:", req.url );
  console.log( "==>> query:", req.query );
  console.log( "==>> params:", req.params );
  res.render('index', { title: 'Express' });
});

module.exports = router;

/*
  '_readableState', 'readable',         '_events',
  '_eventsCount',   '_maxListeners',    'socket',
  'connection',     'httpVersionMajor', 'httpVersionMinor',
  'httpVersion',    'complete',         'headers',
  'rawHeaders',     'trailers',         'rawTrailers',
  'aborted',        'upgrade',          'url',
  'method',         'statusCode',       'statusMessage',
  'client',         '_consuming',       '_dumped',
  'next',           'baseUrl',          'originalUrl',
  '_parsedUrl',     'params',           'query',
  'res',            '_startAt',         '_startTime',
  '_remoteAddress', 'body',             'secret',
  'cookies',        'signedCookies',    '_parsedOriginalUrl',
  'route'
*/
