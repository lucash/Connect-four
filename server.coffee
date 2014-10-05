Db = require 'db'
Plugin = require 'plugin'
Event = require 'event'

exports.client_challenge = (otherId) !->
	gameId = Db.shared.modify 'maxGameId', (v) -> (v||0) + 1
	
	Db.shared.set 'games', gameId,
		player0: Plugin.userId()
		player1: +otherId
		state: 'challenge'
		board: {
			0: {0:'wr', 1:'wn', 2:'wb', 3:'wq', 4:'wk', 5:'wb', 6:'wn', 7:'wr'},
			1: {0:'wp', 1:'wp', 2:'wp', 3:'wp', 4:'wp', 5:'wp', 6:'wp', 7:'wp'},
			6: {0:'bp', 1:'bp', 2:'bp', 3:'bp', 4:'bp', 5:'bp', 6:'bp', 7:'bp'},
			7: {0:'br', 1:'bn', 2:'bb', 3:'bq', 4:'bk', 5:'bb', 6:'bn', 7:'br'}
		}
		castling:
			w: {east: true, west: true}
			b: {east: true, west: true}
		turn: 'w'
		move: 0
		log: {}

	Db.personal(Plugin.userId()).set 'gameId', gameId
	Db.personal(otherId).set 'gameId', gameId

	Event.create
		unit: 'accept'
		text: "Chess: #{Plugin.userName()} challenged you!"
		include: [otherId]


exports.client_cancel = !->
	gameId = Db.personal(Plugin.userId()).get 'gameId'
	game = Db.shared.ref 'games', gameId
	state = game.get('state')
	if state is 'challenge'
		# cancel challenge by player0 or reject challenge by player1
		game.set 'state', 'reject'
	else if state is 'play'
		game.set 'state', 'resign'
	else
		# affirm cancel by other
		Db.shared.remove 'games', gameId
	Db.personal(Plugin.userId()).remove 'gameId'

exports.client_accept = !->
	gameId = Db.personal(Plugin.userId()).get 'gameId'
	game = Db.shared.ref 'games', gameId
	if game.get('state') is 'challenge'
		game.set 'state', 'play'
		game.set 'playerw', player0 = game.get('player0')
		game.set 'playerb', game.get('player1')
		game.remove 'player0'
		game.remove 'player1'

		Event.create
			unit: 'accept'
			text: "Chess: #{Plugin.userName()} accepted your challenge"
			include: [player0]

exports.client_move = (from, to) !->
	gameId = Db.personal(Plugin.userId()).get 'gameId'
	game = Db.shared.ref 'games', gameId
	turn = game.get('turn')
	if game.get('state') isnt 'play' or game.get('player'+turn) isnt Plugin.userId()
		return

	board = game.get 'board'

	color = board[from[0]][from[1]]?.charAt(0)
	piece = board[from[0]][from[1]]?.charAt(1)
	if color isnt turn
		return

	g = generators[piece](board,from, game)
	while move = g()
		if move[0] is to[0] and move[1] is to[1]
			break

	if !move
		return

	text = (if piece is 'p' then '' else piece.toUpperCase()) +
		(if board[to[0]]?[to[1]] then 'x' else '') + String.fromCharCode(97+to[1]) + (to[0]+1)

	(board[to[0]]||={})[to[1]] = color + piece
	delete board[from[0]][from[1]]
	ownKing = {}
	attackBoard = makeAttackBoard(board,turn,ownKing)
	if attackBoard[ownKing[0]]?[ownKing[1]]
		return

	if piece in ['k', 'r'] and game.get('castling', color)
		if piece is 'k'
			game.remove 'castling', color
			if to[1] in [6,2]
				rook = if to[1] is 6 then 7 else 0
				game.set 'board', to[0], (if to[1] is 6 then 5 else 3), board[to[0]][rook]
				game.remove 'board', to[0], rook
				text = if to[1] is 6 then '0-0' else '0-0-0'
		else if from[1] is 0
			game.remove 'castling', color, 'west'
		else if from[1] is 7
			game.remove 'castling', color, 'east'

	game.set 'board', to[0], to[1], color + piece
	game.remove 'board', from[0], from[1]
	game.set 'log', game.get('move'), turn, text
	turn = game.modify 'turn', (t) -> if t is 'w' then 'b' else 'w'
	if turn is 'w'
		game.modify 'move', (m) -> m+1

	Event.create
		unit: 'move'
		text: "Chess: #{Plugin.userName()} moved #{text}"
		include: [game.get('player'+turn)]

