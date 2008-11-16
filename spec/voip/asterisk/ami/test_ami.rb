require File.dirname(__FILE__) + "/../../../test_helper"
require 'adhearsion'
require 'adhearsion/voip/asterisk/manager_interface'

context "ManagerInterface" do
  
  include ManagerInterfaceTestHelper
  
  before :each do
    @Manager = Adhearsion::VoIP::Asterisk::Manager
    @host, @port = "foobar", 9999
  end
  
  test "should receive data and not die" do
    manager = new_manager_without_events
    flexmock(Thread).should_receive(:new).twice.and_yield
    mock_em_connection = mock_for_next_created_socket
    
    flexmock(FutureResource).new_instances.should_receive(:resource).once.and_return
    
    mock_em_connection.should_receive(:readpartial).once.and_return ami_packets.fresh_socket_connection
    mock_em_connection.should_receive(:readpartial).once.and_raise EOFError
    
    flexmock(manager).should_receive(:action_message_received).once.with(@Manager::NormalAmiResponse)
    manager.connect!
    
  end
  
  test "should use the defaults specified in DEFAULT_SETTINGS when no overrides are given" do
    manager = @Manager::ManagerInterface.new
    %w[host port username password events].each do |property|
      manager.send(property).should.eql @Manager::ManagerInterface::DEFAULT_SETTINGS[property.to_sym]
    end
  end
  
  test "should override the DEFAULT_SETTINGS settings with overrides given to the constructor" do
    overrides = {
      :host     => "yayiamahost",
      :port     => 1337,
      :username => "root",
      :password => "toor",
      :events   => false
    }
    manager = @Manager::ManagerInterface.new overrides
    %w[host port username password events].each do |property|
      manager.send(property).should.eql overrides[property.to_sym]
    end
  end
  
  test "should raise an ArgumentError when it's instantiated with an unrecognized named argument" do
    the_following_code {
      @Manager::ManagerInterface.new :ifeelsopretty => "OH SO PRETTY!"
    }.should.raise ArgumentError
  end
  
  test "a received message that matches an action ID for which we're waiting" do
    action_id = "OHAILOLZ"
    
    manager = new_manager_without_events
    
    flexmock(@Manager::ManagerInterface::ManagerInterfaceAction).new_instances.should_receive(:action_id).once.and_return action_id
    flexmock(manager).should_receive(:login).once.and_return
    
    mock_em_connection = mock_for_next_created_socket
    
    manager.connect!
    
    flexmock(FutureResource).new_instances.should_receive(:resource).once.and_return :THREAD_WAITING_MOCKED_OUT
    flexmock(FutureResource).new_instances.should_receive(:resource=).once.with(@Manager::NormalAmiResponse)
    
    manager.send_action("ping").should.equal :THREAD_WAITING_MOCKED_OUT
    
    manager.send(:instance_variable_get, :@sent_messages).has_key?(action_id).should.equal true
    
    manager.send(:instance_variable_get, :@actions_connection).
        send(:instance_variable_get, :@handler).
        receive_data("Response: Pong\r\nActionID: #{action_id}\r\n\r\n")
    
    manager.send(:instance_variable_get, :@sent_messages).has_key?(action_id).should.equal false
  end
  
  test "a received event is received by Theatre" do
    flexmock(Adhearsion::Events).should_receive(:trigger).once.with(%w[asterisk events], @Manager::Event)
    
    manager = new_manager_with_events
    flexmock(manager).should_receive(:login).twice.and_return
    
    mock_actions_connection = mock_for_next_created_socket
    mock_events_connection  = mock_for_next_created_socket
    
    manager.connect!
    
    manager.send(:instance_variable_get, :@events_connection).
        send(:instance_variable_get, :@handler).
        receive_data ami_packets.reload_event
  end
  
  test "an AMIError should be raised when the action's FutureResource is set to an AMIError instance" do

    flexmock(FutureResource).new_instances.should_receive(:resource).once.and_return @Manager::AMIError.new
    
    manager            = new_manager_without_events
    actions_connection = mock_for_next_created_socket
    flexmock(manager).should_receive(:login).once.and_return
    
    manager.connect!
    
    the_following_code {
      manager.send_action "Foobar"
    }.should.raise @Manager::AMIError
    
  end
  
  test "an AuthenticationFailedException should be raised when the action's FutureResource is set to an AMIError instance" do
    raise
    flexmock(FutureResource).new_instances.should_receive(:resource).once.and_return @Manager::AMIError.new
    
    manager            = new_manager_without_events
    actions_connection = mock_for_next_created_socket
    
    the_following_code {
      manager.connect!
    }.should.raise @Manager::ManagerInterface::AuthenticationFailedException
    
  end
  
  test "that we can test shit sending" do
    response = @Manager::NormalAmiResponse.new
    flexmock(@Manager::ManagerInterface::ManagerInterfaceAction).new_instances.should_receive(:response).once.and_return response
    
    mock_event_socket = flexmock "EventSocket"
    
    flexmock(EventSocket).should_receive(:connect).once.and_return mock_event_socket
    
    write_queue_mock = TestableQueueMock.new
    flexmock(Queue).should_receive(:new).once.and_return write_queue_mock
    
    manager = new_manager_without_events
    
    write_queue_mock.manager = manager
    
    flexmock(manager).should_receive(:login).and_return
    
    manager.connect!
    manager.send_action "Ping"
    
    write_queue_mock.map_action_to_response ""
    write_queue_mock.received_action?(response).should.equal true
  end
  
  test "after calling connect!() with events enabled, both connections perform a login" do
    
    raise
    mock_actions_socket = flexmock "actions EventSocket"
    mock_events_socket  = flexmock "events EventSocket"
    
    write_queue = TestableQueueMock.new(mock_actions_socket)
    
    flexmock(FutureResource).new_instances.should_receive(:resource).once.and_return @Manager::NormalAmiResponse.new
    
    mock_actions_socket.should_receive(:send_data).once.with(/Login/)
    mock_events_socket. should_receive(:send_data).once.with(/Login/)
    
    flexmock(EventSocket).should_receive(:connect).twice.and_return mock_actions_socket, mock_events_socket
    
    flexmock(Queue).should_receive(:new).twice.and_return mock_actions_socket, mock_events_socket
    
    manager = new_manager_with_events
    
    
    
    manager.connect!
  end
  
  test "a failed login on the actions socket raises an AuthenticationFailedException" do
    raise
    manager = new_manager_with_events
    
    mock_socket = flexmock("mock TCPSocket")
    
    # By saying this should happen only once, we're also asserting that the events thread never does a login.
    flexmock(EventSocket).should_receive(:connect).once.and_return mock_socket
    
    future_resource                  = FutureResource.new
    future_resource.resource         = @Manager::AMIError.new
    future_resource.resource.message = "Authentication failed"
    
    action = @Manager::ManagerInterface::ManagerInterfaceAction.new "Login", "Username" => "restdoesntmatter"
    flexmock(action).should_receive(:future_resource).once.and_return future_resource
    
    flexmock(@Manager::ManagerInterface::ManagerInterfaceAction).should_receive(:new).once.and_return action
    
    flexmock(manager).should_receive(:send_action_asynchronously_with_connection).once.with(mock_socket, action).and_return action
    
    the_following_code {
      manager.connect!
    }.should.raise @Manager::ManagerInterface::AuthenticationFailedException
    
  end
  
  test "a failed login on the events socket raises an AuthenticationFailedException" do
    raise
    success = @Manager::NormalAmiResponse.new
    success["Message"] = "Authentication accepted"
    
    failed = @Manager::AMIError.new
    failed.message = "Authentication failed"
    
    manager = new_manager_with_events
    
    mock_actions_socket = flexmock "mock actions EventSocket"
    mock_events_socket = flexmock "mock actions EventSocket"
    
    # By saying this should happen only once, we're also asserting that the events thread never does a login.
    flexmock(EventSocket).should_receive(:connect).once.and_return mock_actions_socket
    flexmock(EventSocket).should_receive(:connect).once.and_return mock_events_socket
    
    success_resource = FutureResource.new
    success_resource.resource = success
    
    failed_resource = FutureResource.new
    failed_resource.resource = failed
    
    flexmock(manager).should_receive(:send_action_asynchronously_with_connection).once.with(mock_actions_socket, "Login", Hash).and_return success_resource
    flexmock(manager).should_receive(:send_action_asynchronously_with_connection).once.with(mock_events_socket, "Login", Hash).and_return failed_resource
    
    the_following_code {
      manager.connect!
    }.should.raise @Manager::ManagerInterface::AuthenticationFailedException
    
  end
  
  test "sending an Action on the ManagerInterface" do
    raise
    mock_event_socket = flexmock "EventSocket"
    flexmock(EventSocket).should_receive(:connect).once.and_return mock_event_socket
    mock_event_socket.should_receive(:send_data).and_return
    
    flexmock(FutureResource).new_instances.should_receive(:resource).once.and_return @Manager::NormalAmiResponse.new
    
    flexmock(Queue).new_instances.should_receive(:<<).once.with @Manager::ManagerInterface::ManagerInterfaceAction
    flexmock(Queue).new_instances.should_receive(:pop).once
    
    manager = new_manager_without_events
    # flexmock(manager).should_receive(:write_loop).once
    flexmock(manager).should_receive(:login).once.and_return
    manager.connect!
    manager.send_action "Ping", "ArbitraryHeader" => "Foobar"
  end

  # test "should raise an error if trying to send an action before connecting" do
  #   the_following_code {
  #     new_manager_without_events.send_action "foo"
  #   }.should.raise( @Manager::ManagerInterface::NotConnectedError)
  # end
  
  test "sending an Action on the ManagerInterface should be received by the EventSocket" do
    raise
    name, headers = "foobar", {"ActionID" => 1226534602.32764}
    
    response = @Manager::NormalAmiResponse.new
    flexmock(FutureResource).new_instances.should_receive(:resource).once.and_return response
    
    mock_connection = flexmock "EventSocket"
    flexmock(EventSocket).should_receive(:connect).once.and_return mock_connection
    
    action = @Manager::ManagerInterface::ManagerInterfaceAction.new(name, headers)
    flexmock(@Manager::ManagerInterface::ManagerInterfaceAction).should_receive(:new).once.with(name, headers).and_return action
    
    mock_connection.should_receive(:send_data).once.with action.to_s
    
    flexmock(Queue).new_instances.should_receive(:<<).once.with @Manager::ManagerInterface::ManagerInterfaceAction
    
    manager = new_manager_without_events
    manager.connect!
    manager.send_action(name, headers)
    
  end
  
  # test 'a "will follow" AMI action' do
  
  # TODO: TEST THAT actions with causal events are combined.
  
  # TODO: TEST THE WRITE LOCK FOR MESSAGES WHICH DO NOT REPLY WITH AN ACTION ID DO LOCK EVERYTHING..
  
  # QUESTION: Do AMI errors respond with action id?
  
  # YAGNI? test "a failed login on sets the state to :failed"
  
