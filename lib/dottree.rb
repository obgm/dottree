#! /usr/bin/env ruby

require 'open3'

module Tree

  class Tree < Struct.new(:structure, :globalattrs, :nodeattrs, :edgeattrs)
    def initialize(structure = [], globalattrs = {}, nodeattrs = {}, edgeattrs = {})
      # set default attributes
      globalattrs[:fontname] ||= 'Palatino'
      globalattrs[:fontsize] ||= 14

      nodeattrs[:fontname] ||= globalattrs[:fontname]
      nodeattrs[:fontsize] ||= globalattrs[:fontsize]
      nodeattrs[:shape] ||= 'ellipse'
      nodeattrs[:style] ||= 'filled'
      nodeattrs[:fillcolor] ||= 'lightblue'

      edgeattrs[:arrowsize] ||= 0.6
      edgeattrs[:arrowhead] ||= 'vee'

      super(structure, globalattrs, nodeattrs, edgeattrs)
    end

    def to_s
      globals = []
      globalattrs.each {|k,v| globals << "#{k.to_s}=\"#{v.to_s}\"" }

      nodespecific = []
      nodeattrs.each {|k,v| nodespecific << "#{k.to_s}=\"#{v.to_s}\"" }

      edgespecific = []
      edgeattrs.each {|k,v| edgespecific << "#{k.to_s}=\"#{v.to_s}\"" }

      # Sort structure to cluster nodes with the same ancestor node
      # in a subgraph with attribute rank=same; The edges are put to the
      # bottom of the graph.
      ranks = Hash.new { |hash, key| hash[key] = [] }
      nodes = structure.flatten.filter {|elem| elem.is_a?(Node)}.each do |node|
        ranks[node.rank] << node
      end
      edges = structure.flatten.filter {|elem| elem.is_a?(Edge)}

      def ranked(r)
        r.map do |rank, nodelist|
          nodes = nodelist.map {|n| n.to_s}.join("\n")
          if rank > 0
            "{ rank=same;\n#{nodes}\n}"
          else
            nodes
          end
        end.join("\n")
      end

<<-HERE
digraph Tree {
    graph [#{globals.join(', ') }];
    node [#{nodespecific.join(', ') }];
    edge [#{edgespecific.join(', ') }];
    stylesheet="svgstyle.css";
    #{ranked(ranks)}
    #{edges.map {|n| n.to_s}.join("\n")}
}
HERE
    end

    # Creates an SVG file from the Tree structure. This function
    # creates a temporary file that is used as input to the dot
    # program.
    def to_svg(options = {})
      result_str = ""
      begin
        Open3.popen3('dot -Tsvg') do |stdin,stdout,stderr,thr|
          stdin.puts self.to_s
          stdin.close

          result_str = stdout.read
          error = stderr.read
          STDERR.puts error unless error.empty?

          result_code = thr.value
          STDERR.puts result_code unless result_code == 0
        end
      rescue Errno::ENOENT => e
        STDERR.puts "Error when invoking dot: #{e.message}."
        STDERR.puts "Please check that the graphviz package is installed and the dot executable is in the path."
      end

      result_str
    end
  end

  class Node < Struct.new(:id, :attr, :rank)
    def initialize(id, attr = {}, rank = 0)
      super(id, attr, rank)
    end

    def to_s
      attributes = []
      attr.each {|k,v| attributes << "#{k.to_s}=\"#{v.to_s}\"" }
      "#{id} [ #{attributes.join(', ')} ];"
    end
  end

  Edge = Struct.new(:nodes, :attr) do
    def to_s
      attributes = []
      attr.each {|k,v| attributes << "#{k.to_s}=\"#{v.to_s}\"" } unless attr.nil?
      "#{nodes.join(' -> ')} [ #{attributes.join(', ')} ];"
    end
  end

end # module Tree

if __FILE__ == $0
  puts Tree::Tree.new([Tree::Node.new(:root, { label: 'A'}),
                       Tree::Node.new(:left, { label: 'B'}, 1),
                       Tree::Node.new(:right, { label: 'C', fillcolor: :yellow }, 1),
                       Tree::Edge.new([:root, :left]),
                       Tree::Edge.new([:root, :right])],
                      { fontname: 'Deja Vu Sans', fontsize: 12 }).to_svg
end
