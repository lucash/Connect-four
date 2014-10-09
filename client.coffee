Db = require 'db'
Dom = require 'dom'
Modal = require 'modal'
Obs = require 'obs'
Plugin = require 'plugin'
Page = require 'page'
Server = require 'server'
Ui = require 'ui'
Form = require 'form'
Time = require 'time'
{tr} = require 'i18n'

exports.render = ->
	gameId = Page.state.get(0)
	if gameId
		renderGame gameId
	else
		renderOverview()

renderOverview = !->
	Dom.h2 tr("Your games")

	Ui.list !->
		Db.shared.iterate 'games', (game) !->
			Ui.item !->
				Dom.style
					display_: 'box'
					_boxAlign: 'center'
				turn = game.get('turn')
				player0 = game.get('player0') is Plugin.userId()
				player1 = game.get('player1')

				if !turn and player0 and game.get('list1')
					Dom.div !->
						Dom.style _boxFlex: 1
						Dom.text tr("Challenged %1, waiting for a response..", Plugin.userName(game.get('player1')))
					Ui.button tr("Cancel"), !->
						Server.call 'cancel', game.key()

				else if !turn and player0
					Dom.div !->
						Dom.style _boxFlex: 1
						Dom.text tr("%1 did not accept the game")
					Ui.button tr("Ok"), !->
						Server.call 'cancel', game.key()

				else if !turn
					Dom.div !->
						Dom.style _boxFlex: 1
						Dom.text tr("%1 challenged you. Accept?", Plugin.userName(game.get('player0')))
					Ui.button tr("Yes"), !->
						Server.call 'accept', game.key()
					Ui.button tr("No"), !->
						Server.call 'cancel', game.key()

				else
					Dom.div !->
						Dom.style _boxFlex: 1
						Dom.span !->
							Dom.text Plugin.userName(game.get('white'))
							Dom.style
								fontWeight: if game.get('turn') is 'white' then 'bold' else 'normal'
						Dom.text ' vs '
						Dom.span !->
							Dom.text Plugin.userName(game.get('black'))
							Dom.style
								fontWeight: if game.get('turn') is 'black' then 'bold' else 'normal'

						Dom.div !->
							Dom.style
								display: 'inline-block'
								margin: '0 0 0 8px'
								fontSize: '85%'
							Time.deltaText game.get('order')*.001

					Dom.div !->
						if game.get(game.get('turn')) is Plugin.userId()
							Dom.style
								color: Plugin.colors().highlight
							Dom.text tr("Your move!")

					Dom.onTap !->
						Page.nav game.key()
			
		, (game) ->
			if Plugin.userId() in [game.get('list0'), game.get('list1')]
				-game.get('order')
	
	Ui.bigButton tr("New game"), !->
		Modal.show tr("Challenge opponent"), !->
			Dom.style width: '80%'
			Ui.list !->
				Dom.style
					maxHeight: '40%'
					overflow: 'auto'
					_overflowScrolling: 'touch'
					backgroundColor: '#eee'
					margin: '-12px -12px -15px -12px'
				Plugin.users.iterate (user) !->
					Ui.item !->
						Ui.avatar user.get('avatar')
						Dom.text user.get('name')
						Dom.onTap !->
							Modal.remove()
							Server.call 'challenge', user.key()
				, (user) ->
					if +user.key() != Plugin.userId()
						user.get('name')
		, false, ['cancel', tr("Cancel")]

	Dom.h2 "Other games"

	Ui.list !->
		Db.shared.iterate 'games', (game) !->
			Ui.item !->
				Dom.span !->
					Dom.text Plugin.userName(game.get('white'))
					Dom.style
						fontWeight: if game.get('turn') is 'white' then 'bold' else 'normal'
				Dom.text ' vs '
				Dom.span !->
					Dom.text Plugin.userName(game.get('black'))
					Dom.style
						fontWeight: if game.get('turn') is 'black' then 'bold' else 'normal'

				Dom.div !->
					Dom.style
						display: 'inline-block'
						margin: '0 0 0 8px'
						fontSize: '85%'
					Time.deltaText game.get('order')*.001

				Dom.onTap !->
					Page.nav game.key()
		, (game) ->
			if game.get('turn') and Plugin.userId() not in [game.get('black'), game.get('white')]
				true

