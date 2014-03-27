require_relative 'fs'

class Object
	def quick_binding
		@quick_binding ||= binding
	end
end

class Module
	attr_writer :quick_instance

	def quick_instance
		@quick_instance ||= Object.new.extend self
	end

	def code_files
		@code_files ||= Hash.new do |h, k|
			h[k] = Quick::FS::CodeFile.new self, k
		end
	end
end

class Class
	def quick_instance
		@quick_instance ||= allocate
	end
end

# vim:tabstop=2 shiftwidth=2 noexpandtab:

