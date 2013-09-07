log		= require( "logging" ).from __filename
fs		= require "fs"
async		= require "async"
util		= require "util"
find		= require "find"
mp3info		= require "mp3info"
cradle		= require "cradle"
echonest	= require "echonest"
http		= require "http"
express		= require "express"
sylvester	= require "sylvester"

config	= { }
runtime	= { }

update_database = ( cb ) ->
	log "Updating the database.."
	
	async.waterfall [ ( cb ) ->
		log "Searching for mp3 files.."

		async.map config['directories'], ( directory, cb ) ->
			find.file /\.mp3/, directory, ( files ) ->
				return cb null, files

		, ( err, file_arrays ) ->
			_r = [ ]
			async.each file_arrays, ( file_array, cb ) ->
				for file in file_array
					if file in _r
						continue
					_r.push file

				cb null
			, ( err ) ->
				cb null, _r

	
	, ( files, cb ) ->
		log "Scraping metadata of files.."
		async.map files, ( file, cb ) ->
			mp3info file, ( err, file_info ) ->
				if err
					return cb err

				cb null, { "path": file, "info": file_info }
		, ( err, file_infos ) ->
			if err
				return cb err
			return cb null, file_infos

	, ( files, cb ) ->
		log "Verifying database records."
		
		async.each files, ( file, cb ) ->

			# Sanity check to make sure the file_info contains at least a title and artist..
			# For now just skip the files that do not match.. 
			for req, reg of { "artist": /[a-zA-Z]/, "title": /[a-zA-Z]/ }
				if not file['info']['id3'][req]? or not file['info']['id3'][req].match reg
					log "Skipping invalid ID3 tagged file #{file['path']}.."
					return cb null

			# Check runtime['db'] for file['info']['id3']['artist'] and file['info']['id3']['title']...
			runtime['db'].view 'songs/by-artist-and-title', { key: [ file['info']['id3']['artist'], file['info']['id3']['title'] ] }, ( err, docs ) ->
				if err
					return cb err
	
				# If that document doesn't exist, query echonest and create it in the database..
				if docs.length isnt 0
					return cb null
				
				_doc = file['info']['id3']
				_doc.type	= "song"
				_doc.path	= file['path']

				# Query echonest and try to find that song..
				runtime['echonest'].song.search { "title": _doc['title'], "artist": _doc['artist'] }, ( err, res ) ->

					log "#{_doc.artist}/#{_doc.title} - search."

					# Boolean to handle if we should query for that song ident..
					next_query = true
					if err
						next_query = false

					if not res.songs? or res.songs.length < 1
						next_query = false

					# If we weren't able to find the correct song on echonest, then simply save the doc we have..
					if not next_query
						runtime['db'].save _doc, ( err, res ) ->
							if err
								return cb err
							return cb null

						return

					# Make the request for the audio summary for the particular song on echonest.
					runtime['echonest'].song.profile { "id": res.songs[0].id, "bucket": "audio_summary" }, ( err, res ) ->

							log "#{_doc.artist}/#{_doc.title} - audio_summary."
							
							# Again, simple boolean flag regarding if we found the audio summary..
							found_summary = true
							if err
								found_summary = false

							if ( not res.songs? ) or res.songs.length < 1
								found_summary = false
		
							# Shove the results we got from the audio summary into the doc to save..
							if found_summary
								for key, val of res.songs[0].audio_summary
									_doc[key] = val
							else
								log "Not able to find the audio summary."
							
							# Save the doc.
							runtime['db'].save _doc, ( err, res ) ->
								if err
									return cb err
								return cb null

		# This is the cb for async.each
		, ( err ) ->
			if err
				return cb err
			return cb null

	], ( err ) ->
		log "Done updating the database.."
		return cb null