renderGame = (gameId) !->
	game = Db.shared.ref('games', gameId)
	selected = Obs.create()

	Dom.div !->
		Dom.style
			display_: 'box'
			_boxAlign: 'center'
			_boxPack: 'center'
			margin: '4px 0'

		Dom.div !->
			size = 0|Math.max(200, Math.min(Dom.viewport.get('width')-16, 480)) / 8
			Dom.style
				boxShadow: '0 0 8px #000'
				width: "#{size*8}px"
			for i in [7..0] then do (i) !->
				Dom.div !->
					for j in [0..7] then do (j) !->
						Dom.div !->
							Dom.style
								display: 'inline-block'
								height: "#{size}px"
								width: "#{size}px"
								background: if (s=selected.get()) and s[0] is i and s[1] is j
										Plugin.colors().highlight
									else if (last=game.get('last')) and last[0] is i and last[1] is j
										'#aaf'
									else if (j%2)!=(i%2)
										'white'
									else
										'black'

							if piece = game.get('board', i, j)
								Dom.div !->
									Dom.style
										height: '100%'
										width: '100%'
										background: "url(#{Plugin.resourceUri piece+'.png'}) no-repeat 50% 50%"
										backgroundSize: "#{0|size*.75}px"

							Dom.onTap !->
								if game.get(game.get('turn')) is Plugin.userId()
									s=selected.get()
									if s
										if s[0] isnt i or s[1] isnt j
											Server.call 'move', game.key(), s, [i,j]
										selected.set null

									else if piece and piece.charAt(0) is game.get('turn').charAt(0)
										selected.set [i,j]


	Dom.div !->
		Dom.style
			margin: '8px 0'
			fontSize: '125%'
			textAlign: 'center'
		if winner = game.get('winner')
			winner = game.get(game.get('winner'))
			if winner is Plugin.userId()
				who = tr("You")
			else
				who = Plugin.userName(winner)

			Dom.text tr("%1 won!", who)

			if Plugin.userId() in [game.get('white'), game.get('black')]
				Ui.button !->
					Dom.text tr("Ok")
				, !->
					Server.call 'cancel', game.key()
					Page.back()

		else
			turn = game.get('turn')
			
			if game.get(turn) is Plugin.userId()
				Dom.text tr("Your turn - move a %1 piece, or", turn)
			else
				Dom.text tr("%1's turn", Plugin.userName(game.get(turn)))
			selected.set null

			if Plugin.userId() in [game.get('white'), game.get('black')]
				Ui.button !->
					Dom.text tr("Resign")
				, !->
					Server.call 'resign', game.key()

				#Ui.bigButton tr("Offer draw"), !->
				#	Server.call 'xx'
	
	editingItem = Obs.create(false)
	Dom.div !->
		Dom.style display_: 'box', _boxAlign: 'center'

		addE = null
		save = !->
			return if !addE.value().trim()
			Server.sync 'comment', game.key(), addE.value().trim()
			addE.value ""
			editingItem.set(false)
			Form.blur()

		Ui.avatar Plugin.userAvatar()

		Dom.section !->
			Dom.style display_: 'box', _boxFlex: 1, _boxAlign: 'center'
			Dom.div !->
				Dom.style _boxFlex: 1
				log 'rendering form.text'
				addE = Form.text
					autogrow: true
					name: 'comment'
					text: tr("Add a comment")
					simple: true
					onChange: (v) !->
						editingItem.set(!!v?.trim())
					onReturn: save
					inScope: !->
						Dom.prop 'rows', 1
						Dom.style
							border: 'none'
							width: '100%'
							fontSize: '100%'

			Ui.button !->
				Dom.style
					marginRight: 0
					visibility: (if editingItem.get() then 'visible' else 'hidden')
				Dom.text tr("Add")
			, save

	Dom.section !->
		game.iterate 'log', (entry) !->
			Dom.div !->
				if whiteMove = entry.get('white')
					Dom.style
						margin: '10px 0'
						fontFamily: 'monospace'
					Dom.div !->
						Dom.style
							display: 'inline-block'
							width: '38px'
							fontSize: '85%'
							fontWeight: 'bold'
						Dom.text entry.get('m')||''
					Dom.div !->
						Dom.style display: 'inline-block', padding: '6px'
						Dom.text whiteMove

				else if blackMove = entry.get('black')
					Dom.style
						fontFamily: 'monospace'
						margin: '-10px 0 -10px 90px'
					Dom.div !->
						Dom.style display: 'inline-block', padding: '6px'
						Dom.text blackMove

				else if comment = entry.get('comment')
					Dom.style
						margin: '6px 0 6px 0'
						display_: 'box'
						_boxAlign: 'center'
					Ui.avatar Plugin.userAvatar(entry.get('user')), !->
					Dom.div !->
						Dom.style _boxFlex: 1
						Dom.text comment
		, (entry) -> -entry.key()


