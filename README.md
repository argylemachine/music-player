Note about new development
==========================
As of November 2014 I'm starting to re-write this using [ember-cli](http://www.ember-cli.com/) and [PouchDB](http://pouchdb.com/). The system will be split into two parts, a server and a client.

Please see the [0.1.0 release](https://github.com/argylemachine/music-player/releases/tag/0.1.0) for the old code.

License
=======
The code in this project is under the MIT license, unless otherwise stated. Note that the data retrieved from [echonest](http://echonest.com/) is bound by [its own license](http://developer.echonest.com/licensing.html).

Credits
=======
Original idea and inspiration came from [Music Box](http://thesis.flyingpudding.com/) by [Anita Shen Lillie](http://flyingpudding.com/).


ember-cli-echonest stuff
========================
# Ember-cli-echonest [![Circle CI](https://circleci.com/gh/robwebdev/ember-cli-echonest.png?style=badge)](https://circleci.com/gh/robwebdev/ember-cli-echonest)

The aim of this project is to provide everything required to build an application on top of [The Echonest API](http://developer.echonest.com/docs/v4/index.html) using Ember and Ember CLI.
The project is currently limited to providing an interface to fetch artists and songs, including [basic playlisting](http://developer.echonest.com/docs/v4/basic.html).

## Models
Ember Echonest Adapter provides the following models:
- echonest-artist
- echonest-song

Model names are namespaced with 'echonest-' to avoid conflicts with other potential models in your application.

### echonest-artist
Ember Data convenience for Echonest Artists. For more information visit [The Echonest Artist API docs](http://developer.echonest.com/docs/v4/artist.html)

#### Find an echonest-artist by id
This is returns an [artist profile](http://developer.echonest.com/docs/v4/artist.html#profile) with the buckets specified on the adapter.

```js
this.store.find('echonest-artist', 'ARH6W4X1187B99274F')
  .then(function (record) {
      record.get('name'); // Radiohead
  });
```

#### Find an echonest-artist by query
This is returns a list of [artist profiles](http://developer.echonest.com/docs/v4/artist.html#profile) with the buckets specified on the adapter.

```js
this.store.find('echonest-artist', {
    name: 'Radiohead'
}).then(function (records) {
    records.get('content.0.name'); // Radiohead
});
```

#### Find similar echoest-artists
Similar artists are available via an async relationship on an echonest-artist record. This calls the [similar artsist API method](http://developer.echonest.com/docs/v4/artist.html#similar) with the echonest-artist id.
```javascript
echonestArtistRecord.get('similar')
  .then(function (records) {
      records; // similar artists records
  });
```

### Songs
```javascript
this.store.find('echonest-song', 'ARH6W4X1187B99274F')
  .then(function (record) {
    record.get('artist_name'); // 'Radiohead'
    record.get('title'); // 'Stay fly'
  });
});
```

```javascript
this.store.find('echonest-song', {
  playlist: 'basic',
  artist_id: 'ARH6W4X1187B99274F'
}).then(function (records) {
    records; // playlist of songs
});
```

## To Do

- [ ] Add echonest-genre model
- [ ] Add echonest-track model
- [ ] Allow easy configuration of buckets
- [ ] Allow configuration of similar artists [API params](http://developer.echonest.com/docs/v4/artist.html#similar)
- [ ] Standard playlisting
- [ ] Premium playlisting
- [ ] Taste profiles
- [ ] Demo app

## Running Tests

* `ember test`
* `ember test --server`

## Building

* `ember build`

For more information on using ember-cli, visit [http://www.ember-cli.com/](http://www.ember-cli.com/).
