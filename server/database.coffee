class Model
    @whitelist = []
    @table = null

    constructor: (row) ->
        for own column, value of row
            this[column] = value

    update: (database, callback) ->
        query = 'UPDATE ' + @constructor.table + ' SET'
        values = []
        count = 1
        for own column, value of this
            if column != 'id' and value?
                if count > 1 then query += ','
                query += ' '  + column + '=$' + count
                values.push value
                count++
        query += ' WHERE id=' + this.id
        console.log query
        database.query query, values, callback

    toJSON: () ->
        json = {}
        for property in @constructor.whitelist
            json[property] = this[property]
        return json

    @fetch: (database, query, parameters, callback) ->
        database.query query, parameters, (err, response) =>
            return callback err, null if err?
            results = []
            for row in response.rows
                object = new @ row
                results.push object
            callback null, results

exports.Model = Model


class User extends Model
    @whitelist = ['id', 'name', 'email', 'facebook_id', 'twitter_id', 'interests', 'username']
    @table = 'users'

exports.User = User