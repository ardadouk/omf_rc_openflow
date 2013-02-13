# This resource is created from the parent :virtual_openflow_switch_factory resource.
# It is related with a bridge of an ovsdb-server instance, and behaves as a proxy between experimenter and the actual ovsdb-server bridge.
#
module OmfRc::ResourceProxy::VirtualOpenflowSwitch
  include OmfRc::ResourceProxyDSL

  register_proxy :virtual_openflow_switch, :create_by => :virtual_openflow_switch_factory

  utility :virtual_openflow_switch_tools


  # Switch name is initiated with value "nil"
  hook :before_ready do |resource|
    resource.property.name = nil
  end

  # Before release, the related ovsdb-server instance should also remove the corresponding switch
  hook :before_release do |resource|
    arguments = {
      "method" => "transact",
      "params" => [ "Open_vSwitch",
                    { "op" => "mutate",
                      "table" => "Open_vSwitch",
                      "where" => [],
                      "mutations" => [["bridges", "delete", ["set", [["uuid", resource.property.uuid]]]]]
                    },
                    { "op" => "delete",
                      "table" => "Bridge",
                      "where" => [["name", "==", resource.property.name]],
                    },
                    { "op" => "delete",
                      "table" => "Port",
                      "where" => [["name", "==", resource.property.name]]
                    },
                    { "op" => "delete",
                      "table" => "Interface",
                      "where" => [["name", "==", resource.property.name]]
                    }
                  ],
      "id" => "remove-switch"
    }
    resource.ovs_connection("ovsdb-server", arguments)
  end


  # Switch name is one-time configured
  configure :name do |resource, name|
    raise "The name cannot be changed" if resource.property.name
    resource.property.name = name.to_s
    arguments = {
      "method" => "transact",
      "params" => [ "Open_vSwitch",
                    { "op" => "insert",
                      "table" => "Interface",
                      "row" => {"name" => resource.property.name, "type" => "internal"},
                      "uuid-name" => "new_interface"
                    },
                    { "op" => "insert",
                      "table" => "Port",
                      "row" => {"name" => resource.property.name, "interfaces" => ["named-uuid", "new_interface"]},
                      "uuid-name" => "new_port"
                    },
                    { "op" => "insert",
                      "table" => "Bridge",
                      "row" => {"name" => resource.property.name, "ports" => ["named-uuid", "new_port"], "datapath_type" => "netdev"},
                      "uuid-name" => "new_bridge"
                    },
                    { "op" => "mutate",
                      "table" => "Open_vSwitch",
                      "where" => [],
                      "mutations" => [["bridges", "insert", ["set", [["named-uuid", "new_bridge"]]]]]
                    }
                  ],
      "id" => "add-switch"
    }
    result = resource.ovs_connection("ovsdb-server", arguments)["result"]
    raise "The requested switch already existed in ovsdb-server or there is another problem" if result[4]
    resource.property.uuid = result[2]["uuid"][1]
    resource.property.name
  end

  # Add/remove port
  configure :ports do |resource, array_parameters|
    array_parameters = [array_parameters] if !array_parameters.kind_of?(Array)
    array_parameters.each do |parameters|
      arguments = nil
      if parameters.operation == "add"
        arguments = {
          "method" => "transact",
          "params" => [ "Open_vSwitch",
                        { "op" => "insert",
                          "table" => "Interface",
                          "row" => {"name" => parameters.name, "type" => parameters.type},
                          "uuid-name" => "new_interface"
                        },
                        { "op" => "insert",
                          "table" => "Port",
                          "row" => {"name" => parameters.name, "interfaces" => ["named-uuid", "new_interface"]},
                          "uuid-name" => "new_port"
                        },
                        { "op" => "mutate",
                          "table" => "Bridge",
                          "where" => [["name", "==", resource.property.name]],
                          "mutations" => [["ports", "insert", ["set", [["named-uuid", "new_port"]]]]]
                        }
                      ],
          "id" => "add-port"
        }
      elsif parameters.operation == "remove" # TODO: It is not filled
      end
      result = resource.ovs_connection("ovsdb-server", arguments)["result"]
      raise "The configuration of the switch ports faced a problem" if result[3]
    end
    resource.ports
  end

  # Request port information (XXX: very restrictive, just to support our case)
  request :port do |resource, parameters|
    arguments = {
      "method" => parameters.information,
      "params" => [parameters.name],
      "id" => "port-info"
    }
    resource.ovs_connection("ovs-vswitchd", arguments)["result"]
  end

  # Configure port (XXX: very restrictive, just to support our case)
  configure :port do |resource, parameters|
    arguments = {
      "method" => "transact",
      "params" => [ "Open_vSwitch",
                    { "op" => "mutate",
                      "table" => "Interface",
                      "where" => [["name", "==", parameters.name]],
                      "mutations" => [["options", "insert", ["map", 
                         [["remote_ip", parameters.remote_ip], ["remote_port", parameters.remote_port.to_s]]]]]
                    }
                  ],
      "id" => "configure-port"
    }
    resource.ovs_connection("ovsdb-server", arguments)["result"]
  end
end
