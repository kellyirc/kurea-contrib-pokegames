Chance = require 'chance'
Q = require 'q'

PokemonDb = require './pokemondb'

class exports.Game
	constructor: (@module, @origin) ->

	start: (a...) ->
		@onStart? a...

	stop: (a...) ->
		@onStop? a...

	say: (msg) ->
		@module.reply @origin, msg

class exports.GuessPokemonGame extends exports.Game
	pokemonCount: 719

	questionTimeout: 30 * 1000
	nextQuestionDelay: 3 * 1000

	constructor: ->
		super
		@chance = new Chance

	onStart: ->
		@startQuestion()

	onStop: ->
		@stopCurrentQuestion null

	startQuestion: ->
		@say 'Ready yourselves! Getting next Pokemon...'

		id = @chance.natural max: @pokemonCount-1

		PokemonDb.pokemon {id}
		
		.then (@currentPkmn) =>
			descObj = @chance.pick currentPkmn.descriptions

			PokemonDb.get descObj.resource_uri

		.then (@desc) =>
			console.log "#{@currentPkmn.name}"

			@say "Who's that Pokemon?! #{@desc.description}"

			@timeout = setTimeout =>
				@stopCurrentQuestion null

			, @questionTimeout

		.fail (err) =>
			console.error err.stack

	stopCurrentQuestion: (answeredBy) ->
		if answeredBy?
			@say "#{answeredBy.user} got the right answer!"

			console.log "Answered by #{answeredBy.name}"

		else
			@say "Time's up! It was #{@currentPkmn.name}!"

			console.log 'No one answered.'

		clearTimeout @timeout
		@currentPkmn = null

		Q.delay @nextQuestionDelay
		.then => @startQuestion()

	onMessage: (origin, message) ->
		return if not @currentPkmn?

		if message.toLowerCase() is @currentPkmn.name.toLowerCase()
			@stopCurrentQuestion origin