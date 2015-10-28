require 'spec_helper'

describe DeliverySugar::DSL do
  let(:example_knife_rb) { File.join(SUPPORT_DIR, 'example_knife.rb') }
  let(:example_config) do
    Chef::Config.from_file(example_knife_rb)
    config = Chef::Config.save
    Chef::Config.reset
    config
  end
  let(:custom_workspace) { '/var/my/awesome/workspace' }
  let(:default_workspace) { '/var/opt/delivery/workspace' }
  let(:mock_new_node) do
    n = Chef::Node.new
    n.set['delivery']['workspace_path'] = custom_workspace
    n
  end
  let(:mock_old_node) do
    n = Chef::Node.new
    n.set['delivery']['workspace'] = 'something'
    n
  end

  subject do
    Object.new.extend(described_class)
  end

  describe '#delivery_knife_rb' do
    context 'when node attribute is set from the delivery-cli' do
      before do
        allow_any_instance_of(DeliverySugar::DSL).to receive(:node)
          .and_return(mock_new_node)
      end
      it 'returns the custom delivery knife.rb' do
        expect(subject.delivery_knife_rb).to eq("#{custom_workspace}/.chef/knife.rb")
      end
    end

    context 'when node attribute is not set' do
      it 'returns the default delivery knife.rb' do
        expect(subject.delivery_knife_rb).to eq("#{default_workspace}/.chef/knife.rb")
      end
    end
  end

  describe '#delivery_workspace' do
    context 'when node attribute is set from the delivery-cli' do
      before do
        allow_any_instance_of(DeliverySugar::DSL).to receive(:node)
          .and_return(mock_new_node)
      end
      it 'returns the custom workspace' do
        expect(subject.delivery_workspace).to eq(custom_workspace)
      end
    end

    context 'when old version of delivery-cli sets partial attribute' do
      before do
        allow_any_instance_of(DeliverySugar::DSL).to receive(:node)
          .and_return(mock_old_node)
      end
      it 'returns the default workspace' do
        expect(subject.delivery_workspace).to eq(default_workspace)
      end
    end

    context 'when node attribute is not set' do
      it 'returns the default workspace' do
        expect(subject.delivery_workspace).to eq(default_workspace)
      end
    end
  end

  describe '#with_server_config' do
    before do
      allow_any_instance_of(DeliverySugar::DSL).to receive(:delivery_knife_rb)
        .and_return(example_knife_rb)
    end

    it 'runs code block with the chef server\'s Chef::Config' do
      block = lambda do
        subject.with_server_config do
          Chef::Config[:chef_server_url]
        end
      end
      expect(Chef::Config[:chef_server_url])
        .not_to eql(example_config[:chef_server_url])
      expect(block.call).to match(example_config[:chef_server_url])
    end
  end

  describe '#load_delivery_chef_config' do
    before do
      allow_any_instance_of(DeliverySugar::DSL).to receive(:delivery_knife_rb)
        .and_return(example_knife_rb)
    end

    it 'calls chef_server.load_server_config' do
      subject.load_delivery_chef_config
      expect(Chef::Config[:chef_server_url]).to eql(example_config[:chef_server_url])
    end
  end

  describe '.changed_cookbooks' do
    it 'gets a list of changed cookbook from the change object' do
      expect(subject).to receive_message_chain(:change,
                                               :changed_cookbooks)
      subject.changed_cookbooks
    end
  end

  describe '.changed_files' do
    it 'gets a list of changed files from the change object' do
      expect(subject).to receive_message_chain(:change, :changed_files)
      subject.changed_files
    end
  end

  describe '.delivery_chef_server' do
    let(:chef_server_configuration) { double 'a configuration hash' }

    it 'returns a cheffish configuration for interacting with the chef server' do
      expect(subject).to receive_message_chain(:chef_server, :cheffish_details)
        .and_return(chef_server_configuration)

      expect(subject.delivery_chef_server).to eql(chef_server_configuration)
    end
  end

  describe '.delivery_environment' do
    it 'get the current environment from the Change object' do
      expect(subject).to receive_message_chain(:change,
                                               :environment_for_current_stage)
      subject.delivery_environment
    end
  end

  describe '.get_acceptance_environment' do
    it 'gets the acceptance environment for the pipeline from the change object' do
      expect(subject).to receive_message_chain(:change,
                                               :acceptance_environment)
      subject.get_acceptance_environment
    end
  end

  describe '.project_slug' do
    it 'gets slug from Change object' do
      expect(subject).to receive_message_chain(:change, :project_slug)
      subject.project_slug
    end
  end

  describe '.get_project_secrets' do
    let(:project_slug) { 'ent-org-proj' }
    let(:data_bag_contents) do
      {
        'id' => 'ent-org-proj',
        'secret' => 'password'
      }
    end

    it 'gets the secrets from the Change object' do
      expect(subject).to receive_message_chain(:change, :project_slug)
        .and_return(project_slug)
      expect(subject)
        .to receive_message_chain(:chef_server, :encrypted_data_bag_item)
        .with('delivery-secrets', project_slug).and_return(data_bag_contents)

      expect(subject.get_project_secrets).to eql(data_bag_contents)
    end
  end
end
