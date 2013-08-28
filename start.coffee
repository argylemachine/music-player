log		= require( "logging" ).from __filename
fs		= require "fs"
async		= require "async"
util		= require "util"
find		= require "find"
mp3info		= require "mp3info"
cradle		= require "cradle"
echonest	= require "echonest"

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
			# Check runtime['db'] for file['info']['id3']['artist'] and file['info']['id3']['title']...
			runtime['db'].view 'songs/by-artist-and-title', { key: [ file['info']['id3']['artist'], file['info']['id3']['title'] ] }, ( err, docs ) ->
				if err
					return cb err
	
				# If that document doesn't exist, query echonest and create it in the database..
				if docs.length isnt 0
					return cb null

				
				_doc = file['info']['id3']
				_doc.type = "song"

				log "#{_doc.artist}/#{_doc.title} .."

				# Query echonest and try to find that song..
				runtime['echonest'].song.search { "title": _doc['title'], "artist": _doc['artist'] }, ( err, res ) ->

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
		rate_limit = 5

		runtime['echonest'] = new echonest.Echonest { "api_key": config['echonest_api_key'], "rate_limit": rate_limit }

		return cb null

	, ( cb ) ->
		update_database cb

	], ( err, res ) ->
		if err
			log "Unable to startup: #{err}"
			process.exit 1
		log "Startup complete!"