start_webserver = ( cb ) ->

	app = express( )

	app.use express.logger( )
	app.use express.static __dirname + "/static"

	_error_out = ( res, err ) ->
		res.json { "error": err }

	app.param "id", ( req, res, cb, id ) ->
		runtime['db'].get id, ( err, doc ) ->
			if err
				return cb "not_found"
			req.doc = doc
			cb null

	app.get "/songs", ( req, res ) ->
		runtime['db'].view "songs/by-artist-and-title", ( err, docs ) ->
			if err
				return _error_out res, err

			res.json (doc.value for doc in docs)

	app.get "/artists", ( req, res ) ->
		runtime['db'].view "songs/null-by-artist", { group: true, reduce: true }, ( err, docs ) ->
			if err
				return _error_out res, err

			res.json ( doc.key for doc in docs )

	app.get "/pca/basic", ( req, res ) ->
		# This returns a list of objects.
		# The objects contain track information, such as title, artist, as well
		# as x and y which are computed using PCA on the features that are specified.

		# The 'pca' keyword is used to specify what attributes we want to perform the PCA on.
		attrs = req.query.pca

		# Force at least a single attribute to be specified.
		if not attrs
			return _error_out res, "No pca specified."
		
		# This just gets a list of documents from the CouchDB server. The view isn't important at this point.
		runtime['db'].view "songs/by-artist-and-title", ( err, docs ) ->

			# Error out if we get an error back from CouchDB.
			if err
				return _error_out res, err

			valid_docs = [ ]

			# Iterate over all the documents we got back. Ensure the attributes
			# that we're looking for exist. Populate the valid_docs array.
			for doc in (doc.value for doc in docs)
				# Sanity check on each doc. Make sure it has the attributes requested..
				skip = false
				for attr in attrs
					if not doc[attr]?
						skip = true
						break

				# If we should skip this document, continue with the next doc.
				if skip
					continue

				valid_docs.push doc

			# Go through each attribute that was specified.
			for attr in attrs

				# Calculate the mean of the attribute for all docs in valid_docs.
				sum = 0
				for doc in valid_docs
					sum += doc[attr]
				mean = ( sum / valid_docs.length )
				
				# Calculate the standard deviation.
				squared_diff_sum = 0
				for doc in valid_docs
					squared_diff_sum += Math.pow( ( doc[attr] - mean ), 2 )
				standard_deviation = Math.sqrt( squared_diff_sum / valid_docs.length )

				# Now that we have the mean and standard deviation for the attribute, run through 
				# each doc in valid_docs and compute the normalized attribute.
				for doc in valid_docs
					doc["normalized_" + attr] = doc[attr] - mean
					doc["normalized_" + attr] = doc["normalized_" + attr] / standard_deviation

			# We've normalized the data at this point, so each doc contains ["normalized_"+attr] for
			# each attr in attrs. At this point, generate a quick matrix using arrays so that we
			# can use the sylvester module to compute the PCA.

			matrix = [ ]
			for doc in valid_docs
				_i = [ ]
				for attr in attrs
					_i.push doc["normalized_"+attr]
				matrix.push _i

			# Project into 2 dimensions..
			svd	= sylvester.Matrix.create matrix
			k	= svd.pcaProject 2

			for i in [0..valid_docs.length-1]
				valid_docs[i].x = k.Z.elements[i][0]
				valid_docs[i].y = k.Z.elements[i][1]
			
			res.json valid_docs

	app.get "/song/:id", ( req, res ) ->
		res.sendfile req.doc.path
			
	app.get "/", ( req, res ) ->
		res.redirect "/index.html"
	
	web_server = http.createServer app

	web_server.listen config['port'], ( ) ->
		log "Started the web server.."
		return cb null


async.series [ ( cb ) ->
		log "Parsing config.."
		fs.readFile "config.json", ( err, data ) ->
			if err
				return cb err
			try
				config = JSON.parse data
				return cb null
			catch err
				return cb err
	, ( cb ) ->
		log "Validating config.."
		async.map [ "database_url", "database_port", "database_db", "port", "directories", "echonest_api_key" ], ( req, cb ) ->
			if not config[req]?
				return cb "Field #{req} not found."
			cb null
		, ( err, res ) ->
			if err
				return cb err
			cb null

	, ( cb ) ->
		log "Setting up database connection."
		db = new (cradle.Connection)( config['database_url'], config['database_port'], { "cache": false } ).database config['database_db']

		db.exists ( err, exists ) ->
			if err
				return cb err

			runtime['db'] = db

			if not exists
				db.create( )
				return cb null

			return cb null
	, ( cb ) ->
		log "Validating database views."

		# Grab the design document..
		runtime['db'].get "_design/songs", ( err, doc ) ->
			if err and err.error is "not_found"
				runtime['db'].save "_design/songs", {
					"by-artist-and-title": {
						"map": ( doc ) ->
							if doc.type is "song" and doc.artist and doc.title
								emit [ doc.artist, doc.title ], doc
					},
					"null-by-artist": {
						"map": ( doc ) ->
							if doc.type is "song" and doc.artist
								emit doc.artist, null

						,"reduce": "_count"
					}
				}, ( err, res ) ->
					if err
						return cb err
					
					return cb null
			
			else if err
				return cb err
			else
				return cb null

	, ( cb ) ->
		log "Setting up new echonest connection handler.."

		# Get rate_limit by doing a quick http query to echonest and parsing the header..
		#TODO
		# Note that the rate limit in the echonest library is the time ( in ms ) between requests, so we generate
		# it by dividing a minute by the number of requests we're allowed to run in a minute ( with a buffer ).
		rate_limit = 60000/100

		runtime['echonest'] = new echonest.Echonest { "api_key": config['echonest_api_key'], "rate_limit": rate_limit }

		return cb null

	, update_database

	, start_webserver

	], ( err, res ) ->
		if err
			log "Unable to startup: #{err}"
			process.exit 1
		log "Startup complete!"



