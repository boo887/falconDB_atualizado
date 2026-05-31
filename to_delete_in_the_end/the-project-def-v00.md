I - The distributed DB system architecture - falconDB

  The system is made by:

  1 - A reverse proxy server (RP), the falconDB public entry point

  2 - A group of logical data nodes (DN),that receives data according to
      a established data sharding protocol, which are physically made of a
      pre-defined number of servers.
      Each DN has a master, elected using an election algorithm, in the case the
      raft.
      On the starting of a specific DN, an election must be executed after which
      the master tells RP its identity.
      The election must be logged in trace mode, and all phases of election
      must be added to the log in order to see and understand the election process.
      It is suggested that a raft.log for each DN server, where the election
      and the master identity send to RP by the master are logged.

  The above system is made of servers defined by file /app/etc/configure.json,
      present in all falconDB servers.

II - notes on the project

1 - use nodejs ecosystem with :
  a) express
  b) winston module to provide system logging
      i- errors are normalized according to the what is statted latter in this
         document.
     ii- error codes must have a normalized code reflecting in its name the
         system that it belongs to
  c) axios module to execute http requests between servers excluding, of course,
     the requests that are handled to the current master of a specific DN, sent
     via RP pass-through functions provided by the RP code.

  CRITICAL: the system architecture has already been provided and the only
            module that can be added is the raft, which means that no other
            architecture can be used as the result of a search in the 
            web or AI creation.

2 - two modules must be defined: 
    a) a wrapper for the log system, 
    b) a module for the crud actions on the FS, using the standard fs module.
       Each pair (key,value) will exist in directory /app/DBdata, inside
       a json file that has by name the md5sum of the key where the object:
         {"key":<key>,"value":<value>} exists.

       The <key> and <value> can be a string, a number or a flat json object.

3 - the system start/stop/restart/stat must be done via falconDBd command,
    a bash script that will start/stop/restart, in a pre defined sequence,
    the distributed DB.

4 - The CRUD write actions (CDU) must use a two phase commit algorithm to
    guarantee the system maintains  data integrity between the servers of 
    a node.

5 - All servers are kept alive using forever

6 - The routes 
    a) common to ALL servers are:

      Route             Method  Rest Description
      /status           get     pub  to return the system status
                                     (connect to each one of the DN masters
                                     and ask for the DN Status and then
                                     presents all the sentities status: the
                                     start time and the living time)
      /stat             get     pub  return the stats associated to the service:
                                     no each one of the CRUD operations from
                                     the current start of the DB service.
      /admin            -       -    the admin root route
      /admin/loglevel   get     prv  used to change the server dbglevel
      /db               -       -    the DB root route
      /db/c             post    pub  to Create a DB pair key:value
      /db/r             get     pub  to Read and return DB value associated to a key
      /db/u             post    pub  to Update a DB pair key:value; just send
                                     members of the object to be updated; new
                                     members can be added, as members can be
                                     deleted ( "member_name": "--delete--"
                                     or "member_name": "\-\-delete\-\-"
                                     if need to update or create to the
                                     value "--delete--" )
      /db/d             get     pub  to Delete  a DB pair key:value identified
                                     by the key
      /stop             get     RPt  To stop the node

    b) RP specific

      Route             Method  Rest Description
      /set_master       get     DNp  to be used by the elected master of a DN


    c) DN specific

      Route             Method  Rest Description
      /election         get     DNp  to exchange needed information to
                                     establish the master of the DN
      /maintenance      get     DNp  to exchange data to do all needed actions
                                     needed to make all data correctly 
                                     synchronized in each one of the DN servers.
      /any-other-needed ???     DNp  to perform any specific action that were
                                     not logically associated to the 2 previous
                                     pre-defined routes

      LEGEND:
             Rest - restriction of ORIGIN in the route
             RPo - (RPonly) - accept requests only from RP
             RPt - (RPtest) - accept requests only from RP.
                              BUT during presentation can receive request from
                              another host defined in configure.json in the 
                              member test_client_ip
             prv - private route to be used only if origin is the same server 
                   as the server that controls the route
             DNp - private route to be used only by any member of a DN

        NOTES: 
             1 - the routes db/[crud] are public in case of the RP, but for each 
                 server in a DN they are in fact RPt type,  
             2 - some restrictions can be redefined if needed to overcome any
                 detected ambiguity or imprecision .

7 - the normalized response for all servers
    All response is an object with the following architecture:

    a) object has two mandatory members: "data" and "error".
    b) Object in an error situation ("data" member is 0 (zero) ):

      {
        "data": 0,
        "error": {
          "code": "eRPMD023W",
          [ "errno": 10, ]
          "message": "the IP origin of the anouncing master has not the same IP"
        }
      }

    c) Object in an success situation ( "error" member is 0 (zero) ):
      {
        "data": {
          "DB_key": "bc9947a5071805493e7253c2af5d88c8",
          "DN_id": 0,
          "tuple": {
            "key": "mail@what.ever.com",
            "value": {
              "a": 123,
              "b": "text"
            }
          }
        },
        "error": 0
      }

8 - FS structure
    The FS structure has been provided in the information on w08
