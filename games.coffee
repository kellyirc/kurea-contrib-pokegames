Chance = require 'chance'
Q = require 'q'
irc = require 'irc-colors'
_ = require 'lodash'

PokemonDb = require './pokemondb'

asArray = (collection) ->
	_.chain collection
	.map (v,k) -> [k, v]
	.zip()
	.value()

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

	questionTimeout: 8 * 1000
	nextQuestionDelay: 3 * 1000
	hintCount: 4

	hints:
		hard: asArray
			'type': 8
			'stat': 3
			'move': 12
			'species': 5

	constructor: ->
		super
		@chance = new Chance

	onStart: ->
		@startQuestion()

	onStop: ->
		@stopCurrentQuestion null, yes

	startQuestion: ->
		@say 'Ready yourselves! Getting next Pokemon...'

		id = @chance.natural max: @pokemonCount-1

		PokemonDb.pokemon {id}
		
		.then (@currentPkmn) =>
			descObj = @chance.pick currentPkmn.descriptions

			PokemonDb.get descObj.resource_uri

		.then (@desc) =>
			@say "#{irc.bold "Who's that Pokemon?!"} #{@redactPokemonName @currentPkmn, @desc.description}"
			hintsGiven = 0

			@timeout = setInterval =>
				if hintsGiven++ < @hintCount
					@dropHint()

				else
					@stopCurrentQuestion null

			, @questionTimeout

		.fail (err) =>
			console.error err.stack

	dropHint: (difficulty = 'hard') ->
		loop
			hintType = @chance.weighted @hints[difficulty]...

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
					move = @chance.pick @currentPkmn.moves
					learnedFrom = switch move.learn_type
						when 'machine' then "using a #{irc.bold 'TM/HM'}"
						when 'tutor' then "from a #{irc.bold 'Tutor'}"
						when 'level up' then "at #{irc.bold 'level ' + move.level}"
						when 'egg move' then "as an #{irc.bold Egg Move}"

					@say "It can learn #{irc.bold move.name} #{learnedFrom}."

				when 'species'
					continue if not @currentPkmn.species? or @currentPkmn.species is ''

					@say "It is known as the #{irc.bold @currentPkmn.species}."

			break

	stopCurrentQuestion: (answeredBy, halt = no) ->
		if @currentPkmn?
			if answeredBy?
				@say "#{irc.bold answeredBy.user} got the right answer! It was #{irc.bold @currentPkmn.name}!"

				console.log "Answered by #{answeredBy.name}"

			else
				@say "#{irc.red.bold "Time's up!"} It was #{irc.bold @currentPkmn.name}!"

				console.log 'No one answered.'

		clearTimeout @timeout
		@currentPkmn = null

		if not halt
			Q.delay @nextQuestionDelay
			.then => @startQuestion()

		else
			@say 'Game has been stopped.'
			console.log 'HALTED!!!!!!!!!!!!!!'

	redactPokemonName: (pkmn, text) ->
		text.replace (new RegExp pkmn.name, 'ig'), '[REDACTED]'

	onMessage: (origin, message) ->
		return if not @currentPkmn?

		if message.toLowerCase() is @currentPkmn.name.toLowerCase()
			@stopCurrentQuestion origin