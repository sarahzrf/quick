require 'singleton'
require 'rfusefs'
require 'ruby_parser'
require_relative 'core_ext'

class Class
	def define(constants)
		constants.each do |name, val|
			define_method(name) {|*args| val}
		end
	end
end

class RFuseCheck
	include Singleton

	define can_write?: true, can_mkdir?: false
end

class DRbPort
	include Singleton

	attr_accessor :drb_port

	define file?: true, can_read?: true

	def read_file
		drb_port.to_s
	end
end

class MethodFile
	Parser = RubyParser.new

	define file?: true, can_read?: true, can_write?: true

	def initialize(mod, name)
		@mod, @name = mod, name
		@defined_source = @working_source = ''
	end

	def read_file(path)
		@working_source
	end

	def write_to(path, src)
		@working_source = src
		define!
	rescue ArgumentError
	end

	private
	
	def define!
		sexp = Parser.parse @working_source
		unless sexp and sexp.node_type == :defn
			raise ArgumentError, "not a method definition"
		end
		name = sexp[1]
		raise ArgumentError, "wrong method name" unless name.to_s == @name
		@mod.module_eval @working_source
		@defined_source = @working_source
	rescue Racc::ParseError => e
		raise ArgumentError, e.message
	end
end

class ModuleDir
	class << self
		def path_method(name, value=nil, &body)
			body = proc {value} if value and not body
			define_method name do |path=nil, *args|
				cur, child = path_parts path
				if cur
					target = child cur
					if target.respond_to? name
						target.send name, child, *args
					else
						FuseFS::DEFAULT_FS.send name, child, *args
					end
				else
					instance_exec *args, &body if body
				end
			end
		end
	end

	def initialize(mod)
		@mod = mod
	end

	other_methods = FuseFS::DEFAULT_FS.class.instance_methods(false)
	other_methods -= [:mounted, :unmounted]
	other_methods.each do |meth| # don't do meth
		path_method meth
	end

	path_method :contents do
		submods.map(&:to_s) +
			submeths.map(&:to_s) <<
			'#singleton_class'
	end

	path_method :directory?, true
	path_method :can_write?, true

	private

	def path_parts(path)
		return nil unless path
		path = path.sub /\A\//, ''
		path.split '/', 2
	end

	def child(name)
		case name
		when '._rfuse_check_'
			RFuseCheck.instance
		when '#drb_port'
			DRbPort.instance
		when '#singleton_class'
			self.class.new @mod.singleton_class
		else
			begin
				subdir name
			rescue Errno::ENOENT
				subfile name
			end
		end
	end

	def subdir(name)
		self.class.new @mod.const_get(name)
	rescue NameError
		raise Errno::ENOENT
	end

	def subfile(name)
		unless name =~ /\A(.+)\.rb/ and @mod.method_files.key? $1
			raise Errno::ENOENT
		end
		@mod.method_files[$1]
	end

	def submods
		@mod.constants(false).select {|c| @mod.const_get(c).is_a? Module}
	end
	
	def submeths
		@mod.method_files.keys.map {|name| name + '.rb'}
	end

	def instance_methods
		@mod.instance_methods false
	end
end

# vim:tabstop=2 shiftwidth=2 noexpandtab:

