angular.module('application', ['ui.scroll', 'ui.scroll.jqlite']).controller('mainController',
	[ '$scope', '$log', '$timeout'
		($scope, console, $timeout)->
			datasource = {}

			datasource.get = (index, count, success)->
				$timeout(
					->
						result = []
						actualIndex = index

						start = Math.max(-4, actualIndex)
						end = Math.min(actualIndex + count-1, 10)

						if (start > end)
							success result
						else
							for i in [start..end]
								item = {}
								item.id = i
								item.content = "item #" + i
								result.push item
							success(result)
					100
				)

			$scope.datasource =  datasource

			# 1st list adapter implementation

			$scope.firstListAdapter = remain: true

			$scope.updateList1 = ->
				$scope.firstListAdapter.applyUpdates (item, scope) ->
					#if item.id == -4
						r = []
						for i in [1..2]
							it = {}
							it.id = 100 + item.id
							it.content = " * #{item.id} ##{i}"
							r.push it
						r
					#else
						#[item]

			$scope.removeFromList1 = ->
				$scope.firstListAdapter.applyUpdates (item) ->
					if item.id % 2 == 0
						return []
					else
						return [item]

			idList1 = 1000

			$scope.addToList1 = ->
				$scope.firstListAdapter.insert 2,
					id: idList1
					content: 'a new one #' + idList1
				idList1++
				return

			# 2nd list adapter implementation

			$scope.updateList2 = ->
				$scope.second.list.adapter.update (scope) ->
					scope.item.content += ' *'

			$scope.removeFromList2 = ->
				$scope.second.list.adapter.delete (scope) ->
					scope.item.id % 2 != 0
				return

			idList2 = 2000

			$scope.addToList2 = ->
				$scope.second.list.adapter.insert 4,
					id: idList2
					content: 'a new one #' + idList2
				idList2++
				return

	])

angular.bootstrap(document, ["application"])

###
//# sourceURL=src/scripts/adapter.js
###