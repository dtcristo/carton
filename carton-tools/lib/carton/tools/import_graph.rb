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

      # Every node with an import in or out, the app first, then by path.
      def nodes
        found = @adjacent.flat_map { |from, targets| [from, *targets.keys] }
        found.uniq.sort_by { |node| node ? [1, node] : [0, ''] }
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
        index = {}
        low = {}
        stack = []
        on_stack = {}
        found = []
        nodes.each do |root|
          next if index.key?(root)

          work = [[root, 0]]
          index[root] = low[root] = index.size
          stack << root
          on_stack[root] = true
          until work.empty?
            node, position = work.last
            targets = successors(node)
            if position < targets.size
              work.last[1] += 1
              target = targets[position]
              if !index.key?(target)
                index[target] = low[target] = index.size
                stack << target
                on_stack[target] = true
                work << [target, 0]
              elsif on_stack[target]
                low[node] = [low[node], index[target]].min
              end
            else
              work.pop
              low[work.last[0]] = [
                low[work.last[0]],
                low[node],
              ].min if work.any?
              next unless low[node] == index[node]

              component = []
              loop do
                member = stack.pop
                on_stack.delete(member)
                component << member
                break if member == node
              end
              if component.size > 1 || @adjacent[node].key?(node)
                found << component
              end
            end
          end
        end
        found
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
