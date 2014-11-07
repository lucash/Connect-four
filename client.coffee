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
Toast = require 'toast'
Social = require 'social'
{Chess} = require 'chess'
{tr} = require 'i18n'

# input that handles selection of a member
selectMember = (opts) !->
	opts ||= {}
	[handleChange, initValue] = Form.makeInput opts, (v) -> 0|v

	value = Obs.create(initValue)
	Form.box !->
		Dom.style fontSize: '125%', paddingRight: '56px'
		Dom.text opts.title||tr("Selected member")
		v = value.get()
		Dom.div !->
			Dom.style color: (if v then 'inherit' else '#aaa')
			Dom.text (if v then Plugin.userName(v) else tr("Nobody"))
		if v
			Ui.avatar Plugin.userAvatar(v), !->
				Dom.style position: 'absolute', right: '6px', top: '50%', marginTop: '-20px'

		Dom.onTap !->
			Modal.show opts.selectTitle||tr("Select member"), !->
				Dom.style width: '80%'
				Dom.div !->
					Dom.style
						maxHeight: '40%'
						overflow: 'auto'
						_overflowScrolling: 'touch'
						backgroundColor: '#eee'
						margin: '-12px'

					Plugin.users.iterate (user) !->
						Ui.item !->
							Ui.avatar user.get('avatar')
							Dom.text user.get('name')

							if +user.key() is +value.get()
								Dom.style fontWeight: 'bold'

								Dom.div !->
									Dom.style
										Flex: 1
										padding: '0 10px'
										textAlign: 'right'
										fontSize: '150%'
										color: Plugin.colors().highlight
									Dom.text "✓"

							Dom.onTap !->
								handleChange user.key()
								value.set user.key()
								Modal.remove()
			, (choice) !->
				log 'choice', choice
				if choice is 'clear'
					handleChange ''
					value.set ''
			, ['cancel', tr("Cancel"), 'clear', tr("Clear")]

exports.renderSettings = !->
	if Db.shared
		Dom.text tr("Game has already started")

	else
		selectMember
			name: 'opponent'
			title: tr("Opponent")

exports.render = !->
	if Db.shared.get('waitWhite') && Db.shared.get('white') is Plugin.userId()
		renderChallenge 'white'

	else if Db.shared.get('waitBlack') && Db.shared.get('black') is Plugin.userId()
		renderChallenge 'black'

	else if !Db.shared.get('waitWhite') && !Db.shared.get('waitBlack')
		renderGame()

	else
		renderWait()

renderChallenge = !->
	Dom.div !->
		Dom.text tr("You are challenged. Accept?")
		Ui.bigButton tr("Accept"), !->
			Server.call 'accept'


renderWait = !->
	Dom.div !->
		Dom.style
			padding: '8px'
			textAlign: 'center'
			fontSize: '120%'
		Dom.text tr("Waiting for opponent to accept...")


renderGame = !->
	chess = new Chess(Db.shared.ref('game'))
	dbg.chess = chess

	isBlack = Db.shared.get('black') is Plugin.userId() and Db.shared.get('white') isnt Plugin.userId()

	renderSide = (side) !->
		Dom.div !->
			Dom.style
				textAlign: 'center'
				fontSize: '130%'
				padding: '8px 0'
			Dom.text Plugin.userName(Db.shared.get(side))

			if chess.result.get() is side
				Dom.text " - wins!"

			if chess.result.get() is 'draw'
				Dom.text " - draw"

			else if chess.turn.get() is side
				Dom.text " - to move"

	renderSide if isBlack then 'white' else 'black'
	
	Dom.div !->
		Dom.style
			display_: 'box'
			_boxAlign: 'center'
			_boxPack: 'center'
			margin: '4px 0'

		selected = Obs.create {}

		Dom.div !->
			size = 0|Math.max(200, Math.min(Dom.viewport.get('width')-16, 480)) / 8
			Dom.style
				boxShadow: '0 0 8px #000'
				width: "#{size*8}px"

			for y,yi in (if isBlack then '12345678' else '87654321') then do (y,yi) !->
				Dom.div !->
					for x,xi in (if isBlack then 'hgfedcba' else 'abcdefgh') then do (x,xi) !->
						Dom.div !->
							Dom.style
								display: 'inline-block'
								height: "#{size}px"
								width: "#{size}px"
								background: if selected.get(x+y)
										Plugin.colors().highlight
									else if chess.last.get(1) is x+y
										'#aaf'
									else if ((xi%2)!=(yi%2)) == isBlack
										'white'
									else
										'black'

							if piece = chess.board.get(x+y)
								Dom.div !->
									Dom.style
										height: '100%'
										width: '100%'
										background: "url(#{Plugin.resourceUri piece+'.png'}) no-repeat 50% 50%"
										backgroundSize: "#{0|size*.75}px"

							Dom.onTap !->
								from = false
								for k of selected.get()
									from = k
									break

								if piece and piece[0] is chess.turn.get()[0] and !from
									selected.set x+y, true
								else if from and from isnt x+y
									log 'move', from, '>', x+y
									type = chess.canMove from, x+y
									if type is 'promotion'
										t = chess.turn.get()[0]
										choosePiece [t+'q',t+'r',t+'b',t+'n'], (piece) ->
											if piece
												Server.sync 'move', from, x+y, piece[1], !->
													chess.move from, x+y, piece[1]
									else if type
										Server.sync 'move', from, x+y, !->
											chess.move from, x+y
									else
										Toast.show tr("Invalid move :(")

									selected.set {}
								else
									selected.set {}

	renderSide if isBlack then 'black' else 'white'

	Social.renderComments()
	

choosePiece = (pieces, cb) !->
	require('modal').show tr("Choose piece"), !->
		pieces.forEach (piece) !->
			Dom.div !->
				Dom.style
					display: 'inline-block'
					height: '40px'
					width: '40px'
					margin: '4px'
					background: "url(#{Plugin.resourceUri piece+'.png'}) no-repeat 50% 50%"
					backgroundSize: '32px'

				Dom.onTap !->
					require('modal').remove()
					cb(piece)
	, !->
		cb()
	, ['cancel', tr("Cancel")]


