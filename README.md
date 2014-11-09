Note about new development
==========================
As of November 2014 I'm starting to re-write this using [ember-cli](http://www.ember-cli.com/) and [PouchDB](http://pouchdb.com/). The system will be split into two parts, a server and a client.

Please see the [0.1.0 release](https://github.com/argylemachine/music-player/releases/tag/0.1.0) for the old code.

About
=====
[music-player](https://github.com/argylemachine/music-player) is a web based music player and visualization system. Instead of viewing a music library via a traditonal grid, a scatter plot graph is used. The position of each song is computed by using a [Principle Components Analysis](http://en.wikipedia.org/wiki/Principle_components_analysis). Basically the songs that have similar values for the selected properties are closer together.

A screenshot of the current system is below.
![Current Screenshot](https://raw.github.com/argylemachine/music-player/develop/screenshots/current.png "Current Screenshot")

Installation
============
### Requirements
 * [CouchDB](http://couchdb.apache.org/)
 * [NodeJS](http://nodejs.org/) >= 0.10.7

### Quick Overview
 * Install CouchDB
 * Check out the development version of [music-player](https://github.com/argylemachine/music-player)

 ```
 git clone https://github.com/argylemachine/music-player.git
 cd music-player
 git checkout develop
 ```


 * Get an API key from echonest. [Register Here](https://developer.echonest.com/account/register). I highly suggest applying for an upgraded account.
 * Modify config.json to suite.
 * Install required nodejs libraries. ( `npm install` ).
 * Run `start.coffee`.

License
=======
The code in this project is under the MIT license, unless otherwise stated. Note that the data retrieved from [echonest](http://echonest.com/) is bound by [its own license](http://developer.echonest.com/licensing.html).

Credits
=======
Original idea and inspiration came from [Music Box](http://thesis.flyingpudding.com/) by [Anita Shen Lillie](http://flyingpudding.com/).
