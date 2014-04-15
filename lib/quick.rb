require 'pathname'
require_relative 'quick/core_ext'
require_relative 'quick/fs'
require_relative 'quick/service'

module Quick
	extend self

	VERSION = '0.2.2'

	def brb_service
		@brb_service ||=
			begin
				uri = File.read('#brb_uri')
				service = BrB::Tunnel.create nil, uri
				if service.error?
					raise "failed to connect to the Quick instance"
				end
				service
			end
	rescue Errno::ENOENT
		raise "not in a Quick directory"
	end

	def run(dir)
		Quick::Service.run dir
	end

	def stop
		brb_service.stop
		sleep 1
	end

	def pry_here(instance=true)
		brb_service.pry_at_block pwd_from_root, instance
	end

	def eval_here(code, instance=true)
		success, result = brb_service.eval_block pwd_from_root, code, instance
		if success
			result
		else
			raise result
		end
	end

	def module_here(name)
		const_defined? name
		brb_service.new_mod_block pwd_from_root, name
	rescue NameError
		raise "invalid module name"
	end

	def class_here(name, super_path='Object')
		const_defined? name
		brb_service.new_mod_block pwd_from_root, name, from_root(super_path)
	rescue NameError
		raise "invalid class name"
	end

	def checkpointing?
		brb_service.checkpointing_block
	end

	def repo
		raise "checkpointing is not enabled!" unless checkpointing?
		brb_service.repo_block
	end

	def checkpoint(msg)
		raise "checkpointing is not enabled!" unless checkpointing?
		brb_service.hibernate msg
		sleep 1
	end

	def load
		raise "checkpointing is not enabled!" unless checkpointing?
		brb_service.load
		sleep 1
	end

	def pwd_from_root
		from_root Dir.pwd
	end

	def from_root(path)
		pn = Pathname.new path
		return path if pn.relative?
		root = Pathname.new brb_service.mount_point_block
		pn.relative_path_from(root).to_path
	end
end

# vim:tabstop=2 shiftwidth=2 noexpandtab:

