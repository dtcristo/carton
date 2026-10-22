# frozen_string_literal: true

require_relative 'project'

module Carton
  module Tools
    # A Project's Cartons and the imports between them. Each node is a
    # Carton's Entrypoint, or nil for the app, which runs in Main. Of parallel
    # imports between the same two nodes, the first eager one stands for them
    # all, so a pair is lazy only when every import between them is.
    class ImportGraph
      def initialize(project)
        @project = project
        @adjacent = Hash.new { |hash, node| hash[node] = {} }
        project.edges.each do |edge|
          next unless edge.carton

          from = project.owner(edge.call.file)&.entrypoint
          to = edge.carton.entrypoint
          current = @adjacent[from][to]
          @adjacent[from][to] = edge if current.nil? ||
            (current.call.lazy && !edge.call.lazy)
        end
      end

      # The app, then every Carton with an import in or out, by path.
      def nodes
        found = @adjacent.flat_map { |from, targets| [from, *targets.keys] }
        [nil, *found.compact.uniq.sort]
      end

      # One edge per importing pair, ordered by node.
      def edges
        nodes.flat_map do |node|
          successors(node).map { |to| @adjacent[node][to] }
        end
      end

      # One shortest cycle per strongly connected component, as its edges,
      # starting from the component's smallest Entrypoint. An all-eager cycle
      # is preferred, since it is certain to raise.
      def cycles
        components.filter_map do |component|
          members = component.to_h { |node| [node, true] }
          shortest(members, eager: true) || shortest(members, eager: false)
        end
      end

      # The shortest chain of edges from `from` to `to`, or nil.
      def path(from, to)
        parents = { from => nil }
        queue = [from]
        until queue.empty?
          node = queue.shift
          return chain(parents, to) if node == to && from != to

          successors(node).each do |target|
            next if parents.key?(target)

            parents[target] = @adjacent[node][target]
            queue << target
          end
        end
        nil
      end

      private

      def successors(node)
        @adjacent.key?(node) ? @adjacent[node].keys.sort : []
      end

      def chain(parents, node)
        edges = []
        while (edge = parents[node])
          edges.unshift(edge)
          node = @project.owner(edge.call.file)&.entrypoint
        end
        edges
      end

      # Tarjan's algorithm, iterative so a long chain of imports cannot
      # exhaust the stack. Only components that hold a cycle: more than one
      # node, or a node that imports itself.
      def components
        @index = {}
        @low = {}
        @stack = []
        @on_stack = {}
        found = []
        nodes.each { |root| connect(root, found) unless @index.key?(root) }
        found.select do |component|
          component.size > 1 || @adjacent[component.first].key?(component.first)
        end
      end

      def connect(root, found)
        enter(root)
        work = [[root, 0]]
        until work.empty?
          node, position = work.last
          targets = successors(node)
          if position < targets.size
            work.last[1] += 1
            target = targets[position]
            if !@index.key?(target)
              enter(target)
              work << [target, 0]
            elsif @on_stack[target]
              @low[node] = [@low[node], @index[target]].min
            end
          else
            work.pop
            parent = work.last&.first
            @low[parent] = [@low[parent], @low[node]].min if work.any?
            found << leave(node) if @low[node] == @index[node]
          end
        end
      end

      def enter(node)
        @index[node] = @low[node] = @index.size
        @stack << node
        @on_stack[node] = true
      end

      # Pop the component whose root is `node`.
      def leave(node)
        component = []
        loop do
          member = @stack.pop
          @on_stack.delete(member)
          component << member
          return component if member == node
        end
      end

      # The shortest cycle within `members`, by breadth-first search from
      # each member in order, or nil.
      def shortest(members, eager:)
        best = nil
        members
          .keys
          .sort_by(&:to_s)
          .each do |start|
            cycle = cycle_from(start, members, eager)
            best = cycle if cycle && (best.nil? || cycle.size < best.size)
          end
        best
      end

      def cycle_from(start, members, eager)
        parents = { start => nil }
        queue = [start]
        until queue.empty?
          node = queue.shift
          successors(node).each do |target|
            edge = @adjacent[node][target]
            next unless members.key?(target)
            next if eager && edge.call.lazy
            return *chain(parents, node), edge if target == start
            next if parents.key?(target)

            parents[target] = edge
            queue << target
          end
        end
        nil
      end
    end
  end
end
