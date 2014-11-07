Db = require 'db'
Plugin = require 'plugin'
Event = require 'event'
{Chess} = require 'chess'

exports.onInstall = (config) !->
	if config and config.opponent
		config = if Math.random()>.5
				{white: Plugin.userId(), black: config.opponent}
			else
				{black: Plugin.userId(), white: config.opponent}
	if config and config.white and config.black
		Db.shared.set
			white: +config.white
			black: +config.black
			waitWhite: true
			waitBlack: true

		accept(Plugin.userId())

		Event.create
			unit: 'game'
			text: "Chess: #{Plugin.userName()} wants to play"
			for: [+config.white, +config.black]
			new: [-Plugin.userId()]

exports.onConfig = !->
	# todo

exports.getTitle = ->
	Plugin.userName(Db.shared.get('white')) + ' vs ' + Plugin.userName(Db.shared.get('black'))

exports.client_accept = !->
	accept(Plugin.userId())

accept = (userId) !->
	log 'accept', userId
	waitWhite = Db.shared.get('waitWhite')
	waitBlack = Db.shared.get('waitBlack')
	if waitWhite || waitBlack
		if userId is Db.shared.get('white')
			Db.shared.remove 'waitWhite'
			waitWhite = false
		if userId is Db.shared.get('black')
			Db.shared.remove 'waitBlack'
			waitBlack = false

		if !waitWhite && !waitBlack
			log 'game begin'
			Event.create
				unit: 'game'
				text: "Game has begun!"
				for: [Db.shared.get('white'), Db.shared.get('black')]
				new: [-userId]
			Db.shared.set 'game', require('chess').setup()

exports.client_move = (from, to, promotionPiece) !->
	game = Db.shared.ref('game')
	(new Chess(game)).move from, to, promotionPiece

	Event.create
		unit: 'move'
		text: "Chess: #{Plugin.userName()} moved"
		for: [Db.shared.get('white'), Db.shared.get('black')]
		new: [-Plugin.userId()]

