#!/usr/bin/env ruby

require 'omf_rc'
require 'omf_rc/resource_factory'
#require 'omf_rc_openflow'
$stdout.sync = true

Blather.logger = logger

opts = {
  # XMPP server domain
  server: 'srv.mytestbed.net',
  user: 'flowvisor',
  password: 'pw',
  uid: 'flowvisor',
  # Debug mode of not
  debug: false
}

Logging.logger.root.level = :debug if opts[:debug]

OmfRc::ResourceFactory.load_addtional_resource_proxies(File.dirname(__FILE__)+"/../lib/omf_rc/util")
OmfRc::ResourceFactory.load_addtional_resource_proxies(File.dirname(__FILE__)+"/../lib/omf_rc/resource_proxy")

EM.run do
  # Use resource factory method to initialise a new instance of garage
  info "Starting #{opts[:uid]}"
  flowvisor = OmfRc::ResourceFactory.new(:openflow_slice_factory, opts)
  flowvisor.connect

  # Disconnect garage from XMPP server, when these two signals received
  trap(:INT) { flowvisor.disconnect }
  trap(:TERM) { flowvisor.disconnect }
end
