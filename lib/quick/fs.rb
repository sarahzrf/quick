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

module Quick
	module FS
		class RFuseCheck
			include Singleton

			define can_write?: true, can_mkdir?: false, times: [Time.now] * 3
		end

		class FSConstant
			attr_writer :contents

			define file?: true, can_read?: true, times: [Time.now] * 3

			def contents
				if @contents.respond_to? :call
					@contents.call
				else
					@contents
				end
			end

			def size(path)
				contents.bytesize
			end

			def read_file(path)
				contents.to_s
			end
		end

		BrBURI = FSConstant.new
		BrBURI.contents = proc {BrB::Service.uri}
		FSRoot = FSConstant.new

		class ROCodeFile
			define file?: true, can_read?: true, can_write?: false

			attr_accessor :source, :mtime, :ctime

			def initialize(source)
				@source = source
			end

			def times(path)
				now = Time.now
				[@atime ||= now, @mtime ||= now, @ctime ||= now]
			end

			def size(path)
				@source.bytesize
			end

			def read_file(path)
				@atime = Time.now
				@source
			end
		end

		class CodeFile
			Parser = RubyParser.new

			define file?: true, can_read?: true, can_write?: true

			attr_reader :in_use

			def initialize(mod, name)
				@mod, @name = mod, name
				@source = ''
				@in_use = ROCodeFile.new @source
			end

			def read_file(path)
				@atime = Time.now
				@source
			end

			def size(path)
				@source.bytesize
			end

			def write_to(path, source)
				@source = source
				@mtime = @ctime = Time.now
				eval!
			rescue ArgumentError
			end

			def touch(path)
				@mtime = Time.now
			end

			def times(path)
				now = Time.now
				[@atime ||= now, @mtime ||= now, @ctime ||= now]
			end

			private

			def eval!
				sexp = Parser.parse @source
				raise ArgumentError, "no source" unless sexp
				is_meth = sexp.node_type == :defn
				is_meths = sexp.node_type == :block &&
					sexp.rest.all? {|n| n.node_type == :defn}
				unless is_meth or is_meths or @name == 'header.rb'
					raise ArgumentError, "not 1 or more method definitions"
				end
				@mod.module_eval @source
				@in_use.source = @source
				@in_use.mtime = @in_use.ctime = Time.now
			rescue Racc::ParseError => e
				raise ArgumentError, e.message
			rescue StandardError => e
				raise ArgumentError, e.message
			end
		end

		class ModuleDir
			def self.path_method(name, value=nil, &body)
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
						if body
							instance_exec *args, &body
						else
							FuseFS::DEFAULT_FS.send name, child, *args
						end
					end
				end
			end

			def initialize(mod)
				@mod = mod
			end

			other_methods = FuseFS::DEFAULT_FS.class.instance_methods(false)
			other_methods -= [:mounted, :unmounted]
			other_methods.each do |meth| # don't be like other_methods. don't do meth.
				path_method meth
			end

			path_method :contents do
				@atime = Time.now
				submods + subfiles <<
					'#singleton_class'
			end

			path_method :touch do
				@mtime = Time.now
			end

			path_method :times do
				now = Time.now
				[@atime ||= now, @mtime ||= now, @ctime ||= now]
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
				when '#brb_uri'
					BrBURI
				when '#fs_root'
					FSRoot
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
				raise Errno::ENOENT unless name.end_with? '.rb'
				unless name =~ /\A(.+)\.in_use.rb\Z/
					@mod.code_files[name]
				else
					name = $1 + '.rb'
					raise Errno::ENOENT unless @mod.code_files.key? name
					@mod.code_files[name].in_use
				end
			end

			def submods
				consts = @mod.constants(false)
				consts.delete :fatal
				consts.select {|c| @mod.const_get(c).is_a? Module}.map &:to_s
			end

			def subfiles
				files = @mod.code_files.keys.map(&:to_s)
				files + files.map {|s| s.sub /rb\Z/, 'in_use.rb'}
			end
		end
	end
end

# vim:tabstop=2 shiftwidth=2 noexpandtab:

