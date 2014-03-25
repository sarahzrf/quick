require 'ruby_parser'

class Module
	Parser = RubyParser.new

	def method_sources
		@method_sources ||= {}
	end

	def define_from_source(source)
		sexp = Parser.parse source
		raise ArgumentError, "not a method definition" unless sexp.node_type == :defn
		name = sexp[1]
		module_eval source
		method_sources[name] = source
	rescue Racc::ParseError => e
		raise ArgumentError, e.message
	end
end

# vim:tabstop=2 shiftwidth=2 noexpandtab:

