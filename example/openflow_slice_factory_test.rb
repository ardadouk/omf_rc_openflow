# OMF_VERSIONS = 6.0

@comm = OmfEc.comm

# @comm is default communicator defined in script runner
#
@flowvisor_id = "flowvisor"
@flowvisor_topic = @comm.get_topic(@flowvisor_id)

@slice_id = nil
@slice_topic = nil

msgs = {
  create_slice: @comm.create_message([type: 'openflow_slice']),
  config_slice: @comm.configure_message([name: 'test', contact_email: 'a@a']),
  slices: @comm.request_message([:slices]),
  config_flows: @comm.configure_message([flows: [{operation: 'add', device: '00:00:00:00:00:00:00:01', eth_dst: '11:22:33:44:55:66'},
                                                 {operation: 'add', device: '00:00:00:00:00:00:00:01', eth_dst: '11:22:33:44:55:77'}]]),
}

@flowvisor_topic.subscribe {msgs[:create_slice].publish @flowvisor_id}

# If flowvisor is not raised, the following rule will be activated.
@flowvisor_topic.on_message lambda {|m| m.operation == :inform && m.read_content('inform_type') == 'CREATION_FAILED' } do |message|
  logger.error message.read_content('reason')
  done!
end

msgs[:create_slice].on_inform_creation_ok do |message|
  @slice_id = message.resource_id
  @slice_topic = @comm.get_topic(@slice_id)
 
  msgs[:release_slice] ||= @comm.release_message {|m| m.element('resource_id', @slice_id)}
  msgs[:release_slice].on_inform_released do |message|
    logger.info "Slice (#{@slice_id}) released"
    m = @comm.request_message([:slices])
    m.on_inform_status do |message|
      logger.info "Flowvisor (#{message.read_property('uid')}) requested slices: #{message.read_property('slices').join(', ')}"
      done!
    end
    m.publish @flowvisor_id
  end
  
  logger.info "Slice (#{@slice_id}) created"
  @slice_topic.subscribe {msgs[:config_slice].publish @slice_id}
end

msgs[:config_slice].on_inform_status do |message|
  logger.info "Slice (#{message.read_property('uid')}) configured name: #{message.read_property('name')} & contact_email: #{message.read_property('contact_email')}"
  msgs[:slices].publish @flowvisor_id
end

msgs[:slices].on_inform_status do |message|
  logger.info "Flowvisor (#{message.read_property('uid')}) requested slices: #{message.read_property('slices').join(', ')}"
  msgs[:config_flows].publish @slice_id
end

msgs[:config_flows].on_inform_status do |message|
  logger.info "Slice (#{message.read_property('uid')}) configured flows: "
  message.read_property('flows').each do |flow|
    logger.info "  #{flow}"
  end
  msgs[:release_slice].publish @flowvisor_id
end
