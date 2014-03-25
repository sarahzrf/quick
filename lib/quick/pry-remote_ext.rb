require 'pry-remote'

module PryRemote
  class Server
    def initialize(object, host = DefaultHost, port = DefaultPort, options = {})
      @host    = host
      @port    = port

      @object  = object
      @options = options

      @client = PryRemote::Client.new
      drb = DRb.start_service uri, @client
      yield drb if block_given?

      puts "[pry-remote] Waiting for client on #{uri}"
      @client.wait

      puts "[pry-remote] Client received, starting remote session"
    end
  end
end

class Object
  # Starts a remote Pry session
  #
  # @param [String]  host Host of the server
  # @param [Integer] port Port of the server
  # @param [Hash] options Options to be passed to Pry.start
  def remote_pry(host = PryRemote::DefaultHost, port = PryRemote::DefaultPort, options = {}, &blk)
    PryRemote::Server.new(self, host, port, options, &blk).run
  end

  # a handy alias as many people may think the method is named after the gem
  # (pry-remote)
  alias pry_remote remote_pry
end

