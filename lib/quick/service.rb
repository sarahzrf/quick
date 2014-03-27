require 'pry-remote-em/server'
require_relative 'core_ext'

Quick::Main = self

module Quick
	module Service
		module_function

		def start
			raise "already running" if @running
			raise NotImplementedError
			@running = true
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
			halt
			yield
			sleep 10
			start
		end

		private

		def halt
			raise NotImplementedError
		end

		def resolve_path(path)
			path = path.sub /\A\//, ''
			parts = path.split '/'
			parts.inject(Object) {|mod, name| mod.const_get name}
		end
	end
end

# vim:tabstop=2 shiftwidth=2 noexpandtab:

