module.exports = (Module) ->
	games = require './games'

	convertParamsToObj = (params) ->
		pattern = /(\S+)\s*=\s*(\S+)/g
		o = {}

		while (match = pattern.exec params)?
			o[match[1]] = match[2]

		o

	class PokegamesModule extends Module
		shortName: 'Pokegames'
		helpText:
			default: 'A module with Pokemon games for Kurea'

		originString: (origin) -> "#{origin.bot.getName()};#{origin.channel}"

		constructor: (moduleManager) ->
			super

			@games = {}

			startGame = (origin, route) =>
				return if not origin.channel?

				{mode} = route.params
				[params] = route.splats

				originStr = @originString origin

				if @games[originStr]?
					@reply origin, 'There is already a game going on in here!'
					return

				GameClazz = games.gameTypes[mode]
				if not GameClazz?
					@reply origin, "Unknown game mode: '#{mode}'"
					return

				@games[originStr] = game = new GameClazz @, origin, originStr, convertParamsToObj params

				game.start()

			@addRoute 'pokegames start :mode *', startGame
			@addRoute 'pokegames start :mode', startGame

			@addRoute 'pokegames stop', (origin, route) =>
				return if not origin.channel?

				originStr = @originString origin

				@games[originStr].stop()

			@on 'message', (bot, user, channel, message) =>
				game = @games[@originString {bot, user, channel}]

				game?.onMessage? {bot, user, channel}, message

		destroy: ->
			for originStr, game of @games
				game.stop()

		gameStopped: (game) ->
			delete @games[game.originStr]

	PokegamesModule