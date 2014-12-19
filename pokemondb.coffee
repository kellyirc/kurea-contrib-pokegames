request = require 'request'
Q = require 'q'
_ = require 'lodash'

r = request.defaults
	json: yes

exports.get = (path, cb) ->
	Q.ninvoke r, 'get', "http://pokeapi.co#{path}"
	.then ([res, body]) -> body
	.nodeify cb

exports.pokemon = ({id}, cb) ->
	exports.get "/api/v1/pokemon/#{id}", cb