require 'singleton'
require 'rfusefs'

class RFuseCheck
	include Singleton

	def can_write?(path)
		true
	end

	def can_mkdir?(path)
		false
	end
end

class ModuleDir
	class << self
		def rec_method(name, &body)
			define_method name do |path|
				cur, child = path_parts path
				if cur
					child(cur).send name, child
				else
					instance_eval &body
				end
			end
		end
	end

	def initialize(mod)
		@mod = mod
	end

	rec_method :contents do
		submods.map(&:to_s) <<
			'#singleton_class'
	end

	rec_method :directory? do
		true
	end

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
		when '#singleton_class'
			self.class.new @mod.singleton_class
		else
			begin
				subdir name
			rescue Errno::ENOENT
				submeth name
			end
		end
	end

	def subdir(name)
		self.class.new @mod.const_get(name)
	rescue NameError
		raise Errno::ENOENT
	end

	def submeth(name)
		raise Errno::ENOENT
	end

	def submods
		@mod.constants(false).select {|c| @mod.const_get(c).is_a? Module}
	end

	def instance_methods
		@mod.instance_methods false
	end
end

# vim:tabstop=2 shiftwidth=2 noexpandtab:

