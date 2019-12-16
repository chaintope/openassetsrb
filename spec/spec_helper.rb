# $LOAD_PATH.unshift File.expand_path('../lib', __FILE__)
require 'rubygems'
require 'openassets'
require 'json'

RSpec.configure do |config|
  config.before(:each) do |example|
    if example.metadata[:network] == :testnet
      Bitcoin.chain_params = :testnet
    elsif example.metadata[:network] == :litecoin
      Bitcoin.chain_params = :litecoin
    elsif example.metadata[:network] == :litecoin_testnet
      Bitcoin.chain_params = :litecoin_testnet
    else
      Bitcoin.chain_params = :mainnet
    end
  end
end

def fixture_file(relative_path)
  file = File.read(File.join(File.dirname(__FILE__), 'fixtures', relative_path))
  JSON.parse(file)
end

def load_tx_mock(provider_mock)
  Dir::entries(__dir__ + "/fixtures/tx").each do |file_name|
    next unless file_name.include?(".json")
    txid = file_name.delete(".json")
    json = fixture_file("tx/#{txid}.json")
    allow(provider_mock).to receive(:get_transaction).with(txid, 0).and_return(json['hex'])
    allow(provider_mock).to receive(:get_transaction).with(txid, 1).and_return(json)
    allow(provider_mock).to receive(:getrawtransaction).with(txid, 0).and_return(json['hex'])
    allow(provider_mock).to receive(:getrawtransaction).with(txid, 1).and_return(json)
  end
end

def load_block_mock(provider_mock)
  Dir::entries(__dir__ + "/fixtures/block").each do |file_name|
    next unless file_name.include?(".json")
    block_hash = file_name.delete(".json")
    json = fixture_file("block/#{block_hash}.json")
    allow(provider_mock).to receive(:getblockhash).with(json['height']).and_return(block_hash)
    allow(provider_mock).to receive(:getblock).with(block_hash).and_return(json)
  end
end

def load_help(version)
  File.read("#{File.dirname(__FILE__)}/fixtures/help-result-#{version}.txt")
end

class OpenAssets::Provider::BitcoinCoreProvider
  alias_method :original_request, :request

  def request(command, *params)
    return load_help(core_version) if command == :help
    original_request(command, *params)
  end

  def core_version
    "0.16.0"
  end

end