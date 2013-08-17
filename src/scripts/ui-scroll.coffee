###
globals: angular, window

	List of used element methods available in JQuery but not in JQuery Lite

		element.before(elem)
		element.height()
		element.offset()
		element.outerHeight(true)
		element.height(value) = only for Top/Bottom padding elements
		element.scrollTop()
		element.scrollTop(value)

###
angular.module('ui.scroll', [])

	.directive( 'ngScrollViewport'
		[ '$log'
			(console) ->
				controller:
					[ '$scope', '$element'
						(scope, element) -> element
					]

		])

	.directive( 'ngScrollCanvas'
		[ '$log'
			(console) ->
				controller:
					[ '$scope', '$element'
						(scope, element) -> element
					]

		])

	.directive( 'ngScroll'
		[ '$log', '$injector', '$rootScope'
			(console, $injector, $rootScope) ->
				require: ['?^ngScrollViewport', '?^ngScrollCanvas']
				transclude: 'element'
				priority: 1000
				terminal: true

				compile: (element, attr, linker) ->
					($scope, $element, $attr, controllers) ->

						match = $attr.ngScroll.match /^\s*(\w+)\s+in\s+(\w+)\s*$/
						if !match
							throw new Error "Expected ngScroll in form of '_item_ in _datasource_' but got '#{$attr.ngScroll}'"

						itemName = match[1]
						datasourceName = match[2]

						isDatasource = (datasource) ->
							angular.isObject(datasource) and datasource.get and angular.isFunction(datasource.get)

						datasource = $scope[datasourceName]
						if !isDatasource datasource
							datasource = $injector.get(datasourceName)
							throw new Error "#{datasourceName} is not a valid datasource" unless isDatasource datasource

						bufferSize = Math.max(3, +$attr.bufferSize || 10)
						bufferPadding = -> viewport.height() * Math.max(0.2, +$attr.padding || 0.5) # some extra space to initate preload

						controller = null

						linker temp = $scope.$new(),
							(template) ->
								temp.$destroy()

								viewport = controllers[0] || angular.element(window)
								canvas = controllers[1] || element.parent()

								switch template[0].localName
									when 'li'
										if canvas[0] == viewport[0]
											throw new Error "element cannot be used as both viewport and canvas: #{canvas[0].outerHTML}"
										topPadding = angular.element('<li/>')
										bottomPadding = angular.element('<li/>')
									when 'tr','dl'
										throw new Error "ng-scroll directive does not support <#{template[0].localName}> as a repeating tag: #{template[0].outerHTML}"
									else
										if canvas[0] == viewport[0]
											# if canvas and the viewport are the same create a new div to service as canvas
											contents = canvas.contents()
											canvas = angular.element('<div/>')
											viewport.append canvas
											canvas.append contents
										topPadding = angular.element('<div/>')
										bottomPadding = angular.element('<div/>')

								viewport.css({'overflow-y': 'auto', 'display': 'block'})
								canvas.css({'overflow-y': 'visible', 'display': 'block'})
								element.before topPadding
								element.after bottomPadding

								scrollHeight = (elem)->
									elem[0].scrollHeight || elem[0].document.documentElement.scrollHeight

								controller =
									viewport: viewport
									canvas: canvas
									topPadding: (value) ->
										if arguments.length
											topPadding.height(value)
										else
											topPadding.height()
									bottomPadding: (value) ->
										if arguments.length
											bottomPadding.height(value)
										else
											bottomPadding.height()
									append: (element) -> bottomPadding.before element
									prepend: (element) -> topPadding.after element
									bottomDataPos: ->
										scrollHeight(viewport) - bottomPadding.height()
									topDataPos: ->
										#viewport.scrollTop() -
										topPadding.height()

						viewport = controller.viewport
						canvas = controller.canvas

						first = 1
						next = 1
						buffer = []
						pending = []
						eof = false
						bof = false
						loading = datasource.loading || (value) ->
						isLoading = false

						removeFromBuffer = (start, stop)->
							for i in [start...stop]
								buffer[i].scope.$destroy()
								buffer[i].element.remove()
							buffer.splice start, stop - start

						reload = ->
							first = 1
							next = 1
							removeFromBuffer(0, buffer.length)
							controller.topPadding(0)
							controller.bottomPadding(0)
							pending = []
							eof = false
							bof = false
							adjustBuffer(true)

						bottomVisiblePos = ->
							viewport.scrollTop() + viewport.height()

						topVisiblePos = ->
							viewport.scrollTop()

						shouldLoadBottom = ->
							console.log "*** load bottom=#{controller.bottomDataPos() < bottomVisiblePos() + bufferPadding()}"
							!eof && controller.bottomDataPos() < bottomVisiblePos() + bufferPadding()

						clipBottom = ->
							# clip the invisible items off the bottom
							bottomHeight = 0 #controller.bottomPadding()
							overage = 0

							for item in buffer[..].reverse()
								itemHeight = item.element.outerHeight(true)
								if controller.bottomDataPos() - bottomHeight - itemHeight > bottomVisiblePos() + bufferPadding()
									# top boundary of the element is below the bottom of the visible area
									bottomHeight += itemHeight
									overage++
									eof = false
								else
									break

							if overage > 0
								removeFromBuffer(buffer.length - overage, buffer.length)
								next -= overage
								controller.bottomPadding(controller.bottomPadding() + bottomHeight)
								console.log "clipped off bottom #{overage} bottom padding #{controller.bottomPadding()}"

						shouldLoadTop = ->
							console.log "*** load top=#{(controller.topDataPos() > topVisiblePos() - bufferPadding())}"
							!bof && (controller.topDataPos() > topVisiblePos() - bufferPadding())

						clipTop = ->
							# clip the invisible items off the top
							topHeight = 0
							overage = 0
							for item in buffer
								itemHeight = item.element.outerHeight(true)
								if controller.topDataPos() + topHeight + itemHeight < topVisiblePos() - bufferPadding()
									topHeight += itemHeight
									overage++
									bof = false
								else
									break
							if overage > 0
								removeFromBuffer(0, overage)
								controller.topPadding(controller.topPadding() + topHeight)
								first += overage
								console.log "clipped off top #{overage} top padding #{controller.topPadding() + topHeight}"

						enqueueFetch = (direction)->
							if (!isLoading)
								isLoading = true
								loading(true)
							#console.log "Requesting fetch... #{{true:'bottom', false: 'top'}[direction]} pending #{pending.length}"
							if pending.push(direction) == 1
								fetch()

						adjustBuffer = (reloadRequested)->
							console.log "top {actual=#{controller.topDataPos()} visible from=#{topVisiblePos()} bottom {visible through=#{bottomVisiblePos()} actual=#{controller.bottomDataPos()}}"

							enqueueFetch(true) if reloadRequested || shouldLoadBottom()
							enqueueFetch(false) if !reloadRequested && shouldLoadTop()

						insert = (index, item, top) ->
							itemScope = $scope.$new()
							itemScope[itemName] = item
							itemScope.$index = index-1
							wrapper =
								scope: itemScope
							linker itemScope,
							(clone) ->
								wrapper.element = clone
								if top
									controller.prepend clone
									buffer.unshift wrapper
								else
									controller.append clone
									buffer.push wrapper

							# this watch fires once per item inserted after the item template has been processed and values inserted
							# which allows to gather the 'real' height of the thing
							itemScope.$watch 'heightAdjustment', ->
								if top
									# an element is inserted at the top
									newHeight = controller.topPadding() - wrapper.element.outerHeight(true)
									# adjust padding to prevent it from visually pushing everything down
									if newHeight >= 0
										# if possible, reduce topPadding
										controller.topPadding(newHeight)
									else
										# if not, increment scrollTop
										scrollTop = viewport.scrollTop() + wrapper.element.outerHeight(true)
										# below is an attempt to ensure that the scrollbar is always there even if
										# there is not enough data. But now I am not sure it is necessary. Commenting out for now
										#if viewport.height() + scrollTop > canvas.height()
											#controller.bottomPadding(controller.bottomPadding() + viewport.height() + scrollTop - canvas.height())
										viewport.scrollTop(scrollTop)
								else
									controller.bottomPadding(Math.max(0,controller.bottomPadding() - wrapper.element.outerHeight(true)))

							itemScope


						finalize = ->
							pending.shift()
							if pending.length == 0
								isLoading = false
								loading(false)
							else
								fetch()

						fetch = () ->
							direction = pending[0]
							#console.log "Running fetch... #{{true:'bottom', false: 'top'}[direction]} pending #{pending.length}"
							lastScope = null
							if direction
								if buffer.length && !shouldLoadBottom()
									finalize()
								else
									#console.log "appending... requested #{bufferSize} records starting from #{next}"
									datasource.get next, bufferSize,
									(result) ->
										if result.length == 0
											eof = true
											console.log "appended: requested #{bufferSize} records starting from #{next} recieved: eof"
											finalize()
											return
										for item in result
											lastScope = insert ++next, item, false

										console.log "appended: #{result.length} buffer size #{buffer.length} first #{first} next #{next}"
										clipTop()
										finalize()
										lastScope.$watch 'adjustBuffer', ->
											adjustBuffer()

							else
								if buffer.length && !shouldLoadTop()
									finalize()
								else
									#console.log "prepending... requested #{size} records starting from #{start}"
									datasource.get first-bufferSize, bufferSize,
									(result) ->
										if result.length == 0
											bof = true
											console.log "prepended: requested #{bufferSize} records starting from #{first-bufferSize} recieved: eof"
											finalize()
											return
										for item in result.reverse()
											lastScope = insert first--, item, true
										console.log "prepended #{result.length} buffer size #{buffer.length} first #{first} next #{next}"
										clipBottom()
										finalize()
#										lastScope.$watch 'adjustBuffer', ->
#											adjustBuffer()
										lastScope.$watch 'adjustBuffer', ->
											adjustBuffer()

						viewport.bind 'resize', ->
							if !$rootScope.$$phase && !isLoading
								adjustBuffer()
								$scope.$apply()

						viewport.bind 'scroll', ->
							if !$rootScope.$$phase && !isLoading
								adjustBuffer()
								$scope.$apply()

						$scope.$watch datasource.revision,
							-> reload()

						eventListener = null

						if datasource.scope
							eventListener = datasource.scope.$new()
							$scope.$on '$destroy', -> eventListener.$destroy()
							eventListener.$on "update.item", (event, locator, newItem)->
								if angular.isFunction locator
									((wrapper)->
										newItem = locator wrapper.scope[itemName]
										if newItem
											wrapper.scope[itemName] = newItem
									) wrapper,i for wrapper,i in buffer
								else
									if 0 <= locator-first-1 < buffer.length
										buffer[locator-first-1].scope[itemName] = newItem
								undefined

		])