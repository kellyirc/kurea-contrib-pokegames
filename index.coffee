module.exports = (Module) ->
	{GuessPokemonGame} = require './games'

	class PokegamesModule extends Module
		shortName: 'Pokegames'
		helpText:
			default: 'A module with Pokemon games for Kurea'

		originString: (origin) -> "#{origin.bot.getName()};#{origin.channel}"

		constructor: (moduleManager) ->
			super

			@games = {}

			@addRoute 'pokegames start *', (origin, route) =>
				return if not origin.channel?

				[mode] = route.splats
				originStr = @originString origin

				if @games[originStr]?
					@reply origin, 'There is already a game going on in here!'
					return

				@games[originStr] = game = new GuessPokemonGame @, origin
				game.start()

			@addRoute 'pokegames stop', (origin, route) =>
				return if not origin.channel?

				originStr = @originString origin

				@games[originStr].stop()
				delete @games[originStr]

			@on 'message', (bot, user, channel, message) =>
				game = @games[@originString {bot, user, channel}]

				game?.onMessage? {bot, user, channel}, message

		destroy: ->
			for originStr, game of @games
				game.stop()

	PokegamesModule