end

context "ManagerInterfaceAction" do
  
  before :each do
    @ManagerInterface = Adhearsion::VoIP::Asterisk::Manager::ManagerInterface
  end
  
  test "should simply proxy the replies_with_action_id?() method" do
    name, headers = "foobar", {"foo" => "bar"}
    flexmock(@ManagerInterface).should_receive(:replies_with_action_id?).once.and_return
    @ManagerInterface::ManagerInterfaceAction.new(name, headers).replies_with_action_id?
  end
  
  test "should simply proxy the has_causal_events?() method" do
    name, headers = "foobar", {"foo" => "bar"}
    flexmock(@ManagerInterface).should_receive(:has_causal_events?).once.and_return
    @ManagerInterface::ManagerInterfaceAction.new(name, headers).has_causal_events?
  end
  
  test "should properly convert itself into a String" do
    name, headers = "Hawtsawce", {"Monkey" => "Zoo"}
    string = @ManagerInterface::ManagerInterfaceAction.new(name, headers).to_s
    string.should =~ /^Action: Hawtsawce\r\n/
    string.should =~ /\r\n\r\n$/
    string.should =~ /^(\w+:\s*[\w-]+\r\n){3}\r\n$/
  end
  
end

context "DelegatingAsteriskManagerInterfaceLexer" do
  test "should translate the :syntax_error_encountered method call when a method_delegation_map is given" do
    official_method, new_method = :syntax_error_encountered, :ohai_syntax_error!
    method_argument = :testing123
    mock_manager_interface = flexmock "ManagerInterface which receives callbacks"
    mock_manager_interface.should_receive(new_method).once.with(method_argument).and_return
    parser = Adhearsion::VoIP::Asterisk::Manager::DelegatingAsteriskManagerInterfaceLexer.new mock_manager_interface,
        official_method => new_method
    parser.send official_method, method_argument
  end
  test "should translate the :message_received method call when a method_delegation_map is given" do
    official_method, new_method = :message_received, :wuzup_new_message_YO!
    method_argument = :message_message_message_message
    mock_manager_interface = flexmock "ManagerInterface which receives callbacks"
    mock_manager_interface.should_receive(new_method).once.with(method_argument).and_return
    parser = Adhearsion::VoIP::Asterisk::Manager::DelegatingAsteriskManagerInterfaceLexer.new mock_manager_interface,
        official_method => new_method
    parser.send official_method, method_argument
  end
  test "should translate the :syntax_error_encountered method call when a method_delegation_map is given" do
    official_method, new_method = :error_received, :zomgs_ERROR!
    method_argument = :errrrrrr
    mock_manager_interface = flexmock "ManagerInterface which receives callbacks"
    mock_manager_interface.should_receive(new_method).once.with(method_argument).and_return
    parser = Adhearsion::VoIP::Asterisk::Manager::DelegatingAsteriskManagerInterfaceLexer.new mock_manager_interface,
        official_method => new_method
    parser.send official_method, method_argument
  end
  
  test "should translate all method calls when a comprehensive method_delegation_map is given" do
    method_delegation_map = {
      :error_received   => :here_is_an_error,
      :message_received => :here_is_a_message,
      :syntax_error_encountered => :here_is_a_syntax_error
    }
    mock_manager_interface = flexmock "ManagerInterface which receives callbacks"
    method_delegation_map.each_pair do |old_method,new_method|
      mock_manager_interface.should_receive(new_method).once.with(old_method).and_return
    end
    parser = Adhearsion::VoIP::Asterisk::Manager::DelegatingAsteriskManagerInterfaceLexer.new mock_manager_interface, method_delegation_map
    method_delegation_map.each_pair do |old_method, new_method|
      parser.send(old_method, old_method)
    end
  end
