module.exports = (Module) ->
	class PokegamesModule extends Module
		shortName: 'Pokegames'
		helpText:
			default: 'A module with Pokemon games for Kurea'
		usage:
			default: 'pokegames [arg]'

		constructor: (moduleManager) ->
			super

			@addRoute 'pokegames', (origin, route) =>
				@reply origin, "Not yet implemented."

	PokegamesModule