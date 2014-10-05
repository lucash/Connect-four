Db = require 'db'
Dom = require 'dom'
Modal = require 'modal'
Obs = require 'obs'
Plugin = require 'plugin'
Page = require 'page'
Server = require 'server'
Ui = require 'ui'
{tr} = require 'i18n'

exports.render = ->
	gameId = Page.state.get(0) || Db.personal.get('gameId')
	if !gameId
		Dom.h2 "Ongoing games"

		Ui.list !->
			Db.shared.iterate 'games', (game) !->
				Ui.item !->
					Dom.text "Game "+game.key()
					Dom.onTap !->
						Page.nav game.key()

		Dom.h2 "New game"
		Dom.div !->
			Dom.text tr("Start a game by challenging someone")

		Ui.list !->
			Plugin.users.iterate (user) !->
				Ui.item !->
					Dom.text user.get('name')
					Dom.onTap !->
						Server.call 'challenge', +user.key()
			, (user) -> if +user.key() != Plugin.userId() then true

		return

	game = Db.shared.ref 'games', gameId

	state = game.get('state')
	if state is 'challenge' and game.get('player0') is Plugin.userId()
		Dom.div tr("Waiting for %1", Plugin.userName(game.get('player1')))
		Ui.bigButton tr("Cancel"), !->
			Server.call 'cancel'

	else if state is 'challenge'
		Dom.div tr("You have been challenged by %1. Accept?", Plugin.userName(game.get('player0')))
		Ui.bigButton 'yes', !->
			Server.call 'accept'
		Ui.bigButton 'no', !->
			Server.call 'cancel'

	else if state is 'reject'
		if game.get('player0') is Plugin.userId()
			Dom.div tr("%1 did not accept the game", 'xx')
		else
			Dom.div tr("%1 challenged you for a game, but then changed his mind...", 'x')
		Ui.bigButton 'ok', !->
			Server.call 'cancel'

	else if state is 'resign'
		Dom.div tr("%1 has resigned", 'xx')
		Ui.bigButton 'ok', !->
			Server.call 'cancel'

	else
		renderGame game

renderGame = (game) !->

	selected = Obs.create()
	Dom.div !->
		Dom.style
			display_: 'box'
			_boxAlign: 'center'
			_boxPack: 'center'

		Dom.div !->
			Dom.style
				width: '320px'
			for i in [7..0] then do (i) !->
				Dom.div !->
					for j in [0..7] then do (j) !->
						Dom.div !->
							Dom.style
								display: 'inline-block'
								height: '40px'
								width: '40px'
								background: if (s=selected.get()) and s[0] is i and s[1] is j
										'#0a0'
									else if (j%2)!=(i%2)
										'white'
									else
										'black'

							if piece = game.get('board', i, j)
								Dom.div !->
									Dom.style
										height: '40px'
										width: '40px'
										background: "url(#{Plugin.resourceUri piece+'.png'}) no-repeat 50% 50%"
										backgroundSize: '30px'

							Dom.onTap !->
								if game.get('player'+game.get('turn')) is Plugin.userId()
									s=selected.get()
									if s
										if s[0] isnt i or s[1] isnt j
											Server.call 'move', s, [i,j]
										selected.set null

									else if piece and piece.charAt(0) is game.get('turn')
										selected.set [i,j]


	Dom.div !->
		turn = game.get('turn')
		Dom.style
			margin: '8px 0'
			fontSize: '125%'
			textAlign: 'center'
		if game.get('player'+turn) is Plugin.userId()
			Dom.text tr("Your turn - move a %1 piece", {w: tr("white"), b: tr("black")}[turn])
		else
			Dom.text tr("%1's turn", Plugin.userName(game.get('player'+turn)))
		selected.set null

	if Plugin.userId() in [game.get('playerw'), game.get('playerb')]
		Ui.bigButton tr("Resign"), !->
			Server.call 'cancel'

		#Ui.bigButton tr("Offer draw"), !->
		#	Server.call 'xx'
