require 'ffi'

module Quick
	module DMTCP
		module FFI
			extend ::FFI::Library
			ffi_lib 'dmtcpaware'
			attach_function :dmtcpCheckpoint, [], :int
		end

		extend self

		def checkpoint
			FFI.dmtcpCheckpoint
		end

		def load
			file = File.join Service.repo, 'dmtcp_restart_script.sh'
			exec file
		end
	end
end

# vim:tabstop=2 shiftwidth=2 noexpandtab:

