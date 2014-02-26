AWS = require 'aws-sdk'
bcrypt = require 'bcrypt'
crypto = require 'crypto'
express = require 'express'
pg = require 'pg'
https = require 'https'
isodate = require 'isodate'

AWS.config.loadFromPath './aws.json'
DynamoDB = new AWS.DynamoDB {apiVersion: '2012-08-10'}


TokenGenerator = (user, req, res) ->
    crypto.randomBytes 64, (err, random) ->
        return res.json 500, {error: 'Crypto function does not exist.'} if err?
        token = random.toString 'hex'
        req.models.Session.create {
            user_id: user.id,
            ip_address: req.ip,
            token: token,
            created_time: new Date()
        }, (err, session) ->
            return res.json 500, {error: 'Unable to create session token.'} if err?
            res.json {access_token: token}

AuthenticationMiddleware = (req, res, callback) ->
    if not req.query.token?
        return res.json 401, {error: 'A valid session token is required.'}
    req.models.Session.find {token: req.query.token}, (err, results) ->
        return res.json 503, {error: err} if err?
        if results.length == 0
            return res.json 401, {error: 'Invalid session token.'}
        session = results[0]
        callback session.user

ThreadPermissionsMiddleware = (req, res, callback) ->
    AuthenticationMiddleware req, res, (user) ->
        req.models.Thread.get parseInt(req.params.thread_id), (err, thread) ->
            return res.json 503, {error: 'Unable to lookup thread.'} if err?
            await thread.getUsers defer err, users
            return res.json 503, {error: 'Unable to lookup thread.'} if err?
            for u in users
                if u.id == user.id
                    return callback user, thread
            if thread.password?
                await bcrypt.compare req.body.password, thread.password, defer err, result
                return res.json 503, {error: 'Crypto function does not exist.'} if err?
                return res.json 401, {error: 'Incorrect password.'} if not result
            await user.addThreads [thread], {subscribed: true}, defer err
            return res.json 503, {error: 'Unable to subscribe to thread.'} if err?                
            callback user, thread


exports.make = (server) ->

    server.post '/api/1/generate', (req, res) ->
        await
            for i in [1..10000]
                username = Math.random()
                latitude = Math.random() * 180 - 90
                longitude = Math.random() * 360 - 180
                user = {
                    username: username,
                    name: username,
                    email: username,
                    password: username,
                    latitude: latitude,
                    longitude: longitude
                }
                req.models.User.create user, defer err, user
        res.send 'Done'

    server.post '/api/1/users', (req, res) ->
        if not req.body.username? or not req.body.latitude? or not req.body.longitude?
            return res.json 405, {error: 'Method missing required parameters.'} 

        if req.body.name? and req.body.email? and req.body.password?
            bcrypt.hash req.body.password, 8, (err, hash) ->
                return res.json 500, {error: 'Crypto function does not exist.'} if err?
                req.models.User.create {
                    username: req.body.username,
                    name: req.body.name,
                    email: req.body.email,
                    password: hash,
                    latitude: req.body.latitude,
                    longitude: req.body.longitude
                }, (err, user) ->
                    if err?
                        if err.code == '23505' then return res.json 409, {'error': 'User already exists.'}
                        else return res.json 503, {error: 'Unable to create user.' + err}
                    TokenGenerator user, req, res
        else if req.body.facebook?
            request = https.request 'https://graph.facebook.com/me?access_token=' + req.body.facebook, (response) ->
                data = ''
                response.on 'data', (chunk) ->
                    data += chunk
                response.on 'end', () ->
                    response = JSON.parse data
                    req.models.User.create {
                        facebook_id: response.id,
                        username: req.body.username,
                        name: response.name,
                        latitude: req.body.latitude,
                        longitude: req.body.longitude
                    }, (err, user) ->
                        if err?
                            if err.code == '23505' then return res.json 409, {'error': 'User already exists.'}
                            else return res.json 503, {error: 'Unable to create user.'}
                        TokenGenerator user, req, res
            request.on 'error', (err) ->
                res.json 500, {error: 'Unable to connect to Facebook.'}
            request.end()
        else if req.body.twitter?
            res.json 500, {error: 'Twitter registration is not yet available.'}
        else
            res.json 405, {error: 'Method missing required parameters.'}


    server.post '/api/1/sessions', (req, res) ->
        if req.body.email? and req.body.password?
            req.models.User.find {email: req.body.email}, (err, results) ->
                return res.json 503, {error: 'Unable to lookup user.'} if err?
                if results.rowCount == 0
                    return res.json 500, {error: 'No user with supplied email address.'}
                user = results[0]
                bcrypt.compare req.body.password, user.password, (err, result) ->
                    return res.json 500, {error: 'Crypto function does not exist.'} if err?
                    if result == true
                        TokenGenerator user, req, res
                    else
                        return res.json 401, {error: 'Email and password combination is incorrect.'}
        else if req.body.facebook?
            request = https.request 'https://graph.facebook.com/me?access_token=' + req.body.facebook, (response) ->
                data = ''
                response.on 'data', (chunk) ->
                    data += chunk
                response.on 'end', () ->
                    if response.statusCode != 200
                        return res.json 401, {error: 'Invalid Facebook access token.'}
                    response = JSON.parse data
                    req.models.User.find {facebook_id: response.id}, (err, results) ->
                        return res.json 503, {error: 'Unable to lookup user.'} if err?
                        if results.rowCount == 0
                            return res.json 500, {error: 'No user associated with that Facebook account.'}
                        user = results[0]
                        TokenGenerator user, req, res
            request.on 'error', (err) ->
                res.json 500, {error: 'Unable to connect to Facebook.'}
            request.end()
        else if req.body.twitter?
            res.json 500, {error: 'Twitter registration is not yet available.'}
        else
            res.json 405, {error: 'Method missing required parameters.'}


    server.put '/api/1/users/me', (req, res) ->
        AuthenticationMiddleware req, res, (user) ->
            user.name = req.body.name if req.body.name?
            user.email = req.body.email if req.body.email?
            user.username = req.body.username if req.body.username?
            user.latitude = req.body.latitude if req.body.latitude?
            user.longitude = req.body.longitude if req.body.longitude?
            user.available = req.body.available if req.body.available?
            if req.body.password?
                if user.password?
                    await bcrypt.compare req.body.old_password, user.password, defer err, result
                    return res.json 500, {error: 'Crypto function does not exist.' + err} if err?
                    return res.json 401, {error: 'old password is incorrect.'} if user.password? and not result    
                await crypt.hash req.body.password, 8, defer err, hash
                return res.json 500, {error: 'Crypto function does not exist.'} if err?
                user.password = hash
            user.save (err) ->
                return res.json 503, {error: 'Unable to update user.'} if err?
                return res.json user 


    server.get '/api/1/users/:user_id', (req, res) ->
        if req.params.user_id == 'me'
            await AuthenticationMiddleware req, res, defer user
            res.json user
        else
            await req.models.User.get parseInt(req.params.user_id), defer err, user
            return res.json 503, {error: 'Unable to fetch user.'} if err?
            res.json {id: user.id, username: user.username}


    server.get '/api/1/users', (req, res) ->
        AuthenticationMiddleware req, res, (user) ->
            latitude = user.latitude
            longitude = user.longitude
            if req.query.latitude? and req.query.longitude?
                latitude = parseFloat(req.query.latitude)
                longitude = parseFloat(req.query.longitude)
            location = "'SRID=4326;POINT(" + longitude + " " + latitude + ")'"

            degrees = 0.001
            while degrees < 100
                query = 'SELECT users.id, users.username, array_agg(interests.name) as interests, st_distance_sphere(location, ' + location + ') as distance FROM users LEFT JOIN (users_interests JOIN interests ON users_interests.interest_id = interests.id) ON users_interests.user_id = users.id WHERE available = TRUE AND ST_Within(location, ST_Buffer(' + location + ', ' + degrees + ')) GROUP BY users.id LIMIT 100'
                await req.db.driver.execQuery query, defer err, results
                return res.json 500, {error: 'Unable to find users.'} if err?
                users = []
                for row in results
                    if row.id != user.id
                        row.interests = [] if not row.interests[0]?
                        users.push {id: row.id, username: row.username, interests: row.interests}
                if users.length > 0
                    return res.json {users: users}
                degrees = 10 * degrees
            return res.json {users: []}


    server.get '/api/1/users/me/threads', (req, res) ->
        AuthenticationMiddleware req, res, (user) ->
            user.getThreads (err, threads) ->
                return res.json 503, {error: 'Unable to fetch threads.'} if err?
                for thread in threads
                    delete thread.owner
                res.json {threads: threads}


    server.get '/api/1/threads', (req, res) ->
        if not req.query.latitude? or not req.query.longitude?
            return res.json 405, {error: 'Method missing required parameters.'}

        latitude = parseFloat(req.query.latitude)
        longitude = parseFloat(req.query.longitude)
        location = "'SRID=4326;POINT(" + longitude + " " + latitude + ")'"

        degrees = 0.001
        while degrees < 100
            query = 'SELECT threads.*, array_agg(interests.name) as interests, st_distance_sphere(location, ' + location + ') as distance FROM threads LEFT JOIN (threads_interests JOIN interests ON threads_interests.interest_id = interests.id) ON threads_interests.thread_id = threads.id WHERE (expiration IS NULL OR expiration > NOW()) AND ST_Within(location, ST_Buffer(' + location + ', ' + degrees + ')) GROUP BY threads.id LIMIT 100'
            await req.db.driver.execQuery query, defer err, results
            return res.json 500, {error: 'Unable to find threads.'} if err?
            threads = []
            for row in results
                row.interests = [] if not row.interests[0]?
                delete row.location
                delete row.owner_id
                row.password = row.password?
                threads.push row
            if threads.length > 0
                return res.json {threads: threads}
            degrees = 10 * degrees
        return res.json {threads: []}


    server.post '/api/1/threads', (req, res) ->
        AuthenticationMiddleware req, res, (user) ->
            if not req.body.name? or not req.body.message?
                return res.json 405, {error: 'Method missing required parameters.'}

            thread = {}
            thread.owner_id = user.id
            thread.name = req.body.name
            thread.expiration = isodate(req.body.expiration) if req.body.expiration?
            if req.body.latitude? and req.body.longitude?
                thread.latitude = req.body.latitude
                thread.longitude = req.body.longitude
            else if not req.body.user_id?
                return res.json 405, {error: 'Method missing required paramters.'}

            if req.body.password?
                await bcrypt.hash req.body.password, 8, defer err, hash
                return res.json 500, {error: 'Crypto function does not exist.'} if err?
                thread.password = hash

            users = []
            users.push user
            if req.body.user_id?
                await req.models.User.get req.body.user_id, defer err, friend
                return res.json 503, {error: 'Unable to find user.'} if err?
                users.push friend

            req.models.Thread.create thread, (err, thread) ->
                return res.json 503, {error: 'Unable to create thread.'} if err?
                thread.addUsers users, {subscribed: true}, (err) ->
                    return res.json 500, {error: 'Unable to subscribe to thread.'} if err?
                    # TODO ping message url to send message, this will notify users
                    res.json thread


    server.get '/api/1/threads/:thread_id/messages', (req, res) ->
        ThreadPermissionsMiddleware req, res, (user) ->
            conditions = {'ThreadId': {'AttributeValueList': [{'S': req.params.thread_id}], 'ComparisonOperator': 'EQ'}}
            DynamoDB.query {TableName: 'Messages', ConsistentRead: true, KeyConditions: conditions, ScanIndexForward: false}, (err, data) ->
                return res.json 503, {error: 'Unable to connect to DynamoDB.' + err} if err?
                messages = []
                for message in data['Items']
                    message.id = message['CreatedTime-Random']['S']
                    message.text = message.text.S
                    message.created_time = message.created_time.S
                    message.user_id = parseInt(message.user_id.N)
                    delete message['ThreadId']
                    delete message['CreatedTime-Random']
                    messages.push message
                res.json {messages: messages}


    server.post '/api/1/threads/:thread_id/messages', (req, res) ->
        return res.json 405, {error: 'Method missing required parameters'} if not req.body.text?
        ThreadPermissionsMiddleware req, res, (user) ->
            time = new Date().toISOString()
            message = {}
            id = time + '-' + Math.random();
            message['ThreadId'] = {S: req.params.thread_id}
            message['CreatedTime-Random'] = {'S': id}
            message['created_time'] = {'S': time}
            message['text'] = {'S': req.body.text}
            message['user_id'] = {'N': user.id}
            DynamoDB.putItem {TableName: 'Messages', Item: message}, (err, data) ->
                return res.json 503, {error: 'Unable to connect to DynamoDB.'} if err?
                res.json {id: id, text: req.body.text, created_time: time, user_id: user.id}
                    



