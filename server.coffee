Db = require 'db'
Plugin = require 'plugin'
Event = require 'event'

exports.onInstall = (config) !->
	initializeGame(config)

initializeGame = (config) !->
	if config and config.opponent
		config = if Math.random()>.5
				{red: Plugin.userId(), yellow: config.opponent}
			else
				{yellow: Plugin.userId(), red: config.opponent}
	if config and config.red and config.yellow
		challenge = {}
		challenge[+config.red] = true
		challenge[+config.yellow] = true
		wins = Db.shared.get('wins')
		Db.shared.set
			red: +config.red
			yellow: +config.yellow
			challenge: challenge
			columns: {}
			turn: 'red'
			winner: null
			wins: wins

		Event.create
			unit: 'game'
			text: "Connect four: #{Plugin.userName()} wants to play"
			for: x=[+config.red, +config.yellow]
			new: [-Plugin.userId()]

		accept(Plugin.userId())
			# todo: this currently shows some error due to a framework Db issue

addWin = (userId) !->
	wins = Db.shared.ref('wins')
	if !wins?
		Db.shared.set('wins', {})
	if !wins.get(userId)
		wins.set(userId, 0)
	wins.modify userId, (count) !-> 
		log count, count+1
		return count+1

exports.onUpgrade = !->

exports.onConfig = !->

exports.getTitle = ->
	Plugin.userName(Db.shared.get('red')) + ' vs ' + Plugin.userName(Db.shared.get('yellow'))

exports.client_accept = !->
	accept(Plugin.userId())

exports.client_reset = !->
	if Db.shared.get('red') is Plugin.userId()
		opponentId = Db.shared.get('yellow')
	else
		opponentId = Db.shared.get('red')
	initializeGame({opponent: opponentId})

exports.client_add = (column) !->
	columns = Db.shared.ref('columns')
	
	if !(columns.get(column)?)
		itemCount = 0
		columns.set(column, {})
	else
		itemCount = Object.keys(columns.get(column)).length
	
	if itemCount < 6
		columns.ref(column).set(itemCount, Db.shared.get('turn'))
	
	Db.shared.set('last', {
		column: column,
		row: itemCount
	})
	
	if columnContainsFour(column) or rowContainsFour(itemCount) or diagonalContainsFour(column, itemCount)
		if Db.shared.get('turn') is 'red'
			Db.shared.set('winner', Db.shared.get('red'))
			addWin(Db.shared.get('red'))
		else
			Db.shared.set('winner', Db.shared.get('yellow'))
			addWin(Db.shared.get('yellow'))
	else
		if Db.shared.get('turn') is 'red'
			Db.shared.set('turn', 'yellow')
			nextTurn = 'yellow'
		else if Db.shared.get('turn') is 'yellow'
			Db.shared.set('turn', 'red')
			nextTurn = 'red'
	
	if nextTurn?
		if nextTurn is 'red'
			nextTurnPlayerId = Db.shared.get('red')
		else
			nextTurnPlayerId = Db.shared.get('yellow')
		
		Event.create
			unit: 'game'
			text: "Connect four: Its your turn against #{Plugin.userName()}"
			for: x=[+nextTurnPlayerId]
			new: [-Plugin.userId()]

columnContainsFour = (column) !->
	columnData = Db.shared.ref('columns').get(column)
	turnColor = Db.shared.get('turn')
	count = 0
	for row of columnData
		if turnColor is columnData[row]
			count++
			if (count is 4)
				return true
		else
			count = 0
	
	return false

rowContainsFour = (row) !->
	turnColor = Db.shared.get('turn')
	count = 0
	for column of [0,1,2,3,4,5,6]
		if turnColor is getField(column, row)
			count++
			if (count is 4)
				return true
		else
			count = 0
	
	return false

diagonalContainsFour = (column, row) !->
	origColumn = column
	origRow = row
	
	currentTurn = Db.shared.get('turn')
	
	count = 0
	# left bottom
	while (getField(column, row) is currentTurn)
		count++
		column--
		row--
	
	# right top do not count original field again
	column = origColumn + 1
	row = origRow + 1
	while (getField(column, row) is currentTurn)
		count++
		column++
		row++
	
	if count >= 4
		return true
	
	# different diagonal
	count = 0
	column = origColumn
	row = origRow
	# left top
	while (getField(column, row) is currentTurn)
		count++
		column--
		row++
	
	# right bottom
	column = origColumn + 1
	row = origRow - 1
	# left top
	while (getField(column, row) is currentTurn)
		count++
		column++
		row--
	
	if count >= 4
		return true

getField = (column, row) !->
	columns = Db.shared.ref('columns')
	if columns.get(column) and columns.ref(column).get(row)
		return columns.ref(column).get(row)

accept = (userId) !->
	log 'accept', userId
	Db.shared.remove 'challenge', userId
	if !Object.keys(Db.shared.get('challenge')).length # objEmpty(...)
		log 'game begin'
		Db.shared.remove 'challenge'
		Event.create
			unit: 'game'
			text: "Connect four game has begun!"
			for: [Db.shared.get('red'), Db.shared.get('yellow')]

