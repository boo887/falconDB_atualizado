var express = require('express');
var router = express.Router();

/* GET users listing. */
router.get('/', function(req, res, next) {
  console.log("em ./routes/users.js"); 
  let users=[
    {
	  id: 1,
	  name: 'Ana',
	  url: 'https://what.ever.com',
	  age: 22,
	  nif: 123456789,
	  },
	  {
	  id: 2,
	  name: 'António',
	  url: 'https://i.dont.know.com',
	  age: 23,
	  nif: 234567890
	  }
   ];

   console.table( users );
   console.log( global.errors );

   res.send( users );

   //res.send('respond with a resource');
});

module.exports = router;

//http://localhost:3100/images/f.jpeg
//http://localhost:3100/users
