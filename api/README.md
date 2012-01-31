# Paths

## Key

### GET /v1/key/:key

Returns the information stored about `:key` or a 404 if the key wasn't
found.

### DELETE /v1/key/:key

Removes the `:key`. Returns `true` when the key was deleted
successfully or a 404 if it didn't exist in the first place.

### PUT /v1/key/:key

Modify the `:key` by merging the JSON body of the call with `:key`. If
the key doesn't exist a 404 will be returned.

### POST /v1/key/:key

Create a new API key. If one already exists then a 400 will be
returned. Returns the new structure on success.

## Api

### GET /v1/api/:api

Returns the information stored about `:api` or a 404 if the api wasn't
found.

### DELETE /v1/api/:api

Removes the api at `:api`. Returns `true` when the api was deleted
successfully or a 404 if it didn't exist in the first place.

### PUT /v1/api/:api

Modify the `:api` by merging the JSON body of the call with `:api`. If
the api doesn't exist a 404 will be returned.

### POST /v1/api/:api

Create a new API `:api`. If one already exists then a 400 will be
returned. Returns the new structure on success.
