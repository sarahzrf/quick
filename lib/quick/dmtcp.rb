require 'ffi'
require_relative 'service'

module Quick
	module DMTCP
		#module FFI
		#	extend ::FFI::Library
		#	ffi_lib '/usr/local/lib/dmtcp/libdmtcp.so'
		#	attach_function :dmtcpCheckpoint, [], :int
		#end

		extend self

		def checkpoint
			#FFI.dmtcpCheckpoint
			system 'dmtcp_nocheckpoint', 'dmtcp_command', '-bc'
		end

		def load
			file = File.join Service.repo, 'dmtcp_restart_script.sh'
			raise Errno::ENOENT unless File.file? file
			exec 'dmtcp_nocheckpoint', file
		end
	end
end

# vim:tabstop=2 shiftwidth=2 noexpandtab:

