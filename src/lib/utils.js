"use strict";

global.axios = require( "axios" );
global.luxon = require( "luxon" );

global.Jstr  = s => JSON.stringify(s,null,2);
global.Jstr0 = s => JSON.stringify(s);
global.now = Date.now;
global.exit = process.exit;

var dns = require('dns');

var Utils ={};
Utils.luxon = global.luxon;

async function my_axios_get( url, options, stat=-1 ){
  let my_resp;
  try{
    my_resp = await axios.get( url, options );
    let data = ( "data" in my_resp ? my_resp.data : "data.not-in-resp");
    //console.log( "my_axios_get:", {url,  data });

    if( (-1 != stat) && Array.isArray(stat)){
      stat.push( data );
    }
    return 0;
  }catch(err){
    console.log( "my_axios_get => error:", err );
    return err;
  }
}
Utils.my_axios_get = my_axios_get;

function getClientIP(req) {   
  let ip_s =  (    req.headers['x-forwarded-for']
                || req.headers['cf-connecting-ip']
                || req.socket.remoteAddress
                || '').split(',')[0]?.trim();
  let s = ip_s.split(':');
  let n = s.length;
  return s[ n-1 ];
}
Utils.getClientIP = getClientIP;


function ip2host( ip, cb ){   
  dns.reverse( ip, function(err, hostnames){
    //console.log( "ip2host:", {ip, hostnames} );
    cb( ( Array.isArray(hostnames)
	  ? ( hostnames[0] ? hostnames[0] : "undef" )
	  : "undef"
        ) );
  });
}
Utils.ip2host = ip2host;

/*
   rp     =>  rp.w08_upt
   dn0-s0 => dn0s0.w08_upt
*/
function ip2hostSync( ip ){
  return new Promise((resolve) => {
    ip2host( ip, (host) => resolve(host) );
  });
}
Utils.ip2hostSync = ip2hostSync;

module.exports = Utils;
