m <<<
	class: (...clses) ->
		res = []
		for cls in clses
			if Array.isArray cls
				res.push m.class ...cls
			else if cls instanceof Object
				for k, v of cls
					res.push k if v
			else if cls?
				res.push cls
		res.join " "

	style: (...styls) ->
		res = {}
		for styl in styls
			if Array.isArray styl
				styl = m.style ...styl
			if styl instanceof Object
				for k, val of styl
					res[k] = val
		res

	bind: (comp) ->
		for k, v of comp
			if typeof v is \function
				comp[k] = v.bind comp
		comp

Utils =
	hexToRgba: (color) ->
		color = @extendColor color
		[, r, g, b, a] = color is /^#(..)(..)(..)(..)$/
		r = parseInt r, 16
		g = parseInt g, 16
		b = parseInt b, 16
		a = +(parseInt(a, 16) / 255)toFixed 2
		[r, g, b, a]

	rgbaToHex: (rgba) ->
		rgba = [...rgba]
		rgba.3 = Math.round rgba.3 * 255
		color = \# + rgba.map (.toString 16 .padStart 2 0) .join ""
		@shortenColor color

	extendColor: (color) ->
		match color
		| /^#[a-f\d]{3}$/i
			color[0 1 1 2 2 3 3] * "" + \ff
		| /^#[a-f\d]{4}$/i
			color[0 1 1 2 2 3 3 4 4] * ""
		| /^#[a-f\d]{6}$/i
			color + \ff
		| /^#[a-f\d]{8}$/i
			color

	shortenColor: (color) ->
		match color
		| /^#[a-f\d]{3}f$/
			color.slice 0 -1
		| /^#([a-f\d])\1([a-f\d])\2([a-f\d])\3(ff)?$/i
			color[0 1 3 5] * ""
		| /^#[a-f\d]{6}ff$/i
			color.slice 0 -2
		| /^#([a-f\d])\1([a-f\d])\2([a-f\d])\3([a-f\d])\4$/i
			color[0 1 3 5 7] * ""
		| /^(#[a-f\d]{3}|#[a-f\d]{4}|#[a-f\d]{6}|#[a-f\d]{8})$/i
			color

	inputizeColor: (color) ->
		match color
		| /^#[a-f\d]{3,4}$/i
			color[0 1 1 2 2 3 3] * ""
		| /^#[a-f\d]{8}$/i
			color[0 1 2 3 4 5 6] * ""
		| /^#[a-f\d]{6}$/i
			color

	mixColor: (base, added) ->
		base = @hexToRgba base
		added = @hexToRgba added
		alpha = +(1 - (1 - added.3) * (1 - base.3))toFixed 2
		mix =
			Math.round added.0 * added.3 / alpha + base.0 * base.3 * (1 - added.3) / alpha
			Math.round added.1 * added.3 / alpha + base.1 * base.3 * (1 - added.3) / alpha
			Math.round added.2 * added.3 / alpha + base.2 * base.3 * (1 - added.3) / alpha
			alpha
		mix = @rgbaToHex mix
		@shortenColor mix

ColorInput = m.bind do
	oninput: (event, vnode) !->
		{value} = event.target
		if event.target.type is \color
			if color = Utils.extendColor vnode.attrs.value
				alpha = color.slice -2
				unless alpha is \ff
					value = value.slice(0 7) + alpha
		vnode.attrs.oninput? value, event
		if color = Utils.shortenColor value
			vnode.attrs.oncolor? color, event

	view: (vnode) ->
		m \.ColorInput,
			class: vnode.attrs.class
			m \input.ColorInput-text,
				minlength: 2
				maxlength: 9
				value: vnode.attrs.value
				oninput: !~>
					@oninput it, vnode
			m \.ColorInput-color,
				style:
					background: vnode.attrs.value
				onclick: (event) !~>
					event.target.nextElementSibling.click!
			m \input.ColorInput-input,
				type: \color
				value: Utils.inputizeColor vnode.attrs.color
				oninput: !~>
					@oninput it, vnode

App = m.bind do
	oninit: !->
		@color = \#333
		@tmpColor = @color
		@gridColor = \#ccc
		@tmpGridColor = @gridColor
		@isShowGrid = yes
		@tileW = 8
		@tileH = 8
		@tmpTileW = @tileW
		@tmpTileH = @tileH
		@isShowTile = yes
		@alphaColor = \#eee
		@tmpAlphaColor = @alphaColor
		@sel = null
		@selPts = []
		@file = null
		@pts = []
		@code = void
		@ctrl = void
		@shift = void
		@alt = void
		@mouse = 0
		@isKeyDown = no
		@x = void
		@y = void
		@cursor = void
		@hists = []
		@histsIndex = 0
		@pushHist!

	resize: (w = @w, h = @h, z = @z) !->
		w = Math.floor +w
		h = Math.floor +h
		z = Math.floor +z
		if 1 <= w <= 1024 and 1 <= h <= 1024 and 2 <= z <= 16
			unless w is @w and h is @h and z is @z
				@w = w
				@h = h
				@z = z
				@tmpW = @w
				@tmpH = @h
				@wz = @w * @z
				@hz = @h * @z
				@vw = Math.floor viewEl.offsetWidth / @z
				@vh = Math.floor viewEl.offsetHeight / @z
				@vw <?= @w
				@vh <?= @h
				@vwz = @vw * @z
				@vhz = @vh * @z
				canvas.width = @vwz
				canvas.height = @vhz
				@g = canvas.getContext \2d
				@g.imageSmoothingEnabled = no
				@redraw!
				m.redraw!

	oncreate: !->
		@resize 48 32 12
		addEventListener \keydown @onkeydown
		addEventListener \keyup @onkeyup
		addEventListener \resize @onresize
		addEventListener \contextmenu (.preventDefault!)

	inBound: (x, y) ->
		0 <= x < @w and 0 <= y < @h

	mergeSelPts: !->
		for pt in @selPts
			if @inBound pt.0, pt.1
				index = @pts.findIndex ~> it.0 is pt.0 and it.1 is pt.1 and it isnt pt
				if index >= 0
					pt.2 = Utils.mixColor @pts[index]2, pt.2
					@pts.splice index, 1
			else
				@pts.splice @pts.indexOf(pt), 1

	onpointerdownEdit: (event) !->
		canvas.setPointerCapture event.pointerId
		@mouse = event.which
		if @mouse is 2
			event.preventDefault!
		@x = void
		@y = void
		@ctrl = event.ctrlKey
		@shift = event.shiftKey
		@alt = event.altKey
		@onpointermoveEdit event, yes yes no

	onpointermoveEdit: (event, isDown, isMove = yes, isUp) !->
		event.redraw = no
		mx = Math.floor event.offsetX / @z
		my = Math.floor event.offsetY / @z
		if mx isnt @x or my isnt @y or isDown or isUp
			if @mouse
				if isDown
					@x = mx
					@y = my
				inBound = @inBound mx, my
				if @shift
					if isDown
						if @selPts.length
							@mergeSelPts!
						@sel = x0: mx, y0: my
						if @mouse is 2
							@selPts = []
					if isMove
						@sel.x = mx
						@sel.y = my
						@sel.x1 = Math.min @sel.x0, mx
						@sel.y1 = Math.min @sel.y0, my
						@sel.x2 = Math.max @sel.x0, mx
						@sel.y2 = Math.max @sel.y0, my
						if @mouse in [1 2]
							@sel.pts = @pts.filter ~>
								@sel.x1 <= it.0 <= @sel.x2 and @sel.y1 <= it.1 <= @sel.y2
						else
							@sel.pts = null
					else
						if @sel.pts
							for pt in @sel.pts
								unless @selPts.includes pt
									@selPts.push pt
						else
							@selPts .= filter ~>
								it.0 < @sel.x1 or it.0 > @sel.x2 or it.1 < @sel.y1 or it.1 > @sel.y2
						@sel = null
						@pushHist!
					@redraw!
				else if @alt
					unless @selPts.length
						if isMove
							if @mouse in [1 3]
								grid = []
								for pt in @pts
									grid[][pt.1][pt.0] = pt
							if @mouse is 1
								if color = grid[my]?[mx]?2
									unless color is @color
										fill = (x, y) !~>
											if @inBound x, y
												if pt = grid[y]?[x]
													if pt.2 is color
														pt.2 = @color
														fill x - 1, y
														fill x + 1, y
														fill x, y - 1
														fill x, y + 1
										fill mx, my
								else
									fill = (x, y) !~>
										if @inBound x, y
											unless pt = grid[][y][x]
												newPt = [x, y, @color]
												@pts.push newPt
												grid[y][x] = newPt
												fill x - 1, y
												fill x + 1, y
												fill x, y - 1
												fill x, y + 1
									fill mx, my
								grid = null
								@redraw!
							else if @mouse is 3
								if color = grid[my]?[mx]?2
									fill = (x, y) !~>
										if @inBound x, y
											if pt = grid[y]?[x]
												if pt.2 is color
													@pts.splice @pts.indexOf(pt), 1
													delete grid[y][x]
													fill x - 1, y
													fill x + 1, y
													fill x, y - 1
													fill x, y + 1
									fill mx, my
								grid = null
								@redraw!
				else
					if @selPts.length
						if @mouse is 2
							if isDown
								@cursor = \copy
						if @mouse in [1 2]
							if isMove
								for pt in @selPts
									if @mouse is 2
										if isDown
											if @inBound pt.0, pt.1
												findPt = @pts.find ~> it.0 is pt.0 and it.1 is pt.1 and it isnt pt
												if findPt
													findPt.2 = Utils.mixColor findPt.2, pt.2
												else
													newPt = [...pt]
													@pts.push newPt
									pt.0 += mx - @x
									pt.1 += my - @y
								@redraw!
							else
								@pushHist!
						else
							inSelPts = @selPts.some ~> it.0 is mx and it.1 is my
							if inSelPts
								for pt in @selPts
									@pts.splice @pts.indexOf(pt), 1
								@selPts = []
								@pushHist!
							else
								@mergeSelPts!
								@selPts = []
							@redraw!
					else
						if inBound
							if @mouse is 1
								if isMove
									pt = @pts.find ~> it.0 is mx and it.1 is my
									if pt
										pt.2 = Utils.mixColor pt.2, @color
									else
										newPt = [mx, my, @color]
										@pts.push newPt
									@redraw!
								else
									@pushHist!
							else if @mouse is 2
								if isMove
									pt = @pts.find ~> it.0 is mx and it.1 is my
									if pt
										@color = @tmpColor = pt.2
							else
								if isMove
									pt = @pts.find ~> it.0 is mx and it.1 is my
									if pt
										@pts.splice @pts.indexOf(pt), 1
										@redraw!
								else
									@pushHist!
			@x = mx
			@y = my
			m.redraw!

	onlostpointercaptureEdit: (event) !->
		@onpointermoveEdit event, no no yes
		@mouse = 0
		unless @isKeyDown
			@ctrl = void
			@shift = void
			@alt = void
			@code = void
			@cursor = void

	onkeydown: (event) !->
		unless event.repeat
			unless event.target.matches "textarea,input:not([type]),input[type=text],input[type=number]"
				unless @mouse
					@ctrl = event.ctrlKey
					@shift = event.shiftKey
					@alt = event.altKey
					{@code} = event
					@isKeyDown = yes
					@cursor = void
					if not @ctrl and @shift and not @alt
						@cursor = \crosshair
					switch @code
					| \KeyS
						if @ctrl
							event.preventDefault!
							if @shift
								@saveAs!
							else
								@save!
					| \KeyO
						if @ctrl
							event.preventDefault!
							@open!
					| \KeyZ
						if @ctrl
							event.preventDefault!
							if @shift
								@redoHist!
							else
								@undoHist!
					| \KeyY
						if @ctrl
							event.preventDefault!
							@redoHist!
					| \Escape
						if @selPts.length
							@mergeSelPts!
							@selPts = []
							@redraw!
					m.redraw!

	onkeyup: (event) !->
		if event.key is \Alt
			event.preventDefault!
		unless @mouse
			@ctrl = void
			@shift = void
			@alt = void
			@code = void
			@cursor = void
			m.redraw!
		@isKeyDown = no

	onresize: (event) !->
		@resize!

	onchangeTileSize: (prop, event) !->
		if value = +event.target.value
			value = Math.floor value
			if 1 < value < 9e9
				@[prop] = value
				@redraw!

	open: !->
		try
			[@file] = await showOpenFilePicker do
				excludeAcceptAllOption: yes
				types:
					accept:
						"image/png": [\.png]
					...
			file = await @file.getFile!
			reader = new FileReader
			reader.onload = !~>
				img = new Image
				img.src = reader.result
				img.onload = !~>
					@resize img.width, img.height
					el = document.createElement \canvas
					el.width = @w
					el.height = @h
					g = el.getContext \2d
					g.imageSmoothingEnabled = yes
					g.drawImage img, 0 0
					data = g.getImageData 0 0 @w, @h .data
					@pts = []
					for i til data.length by 4
						if a = data[i + 3]
							j = i / 4
							x = j % @w
							y = Math.floor j / @w
							r = data[i]
							g = data[i + 1]
							b = data[i + 2]
							a = +(a / 255)toFixed 2
							color = Utils.rgbaToHex [r, g, b, a]
							pt = [x, y, color]
							@pts.push pt
					@sel = null
					@selPts = []
					@redraw!
					m.redraw!
			reader.readAsDataURL file

	save: !->
		if @file
			el = document.createElement \canvas
			el.width = @w
			el.height = @h
			g = el.getContext \2d
			g.imageSmoothingEnabled = yes
			for pt in @pts
				g.fillStyle = pt.2
				g.fillRect pt.0, pt.1, 1 1
			el.toBlob (blob) !~>
				writer = await @file.createWritable!
				await writer.write blob
				await writer.close!
		else
			@saveAs!

	saveAs: !->
		try
			@file = await showSaveFilePicker do
				excludeAcceptAllOption: yes
				types:
					accept:
						"image/png": [\.png]
					...
			await @save!
			m.redraw!

	pushHist: !->
		if @histsIndex
			@hists.splice 0 @histsIndex
			@histsIndex = 0
		hist = JSON.stringify do
			w: @w
			h: @h
			pts: @pts
			selPts: @selPts.map ~> @pts.indexOf it
		willPush = yes
		if oldHist = @hists.0
			if hist is oldHist
				willPush = no
		if willPush
			@hists.unshift hist
			if @hists.length > 100
				@hists.pop!

	undoHist: !->
		if @histsIndex < @hists.length - 1
			hist = @hists[++@histsIndex]
			@applyHist hist

	redoHist: !->
		if @histsIndex > 0
			hist = @hists[--@histsIndex]
			@applyHist hist

	applyHist: (hist) !->
		hist = JSON.parse hist
		{w, h, @pts, @selPts} = hist
		@resize w, h
		@selPts .= map (@pts.)
		@redraw!

	redraw: !->
		@g.clearRect 0 0 @vwz, @vhz
		for pt in @pts
			@g.fillStyle = pt.2
			@g.fillRect pt.0 * @z, pt.1 * @z, @z, @z
		@g.fillStyle = @gridColor
		if @isShowGrid
			@g.globalAlpha = 0.25
			for x til @wz by @z
				@g.fillRect x, 0 1 @hz + 1
			for y til @hz by @z
				@g.fillRect 0 y, @wz + 1, 1
		if @isShowTile
			@g.globalAlpha = 0.5
			for x til @wz by @z * @tileW
				@g.fillRect x, 0 1 @hz + 1
			for y til @hz by @z * @tileH
				@g.fillRect 0 y, @wz + 1, 1
		@g.globalAlpha = 1
		pts = @selPts
		if @sel
			if @sel.pts
				pts ++= @sel.pts
			else
				pts .= filter ~>
					it.0 < @sel.x1 or it.0 > @sel.x2 or it.1 < @sel.y1 or it.1 > @sel.y2
		if pts.length
			@g.fillStyle = \#07d
			for pt in pts
				@g.fillRect pt.0 * @z - 2, pt.1 * @z - 2, @z + 4, @z + 4
			for pt in pts
				@g.clearRect pt.0 * @z, pt.1 * @z, @z, @z
				@g.fillStyle = pt.2
				@g.fillRect pt.0 * @z, pt.1 * @z, @z, @z
		if @sel
			@g.strokeStyle = \#07d
			@g.lineWidth = 2
			@g.setLineDash [4 2]
			@g.strokeRect do
				@sel.x1 * @z - 1
				@sel.y1 * @z - 1
				(@sel.x2 - @sel.x1 + 1) * @z + 2
				(@sel.y2 - @sel.y1 + 1) * @z + 2

	view: ->
		m \.main,
			style:
				cursor: @cursor
			m \.toolbar.column,
				m \.col,
					m \.row,
						m \.col-3 "x: #{@x ? \-}"
						m \.col-3 "y: #{@y ? \-}"
					m \button.button.w-100.mt-3,
						onclick: @open
						@file and @file.name or "Mở tập tin..."
					m \.row.wrap.middle.mt-3.gap-y-3,
						m \.col-6 "Thu phóng"
						m \input.rangeInput.col-5,
							type: \range
							min: 2
							max: 16
							value: @z
							oninput: !~>
								@resize @w, @h, it.target.valueAsNumber
						m \.col-1.text-right @z
						m \.col-6 "Kích thước ảnh"
						m \.col-6.row.gap-x-2,
							m \input.input.w-100,
								type: \number
								min: 1
								value: @tmpW
								oninput: !~>
									@tmpW = it.target.value
								onchange: !~>
									@resize it.target.valueAsNumber, @h
							m \input.input.w-100,
								type: \number
								min: 1
								value: @tmpH
								oninput: !~>
									@tmpH = it.target.value
								onchange: !~>
									@resize @w, it.target.valueAsNumber
						m \.col-6 "Kích thước lưới"
						m \.col-6.row.gap-x-2,
							m \input.input.w-100,
								type: \number
								min: 2
								value: @tmpTileW
								oninput: !~>
									@tmpTileW = it.target.value
								onchange: !~>
									@onchangeTileSize \tileW event
							m \input.input.w-100,
								type: \number
								min: 2
								value: @tmpTileH
								oninput: !~>
									@tmpTileH = it.target.value
								onchange: !~>
									@onchangeTileSize \tileH event
						m \.col-6 "Màu vẽ"
						m ColorInput,
							class: \col-6
							value: @tmpColor
							oninput: (@tmpColor) !~>
							color: @color
							oncolor: (@color) !~>
						m \.col-6 "Màu lưới"
						m ColorInput,
							class: \col-6
							value: @tmpGridColor
							oninput: (@tmpGridColor) !~>
							color: @gridColor
							oncolor: (@gridColor) !~>
								@redraw!
						m \.col-6 "Nền trong suốt"
						m ColorInput,
							class: \col-6
							value: @tmpAlphaColor
							oninput: (@tmpAlphaColor) !~>
							color: @alphaColor
							oncolor: (@alphaColor) !~>
						m \label.col-6.row.middle,
							m \input.checkInput,
								type: \checkbox
								checked: @isShowTile
								oninput: !~>
									@isShowTile = it.target.checked
									@redraw!
							m \.ml-3 "Hiện ô lưới"
						m \label.col-6.row.middle,
							m \input.checkInput,
								type: \checkbox
								checked: @isShowGrid
								oninput: !~>
									@isShowGrid = it.target.checked
									@redraw!
							m \.ml-3 "Hiện lưới"
			m \.view#viewEl,
				m \canvas#canvas,
					style:
						background: @alphaColor
					onpointerdown: @onpointerdownEdit
					onpointermove: @onpointermoveEdit
					onlostpointercapture: @onlostpointercaptureEdit

m.mount document.body, App
