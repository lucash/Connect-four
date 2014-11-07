exports.setup = ->
	board: do ->
		board = {}
		for color in ['w', 'b']
			for x,piece of {a:'r', b:'n', c:'b', d:'q', e:'k', f:'b', g:'n', h:'r'}
				board[x+(if color is 'w' then 1 else 8)] = color + piece
				board[x+(if color is 'w' then 2 else 7)] = color + 'p'
		board
	turn: 'white'
	moveId: 1
	result: false
	castling: {wk: true, wq: true, bk: true, bq: true}
		# white/black king/queenside castling still possible

class Chess
	
	state = null
	constructor: (_state) !->
		state = _state
		if _state.readOnly?
			@board = state.ref('board').readOnly()
			@turn = state.ref('turn').readOnly()
			@moveId = state.ref('moveId').readOnly()
			@last = state.ref('last').readOnly()
			@result = state.ref('result').readOnly()

	move: (from, to, promotionPiece='q') ->
		type = @canMove(from, to)
		return false if !type

		square = state.get 'board', from
		[color,piece] = square

		state.set 'board', to, if type is 'promotion' then color+promotionPiece else square
		state.remove 'board', from

		if type is 'enPassant' and lastTo = state.peek('last')?[1]
			state.remove 'board', lastTo

		else if type is 'castle'
			state.remove 'board', (if to[0] is 'g' then 'h' else 'a')+to[1]
			state.set 'board', (if to[0] is 'g' then 'f' else 'd')+to[1], color+'r'

		if piece is 'k' or (piece is 'r' and from.charAt(0) is 'a')
			state.remove 'castling', color + 'q'
		if piece is 'k' or (piece is 'r' and from.charAt(0) is 'h')
			state.remove 'castling', color + 'k'

		state.set 'last', [from, to]

		color = state.modify 'turn', (t) -> if t is 'white' then 'black' else 'white'

		if mate = isMate(state.get('board'), color[0])
			state.set 'result', if mate is 'stale' then 'draw' else if color is 'white' then 'black' else 'white'
		else if color is 'w'
			state.modify 'moveId', (m) -> m+1

		true
		
	canMove: (from, to) ->
		square = state.get('board', from)
		return false if !square

		[color,piece] = square

		return false if color isnt state.get('turn')[0]

		isValid = false
		for move,type of findMoves(state.get('board'), from)
			isValid = move is to
			break if isValid
		return false if !isValid

		board = state.get('board')
		board[to] = square
		delete board[from]
		return false if isCheck(board,color)

		type

	isCheck = (board, forColor) ->
		attacked = {}
		kingLoc = false
		for loc,square of board when square?
			#log 'isCheck?', loc, square
			if square[0] isnt forColor
				for move of findMoves(board, loc)
					attacked[move] = true
			else if square is forColor + 'k'
				kingLoc = loc
		attacked[kingLoc]

	isMate = (board, forColor) ->
		# see if there's possible legal moves by forColor
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

	find: (base) ->
		findMoves state.get('board'), base

	findMoves = (board, base) ->
		#log 'findMoves', base
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
			last = state?.peek('last')
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
					if state and state.peek('castling', color+side) and findMove(x,0,null)
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

exports.Chess = Chess