end

context "ActionManagerInterfaceConnection" do
  test "should notify its associated ManagerInterface when a new message is received"
  test "should notify its associated ManagerInterface when a new event is received"
  test "should notify its associated ManagerInterface when a new error is received"
end

context "EventManagerInterfaceConnection" do
  test "should notify its associated ManagerInterface when a new message is received"
  test "should notify its associated ManagerInterface when a new event is received"
  test "should notify its associated ManagerInterface when a new error is received"
  test "should stop gracefully by allowing the Queue to finish writing to the Theatre"
  test "should stop forcefully by not allowing the Queue to finish writing to the Theatre"
end

BEGIN {
  
  module ManagerInterfaceTestHelper
    
    def mocked_queue
      # This mock queue receives a ManagerInterfaceAction with <<(). Within the semantics of the OO design, this should be
      # immediately picked up by the writer queue. The writer queue calls to_s on each object and passes that string to the
      # event socket, blocking if it's an event with causal events.
      mock_queue = TestableQueue.new

    end
    
    def ami_packets
      returning OpenStruct.new do |struct|
        struct.fresh_socket_connection = "Asterisk Call Manager/1.0\r\nResponse: Success\r\n"+
            "Message: Authentication accepted\r\n\r\n"
        
        struct.reload_event = %{Event: ChannelReload\r\nPrivilege: system,all\r\nChannel: SIP\r\n} +
            %{ReloadReason: RELOAD (Channel module reload)\r\nRegistry_Count: 1\r\nPeer_Count: 2\r\nUser_Count: 1\r\n\r\n}

        struct.authentication_failed = %{Asterisk Call Manager/1.0\r\nResponse: Error\r\nMessage: Authentication failed\r\nActionID: %s\r\n\r\n}
        
        struct.unknown_command_error = "Response: Error\r\nActionID: 2123123\r\nMessage: Invalid/unknown command\r\n\r\n"
      end
    end
    
    def new_manager_with_events
      @Manager::ManagerInterface.new :host => @host, :port => @port, :events => true
    end
    
    def new_manager_without_events
      @Manager::ManagerInterface.new :host => @host, :port => @port, :events => false
    end
    
    def mock_for_next_created_socket
      actions_socket_mock = flexmock "TCPSocket"
      flexmock(TCPSocket).should_receive(:new).once.and_return actions_socket_mock
      actions_socket_mock
    end
    
  end
  

  ##
  # Had to implement this class to make the Thread-based testing simpler.
  #
  class TestableQueueMock
    
    attr_accessor :manager
    def initialize
      @actions = []
      @action_to_response_hash = {}
    end
    
    def <<(action)
      @actions << action
      @manager.send(:instance_variable_get, :@actions_connection).send_data action.to_s
      response = @action_to_response_hash[action.name]
      @event_socket.receive_data(response)
    end
    
    def map_action_to_response(new_map)
      @action_to_response_hash.update new_map
    end
    
    def received_action?(action)
      @actions.include?(action)
    end
    
  end
}
