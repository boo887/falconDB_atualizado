#!/usr/bin/env node

function normalizeKey(input) {
  try {
    const obj = JSON.parse(input);
    if (typeof obj === 'object' && obj !== null && !Array.isArray(obj)) {
      const sorted = Object.entries(obj).sort((a, b) => a[0].localeCompare(b[0]));
      return JSON.stringify(Object.fromEntries(sorted));
    }
  } catch (_) {}
  return input;
}

// When called with an argument: output just the encoded key (for use in scripts)
if (process.argv[2]) {
  const key = process.argv[2];
  const normalized = normalizeKey(key);
  process.stdout.write(encodeURIComponent(normalized));
  process.exit(0);
}

// When called with no argument: demo mode
let key = {
  "a":"hello",
  "b":"world hi",
  "c":12345
};

let key1 = {
  "b":"world hi",
  "a":"hello",
  "c":12345
};

console.log( Object.keys(key1));
console.log( Object.values(key1));
console.log( Object.entries(key1));
console.log( JSON.stringify( Object.entries(key1)));

let str  = normalizeKey(JSON.stringify(key));
let str1 = normalizeKey(JSON.stringify(key1));

let enc_str  = encodeURIComponent( str );
let enc_str1 = encodeURIComponent( str1 );

let url  = `http://localhost:8000/db/c?key=${enc_str}`;
let url1 = `http://localhost:8000/db/r?key=${enc_str1}`;
let url2 = `http://localhost:8000/db/u?key=${enc_str}`;  // value goes on body
let url3 = `http://localhost:8000/db/d?key=${enc_str}`;

console.log( key );
console.log( str );
console.log( enc_str );
console.log( '' );
console.log( 'key and key1 produce same encoded string:', enc_str === enc_str1 );
console.log( '' );
console.log( url );
console.log( url1 );
console.log( url2 );
console.log( url3 );
