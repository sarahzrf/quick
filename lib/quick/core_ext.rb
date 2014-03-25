require_relative 'fs'

class Module
	def method_files
		@method_files ||= Hash.new {|h, k| h[k] = MethodFile.new self, k}
	end
end

# vim:tabstop=2 shiftwidth=2 noexpandtab:

