_ = require 'lodash'
Q = require 'q'
async = require 'async-q'

Chance = require 'chance'
irc = require 'irc-colors'

PokemonDb = require './pokemondb'

asArray = (collection) ->
	_.chain collection
	.map (v,k) -> [k, v]
	.zip()
	.value()

Chance::partialString = (string) ->
	percent = @floating min: 0.2, max: 0.45

	len = string.length * percent // 1
	restLen = string.length - len

	string[...len] + (new Array restLen+1).join '_'

fixPokemonName = (name) ->
	return name if name.toLowerCase() in ['ho-oh', 'mr-mime']

	name.replace /\-.+/g, ''

class exports.Game
	constructor: (@module, @origin, @originStr, @params) ->

	start: (a...) ->
		@onStart? a...

	stop: (a...) ->
		@onStop? a...
		@module.gameStopped @

	say: (msg) ->
		@module.reply @origin, msg

class exports.GuessPokemonGame extends exports.Game
	pokemonCount: 719

	questionTimeout: 12 * 1000
	nextQuestionDelay: 3 * 1000
	hintCount: 3
	maxRounds: Infinity

	hints:
		hard: asArray
			'type': 8
			'stat': 3
			'move': 12
			'species': 5

		final: asArray
			'partial name': 1

	getDifficulty: (currentHint) ->
		return 'final' if currentHint is @hintCount

		'hard'

	constructor: ->
		super
		@chance = new Chance
		@stopped = no
		@currentRound = 0

		for key, value of @params
			switch key
				when 'hints'
					@hintCount = Number value

				when 'rounds'
					if value in ['infinite', 'infinity', 'unlimited']
						@maxRounds = Infinity

					else @maxRounds = Number value

				when 'hint-interval'
					@questionTimeout = (Number value) * 1000

				when 'next-question-delay'
					@nextQuestionDelay = (Number value) * 1000

	onStart: ->
		@startQuestion()

	onStop: ->
		@stopped = yes
		@stopCurrentQuestion()

	assertNotStopped: (pkmn) ->
		if @stopped or (pkmn? and pkmn isnt @currentPkmn)
			e = new Error 'Stopped.'
			e.stopped = yes
			throw e

	startQuestion: ->
		Q.fcall =>
			@assertNotStopped()

			@currentRound++

			@say irc.green 'Getting next Pokemon...'

			id = @chance.pick [0...@pokemonCount]

			PokemonDb.pokemon {id}

		.then (@currentPkmn) =>
			@assertNotStopped()

			@currentPkmn.name = fixPokemonName @currentPkmn.name
			descObj = @chance.pick currentPkmn.descriptions

			PokemonDb.get descObj.resource_uri

		.then (@desc) =>
			@assertNotStopped()

			console.log 'The game may now commence.'

			@say "
				#{irc.bold "Who's that Pokemon?!"}
				#{@redactPokemonName @currentPkmn, @desc.description}
			"

			@hintsGiven = 0
			@hintLimits =
				'type': 1
				'stat': 2
				'move': 3
				'species': 1
				'partial name': 1

		.then =>
			pkmn = @currentPkmn

			Q.fcall =>
				async.until (=> @hintsGiven >= @hintCount), =>
					Q.delay @questionTimeout
					.then =>
						@assertNotStopped pkmn

						@dropHint @getDifficulty ++@hintsGiven

			.delay @questionTimeout

			.then =>
				@assertNotStopped pkmn

				@correctAnswer null

		.fail (err) =>
			if not err.stopped?
				console.error err.stack
				@say "Looks like there was an error! #{irc.red.bold err.toString()}"
				@stop()

	dropHint: (difficulty = 'hard') ->
		loop
			hintType = @chance.weighted @hints[difficulty]...
			continue if @hintLimits[hintType]? and @hintLimits[hintType]-- <= 0

			switch hintType
				when 'type'
					[type1, type2] = @currentPkmn.types

					type = if type2? then "#{type1.name}-#{type2.name}" else type1.name
					@say "It is of type #{irc.bold type}."

				when 'stat'
					stats =
						hp: 'HP'
						attack: 'Attack'
						defense: 'Defense'
						sp_def: 'Sp. Defense'
						sp_atk: 'Sp. Attack'
						speed: 'Speed'

					stat = @chance.pick _.keys stats
					@say "Its base #{irc.bold stats[stat]} is #{irc.bold @currentPkmn[stat]}."

				when 'move'
					continue if @currentPkmn.moves.length <= 0

					move = @chance.pick @currentPkmn.moves

					continue if move.learn_type in ['machine']

					learnedFrom = switch move.learn_type
						when 'tutor' then "from a #{irc.bold 'Tutor'}"
						when 'level up' then "at #{irc.bold 'level ' + move.level}"
						when 'egg move' then "as an #{irc.bold 'Egg Move'}"

					@say "It can learn #{irc.bold move.name} #{learnedFrom}."

				when 'species'
					continue if not @currentPkmn.species? or @currentPkmn.species is ''

					@say "It is known as the #{irc.bold @currentPkmn.species}."

				when 'partial name'
					name = @chance.partialString @currentPkmn.name
					@say "Its name is #{irc.bold name}."

			console.log "Dropped hint of type '#{hintType}' (difficulty: #{difficulty})"

			break

	stopCurrentQuestion: ->
		@currentPkmn = null

	correctAnswer: (answeredBy) ->
		if answeredBy?
			console.log "Answered by #{answeredBy.user}"
			@say "
				#{irc.bold answeredBy.user} got the right answer!
				It was #{irc.bold @currentPkmn.name}!
			"

		else
			console.log 'No one answered.'
			@say "#{irc.red.bold "Time's up!"} It was #{irc.bold @currentPkmn.name}!"

		@stopCurrentQuestion()

		if @currentRound >= @maxRounds
			@say 'Game has been stopped.'
			console.log 'Halted game.'
			@stop()

		Q.delay @nextQuestionDelay
		.then => @startQuestion()

	redactPokemonName: (pkmn, text) ->
		text.replace (new RegExp pkmn.name, 'ig'), '[REDACTED]'

	onMessage: (origin, message) ->
		return if not @currentPkmn?

		normalize = (str) ->
			str
			.replace /[^\w]/g, ''
			.toLowerCase()

		if (normalize message) is (normalize @currentPkmn.name)
			@correctAnswer origin

exports.gameTypes =
	'whos-that-pokemon': exports.GuessPokemonGame
	'guess-pokemon': exports.GuessPokemonGame
