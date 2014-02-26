require 'iced-coffee-script'
express = require 'express'
orm = require 'orm'
pg = require 'pg'


debug = true
server = express()
server.enable 'trust proxy'
server.set 'view engine', 'ejs'
server.use express.logger()
server.use express.bodyParser()
server.use express.static __dirname + '/static'

server.use orm.express 'postgres://username:password@localhost/chatmarkers?pool=true', {
    define: (db, models) ->
        models.User = db.define 'users', {
            name: {type: 'text', size: 32, required: true},
            username: {type: 'text', size: 32, required: true},
            email: {type: 'text', size: 256},
            password: {type: 'text', size: 256},
            facebook_id: {type: 'text', size: 128},
            twitter_id: {type: 'text', size: 128},
            available: {type: 'boolean', defaultValue: true, required: true},
            latitude: {type: 'number', rational: true, required: true},
            longitude: {type: 'number', rational: true, required: true}
        }, {
            methods: {
                toJSON: () ->
                    result = {}
                    for own key, value of @
                        if key != 'password' and key != 'location'
                            result[key] = value
                    return result
            }
        }
        models.Interest = db.define 'interests', {
            name: {type: 'text', size: 32, required: true}
        }
        models.Session = db.define 'sessions', {
            ip_address: {type: 'text', size: 45, required: true},
            device_id: {type: 'text', size: 128},
            device_type: {type: 'text', size: 10},
            token: {type: 'text', size: 128, required: true},
            created_time: {type: 'date'}
        }
        models.Thread = db.define 'threads', {
            name: {type: 'text', size: 32, required: true},
            password: {type: 'text', size: 256},
            expiration: {type: 'date'},
            latitude: {type: 'number', rational: true},
            longitude: {type: 'number', rational: true}
        }, {
            methods: {
                toJSON: () ->
                    result = {}
                    for own key, value of @
                        if key != 'password'
                            result[key] = value
                    return result
            }
        }
        models.Session.hasOne 'user', models.User, {reverse: 'sessions', autoFetch: true}
        models.User.hasMany 'interests', models.Interest, {}, {reverse: 'users', mergeTable: 'users_interests', mergeId: 'user_id', mergeAssocId: 'interest_id'}
        models.Thread.hasMany 'interests', models.Interest, {}, {reverse: 'threads', mergeTable: 'threads_interests', mergeId: 'thread_id', mergeAssocId: 'interest_id'}
        models.Thread.hasMany 'users', models.User, {subscribed: Boolean}, {reverse: 'threads', mergeTable: 'threads_users', mergeId: 'thread_id', mergeAssocId: 'user_id'}
        models.Thread.hasOne 'owner', models.User, {autoFetch: true}
}

# Add method for displaying errors
server.use (req, res, next) ->
    res.error = (status, err) ->
        throw {status: status, cause: err}
    next()

# Redirect all www requests to the non www equivalent
server.all /.*/, (req, res, next) ->    
    host = req.header "host"
    if host.match /^www\..*/i
        res.redirect 301, "http://" + host.substring(4) + req.url
    else
        next()

# Add the API end points to the server
api = require './api'
api.make server

server.get '/', (req, res) ->
    res.render 'index', {name: 'guest'}

# Error handler with debug options
server.use (err, req, res, next) ->
    status = err.status
    status ?= 500
    err = err.cause if err.cause?
    title = 'HTTP ' + status
    res.status(status).render 'error', {title: title, err: if debug then err else null}

server.listen 80
