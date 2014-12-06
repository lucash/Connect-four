Db = require 'db'

exports.init = !->
	Db.shared.set 'board', do ->
		board = {}
		for color in ['w', 'b']
			for x,piece of {a:'r', b:'n', c:'b', d:'q', e:'k', f:'b', g:'n', h:'r'}
				board[x+(if color is 'w' then 1 else 8)] = color + piece
				board[x+(if color is 'w' then 2 else 7)] = color + 'p'
		board
	Db.shared.set 'turn', 'white'
	Db.shared.set 'moveId', 1
	Db.shared.set 'castling', {wk: true, wq: true, bk: true, bq: true}
		# indicates white/black king/queenside castling still possible

exports.move = (from, to, promotionPiece='q') ->
	boardRef = Db.shared.ref('board')
	return false if !boardRef

	type = canMove(from, to)
	return false if !type

	square = boardRef.get from
	[color,piece] = square

	capture = !!boardRef.peek(to)

	boardRef.set to, if type is 'promotion' then color+promotionPiece else square
	boardRef.remove from

	if type is 'enPassant' and lastTo = Db.shared.peek('last')?[1]
		boardRef.remove lastTo

	else if type is 'castle'
		boardRef.remove (if to[0] is 'g' then 'h' else 'a')+to[1]
		boardRef.set (if to[0] is 'g' then 'f' else 'd')+to[1], color+'r'

	if piece is 'k' or (piece is 'r' and from.charAt(0) is 'a')
		Db.shared.remove 'castling', color + 'q'
	if piece is 'k' or (piece is 'r' and from.charAt(0) is 'h')
		Db.shared.remove 'castling', color + 'k'

	Db.shared.set 'last', [from, to]

	color = Db.shared.modify 'turn', (t) -> if t is 'white' then 'black' else 'white'

	if mate = isMate(boardRef.get(), color[0])
		Db.shared.set 'result', if mate is 'stale' then 'draw' else if color is 'white' then 'black' else 'white'
	else if color is 'w'
		Db.shared.modify 'moveId', (m) -> m+1

	# return notation string:
	if type is 'castle' and to[0] is 'g'
		'0-0'
	else if type is 'castle'
		'0-0-0'
	else
		(if piece isnt 'p' then piece.toUpperCase() else '') + (if capture then 'x' else '') + to
	
exports.canMove = canMove = (from, to) ->
	square = Db.shared.get('board', from)
	return false if !square

	[color,piece] = square

	return false if color isnt Db.shared.get('turn')[0]

	board = Db.shared.get('board')
	isValid = false
	for move,type of findMoves(board, from)
		isValid = move is to
		break if isValid
	return false if !isValid

	board[to] = square
	delete board[from]
	return false if isCheck(board,color)

	type

exports.isCheck = isCheck = (board, forColor) ->
	attacked = {}
	kingLoc = false
	for loc,square of board when square?
		#log 'isCheck?', loc, square
		if square[0] isnt forColor
			for move of findMoves(board, loc)
				attacked[move] = true
		else if square is forColor + 'k'
			kingLoc = loc
	if attacked[kingLoc]
		kingLoc

isMate = (board, forColor) ->
	# check if stale or check mate on board
	# forColor: 'w' || 'b'
	
	for loc,square of board when square?[0] is forColor
		moves = findMoves(board,loc)
		delete board[loc]
		for move of moves
			prev = board[move]
			board[move] = square
			if not isCheck(board, forColor)
				#log 'no mate; move', loc, square, 'to', move
				board[move] = prev
				board[loc] = square
				return false
			board[move] = prev
		board[loc] = square

	#log 'looks like mate!', forColor
	# no moves? then it's either checkmate or stalemate
	if isCheck(board, forColor) then 'check' else 'stale'

exports.find = (base) ->
	findMoves Db.shared.get('board'), base

findMoves = (board, base) ->
	# get array of possible moves from a given start location
	square = board[base]
	[color,piece] = square

	moves = {}
	findMove = (deltaX, deltaY, ifEmpty, special) ->
		loc = locDelta(base, deltaX, deltaY)
		if !loc or (board[loc]?[0] is color)
			# invalid location, or own piece
			false
		else
			# ifEmpty == true: only add if square is empty
			# ifEmpty == false: only add if square contains opponent piece
			# ifEmpty == undefined: add if square is empty or contains opponent piece
			# ifEmpty == null: never add
			if ifEmpty isnt null and (!ifEmpty? or (ifEmpty == !board[loc]))
				moves[loc] = special||true # add to possible moves

			!board[loc] # whether to continue search

	if piece is 'p'
		y = if color is 'w' then 1 else -1
		isPromotion = +base[1] is (if color is 'w' then 7 else 2)
		if findMove(0, y, true, (if isPromotion then 'promotion'))
			if +base[1] is (if color is 'w' then 2 else 7)
				findMove(0, y*2, true)
		last = Db.shared.peek('last')
		for x in [-1,1]
			enPassant = last and (last[1] is locDelta(base,x,0)) and board[last[1]][1] is 'p'
			findMove(x, y, (if enPassant then undefined else false), (if isPromotion then 'promotion' else if enPassant then 'enPassant'))

	else if piece is 'n'
		explore = [[2,1],[1,2],[-1,2],[-2,1],[-2,-1],[-1,-2],[1,-2],[2,-1]]
		explore.single = true

	else if piece in ['k','q']
		explore = [[1,0],[0,1],[-1,0],[0,-1],[1,1],[1,-1],[-1,-1],[-1,1]]

		if piece is 'k'
			explore.single = true
			# check castling
			for side,x of {k:1, q:-1}
				if Db.shared?.peek('castling', color+side) and findMove(x,0,null)
					# todo: check for check
					findMove(x+x, 0, true, 'castle')

	else if piece is 'r'
		explore = [[1,0],[0,1],[-1,0],[0,-1]]

	else if piece is 'b'
		explore = [[1,1],[1,-1],[-1,1],[-1,-1]]

	for [dx,dy] in explore||[]
		x = y = 0
		loop
			x += dx
			y += dy
			break if !findMove(x,y) or explore.single
	
	moves
	
locDelta = (base, deltaX, deltaY) ->
	to = String.fromCharCode(base.charCodeAt(0) + deltaX) + (parseInt(base[1]) + deltaY)
	if to.length == 2 and ('a'.charCodeAt(0) <= to.charCodeAt(0) <= 'h'.charCodeAt(0)) and (1 <= parseInt(to.charAt(1)) <= 8)
		to

