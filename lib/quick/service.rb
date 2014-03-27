require 'pry-remote-em/server'
require 'brb'
require_relative 'core_ext'
require_relative 'fs'

Quick::Main = self

module Quick
	module Service
		module_function

		# warning: run/stop/hibernate are pretty awful because I
		# don't actually know how to use EventMachine properly.
		# If you know how to make these better, PLEASE feel free
		# to submit a pull request!
		def run(mount_point)
			while true
				raise "already running" if @running
				@mount_point = FS::FSRoot.contents = mount_point
				@root = FS::ModuleDir.new Object
				Thread.new do
					FuseFS.start @root, mount_point
				end
				EM.run do
					Main.remote_pry_em
					BrB::Service.start_service object: self
					@running = true
				end
				if @hibernating
					sleep 10
					@hibernating = false
				else
					break
				end
			end
		end

		def stop
			raise "not running" unless @running
			FuseFS.exit
			BrB::Service.stop_service
			EM.stop
			@running = false
		end

		def eval(module_path, code, instance=true)
			mod = resolve_path module_path
			if instance
				mod.quick_instance.quick_binding.eval code
			else
				mod.quick_binding.eval code
			end
		end

		def new_mod(parent_path, name, super_path=nil)
			parent = resolve_path parent_path
			unless super_path
				parent.const_set name, Module.new
			else
				superclass = resolve_path super_path
				parent.const_set name, Class.new(superclass)
			end
		end

		def hibernate
			@hibernating = true
			stop
		end

		def resolve_path(path)
			path = path.sub /\A\//, ''
			parts = path.split '/'
			parts.inject(Object) {|mod, name| mod.const_get name}
		end
	end
end

# vim:tabstop=2 shiftwidth=2 noexpandtab:

