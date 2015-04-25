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
Social = require 'social'
{tr} = require 'i18n'

exports.renderSettings = !->
	if Db.shared
		Dom.text tr("Game has started")

	else
		selectMember
			name: 'opponent'
			title: tr("Opponent")

isUserTurn = !->
  redId = Db.shared.get('red')
  yellowId = Db.shared.get('yellow')
  turn = Db.shared.get('turn')
  return (Plugin.userId() is redId and turn is 'red') or (Plugin.userId() is yellowId and turn is 'yellow')

getOpponentName = !->
	if Plugin.userId() is Db.shared.get('red')
		return Plugin.userName(Db.shared.get('yellow'))
	else
		return Plugin.userName(Db.shared.get('red'))

exports.render = !->

	redId = Db.shared.get('red')
	yellowId = Db.shared.get('yellow')
	color = if Plugin.userId() is redId
			'red'
		else if Plugin.userId() is yellowId
			'yellow'

	if challenge=Db.shared.get('challenge')
		Dom.div !->
			Dom.style
				padding: '8px'
				textAlign: 'center'
				fontSize: '120%'

			Dom.div !->
				Dom.span !->
					Dom.cls 'red'
					Dom.text Plugin.userName(redId)
				Dom.span !->
					Dom.text ' vs. '
				Dom.span !->
					Dom.cls 'yellow'
					Dom.text Plugin.userName(yellowId)

			if challenge[Plugin.userId()]
				if Db.shared.get('red') is Plugin.userId()
					challenger = Db.shared.get('yellow')
				else
					challenger = Db.shared.get('red')
				Dom.div tr("%1 challenged you for a game of connect four.", Plugin.userName(challenger))
				
				Ui.bigButton tr("Accept"), !->
					Server.call 'accept'

			else
				break for id of challenge
				Dom.div tr("Waiting for %1 to accept...", Plugin.userName(id))

	else
		if Db.shared.get('winner')?
			Dom.div !->
				Dom.cls 'finished'
				if Db.shared.get('winner') is Plugin.userId()
					Dom.cls 'winner'
					Dom.text 'You won'
				else if Plugin.userId() is Db.shared.get('red') or Plugin.userId() is Db.shared.get('yellow')
					Dom.cls 'looser'
					Dom.text 'You lost'
				else
					Dom.cls 'neutral'
					Dom.text Plugin.userName(Db.shared.get('winner')) + ' won the game'
			if Plugin.userId() is Db.shared.get('red') or Plugin.userId() is Db.shared.get('yellow')
				Ui.bigButton "New game", !->
					Server.call 'reset'
		
		if not Db.shared.get('winner')?
			Dom.div !->
				Dom.cls 'turn'
				Dom.cls Db.shared.get('turn')
				if isUserTurn()
					Dom.text 'It\'s your turn'
				else
					Dom.text 'Waiting for ' + getOpponentName()
		Dom.div !->
			Dom.cls 'board'
			columns = Db.shared.ref("columns")
			[0,1,2,3,4,5,6].forEach (column) !->
				Dom.div !->
					Dom.cls 'columnselection'
					Dom.cls 'column'
					if isUserTurn() and not columns.ref(column).get(5) and not Db.shared.get('winner')?
						Dom.cls 'active'
						Dom.onTap !->
							Server.call 'add', column
			[0,1,2,3,4,5].forEach (row) !->
				row = 5 - row
				[0,1,2,3,4,5,6].forEach (column) !->
					Dom.div !->
						Dom.cls 'square'
						Dom.cls 'column'
						if columns.get(column)? and columns.ref(column).get(row)?
							Dom.cls columns.ref(column).get(row)
							last = Db.shared.get('last')
							if column is last.column and row is last.row
								Dom.cls 'last'

	Social.renderComments()


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

Dom.css
	'.board':
		boxShadow: '0 0 8px #000'
	'.column':
		width: '14.28%'
		boxSizing: 'border-box'
		position: 'relative'
		display: 'inline-block'
	'.square':
		padding: '14.28% 0 0' # use padding-top trick to maintain aspect ratio
		border: '1px solid whitesmoke'
		background: 'darkgrey'
	'.square:before':
		content: '\' \''
		position: 'absolute'
		
		width: '80%'
		height: '80%'
		
		marginLeft: '10%'
		marginTop: '10%'
		
		borderRadius: '100000px'
		background: 'white none repeat scroll 0% 0%'
		top: '0'
		left: '0'
	'.square.yellow:before':
		background: 'yellow'
	'.square.red:before':
		background: 'red'
	'.square.last':
		background: 'lightgrey'
	'.columnselection.active':
		cursor: 'pointer'
	'.columnselection.active:after':
		borderTopColor: '#0077CF'
	'.columnselection':
		height: '0'
		marginBottom: '30px'
		border: '1px solid transparent'
	'.columnselection:after':
		content: '\' \''
		top: '100%'
		left: '50%'
		border: 'solid transparent'
		height: '0'
		width: '0'
		position: 'absolute'
		borderColor: 'transparent'
		borderTopColor: 'grey'
		borderWidth: '20px'
		marginLeft: '-20px'
	'.finished':
		boxShadow: '0px 0px 10px'
		textAlign: 'center'
		fontSize: '5em'
		fontWeight: 'bold'
		border: '2px solid'
		textShadow: '3px 3px 5px'
		marginBottom: '10px'
	'.finished.winner':
		color: 'green'
		borderColor: 'green'
	'.finished.looser':
		color: 'red'
		borderColor: 'red'
	'.finished.neutral':
		color: 'grey'
		borderColor: 'grey'
		fontSize: '2em'
		padding: '1em'
	'.turn':
		textAlign: 'center'
		fontSize: '1.5em'
		padding: '0.5em'
	'.yellow':
		color: 'yellow'
	'.red':
		color: 'red'