metaGenerator = (dirs, depthOfOne) ->
	(board,base) ->
		dir = 0
		{0:at0, 1:at1} = base
		myColor = board[base[0]][base[1]].charAt(0)
		next = ->
			return false if dir is dirs.length
			at0 += dirs[dir][0]
			at1 += dirs[dir][1]
			r = false
			if f=board[at0]?[at1]
				if f.charAt(0) isnt myColor
					# we can capture the other's piece
					r = [at0, at1]
			else if 0 <= at0 <= 7 and 0 <= at1 <= 7
				r = [at0, at1]
				if !depthOfOne
					return r

			dir++
			{0:at0, 1:at1} = base
			return if r then r else next()

generators =
	r: metaGenerator [[1,0],[0,1],[-1,0],[0,-1]]
	b: metaGenerator [[1,1],[1,-1],[-1,-1],[-1,1]]
	q: metaGenerator [[1,0],[0,1],[-1,0],[0,-1],[1,1],[1,-1],[-1,-1],[-1,1]]
	n: metaGenerator [[2,1],[1,2],[-1,2],[-2,1],[-2,-1],[-1,-2],[1,-2],[2,-1]], true
	k: (board,base,game) ->
		dirs = [[1,0],[0,1],[-1,0],[0,-1],[1,1],[1,-1],[-1,-1],[-1,1]]
		myColor = board[base[0]][base[1]].charAt(0)
		if game and game.get('castling',myColor,'west')
			dirs.push [0,-2]
		if game and game.get('castling',myColor,'east')
			dirs.push [0,2]
		metaGenerator(dirs,true)(board, base)

	p: (board,base) ->
		myColor = board[base[0]][base[1]].charAt(0)
		dirs = []
		dir = if myColor is 'w' then 1 else -1
		start = if myColor is 'w' then 1 else 6
		if !board[base[0]+dir]?[base[1]]
			dirs.push [dir,0]
			if base[0] is start and !board[base[0]+dir+dir]?[base[1]]
				dirs.push [dir+dir,0]
		for eastWest in [-1,1]
			if (c=board[base[0]+dir]?[base[1]+eastWest]) and c.charAt(0) isnt myColor
				dirs.push [dir,eastWest]
		metaGenerator(dirs,true)(board, base)


makeAttackBoard = (board, color, ownKing) ->
	ab = {}
	for i of board
		for j of board[i]
			piece = board[i][j]
			if piece.charAt(0) isnt color
				g = generators[piece.charAt(1)](board,[+i,+j])
				while move = g()
					(ab[move[0]]||={})[move[1]] = true
			else if piece.charAt(1) is 'k'
				ownKing[0] = i
				ownKing[1] = j
	ab

###
#validate =
	p: (board, from, to, turn) ->
		capture = board[to[0]]?[to[1]]
		if !capture and to[1] == from[1] and to[0] == from[0] + (if turn then -1 else 1)
			# one ahead 
			true
		else if !capture and to[1] == from[1] and from[0] == (if turn then 6 else 1) and to[0] == (if turn then 4 else 3)
			# two ahead in initial position
			if !board[if turn then 5 else 2]?[from[1]]
				true
		else if capture and to[1] in [from[1]-1,from[1]+1] and to[0] == from[0] + (if turn then -1 else 1)
			# capture
			true

	n: (board, from, to) ->
		d0 = Math.abs(from[0] - to[0])
		d1 = Math.abs(from[1] - to[1])
		d0 in [1,2] and d1 in [1,2] and d0+d1 == 3
		
	b: (board, from, to) ->
		d = Math.abs(from[0] - to[0])
		if !d || d isnt Math.abs(from[1] - to[1])
			return

		for i in [1...d] by 1
			if board[from[0] + if to[0] > from[0] then i else -i]?[from[1] + if to[1] > from[1] then i else -i]
				return
		true

	r: (board, from, to) ->
		if from[0] is to[0]
			for d in [from[1]...to[1]]
				if d isnt from[1] and board[from[0]]?[d]
					return
			true
		else if from[1] is to[1]
			for d in [from[0]...to[0]]
				if d isnt from[0] and board[d]?[to[0]]
					return
			true

	q: (board, from, to) ->
		@b(board, from, to) || @r(board, from, to)

	k: (board, from, to) ->
		Math.abs(from[0] - to[0]) in [0,1] and Math.abs(from[1] - to[1]) in [0,1]
###
