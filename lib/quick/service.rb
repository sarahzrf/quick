require 'pry-remote-em/server'
require 'brb'
require 'git'
require_relative 'core_ext'
require_relative 'fs'

# ugly hacks ahoy!

module PryRemoteEm::Server
	alias_method :old_unbind, :unbind

	def unbind
		old_unbind
		url = Quick::Service.pries.delete @obj
		PryRemoteEm.stop_server url
	end
end

class Object
	def quick_pry
		if Quick::Service.pries.key? self
			Quick::Service.pries[self]
		else
			Quick::Service.pries[self] = remote_pry_em 'localhost', :auto
		end
	end
end

module Quick
	module Service
		extend self

		attr_reader :checkpointing

		# warning: run/stop/hibernate are pretty awful because I
		# don't actually know how to use EventMachine properly.
		# If you know how to make these better, PLEASE feel free
		# to submit a pull request!
		def run(mount_point, checkpointing=true)
			raise "already running" if @running
			@mount_point = File.absolute_path mount_point
			@checkpointing = checkpointing
			if checkpointing
				require_relative 'dmtcp'
				begin
					DMTCP.load
				rescue Errno::ENOENT
				end
			end
			@root = FS::ModuleDir.new Object
			loop do
				Thread.new do
					FuseFS.start @root, @mount_point
				end
				EM.run do
					BrB::Service.start_service object: self
					@running = true
				end
				@on_stop and @on_stop.call
				if @hibernating
					@hibernating = false
				else
					break
				end
			end
		ensure
			FuseFS.unmount
		end

		def stop(&blk)
			raise "not running" unless @running
			@running = false
			@on_stop = blk
			FuseFS.unmount
			FuseFS.exit
			BrB::Service.stop_service
			EM.stop
		end

		def hibernate(msg)
			@hibernating = true
			stop do
				DMTCP.checkpoint
				repo = Git.open repo
				repo.add all: true
				repo.commit_all msg
			end
		end

		def load
			stop do
				DMTCP.load
			end
		end

		def eval(module_path, code, instance=true)
			mod = resolve_path module_path
			if instance
				[true, mod.quick_instance.quick_binding.eval(code).inspect]
			else
				[true, mod.quick_binding.eval(code).inspect]
			end
		rescue => e
			[false, e.message]
		end

		def new_mod(parent_path, name, super_path=nil)
			parent = resolve_path parent_path
			unless super_path
				parent.const_set name, Module.new
			else
				superclass = resolve_path super_path
				parent.const_set name, Class.new(superclass)
			end
			name
		end

		def pries
			@pries ||= {}
		end

		def pry_at(module_path, instance=true)
			mod = resolve_path module_path
			target = if instance
				mod.quick_instance.quick_binding
			else
				mod.quick_binding
			end
			target.quick_pry
		end

		def mount_point
			@mount_point
		end

		def repo
			File.join(Dir.home, '.quick', File.basename(@mount_point))
		end

		def resolve_path(path)
			path = path.sub /\A(\/|\.|\.\.)/, ''
			parts = path.split '/'
			parts.inject(Object) {|mod, name| mod.const_get name}
		end
	end
end

# vim:tabstop=2 shiftwidth=2 noexpandtab:

