m <<<
	cssUnitless:
		animationIterationCount: yes
		borderImageOutset: yes
		borderImageSlice: yes
		borderImageWidth: yes
		boxFlex: yes
		boxFlexGroup: yes
		boxOrdinalGroup: yes
		columnCount: yes
		columns: yes
		flex: yes
		flexGrow: yes
		flexPositive: yes
		flexShrink: yes
		flexNegative: yes
		flexOrder: yes
		gridArea: yes
		gridRow: yes
		gridRowEnd: yes
		gridRowSpan: yes
		gridRowStart: yes
		gridColumn: yes
		gridColumnEnd: yes
		gridColumnSpan: yes
		gridColumnStart: yes
		fontWeight: yes
		lineClamp: yes
		lineHeight: yes
		opacity: yes
		order: yes
		orphans: yes
		tabSize: yes
		widows: yes
		zIndex: yes
		zoom: yes
		fillOpacity: yes
		floodOpacity: yes
		stopOpacity: yes
		strokeDasharray: yes
		strokeDashoffset: yes
		strokeMiterlimit: yes
		strokeOpacity: yes
		strokeWidth: yes

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
					res[k] += \px if not @cssUnitless[k] and +val
		res

	bind: (comp) ->
		for k, v of comp
			if typeof v is \function
				comp[k] = v.bind comp
		comp

	comp: (opts,, statics) ->
		comp = ->
			old = null
			vdom = {}
			vdom <<< opts
			vdom <<<
				$$oninit: opts.oninit or ->
				$$oncreate: opts.oncreate or ->
				$$onbeforeupdate: opts.onbeforeupdate or ->
				$$onupdate: opts.onupdate or ->
				$$onbeforeremove: opts.onbeforeremove or ->
				$$onremove: opts.onremove or ->
				oninit: !->
					@{attrs or {}, children or []} = it
					@dom = null
					old :=
						attrs: {...@attrs}
						children: [...@children]
						dom: null
					@$$oninit!
					@$$onbeforeupdate old, yes
				oncreate: !->
					@dom = it.dom
					@$$oncreate!
					@$$onupdate old, yes
				onbeforeupdate: ->
					@{attrs or {}, children or []} = it
					@$$onbeforeupdate old
				onupdate: !->
					@dom = it.dom
					@$$onupdate old
					old :=
						attrs: {...@attrs}
						children: [...@children]
						dom: @dom
				onbeforeremove: ->
					@$$onbeforeremove!
				onremove: !->
					@$$onremove!
			m.bind vdom
		comp <<< statics
		m.bind comp

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

ColorInput = m.comp do
	onbeforeupdate: !->
		@color = Utils.inputizeColor @attrs.color

	oninput: (event) !->
		{value} = event.target
		if event.target.type is \color
			if color = Utils.extendColor @attrs.value
				alpha = color.slice -2
				unless alpha is \ff
					value = value.slice(0 7) + alpha
		@attrs.oninput? value, event
		if color = Utils.shortenColor value
			@attrs.oncolor? color, event

	view: ->
		m \.ColorInput,
			class: @attrs.class
			m \input.ColorInput-text,
				minlength: 2
				maxlength: 9
				value: @attrs.value
				oninput: @oninput
			m \.ColorInput-color,
				style:
					background: @attrs.value
				onclick: (event) !~>
					event.target.nextElementSibling.click!
			m \input.ColorInput-input,
				type: \color
				value: @color
				oninput: @oninput

App = m.comp do
	oninit: !->
		@w = 48
		@h = 32
		@tmpW = @w
		@tmpH = @h
		@z = 12
		@color = \#e91
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
		@grid = null
		@edit = null
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

	oncreate: !->
		@resize!
		addEventListener \keydown @onkeydown
		addEventListener \keyup @onkeyup
		addEventListener \contextmenu (.preventDefault!)

	open: !->
		try
			[@file] = await showOpenFilePicker do
				types:
					excludeAcceptAllOption: yes
					accept:
						"image/*": [\.png]
					...
			file = await @file.getFile!
			reader = new FileReader
			reader.onload = !~>
				img = new Image
				img.src = reader.result
				img.onload = !~>
					@w = img.width
					@h = img.height
					@resize!
					@edit.clearRect 0 0 @w, @h
					@edit.drawImage img, 0 0
					data = @edit.getImageData 0 0 @w, @h .data
					@pts = []
					for i til data.length by 4
						if a = data[i + 3]
							j = i / 4
							x = j % @w
							y = j // @w
							r = data[i]
							g = data[i + 1]
							b = data[i + 2]
							a = +(a / 255)toFixed 2
							color = Utils.rgbaToHex [r, g, b, a]
							pt = [x, y, color]
							@pts.push pt
					@sel = null
					@selPts = []
					@drawGrid!
			reader.readAsDataURL file

	inBound: (x, y) ->
		0 <= x < @w and 0 <= y < @h

	onpointerdownEdit: (event) !->
		editEl.setPointerCapture event.pointerId
		@mouse = event.which
		if @mouse is 2
			event.preventDefault!
		@x = void
		@y = void
		@onpointermoveEdit event, yes

	onpointermoveEdit: (event, isDown) !->
		mx = event.offsetX // @z
		my = event.offsetY // @z
		unless mx is @x and my is @y
			if @mouse
				if isDown
					@x = mx
					@y = my
				curPtInBound = @inBound mx, my
				if @selPts.length
					inSelPts = @selPts.some ~> it.0 is mx and it.1 is my
				dx = mx - @x
				dy = my - @y
				curPt = @pts.find ~> it.0 is mx and it.1 is my
				if @shift
					if @ctrl
						if curPt
							# for pt in @selPts
							if @mouse is 2
								@selPts = []
							grid = []
							for pt in @pts
								grid[][pt.1][pt.0] = pt
							finded = []
							findNear = (pt) !~>
								unless finded.includes pt
									finded.push pt
									index = @selPts.indexOf pt
									if index is -1
										if @mouse in [1 2]
											@selPts.push pt
									else
										if @mouse is 3
											@selPts.splice index, 1
									for y from pt.1 - 1 to pt.1 + 1
										for x from pt.0 - 1 to pt.0 + 1
											unless x is pt.0 and y is pt.1
												if nearPt = grid[y]?[x]
													if nearPt.2 is pt.2
														findNear nearPt
							findNear curPt
							grid = null
							@drawGrid!
					else
						if isDown
							@sel = x0: mx, y0: my
							if @mouse is 2
								@selPts = []
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
						@drawGrid!
				else
					if @selPts.length
						if @mouse in [1 2]
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
								pt.0 += dx
								pt.1 += dy
							@drawEdit!
							@drawGrid!
						else
							if inSelPts
								for pt in @selPts
									@pts.splice @pts.indexOf(pt), 1
								@drawEdit!
							else
								for pt in @selPts
									if @inBound pt.0, pt.1
										findPt = @pts.find ~> it.0 is pt.0 and it.1 is pt.1 and it isnt pt
										if findPt
											findPt.2 = Utils.mixColor findPt.2, pt.2
											@pts.splice @pts.indexOf(pt), 1
									else
										@pts.splice @pts.indexOf(pt), 1
							@selPts = []
							@drawGrid!
					else
						if curPtInBound
							if @mouse is 1
								if curPt
									curPt.2 = Utils.mixColor curPt.2, @color
								else
									newPt = [mx, my, @color]
									@pts.push newPt
								@drawEdit!
							else if @mouse is 2
								if curPt
									@color = @tmpColor = curPt.2
							else
								if curPt
									@pts.splice @pts.indexOf(curPt), 1
									@drawEdit!
			@x = mx
			@y = my

	onlostpointercaptureEdit: (event) !->
		@mouse = 0
		unless @isKeyDown
			@ctrl = void
			@shift = void
			@alt = void
			@code = void
		if @sel
			if @sel.pts
				for pt in @sel.pts
					unless @selPts.includes pt
						@selPts.push pt
			else
				@selPts .= filter ~>
					it.0 < @sel.x1 or it.0 > @sel.x2 or it.1 < @sel.y1 or it.1 > @sel.y2
			@sel = null
			@drawGrid!

	onkeydown: (event) !->
		unless event.repeat
			unless event.target.matches "textarea,input:not([type]),input[type=text],input[type=number]"
				unless @mouse
					@ctrl = event.ctrlKey
					@shift = event.shiftKey
					@alt = event.altKey
					{@code} = event
					@isKeyDown = yes
					switch @code
					| \KeyO
						@open!
					| \Escape
						if @selPts.length
							for pt in @selPts
								if @inBound pt.0, pt.1
									findPt = @pts.find ~> it.0 is pt.0 and it.1 is pt.1 and it isnt pt
									if findPt
										findPt.2 = Utils.mixColor findPt.2, pt.2
										@pts.splice @pts.indexOf(pt), 1
								else
									@pts.splice @pts.indexOf(pt), 1
							@selPts = []
							@drawGrid!

	onkeyup: (event) !->
		unless @mouse
			@ctrl = void
			@shift = void
			@alt = void
			@code = void
		@isKeyDown = no

	onchangeSize: (prop, event) !->
		if value = +event.target.value
			value = Math.floor value
			if 0 < value < 1024
				@[prop] = value
				@resize!

	onchangeTileSize: (prop, event) !->
		if value = +event.target.value
			value = Math.floor value
			if 1 < value < 9e9
				@[prop] = value
				@drawGrid!

	resize: !->
		@wz = @w * @z
		@hz = @h * @z
		@wz1 = @wz + 1
		@hz1 = @hz + 1
		editEl.width = @w
		editEl.height = @h
		@edit = editEl.getContext \2d
		@edit.imageSmoothingEnabled = no
		@drawEdit!
		gridEl.width = @wz1
		gridEl.height = @hz1
		@grid = gridEl.getContext \2d
		@grid.imageSmoothingEnabled = no
		@drawGrid!

	drawGrid: !->
		@grid.clearRect 0 0 @wz1, @hz1
		@grid.fillStyle = @gridColor
		if @isShowGrid
			@grid.globalAlpha = 0.25
			for x to @wz by @z
				@grid.fillRect x, 0 1 @hz1
			for y to @hz by @z
				@grid.fillRect 0 y, @wz1, 1
		if @isShowTile
			@grid.globalAlpha = 0.5
			for x to @wz by @z * @tileW
				@grid.fillRect x, 0 1 @hz1
			for y to @hz by @z * @tileH
				@grid.fillRect 0 y, @wz1, 1
		@grid.globalAlpha = 1
		pts = @selPts
		if @sel
			if @sel.pts
				pts ++= @sel.pts
			else
				pts .= filter ~>
					it.0 < @sel.x1 or it.0 > @sel.x2 or it.1 < @sel.y1 or it.1 > @sel.y2
		if pts.length
			@grid.fillStyle = \#07d
			for pt in pts
				@grid.fillRect pt.0 * @z - 2, pt.1 * @z - 2, @z + 4, @z + 4
			for pt in pts
				@grid.fillStyle = pt.2
				@grid.fillRect pt.0 * @z, pt.1 * @z, @z, @z
		if @sel
			@grid.strokeStyle = \#07d
			@grid.lineWidth = 2
			@grid.setLineDash [4 2]
			@grid.strokeRect do
				@sel.x1 * @z - 1
				@sel.y1 * @z - 1
				(@sel.x2 - @sel.x1 + 1) * @z + 2
				(@sel.y2 - @sel.y1 + 1) * @z + 2

	drawEdit: !->
		@edit.clearRect 0 0 @w, @h
		for pt in @pts
			@edit.fillStyle = pt.2
			@edit.fillRect pt.0, pt.1, 1 1

	view: ->
		m \.main,
			m \.side.column,
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
								@z = +it.target.value
								@resize!
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
									@onchangeSize \w event
							m \input.input.w-100,
								type: \number
								min: 1
								value: @tmpH
								oninput: !~>
									@tmpH = it.target.value
								onchange: !~>
									@onchangeSize \h event
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
								@drawGrid!
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
									@drawGrid!
							m \.ml-3 "Hiện ô lưới"
						m \label.col-6.row.middle,
							m \input.checkInput,
								type: \checkbox
								checked: @isShowGrid
								oninput: !~>
									@isShowGrid = it.target.checked
									@drawGrid!
							m \.ml-3 "Hiện lưới"
			m \.view,
				m \canvas#editEl,
					style:
						background: @alphaColor
						zoom: @z
					onpointerdown: @onpointerdownEdit
					onpointermove: @onpointermoveEdit
					onlostpointercapture: @onlostpointercaptureEdit
				m \canvas#gridEl

m.mount document.body, App
