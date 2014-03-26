require_relative 'fs'

class Module
	attr_accessor :quick_instance

	def quick_binding
		@quick_binding ||= binding
	end

	def code_files
		@code_files ||= Hash.new do |h, k|
			h[k] = Quick::FS::CodeFile.new self, k
		end
	end
end

# vim:tabstop=2 shiftwidth=2 noexpandtab:

